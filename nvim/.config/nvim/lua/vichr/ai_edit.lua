local M = {}

local uv = vim.uv or vim.loop
local opencode_version = '1.18.21'
local helper_cache_version = '5'
local output_limit = { max_bytes = 32768, max_lines = 10 }
local jobs = {}
local options = {
  keymap = '<leader>ai',
  command = 'opencode',
  timeout_ms = 5 * 60 * 1000,
  cleanup_timeout_ms = 2000,
  max_bytes = 1024 * 1024,
  width = 0.6,
  height = 0.3,
}

local safe_tools = {
  invalid = false,
  read = true,
  glob = true,
  grep = true,
  stage_text = true,
  apply_patch = false,
  edit = false,
  write = false,
  bash = false,
  webfetch = false,
  websearch = false,
  codesearch = false,
  task = false,
  todowrite = false,
  question = false,
  skill = false,
}

local function notify(message, level)
  vim.notify('AI edit: ' .. message, level or vim.log.levels.INFO)
end

local function random_id()
  return vim.fn.sha256(vim.fn.tempname() .. tostring(uv.hrtime()) .. tostring(vim.fn.getpid())):sub(1, 24)
end

local function copy_table(value)
  return vim.deepcopy(value)
end

local function buffer_text(buffer)
  return table.concat(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), '\n')
end

local function absolute_buffer_path(buffer)
  local name = vim.api.nvim_buf_get_name(buffer)
  if name == '' then
    return nil
  end
  return vim.fn.fnamemodify(name, ':p')
end

local function eligible(buffer, max_bytes)
  if not vim.api.nvim_buf_is_valid(buffer) or not vim.api.nvim_buf_is_loaded(buffer) then
    return nil, 'target buffer is no longer available'
  end
  if vim.bo[buffer].buftype ~= '' then
    return nil, 'current buffer is not a file buffer'
  end
  local path = absolute_buffer_path(buffer)
  if not path then
    return nil, 'current buffer has no file name'
  end
  if vim.bo[buffer].readonly then
    return nil, 'current buffer is readonly'
  end
  if not vim.bo[buffer].modifiable then
    return nil, 'current buffer is not writable'
  end
  if vim.bo[buffer].binary then
    return nil, 'binary buffers are unsupported'
  end
  local text = buffer_text(buffer)
  if #text > max_bytes then
    return nil, string.format('buffer size exceeds %d-byte limit', max_bytes)
  end
  return { path = path, text = text }
end

local function project_root(path)
  local directory = vim.fs.dirname(path)
  local current = directory
  while current and current ~= '' do
    if uv.fs_stat(current .. '/.git') then
      return current
    end
    local parent = vim.fs.dirname(current)
    if not parent or parent == current then
      break
    end
    current = parent
  end
  return directory
end

local function capture_visual(buffer, mode)
  if mode == '\22' then
    return nil, 'blockwise selections are unsupported'
  end
  if mode ~= 'v' and mode ~= 'V' then
    return nil, 'unsupported visual selection'
  end

  local anchor = vim.fn.getpos 'v'
  local cursor = vim.fn.getpos '.'
  local first = { row = anchor[2], col = anchor[3] }
  local last = { row = cursor[2], col = cursor[3] }
  if first.row > last.row or (first.row == last.row and first.col > last.col) then
    first, last = last, first
  end

  if mode == 'V' then
    return {
      kind = 'line',
      start_row = first.row - 1,
      end_row = last.row,
      label = string.format('lines %d-%d', first.row, last.row),
    }
  end

  local region_options = {
    type = 'v',
    exclusive = vim.o.selection == 'exclusive',
  }
  local lines = vim.fn.getregion(anchor, cursor, region_options)
  region_options.eol = true
  local positions = vim.fn.getregionpos(anchor, cursor, region_options)
  if #lines == 0 or #positions == 0 then
    return nil, 'visual selection is empty'
  end

  local start_position = positions[1][1]
  local start_row = start_position[2] - 1
  local start_col = math.max(0, start_position[3] - 1)
  local end_row = start_row + #lines - 1
  local end_col = #lines == 1 and start_col + #lines[1] or #lines[#lines]
  local selected = table.concat(lines, '\n')
  local valid_range, actual_lines = pcall(vim.api.nvim_buf_get_text, buffer, start_row, start_col, end_row, end_col, {})
  if not valid_range or table.concat(actual_lines, '\n') ~= selected then
    return nil, 'visual selection does not map to an exact buffer byte range'
  end

  return {
    kind = 'character',
    start_row = start_row,
    start_col = start_col,
    end_row = end_row,
    end_col = end_col,
    text = selected,
    label = string.format('%d:%d-%d:%d', first.row, first.col, last.row, last.col),
  }
end

local function selection_text(buffer, target)
  if target.text ~= nil then
    return target.text
  end
  if target.kind == 'line' then
    return table.concat(vim.api.nvim_buf_get_lines(buffer, target.start_row, target.end_row, false), '\n')
  end
  return table.concat(vim.api.nvim_buf_get_text(buffer, target.start_row, target.start_col, target.end_row, target.end_col, {}), '\n')
end

local function read_file(path)
  local file, error_message = io.open(path, 'rb')
  if not file then
    return nil, error_message
  end
  local value = file:read '*a'
  file:close()
  return value
end

local function write_file(path, text, mode)
  local descriptor, open_error = uv.fs_open(path, 'w', mode or tonumber('600', 8))
  if not descriptor then
    return nil, open_error
  end

  local offset = 0
  local operation_error
  while offset < #text do
    local written, write_error = uv.fs_write(descriptor, text:sub(offset + 1), -1)
    if not written then
      operation_error = write_error
      break
    end
    if written <= 0 or written > #text - offset then
      operation_error = 'invalid short write result: ' .. tostring(written)
      break
    end
    offset = offset + written
  end
  if not operation_error then
    local synced, sync_error = uv.fs_fsync(descriptor)
    if not synced then
      operation_error = sync_error
    end
  end
  local closed, close_error = uv.fs_close(descriptor)
  if operation_error then
    return nil, operation_error
  end
  if not closed then
    return nil, close_error
  end
  return true
end

local function create_directory_recursive(path)
  local status = uv.fs_lstat(path)
  if status then
    if status.type ~= 'directory' then
      return nil, 'path is not a directory'
    end
    return true
  end
  local parent = vim.fs.dirname(path)
  if parent and parent ~= path then
    local ok, error_message = create_directory_recursive(parent)
    if not ok then
      return nil, error_message
    end
  end
  local created, mkdir_error = uv.fs_mkdir(path, tonumber('700', 8))
  if created then
    return true
  end
  status = uv.fs_lstat(path)
  if not status or status.type ~= 'directory' then
    return nil, mkdir_error
  end
  return true
end

local function private_directory(path)
  local created, mkdir_error = create_directory_recursive(path)
  if not created then
    return nil, mkdir_error
  end
  local ok, error_message = uv.fs_chmod(path, tonumber('700', 8))
  if not ok then
    return nil, error_message
  end
  return true
end

local function cleanup(job)
  if job.cleaned then
    return
  end
  job.cleaned = true
  if job.stage_root then
    vim.fn.delete(job.stage_root, 'rf')
  end
  if job.helper_build then
    vim.fn.delete(job.helper_build, 'rf')
  end
end

local function create_staging(job)
  local parent = vim.fn.stdpath 'cache' .. '/nvim-ai-edit/staging'
  local ok, error_message = private_directory(parent)
  if not ok then
    return nil, 'cannot create private staging parent: ' .. tostring(error_message)
  end
  local root = parent .. '/' .. random_id()
  ok, error_message = private_directory(root)
  if not ok then
    return nil, 'cannot create private staging directory: ' .. tostring(error_message)
  end
  job.stage_root = root

  local extension = vim.fn.fnamemodify(job.path, ':e')
  local suffix = extension == '' and '' or '.' .. extension
  job.stage_target = root .. '/target' .. suffix
  ok, error_message = write_file(job.stage_target, job.target_text)
  if not ok then
    return nil, 'cannot write staging target: ' .. tostring(error_message)
  end

  if job.target.kind ~= 'whole' then
    job.stage_context = root .. '/context' .. suffix
    ok, error_message = write_file(job.stage_context, job.full_text, tonumber('400', 8))
    if not ok then
      return nil, 'cannot write read-only context: ' .. tostring(error_message)
    end
    uv.fs_chmod(job.stage_context, tonumber('400', 8))
  end
  return true
end

local function helper_source()
  local source_paths = vim.api.nvim_get_runtime_file('lua/vichr/ai_edit/stage_text.ts', false)
  local source_path = source_paths[1]
  if not source_path then
    return nil, 'trusted stage_text helper source is missing'
  end
  local source, read_error = read_file(source_path)
  if not source then
    return nil, 'cannot read trusted stage_text helper: ' .. tostring(read_error)
  end
  local parent = vim.fn.stdpath 'cache' .. '/nvim-ai-edit'
  local command = vim.fn.exepath(options.command)
  if command == '' then
    command = options.command
  end
  local root = parent
    .. '/helper-'
    .. helper_cache_version
    .. '-'
    .. opencode_version
    .. '-'
    .. vim.fn.sha256(source):sub(1, 16)
    .. '-'
    .. vim.fn.sha256(command):sub(1, 12)
  return { source = source, parent = parent, root = root, cache = root .. '/opencode' }
end

local function verify_helper_cache(cache, source)
  local status = uv.fs_lstat(cache)
  if not status or status.type ~= 'directory' then
    return nil, 'published helper cache is missing'
  end
  for _, path in ipairs {
    cache .. '/tool/stage_text.ts',
    cache .. '/package.json',
    cache .. '/node_modules/@opencode-ai/plugin/package.json',
    cache .. '/node_modules/@opencode-ai/plugin/dist/index.js',
  } do
    local file_status = uv.fs_lstat(path)
    if not file_status or file_status.type ~= 'file' then
      return nil, 'published helper cache contains a missing or redirected required file'
    end
  end
  local installed_source, source_error = read_file(cache .. '/tool/stage_text.ts')
  if installed_source ~= source then
    return nil, 'published helper source differs from trusted source: ' .. tostring(source_error or '')
  end
  local manifest_text, manifest_error = read_file(cache .. '/package.json')
  if not manifest_text then
    return nil, 'published helper manifest is unreadable: ' .. tostring(manifest_error)
  end
  local manifest_ok, manifest = pcall(vim.json.decode, manifest_text)
  if
    not manifest_ok
    or type(manifest) ~= 'table'
    or type(manifest.dependencies) ~= 'table'
    or manifest.dependencies['@opencode-ai/plugin'] ~= opencode_version
  then
    return nil, 'published helper manifest has wrong dependency version'
  end
  local package_text, package_error = read_file(cache .. '/node_modules/@opencode-ai/plugin/package.json')
  if not package_text then
    return nil, 'published helper dependency is unreadable: ' .. tostring(package_error)
  end
  local package_ok, package = pcall(vim.json.decode, package_text)
  if not package_ok or type(package) ~= 'table' or package.version ~= opencode_version then
    return nil, 'published helper dependency has wrong version'
  end
  return true
end

local function seal_helper_cache(path)
  local status = uv.fs_lstat(path)
  if not status then
    return nil, 'cannot inspect helper cache entry'
  end
  if status.type == 'link' then
    return true
  end
  if status.type == 'directory' then
    local scanner, scan_error = uv.fs_scandir(path)
    if not scanner then
      return nil, scan_error
    end
    while true do
      local name = uv.fs_scandir_next(scanner)
      if not name then
        break
      end
      local ok, error_message = seal_helper_cache(path .. '/' .. name)
      if not ok then
        return nil, error_message
      end
    end
    return uv.fs_chmod(path, tonumber('500', 8))
  end
  return uv.fs_chmod(path, tonumber('400', 8))
end

local function discard_helper_build(path)
  local status = uv.fs_lstat(path)
  if not status then
    return
  end
  if status.type == 'directory' then
    uv.fs_chmod(path, tonumber('700', 8))
    local scanner = uv.fs_scandir(path)
    if scanner then
      while true do
        local name = uv.fs_scandir_next(scanner)
        if not name then
          break
        end
        discard_helper_build(path .. '/' .. name)
      end
    end
  elseif status.type ~= 'link' then
    uv.fs_chmod(path, tonumber('600', 8))
  end
  if status.type == 'directory' then
    vim.fn.delete(path, 'rf')
  else
    vim.fn.delete(path)
  end
end

local function materialize_helper_build(info)
  local ok, error_message = private_directory(info.parent)
  if not ok then
    return nil, 'cannot create trusted helper parent: ' .. tostring(error_message)
  end
  local root = info.parent .. '/.helper-build-' .. random_id()
  local cache = root .. '/opencode'
  local tool_directory = cache .. '/tool'
  ok, error_message = private_directory(tool_directory)
  if not ok then
    return nil, 'cannot create trusted helper build: ' .. tostring(error_message)
  end
  ok, error_message = write_file(tool_directory .. '/stage_text.ts', info.source)
  if not ok then
    vim.fn.delete(root, 'rf')
    return nil, 'cannot materialize trusted helper: ' .. tostring(error_message)
  end
  local manifest = vim.json.encode { dependencies = { ['@opencode-ai/plugin'] = opencode_version } }
  ok, error_message = write_file(cache .. '/package.json', manifest)
  if not ok then
    vim.fn.delete(root, 'rf')
    return nil, 'cannot materialize helper dependency manifest: ' .. tostring(error_message)
  end
  return { root = root, cache = cache }
end

local function isolated_environment(job, cache, config, suffix)
  local environment = vim.fn.environ()
  local isolation = job.stage_root .. '/' .. suffix
  private_directory(isolation .. '/home')
  if cache then
    environment.XDG_CONFIG_HOME = vim.fs.dirname(cache)
  else
    private_directory(isolation .. '/config')
    environment.XDG_CONFIG_HOME = isolation .. '/config'
  end
  environment.OPENCODE_TEST_HOME = isolation .. '/home'
  environment.OPENCODE_CONFIG = nil
  environment.OPENCODE_CONFIG_DIR = cache
  environment.OPENCODE_CONFIG_CONTENT = vim.json.encode(config)
  environment.OPENCODE_PURE = '1'
  environment.OPENCODE_DISABLE_DEFAULT_PLUGINS = nil
  environment.OPENCODE_DISABLE_PROJECT_CONFIG = '1'
  environment.OPENCODE_DISABLE_AUTOSHARE = '1'
  environment.NVIM_AI_EDIT_STAGE_ROOT = job.stage_root
  environment.NVIM_AI_EDIT_STAGE_TARGET = job.stage_target
  environment.NVIM_AI_EDIT_MAX_BYTES = tostring(job.options.max_bytes)
  environment.NVIM_AI_EDIT_CONTEXT = job.stage_context
  return environment
end

local function runtime_environment(job)
  return isolated_environment(job, job.cache, job.config, 'runtime')
end

local function global_config_environment(job)
  local environment = vim.fn.environ()
  environment.OPENCODE_CONFIG_CONTENT = vim.json.encode(job.config)
  environment.OPENCODE_PURE = '1'
  environment.OPENCODE_DISABLE_DEFAULT_PLUGINS = nil
  environment.OPENCODE_DISABLE_PROJECT_CONFIG = '1'
  environment.OPENCODE_DISABLE_AUTOSHARE = '1'
  return environment
end

local function restricted_config(job)
  local permission = {
    invalid = 'deny',
    read = 'allow',
    glob = 'allow',
    grep = 'allow',
    stage_text = 'allow',
    apply_patch = 'deny',
    edit = 'deny',
    write = 'deny',
    bash = 'deny',
    webfetch = 'deny',
    websearch = 'deny',
    codesearch = 'deny',
    task = 'deny',
    todowrite = 'deny',
    question = 'deny',
    skill = 'deny',
    external_directory = 'deny',
    lsp = 'deny',
  }
  local prompt = table.concat({
    'Edit only the host-selected staging target through stage_text.',
    'Use stage_text read pages as authoritative unsaved target content; context is read-only.',
    'Submit exactly once with the current revision using exact operations or a complete replacement.',
    'Never mutate project files. Project reads are context only.',
    'Original file: ' .. job.path,
    'Project root: ' .. job.project_root,
    'Target scope: ' .. (job.target.label or 'whole buffer'),
  }, '\n')
  return {
    share = 'disabled',
    snapshot = false,
    formatter = false,
    lsp = false,
    plugin = vim.json.decode '[]',
    tool_output = copy_table(output_limit),
    tools = copy_table(safe_tools),
    permission = permission,
    agent = {
      [job.agent] = {
        mode = 'primary',
        disable = false,
        prompt = prompt,
        permission = copy_table(permission),
      },
    },
  }
end

local function enabled_tools(value)
  local result = {}
  for name, enabled in pairs(value or {}) do
    if enabled == true then
      table.insert(result, name)
    end
  end
  table.sort(result)
  return result
end

local expected_enabled_tools = { 'glob', 'grep', 'read', 'stage_text' }

local function validate_resolved_config(config)
  if type(config) ~= 'table' then
    return nil, 'resolved config is not an object'
  end
  if config.share ~= 'disabled' then
    return nil, 'sharing is not disabled'
  end
  if config.snapshot ~= false then
    return nil, 'snapshots are not disabled'
  end
  if config.formatter ~= false then
    return nil, 'formatters are not disabled'
  end
  if config.lsp ~= false then
    return nil, 'LSP is not disabled'
  end
  if type(config.plugin) ~= 'table' or not vim.tbl_isempty(config.plugin) then
    return nil, 'configured plugins are not disabled'
  end
  if config.mcp ~= nil and (type(config.mcp) ~= 'table' or not vim.tbl_isempty(config.mcp)) then
    return nil, 'MCP servers are configured'
  end
  if not vim.deep_equal(config.tool_output, output_limit) then
    return nil, 'tool output limits differ from 32768 bytes and 10 lines'
  end
  if not vim.deep_equal(enabled_tools(config.tools), expected_enabled_tools) then
    return nil, 'resolved enabled tools differ from read, glob, grep, and stage_text'
  end
  for name, allowed in pairs(safe_tools) do
    if allowed == false and config.tools[name] == true then
      return nil, name .. ' is enabled'
    end
  end
  return true
end

local function validate_resolved_agent(agent, expected_name)
  if type(agent) ~= 'table' or agent.name ~= expected_name then
    return nil, 'runtime agent resolution does not match unique agent'
  end
  if agent.mode ~= 'primary' or (agent.disable ~= nil and agent.disable ~= false) then
    return nil, 'runtime primary agent is disabled or has wrong mode'
  end
  if not vim.deep_equal(enabled_tools(agent.tools), expected_enabled_tools) then
    return nil, 'runtime agent enabled tools differ from read, glob, grep, and stage_text'
  end
  return true
end

local function show_error(message)
  local lines = vim.split(message ~= '' and message or 'Unknown OpenCode failure', '\n', { plain = true })
  local buffer = vim.api.nvim_create_buf(false, true)
  vim.bo[buffer].buftype = 'nofile'
  vim.bo[buffer].bufhidden = 'wipe'
  vim.bo[buffer].swapfile = false
  vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  vim.bo[buffer].modifiable = false
  local width = math.max(20, math.min(vim.o.columns - 4, math.floor(vim.o.columns * 0.7)))
  local height = math.max(3, math.min(vim.o.lines - 4, #lines + 2))
  vim.api.nvim_open_win(buffer, true, {
    relative = 'editor',
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' AI edit error ',
    title_pos = 'center',
  })
end

local function cleanup_environment(job)
  local root = vim.fn.stdpath 'cache' .. '/nvim-ai-edit/session-cleanup/' .. random_id()
  private_directory(root .. '/config')
  private_directory(root .. '/home')
  local environment = vim.fn.environ()
  environment.XDG_CONFIG_HOME = root .. '/config'
  environment.OPENCODE_TEST_HOME = root .. '/home'
  environment.OPENCODE_CONFIG = nil
  environment.OPENCODE_CONFIG_DIR = nil
  environment.OPENCODE_CONFIG_CONTENT = vim.json.encode {
    share = 'disabled',
    snapshot = false,
    formatter = false,
    lsp = false,
    plugin = vim.json.decode '[]',
    tools = vim.json.decode '{}',
  }
  environment.OPENCODE_PURE = '1'
  environment.OPENCODE_DISABLE_DEFAULT_PLUGINS = nil
  environment.OPENCODE_DISABLE_PROJECT_CONFIG = '1'
  environment.OPENCODE_DISABLE_AUTOSHARE = '1'
  environment.NVIM_AI_EDIT_STAGE_ROOT = nil
  environment.NVIM_AI_EDIT_STAGE_TARGET = nil
  environment.NVIM_AI_EDIT_MAX_BYTES = nil
  environment.NVIM_AI_EDIT_CONTEXT = nil
  return environment, root
end

local function delete_session(job, session_id)
  if job.deleted_sessions[session_id] then
    return
  end
  job.deleted_sessions[session_id] = true
  local environment, cleanup_root = cleanup_environment(job)
  local finished = false
  local timer = uv.new_timer()
  local process
  local function close_timer()
    timer:stop()
    if not timer:is_closing() then
      timer:close()
    end
  end
  local ok
  ok, process = pcall(vim.system, { job.options.command, 'session', 'delete', session_id }, {
    cwd = job.project_root,
    env = environment,
    text = true,
  }, function(result)
    vim.schedule(function()
      vim.fn.delete(cleanup_root, 'rf')
      if finished then
        return
      end
      finished = true
      close_timer()
      if result.code ~= 0 then
        notify('could not delete OpenCode session ' .. session_id, vim.log.levels.WARN)
      end
    end)
  end)
  if not ok or not process then
    close_timer()
    vim.fn.delete(cleanup_root, 'rf')
    notify('could not start OpenCode session cleanup for ' .. session_id, vim.log.levels.WARN)
    return
  end
  timer:start(job.options.cleanup_timeout_ms, 0, function()
    vim.schedule(function()
      if finished then
        return
      end
      finished = true
      close_timer()
      pcall(process.kill, process, 15)
      local kill_timer = uv.new_timer()
      kill_timer:start(500, 0, function()
        pcall(process.kill, process, 9)
        kill_timer:stop()
        kill_timer:close()
      end)
      notify('OpenCode session cleanup timed out for ' .. session_id, vim.log.levels.WARN)
    end)
  end)
end

local function remember_session(job, value)
  if type(value) ~= 'table' then
    return
  end
  local session_id = value.sessionID or value.sessionId or value.session_id
  if type(session_id) == 'string' and session_id ~= '' then
    job.sessions[session_id] = true
    if job.done then
      delete_session(job, session_id)
    end
  end
  for _, nested in pairs(value) do
    if type(nested) == 'table' then
      remember_session(job, nested)
    end
  end
end

local function parse_event(job, event)
  remember_session(job, event)
  if event.type == 'error' then
    job.event_error = true
    table.insert(job.errors, type(event.error) == 'string' and event.error or vim.inspect(event.error or event))
  end
  local part = event.part
  if type(part) == 'table' and type(part.state) == 'table' then
    if part.state.status == 'error' then
      job.tool_error = true
      table.insert(job.errors, tostring(part.state.error or ('tool ' .. tostring(part.tool) .. ' failed')))
    end
    if part.tool == 'stage_text' and part.state.status == 'completed' and type(part.state.input) == 'table' and part.state.input.action == 'submit' then
      job.submit_count = job.submit_count + 1
    end
  end
end

local function consume_stdout(job, data, final)
  if data then
    job.stdout_buffer = job.stdout_buffer .. data
  end
  while true do
    local newline = job.stdout_buffer:find('\n', 1, true)
    if not newline then
      break
    end
    local line = job.stdout_buffer:sub(1, newline - 1)
    job.stdout_buffer = job.stdout_buffer:sub(newline + 1)
    if line:match '%S' then
      local ok, event = pcall(vim.json.decode, line)
      if ok then
        parse_event(job, event)
      else
        job.parse_error = true
        table.insert(job.errors, 'invalid JSON event: ' .. line)
      end
    end
  end
  if final and job.stdout_buffer:match '%S' then
    local line = job.stdout_buffer
    job.stdout_buffer = ''
    local ok, event = pcall(vim.json.decode, line)
    if ok then
      parse_event(job, event)
    else
      job.parse_error = true
      table.insert(job.errors, 'invalid JSON event: ' .. line)
    end
  end
end

local function validated_stage_result(job)
  local status = uv.fs_lstat(job.stage_target)
  if not status or status.type ~= 'file' then
    return nil, 'staging target is missing or not a regular file'
  end
  local resolved_root = uv.fs_realpath(job.stage_root)
  local resolved_target = uv.fs_realpath(job.stage_target)
  if not resolved_root or not resolved_target or resolved_target:sub(1, #resolved_root + 1) ~= resolved_root .. '/' then
    return nil, 'staging target escaped its private root'
  end
  local text, read_error = read_file(job.stage_target)
  if not text then
    return nil, 'cannot read staged result: ' .. tostring(read_error)
  end
  if #text > job.options.max_bytes then
    return nil, 'staged result exceeds configured size limit'
  end
  if not pcall(vim.str_utfindex, text) then
    return nil, 'staged result contains invalid UTF-8'
  end
  return text
end

local function split_result(text, strip_final_newline)
  if strip_final_newline and text:sub(-1) == '\n' then
    text = text:sub(1, -2)
  end
  if text == '' then
    return {}
  end
  return vim.split(text, '\n', { plain = true })
end

local function apply_result(job, text)
  local current, eligibility_error = eligible(job.buffer, job.options.max_bytes)
  if not current then
    return nil, eligibility_error
  end
  if current.path ~= job.path then
    return nil, 'target buffer now refers to another file'
  end
  if vim.api.nvim_buf_get_changedtick(job.buffer) ~= job.changedtick then
    return nil, 'target buffer changed while OpenCode was running'
  end
  if text == job.target_text then
    return 'noop'
  end

  if job.target.kind == 'whole' then
    vim.api.nvim_buf_set_lines(job.buffer, 0, -1, false, split_result(text, true))
    vim.bo[job.buffer].endofline = job.endofline
  elseif job.target.kind == 'line' then
    vim.api.nvim_buf_set_lines(job.buffer, job.target.start_row, job.target.end_row, false, split_result(text, false))
  else
    vim.api.nvim_buf_set_text(job.buffer, job.target.start_row, job.target.start_col, job.target.end_row, job.target.end_col, split_result(text, false))
  end
  return 'applied'
end

local function finish(job, outcome, result)
  if job.done then
    return
  end
  job.done = true
  if job.timer then
    job.timer:stop()
    if not job.timer:is_closing() then
      job.timer:close()
    end
  end
  if jobs[job.buffer] == job then
    jobs[job.buffer] = nil
  end
  for session_id in pairs(job.sessions) do
    delete_session(job, session_id)
  end

  if outcome == 'cancelled' then
    notify('cancelled', vim.log.levels.WARN)
  elseif outcome == 'timeout' then
    notify('timed out', vim.log.levels.ERROR)
  elseif outcome == 'error' then
    local details = result or table.concat(job.errors, '\n')
    local summary = details:match '([^\n]+)' or 'OpenCode failed'
    notify('OpenCode failed: ' .. summary, vim.log.levels.ERROR)
    show_error(details)
  elseif outcome == 'stale' then
    notify(result or 'target changed; staged result discarded', vim.log.levels.WARN)
  elseif outcome == 'noop' then
    notify 'no changes produced'
  elseif outcome == 'applied' then
    notify 'buffer changed; use u to revert'
  end
  cleanup(job)
end

local function stop_job(job, outcome)
  if job.done then
    return
  end
  if job.process then
    local process = job.process
    pcall(process.kill, process, 15)
    local kill_timer = uv.new_timer()
    kill_timer:start(500, 0, function()
      pcall(process.kill, process, 9)
      kill_timer:stop()
      kill_timer:close()
    end)
  end
  finish(job, outcome)
end

local function launch_run(job)
  local stdout_callback = function(error_message, data)
    vim.schedule(function()
      if error_message then
        table.insert(job.errors, tostring(error_message))
      end
      consume_stdout(job, data, false)
    end)
  end
  local stderr_callback = function(error_message, data)
    vim.schedule(function()
      if error_message then
        table.insert(job.errors, tostring(error_message))
      end
      if data then
        table.insert(job.stderr, data)
      end
    end)
  end

  local ok, process = pcall(vim.system, { job.options.command, 'run', '--agent', job.agent, '--format', 'json' }, {
    cwd = job.project_root,
    env = job.environment,
    text = true,
    stdin = job.instruction,
    stdout = stdout_callback,
    stderr = stderr_callback,
  }, function(system_result)
    vim.schedule(function()
      if job.done then
        return
      end
      consume_stdout(job, nil, true)
      if system_result.code ~= 0 then
        table.insert(job.errors, string.format('OpenCode exited with status %d', system_result.code))
      end
      local stderr = table.concat(job.stderr)
      if stderr:match '%S' then
        table.insert(job.errors, stderr)
      end
      if system_result.code ~= 0 or job.event_error or job.tool_error or job.parse_error then
        finish(job, 'error', table.concat(job.errors, '\n'))
        return
      end
      if job.submit_count ~= 1 then
        finish(job, 'error', string.format('expected exactly one successful stage_text submit, received %d', job.submit_count))
        return
      end
      local text, stage_error = validated_stage_result(job)
      if not text then
        finish(job, 'error', stage_error)
        return
      end
      local application, application_error = apply_result(job, text)
      if not application then
        finish(job, 'stale', application_error)
        return
      end
      finish(job, application)
    end)
  end)
  if not ok or not process then
    finish(job, 'error', 'could not start OpenCode: ' .. tostring(process))
    return
  end
  job.process = process
end

local function decode_debug_output(result, label)
  if result.code ~= 0 then
    return nil, label .. ' failed: ' .. tostring(result.stderr or '')
  end
  local ok, value = pcall(vim.json.decode, (result.stdout or ''):match '^%s*(.-)%s*$')
  if not ok then
    return nil, label .. ' returned invalid JSON: ' .. tostring(result.stdout)
  end
  return value
end

local function debug_environment(environment)
  local result = {}
  for name, value in pairs(environment) do
    table.insert(result, name .. '=' .. tostring(value))
  end
  return result
end

local function run_debug(job, arguments, label, callback, cwd, environment)
  job.debug_count = (job.debug_count or 0) + 1
  local prefix = job.stage_root .. '/debug-' .. job.debug_count
  local stdout_path = prefix .. '.json'
  local stderr_path = prefix .. '.stderr'
  local stdout_fd, stdout_error = uv.fs_open(stdout_path, 'w', tonumber('600', 8))
  if not stdout_fd then
    return nil, 'cannot open ' .. label .. ' output: ' .. tostring(stdout_error)
  end
  local stderr_fd, stderr_error = uv.fs_open(stderr_path, 'w', tonumber('600', 8))
  if not stderr_fd then
    uv.fs_close(stdout_fd)
    return nil, 'cannot open ' .. label .. ' errors: ' .. tostring(stderr_error)
  end

  local process
  local spawn_ok, spawned, spawn_error = pcall(uv.spawn, job.options.command, {
    args = arguments,
    cwd = cwd or job.project_root,
    env = debug_environment(environment or job.environment or vim.fn.environ()),
    stdio = { nil, stdout_fd, stderr_fd },
    hide = true,
  }, function(code, signal)
    if process and not process:is_closing() then
      process:close()
    end
    uv.fs_close(stdout_fd)
    uv.fs_close(stderr_fd)
    vim.schedule(function()
      local stdout, read_stdout_error = read_file(stdout_path)
      local stderr, read_stderr_error = read_file(stderr_path)
      callback {
        code = code,
        signal = signal,
        stdout = stdout or '',
        stderr = stderr or tostring(read_stdout_error or read_stderr_error or ''),
      }
    end)
  end)
  if not spawn_ok or not spawned then
    uv.fs_close(stdout_fd)
    uv.fs_close(stderr_fd)
    return nil, tostring(spawn_ok and spawn_error or spawned)
  end
  process = spawned
  return process
end

local function prepare_helper(job, callback)
  local info, info_error = helper_source()
  if not info then
    callback(nil, info_error)
    return
  end
  local verified = verify_helper_cache(info.cache, info.source)
  if verified then
    local sealed, seal_error = seal_helper_cache(info.root)
    callback(sealed and info.cache or nil, seal_error)
    return
  end

  local build, build_error = materialize_helper_build(info)
  if not build then
    callback(nil, build_error)
    return
  end
  job.helper_build = build.root
  local bootstrap_config = copy_table(job.config)
  bootstrap_config.model = 'opencode/big-pickle'
  local environment = isolated_environment(job, build.cache, bootstrap_config, 'bootstrap')
  local process, start_error = run_debug(job, { 'debug', 'agent', job.agent }, 'OpenCode helper bootstrap', function(result)
    if job.done then
      discard_helper_build(build.root)
      return
    end
    if result.code ~= 0 then
      discard_helper_build(build.root)
      job.helper_build = nil
      callback(nil, 'helper dependency bootstrap failed: ' .. tostring(result.stderr or ''))
      return
    end
    local valid, validation_error = verify_helper_cache(build.cache, info.source)
    if not valid then
      discard_helper_build(build.root)
      job.helper_build = nil
      callback(nil, validation_error)
      return
    end
    local sealed, seal_error = seal_helper_cache(build.root)
    if not sealed then
      discard_helper_build(build.root)
      job.helper_build = nil
      callback(nil, 'cannot seal trusted helper cache: ' .. tostring(seal_error))
      return
    end
    local published, publish_error = uv.fs_rename(build.root, info.root)
    if not published then
      discard_helper_build(build.root)
      local winner_valid, winner_error = verify_helper_cache(info.cache, info.source)
      if not winner_valid then
        job.helper_build = nil
        callback(nil, 'cannot publish trusted helper cache: ' .. tostring(publish_error or winner_error))
        return
      end
    end
    job.helper_build = nil
    callback(info.cache)
  end, job.project_root, environment)
  if not process then
    vim.fn.delete(build.root, 'rf')
    job.helper_build = nil
    callback(nil, 'could not start helper dependency bootstrap: ' .. tostring(start_error))
    return
  end
  job.process = process
end

local function preflight_agent(job)
  local process, start_error = run_debug(job, { 'debug', 'agent', job.agent }, 'OpenCode agent preflight', function(result)
    if job.done then
      return
    end
    local agent, decode_error = decode_debug_output(result, 'OpenCode agent preflight')
    if not agent then
      finish(job, 'error', decode_error)
      return
    end
    local safe, safety_error = validate_resolved_agent(agent, job.agent)
    if not safe then
      finish(job, 'error', 'unsafe OpenCode agent configuration: ' .. safety_error)
      return
    end
    launch_run(job)
  end)
  if not process then
    finish(job, 'error', 'could not start OpenCode agent preflight: ' .. tostring(start_error))
    return
  end
  job.process = process
end

local preflight_config

local provider_config_fields = { 'model', 'small_model', 'provider', 'enabled_providers', 'disabled_providers' }

local function preflight_global_config(job)
  local environment = global_config_environment(job)
  local process, start_error = run_debug(job, { 'debug', 'config' }, 'OpenCode global config resolution', function(result)
    if job.done then
      return
    end
    local config, decode_error = decode_debug_output(result, 'OpenCode global config resolution')
    if not config then
      finish(job, 'error', decode_error)
      return
    end
    local safe, safety_error = validate_resolved_config(config)
    if not safe then
      finish(job, 'error', 'unsafe OpenCode configuration: ' .. safety_error)
      return
    end
    if type(config.model) ~= 'string' or not config.model:match '^([^/]+)/' then
      finish(job, 'error', 'unsafe OpenCode configuration: resolved model/provider is unavailable')
      return
    end
    for _, field in ipairs(provider_config_fields) do
      if config[field] ~= nil then
        job.config[field] = copy_table(config[field])
      end
    end
    prepare_helper(job, function(cache, cache_error)
      if job.done then
        return
      end
      if not cache then
        finish(job, 'error', 'dependency bootstrap failed: ' .. tostring(cache_error))
        return
      end
      job.cache = cache
      job.environment = runtime_environment(job)
      preflight_config(job)
    end)
  end, job.project_root, environment)
  if not process then
    finish(job, 'error', 'could not start OpenCode global config resolution: ' .. tostring(start_error))
    return
  end
  job.process = process
end

local function preflight_version(job)
  local process, start_error = run_debug(job, { '--version' }, 'OpenCode version preflight', function(result)
    if job.done then
      return
    end
    if result.code ~= 0 then
      finish(job, 'error', 'OpenCode version preflight failed: ' .. tostring(result.stderr or ''))
      return
    end
    local version = (result.stdout or ''):match '^%s*(.-)%s*$'
    if version ~= opencode_version then
      finish(job, 'error', 'unsupported OpenCode version: expected ' .. opencode_version .. ', resolved ' .. tostring(version))
      return
    end
    preflight_global_config(job)
  end)
  if not process then
    finish(job, 'error', 'could not start OpenCode version preflight: ' .. tostring(start_error))
    return
  end
  job.process = process
end

preflight_config = function(job)
  local process, start_error = run_debug(job, { 'debug', 'config' }, 'OpenCode dependency/config preflight', function(result)
    if job.done then
      return
    end
    local config, decode_error = decode_debug_output(result, 'OpenCode dependency/config preflight')
    if not config then
      finish(job, 'error', decode_error)
      return
    end
    local safe, safety_error = validate_resolved_config(config)
    if not safe then
      finish(job, 'error', 'unsafe OpenCode configuration: ' .. safety_error)
      return
    end
    if type(config.model) ~= 'string' then
      finish(job, 'error', 'unsafe OpenCode configuration: resolved model/provider is unavailable')
      return
    end
    if not config.model:match '^([^/]+)/' then
      finish(job, 'error', 'unsafe OpenCode configuration: resolved model has no provider')
      return
    end
    preflight_agent(job)
  end)
  if not process then
    finish(job, 'error', 'could not start OpenCode config preflight: ' .. tostring(start_error))
    return
  end
  job.process = process
end

local function start_job(snapshot, instruction)
  local buffer = snapshot.buffer
  if jobs[buffer] then
    notify('an edit is already running for this buffer', vim.log.levels.WARN)
    return
  end
  local current, validation_error = eligible(buffer, options.max_bytes)
  if not current then
    notify(validation_error, vim.log.levels.WARN)
    return
  end
  if current.path ~= snapshot.path then
    notify('target buffer now refers to another file', vim.log.levels.WARN)
    return
  end
  if vim.api.nvim_buf_get_changedtick(buffer) ~= snapshot.changedtick or current.text ~= snapshot.text then
    notify('target buffer changed while prompt was open', vim.log.levels.WARN)
    return
  end

  local job = {
    buffer = buffer,
    path = snapshot.path,
    project_root = project_root(snapshot.path),
    full_text = snapshot.text,
    target_text = snapshot.target_text,
    target = snapshot.target,
    changedtick = snapshot.changedtick,
    endofline = snapshot.endofline,
    instruction = instruction,
    options = copy_table(options),
    agent = 'nvim-ai-edit-' .. random_id(),
    sessions = {},
    deleted_sessions = {},
    errors = {},
    stderr = {},
    stdout_buffer = '',
    submit_count = 0,
  }
  jobs[buffer] = job

  local staged, staging_error = create_staging(job)
  if not staged then
    finish(job, 'error', staging_error)
    return
  end
  job.config = restricted_config(job)
  job.timer = uv.new_timer()
  job.timer:start(job.options.timeout_ms, 0, function()
    vim.schedule(function()
      stop_job(job, 'timeout')
    end)
  end)
  notify 'running'
  preflight_version(job)
end

local function close_window(window)
  if vim.api.nvim_win_is_valid(window) then
    vim.api.nvim_win_close(window, true)
  end
end

local function open_prompt(snapshot)
  local buffer = snapshot.buffer
  local target = snapshot.target
  local root = project_root(snapshot.path)
  local relative_path = vim.fs.relpath(root, snapshot.path) or vim.fn.fnamemodify(snapshot.path, ':t')
  local title = ' AI edit: ' .. relative_path
  if target.label then
    title = title .. ' [' .. target.label .. ']'
  end
  title = title .. ' '

  local prompt = vim.api.nvim_create_buf(false, true)
  vim.bo[prompt].buftype = 'nofile'
  vim.bo[prompt].bufhidden = 'wipe'
  vim.bo[prompt].swapfile = false
  vim.bo[prompt].filetype = 'markdown'
  local width = math.max(20, math.min(vim.o.columns - 4, math.floor(vim.o.columns * options.width)))
  local height = math.max(3, math.min(vim.o.lines - 4, math.floor(vim.o.lines * options.height)))
  local window = vim.api.nvim_open_win(prompt, true, {
    relative = 'editor',
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = title,
    title_pos = 'center',
  })

  local function submit()
    if not vim.api.nvim_buf_is_valid(prompt) then
      return
    end
    local instruction = table.concat(vim.api.nvim_buf_get_lines(prompt, 0, -1, false), '\n')
    if not instruction:match '%S' then
      notify('instruction is required', vim.log.levels.WARN)
      return
    end
    close_window(window)
    start_job(snapshot, instruction)
  end

  local function newline(advance_codepoint)
    if not vim.api.nvim_win_is_valid(window) then
      return
    end
    local cursor = vim.api.nvim_win_get_cursor(window)
    local line = vim.api.nvim_buf_get_lines(prompt, cursor[1] - 1, cursor[1], false)[1]
    local column = math.min(#line, cursor[2])
    if advance_codepoint and column < #line then
      column = vim.str_byteindex(line, vim.str_utfindex(line, column) + 1)
    end
    vim.api.nvim_buf_set_text(prompt, cursor[1] - 1, column, cursor[1] - 1, column, { '', '' })
    vim.api.nvim_win_set_cursor(window, { cursor[1] + 1, 0 })
  end

  local map_options = { buffer = prompt, silent = true, nowait = true }
  vim.keymap.set({ 'n', 'i' }, '<CR>', submit, map_options)
  vim.keymap.set('n', '<C-j>', function()
    newline(true)
  end, map_options)
  vim.keymap.set('i', '<C-j>', function()
    newline(false)
  end, map_options)
  vim.keymap.set({ 'n', 'i' }, '<Esc>', function()
    close_window(window)
  end, map_options)
  vim.cmd 'startinsert'
end

local function invoke(mode)
  local buffer = vim.api.nvim_get_current_buf()
  if jobs[buffer] then
    notify('an edit is already running for this buffer', vim.log.levels.WARN)
    return
  end
  local snapshot, validation_error = eligible(buffer, options.max_bytes)
  if not snapshot then
    notify(validation_error, vim.log.levels.WARN)
    return
  end
  if vim.fn.executable(options.command) ~= 1 then
    notify('OpenCode executable not found: ' .. options.command, vim.log.levels.ERROR)
    return
  end
  local target = { kind = 'whole', label = nil }
  if mode == 'visual' then
    local visual_mode = vim.fn.mode(1):sub(1, 1)
    target, validation_error = capture_visual(buffer, visual_mode)
    if not target then
      notify(validation_error, vim.log.levels.WARN)
      return
    end
  end
  local target_text = target.kind == 'whole' and snapshot.text or selection_text(buffer, target)
  if #target_text > options.max_bytes then
    notify('selection size exceeds configured limit', vim.log.levels.WARN)
    return
  end
  snapshot.buffer = buffer
  snapshot.target = target
  snapshot.target_text = target_text
  snapshot.changedtick = vim.api.nvim_buf_get_changedtick(buffer)
  snapshot.endofline = vim.bo[buffer].endofline
  open_prompt(snapshot)
end

local function validate_options(overrides)
  local allowed = {
    keymap = true,
    command = true,
    timeout_ms = true,
    cleanup_timeout_ms = true,
    max_bytes = true,
    width = true,
    height = true,
  }
  for key in pairs(overrides) do
    if not allowed[key] then
      error('vichr.ai_edit: unknown option ' .. key)
    end
  end
  if type(overrides.keymap) ~= 'string' or overrides.keymap == '' then
    error 'vichr.ai_edit: keymap must be non-empty text'
  end
  if type(overrides.command) ~= 'string' or overrides.command == '' then
    error 'vichr.ai_edit: command must be non-empty text'
  end
  for _, key in ipairs { 'timeout_ms', 'cleanup_timeout_ms', 'max_bytes' } do
    if type(overrides[key]) ~= 'number' or overrides[key] <= 0 or overrides[key] % 1 ~= 0 then
      error('vichr.ai_edit: ' .. key .. ' must be a positive integer')
    end
  end
  for _, key in ipairs { 'width', 'height' } do
    if type(overrides[key]) ~= 'number' or overrides[key] <= 0 or overrides[key] > 1 then
      error('vichr.ai_edit: ' .. key .. ' must be greater than 0 and at most 1')
    end
  end
end

function M.cancel(buffer)
  buffer = buffer or vim.api.nvim_get_current_buf()
  local job = jobs[buffer]
  if not job then
    notify('no active edit for this buffer', vim.log.levels.WARN)
    return
  end
  stop_job(job, 'cancelled')
end

function M.setup(overrides)
  local configured = copy_table(options)
  for key, value in pairs(overrides or {}) do
    configured[key] = value
  end
  validate_options(configured)
  options = configured

  vim.keymap.set('n', options.keymap, function()
    invoke 'normal'
  end, { desc = 'AI edit buffer' })
  vim.keymap.set('x', options.keymap, function()
    invoke 'visual'
  end, { desc = 'AI edit selection' })
  vim.api.nvim_create_user_command('AIEditCancel', function()
    M.cancel()
  end, { desc = 'Cancel AI edit for current buffer', force = true })
end

return M

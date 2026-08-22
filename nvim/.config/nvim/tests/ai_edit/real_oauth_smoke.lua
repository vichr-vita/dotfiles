local project = assert(vim.env.AI_EDIT_REAL_PROJECT)
local command = assert(vim.env.AI_EDIT_REAL_OPENCODE)
local target = project .. '/src/target.ts'
local notifications = {}

vim.notify = function(message)
  table.insert(notifications, tostring(message))
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.keycode(keys), 'xt', false)
end

local function read_file(path)
  local file = assert(io.open(path, 'rb'))
  local value = file:read '*a'
  file:close()
  return value
end

local function prompt(buffer, instruction)
  assert(
    vim.wait(2000, function()
      return vim.api.nvim_get_current_buf() ~= buffer and vim.bo.buftype == 'nofile'
    end, 10),
    'real OAuth smoke prompt did not open'
  )
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { instruction })
  feed '<CR>'
end

local function wait_for_change(buffer, previous_notification_count)
  assert(
    vim.wait(190000, function()
      for index = previous_notification_count + 1, #notifications do
        local message = notifications[index]:lower()
        if message:match 'changed' or message:match 'failed' or message:match 'timed out' then
          return true
        end
      end
      return false
    end, 10),
    'installed OpenCode OAuth smoke did not finish'
  )
  assert(not notifications[#notifications]:lower():match 'failed', vim.inspect(notifications))
  vim.api.nvim_set_current_buf(buffer)
end

vim.cmd('silent edit ' .. vim.fn.fnameescape(target))
local buffer = vim.api.nvim_get_current_buf()
local before = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
local before_disk = read_file(target)
require('vichr.ai_edit').setup {
  keymap = '<F8>',
  command = command,
  timeout_ms = 180000,
  cleanup_timeout_ms = 5000,
}

local notification_count = #notifications
feed '<F8>'
prompt(buffer, 'Use stage_text to replace exact text REAL_PROJECT_TARGET with OAUTH_WHOLE_RESULT. Preserve everything else and submit exactly once.')
wait_for_change(buffer, notification_count)
local result = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
assert(result[1] == 'OAUTH_WHOLE_RESULT', 'whole-buffer OAuth smoke produced unexpected result: ' .. vim.inspect(notifications))
assert(vim.bo[buffer].modified, 'whole-buffer OAuth result was saved automatically')
assert(read_file(target) == before_disk, 'whole-buffer OAuth result changed disk before manual save')
vim.cmd 'undo'
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), before), 'whole-buffer OAuth undo did not restore target')

local utf8_line = 'prefix café 中央 suffix'
local utf8_before = { utf8_line, 'untouched line' }
vim.api.nvim_buf_set_lines(buffer, 0, -1, false, utf8_before)
vim.cmd 'write'
local utf8_disk = read_file(target)
local selected = 'café 中央'
local start_col = assert(utf8_line:find(selected, 1, true)) - 1
local end_col = start_col + #selected - #'央'
vim.api.nvim_win_set_cursor(0, { 1, start_col })
feed 'v'
vim.api.nvim_win_set_cursor(0, { 1, end_col })
notification_count = #notifications
feed '<F8>'
prompt(buffer, 'Replace the entire staged UTF-8 selection with UTF8_SELECTION_RESULT using stage_text. Submit exactly once.')
wait_for_change(buffer, notification_count)
result = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
assert(result[1] == 'prefix UTF8_SELECTION_RESULT suffix', 'UTF-8 selection OAuth smoke escaped or missed selection: ' .. vim.inspect(result))
assert(result[2] == 'untouched line', 'UTF-8 selection OAuth smoke changed unselected line')
assert(vim.bo[buffer].modified, 'UTF-8 selection OAuth result was saved automatically')
assert(read_file(target) == utf8_disk, 'UTF-8 selection OAuth result changed disk before manual save')
vim.cmd 'write'
assert(read_file(target):match '^prefix UTF8_SELECTION_RESULT suffix\n', 'manual save did not persist reviewed OAuth result')
vim.cmd 'undo'
assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buffer, 0, -1, false), utf8_before), 'UTF-8 selection OAuth undo did not restore target')

vim.api.nvim_buf_set_lines(buffer, 0, -1, false, before)
vim.bo[buffer].endofline = before_disk:sub(-1) == '\n'
vim.cmd 'write'
assert(read_file(target) == before_disk, 'OAuth smoke did not restore fixture bytes')
vim.wait(6000, function()
  return false
end, 10)
for _, message in ipairs(notifications) do
  assert(not message:lower():match 'could not delete', 'automatic OAuth session cleanup failed: ' .. message)
  assert(not message:lower():match 'cleanup timed out', 'automatic OAuth session cleanup timed out: ' .. message)
end
print 'installed OpenCode whole-buffer and UTF-8 selection OAuth smoke passed'

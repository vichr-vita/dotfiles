local capabilities = require("custom.config.cmp_config")
local on_attach = require("custom.config.lsp_config")

-- local rt = require("rust-tools")
-- local on_attach = function(_, bufnr)
--   -- Hover actions
--   vim.keymap.set("n", "<Leader>k", rt.hover_actions.hover_actions, { buffer = bufnr })
--   -- Code action groups
--   vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, { buffer = bufnr })
-- end

local options = {
  server = {
    on_attach = on_attach,
    capabilities = capabilities
  }
}

return options

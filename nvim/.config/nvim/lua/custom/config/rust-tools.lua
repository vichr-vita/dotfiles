local capabilities = require("custom.config.cmp_config")
local on_attach = require("custom.config.lsp_config")

local options = {
  server = {
    on_attach = on_attach,
    capabilities = capabilities
  }
}

return options

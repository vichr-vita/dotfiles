vim.opt.expandtab = false
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2

require('cmp-graphql').setup {
  schema_path = 'graphql.schema.json',
}

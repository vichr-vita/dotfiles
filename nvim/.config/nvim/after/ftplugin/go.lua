vim.opt.expandtab = false
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4


vim.keymap.set(
	"n",
	"<leader>ee",
	"oif err != nil {<CR>}<Esc>Oreturn err<Esc>"
)

vim.opt.expandtab = false
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4


-- vim.keymap.set(
-- 	"n",
-- 	"<leader>ee",
-- 	"oif err != nil {<CR>}<Esc>Oreturn err<Esc>"
-- )

vim.keymap.set(
	"n",
	"<leader>ee",
	":GoIfErr<CR>",
	{ noremap = true, silent = true }
)

vim.keymap.set(
	"n",
	"<leader>tjs",
	":GoTagAdd json -transform snakecase<CR>",
	{ noremap = true, silent = true }
)

vim.keymap.set(
	"n",
	"<leader>tjc",
	":GoTagAdd json -transform camelcase<CR>",
	{ noremap = true, silent = true }
)


vim.keymap.set(
	"n",
	"<leader>ty",
	":GoTagAdd yaml<CR>",
	{ noremap = true, silent = true }
)

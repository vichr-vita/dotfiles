local bufnr = vim.api.nvim_get_current_buf()


local nmap = function(keys, func, desc)
	if desc then
		desc = 'RustLsp: ' .. desc
	end

	vim.keymap.set('n', keys, func, { buffer = bufnr, desc = desc })
end

nmap('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
vim.keymap.set(
	"n",
	"<leader>ca",
	function()
		vim.cmd.RustLsp('codeAction') -- supports rust-analyzer's grouping
		-- or vim.lsp.buf.codeAction() if you don't want grouping.
	end,
	{ silent = true, buffer = bufnr, desc = '(Rust) [C]ode [A]ction' }
)

vim.lsp.inlay_hint.enable(true)


nmap('gd', vim.lsp.buf.definition, '[G]oto [D]efinition')
nmap('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
nmap('gI', vim.lsp.buf.implementation, '[G]oto [I]mplementation')
nmap('<leader>D', vim.lsp.buf.type_definition, 'Type [D]efinition')
nmap('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
nmap('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')

-- See `:help K` for why this keymap
nmap('K', vim.lsp.buf.hover, 'Hover Documentation')
nmap('<C-k>', vim.lsp.buf.signature_help, 'Signature Documentation')

-- Lesser used LSP functionality
nmap('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')
nmap('<leader>wa', vim.lsp.buf.add_workspace_folder, '[W]orkspace [A]dd Folder')
nmap('<leader>wr', vim.lsp.buf.remove_workspace_folder, '[W]orkspace [R]emove Folder')
nmap('<leader>wl', function()
	print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
end, '[W]orkspace [L]ist Folders')

-- Create a command `:Format` local to the LSP buffer
vim.api.nvim_buf_create_user_command(bufnr, 'Format', function(_)
	vim.lsp.buf.format()
end, { desc = 'Format current buffer with LSP' })

vim.api.nvim_set_keymap('n', '<leader>fm', ':Format<CR>', { noremap = true, silent = true })


-- vim.lsp.inlay_hint.enable(bufnr, true)

-- rust specific TODO: this is not needed for other languages, think about rewriting it so it's executed contitionally
-- Hover actions
-- local rt = require("rust-tools")
--
-- Code action groups
-- vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, { buffer = bufnr })

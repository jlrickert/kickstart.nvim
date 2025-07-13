-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Clear highlights on search when pressing <Esc> in normal mode
--  See `:help hlsearch`
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- [[ Diagnostic keymaps ]]
vim.keymap.set(
	'n',
	'<leader>q',
	vim.diagnostic.setloclist,
	{ desc = 'Open diagnostic [Q]uickfix list' }
)

vim.keymap.set('n', 'gl', function()
	vim.diagnostic.open_float({ border = 'rounded' })
end, { desc = 'Show diagnostic details in float' })

-- [[ Spelling keymaps ]]
vim.keymap.set('n', '<leader>ss', function()
	local builtin = require('telescope.builtin')
	local theme = require('telescope.themes')

	-- opts include:
	builtin.spell_suggest(
		theme.get_dropdown({ preview = false, winblend = 10 })
	)
end, { desc = 'Spell [S]suggestion [S]earch' })

-- [[ File explorer keymaps ]]
vim.keymap.set('n', '<leader>e', function()
	require('neo-tree.command').execute({ toggle = true, dir = vim.fn.getcwd() })
end, { desc = '[E]xplore files' })

-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
-- for people to discover. Otherwise, you normally need to press <C-\><C-n>, which
-- is not what someone will guess without a bit more experience.
--
-- NOTE: This won't work in all terminal emulators/tmux/etc. Try your own mapping
-- or just use <C-\><C-n> to exit terminal mode
vim.keymap.set(
	't',
	'<Esc><Esc>',
	'<C-\\><C-n>',
	{ desc = 'Exit terminal mode' }
)

-- TIP: Disable arrow keys in normal mode
-- vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
-- vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
-- vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
-- vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Keybinds to make split navigation easier.
--  Use CTRL+<hjkl> to switch between windows
--
--  See `:help wincmd` for a list of all window commands
vim.keymap.set(
	'n',
	'<C-h>',
	'<C-w><C-h>',
	{ desc = 'Move focus to the left window' }
)
vim.keymap.set(
	'n',
	'<C-l>',
	'<C-w><C-l>',
	{ desc = 'Move focus to the right window' }
)
vim.keymap.set(
	'n',
	'<C-j>',
	'<C-w><C-j>',
	{ desc = 'Move focus to the lower window' }
)
vim.keymap.set(
	'n',
	'<C-k>',
	'<C-w><C-k>',
	{ desc = 'Move focus to the upper window' }
)

-- [[ Window keymaps ]]
-- Set <leader>w as the prefix for window commands
vim.keymap.set('n', '<leader>w', '<C-w>', { desc = 'Window commands prefix' })

-- NOTE: Some terminals have colliding keymaps or are not able to send distinct keycodes
-- vim.keymap.set("n", "<C-S-h>", "<C-w>H", { desc = "Move window to the left" })
-- vim.keymap.set("n", "<C-S-l>", "<C-w>L", { desc = "Move window to the right" })
-- vim.keymap.set("n", "<C-S-j>", "<C-w>J", { desc = "Move window to the lower" })
-- vim.keymap.set("n", "<C-S-k>", "<C-w>K", { desc = "Move window to the upper" })

-- Save file with sudo
vim.keymap.set('c', 'w!!', function()
	local cmd = 'w !sudo tee % >/dev/null'
	local keys = vim.api.nvim_replace_termcodes(cmd, true, false, true)
	vim.api.nvim_feedkeys(keys, 'n', false)
end, { noremap = false, silent = true, desc = 'Save file with sudo' })

-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
	desc = 'Highlight when yanking (copying) text',
	group = vim.api.nvim_create_augroup(
		'kickstart-highlight-yank',
		{ clear = true }
	),
	callback = function()
		vim.hl.on_yank()
	end,
})

-- vim: ts=4 sts=4 sw=4 et

return {
	{
		'nvim-treesitter/nvim-treesitter-textobjects',
		branch = 'main',
		dependencies = { 'nvim-treesitter/nvim-treesitter' },
		config = function()
			require('nvim-treesitter-textobjects').setup({
				select = {
					lookahead = true,
					selection_modes = {
						['@parameter.outer'] = 'v',
						['@function.outer'] = 'V',
						['@class.outer'] = '<c-v>',
					},
					include_surrounding_whitespace = true,
				},
				move = {
					set_jumps = true,
				},
			})

			-- Select keymaps
			local ts_select =
				require('nvim-treesitter-textobjects.select')
			vim.keymap.set({ 'x', 'o' }, 'af', function()
				ts_select.select_textobject(
					'@function.outer',
					'textobjects'
				)
			end, { desc = 'Select outer function' })
			vim.keymap.set({ 'x', 'o' }, 'if', function()
				ts_select.select_textobject(
					'@function.inner',
					'textobjects'
				)
			end, { desc = 'Select inner function' })
			vim.keymap.set({ 'x', 'o' }, 'ac', function()
				ts_select.select_textobject(
					'@class.outer',
					'textobjects'
				)
			end, { desc = 'Select outer class' })
			vim.keymap.set({ 'x', 'o' }, 'ic', function()
				ts_select.select_textobject(
					'@class.inner',
					'textobjects'
				)
			end, { desc = 'Select inner class' })
			vim.keymap.set({ 'x', 'o' }, 'as', function()
				ts_select.select_textobject('@local.scope', 'locals')
			end, { desc = 'Select language scope' })

			-- Move keymaps
			local move = require('nvim-treesitter-textobjects.move')
			vim.keymap.set({ 'n', 'x', 'o' }, ']f', function()
				move.goto_next_start('@function.outer', 'textobjects')
			end, { desc = 'Next function start' })
			vim.keymap.set({ 'n', 'x', 'o' }, ']F', function()
				move.goto_next_end('@function.outer', 'textobjects')
			end, { desc = 'Next function end' })
			vim.keymap.set({ 'n', 'x', 'o' }, ']c', function()
				move.goto_next_start('@class.outer', 'textobjects')
			end, { desc = 'Next class start' })
			vim.keymap.set({ 'n', 'x', 'o' }, ']C', function()
				move.goto_next_end('@class.outer', 'textobjects')
			end, { desc = 'Next class end' })
			vim.keymap.set({ 'n', 'x', 'o' }, ']a', function()
				move.goto_next_start(
					'@parameter.inner',
					'textobjects'
				)
			end, { desc = 'Next parameter' })
			vim.keymap.set({ 'n', 'x', 'o' }, ']A', function()
				move.goto_next_end('@parameter.inner', 'textobjects')
			end, { desc = 'Next parameter end' })
			vim.keymap.set({ 'n', 'x', 'o' }, '[f', function()
				move.goto_previous_start(
					'@function.outer',
					'textobjects'
				)
			end, { desc = 'Previous function start' })
			vim.keymap.set({ 'n', 'x', 'o' }, '[F', function()
				move.goto_previous_end(
					'@function.outer',
					'textobjects'
				)
			end, { desc = 'Previous function end' })
			vim.keymap.set({ 'n', 'x', 'o' }, '[c', function()
				move.goto_previous_start(
					'@class.outer',
					'textobjects'
				)
			end, { desc = 'Previous class start' })
			vim.keymap.set({ 'n', 'x', 'o' }, '[C', function()
				move.goto_previous_end(
					'@class.outer',
					'textobjects'
				)
			end, { desc = 'Previous class end' })
			vim.keymap.set({ 'n', 'x', 'o' }, '[a', function()
				move.goto_previous_start(
					'@parameter.inner',
					'textobjects'
				)
			end, { desc = 'Previous parameter' })
			vim.keymap.set({ 'n', 'x', 'o' }, '[A', function()
				move.goto_previous_end(
					'@parameter.inner',
					'textobjects'
				)
			end, { desc = 'Previous parameter end' })
		end,
	},
}

-- vim: ts=4 sts=4 sw=4 et

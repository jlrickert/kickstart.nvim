-- Adds colors to hex values in things like css
-- https://github.com/catgoose/nvim-colorizer.lua
return {
	{
		'catgoose/nvim-colorizer.lua',
		config = function()
			require('colorizer').setup({
				filetypes = {
					'css',
					'scss',
					'javascript',
					'typescript',
					'typescriptreact',
					'python',
					'svelte',
					'lua',
					'go',
					html = { mode = 'foreground' },
				},
			})
		end,
	},
}

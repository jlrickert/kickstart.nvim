-- highlight hovered over words
return {
	{
		'RRethy/vim-illuminate',
		lazy = true,
		config = function()
			require('illuminate').configure({
				under_cursor = false,
				filetypes_denylist = {
					'DressingSelect',
					'Outline',
					'TelescopePrompt',
					'alpha',
					'harpoon',
					'toggleterm',
					'neo-tree',
					'Spectre',
				},
			})
		end,
	},
}

return {
	{
		'rebelot/kanagawa.nvim',
		lazy = false,
		priority = 1000,
		config = function()
			local appearance = require('custom.appearance')

			local function apply_kanagawa()
				require('kanagawa').setup({
					--background = { dark = 'dragon', light = 'lotus' },
					background = { dark = 'wave', light = 'lotus' },
					commentStyle = { italic = false },
					keywordStyle = { italic = false },
				})
				vim.cmd.colorscheme('kanagawa')
			end

			-- Initial paint based on current OS appearance.
			vim.o.background = appearance.current() or 'dark'
			apply_kanagawa()

			-- Re-apply on OS appearance change. Augroup with clear=true
			-- prevents duplicate handlers across :Lazy reload.
			vim.api.nvim_create_autocmd('User', {
				group = vim.api.nvim_create_augroup(
					'KanagawaAppearanceHandler',
					{ clear = true }
				),
				pattern = 'OSAppearanceChanged',
				callback = function(args)
					local mode = args.data and args.data.mode
					if mode and mode ~= vim.o.background then
						vim.o.background = mode
						apply_kanagawa()
					end
				end,
			})

			-- Idempotent: safe to call from any/every theme plugin.
			appearance.setup()
		end,
	},
}
-- vim: ts=4 sts=4 sw=4 et

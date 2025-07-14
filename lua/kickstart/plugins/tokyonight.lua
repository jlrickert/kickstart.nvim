return {
	{ -- You can easily change to a different colorscheme.
		-- Change the name of the colorscheme plugin below, and then
		-- change the command in the config to whatever the name of that colorscheme is.
		--
		-- If you want to see what colorschemes are already installed, you can use `:Telescope colorscheme`.
		'folke/tokyonight.nvim',
		priority = 1000, -- Make sure to load this before all the other start plugins.
		config = function()
			---@diagnostic disable-next-line: missing-fields
			require('tokyonight').setup({
				styles = {
					comments = { italic = false }, -- Disable italics in comments
				},
			})

			-- Load the colorscheme here.
			-- Like many other themes, this one has different styles, and you could load
			-- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
			local is_dark_mode = false
			if vim.fn.has('mac') == 1 then
				-- On macOS, 'defaults read -g AppleInterfaceStyle' returns
				-- 'Dark' if dark mode is enabled, and an error/empty string if
				-- light mode is enabled.
				local result = vim.fn.system(
					'defaults read -g AppleInterfaceStyle 2>/dev/null'
				)
				if result:find('Dark') then
					is_dark_mode = true
				end
			end

			if is_dark_mode then
				vim.cmd.colorscheme('tokyonight-night')
			else
				vim.cmd.colorscheme('tokyonight-day')
			end
		end,
	},
}
-- vim: ts=4 sts=4 sw=4 et

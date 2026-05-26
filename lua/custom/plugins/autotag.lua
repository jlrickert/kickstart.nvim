---@type LazyPluginSpec
return {
	'windwp/nvim-ts-autotag',
	---@type nvim-ts-autotag.Opts
	opts = {
		-- Defaults
		enable_close = true, -- Auto close tags
		enable_rename = true, -- Auto rename pairs of tags
		enable_close_on_slash = false, -- Auto close on trailing </
	},
	lazy = false,
	config = function()
		require('nvim-ts-autotag').setup({})
	end,
}

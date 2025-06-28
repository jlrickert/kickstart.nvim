return {
	{ -- Autoformat
		'stevearc/conform.nvim',
		event = { 'BufWritePre' },
		cmd = { 'ConformInfo' },
		keys = {
			{
				'<leader>f',
				function()
					require('conform').format({ async = true, lsp_format = 'fallback' })
				end,
				mode = '',
				desc = '[F]ormat buffer',
			},
		},
		opts = {
			notify_on_error = false,
			format_on_save = function(bufnr)
				-- Only enable format-on-save for explicitly defined filetypes.
				-- If the current buffer's filetype is 'go', specific
				-- formatting options are returned.
				local enabled_filetypes = { go = true }
				if enabled_filetypes[vim.bo[bufnr].filetype] then
					return {
						timeout_ms = 500,
						lsp_format = 'fallback',
					}
				end

				return nil

				-- -- Disable "format_on_save lsp_fallback" for languages that don't
				-- -- have a well standardized coding style. You can add additional
				-- -- languages here or re-enable it for the disabled ones.
				-- local disable_filetypes = { c = true, cpp = true, php = true }
				-- if disable_filetypes[vim.bo[bufnr].filetype] then
				-- 	return nil
				-- else
				-- 	return {
				-- 		timeout_ms = 500,
				-- 		lsp_format = 'fallback',
				-- 	}
				-- end
			end,
			lang_to_ft = {
				bash = 'sh',
				zsh = 'sh',
			},
			formatters_by_ft = {
				lua = { 'stylua' },
				go = { 'goimports', 'gofmt' },
				php = { 'pretty-php' },
				bash = { 'shfmt' },
				zsh = { 'shfmt' },
				python = function(bufnr)
					if require('conform').get_formatter_info('ruff_format', bufnr).available then
						return { 'ruff_format' }
					else
						return { 'isort', 'black' }
					end
				end,
				-- Conform can also run multiple formatters sequentially
				--
				-- You can use 'stop_after_first' to run the first available formatter from the list
				javascript = { 'prettierd', 'prettier', stop_after_first = true },
				typescript = { 'prettierd', 'prettier', stop_after_first = true },
				html = { 'prettierd', 'prettier', stop_after_first = true },
				css = { 'prettierd', 'prettier', stop_after_first = true },
				markdown = { 'prettierd', 'prettier', stop_after_first = true },
				rust = { 'rustfmt', lsp_format = 'fallback' },
                perl = { 'perltidy' },
				js = { 'jq' },
				yaml = { 'yq' },
                sql = { 'sleek' },
				['*'] = { 'codespell' },
			},
		},
	},
}
-- vim: ts=4 sts=4 sw=4 et

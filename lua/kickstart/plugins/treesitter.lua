return {
	{ -- Parser management and treesitter setup
		'nvim-treesitter/nvim-treesitter',
		branch = 'main',
		build = ':TSUpdate',
		lazy = false,
		config = function()
			require('nvim-treesitter').install({
				'bash',
				'c',
				'css',
				'csv',
				'diff',
				'dockerfile',
				'editorconfig',
				'fish',
				'git_config',
				'git_rebase',
				'gitattributes',
				'gitcommit',
				'gitignore',
				'go',
				'graphql',
				'html',
				'javascript',
				'jq',
				'lua',
				'luadoc',
				'markdown',
				'markdown_inline',
				'mermaid',
				'passwd',
				'perl',
				'php',
				'phpdoc',
				'printf',
				'query',
				'rust',
				'tsv',
				'typescript',
				'vim',
				'vimdoc',
				'superhtml',
			})

			-- Enable treesitter highlighting and indentation for all filetypes
			vim.api.nvim_create_autocmd('FileType', {
				group = vim.api.nvim_create_augroup(
					'treesitter-setup',
					{ clear = true }
				),
				callback = function(args)
					pcall(vim.treesitter.start, args.buf)
					vim.bo[args.buf].indentexpr =
						"v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})

			-- Incremental selection using treesitter nodes
			local sel_node = nil

			local function ts_select(node)
				if not node then
					return
				end
				sel_node = node
				local sr, sc, er, ec = node:range()
				local end_lnum, end_col
				if ec > 0 then
					end_lnum = er + 1
					end_col = ec - 1
				elseif er > 0 then
					end_lnum = er
					local line =
						vim.api.nvim_buf_get_lines(0, er - 1, er, true)[1]
							or ''
					end_col = math.max(0, #line - 1)
				else
					end_lnum = 1
					end_col = 0
				end

				local mode = vim.fn.mode()
				if mode:match('[vV\22]') then
					vim.cmd([[execute "normal! \<Esc>"]])
				end
				vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
				vim.cmd('normal! v')
				vim.api.nvim_win_set_cursor(0, { end_lnum, end_col })
			end

			vim.keymap.set('n', 'gnn', function()
				ts_select(vim.treesitter.get_node())
			end, { desc = 'Init treesitter selection' })

			vim.keymap.set('x', 'grn', function()
				if sel_node and sel_node:parent() then
					ts_select(sel_node:parent())
				end
			end, { desc = 'Expand treesitter selection' })

			vim.keymap.set('x', 'grm', function()
				if sel_node then
					local child = sel_node:named_child(0)
					if child then
						ts_select(child)
					end
				end
			end, { desc = 'Shrink treesitter selection' })

			vim.keymap.set('x', 'grc', function()
				if sel_node then
					local node = sel_node
					while node:parent() do
						node = node:parent()
					end
					ts_select(node)
				end
			end, { desc = 'Select enclosing scope' })
		end,
	},
}

-- vim: ts=4 sts=4 sw=4 et

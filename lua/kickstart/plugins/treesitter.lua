return {
	{ -- Highlight, edit, and navigate code
		'nvim-treesitter/nvim-treesitter',
		build = ':TSUpdate',
		main = 'nvim-treesitter.configs', -- Sets main module to use for opts
		-- [[ Configure Treesitter ]] See `:help nvim-treesitter`
		lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
		cmd = { 'TSUpdate', 'TSInstall', 'TSBufEnable', 'TSModuleInfo' },
		init = function(plugin)
			-- PERF: add nvim-treesitter queries to the rtp and it's custom query predicates early
			-- This is needed because a bunch of plugins no longer
			-- `require("nvim-treesitter")`, which no longer trigger the
			-- **nvim-treesitter** module to be loaded in time. Luckily, the
			-- only things that those plugins need are the custom queries,
			-- which we make available during startup.
			require('lazy.core.loader').add_to_rtp(plugin)
			require('nvim-treesitter.query_predicates')
		end,
		---@type TSConfig
		---@diagnostic disable-next-line: missing-fields
		opts = {
			ensure_installed = {
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
			},
			-- Autoinstall languages that are not installed
			auto_install = true,
			highlight = {
				enable = true,
				-- Some languages depend on vim's regex highlighting system (such as Ruby) for indent rules.
				--  If you are experiencing weird indenting issues, add the language to
				--  the list of additional_vim_regex_highlighting and disabled languages for indent.
				additional_vim_regex_highlighting = { 'ruby' },
			},
			indent = { enable = true, disable = { 'ruby' } },
			textobjects = {
				select = {
					enable = true,

					-- Automatically jump forward to textobj, similar to targets.vim
					lookahead = true,

					keymaps = {
						-- You can use the capture groups defined in textobjects.scm
						['af'] = '@function.outer',
						['if'] = '@function.inner',
						['ac'] = '@class.outer',
						-- You can optionally set descriptions to the mappings (used in the desc parameter of
						-- nvim_buf_set_keymap) which plugins like which-key display
						['ic'] = {
							query = '@class.inner',
							desc = 'Select inner part of a class region',
						},
						-- You can also use captures from other query groups like `locals.scm`
						['as'] = {
							query = '@local.scope',
							query_group = 'locals',
							desc = 'Select language scope',
						},
					},
					-- You can choose the select mode (default is charwise 'v')
					--
					-- Can also be a function which gets passed a table with the keys
					-- * query_string: eg '@function.inner'
					-- * method: eg 'v' or 'o'
					-- and should return the mode ('v', 'V', or '<c-v>') or a table
					-- mapping query_strings to modes.
					selection_modes = {
						['@parameter.outer'] = 'v', -- charwise
						['@function.outer'] = 'V', -- linewise
						['@class.outer'] = '<c-v>', -- blockwise
					},
					-- If you set this to `true` (default is `false`) then any textobject is
					-- extended to include preceding or succeeding whitespace. Succeeding
					-- whitespace has priority in order to act similarly to eg the built-in
					-- `ap`.
					--
					-- Can also be a function which gets passed a table with the keys
					-- * query_string: eg '@function.inner'
					-- * selection_mode: eg 'v'
					-- and should return true or false
					include_surrounding_whitespace = true,
				},
				move = {
					enable = true,
					goto_next_start = {
						[']f'] = '@function.outer',
						[']c'] = '@class.outer',
						[']a'] = '@parameter.inner',
					},
					goto_next_end = {
						[']F'] = '@function.outer',
						[']C'] = '@class.outer',
						[']A'] = '@parameter.inner',
					},
					goto_previous_start = {
						['[f'] = '@function.outer',
						['[c'] = '@class.outer',
						['[a'] = '@parameter.inner',
					},
					goto_previous_end = {
						['[F'] = '@function.outer',
						['[C'] = '@class.outer',
						['[A'] = '@parameter.inner',
					},
				},
			},
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = 'gnn',
					node_incremental = 'grn',
					scope_incremental = 'grc',
					node_decremental = 'grm',
				},
			},
		},

		-- There are additional nvim-treesitter modules that you can use to interact
		-- with nvim-treesitter. You should go explore a few and see what interests you:
		--
		--    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
		--    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
		--    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
	},
}

-- vim: ts=4 sts=4 sw=4 et

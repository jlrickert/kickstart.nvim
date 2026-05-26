-- Ensure Lua files use real tab characters (not spaces) and have sensible tab widths.
vim.opt_local.expandtab = false
vim.opt_local.tabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.softtabstop = 0
vim.opt_local.smartindent = true

-- Note: if pressing Tab in Insert mode still doesn't insert a tab character,
-- it's likely an Insert-mode mapping from a completion/snippet plugin (e.g. blink.cmp, luasnip).
-- In Neovim run:
--   :verbose imap <Tab>
-- to see what is mapped and where it was set. If a plugin is mapping Tab, change or disable that mapping
-- instead of elying only on expandtab.

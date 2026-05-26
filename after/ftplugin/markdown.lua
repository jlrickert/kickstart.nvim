-- Enable sensible defaults for Markdown files.
--
-- Turn on spell checking by default for Markdown and set a couple of niceties.

-- Enable spell checking
vim.opt_local.spell = true
-- Set spell language (adjust to your preference, e.g. "en_gb")
vim.opt_local.spelllang = { 'en_us' }

-- Make reading/wrapping Markdown nicer
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true

-- Comfortable textwidth for prose
local prose_textwidth = 80
vim.opt_local.textwidth = prose_textwidth
vim.opt_local.colorcolumn = '81'

-- End of markdown ftplugin settings.

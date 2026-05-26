-- Generic OS appearance watcher.
--
-- Fires a `User OSAppearanceChanged` autocmd whenever the OS theme flips
-- between dark and light. `args.data.mode` is `'dark'` or `'light'`.
--
-- Listeners (e.g. theme plugins) register their own autocmd:
--
--     vim.api.nvim_create_autocmd('User', {
--         pattern = 'OSAppearanceChanged',
--         callback = function(args)
--             vim.o.background = args.data.mode
--             -- ... reapply your theme ...
--         end,
--     })
--
-- Idempotent: setup() may be called from multiple theme configs; only the
-- first call starts a timer.

local M = {}

local function detect_macos_appearance()
	if vim.fn.has('mac') == 0 then
		return nil
	end
	local out = vim.fn.system('defaults read -g AppleInterfaceStyle 2>/dev/null')
	if type(out) ~= 'string' then
		return nil
	end
	if out:find('Dark') then
		return 'dark'
	end
	if out == '' then
		return 'light'
	end
	return nil
end

-- Returns 'dark', 'light', or nil (unknown / non-mac).
function M.current()
	return detect_macos_appearance()
end

local started = false
local timer = nil

-- Starts the appearance watcher. opts.interval (ms, default 4000)
-- controls polling cadence. No-op on non-macOS or when already started.
function M.setup(opts)
	if started then
		return
	end
	if vim.fn.has('mac') == 0 then
		return
	end

	opts = opts or {}
	local interval = opts.interval or 4000

	local current = detect_macos_appearance()
	timer = vim.uv.new_timer()
	if not timer then
		return
	end

	-- libuv timer callbacks run in a "fast" context; vim.schedule_wrap
	-- defers the body to the main loop where editor APIs are legal.
	timer:start(
		interval,
		interval,
		vim.schedule_wrap(function()
			local mode = detect_macos_appearance()
			if mode == nil or mode == current then
				return
			end
			current = mode
			vim.api.nvim_exec_autocmds('User', {
				pattern = 'OSAppearanceChanged',
				data = { mode = mode },
			})
		end)
	)

	vim.api.nvim_create_autocmd('VimLeavePre', {
		group = vim.api.nvim_create_augroup(
			'CustomAppearanceWatcher',
			{ clear = true }
		),
		callback = function()
			if timer and not timer:is_closing() then
				timer:stop()
				timer:close()
			end
		end,
	})

	started = true
end

return M
-- vim: ts=4 sts=4 sw=4 et

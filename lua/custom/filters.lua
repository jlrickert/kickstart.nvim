local function async_filter(cmd_string, range_start, range_end)
	local buf = 0
	local start_row = range_start
	local end_row = range_end

	-- capture lines to send to stdin
	local ok, lines =
		pcall(vim.api.nvim_buf_get_lines, buf, start_row - 1, end_row, false)
	if not ok then
		vim.notify('Failed to get buffer lines', vim.log.levels.ERROR)
		return
	end

	-- full path (empty if none)
	local filepath = vim.api.nvim_buf_get_name(buf)

	-- build command string, handle {}
	local cmdstr = cmd_string or ''
	if filepath ~= '' and cmdstr:find('{}', 1, true) then
		local esc_path = vim.fn.shellescape(filepath)
		cmdstr = cmdstr:gsub('{}', esc_path)
	elseif filepath ~= '' then
		-- export NVIM_FILEPATH for child if no {} placeholder
		local esc_path = vim.fn.shellescape(filepath)
		cmdstr = 'NVIM_FILEPATH=' .. esc_path .. ' ' .. cmdstr
	end

	local stdout, stderr = {}, {}

	-- -- lock the buffer: save and set options
	-- local prev_mod = vim.api.nvim_buf_get_option(buf, 'modifiable')
	-- local prev_ro = vim.api.nvim_buf_get_option(buf, 'readonly')
	-- pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', false)
	-- pcall(vim.api.nvim_buf_set_option, buf, 'readonly', true)

	-- show virtual text at start of range
	local ns = vim.api.nvim_create_namespace('async_filter_lock')
	local virt_line = math.max(0, start_row - 1)
	local extmark_id = vim.api.nvim_buf_set_extmark(buf, ns, virt_line, 0, {
		virt_text = { { ' Filtering (async) — buffer locked ', 'Comment' } },
		virt_text_pos = 'eol',
	})

	-- start the job
	local job = vim.fn.jobstart({ 'bash', '-lc', cmdstr }, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data, _)
			if data then
				for _, l in ipairs(data) do
					table.insert(stdout, l)
				end
			end
		end,
		on_stderr = function(_, data, _)
			if data then
				for _, l in ipairs(data) do
					table.insert(stderr, l)
				end
			end
		end,
		on_exit = function(_, code, _)
			vim.schedule(function()
				-- remove virtual text
				pcall(vim.api.nvim_buf_del_extmark, buf, ns, extmark_id)

				-- temporarily allow edits to replace lines
				pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', true)
				pcall(vim.api.nvim_buf_set_option, buf, 'readonly', false)

				if code ~= 0 then
					local err = table.concat(stderr, '\n')
					if err == '' then
						err = 'filter exited with code ' .. tostring(code)
					end
					vim.notify('Filter failed: ' .. err, vim.log.levels.ERROR)
					-- restore original state
					pcall(
						vim.api.nvim_buf_set_option,
						buf,
						'modifiable',
						prev_mod
					)
					pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
					return
				end

				-- remove single trailing empty chunk that jobstart sometimes returns
				if #stdout == 1 and stdout[1] == '' then
					stdout = {}
				end

				-- replace selected range
				pcall(
					vim.api.nvim_buf_set_lines,
					buf,
					start_row - 1,
					end_row,
					false,
					stdout
				)

				-- restore original state
				pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', prev_mod)
				pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
			end)
		end,
	})

	if job <= 0 then
		-- cleanup and notify
		pcall(vim.api.nvim_buf_del_extmark, buf, ns, extmark_id)
		pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', prev_mod)
		pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
		vim.notify('Failed to start job', vim.log.levels.ERROR)
		return
	end

	-- stream the selection to stdin and close
	local input = table.concat(lines, '\n') .. '\n'
	pcall(vim.fn.chansend, job, input)
	pcall(vim.fn.chanclose, job, 'stdin')
end

-- Locking version of async_filter.
-- This version prevents concurrent filters on the same buffer and properly
-- saves/restores buffer modifiable/readonly state. It stores a buffer-local
-- variable "async_filter_locked" while the filter job runs.
local function async_filter_locked(cmd_string, range_start, range_end)
	local buf = 0
	local start_row = range_start
	local end_row = range_end

	-- prevent concurrent runs on the same buffer
	local locked = false
	pcall(function()
		locked = vim.api.nvim_buf_get_var(buf, 'async_filter_locked')
	end)
	if locked then
		vim.notify(
			'Another filter is already running on this buffer',
			vim.log.levels.WARN
		)
		return
	end

	-- mark as locked
	pcall(vim.api.nvim_buf_set_var, buf, 'async_filter_locked', true)

	-- capture lines to send to stdin
	local ok, lines =
		pcall(vim.api.nvim_buf_get_lines, buf, start_row - 1, end_row, false)
	if not ok then
		vim.notify('Failed to get buffer lines', vim.log.levels.ERROR)
		pcall(vim.api.nvim_buf_del_var, buf, 'async_filter_locked')
		return
	end

	-- full path (empty if none)
	local filepath = vim.api.nvim_buf_get_name(buf)

	-- build command string, handle {}
	local cmdstr = cmd_string or ''
	if filepath ~= '' and cmdstr:find('{}', 1, true) then
		local esc_path = vim.fn.shellescape(filepath)
		cmdstr = cmdstr:gsub('{}', esc_path)
	elseif filepath ~= '' then
		-- export NVIM_FILEPATH for child if no {} placeholder
		local esc_path = vim.fn.shellescape(filepath)
		cmdstr = 'NVIM_FILEPATH=' .. esc_path .. ' ' .. cmdstr
	end

	local stdout, stderr = {}, {}

	-- lock the buffer by setting options and saving previous state
	local ok_mod, prev_mod =
		pcall(vim.api.nvim_buf_get_option, buf, 'modifiable')
	if not ok_mod then
		prev_mod = true
	end
	local ok_ro, prev_ro = pcall(vim.api.nvim_buf_get_option, buf, 'readonly')
	if not ok_ro then
		prev_ro = false
	end

	-- make buffer non-editable by user while filter runs
	pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', false)
	pcall(vim.api.nvim_buf_set_option, buf, 'readonly', true)

	-- show virtual text at start of range
	local ns = vim.api.nvim_create_namespace('async_filter_locking')
	local virt_line = math.max(0, start_row - 1)
	local extmark_id = vim.api.nvim_buf_set_extmark(buf, ns, virt_line, 0, {
		virt_text = {
			{ ' Filtering (async, locked) — buffer locked ', 'Comment' },
		},
		virt_text_pos = 'eol',
	})

	-- cleanup helper (safe, idempotent)
	local function cleanup_and_restore()
		pcall(vim.api.nvim_buf_del_extmark, buf, ns, extmark_id)
		-- restore original state
		pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', prev_mod)
		pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
		pcall(vim.api.nvim_buf_del_var, buf, 'async_filter_locked')
	end

	-- start the job
	local job = vim.fn.jobstart({ 'bash', '-lc', cmdstr }, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data, _)
			if data then
				for _, l in ipairs(data) do
					table.insert(stdout, l)
				end
			end
		end,
		on_stderr = function(_, data, _)
			if data then
				for _, l in ipairs(data) do
					table.insert(stderr, l)
				end
			end
		end,
		on_exit = function(_, code, _)
			vim.schedule(function()
				-- temporarily allow edits to replace lines
				pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', true)
				pcall(vim.api.nvim_buf_set_option, buf, 'readonly', false)

				if code ~= 0 then
					local err = table.concat(stderr, '\n')
					if err == '' then
						err = 'filter exited with code ' .. tostring(code)
					end
					vim.notify('Filter failed: ' .. err, vim.log.levels.ERROR)
					cleanup_and_restore()
					return
				end

				-- remove single trailing empty chunk that jobstart sometimes returns
				if #stdout == 1 and stdout[1] == '' then
					stdout = {}
				end

				-- replace selected range
				pcall(
					vim.api.nvim_buf_set_lines,
					buf,
					start_row - 1,
					end_row,
					false,
					stdout
				)

				-- final cleanup & restore
				cleanup_and_restore()
			end)
		end,
	})

	if job <= 0 then
		-- cleanup and notify
		cleanup_and_restore()
		vim.notify('Failed to start job', vim.log.levels.ERROR)
		return
	end

	-- stream the selection to stdin and close
	local input = table.concat(lines, '\n') .. '\n'
	pcall(vim.fn.chansend, job, input)
	pcall(vim.fn.chanclose, job, 'stdin')
end

local function filter_sync(cmd_string, range_start, range_end)
	local buf = 0
	local start_row = range_start
	local end_row = range_end

	-- capture lines to send to stdin
	local ok, lines =
		pcall(vim.api.nvim_buf_get_lines, buf, start_row - 1, end_row, false)
	if not ok then
		vim.notify('Failed to get buffer lines', vim.log.levels.ERROR)
		return
	end

	-- full path (empty if none)
	local filepath = vim.api.nvim_buf_get_name(buf)

	-- build command string, handle {} and export file/line env var
	local cmdstr = cmd_string or ''
	if filepath ~= '' then
		local esc_path = vim.fn.shellescape(filepath)
		local fileline = filepath .. ':' .. tostring(start_row)
		local esc_fileline = vim.fn.shellescape(fileline)

		if cmdstr:find('{}', 1, true) then
			-- replace {} with escaped path and still export NVIM_FILELINE
			cmdstr = cmdstr:gsub('{}', esc_path)
			cmdstr = 'NVIM_FILELINE=' .. esc_fileline .. ' ' .. cmdstr
		else
			-- export NVIM_FILEPATH and NVIM_FILELINE for the child if no {} placeholder
			cmdstr = 'NVIM_FILEPATH='
				.. esc_path
				.. ' NVIM_FILELINE='
				.. esc_fileline
				.. ' '
				.. cmdstr
		end
	end

	-- show virtual text at start of range
	local ns = vim.api.nvim_create_namespace('filter_sync')
	local virt_line = math.max(0, start_row - 1)
	local extmark_id = vim.api.nvim_buf_set_extmark(buf, ns, virt_line, 0, {
		virt_text = { { ' Filtering (sync) ', 'Comment' } },
		virt_text_pos = 'eol',
	})

	-- save and set buffer options to allow replacement
	local ok_mod, prev_mod =
		pcall(vim.api.nvim_buf_get_option, buf, 'modifiable')
	if not ok_mod then
		prev_mod = true
	end
	local ok_ro, prev_ro = pcall(vim.api.nvim_buf_get_option, buf, 'readonly')
	if not ok_ro then
		prev_ro = false
	end

	-- ensure buffer is writable for replacement
	pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', true)
	pcall(vim.api.nvim_buf_set_option, buf, 'readonly', false)

	-- run synchronously, capture stdout+stderr by redirecting stderr to stdout
	local input = table.concat(lines, '\n') .. '\n'
	local full_cmd = cmdstr .. ' 2>&1'
	local ok_sys, result = pcall(vim.fn.systemlist, full_cmd, input)
	-- remove virtual text and restore options regardless
	pcall(vim.api.nvim_buf_del_extmark, buf, ns, extmark_id)

	if not ok_sys then
		-- systemlist call failed (pcall), restore and notify
		pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', prev_mod)
		pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
		vim.notify('Failed to run filter command', vim.log.levels.ERROR)
		return
	end

	local stdout_lines = result or {}

	-- check exit code
	local exit_code = vim.v.shell_error or 0
	if exit_code ~= 0 then
		local err = table.concat(stdout_lines, '\n')
		if err == '' then
			err = 'filter exited with code ' .. tostring(exit_code)
		end
		vim.notify('Filter failed: ' .. err, vim.log.levels.ERROR)
		-- restore original state
		pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', prev_mod)
		pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
		return
	end

	-- remove single trailing empty chunk that systemlist sometimes returns
	if #stdout_lines == 1 and stdout_lines[1] == '' then
		stdout_lines = {}
	end

	-- replace selected range
	pcall(
		vim.api.nvim_buf_set_lines,
		buf,
		start_row - 1,
		end_row,
		false,
		stdout_lines
	)

	-- restore original state
	pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', prev_mod)
	pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
end

-- Create a user command usable from visual mode for the original (buggy) async_filter.
-- Example usages:
--   visually select lines then :FilterAsync "sort -u"
--   visually select lines then :FilterAsync "sed -n '1,10p' {}"
vim.api.nvim_create_user_command('FilterAsync', function(opts)
	-- opts.args is the command string; opts.line1/line2 contain the range when range=true
	local cmd_string = opts.args
	-- Use provided range when present; otherwise use current line in normal mode
	local start_row = opts.line1 or vim.fn.line('.')
	local end_row = opts.line2 or vim.fn.line('.')
	async_filter(cmd_string, start_row, end_row)
end, { nargs = '+', range = true, complete = nil })

-- Create a user command for the locking version.
-- Example usage:
--   visually select lines then :FilterAsyncLocked "sort -u"
vim.api.nvim_create_user_command('FilterAsyncLocked', function(opts)
	local cmd_string = opts.args
	-- Use provided range when present; otherwise use current line in normal mode
	local start_row = opts.line1 or vim.fn.line('.')
	local end_row = opts.line2 or vim.fn.line('.')
	async_filter_locked(cmd_string, start_row, end_row)
end, { nargs = '+', range = true, complete = nil })

-- Create a user command for the synchronous filter.
-- Example usage:
--   visually select lines then :FilterSync "sort -u"
vim.api.nvim_create_user_command('FilterSync', function(opts)
	local cmd_string = opts.args
	-- Use provided range when present; otherwise use current line in normal mode
	local start_row = opts.line1 or vim.fn.line('.')
	local end_row = opts.line2 or vim.fn.line('.')
	filter_sync(cmd_string, start_row, end_row)
end, { nargs = '+', range = true, complete = nil })

return {
	async_filter = async_filter,
	async_filter_locked = async_filter_locked,
	filter_sync = filter_sync,
}

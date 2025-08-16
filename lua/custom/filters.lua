-- Asynchronously run a shell command on the given buffer range.
-- Parameters:
--   cmd_string  - (string) shell command to run. If '{}' appears it is replaced
--                 with the shell-escaped buffer filepath; otherwise NVIM_FILEPATH
--                 is exported for the child process when a filepath exists.
--   range_start - (number, 1-based) start line of the range to send to stdin.
--   range_end   - (number, 1-based) end line of the range to send to stdin.
--
-- Behavior:
--   - Captures the selected lines and streams them to the command's stdin using
--     jobstart('bash', '-lc', cmd).
--   - Buffers stdout and stderr separately, then on exit replaces the selected
--     range with the command's stdout (normalized so a single empty chunk becomes
--     an empty result).
--   - Shows a virtual-text marker at the start of the range while the job runs.
--   - Temporarily sets buffer options to allow replacement and restores the
--     previous 'modifiable'/'readonly' state on completion or error.
--   - Uses vim.schedule to perform buffer edits on the main thread.
--
-- Notes / caveats:
--   - Seems to be buggy if you do something else
--   - This is the non-locking variant: it intentionally does not prevent
--     concurrent edits to the buffer, so races with other edits or filters are
--     possible. Use async_filter_locked if you need a buffer-level lock.
--   - Notifies failures via vim.notify with appropriate log levels.
--   - Returns nothing.
local function async_filter(cmd_string, range_start, range_end)
	local buf = 0
	local start_row = range_start
	local end_row = range_end

	-- Capture the selected lines to send to the child process stdin.
	local ok, lines =
		pcall(vim.api.nvim_buf_get_lines, buf, start_row - 1, end_row, false)
	if not ok then
		vim.notify('Failed to get buffer lines', vim.log.levels.ERROR)
		return
	end

	-- Full file path for this buffer (empty string if no file).
	local filepath = vim.api.nvim_buf_get_name(buf)

	-- Build command string. If '{}' appears in the command, replace it with the
	-- shell-escaped file path. Otherwise export NVIM_FILEPATH for the child.
	local cmdstr = cmd_string or ''
	if filepath ~= '' and cmdstr:find('{}', 1, true) then
		local esc_path = vim.fn.shellescape(filepath)
		cmdstr = cmdstr:gsub('{}', esc_path)
	elseif filepath ~= '' then
		local esc_path = vim.fn.shellescape(filepath)
		cmdstr = 'NVIM_FILEPATH=' .. esc_path .. ' ' .. cmdstr
	end

	local stdout, stderr = {}, {}

	-- Record previous modifiable/readonly state so we can restore them on error.
	-- This function intentionally does not lock the buffer for editing; concurrent
	-- edits may race with the filter output.
	local ok_mod, prev_mod =
		pcall(vim.api.nvim_buf_get_option, buf, 'modifiable')
	if not ok_mod then
		prev_mod = true
	end
	local ok_ro, prev_ro = pcall(vim.api.nvim_buf_get_option, buf, 'readonly')
	if not ok_ro then
		prev_ro = false
	end

	-- Show a virtual text marker at the start of the range to indicate filtering.
	local ns = vim.api.nvim_create_namespace('async_filter_lock')
	local virt_line = math.max(0, start_row - 1)
	local extmark_id = vim.api.nvim_buf_set_extmark(buf, ns, virt_line, 0, {
		virt_text = { { ' Filtering (async) — buffer locked ', 'Comment' } },
		virt_text_pos = 'eol',
	})

	-- Start the asynchronous job. stdout/stderr are buffered and collected.
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
				-- Remove the virtual text marker.
				pcall(vim.api.nvim_buf_del_extmark, buf, ns, extmark_id)

				-- Temporarily allow edits so we can replace lines safely.
				pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', true)
				pcall(vim.api.nvim_buf_set_option, buf, 'readonly', false)

				if code ~= 0 then
					-- Assemble error message from stderr (or fallback to exit code).
					local err = table.concat(stderr, '\n')
					if err == '' then
						err = 'filter exited with code ' .. tostring(code)
					end
					vim.notify('Filter failed: ' .. err, vim.log.levels.ERROR)

					-- Restore previous buffer state and return.
					pcall(
						vim.api.nvim_buf_set_option,
						buf,
						'modifiable',
						prev_mod
					)
					pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
					return
				end

				-- jobstart sometimes returns a single empty chunk; normalize that.
				if #stdout == 1 and stdout[1] == '' then
					stdout = {}
				end

				-- Replace the selected range with the filter output.
				pcall(
					vim.api.nvim_buf_set_lines,
					buf,
					start_row - 1,
					end_row,
					false,
					stdout
				)

				-- Restore previous buffer state.
				pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', prev_mod)
				pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
			end)
		end,
	})

	if job <= 0 then
		-- Failed to start job: clean up virtual text and restore state.
		pcall(vim.api.nvim_buf_del_extmark, buf, ns, extmark_id)
		pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', prev_mod)
		pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
		vim.notify('Failed to start job', vim.log.levels.ERROR)
		return
	end

	-- Stream the captured selection to the job's stdin and close it.
	local input = table.concat(lines, '\n') .. '\n'
	pcall(vim.fn.chansend, job, input)
	pcall(vim.fn.chanclose, job, 'stdin')
end

-- Locking version of async_filter.
-- This prevents concurrent filters on the same buffer and properly saves/restores
-- the buffer's modifiable/readonly state. While running it sets a buffer-local
-- variable "async_filter_locked" to true.
local function async_filter_locked(cmd_string, range_start, range_end)
	local buf = 0
	local start_row = range_start
	local end_row = range_end

	-- Prevent concurrent runs on the same buffer.
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

	-- Mark buffer as locked.
	pcall(vim.api.nvim_buf_set_var, buf, 'async_filter_locked', true)

	-- Capture selected lines to send to stdin.
	local ok, lines =
		pcall(vim.api.nvim_buf_get_lines, buf, start_row - 1, end_row, false)
	if not ok then
		vim.notify('Failed to get buffer lines', vim.log.levels.ERROR)
		pcall(vim.api.nvim_buf_del_var, buf, 'async_filter_locked')
		return
	end

	-- Full file path (empty if none).
	local filepath = vim.api.nvim_buf_get_name(buf)

	-- Build command string, handle '{}' placeholder or export NVIM_FILEPATH.
	local cmdstr = cmd_string or ''
	if filepath ~= '' and cmdstr:find('{}', 1, true) then
		local esc_path = vim.fn.shellescape(filepath)
		cmdstr = cmdstr:gsub('{}', esc_path)
	elseif filepath ~= '' then
		local esc_path = vim.fn.shellescape(filepath)
		cmdstr = 'NVIM_FILEPATH=' .. esc_path .. ' ' .. cmdstr
	end

	local stdout, stderr = {}, {}

	-- Save previous modifiable/readonly state (with safe fallbacks).
	local ok_mod, prev_mod =
		pcall(vim.api.nvim_buf_get_option, buf, 'modifiable')
	if not ok_mod then
		prev_mod = true
	end
	local ok_ro, prev_ro = pcall(vim.api.nvim_buf_get_option, buf, 'readonly')
	if not ok_ro then
		prev_ro = false
	end

	-- Make buffer non-editable by the user while the filter runs.
	pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', false)
	pcall(vim.api.nvim_buf_set_option, buf, 'readonly', true)

	-- Show virtual text to indicate the buffer is locked for filtering.
	local ns = vim.api.nvim_create_namespace('async_filter_locking')
	local virt_line = math.max(0, start_row - 1)
	local extmark_id = vim.api.nvim_buf_set_extmark(buf, ns, virt_line, 0, {
		virt_text = {
			{ ' Filtering (async, locked) — buffer locked ', 'Comment' },
		},
		virt_text_pos = 'eol',
	})

	-- Cleanup helper: idempotent and safe to call from multiple paths.
	local function cleanup_and_restore()
		pcall(vim.api.nvim_buf_del_extmark, buf, ns, extmark_id)
		pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', prev_mod)
		pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
		pcall(vim.api.nvim_buf_del_var, buf, 'async_filter_locked')
	end

	-- Start the asynchronous job, collecting stdout/stderr.
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
				-- Temporarily allow edits to replace lines.
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

				-- Normalize single empty-chunk behavior.
				if #stdout == 1 and stdout[1] == '' then
					stdout = {}
				end

				-- Replace the selected range with the collected stdout.
				pcall(
					vim.api.nvim_buf_set_lines,
					buf,
					start_row - 1,
					end_row,
					false,
					stdout
				)

				-- Final cleanup and restore of buffer state.
				cleanup_and_restore()
			end)
		end,
	})

	if job <= 0 then
		-- Failed to start job: cleanup and notify.
		cleanup_and_restore()
		vim.notify('Failed to start job', vim.log.levels.ERROR)
		return
	end

	-- Stream the selection to the job's stdin and close it.
	local input = table.concat(lines, '\n') .. '\n'
	pcall(vim.fn.chansend, job, input)
	pcall(vim.fn.chanclose, job, 'stdin')
end

-- Synchronous filter: runs the command synchronously on the given buffer range.
-- Parameters:
--   cmd_string  - (string) shell command to run. If '{}' appears it is replaced
--                 with the shell-escaped buffer filepath; otherwise NVIM_FILEPATH
--                 and NVIM_FILELINE are exported for the child process when a filepath exists.
--   range_start - (number, 1-based) start line of the range to send to stdin.
--   range_end   - (number, 1-based) end line of the range to send to stdin.
--
-- Behavior:
--   - Captures the selected lines and passes them to the command's stdin via
--     vim.fn.systemlist (synchronous).
--   - Redirects stderr into stdout so both are captured.
--   - Shows a virtual-text marker at the start of the range while running.
--   - Temporarily sets buffer options to allow replacement and restores the
--     previous 'modifiable'/'readonly' state on completion or error.
--   - Normalizes a single empty output chunk to an empty result.
--   - Notifies failures via vim.notify with appropriate log levels.
local function filter_sync(cmd_string, range_start, range_end)
	local buf = 0
	local start_row = range_start
	local end_row = range_end

	-- Capture lines to send to stdin.
	local ok, lines =
		pcall(vim.api.nvim_buf_get_lines, buf, start_row - 1, end_row, false)
	if not ok then
		vim.notify('Failed to get buffer lines', vim.log.levels.ERROR)
		return
	end

	-- Full file path for the buffer (empty if none).
	local filepath = vim.api.nvim_buf_get_name(buf)

	-- Build command string and export NVIM_FILELINE (and NVIM_FILEPATH if needed).
	local cmdstr = cmd_string or ''
	if filepath ~= '' then
		local esc_path = vim.fn.shellescape(filepath)
		local fileline = filepath .. ':' .. tostring(start_row)
		local esc_fileline = vim.fn.shellescape(fileline)

		if cmdstr:find('{}', 1, true) then
			-- Replace {} with escaped path and still export NVIM_FILELINE.
			cmdstr = cmdstr:gsub('{}', esc_path)
			cmdstr = 'NVIM_FILELINE=' .. esc_fileline .. ' ' .. cmdstr
		else
			-- Export both NVIM_FILEPATH and NVIM_FILELINE for the child.
			cmdstr = 'NVIM_FILEPATH='
				.. esc_path
				.. ' NVIM_FILELINE='
				.. esc_fileline
				.. ' '
				.. cmdstr
		end
	end

	-- Show virtual text indicating synchronous filtering.
	local ns = vim.api.nvim_create_namespace('filter_sync')
	local virt_line = math.max(0, start_row - 1)
	local extmark_id = vim.api.nvim_buf_set_extmark(buf, ns, virt_line, 0, {
		virt_text = { { ' Filtering (sync) ', 'Comment' } },
		virt_text_pos = 'eol',
	})

	-- Save and set buffer options to allow replacement.
	local ok_mod, prev_mod =
		pcall(vim.api.nvim_buf_get_option, buf, 'modifiable')
	if not ok_mod then
		prev_mod = true
	end
	local ok_ro, prev_ro = pcall(vim.api.nvim_buf_get_option, buf, 'readonly')
	if not ok_ro then
		prev_ro = false
	end

	-- Ensure buffer is writable for replacement.
	pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', true)
	pcall(vim.api.nvim_buf_set_option, buf, 'readonly', false)

	-- Run synchronously. Redirect stderr into stdout so we get both.
	local input = table.concat(lines, '\n') .. '\n'
	local full_cmd = cmdstr .. ' 2>&1'
	local ok_sys, result = pcall(vim.fn.systemlist, full_cmd, input)

	-- Remove virtual text regardless of success/failure.
	pcall(vim.api.nvim_buf_del_extmark, buf, ns, extmark_id)

	if not ok_sys then
		-- systemlist call itself failed.
		pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', prev_mod)
		pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
		vim.notify('Failed to run filter command', vim.log.levels.ERROR)
		return
	end

	local stdout_lines = result or {}

	-- Check command exit code and notify on error.
	local exit_code = vim.v.shell_error or 0
	if exit_code ~= 0 then
		local err = table.concat(stdout_lines, '\n')
		if err == '' then
			err = 'filter exited with code ' .. tostring(exit_code)
		end
		vim.notify('Filter failed: ' .. err, vim.log.levels.ERROR)
		pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', prev_mod)
		pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
		return
	end

	-- Normalize a single trailing empty chunk.
	if #stdout_lines == 1 and stdout_lines[1] == '' then
		stdout_lines = {}
	end

	-- Replace the selected range with the command output.
	pcall(
		vim.api.nvim_buf_set_lines,
		buf,
		start_row - 1,
		end_row,
		false,
		stdout_lines
	)

	-- Restore previous buffer state.
	pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', prev_mod)
	pcall(vim.api.nvim_buf_set_option, buf, 'readonly', prev_ro)
end

-- User command: FilterAsync (non-locking). Example:
--   visually select lines then :FilterAsync sort -u
--   or with {} placeholder: :FilterAsync "sed -n '1,10p' {}"
vim.api.nvim_create_user_command('FilterAsync', function(opts)
	local cmd_string = opts.args
	local start_row = opts.line1 or vim.fn.line('.')
	local end_row = opts.line2 or vim.fn.line('.')
	async_filter(cmd_string, start_row, end_row)
end, { nargs = '+', range = true })

-- User command: FilterAsyncLocked (locking). Example:
--   visually select lines then :FilterAsyncLocked "sort -u"
vim.api.nvim_create_user_command('FilterAsyncLocked', function(opts)
	local cmd_string = opts.args
	local start_row = opts.line1 or vim.fn.line('.')
	local end_row = opts.line2 or vim.fn.line('.')
	async_filter_locked(cmd_string, start_row, end_row)
end, { nargs = '+', range = true })

-- User command: FilterSync (synchronous). Example:
--   visually select lines then :FilterSync "sort -u"
vim.api.nvim_create_user_command('FilterSync', function(opts)
	local cmd_string = opts.args
	local start_row = opts.line1 or vim.fn.line('.')
	local end_row = opts.line2 or vim.fn.line('.')
	filter_sync(cmd_string, start_row, end_row)
end, { nargs = '+', range = true })

return {
	async_filter = async_filter,
	async_filter_locked = async_filter_locked,
	filter_sync = filter_sync,
}

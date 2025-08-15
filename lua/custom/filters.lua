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

	-- lock the buffer: save and set options
	local prev_mod = vim.api.nvim_buf_get_option(buf, 'modifiable')
	local prev_ro = vim.api.nvim_buf_get_option(buf, 'readonly')
	pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', false)
	pcall(vim.api.nvim_buf_set_option, buf, 'readonly', true)

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

-- Create a user command usable from visual mode. It preserves the visual range.
-- Example usages:
--   visually select lines then :FilterAsync "sort -u"
--   visually select lines then :FilterAsync "sed -n '1,10p' {}"   -- uses {} for file path
vim.api.nvim_create_user_command('FilterAsync', function(opts)
	-- opts.args is the command string; opts.line1/line2 contain the range when range=true
	local cmd_string = opts.args
	local start_row = opts.line1 or vim.fn.line("'<")
	local end_row = opts.line2 or vim.fn.line("'>")
	async_filter(cmd_string, start_row, end_row)
end, { nargs = '+', range = true, complete = nil })

return {
	async_filter = async_filter,
}

local M = {}

local Config = require("timecapsule.config")
local Log = require("timecapsule.log")

---@param filepath string
---@return boolean
local function should_stage(filepath, patterns)
	patterns = patterns or (M.config and M.config.file_patterns)

	if not patterns or vim.tbl_isempty(patterns) then
		for _, pattern in ipairs(Config.EXCLUDE_PATTERNS or {}) do
			if filepath == pattern then
				return false
			end
			if pattern:find("%*") then
				local regex = pattern:gsub("%.", "%."):gsub("%*", ".*") .. "$"
				if filepath:match(regex) then
					return false
				end
			end
			if pattern:sub(-1) == "/" and filepath:find(pattern) then
				return false
			end
		end
		return true
	end

	local matches = false
	for _, pattern in ipairs(patterns) do
		local is_exclude = pattern:sub(1, 1) == "!"
		local p = is_exclude and pattern:sub(2) or pattern

		if filepath == p then
			matches = not is_exclude
		elseif p:find("%*") then
			local regex = p:gsub("%.", "%."):gsub("%*", ".*") .. "$"
			if filepath:match(regex) then
				matches = not is_exclude
			end
		elseif p:sub(-1) == "/" and filepath:find(p) then
			matches = not is_exclude
		end
	end

	return matches
end

M.should_stage = should_stage

---@return string
local function get_backup_dir()
	return vim.fn.expand(M.config.backup):gsub("/+$", "")
end

---@return boolean success
---@return string|nil error
local function init_backup_repo()
	local backup_dir = get_backup_dir()

	-- Ensure backup directory exists
	vim.fn.mkdir(backup_dir, "p")

	-- Check if already a git repo
	local result = vim.fn.systemlist("git -C " .. backup_dir .. " rev-parse --git-dir 2>&1")
	if result[1]:match("^%.git$") then
		return true, nil
	end

	-- Initialize new repo
	vim.fn.system({ "git", "init", "--quiet", backup_dir })
	if vim.v.shell_error ~= 0 then
		return false, "git init failed"
	end

	-- Configure git for this repo if not already set
	local email_result = vim.fn.systemlist("git -C " .. backup_dir .. " config user.email 2>&1")
	if not email_result[1] or email_result[1]:gsub("%s+", "") == "" then
		vim.fn.system({ "git", "-C", backup_dir, "config", "user.email", "timecapsule@local" })
	end

	local name_result = vim.fn.systemlist("git -C " .. backup_dir .. " config user.name 2>&1")
	if not name_result[1] or name_result[1]:gsub("%s+", "") == "" then
		vim.fn.system({ "git", "-C", backup_dir, "config", "user.name", "Timecapsule" })
	end

	return true, nil
end

--- Copy file to backup directory preserving relative path
---@param filepath string
---@return boolean success
---@return string|nil error
local function copy_to_backup(filepath)
	local backup_dir = vim.fn.expand(get_backup_dir())
	local abs_path = vim.fn.fnamemodify(filepath, ":p")
	local rel_path = abs_path:sub(2) -- Strip leading "/" for root-relative path
	local backup_path = backup_dir .. "/" .. rel_path

	-- Create destination directory
	local dest_dir = backup_path:match("^(.+)/[^/]+$")
	vim.fn.mkdir(dest_dir, "p")

	local ok, err = vim.loop.fs_copyfile(abs_path, backup_path)
	if not ok then
		return false, "copy failed: " .. tostring(err)
	end

	return true, backup_path
end

---@param opts? table
function M.setup(opts)
	M.config = Config.validate(opts)
	Log.setup(M.config.notify)
	M.enabled = M.config.enable

	if not M.enabled then
		return
	end

	M.augroup = vim.api.nvim_create_augroup("Timecapsule", { clear = true })

	local callback = function()
		M._handle_write()
	end

	vim.api.nvim_create_autocmd("BufWritePost", {
		group = M.augroup,
		pattern = "*",
		callback = callback,
	})
end

function M._handle_write()
	if not M.enabled then
		return
	end

	local bufname = vim.api.nvim_buf_get_name(0)
	if bufname == "" then
		return
	end
	if not M.should_stage(bufname) then
		return
	end

	-- Copy file to backup
	local success, err = copy_to_backup(bufname)
	if not success then
		if M.config.notify.failure then
			Log.failure("Timecapsule: " .. err)
		end
		return
	end

	if M.config.notify.success then
		Log.success("Timecapsule: backed up " .. bufname)
	end

	local backup_path = err

	-- Initialize repo if needed
	success, err = init_backup_repo()
	if not success then
		if M.config.notify.failure then
			Log.failure("Timecapsule: " .. err)
		end
		return
	end

	local backup_dir = get_backup_dir()
	-- Skip files inside backup directory to avoid infinite loop
	local abs_path = vim.fn.fnamemodify(bufname, ":p")
	if abs_path:sub(1, #backup_dir) == backup_dir then
		return
	end

	-- Stage file in backup repo (use relative path)
	local rel_to_backup = backup_path:sub(#backup_dir + 2) -- Strip backup_dir prefix
	vim.fn.system({ "git", "-C", backup_dir, "add", "--", rel_to_backup })
	if vim.v.shell_error ~= 0 then
		if M.config.notify.failure then
			Log.failure("Timecapsule: add failed")
		end
		return
	end

	-- Check if there are staged changes
	local status_result = vim.fn.systemlist("git -C " .. backup_dir .. " status --porcelain 2>&1")
	if vim.tbl_isempty(status_result) then
		if M.config.notify.success then
			Log.success("Timecapsule: file not modified, skipping commit")
		end
		return
	end

	local message = M.config.message_format:gsub("{path}", bufname)

	-- Commit in backup repo
	success, _ = pcall(vim.fn.system, { "git", "-C", backup_dir, "commit", "-m", message })
	if not success then
		if M.config.notify.failure then
			Log.failure("Timecapsule: commit failed")
		end
		return
	end

	local code = vim.v.shell_error
	if code ~= 0 then
		if M.config.notify.failure then
			Log.failure("Timecapsule: git commit failed")
		end
		return
	end

	if M.config.notify.success then
		Log.success("Timecapsule: committed " .. message)
	end

	-- Push if enabled
	if M.config.push and M.config.push.enable then
		local Git = require("timecapsule.git")
		local push_success, push_err = Git.push(backup_dir, M.config.push.branch)
		if not push_success then
			if M.config.notify.failure then
				Log.failure("Timecapsule: " .. push_err)
			end
		else
			if M.config.notify.success then
				Log.success("Timecapsule: pushed to " .. M.config.push.branch)
			end
		end
	end
end

function M.toggle()
	if M.enabled then
		M.enabled = false
		vim.api.nvim_del_augroup_by_id(M.augroup)
		M.augroup = nil
		Log.success("Timecapsule: disabled")
	else
		M.enabled = true
		M.augroup = vim.api.nvim_create_augroup("Timecapsule", { clear = true })
		local callback = function()
			M._handle_write()
		end
		vim.api.nvim_create_autocmd("BufWritePost", {
			group = M.augroup,
			pattern = "*",
			callback = callback,
		})
		Log.success("Timecapsule: enabled")
	end
end

return M

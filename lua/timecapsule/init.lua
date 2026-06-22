local M = {}

local Config = require("timecapsule.config")
local Log = require("timecapsule.log")

---@param filepath string
---@return boolean
local function should_stage(filepath, patterns)
	patterns = patterns or (M.config and M.config.file_patterns)

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
		if pattern:sub(-1) == "/" and filepath:find(".*" .. vim.pesc(pattern)) then
			return false
		end
	end

	if not patterns then
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
		elseif p:sub(-1) == "/" and filepath:find(".*" .. vim.pesc(p)) then
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

	-- Initialize if not already a git repo
	local result = vim.fn.systemlist({ "git", "-C", backup_dir, "rev-parse", "--git-dir" })
	if result[1]:match("^%.git$") then
		-- Repo exists, set identity only if not already configured
		local email_check = vim.fn.systemlist({ "git", "-C", backup_dir, "config", "--get", "user.email" })
		if not email_check[1] or vim.trim(email_check[1]) == "" then
			vim.fn.system({ "git", "-C", backup_dir, "config", "user.email", "timecapsule@local" })
		end
		local name_check = vim.fn.systemlist({ "git", "-C", backup_dir, "config", "--get", "user.name" })
		if not name_check[1] or vim.trim(name_check[1]) == "" then
			vim.fn.system({ "git", "-C", backup_dir, "config", "user.name", "Timecapsule" })
		end
		return true, nil
	end

	-- Initialize new repo
	vim.fn.system({ "git", "init", "-q", backup_dir })
	if vim.v.shell_error ~= 0 then
		return false, "git init failed"
	end

	-- Configure git identity for this repo
	vim.fn.system({ "git", "-C", backup_dir, "config", "user.email", "timecapsule@local" })
	vim.fn.system({ "git", "-C", backup_dir, "config", "user.name", "Timecapsule" })

	return true, nil
end

--- Copy file to backup directory preserving relative path
---@param filepath string
---@return boolean, string|nil
local function copy_to_backup(filepath)
	local backup_dir = get_backup_dir()
	local abs_path = vim.fn.fnamemodify(filepath, ":p")
	-- Verify source file exists before attempting copy
	local src_stat = vim.loop.fs_stat(abs_path)
	if not src_stat or src_stat.type ~= "file" then
		return false, "source file not found: " .. abs_path
	end
	local rel_path = abs_path:gsub("^[A-Za-z]:[\\/]", "") -- Strip drive letter on Windows
	local backup_path = vim.fs.joinpath(backup_dir, rel_path)
	local dest_dir = vim.fn.fnamemodify(backup_path, ":h")

	local mkdir_ok, mkdir_err = pcall(vim.fn.mkdir, dest_dir, "p")
	if not mkdir_ok then
		return false, "mkdir failed: " .. vim.trim(tostring(mkdir_err))
	end

	local copy_ok, copy_err = pcall(vim.loop.fs_copyfile, abs_path, backup_path)
	if not copy_ok then
		return false, "copy failed: " .. tostring(copy_err)
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
	local success, copy_result = copy_to_backup(bufname)
	if not success then
		if M.config.notify.failure then
			Log.failure("Timecapsule: " .. copy_result)
		end
		return
	end

	if M.config.notify.success then
		Log.success("Timecapsule: backed up " .. bufname)
	end
	local backup_path = copy_result

	local repo_success, repo_err = init_backup_repo()
	if not repo_success then
		if M.config.notify.failure then
			Log.failure("Timecapsule: " .. repo_err)
		end
		return
	end

	local backup_dir = get_backup_dir()
	-- Skip files inside backup directory to avoid infinite loop
	local abs_path = vim.fn.fnamemodify(bufname, ":p")
	if abs_path:find("^" .. vim.pesc(backup_dir) .. "/") then
		return
	end

	-- Stage file in backup repo (use relative path)
	local rel_to_backup = assert(backup_path, "backup_path should be set"):sub(#backup_dir + 2) -- Strip backup_dir prefix
	vim.fn.system({ "git", "-C", backup_dir, "add", "--", rel_to_backup })
	if vim.v.shell_error ~= 0 then
		if M.config.notify.failure then
			Log.failure("Timecapsule: add failed")
		end
		return
	end

	-- Check for actual content changes (skip if diff is empty)
	local diff_result = vim.fn.systemlist({ "git", "-C", backup_dir, "diff", "--cached", "--name-only" })
	if not next(diff_result) then
		if M.config.notify.success then
			Log.success("Timecapsule: file not modified, skipping commit")
		end
		return
	end

	local message = M.config.message_format:gsub("{path}", bufname)

	-- Commit in backup repo
	vim.fn.system({ "git", "-C", backup_dir, "commit", "-m", message, "--" })
	if vim.v.shell_error ~= 0 then
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
		local branch = M.config.push.branch
		if not branch then
			local branch_result = vim.fn.systemlist({ "git", "-C", backup_dir, "rev-parse", "--abbrev-ref", "HEAD" })
			local detected_branch = branch_result[1]
			if vim.v.shell_error ~= 0 or not detected_branch or detected_branch:find("^error") then
				branch = "main"
			else
				branch = vim.trim(detected_branch)
			end
		end
		local Git = require("timecapsule.git")
		local push_success, push_err = Git.push(backup_dir, branch)
		if not push_success then
			if M.config.notify.failure then
				Log.failure("Timecapsule: " .. push_err)
			end
		else
			if M.config.notify.success then
				Log.success("Timecapsule: pushed to " .. branch)
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

-- Expose internals for testing
M._init_backup_repo = init_backup_repo
M._copy_to_backup = copy_to_backup
return M

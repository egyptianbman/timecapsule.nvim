local M = {}

--- Safely remove a directory tree. No-op if path does not exist.
---@param dir string
function M.cleanup(dir)
	if not M.dir_exists(dir) then
		return
	end
	vim.fn.delete(dir, "rf")
end

--- Safely stat a file path. Returns nil on failure (file not found, permission denied).
---@param path string
---@return table|false result File metadata or false
function M.fs_stat_safe(path)
	local ok, result = pcall(vim.loop.fs_stat, path)
	return ok and result
end

--- Check if a directory exists.
---@param path string
---@return boolean
function M.dir_exists(path)
	return vim.fn.isdirectory(path) == 1
end

return M

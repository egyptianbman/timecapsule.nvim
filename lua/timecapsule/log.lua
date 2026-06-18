local M = {}

---@param message string
---@param level number
function M.notify(message, level)
	vim.notify(message, level, {
		title = "Timecapsule",
		keep = false,
	})
end

function M.success(message)
	M.notify(message, vim.log.levels.INFO)
end

function M.failure(message)
	M.notify(message, vim.log.levels.ERROR)
end

return M

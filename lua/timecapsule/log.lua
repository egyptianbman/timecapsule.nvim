local M = {}

---@class TimecapsuleLogConfig
---@field success_level? number
---@field failure_level? number

M._config = {
	success_level = vim.log.levels.INFO,
	failure_level = vim.log.levels.ERROR,
}

---@param config? TimecapsuleLogConfig
function M.setup(config)
	if config then
		if config.success_level then
			M._config.success_level = config.success_level
		end
		if config.failure_level then
			M._config.failure_level = config.failure_level
		end
	end
end

---@param message string
---@param level number
function M.notify(message, level)
	vim.notify(message, level, {
		title = "Timecapsule",
		keep = false,
	})
end

function M.success(message)
	M.notify(message, M._config.success_level)
end

function M.failure(message)
	M.notify(message, M._config.failure_level)
end

return M

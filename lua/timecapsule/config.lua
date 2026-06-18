local M = {}

---@class TimecapsuleConfig
---@field enable boolean
---@field file_patterns string[]|nil Patterns to include (default: all with exclusions)
---@field message_format string Format string with {path} placeholder
---@field backup string|nil Backup directory path (default: stdpath('data')/timecapsule)
---@field push table|nil Push configuration
---@field notify table Notification settings
---@field command table Command configuration

M.EXCLUDE_PATTERNS = {
	-- Lock files
	"package-lock.json",
	"yarn.lock",
	"pnpm-lock.yaml",
	"Cargo.lock",
	"go.sum",
	"Pipfile.lock",
	"poetry.lock",
	"Gemfile.lock",
	"composer.lock",
	-- Dependency directories
	"node_modules/",
	"vendor/",
	".venv/",
	-- Build outputs
	"build/",
	"dist/",
	"out/",
	".next/",
	".nuxt/",
	".angular/",
	-- Runtime/IDE
	"__pycache__/",
	".DS_Store",
	"Thumbs.db",
	".idea/",
	".vscode/",
	-- Logs and temp
	"*.log",
	"*.tmp",
	"*.swp",
	"*.swo",
	".cache/",
	"coverage/",
}

M.default_config = {
	enable = true,
	file_patterns = nil,
	message_format = "Updated: {path}",
	backup = nil, -- Will be set to stdpath('data')/backup if nil
	push = {
		enable = false,
		branch = nil, -- Will be set to current git branch if nil
	},
	notify = {
		success = false,
		failure = true,
	},
	command = {
		name = "TimecapsuleToggle",
	},
}

---@param opts? table
---@return TimecapsuleConfig
function M.validate(opts)
	local merged = {}
	for k, v in pairs(M.default_config) do
		merged[k] = v
	end
	for k, v in pairs(opts or {}) do
		merged[k] = v
	end

	if not merged.enable then
		return merged
	end

	if type(merged.message_format) ~= "string" then
		error("message_format must be a string")
	end

	if not merged.backup or type(merged.backup) ~= "string" then
		merged.backup = vim.fn.stdpath("data") .. "/timecapsule"
	end

	if merged.push and type(merged.push) == "table" then
		if type(merged.push.enable) ~= "boolean" then
			error("push.enable must be a boolean")
		end
		if merged.push.branch then
			if type(merged.push.branch) ~= "string" then
				error("push.branch must be a string")
			end
		else
			-- Get current git branch from backup repo
			local branch_result = vim.fn.systemlist("git -C " .. merged.backup .. " rev-parse --abbrev-ref HEAD 2>&1")
			merged.push.branch = branch_result[1]:gsub("%s+", "")
		end
	end

	return merged
end

return M

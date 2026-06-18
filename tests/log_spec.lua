describe("Logging", function()
	local Log = require("timecapsule.log")

	it("should have success and failure functions", function()
		assert.truthy(Log.success)
		assert.truthy(Log.failure)
		assert.truthy(Log.notify)
	end)

	it("should use default log levels", function()
		assert.equal(Log._config.success_level, vim.log.levels.INFO)
		assert.equal(Log._config.failure_level, vim.log.levels.ERROR)
	end)

	it("should allow configuring log levels", function()
		Log.setup({ success_level = vim.log.levels.WARN, failure_level = vim.log.levels.WARN })
		assert.equal(Log._config.success_level, vim.log.levels.WARN)
		assert.equal(Log._config.failure_level, vim.log.levels.WARN)

		-- Reset to defaults
		Log.setup({ success_level = vim.log.levels.INFO, failure_level = vim.log.levels.ERROR })
	end)

	it("should call vim.notify with configured level on success", function()
		local captured = {}
		local orig_notify = vim.notify
		vim.notify = function(msg, level, _opts)
			captured.level = level
			captured.msg = msg
		end

		Log.success("test message")
		assert.equal(captured.level, vim.log.levels.INFO)
		assert.equal(captured.msg, "test message")

		vim.notify = orig_notify
	end)

	it("should call vim.notify with configured level on failure", function()
		local captured = {}
		local orig_notify = vim.notify
		vim.notify = function(msg, level, _opts)
			captured.level = level
			captured.msg = msg
		end

		Log.failure("test error")
		assert.equal(captured.level, vim.log.levels.ERROR)
		assert.equal(captured.msg, "test error")

		vim.notify = orig_notify
	end)
end)

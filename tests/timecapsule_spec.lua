describe("Config system", function()
	local Config = require("timecapsule.config")

	it("should have default config values", function()
		assert.equal(Config.default_config.enable, true)
		assert.equal(Config.default_config.file_patterns, nil)
		assert.equal(Config.default_config.backup, nil)
		assert.equal(Config.default_config.message_format, "Updated: {path}")
		assert.truthy(Config.default_config.notify.failure)
		assert.is_false(Config.default_config.notify.success)
	end)

	it("should merge with defaults", function()
		local opts = { enable = true, message_format = "custom" }
		local config = Config.validate(opts)

		assert.equal(config.enable, true)
		assert.equal(config.message_format, "custom")
		assert.equal(config.backup, vim.fn.stdpath("data") .. "/timecapsule")
		assert.truthy(config.notify.failure)
	end)

	it("should handle nil opts", function()
		local config = Config.validate(nil)

		assert.truthy(config.enable)
		assert.equal(config.message_format, "Updated: {path}")
		assert.equal(config.backup, vim.fn.stdpath("data") .. "/timecapsule")
	end)

	it("should have default excludes", function()
		local excludes = Config.EXCLUDE_PATTERNS

		assert.truthy(vim.tbl_contains(excludes, "package-lock.json"))
		assert.truthy(vim.tbl_contains(excludes, "yarn.lock"))
		assert.truthy(vim.tbl_contains(excludes, "node_modules/"))
		assert.truthy(vim.tbl_contains(excludes, "*.log"))
	end)

	it("should use custom options", function()
		local opts = { message_format = "custom: {path}" }
		local config = Config.validate(opts)

		assert.equal(config.message_format, "custom: {path}")
	end)

	it("should error on invalid message_format", function()
		assert.error(function()
			Config.validate({ message_format = 123 })
		end)
	end)

	it("should error on invalid push.enable", function()
		assert.error(function()
			Config.validate({ push = { enable = "yes" } })
		end)
	end)

	it("should error on invalid push.branch", function()
		assert.error(function()
			Config.validate({ push = { enable = true, branch = 123 } })
		end)
	end)

	it("should validate push settings when provided", function()
		local config = Config.validate({ push = { enable = true, branch = "develop" } })

		assert.is_true(config.push.enable)
		assert.equal(config.push.branch, "develop")
		assert.equal(config.backup, vim.fn.stdpath("data") .. "/timecapsule")
	end)

	it("should use default backup path", function()
		local config = Config.validate({ enable = true })

		assert.equal(config.backup, vim.fn.stdpath("data") .. "/timecapsule")
	end)

	it("should use custom backup path", function()
		local config = Config.validate({ backup = "/test" })
		assert.equal(config.backup, "/test")
	end)
end)

describe("Main module", function()
	it("should have toggle command", function()
		local Timecapsule = require("timecapsule")
		Timecapsule.setup({ enable = true })
		assert.truthy(Timecapsule.enabled)

		Timecapsule.toggle()
		assert.is_false(Timecapsule.enabled)
		assert.is_nil(Timecapsule.augroup)

		Timecapsule.toggle()
		assert.truthy(Timecapsule.enabled)
	end)

	it("should properly manage augroup lifecycle", function()
		local Timecapsule = require("timecapsule")

		-- Setup creates augroup
		Timecapsule.setup({ enable = true })
		assert.truthy(Timecapsule.augroup)

		-- Toggle disables and removes augroup
		Timecapsule.toggle()
		assert.is_nil(Timecapsule.augroup)

		-- Toggle re-enables and recreates augroup
		Timecapsule.toggle()
		assert.truthy(Timecapsule.augroup)
	end)

	it("should copy file to backup directory on write", function()
		local Config = require("timecapsule.config")
		local Timecapsule = require("timecapsule")
		local config = Config.validate({ backup = "/tmp/tc_test_backup" })

		-- Create test file
		local test_file = "/tmp/tc_test_source/test.txt"
		vim.fn.mkdir("/tmp/tc_test_source", "p")
		vim.fn.writefile({ "test content" }, test_file)

		-- Setup and trigger backup
		Timecapsule.setup({ enable = true, backup = config.backup })

		-- Simulate write
		vim.cmd("edit " .. test_file)
		vim.cmd("write")

		-- Verify file was copied
		local backup_file = config.backup .. "/tmp/tc_test_source/test.txt"
		assert.truthy(vim.loop.fs_stat(backup_file), "File should be copied to backup directory")

		local content = vim.fn.readfile(backup_file)
		assert.equal(content[1], "test content", "Backup content should match source")
	end)
end)

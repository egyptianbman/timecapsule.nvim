local Helpers = require("tests.helpers")

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

	it("should error on invalid notify type", function()
		assert.error(function()
			Config.validate({ notify = "enabled" })
		end)
	end)

	it("should error on invalid file_patterns type", function()
		assert.error(function()
			Config.validate({ file_patterns = "*.lua" })
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

describe("Config deep merge", function()
	local Config = require("timecapsule.config")

	it("should deep-merge nested notify table", function()
		local config = Config.validate({ notify = { success = true } })

		assert.is_true(config.notify.success)
		assert.truthy(config.notify.failure)
		assert.truthy(config.notify.success_level)
		assert.truthy(config.notify.failure_level)
	end)

	it("should deep-merge nested push table", function()
		local config = Config.validate({ push = { enable = true } })

		assert.is_true(config.push.enable)
		assert.is_nil(config.push.branch)
	end)

	it("should deep-merge nested command table", function()
		local config = Config.validate({ command = { name = "MyToggle" } })

		assert.equal(config.command.name, "MyToggle")
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
		vim.fn.delete("/tmp/tc_test_backup", "rf")

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

-- Helper to reset module state between tests
local function reset_module()
	local Timecapsule = require("timecapsule")
	if Timecapsule.augroup then
		vim.api.nvim_del_augroup_by_id(Timecapsule.augroup)
		Timecapsule.augroup = nil
	end
	Timecapsule.config = nil
	Timecapsule.enabled = nil
end

describe("init_backup_repo", function()
	local Timecapsule = require("timecapsule")
	local tmp_base = "/tmp/tc_init_repo_test"

	after_each(function()
		Helpers.cleanup(tmp_base)
		reset_module()
	end)

	it("should initialize a git repo in the backup directory", function()
		local backup_dir = tmp_base .. "/repo"
		Timecapsule.config = { backup = backup_dir }

		local success, err = Timecapsule._init_backup_repo()
		assert.truthy(success)
		assert.is_nil(err)
		assert.truthy(vim.loop.fs_stat(backup_dir .. "/.git"))
	end)

	it("should be idempotent when called on an existing repo", function()
		local backup_dir = tmp_base .. "/idempotent"
		Timecapsule.config = { backup = backup_dir }

		local success1, _ = Timecapsule._init_backup_repo()
		assert.truthy(success1)

		local success2, err2 = Timecapsule._init_backup_repo()
		assert.truthy(success2)
		assert.is_nil(err2)
	end)

	it("should set git user.email and user.name", function()
		local backup_dir = tmp_base .. "/config"
		Timecapsule.config = { backup = backup_dir }

		Timecapsule._init_backup_repo()

		local email = vim.fn.systemlist({ "git", "-C", backup_dir, "config", "--local", "--get", "user.email" })
		assert.equal(vim.trim(email[1]), "timecapsule@local")

		local name = vim.fn.systemlist({ "git", "-C", backup_dir, "config", "--local", "--get", "user.name" })
		assert.equal(vim.trim(name[1]), "Timecapsule")
	end)
end)

describe("copy_to_backup", function()
	local Timecapsule = require("timecapsule")
	local tmp_base = "/tmp/tc_copy_test"

	after_each(function()
		Helpers.cleanup(tmp_base)
		reset_module()
	end)

	it("should copy a file to the backup directory", function()
		local backup_dir = tmp_base .. "/backup"
		local source_dir = tmp_base .. "/source"
		vim.fn.mkdir(source_dir, "p")

		local test_file = source_dir .. "/test.txt"
		vim.fn.writefile({ "hello world" }, test_file)

		Timecapsule.config = { backup = backup_dir }

		local success, backup_path = Timecapsule._copy_to_backup(test_file)
		assert.truthy(success)
		assert.truthy(backup_path)
		assert.truthy(vim.loop.fs_stat(backup_path))

		local content = vim.fn.readfile(backup_path)
		assert.equal(content[1], "hello world")
	end)

	it("should return false when copying a non-existent file", function()
		local backup_dir = tmp_base .. "/backup_missing"
		Timecapsule.config = { backup = backup_dir }

		local success, err = Timecapsule._copy_to_backup("/tmp/does_not_exist_at_all.txt")
		assert.is_false(success)
		assert.truthy(err)
		assert.truthy(string.find(err, "source file not found"))
	end)
end)

describe("_handle_write error paths", function()
	local Timecapsule = require("timecapsule")
	local tmp_base = "/tmp/tc_handle_write_test"

	after_each(function()
		Helpers.cleanup(tmp_base)
		reset_module()
		-- Reset to empty buffer
		vim.cmd("enew")
	end)

	it("should return early when disabled", function()
		local backup_dir = tmp_base .. "/disabled"
		Timecapsule.setup({ enable = false, backup = backup_dir })
		assert.is_false(Timecapsule.enabled)

		-- Create a test file and make it the current buffer
		local test_file = tmp_base .. "/disabled_src/test.txt"
		vim.fn.mkdir(vim.fn.fnamemodify(test_file, ":p:h"), "p")
		vim.fn.writefile({ "content" }, test_file)
		vim.cmd("edit " .. test_file)

		Timecapsule._handle_write()

		-- No backup should be created
		assert.is_false(Helpers.dir_exists(backup_dir), "Backup directory should not have been created")
	end)

	it("should return early with empty buffer name", function()
		local backup_dir = tmp_base .. "/empty_buf"
		Timecapsule.setup({ enable = true, backup = backup_dir })

		-- Create a new empty buffer and switch to it
		local buf = vim.api.nvim_create_buf(true, true)
		vim.api.nvim_set_current_buf(buf)

		Timecapsule._handle_write()

		assert.is_false(Helpers.dir_exists(backup_dir), "Backup directory should not have been created")
	end)

	it("should skip files inside the backup directory", function()
		local backup_dir = tmp_base .. "/backup_skip"
		Timecapsule.setup({ enable = true, backup = backup_dir })

		-- Create a file inside the backup dir
		local file_in_backup = backup_dir .. "/inside.txt"
		vim.fn.mkdir(backup_dir, "p")
		vim.fn.writefile({ "content" }, file_in_backup)
		vim.cmd("edit " .. file_in_backup)

		Timecapsule._handle_write()

		--[[ File is copied to backup dir (copy_to_backup runs before skip check), but nothing should be staged. ]]
		assert.truthy(Helpers.fs_stat_safe(file_in_backup), "File should exist in backup dir after copy")
		-- Use diff cached to check only staged files (status --porcelain also shows untracked)
		local staged = vim.fn.systemlist({ "git", "-C", backup_dir, "diff", "--cached", "--name-only" })
		assert.is_true(vim.tbl_isempty(staged), "No files should be staged")
	end)

	it("should skip files not matching file_patterns", function()
		local backup_dir = tmp_base .. "/patterns_skip"
		Timecapsule.setup({
			enable = true,
			backup = backup_dir,
			file_patterns = { "*.lua" },
		})

		-- Create a .txt file (not matching *.lua)
		local test_file = tmp_base .. "/skip_src/test.txt"
		vim.fn.mkdir(vim.fn.fnamemodify(test_file, ":p:h"), "p")
		vim.fn.writefile({ "content" }, test_file)
		vim.cmd("edit " .. test_file)

		Timecapsule._handle_write()

		-- No backup should be created
		assert.is_false(
			Helpers.dir_exists(backup_dir),
			"Backup directory should not have been created for non-matching file"
		)
	end)

	it("should skip commit when content is unchanged", function()
		local backup_dir = tmp_base .. "/no_change"
		Timecapsule.setup({ enable = true, backup = backup_dir })

		-- Create test file and trigger first write
		local test_file = tmp_base .. "/unchanged_src/test.txt"
		vim.fn.mkdir(vim.fn.fnamemodify(test_file, ":p:h"), "p")
		vim.fn.writefile({ "same content" }, test_file)
		vim.cmd("edit " .. test_file)

		Timecapsule._handle_write()

		-- Verify first commit was made
		local oneline = "--oneline"
		local logs = vim.fn.systemlist({ "git", "-C", backup_dir, "log", oneline })
		assert.is_true(#logs > 0, "First write should create a commit")
		local first_count = #logs

		-- Write same content again, then call _handle_write directly to avoid recursive BufWritePost
		vim.fn.writefile({ "same content" }, test_file)
		Timecapsule._handle_write()

		-- Second write should NOT create a new commit
		local logs_after = vim.fn.systemlist({ "git", "-C", backup_dir, "log", oneline })
		assert.equal(#logs_after, first_count, "Second write with same content should skip commit")
	end)
	it("should handle copy failure gracefully", function()
		local backup_dir = tmp_base .. "/copy_fail"
		Timecapsule.setup({ enable = true, backup = backup_dir })
		local test_file = tmp_base .. "/copy_fail_src/test.txt"
		vim.fn.mkdir(vim.fn.fnamemodify(test_file, ":p:h"), "p")
		vim.fn.writefile({ "content" }, test_file)
		vim.cmd("edit " .. test_file)
		Timecapsule._handle_write()
		-- First write creates a commit successfully
		local logs_before = vim.fn.systemlist({ "git", "-C", backup_dir, "log", "--oneline" })
		assert.is_true(#logs_before > 0, "First write should create a commit")
		-- Change backup to a non-existent path to force mkdir failure
		Timecapsule.config.backup = "/proc/nonexistent_tc_copy_fail"
		-- Modify source and trigger write — should fail gracefully
		vim.fn.writefile({ "modified" }, test_file)
		Timecapsule._handle_write()
		-- Verify no crash and commit count unchanged
		assert.equal(
			#logs_before,
			#vim.fn.systemlist({ "git", "-C", backup_dir, "log", "--oneline" }),
			"No new commit after failed operation"
		)
	end)
end)

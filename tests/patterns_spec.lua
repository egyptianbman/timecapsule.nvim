describe("File pattern filtering", function()
	local Patterns = require("timecapsule")

	it("should stage all files by default with exclusions", function()
		Patterns.setup({ enable = true })

		assert.is_false(Patterns.should_stage("node_modules/file.js"))
		assert.is_false(Patterns.should_stage("package-lock.json"))
		assert.is_false(Patterns.should_stage("dist/output.js"))
		assert.is_false(Patterns.should_stage("build/output.js"))

		assert.truthy(Patterns.should_stage("src/app.js"))
		assert.truthy(Patterns.should_stage("src/utils/helper.js"))
	end)

	it("should filter with custom file_patterns", function()
		Patterns.setup({ enable = true, file_patterns = { "*.lua" } })

		assert.truthy(Patterns.should_stage("src/script.lua"))
		assert.is_false(Patterns.should_stage("src/script.js"))
		assert.is_false(Patterns.should_stage("package-lock.json"))
	end)

	it("should handle negation patterns", function()
		Patterns.setup({ enable = true, file_patterns = { "*.lua", "!src/test.lua" } })

		assert.truthy(Patterns.should_stage("src/main.lua"))
		assert.is_false(Patterns.should_stage("src/test.lua"))
	end)

	it("should handle multiple patterns with mixed inclusion/exclusion", function()
		Patterns.setup({ enable = true, file_patterns = { "*.js", "!node_modules/**", "!*.min.js" } })

		assert.truthy(Patterns.should_stage("src/app.js"))
		assert.is_false(Patterns.should_stage("src/app.min.js"))
		assert.is_false(Patterns.should_stage("node_modules/pkg/index.js"))
		assert.is_false(Patterns.should_stage("dist/bundle.min.js"))
	end)
end)

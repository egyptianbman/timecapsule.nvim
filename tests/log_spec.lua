describe("Logging", function()
	local Log = require("timecapsule.log")

	it("should have success and failure functions", function()
		assert.truthy(Log.success)
		assert.truthy(Log.failure)
		assert.truthy(Log.notify)
	end)
end)

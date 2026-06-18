if vim.fn.has("nvim-0.10") ~= 1 then
	vim.notify("Timecapsule requires Neovim 0.10+", vim.log.levels.ERROR)
	return
end

local ok, timecapsule = pcall(require, "timecapsule")
if not ok then
	vim.notify("Failed to load timecapsule: " .. tostring(timecapsule), vim.log.levels.ERROR)
	return
end

timecapsule.setup()

vim.api.nvim_create_user_command("TimecapsuleToggle", function()
	timecapsule.toggle()
end, { desc = "Toggle timecapsule auto-commit" })

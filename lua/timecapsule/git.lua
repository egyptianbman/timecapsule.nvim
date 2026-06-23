local M = {}

---@return boolean
function M.is_in_repo()
  local result = vim.fn.systemlist { "git", "rev-parse", "--is-inside-work-tree" }
  return result[1] == "true"
end

---@param filepath string
---@return boolean success
---@return string|nil error
function M.add(filepath)
  local output = vim.fn.system { "git", "add", "--", filepath }
  if vim.v.shell_error ~= 0 then return false, "git add failed: " .. vim.trim(output) end
  return true, nil
end

---@param filepath string
---@param message string
---@return boolean success
---@return string|nil error
function M.commit(filepath, message)
  local output = vim.fn.system { "git", "commit", "-m", message, "--", filepath }
  if vim.v.shell_error ~= 0 then return false, "git commit failed: " .. vim.trim(output) end
  return true, nil
end

---@param backup_dir string
---@param branch string
---@return boolean|nil success (nil=skipped, true=success, false=failed)
---@return string|nil error
function M.push(backup_dir, branch)
  -- Check if remote exists
  local remotes = vim.fn.systemlist { "git", "-C", backup_dir, "remote" }
  if not remotes or next(remotes) == nil or not vim.tbl_contains(remotes, "origin") then
    return nil, "no remote configured (add origin or set push.enable = false)"
  end
  local output = vim.fn.system { "git", "-C", backup_dir, "push", "origin", branch }
  if vim.v.shell_error ~= 0 then return false, "git push failed: " .. vim.trim(output) end
  return true, nil -- Signal success
end

---@return boolean
function M.is_clean()
  local result = vim.fn.systemlist { "git", "status", "--porcelain" }
  return next(result) == nil
end

return M

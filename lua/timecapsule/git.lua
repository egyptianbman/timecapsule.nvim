local M = {}

---@return boolean
function M.is_in_repo()
  local result = vim.fn.systemlist("git rev-parse --is-inside-work-tree")
  return result[1] == "true"
end

---@param filepath string
---@return boolean success
---@return string|nil error
function M.add(filepath)
  local ok, output = pcall(vim.fn.system, { "git", "add", "--", filepath })
  if not ok then
    return false, "git add failed: " .. output
  end
  local code = vim.v.shell_error
  if code ~= 0 then
    return false, output
  end
  return true, nil
end

---@param filepath string
---@param message string
---@return boolean success
---@return string|nil error
function M.commit(filepath, message)
  local ok, output = pcall(vim.fn.system, { "git", "commit", "-m", message, "--", filepath })
  if not ok then
    return false, "git commit failed: " .. output
  end
  local code = vim.v.shell_error
  if code ~= 0 then
    return false, output
  end
  return true, nil
end

---@param backup_dir string
---@param branch string
---@return boolean|nil success (nil=skipped, true=success, false=failed)
---@return string|nil error
function M.push(backup_dir, branch)
  -- Check if remote exists
  local remotes = vim.fn.systemlist("git -C " .. backup_dir .. " remote")
  if vim.tbl_isempty(remotes) or not vim.tbl_contains(remotes, "origin") then
    return nil, "no remote configured (add origin or set push.enable = false)"
  end
  local ok, output = pcall(vim.fn.system, { "git", "-C", backup_dir, "push", "origin", branch })
  if not ok then
    return false, "git push failed: " .. output
  end
  local code = vim.v.shell_error
  if code ~= 0 then
    return false, output
  end
  return true, nil -- Signal success
end

---@return boolean
function M.is_clean()
  local result = vim.fn.systemlist("git status --porcelain")
  return vim.tbl_isempty(result)
end

return M

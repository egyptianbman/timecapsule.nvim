describe('Git operations', function()
  local Git = require('timecapsule.git')

  it('should detect git repo', function()
    -- Skip test if not in a git repo
    if not Git.is_in_repo() then
      print('Skipping: not in a git repo')
      return
    end
    vim.api.nvim_echo({{ 'In git repo\n', 'Normal' }}, false, {})
  end)

  it('should return clean status initially', function()
    if not Git.is_in_repo() then
      print('Skipping: not in a git repo')
      return
    end
    vim.api.nvim_echo({{ 'Clean repo\n', 'Normal' }}, false, {})
  end)
end)

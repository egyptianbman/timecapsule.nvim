local Helpers = require "tests.helpers"

-- Safely change into a directory and restore cwd on exit, even on assertion failure

local function with_cwd(dir, fn)
  local orig_dir = vim.fn.getcwd()
  vim.fn.chdir(dir)
  local ok, result = pcall(fn)
  -- Restore cwd even on assertion failure; wrap in pcall in case orig_dir was deleted
  pcall(vim.fn.chdir, orig_dir)
  if not ok then error(result) end
  return result
end

describe("Git operations", function()
  local Git = require "timecapsule.git"
  local tmp_base = "/tmp/tc_git_test"

  after_each(function() Helpers.cleanup(tmp_base) end)

  it("should detect being inside a git repo", function()
    local repo = tmp_base .. "/inside"
    vim.fn.mkdir(repo, "p")
    vim.fn.system { "git", "init", repo }
    assert.equal(0, vim.v.shell_error, "git init failed")
    vim.fn.system { "git", "-C", repo, "config", "user.email", "test@test.com" }
    with_cwd(repo, function() assert.truthy(Git.is_in_repo()) end)

    -- Verify the repo was actually created
    assert.truthy(Helpers.fs_stat_safe(repo .. "/.git"))
  end)

  it("should return false when outside a git repo", function()
    local outside = tmp_base .. "/outside"
    Helpers.cleanup(outside)
    vim.fn.mkdir(outside, "p")

    with_cwd(outside, function() assert.is_false(Git.is_in_repo()) end)
  end)

  it("should add a file to the index", function()
    local repo = tmp_base .. "/add_test"
    vim.fn.mkdir(repo, "p")
    vim.fn.system { "git", "init", repo }
    vim.fn.system { "git", "-C", repo, "config", "user.email", "test@test.com" }
    vim.fn.system { "git", "-C", repo, "config", "user.name", "Test" }

    -- Create a file inside the repo
    local test_file = repo .. "/test.txt"
    vim.fn.writefile({ "hello" }, test_file)

    with_cwd(repo, function()
      local success, err = Git.add "test.txt"
      assert.truthy(success)
      assert.is_nil(err)
    end)
  end)

  it("should return false when adding a non-existent file", function()
    local repo = tmp_base .. "/add_missing"
    vim.fn.mkdir(repo, "p")
    vim.fn.system { "git", "init", repo }

    with_cwd(repo, function()
      local success, err = Git.add "does_not_exist.txt"
      assert.is_false(success)
      assert.truthy(err)
      assert.truthy(string.find(err, "git add failed"))
    end)
  end)

  it("should commit a staged file", function()
    local repo = tmp_base .. "/commit_test"
    vim.fn.mkdir(repo, "p")
    vim.fn.system { "git", "init", repo }
    vim.fn.system { "git", "-C", repo, "config", "user.email", "test@test.com" }
    vim.fn.system { "git", "-C", repo, "config", "user.name", "Test" }

    local test_file = repo .. "/test.txt"
    vim.fn.writefile({ "content" }, test_file)

    with_cwd(repo, function()
      Git.add "test.txt"
      local success, err = Git.commit("test.txt", "initial commit")
      assert.truthy(success)
      assert.is_nil(err)
    end)
  end)

  it("should return false when committing without staged changes", function()
    local repo = tmp_base .. "/commit_empty"
    vim.fn.mkdir(repo, "p")
    vim.fn.system { "git", "init", repo }
    vim.fn.system { "git", "-C", repo, "config", "user.email", "test@test.com" }
    vim.fn.system { "git", "-C", repo, "config", "user.name", "Test" }

    -- No files staged — commit should fail
    with_cwd(repo, function()
      local success, err = Git.commit("nonexistent.txt", "no changes")
      assert.is_false(success)
      assert.truthy(err)
    end)
  end)

  it("should push to origin when remote is configured", function()
    local bare = tmp_base .. "/origin.git"
    local repo = tmp_base .. "/push_test"

    Helpers.cleanup(bare)
    Helpers.cleanup(repo)

    -- Create bare repo as origin
    vim.fn.system { "git", "init", "--bare", bare }
    -- Allow pushes to non-fast-forward on bare repo
    vim.fn.system { "git", "-C", bare, "config", "receive.denyCurrentBranch", "ignore" }

    -- Create and configure regular repo
    vim.fn.mkdir(repo, "p")
    vim.fn.system { "git", "init", repo }
    vim.fn.system { "git", "-C", repo, "config", "user.email", "test@test.com" }
    vim.fn.system { "git", "-C", repo, "config", "user.name", "Test" }

    -- Add origin remote and make an initial commit
    vim.fn.system { "git", "-C", repo, "remote", "add", "origin", bare }
    local test_file = repo .. "/test.txt"
    vim.fn.writefile({ "content" }, test_file)
    vim.fn.system { "git", "-C", repo, "add", "--", "test.txt" }
    vim.fn.system { "git", "-C", repo, "commit", "-m", "initial" }

    -- Detect actual branch name (main vs master)
    local branch_result = vim.fn.systemlist { "git", "-C", repo, "branch", "--show-current" }
    local branch = branch_result[1] and vim.trim(branch_result[1]) or "master"
    local success, err = Git.push(repo, branch)
    assert.truthy(success)
    assert.is_nil(err)
  end)

  it("should return nil when no remote is configured", function()
    local repo = tmp_base .. "/no_remote"
    vim.fn.mkdir(repo, "p")
    vim.fn.system { "git", "init", repo }
    vim.fn.system { "git", "-C", repo, "config", "user.email", "test@test.com" }
    vim.fn.system { "git", "-C", repo, "config", "user.name", "Test" }

    -- Make an initial commit so branch exists
    local test_file = repo .. "/test.txt"
    vim.fn.writefile({ "content" }, test_file)
    vim.fn.system { "git", "-C", repo, "add", "--", "test.txt" }
    vim.fn.system { "git", "-C", repo, "commit", "-m", "initial" }

    local branch_result = vim.fn.systemlist { "git", "-C", repo, "branch", "--show-current" }
    local branch = branch_result[1] and vim.trim(branch_result[1]) or "master"
    local success, err = Git.push(repo, branch)
    assert.is_nil(success)
    assert.truthy(err)
    assert.truthy(string.find(err, "no remote"))
  end)

  it("should return false when push fails", function()
    local repo = tmp_base .. "/push_fail"
    vim.fn.mkdir(repo, "p")
    vim.fn.system { "git", "init", repo }
    vim.fn.system { "git", "-C", repo, "config", "user.email", "test@test.com" }
    vim.fn.system { "git", "-C", repo, "config", "user.name", "Test" }

    -- Add a remote that doesn't exist
    vim.fn.system { "git", "-C", repo, "remote", "add", "origin", "https://invalid.example.com/nonexistent.git" }

    -- Make an initial commit
    local test_file = repo .. "/test.txt"
    vim.fn.writefile({ "content" }, test_file)
    vim.fn.system { "git", "-C", repo, "add", "--", "test.txt" }
    vim.fn.system { "git", "-C", repo, "commit", "-m", "initial" }

    -- Detect actual branch name (main vs master)
    local branch_result = vim.fn.systemlist { "git", "-C", repo, "branch", "--show-current" }
    local branch = branch_result[1] and vim.trim(branch_result[1]) or "master"
    local success, err = Git.push(repo, branch)
    assert.is_false(success)
    assert.truthy(err)
    assert.truthy(string.find(err, "git push failed"))
  end)
  it("should return false when pushing a new branch that does not exist on remote", function()
    local bare = tmp_base .. "/new_branch_origin.git"
    local repo = tmp_base .. "/push_new_branch"

    Helpers.cleanup(bare)
    Helpers.cleanup(repo)

    -- Create bare repo as origin (no commits yet)
    vim.fn.system { "git", "init", "--bare", bare }

    -- Create and configure regular repo
    vim.fn.mkdir(repo, "p")
    vim.fn.system { "git", "init", repo }
    vim.fn.system { "git", "-C", repo, "config", "user.email", "test@test.com" }
    vim.fn.system { "git", "-C", repo, "config", "user.name", "Test" }

    -- Add origin remote and make an initial commit
    vim.fn.system { "git", "-C", repo, "remote", "add", "origin", bare }
    local test_file = repo .. "/test.txt"
    vim.fn.writefile({ "content" }, test_file)
    vim.fn.system { "git", "-C", repo, "add", "--", "test.txt" }
    vim.fn.system { "git", "-C", repo, "commit", "-m", "initial" }

    -- Push a new branch that does not exist on the remote
    local success, err = Git.push(repo, "new-feature")
    assert.is_false(success)
    assert.truthy(err)
    assert.truthy(string.find(err, "git push failed"))
  end)

  it("should return true when working tree is clean", function()
    local repo = tmp_base .. "/clean"
    vim.fn.mkdir(repo, "p")
    vim.fn.system { "git", "init", repo }
    vim.fn.system { "git", "-C", repo, "config", "user.email", "test@test.com" }
    vim.fn.system { "git", "-C", repo, "config", "user.name", "Test" }

    local test_file = repo .. "/test.txt"
    vim.fn.writefile({ "content" }, test_file)
    vim.fn.system { "git", "-C", repo, "add", "--", "test.txt" }
    vim.fn.system { "git", "-C", repo, "commit", "-m", "initial" }

    with_cwd(repo, function() assert.is_true(Git.is_clean()) end)
  end)

  it("should return false when working tree has staged changes", function()
    local repo = tmp_base .. "/dirty_staged"
    vim.fn.mkdir(repo, "p")
    vim.fn.system { "git", "init", repo }
    vim.fn.system { "git", "-C", repo, "config", "user.email", "test@test.com" }
    vim.fn.system { "git", "-C", repo, "config", "user.name", "Test" }

    local test_file = repo .. "/test.txt"
    vim.fn.writefile({ "content" }, test_file)
    vim.fn.system { "git", "-C", repo, "add", "--", "test.txt" }
    vim.fn.system { "git", "-C", repo, "commit", "-m", "initial" }

    -- Modify and stage another file
    local new_file = repo .. "/new.txt"
    vim.fn.writefile({ "new content" }, new_file)
    vim.fn.system { "git", "-C", repo, "add", "--", "new.txt" }

    with_cwd(repo, function() assert.is_false(Git.is_clean()) end)
  end)

  it("should return false when working tree has unstaged changes", function()
    local repo = tmp_base .. "/dirty_unstaged"
    vim.fn.mkdir(repo, "p")
    vim.fn.system { "git", "init", repo }
    vim.fn.system { "git", "-C", repo, "config", "user.email", "test@test.com" }
    vim.fn.system { "git", "-C", repo, "config", "user.name", "Test" }

    local test_file = repo .. "/test.txt"
    vim.fn.writefile({ "content" }, test_file)
    vim.fn.system { "git", "-C", repo, "add", "--", "test.txt" }
    vim.fn.system { "git", "-C", repo, "commit", "-m", "initial" }

    -- Modify file without staging
    vim.fn.writefile({ "modified" }, test_file)

    with_cwd(repo, function() assert.is_false(Git.is_clean()) end)
  end)
end)

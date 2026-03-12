///|
async fn switch_wbtest_case_tracking_config_uses_short_branch_names() -> Unit raise Error {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-switch-tracking-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"
  let git_dir = repo_dir + "/.git"

  add_test_run_git(root, ["init", "--initial-branch=main", "-q", "repo"])
  add_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  add_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  fs.write_string(repo_dir + "/init.t", "main\n")
  add_test_run_git(repo_dir, ["add", "init.t"])
  add_test_run_git(repo_dir, ["commit", "-q", "-m", "main"])
  add_test_run_git(repo_dir, ["branch", "foo"])
  add_test_run_git(repo_dir, ["config", "branch.foo.remote", "origin"])
  add_test_run_git(repo_dir, ["config", "branch.foo.merge", "refs/heads/foo"])

  switch_apply_tracking_config(
    fs,
    fs,
    git_dir,
    "refs/heads/foo2",
    Some("foo"),
    Some("inherit"),
  )
  switch_apply_tracking_config(
    fs,
    fs,
    git_dir,
    "refs/heads/foo4",
    Some("foo"),
    Some("direct"),
  )

  let (_, branches) = @bitlib.read_repo_config(fs, git_dir)
  match branches.get("foo2") {
    Some(cfg) => {
      assert_eq(cfg.remote, Some("origin"))
      assert_eq(cfg.merges, ["refs/heads/foo"])
    }
    None => fail("expected inherited tracking config for foo2")
  }
  match branches.get("foo4") {
    Some(cfg) => {
      assert_eq(cfg.remote, Some("."))
      assert_eq(cfg.merges, ["refs/heads/foo"])
    }
    None => fail("expected direct tracking config for foo4")
  }
  assert_true(branches.get("refs/heads/foo2") is None)
  assert_true(branches.get("refs/heads/foo4") is None)

  cleanup_tree(fs, root)
}

///|
async fn switch_wbtest_case_branch_in_use_path_accepts_full_ref() -> Unit raise Error {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-switch-branch-in-use-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"
  let linked_dir = repo_dir + "/wt1"

  add_test_run_git(root, ["init", "--initial-branch=main", "-q", "repo"])
  add_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  add_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  fs.write_string(repo_dir + "/init.t", "main\n")
  add_test_run_git(repo_dir, ["add", "init.t"])
  add_test_run_git(repo_dir, ["commit", "-q", "-m", "main"])
  add_test_run_git(repo_dir, ["checkout", "-q", "-b", "shared"])
  fs.write_string(repo_dir + "/init.t", "shared\n")
  add_test_run_git(repo_dir, ["commit", "-qam", "shared"])
  add_test_run_git(repo_dir, ["worktree", "add", "-f", "wt1", "shared"])
  add_test_run_git(linked_dir, ["checkout", "--detach", "-q", "HEAD"])
  let expected_repo = add_test_git_stdout(repo_dir, [
      "rev-parse", "--show-toplevel",
    ])
    |> add_test_trim_trailing_newline

  assert_eq(
    switch_branch_in_use_path(fs, linked_dir, "refs/heads/shared"),
    Some(expected_repo),
  )

  cleanup_tree(fs, root)
}

///|
async fn switch_wbtest_case_orphan_preserves_index_entries() -> Unit raise Error {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-switch-orphan-index-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"
  let git_dir = repo_dir + "/.git"

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")

  add_test_run_git(root, ["init", "--initial-branch=main", "-q", "repo"])
  add_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  add_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  fs.write_string(repo_dir + "/init.t", "main\n")
  add_test_run_git(repo_dir, ["add", "init.t"])
  add_test_run_git(repo_dir, ["commit", "-q", "-m", "main"])

  @sys.set_env_var("GIT_SHIM_CWD", repo_dir)
  @sys.set_env_var("GIT_SHIM_PWD", repo_dir)
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  handle_switch(["--orphan", "unborn"])

  let entries = @bitlib.read_index_entries(fs, git_dir)
  assert_true(entries.length() > 0)

  add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  add_test_restore_env("GIT_DIR", prev_git_dir)
  add_test_restore_env("GIT_WORK_TREE", prev_work_tree)
  cleanup_tree(fs, root)
}

///|
async fn switch_wbtest_case_orphan_allows_cached_rm() -> Unit raise Error {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-switch-orphan-cached-rm-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")

  add_test_run_git(root, ["init", "--initial-branch=main", "-q", "repo"])
  add_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  add_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])
  fs.write_string(repo_dir + "/init.t", "main\n")
  add_test_run_git(repo_dir, ["add", "init.t"])
  add_test_run_git(repo_dir, ["commit", "-q", "-m", "main"])

  @sys.set_env_var("GIT_SHIM_CWD", repo_dir)
  @sys.set_env_var("GIT_SHIM_PWD", repo_dir)
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  handle_switch(["--orphan", "unborn"])
  handle_rm(["--cached", "-r", "."])

  assert_eq(add_test_git_stdout(repo_dir, ["ls-files"]), "")
  assert_true(fs.is_file(repo_dir + "/init.t"))

  add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  add_test_restore_env("GIT_DIR", prev_git_dir)
  add_test_restore_env("GIT_WORK_TREE", prev_work_tree)
  cleanup_tree(fs, root)
}

///|
async fn switch_wbtest_case_create_branch_in_unborn_repo_keeps_ref_unborn() -> Unit raise Error {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-switch-unborn-create-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"
  let git_dir = repo_dir + "/.git"

  let prev_shim_cwd = @sys.get_env_var("GIT_SHIM_CWD")
  let prev_shim_pwd = @sys.get_env_var("GIT_SHIM_PWD")
  let prev_git_dir = @sys.get_env_var("GIT_DIR")
  let prev_work_tree = @sys.get_env_var("GIT_WORK_TREE")

  add_test_run_git(root, ["init", "--initial-branch=main", "-q", "repo"])
  add_test_run_git(repo_dir, ["config", "user.name", "Test User"])
  add_test_run_git(repo_dir, ["config", "user.email", "test@example.com"])

  @sys.set_env_var("GIT_SHIM_CWD", repo_dir)
  @sys.set_env_var("GIT_SHIM_PWD", repo_dir)
  @sys.unset_env_var("GIT_DIR")
  @sys.unset_env_var("GIT_WORK_TREE")
  handle_switch(["-c", "topic"])

  assert_eq(decode_bytes(fs.read_file(git_dir + "/HEAD")), "ref: refs/heads/topic\n")
  assert_true(not(fs.is_file(git_dir + "/refs/heads/topic")))

  add_test_restore_env("GIT_SHIM_CWD", prev_shim_cwd)
  add_test_restore_env("GIT_SHIM_PWD", prev_shim_pwd)
  add_test_restore_env("GIT_DIR", prev_git_dir)
  add_test_restore_env("GIT_WORK_TREE", prev_work_tree)

  fs.write_string(repo_dir + "/topic.t", "topic\n")
  add_test_run_git(repo_dir, ["add", "topic.t"])
  add_test_run_git(repo_dir, ["commit", "-q", "-m", "topic"])

  assert_eq(
    add_test_git_stdout(repo_dir, ["rev-parse", "--abbrev-ref", "HEAD"])
      |> add_test_trim_trailing_newline,
    "topic",
  )

  cleanup_tree(fs, root)
}

///|
async test "switch: helper cases stay compatible" {
  switch_wbtest_case_tracking_config_uses_short_branch_names()
  switch_wbtest_case_branch_in_use_path_accepts_full_ref()
  switch_wbtest_case_orphan_preserves_index_entries()
  switch_wbtest_case_orphan_allows_cached_rm()
  switch_wbtest_case_create_branch_in_unborn_repo_keeps_ref_unborn()
}

///|
async fn sparse_checkout_wbtest_run_git(
  cwd : String,
  args : Array[String],
) -> Unit raise Error {
  let code = @process.run("git", args[:], inherit_env=true, cwd~)
  assert_eq(code, 0)
}

///|
fn sparse_checkout_wbtest_restore_cwd(prev : String?) -> Unit {
  match prev {
    Some(value) => @sys.set_env_var("GIT_SHIM_CWD", value)
    None => @sys.unset_env_var("GIT_SHIM_CWD")
  }
}

///|
async test "sparse-checkout: init re-enables sparse mode after disable and branch commits" {
  @bitnative.init_native_io()
  let fs = OsFs::new()
  let root = "/tmp/bit-test-sparse-reinit-" +
    get_current_timestamp().to_string()
  cleanup_tree(fs, root)
  fs.mkdir_p(root)
  let repo_dir = root + "/repo"

  sparse_checkout_wbtest_run_git(root, ["init", "-q", "repo"])
  sparse_checkout_wbtest_run_git(repo_dir, ["config", "user.name", "Test User"])
  sparse_checkout_wbtest_run_git(repo_dir, [
    "config", "user.email", "test@example.com",
  ])
  fs.write_string(repo_dir + "/a", "a\n")
  fs.write_string(repo_dir + "/b", "b\n")
  fs.mkdir_p(repo_dir + "/dir")
  fs.write_string(repo_dir + "/dir/c", "c\n")
  sparse_checkout_wbtest_run_git(repo_dir, ["add", "a", "b", "dir/c"])
  sparse_checkout_wbtest_run_git(repo_dir, ["commit", "-q", "-m", "initial"])
  sparse_checkout_wbtest_run_git(repo_dir, ["branch", "-M", "main"])

  let prev_cwd_init = @sys.get_env_var("GIT_SHIM_CWD")
  @sys.set_env_var("GIT_SHIM_CWD", repo_dir)
  handle_sparse_checkout(["init", "--no-cone"])
  handle_sparse_checkout(["set", "/*", "!b", "!/*/"])
  sparse_checkout_wbtest_restore_cwd(prev_cwd_init)
  assert_false(fs.is_file(repo_dir + "/b"))
  assert_false(fs.is_dir(repo_dir + "/dir"))

  let prev_cwd_disable = @sys.get_env_var("GIT_SHIM_CWD")
  @sys.set_env_var("GIT_SHIM_CWD", repo_dir)
  handle_sparse_checkout(["disable"])
  sparse_checkout_wbtest_restore_cwd(prev_cwd_disable)
  let skip_paths_after_disable = @bitlib.read_skip_worktree_paths(
    fs,
    repo_dir + "/.git",
  )
  assert_eq(skip_paths_after_disable.length(), 0)
  assert_true(fs.is_file(repo_dir + "/b"))
  assert_true(fs.is_dir(repo_dir + "/dir"))

  sparse_checkout_wbtest_run_git(repo_dir, [
    "checkout", "-q", "-b", "branchY", "main",
  ])
  fs.write_string(repo_dir + "/b", "branch-y\n")
  sparse_checkout_wbtest_run_git(repo_dir, [
    "commit", "-qam", "modified-b-in-branchY",
  ])
  sparse_checkout_wbtest_run_git(repo_dir, [
    "checkout", "-q", "-b", "branchX", "main",
  ])
  fs.write_string(repo_dir + "/b", "branch-x\n")
  sparse_checkout_wbtest_run_git(repo_dir, [
    "commit", "-qam", "modified-b-in-branchX",
  ])

  let prev_cwd_reinit = @sys.get_env_var("GIT_SHIM_CWD")
  @sys.set_env_var("GIT_SHIM_CWD", repo_dir)
  handle_sparse_checkout(["init"])
  sparse_checkout_wbtest_restore_cwd(prev_cwd_reinit)

  let config = @utf8.decode_lossy(fs.read_file(repo_dir + "/.git/config")[:])
  assert_true(config.contains("sparseCheckout = true"))
  assert_false(fs.is_file(repo_dir + "/b"))
  assert_false(fs.is_dir(repo_dir + "/dir"))

  cleanup_tree(fs, root)
}

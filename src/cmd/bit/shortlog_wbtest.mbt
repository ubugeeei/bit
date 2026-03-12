///|
test "shortlog: detached --glob consumes following token verbatim" {
  assert_eq(shortlog_strip_detached_glob_args(["--glob", "heads/*", "main"]), [
    "main",
  ])
  assert_eq(shortlog_strip_detached_glob_args(["--glob", "-e", "main"]), [
    "main",
  ])
  assert_eq(
    shortlog_strip_detached_glob_args(["-n", "--glob", "--symbolic", "main"]),
    ["-n", "main"],
  )
}

///| WASM Component git operations implementation

///|
fn make_fs() -> WasmFs {
  WasmFs::new()
}

///|
fn[T] wrap_error(f : () -> T raise @bit.GitError) -> Result[T, String] {
  Ok(f()) catch {
    @bit.GitError::IoError(e) => Err(e)
    @bit.GitError::InvalidObject(e) => Err(e)
    @bit.GitError::HashMismatch(a, b) => Err("hash mismatch: \{a} vs \{b}")
    @bit.GitError::PackfileError(e) => Err("packfile error: \{e}")
    @bit.GitError::ProtocolError(e) => Err("protocol error: \{e}")
  }
}

///|
fn join_path(base : String, name : String) -> String {
  if base.length() == 0 {
    name
  } else if base == "/" {
    "/" + name
  } else {
    base + "/" + name
  }
}

///|
fn resolve_git_dir(fs : WasmFs, root : String) -> String {
  let git_path = join_path(root, ".git")
  if fs.is_dir(git_path) {
    git_path
  } else {
    git_path
  }
}

///|
fn is_tree_mode(mode : String) -> Bool {
  mode == "40000" || mode == "040000"
}

///|
fn parse_octal_mode(s : String) -> Int {
  let mut result = 0
  for c in s {
    if c < '0' || c > '7' {
      continue
    }
    result = result * 8 + (c.to_int() - '0'.to_int())
  }
  result
}

///|
fn collect_staged_changes_db(
  db : @bitlib.ObjectDb,
  fs : WasmFs,
  tree_id : @bit.ObjectId,
  prefix : String,
  index_map : Map[String, @bitlib.IndexEntry],
  staged_modified : Array[String],
  staged_deleted : Array[String],
) -> Unit raise @bit.GitError {
  let tree_obj = db.get(fs, tree_id)
  match tree_obj {
    None => raise @bit.GitError::InvalidObject("Missing tree object")
    Some(obj) => {
      if obj.obj_type != @bit.ObjectType::Tree {
        raise @bit.GitError::InvalidObject("Object is not a tree")
      }
      let entries = @bit.parse_tree(obj.data)
      for entry in entries {
        let path = if prefix.length() == 0 {
          entry.name
        } else {
          prefix + "/" + entry.name
        }
        if is_tree_mode(entry.mode) {
          collect_staged_changes_db(
            db,
            fs,
            entry.id,
            path,
            index_map,
            staged_modified,
            staged_deleted,
          )
        } else {
          let mode = parse_octal_mode(entry.mode)
          match index_map.get(path) {
            Some(index_entry) => {
              if index_entry.id != entry.id || index_entry.mode != mode {
                staged_modified.push(path)
              }
              index_map.remove(path)
            }
            None => staged_deleted.push(path)
          }
        }
      }
    }
  }
}

///|
fn collect_staged_changes_from_head(
  fs : WasmFs,
  git_dir : String,
  index_map : Map[String, @bitlib.IndexEntry],
  staged_modified : Array[String],
  staged_deleted : Array[String],
) -> Unit raise @bit.GitError {
  match @bitlib.resolve_head_commit(fs, git_dir) {
    None => ()
    Some(commit_id) => {
      let db = @bitlib.ObjectDb::load_lazy(fs, git_dir)
      match db.get(fs, commit_id) {
        None => ()
        Some(obj) => {
          if obj.obj_type != @bit.ObjectType::Commit {
            raise @bit.GitError::InvalidObject("Object is not a commit")
          }
          let info = @bit.parse_commit(obj.data)
          collect_staged_changes_db(
            db,
            fs,
            info.tree,
            "",
            index_map,
            staged_modified,
            staged_deleted,
          )
        }
      }
    }
  }
}

///|
fn porcelain_lines_from_status(s : StatusResult) -> Array[String] {
  let lines : Array[String] = []
  for p in s.staged_added {
    lines.push("A  " + p)
  }
  for p in s.staged_modified {
    lines.push("M  " + p)
  }
  for p in s.staged_deleted {
    lines.push("D  " + p)
  }
  for p in s.unstaged_modified {
    lines.push(" M " + p)
  }
  for p in s.unstaged_deleted {
    lines.push(" D " + p)
  }
  for p in s.untracked {
    lines.push("?? " + p)
  }
  lines
}

// === git-ops exports ===

///|
pub fn git_init(root : String, default_branch : String) -> Result[Unit, String] {
  let fs = make_fs()
  wrap_error(() => @bitlib.init_repo(fs, root, default_branch~))
}

///|
pub fn add(root : String, paths : Array[String]) -> Result[Unit, String] {
  let fs = make_fs()
  wrap_error(() => @bitlib.add_paths(fs, fs, root, paths))
}

///|
pub fn status(root : String) -> Result[StatusResult, String] {
  let fs = make_fs()
  wrap_error(() => {
    let git_dir = resolve_git_dir(fs, root)
    let entries = @bitlib.read_index_entries(fs, git_dir)
    let index_map : Map[String, @bitlib.IndexEntry] = {}
    for entry in entries {
      index_map[entry.path] = entry
    }
    let files = @ignore.list_working_files(fs, root)
    files.sort()
    let visited : Map[String, Bool] = {}
    let untracked : Array[String] = []
    let unstaged_modified : Array[String] = []
    for rel_path in files {
      visited[rel_path] = true
      match index_map.get(rel_path) {
        Some(index_entry) => {
          let abs_path = join_path(root, rel_path)
          let content = (fs as &@bit.RepoFileSystem).read_file(abs_path) catch {
            _ => continue
          }
          let worktree_id = @bit.hash_blob(content)
          if worktree_id != index_entry.id {
            unstaged_modified.push(rel_path)
          }
        }
        None => untracked.push(rel_path)
      }
    }
    let unstaged_deleted : Array[String] = []
    for entry in entries {
      if visited.get(entry.path) is Some(_) {
        continue
      }
      let abs_path = join_path(root, entry.path)
      if not(fs.is_file(abs_path)) {
        unstaged_deleted.push(entry.path)
      }
    }
    let staged_index_map : Map[String, @bitlib.IndexEntry] = {}
    for entry in entries {
      staged_index_map[entry.path] = entry
    }
    let staged_modified : Array[String] = []
    let staged_deleted : Array[String] = []
    collect_staged_changes_from_head(
      fs, git_dir, staged_index_map, staged_modified, staged_deleted,
    )
    let staged_added : Array[String] = []
    for item in staged_index_map.to_array() {
      let (path, _) = item
      staged_added.push(path)
    }
    staged_added.sort()
    staged_modified.sort()
    staged_deleted.sort()
    unstaged_modified.sort()
    unstaged_deleted.sort()
    untracked.sort()
    StatusResult::{
      staged_added,
      staged_modified,
      staged_deleted,
      unstaged_modified,
      unstaged_deleted,
      untracked,
    }
  })
}

///|
pub fn status_porcelain(root : String) -> Result[Array[String], String] {
  match status(root) {
    Ok(s) => Ok(porcelain_lines_from_status(s))
    Err(e) => Err(e)
  }
}

///|
pub fn commit(
  root : String,
  message : String,
  author : String,
  timestamp : Int64,
) -> Result[String, String] {
  let fs = make_fs()
  wrap_error(() => {
    let id = @bitlib.commit(fs, fs, root, message, author, timestamp)
    id.to_hex()
  })
}

///|
pub fn log(root : String, max_count : Int) -> Result[Array[LogEntry], String] {
  let fs = make_fs()
  wrap_error(() => {
    let git_dir = resolve_git_dir(fs, root)
    let entries = @bitlib.log_head(fs, git_dir, max_count~)
    let result : Array[LogEntry] = []
    for e in entries {
      result.push(LogEntry::{
        id: e.id.to_hex(),
        author: e.author,
        message: e.message,
        timestamp: e.timestamp,
      })
    }
    result
  })
}

///|
pub fn checkout(root : String, target : String) -> Result[Unit, String] {
  let fs = make_fs()
  wrap_error(() => {
    let _ = @bitlib.checkout(fs, fs, root, target)
  })
}

///|
pub fn checkout_b(root : String, branch_name : String) -> Result[Unit, String] {
  let fs = make_fs()
  wrap_error(() => {
    @bitlib.create_branch(fs, fs, root, branch_name)
    let _ = @bitlib.checkout(fs, fs, root, branch_name)
  })
}

///|
pub fn branch_list(root : String) -> Result[Array[BranchInfo], String] {
  let fs = make_fs()
  wrap_error(() => {
    let git_dir = resolve_git_dir(fs, root)
    let (_, branches) = @bitlib.list_branches(fs, git_dir)
    let result : Array[BranchInfo] = []
    for b in branches {
      result.push(BranchInfo::{
        name: b.name,
        commit_id: b.id.to_hex(),
        is_current: b.current,
      })
    }
    result
  })
}

///|
pub fn branch_create(root : String, name : String) -> Result[Unit, String] {
  let fs = make_fs()
  wrap_error(() => @bitlib.create_branch(fs, fs, root, name))
}

///|
pub fn branch_delete(root : String, name : String) -> Result[Unit, String] {
  let fs = make_fs()
  wrap_error(() => @bitlib.delete_branch(fs, fs, root, name))
}

///|
pub fn rm(
  root : String,
  paths : Array[String],
  cached : Bool,
) -> Result[Unit, String] {
  let fs = make_fs()
  wrap_error(() => @bitlib.rm_paths(fs, fs, root, paths, cached~))
}

///|
pub fn mv(
  root : String,
  source : String,
  dest : String,
) -> Result[Unit, String] {
  let fs = make_fs()
  wrap_error(() => @bitlib.mv_path(fs, fs, root, source, dest))
}

// === git-network-ops exports (Phase 3 stubs) ===

///|
pub fn clone(
  url : String,
  dest : String,
  branch : String,
  depth : Int,
) -> Result[Unit, String] {
  let _ = (url, dest, branch, depth)
  Err("clone: not yet implemented")
}

///|
pub fn fetch(root : String, remote : String) -> Result[Unit, String] {
  let _ = (root, remote)
  Err("fetch: not yet implemented")
}

///|
pub fn push(
  root : String,
  remote : String,
  refspec : String,
) -> Result[Unit, String] {
  let _ = (root, remote, refspec)
  Err("push: not yet implemented")
}

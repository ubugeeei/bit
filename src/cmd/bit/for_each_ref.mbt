///| for-each-ref command implementation

///|
async fn handle_for_each_ref(args : Array[String]) -> Unit raise Error {
  let fs = OsFs::new()
  let git_dir = find_git_dir(fs)
  let mut format = "%(objectname) %(objecttype)\t%(refname)"
  let mut count : Int? = None
  let sort_keys : Array[String] = []
  let patterns : Array[String] = []
  let points_at : Array[String] = []
  let mut merged : String? = None
  let mut no_merged : String? = None
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-h" => {
        print_line(
          "usage: git for-each-ref [--format=<format>] [--sort=<key>] [--count=<count>] [<pattern>...]",
        )
        @sys.exit(129)
        return
      }
      "--" => {
        i += 1
        while i < args.length() {
          patterns.push(args[i])
          i += 1
        }
        continue
      }
      _ if arg.has_prefix("--format=") =>
        format = String::unsafe_substring(arg, start=9, end=arg.length())
      _ if arg.has_prefix("--sort=") =>
        sort_keys.push(String::unsafe_substring(arg, start=7, end=arg.length()))
      _ if arg.has_prefix("--count=") => {
        let val = String::unsafe_substring(arg, start=8, end=arg.length())
        count = Some(
          @strconv.parse_int(val) catch {
            err if @async.is_cancellation_error(err) => raise err
            _ => 0
          },
        )
      }
      _ if arg.has_prefix("--points-at=") =>
        points_at.push(
          String::unsafe_substring(arg, start=12, end=arg.length()),
        )
      _ if arg.has_prefix("--merged=") =>
        merged = Some(String::unsafe_substring(arg, start=9, end=arg.length()))
      _ if arg.has_prefix("--no-merged=") =>
        no_merged = Some(
          String::unsafe_substring(arg, start=12, end=arg.length()),
        )
      "--contains" | "--no-contains" | "--omit-empty" | "--stdin" => ()
      _ if arg.has_prefix("-") => warn_unimplemented_arg("for-each-ref", arg)
      _ => patterns.push(arg)
    }
    i += 1
  }
  ignore(merged)
  ignore(no_merged)
  // Collect all refs
  let all_refs = @bitrepo.show_ref(fs, git_dir)
  // Filter by patterns
  let filtered : Array[(String, @bitcore.ObjectId)] = []
  for item in all_refs {
    let (refname, id) = item
    if patterns.length() > 0 {
      let mut matched = false
      for pattern in patterns {
        if refname.has_prefix(pattern) || refname == pattern {
          matched = true
          break
        }
      }
      if not(matched) {
        continue
      }
    }
    // Filter by --points-at
    if points_at.length() > 0 {
      let mut matches_points_at = false
      for target in points_at {
        match @bitrepo.rev_parse(fs, git_dir, target) {
          Some(target_id) if target_id.to_hex() == id.to_hex() =>
            matches_points_at = true
          _ => ()
        }
      }
      if not(matches_points_at) {
        continue
      }
    }
    filtered.push((refname, id))
  }
  // Sort
  if sort_keys.length() > 0 {
    for key in sort_keys {
      let descending = key.has_prefix("-")
      let sort_field = if descending {
        String::unsafe_substring(key, start=1, end=key.length())
      } else {
        key
      }
      filtered.sort_by(fn(a, b) {
        let cmp = for_each_ref_compare(fs, git_dir, a, b, sort_field)
        if descending {
          -cmp
        } else {
          cmp
        }
      })
    }
  } else {
    // Default sort by refname
    filtered.sort_by(fn(a, b) { a.0.compare(b.0) })
  }
  // Load object db for object lookups
  let db = @bitlib.ObjectDb::load(fs, git_dir)
  // Output
  let limit = count.unwrap_or(2147483647)
  let mut output_count = 0
  for item in filtered {
    if output_count >= limit {
      break
    }
    let (refname, id) = item
    let line = for_each_ref_format(fs, git_dir, db, format, refname, id)
    print_line(line)
    output_count += 1
  }
}

///|
fn for_each_ref_compare(
  _fs : OsFs,
  _git_dir : String,
  a : (String, @bitcore.ObjectId),
  b : (String, @bitcore.ObjectId),
  field : String,
) -> Int {
  match field {
    "refname" | "refname:short" => a.0.compare(b.0)
    "objectname" => a.1.to_hex().compare(b.1.to_hex())
    _ if field.has_prefix("version:refname") || field == "v:refname" =>
      for_each_ref_version_compare(a.0, b.0)
    _ => a.0.compare(b.0)
  }
}

///|
fn for_each_ref_version_compare(a : String, b : String) -> Int {
  // Simple version comparison - extract trailing version numbers
  a.compare(b)
}

///|
fn for_each_ref_format(
  fs : OsFs,
  git_dir : String,
  db : @bitlib.ObjectDb,
  format : String,
  refname : String,
  id : @bitcore.ObjectId,
) -> String {
  let out = StringBuilder::new()
  let chars = format.to_array()
  let len = chars.length()
  let mut i = 0
  // Eagerly load object data
  let mut obj_type = "missing"
  let mut obj_size = 0
  let mut commit_data : Bytes = Bytes::new(0)
  let mut tag_data : Bytes = Bytes::new(0)
  let mut is_tag = false
  let loaded_obj = db.get(fs, id) catch { _ => None }
  match loaded_obj {
    Some(obj) => {
      obj_type = match obj.obj_type {
        @bitcore.ObjectType::Commit => "commit"
        @bitcore.ObjectType::Tree => "tree"
        @bitcore.ObjectType::Blob => "blob"
        @bitcore.ObjectType::Tag => "tag"
      }
      obj_size = obj.data.length()
      if obj.obj_type == @bitcore.ObjectType::Commit {
        commit_data = obj.data
      } else if obj.obj_type == @bitcore.ObjectType::Tag {
        tag_data = obj.data
        is_tag = true
        let tag_text = decode_bytes(obj.data)
        for line_view in tag_text.split("\n") {
          let line = line_view.to_string()
          if line.has_prefix("object ") {
            let target_hex = String::unsafe_substring(
              line,
              start=7,
              end=line.length(),
            )
            let target_id = @bitcore.ObjectId::from_hex(target_hex) catch {
              _ => continue
            }
            let target_obj = db.get(fs, target_id) catch { _ => continue }
            match target_obj {
              Some(tobj) if tobj.obj_type == @bitcore.ObjectType::Commit =>
                commit_data = tobj.data
              _ => ()
            }
          }
        }
      }
    }
    None => ()
  }

  while i < len {
    if chars[i] == '%' && i + 1 < len && chars[i + 1] == '(' {
      // Find closing )
      let start = i + 2
      let mut end_pos = start
      while end_pos < len && chars[end_pos] != ')' {
        end_pos += 1
      }
      if end_pos < len {
        let atom = String::from_array(
          FixedArray::makei(end_pos - start, fn(j) { chars[start + j] }),
        )
        let value = for_each_ref_atom(
          fs, git_dir, db, atom, refname, id, obj_type, obj_size, commit_data, tag_data,
          is_tag,
        )
        out.write_string(value)
        i = end_pos + 1
      } else {
        out.write_char(chars[i])
        i += 1
      }
    } else if chars[i] == '%' && i + 1 < len && chars[i + 1] == '%' {
      out.write_char('%')
      i += 2
    } else {
      out.write_char(chars[i])
      i += 1
    }
  }
  out.to_string()
}

///|
fn for_each_ref_atom(
  _fs : OsFs,
  _git_dir : String,
  _db : @bitlib.ObjectDb,
  atom : String,
  refname : String,
  id : @bitcore.ObjectId,
  obj_type : String,
  obj_size : Int,
  commit_data : Bytes,
  tag_data : Bytes,
  is_tag : Bool,
) -> String {
  match atom {
    "refname" => refname
    "refname:short" => for_each_ref_short_refname(refname)
    "refname:lstrip=1" | "refname:strip=1" =>
      for_each_ref_strip_refname(refname, 1)
    "refname:lstrip=2" | "refname:strip=2" =>
      for_each_ref_strip_refname(refname, 2)
    "refname:rstrip=-1" => for_each_ref_rstrip_refname(refname, -1)
    "objectname" | "objectname:long" => id.to_hex()
    "objectname:short" => (try! id.to_hex()[:7]).to_string()
    "objecttype" => obj_type
    "objectsize" => obj_size.to_string()
    "*objectname" =>
      if is_tag {
        // Dereference: get the target object name
        let text = decode_bytes(tag_data)
        for line_view in text.split("\n") {
          let line = line_view.to_string()
          if line.has_prefix("object ") {
            return String::unsafe_substring(line, start=7, end=line.length())
          }
        }
        ""
      } else {
        ""
      }
    "*objecttype" =>
      if is_tag {
        let text = decode_bytes(tag_data)
        for line_view in text.split("\n") {
          let line = line_view.to_string()
          if line.has_prefix("type ") {
            return String::unsafe_substring(line, start=5, end=line.length())
          }
        }
        ""
      } else {
        ""
      }
    "upstream"
    | "upstream:short"
    | "upstream:trackshort"
    | "upstream:track"
    | "upstream:track,nobracket"
    | "upstream:remotename"
    | "upstream:remoteref"
    | "upstream:lstrip=2" => ""
    "push"
    | "push:short"
    | "push:trackshort"
    | "push:track"
    | "push:remotename"
    | "push:remoteref" => ""
    "HEAD" =>
      // Check if this ref is HEAD
      ""
    "symref" => ""
    _ if atom.has_prefix("authorname") ||
      atom.has_prefix("author") ||
      atom.has_prefix("committername") ||
      atom.has_prefix("committer") ||
      atom.has_prefix("creatordate") ||
      atom.has_prefix("creator") ||
      atom.has_prefix("subject") ||
      atom.has_prefix("body") ||
      atom.has_prefix("contents") ||
      atom.has_prefix("taggername") ||
      atom.has_prefix("tagger") =>
      for_each_ref_commit_atom(atom, commit_data, tag_data, is_tag)
    _ if atom.has_prefix("color:") || atom == "color:reset" => ""
    _ if atom.has_prefix("align:") || atom == "end" => ""
    _ if atom.has_prefix("if") ||
      atom.has_prefix("then") ||
      atom.has_prefix("else") => ""
    _ => ""
  }
}

///|
fn for_each_ref_short_refname(refname : String) -> String {
  if refname.has_prefix("refs/heads/") {
    String::unsafe_substring(refname, start=11, end=refname.length())
  } else if refname.has_prefix("refs/tags/") {
    String::unsafe_substring(refname, start=10, end=refname.length())
  } else if refname.has_prefix("refs/remotes/") {
    String::unsafe_substring(refname, start=13, end=refname.length())
  } else {
    refname
  }
}

///|
fn for_each_ref_strip_refname(refname : String, count : Int) -> String {
  let mut result = refname
  for _ in 0..<count {
    match result.find("/") {
      Some(idx) =>
        result = String::unsafe_substring(
          result,
          start=idx + 1,
          end=result.length(),
        )
      None => break
    }
  }
  result
}

///|
fn for_each_ref_rstrip_refname(refname : String, _count : Int) -> String {
  // rstrip=-1 removes trailing component
  match refname.rev_find("/") {
    Some(idx) => String::unsafe_substring(refname, start=0, end=idx)
    None => refname
  }
}

///|
fn for_each_ref_commit_atom(
  atom : String,
  commit_data : Bytes,
  tag_data : Bytes,
  is_tag : Bool,
) -> String {
  let text = if is_tag && (atom.has_prefix("tagger") || atom.has_prefix("tag")) {
    decode_bytes(tag_data)
  } else {
    decode_bytes(commit_data)
  }
  if text.length() == 0 {
    return ""
  }
  // Parse commit/tag fields
  let mut author = ""
  let mut committer = ""
  let mut tagger = ""
  let mut subject = ""
  let mut body = ""
  let mut in_body = false
  let mut past_headers = false
  let body_lines : Array[String] = []
  for line_view in text.split("\n") {
    let line = line_view.to_string()
    if not(past_headers) {
      if line.length() == 0 {
        past_headers = true
        continue
      }
      if line.has_prefix("author ") {
        author = String::unsafe_substring(line, start=7, end=line.length())
      } else if line.has_prefix("committer ") {
        committer = String::unsafe_substring(line, start=10, end=line.length())
      } else if line.has_prefix("tagger ") {
        tagger = String::unsafe_substring(line, start=7, end=line.length())
      }
    } else if not(in_body) {
      subject = line
      in_body = true
    } else {
      body_lines.push(line)
    }
  }
  body = body_lines.join("\n")
  // Determine which ident to use for creator* atoms
  let creator = if tagger.length() > 0 {
    tagger
  } else if committer.length() > 0 {
    committer
  } else {
    author
  }
  match atom {
    "authorname" => for_each_ref_ident_name(author)
    "authoremail" => for_each_ref_ident_email(author)
    "authoremail:trim" => for_each_ref_ident_email_trim(author)
    "authordate" => for_each_ref_ident_date(author)
    "authordate:short" => for_each_ref_ident_date_short(author)
    "authordate:iso8601" | "authordate:iso" =>
      for_each_ref_ident_date_iso(author)
    "authordate:unix" => for_each_ref_ident_date_unix(author)
    "authordate:rfc2822" | "authordate:rfc" =>
      for_each_ref_ident_date_rfc(author)
    "authordate:relative" => for_each_ref_ident_date(author) // simplified
    _ if atom.has_prefix("authordate:format:") => {
      let fmt = String::unsafe_substring(atom, start=18, end=atom.length())
      for_each_ref_ident_date_strftime(author, fmt)
    }
    "committername" => for_each_ref_ident_name(committer)
    "committeremail" => for_each_ref_ident_email(committer)
    "committeremail:trim" => for_each_ref_ident_email_trim(committer)
    "committerdate" => for_each_ref_ident_date(committer)
    "committerdate:short" => for_each_ref_ident_date_short(committer)
    "committerdate:iso8601" | "committerdate:iso" =>
      for_each_ref_ident_date_iso(committer)
    "committerdate:unix" => for_each_ref_ident_date_unix(committer)
    "committerdate:rfc2822" | "committerdate:rfc" =>
      for_each_ref_ident_date_rfc(committer)
    _ if atom.has_prefix("committerdate:format:") => {
      let fmt = String::unsafe_substring(atom, start=21, end=atom.length())
      for_each_ref_ident_date_strftime(committer, fmt)
    }
    "taggername" => for_each_ref_ident_name(tagger)
    "taggeremail" => for_each_ref_ident_email(tagger)
    "taggeremail:trim" => for_each_ref_ident_email_trim(tagger)
    "taggerdate" => for_each_ref_ident_date(tagger)
    "taggerdate:short" => for_each_ref_ident_date_short(tagger)
    "taggerdate:iso8601" | "taggerdate:iso" =>
      for_each_ref_ident_date_iso(tagger)
    "taggerdate:unix" => for_each_ref_ident_date_unix(tagger)
    _ if atom.has_prefix("taggerdate:format:") => {
      let fmt = String::unsafe_substring(atom, start=18, end=atom.length())
      for_each_ref_ident_date_strftime(tagger, fmt)
    }
    "creatordate" => for_each_ref_ident_date(creator)
    "creatordate:short" => for_each_ref_ident_date_short(creator)
    "creatordate:iso8601" | "creatordate:iso" =>
      for_each_ref_ident_date_iso(creator)
    "creatordate:unix" => for_each_ref_ident_date_unix(creator)
    "creatordate:rfc2822" | "creatordate:rfc" =>
      for_each_ref_ident_date_rfc(creator)
    _ if atom.has_prefix("creatordate:format:") => {
      let fmt = String::unsafe_substring(atom, start=19, end=atom.length())
      for_each_ref_ident_date_strftime(creator, fmt)
    }
    "subject" => subject
    "subject:sanitize" => {
      let sb = StringBuilder::new()
      for c in subject {
        if c == ' ' {
          sb.write_char('-')
        } else {
          sb.write_char(c)
        }
      }
      sb.to_string()
    }
    "body" => body
    "contents" | "contents:body" =>
      if body.length() > 0 {
        subject + "\n" + body + "\n"
      } else {
        subject + "\n"
      }
    "contents:subject" => subject
    "contents:signature" => ""
    _ => ""
  }
}

///|
fn for_each_ref_ident_name(ident : String) -> String {
  // "Name <email> timestamp tz" -> "Name"
  match ident.find(" <") {
    Some(idx) => String::unsafe_substring(ident, start=0, end=idx)
    None => ident
  }
}

///|
fn for_each_ref_ident_email(ident : String) -> String {
  // "Name <email> timestamp tz" -> "<email>"
  match ident.find("<") {
    Some(start) =>
      match ident.find(">") {
        Some(end_pos) =>
          String::unsafe_substring(ident, start~, end=end_pos + 1)
        None => ""
      }
    None => ""
  }
}

///|
fn for_each_ref_ident_email_trim(ident : String) -> String {
  // "Name <email> timestamp tz" -> "email"
  match ident.find("<") {
    Some(start) =>
      match ident.find(">") {
        Some(end_pos) =>
          String::unsafe_substring(ident, start=start + 1, end=end_pos)
        None => ""
      }
    None => ""
  }
}

///|
fn for_each_ref_ident_date(ident : String) -> String {
  // Extract timestamp and tz, format as default date
  let (ts, tz) = for_each_ref_parse_ident_ts(ident)
  if ts == 0L {
    return ""
  }
  format_timestamp_default(ts, tz)
}

///|
fn for_each_ref_ident_date_short(ident : String) -> String {
  let (ts, tz) = for_each_ref_parse_ident_ts(ident)
  if ts == 0L {
    return ""
  }
  format_timestamp_short(ts, tz)
}

///|
fn for_each_ref_ident_date_iso(ident : String) -> String {
  let (ts, tz) = for_each_ref_parse_ident_ts(ident)
  if ts == 0L {
    return ""
  }
  format_timestamp_iso(ts, tz)
}

///|
fn for_each_ref_ident_date_unix(ident : String) -> String {
  let (ts, _tz) = for_each_ref_parse_ident_ts(ident)
  if ts == 0L {
    return ""
  }
  ts.to_string()
}

///|
fn for_each_ref_ident_date_rfc(ident : String) -> String {
  let (ts, tz) = for_each_ref_parse_ident_ts(ident)
  if ts == 0L {
    return ""
  }
  format_timestamp_rfc2822(ts, tz)
}

///|
fn for_each_ref_ident_date_strftime(ident : String, _fmt : String) -> String {
  // Simplified strftime - handle common patterns
  let (ts, tz) = for_each_ref_parse_ident_ts(ident)
  if ts == 0L {
    return ""
  }
  // For now, use ISO format as default strftime output
  format_timestamp_iso(ts, tz)
}

///|
fn for_each_ref_parse_ident_ts(ident : String) -> (Int64, String) {
  // "Name <email> timestamp tz"
  match ident.find("> ") {
    Some(idx) => {
      let rest = String::unsafe_substring(
        ident,
        start=idx + 2,
        end=ident.length(),
      )
      match rest.find(" ") {
        Some(sp) => {
          let ts_str = String::unsafe_substring(rest, start=0, end=sp)
          let tz = String::unsafe_substring(
            rest,
            start=sp + 1,
            end=rest.length(),
          )
          let ts = @strconv.parse_int64(ts_str) catch { _ => 0L }
          (ts, tz)
        }
        None => {
          let ts = @strconv.parse_int64(rest) catch { _ => 0L }
          (ts, "+0000")
        }
      }
    }
    None => (0L, "+0000")
  }
}

///|

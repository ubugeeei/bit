///| git interpret-trailers - add or parse trailers in commit messages

///|
async fn handle_interpret_trailers(args : Array[String]) -> Unit raise Error {
  let trailers : Array[String] = []
  let mut where_pos = "end" // before|after|start|end
  let mut if_exists = "add" // replace|addIfDifferent|add|doNothing
  let mut if_missing = "add" // add|doNothing
  let mut in_place = false
  let mut only_trailers = false
  let mut only_input = false
  let mut no_divider = false
  let positional : Array[String] = []
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    match arg {
      "-h" | "--help" => {
        show_simple_command_help(
          "git interpret-trailers [--trailer <token>[(=|:)<value>]] [<file>...]",
          summary="Add or parse trailing meta-data in commit messages.",
        )
        return
      }
      "--trailer" => {
        i += 1
        if i < args.length() {
          trailers.push(args[i])
        }
      }
      "--where" => {
        i += 1
        if i < args.length() {
          where_pos = args[i]
        }
      }
      "--if-exists" => {
        i += 1
        if i < args.length() {
          if_exists = args[i]
        }
      }
      "--if-missing" => {
        i += 1
        if i < args.length() {
          if_missing = args[i]
        }
      }
      "--in-place" => in_place = true
      "--parse" => {
        only_trailers = true
        no_divider = true
      }
      "--only-trailers" => only_trailers = true
      "--only-input" => only_input = true
      "--no-divider" => no_divider = true
      _ if arg.has_prefix("--trailer=") => {
        let value = String::unsafe_substring(arg, start=10, end=arg.length())
        trailers.push(value)
      }
      _ if arg.has_prefix("--where=") => {
        where_pos = String::unsafe_substring(arg, start=8, end=arg.length())
      }
      _ if arg.has_prefix("--if-exists=") => {
        if_exists = String::unsafe_substring(arg, start=12, end=arg.length())
      }
      _ if arg.has_prefix("--if-missing=") => {
        if_missing = String::unsafe_substring(arg, start=13, end=arg.length())
      }
      _ if arg.has_prefix("-") => warn_unimplemented_arg("interpret-trailers", arg)
      _ => positional.push(arg)
    }
    i += 1
  }
  ignore(where_pos)
  ignore(if_exists)
  ignore(if_missing)
  ignore(only_input)
  // Read input
  let fs = OsFs::new()
  let input = if positional.length() > 0 {
    let file_bytes = fs.read_file(positional[0]) catch {
      err => raise err
    }
    decode_bytes(file_bytes)
  } else {
    decode_bytes(read_all_stdin())
  }
  if only_trailers {
    // Parse and print existing trailers only
    let existing = interpret_trailers_parse(input)
    let result = StringBuilder::new()
    for trailer in existing {
      result.write_string(trailer)
      result.write_char('\n')
    }
    if not(no_divider) && existing.length() > 0 {
      // With divider, print separator line before trailers
      // but --parse implies --no-divider
    }
    print_str(result.to_string())
    return
  }
  // Build output: message body + trailer block
  let (body, existing) = interpret_trailers_split(input)
  let all_trailers : Array[String] = []
  all_trailers.append(existing)
  // Add new trailers
  for trailer in trailers {
    all_trailers.push(interpret_trailers_normalize(trailer))
  }
  let result = StringBuilder::new()
  result.write_string(body)
  // Ensure blank line before trailers if body doesn't end with one
  if body.length() > 0 && not(body.has_suffix("\n\n")) {
    if body.has_suffix("\n") {
      result.write_char('\n')
    } else {
      result.write_string("\n\n")
    }
  }
  for trailer in all_trailers {
    result.write_string(trailer)
    result.write_char('\n')
  }
  let output = result.to_string()
  if in_place && positional.length() > 0 {
    fs.write_file(positional[0], str_to_bytes(output)) catch {
      err => raise err
    }
  } else {
    print_str(output)
  }
}

///|
fn interpret_trailers_parse(input : String) -> Array[String] {
  // Find trailer block at end of message
  let lines : Array[String] = []
  for line_view in input.split("\n") {
    lines.push(line_view.to_string())
  }
  // Remove trailing empty lines
  while lines.length() > 0 && trim_string(lines[lines.length() - 1]).length() == 0 {
    ignore(lines.pop())
  }
  // Walk backwards to find trailer block
  let trailers : Array[String] = []
  let mut i = lines.length() - 1
  while i >= 0 {
    let line = lines[i]
    if interpret_trailers_is_trailer(line) {
      trailers.push(line)
      i -= 1
    } else {
      break
    }
  }
  // Reverse since we collected backwards
  trailers.rev()
}

///|
fn interpret_trailers_split(input : String) -> (String, Array[String]) {
  // Split into body and existing trailers
  let lines : Array[String] = []
  for line_view in input.split("\n") {
    lines.push(line_view.to_string())
  }
  // Remove trailing empty line from split
  if lines.length() > 0 && lines[lines.length() - 1].length() == 0 {
    ignore(lines.pop())
  }
  // Walk backwards to find trailer block
  let trailer_start = {
    let mut idx = lines.length()
    let mut i = lines.length() - 1
    while i >= 0 {
      let line = lines[i]
      if interpret_trailers_is_trailer(line) {
        idx = i
        i -= 1
      } else if trim_string(line).length() == 0 {
        // blank line before trailers is part of separator
        break
      } else {
        break
      }
    }
    idx
  }
  let trailers : Array[String] = []
  let mut ti = trailer_start
  while ti < lines.length() {
    trailers.push(lines[ti])
    ti += 1
  }
  // Body is everything before trailer_start
  let body_sb = StringBuilder::new()
  let mut bi = 0
  while bi < trailer_start {
    body_sb.write_string(lines[bi])
    body_sb.write_char('\n')
    bi += 1
  }
  (body_sb.to_string(), trailers)
}

///|
fn interpret_trailers_is_trailer(line : String) -> Bool {
  // A trailer line has format "Key: Value" or "Key = Value"
  // Key must start with a letter/digit and contain no whitespace before separator
  match line.find(": ") {
    Some(idx) => {
      if idx == 0 {
        return false
      }
      let key = String::unsafe_substring(line, start=0, end=idx)
      // Key should not contain spaces
      for c in key.to_array() {
        if c == ' ' || c == '\t' {
          return false
        }
      }
      true
    }
    None =>
      match line.find(" = ") {
        Some(idx) => {
          if idx == 0 {
            return false
          }
          let key = String::unsafe_substring(line, start=0, end=idx)
          for c in key.to_array() {
            if c == ' ' || c == '\t' {
              return false
            }
          }
          true
        }
        None => false
      }
  }
}

///|
fn interpret_trailers_normalize(trailer : String) -> String {
  // Normalize "Key=Value" or "Key:Value" to "Key: Value"
  match trailer.find(": ") {
    Some(_) => trailer // already normalized
    None =>
      match trailer.find(":") {
        Some(idx) => {
          let key = String::unsafe_substring(trailer, start=0, end=idx)
          let value = trim_string(
            String::unsafe_substring(
              trailer,
              start=idx + 1,
              end=trailer.length(),
            ),
          )
          "\{key}: \{value}"
        }
        None =>
          match trailer.find("=") {
            Some(idx) => {
              let key = trim_string(
                String::unsafe_substring(trailer, start=0, end=idx),
              )
              let value = trim_string(
                String::unsafe_substring(
                  trailer,
                  start=idx + 1,
                  end=trailer.length(),
                ),
              )
              "\{key}: \{value}"
            }
            None => trailer
          }
      }
  }
}

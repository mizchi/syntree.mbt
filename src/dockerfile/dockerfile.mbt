///|
/// Dockerfile Tokenizer
pub(all) enum DockerfileTokenType {
  Instruction
  String
  Number
  Variable
  Flag
  Argument
  Path
  Equals
  Comment
  Whitespace
  Newline
  Continuation
  Unknown
} derive(Eq, Debug)

///|
pub impl Show for DockerfileTokenType with fn output(self, logger) {
  match self {
    Instruction => logger.write_string("Instruction")
    String => logger.write_string("String")
    Number => logger.write_string("Number")
    Variable => logger.write_string("Variable")
    Flag => logger.write_string("Flag")
    Argument => logger.write_string("Argument")
    Path => logger.write_string("Path")
    Equals => logger.write_string("Equals")
    Comment => logger.write_string("Comment")
    Whitespace => logger.write_string("Whitespace")
    Newline => logger.write_string("Newline")
    Continuation => logger.write_string("Continuation")
    Unknown => logger.write_string("Unknown")
  }
}

///|
pub(all) struct DockerfileToken {
  token_type : DockerfileTokenType
  from : Int
  to : Int
} derive(Eq, Debug)

///|
pub impl Show for DockerfileToken with fn output(self, logger) {
  logger.write_string("{token_type: ")
  self.token_type.output(logger)
  logger.write_string(", from: ")
  logger.write_string(self.from.to_string())
  logger.write_string(", to: ")
  logger.write_string(self.to.to_string())
  logger.write_string("}")
}

///|
pub(all) struct DockerfileTokenizer {
  input : String
  priv chars : Array[Char]
  priv len : Int
  priv mut pos : Int
  priv mut at_line_start : Bool
}

///|
let dockerfile_instructions : Array[String] = [
  "FROM", "RUN", "CMD", "LABEL", "MAINTAINER", "EXPOSE", "ENV", "ADD", "COPY", "ENTRYPOINT",
  "VOLUME", "USER", "WORKDIR", "ARG", "ONBUILD", "STOPSIGNAL", "HEALTHCHECK", "SHELL",
]

///|
pub fn DockerfileTokenizer::new(input : String) -> DockerfileTokenizer {
  let chars = input.to_array()
  { input, chars, len: chars.length(), pos: 0, at_line_start: true }
}

///|
fn DockerfileTokenizer::peek_at(
  self : DockerfileTokenizer,
  offset : Int,
) -> Char? {
  let idx = self.pos + offset
  if idx >= 0 && idx < self.len {
    Some(self.chars[idx])
  } else {
    None
  }
}

///|
fn is_id_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_'
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn to_upper(s : String) -> String {
  let buf = StringBuilder::new()
  for c in s {
    let upper = if c >= 'a' && c <= 'z' {
      (c.to_int() - 32).unsafe_to_char()
    } else {
      c
    }
    buf.write_char(upper)
  }
  buf.to_string()
}

///|
fn DockerfileTokenizer::read_string(
  self : DockerfileTokenizer,
  quote : Char,
) -> DockerfileToken {
  let start = self.pos
  self.pos += 1
  while self.pos < self.len {
    let c = self.chars[self.pos]
    if c == '\\' && self.pos + 1 < self.len {
      self.pos += 2
    } else if c == quote {
      self.pos += 1
      break
    } else {
      self.pos += 1
    }
  }
  { token_type: String, from: start, to: self.pos }
}

///|
fn DockerfileTokenizer::read_variable(
  self : DockerfileTokenizer,
) -> DockerfileToken {
  let start = self.pos
  self.pos += 1 // skip $
  if self.pos < self.len && self.chars[self.pos] == '{' {
    self.pos += 1
    while self.pos < self.len && self.chars[self.pos] != '}' {
      self.pos += 1
    }
    if self.pos < self.len {
      self.pos += 1
    }
  } else {
    while self.pos < self.len && is_id_char(self.chars[self.pos]) {
      self.pos += 1
    }
  }
  { token_type: Variable, from: start, to: self.pos }
}

///|
fn DockerfileTokenizer::read_instruction(
  self : DockerfileTokenizer,
) -> DockerfileToken {
  let start = self.pos
  while self.pos < self.len && is_id_char(self.chars[self.pos]) {
    self.pos += 1
  }
  let value = String::from_array(self.chars[start:self.pos])
  let upper = to_upper(value)
  let token_type = if dockerfile_instructions.contains(upper) {
    Instruction
  } else {
    Argument
  }
  { token_type, from: start, to: self.pos }
}

///|
fn DockerfileTokenizer::read_flag(
  self : DockerfileTokenizer,
) -> DockerfileToken {
  let start = self.pos
  self.pos += 2 // skip --
  while self.pos < self.len &&
        (is_id_char(self.chars[self.pos]) || self.chars[self.pos] == '-') {
    self.pos += 1
  }
  { token_type: Flag, from: start, to: self.pos }
}

///|
fn DockerfileTokenizer::read_argument(
  self : DockerfileTokenizer,
) -> DockerfileToken {
  let start = self.pos
  while self.pos < self.len {
    let c = self.chars[self.pos]
    if c == ' ' ||
      c == '\t' ||
      c == '\n' ||
      c == '"' ||
      c == '\'' ||
      c == '$' ||
      c == '=' ||
      c == '#' {
      break
    }
    if c == '\\' && self.peek_at(1) == Some('\n') {
      break
    }
    self.pos += 1
  }
  { token_type: Argument, from: start, to: self.pos }
}

///|
pub fn DockerfileTokenizer::next_token(
  self : DockerfileTokenizer,
) -> DockerfileToken? {
  if self.pos >= self.len {
    return None
  }
  let start = self.pos
  let c = self.chars[self.pos]

  // Whitespace
  if c == ' ' || c == '\t' {
    while self.pos < self.len {
      let ch = self.chars[self.pos]
      if ch == ' ' || ch == '\t' {
        self.pos += 1
      } else {
        break
      }
    }
    self.at_line_start = false
    return Some({ token_type: Whitespace, from: start, to: self.pos })
  }

  // Newline
  if c == '\n' {
    self.pos += 1
    self.at_line_start = true
    return Some({ token_type: Newline, from: start, to: self.pos })
  }

  // Line continuation
  if c == '\\' && self.peek_at(1) == Some('\n') {
    self.pos += 2
    self.at_line_start = false
    return Some({ token_type: Continuation, from: start, to: self.pos })
  }

  // Comment
  if c == '#' {
    while self.pos < self.len && self.chars[self.pos] != '\n' {
      self.pos += 1
    }
    return Some({ token_type: Comment, from: start, to: self.pos })
  }

  // String
  if c == '"' || c == '\'' {
    self.at_line_start = false
    return Some(self.read_string(c))
  }

  // Variable
  if c == '$' {
    self.at_line_start = false
    return Some(self.read_variable())
  }

  // Equals
  if c == '=' {
    self.pos += 1
    self.at_line_start = false
    return Some({ token_type: Equals, from: start, to: self.pos })
  }

  // Flag
  if c == '-' && self.peek_at(1) == Some('-') {
    self.at_line_start = false
    return Some(self.read_flag())
  }

  // Instruction at line start
  if self.at_line_start && ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) {
    self.at_line_start = false
    return Some(self.read_instruction())
  }

  // Number
  if is_digit(c) {
    while self.pos < self.len && is_digit(self.chars[self.pos]) {
      self.pos += 1
    }
    self.at_line_start = false
    return Some({ token_type: Number, from: start, to: self.pos })
  }

  // Argument
  self.at_line_start = false
  Some(self.read_argument())
}

///|
pub fn DockerfileTokenizer::tokenize_all(
  self : DockerfileTokenizer,
) -> Array[DockerfileToken] {
  let tokens : Array[DockerfileToken] = []
  while true {
    match self.next_token() {
      Some(token) =>
        match token.token_type {
          Whitespace | Newline | Continuation => ()
          _ => tokens.push(token)
        }
      None => break
    }
  }
  tokens
}

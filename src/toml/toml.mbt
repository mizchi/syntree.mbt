///|
/// TOML Tokenizer
pub(all) enum TomlTokenType {
  Key
  TableHeader
  ArrayTable
  String
  MultilineString
  Number
  Bool
  DateTime
  Equals
  Dot
  Comma
  BracketOpen
  BracketClose
  BraceOpen
  BraceClose
  Comment
  Whitespace
  Newline
  Unknown
} derive(Eq, Debug)

///|
pub impl Show for TomlTokenType with fn output(self, logger) {
  match self {
    Key => logger.write_string("Key")
    TableHeader => logger.write_string("TableHeader")
    ArrayTable => logger.write_string("ArrayTable")
    String => logger.write_string("String")
    MultilineString => logger.write_string("MultilineString")
    Number => logger.write_string("Number")
    Bool => logger.write_string("Bool")
    DateTime => logger.write_string("DateTime")
    Equals => logger.write_string("Equals")
    Dot => logger.write_string("Dot")
    Comma => logger.write_string("Comma")
    BracketOpen => logger.write_string("BracketOpen")
    BracketClose => logger.write_string("BracketClose")
    BraceOpen => logger.write_string("BraceOpen")
    BraceClose => logger.write_string("BraceClose")
    Comment => logger.write_string("Comment")
    Whitespace => logger.write_string("Whitespace")
    Newline => logger.write_string("Newline")
    Unknown => logger.write_string("Unknown")
  }
}

///|
pub(all) struct TomlToken {
  token_type : TomlTokenType
  from : Int
  to : Int
} derive(Eq, Debug)

///|
pub impl Show for TomlToken with fn output(self, logger) {
  logger.write_string("{token_type: ")
  self.token_type.output(logger)
  logger.write_string(", from: ")
  logger.write_string(self.from.to_string())
  logger.write_string(", to: ")
  logger.write_string(self.to.to_string())
  logger.write_string("}")
}

///|
pub(all) struct TomlTokenizer {
  input : String
  priv chars : Array[Char]
  priv len : Int
  priv mut pos : Int
  priv mut at_line_start : Bool
  priv mut expect_value : Bool
}

///|
pub fn TomlTokenizer::new(input : String) -> TomlTokenizer {
  let chars = input.to_array()
  {
    input,
    chars,
    len: chars.length(),
    pos: 0,
    at_line_start: true,
    expect_value: false,
  }
}

///|
fn TomlTokenizer::peek_at(self : TomlTokenizer, offset : Int) -> Char? {
  let idx = self.pos + offset
  if idx >= 0 && idx < self.len {
    Some(self.chars[idx])
  } else {
    None
  }
}

///|
fn is_bare_key_char(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') ||
  (c >= 'A' && c <= 'Z') ||
  (c >= '0' && c <= '9') ||
  c == '_' ||
  c == '-'
}

///|
fn is_digit(c : Char) -> Bool {
  c >= '0' && c <= '9'
}

///|
fn TomlTokenizer::read_basic_string(self : TomlTokenizer) -> TomlToken {
  let start = self.pos
  self.pos += 1
  let is_multiline = self.peek_at(0) == Some('"') &&
    self.peek_at(1) == Some('"')
  if is_multiline {
    self.pos += 2
    if self.pos < self.len && self.chars[self.pos] == '\n' {
      self.pos += 1
    }
  }
  while self.pos < self.len {
    let c = self.chars[self.pos]
    if c == '\\' {
      self.pos += 2
    } else if c == '"' {
      if is_multiline {
        if self.peek_at(1) == Some('"') && self.peek_at(2) == Some('"') {
          self.pos += 3
          break
        } else {
          self.pos += 1
        }
      } else {
        self.pos += 1
        break
      }
    } else {
      self.pos += 1
    }
  }
  let token_type = if is_multiline { MultilineString } else { String }
  { token_type, from: start, to: self.pos }
}

///|
fn TomlTokenizer::read_literal_string(self : TomlTokenizer) -> TomlToken {
  let start = self.pos
  self.pos += 1
  let is_multiline = self.peek_at(0) == Some('\'') &&
    self.peek_at(1) == Some('\'')
  if is_multiline {
    self.pos += 2
    if self.pos < self.len && self.chars[self.pos] == '\n' {
      self.pos += 1
    }
  }
  while self.pos < self.len {
    let c = self.chars[self.pos]
    if c == '\'' {
      if is_multiline {
        if self.peek_at(1) == Some('\'') && self.peek_at(2) == Some('\'') {
          self.pos += 3
          break
        } else {
          self.pos += 1
        }
      } else {
        self.pos += 1
        break
      }
    } else {
      self.pos += 1
    }
  }
  let token_type = if is_multiline { MultilineString } else { String }
  { token_type, from: start, to: self.pos }
}

///|
fn TomlTokenizer::read_number_or_datetime(self : TomlTokenizer) -> TomlToken {
  let start = self.pos

  // Skip sign
  if self.chars[self.pos] == '+' || self.chars[self.pos] == '-' {
    self.pos += 1
  }

  // Read digits
  while self.pos < self.len &&
        (is_digit(self.chars[self.pos]) || self.chars[self.pos] == '_') {
    self.pos += 1
  }

  // Check for date
  if self.pos < self.len &&
    self.chars[self.pos] == '-' &&
    self.pos + 1 < self.len &&
    is_digit(self.chars[self.pos + 1]) {
    while self.pos < self.len {
      let c = self.chars[self.pos]
      if is_digit(c) ||
        c == '-' ||
        c == ':' ||
        c == 'T' ||
        c == 't' ||
        c == ' ' ||
        c == '.' ||
        c == 'Z' ||
        c == 'z' ||
        c == '+' {
        self.pos += 1
      } else {
        break
      }
    }
    return { token_type: DateTime, from: start, to: self.pos }
  }

  // Decimal part
  if self.pos < self.len &&
    self.chars[self.pos] == '.' &&
    self.pos + 1 < self.len &&
    is_digit(self.chars[self.pos + 1]) {
    self.pos += 1
    while self.pos < self.len &&
          (is_digit(self.chars[self.pos]) || self.chars[self.pos] == '_') {
      self.pos += 1
    }
  }

  // Exponent
  if self.pos < self.len &&
    (self.chars[self.pos] == 'e' || self.chars[self.pos] == 'E') {
    self.pos += 1
    if self.pos < self.len &&
      (self.chars[self.pos] == '+' || self.chars[self.pos] == '-') {
      self.pos += 1
    }
    while self.pos < self.len &&
          (is_digit(self.chars[self.pos]) || self.chars[self.pos] == '_') {
      self.pos += 1
    }
  }
  { token_type: Number, from: start, to: self.pos }
}

///|
fn TomlTokenizer::read_bare_key(self : TomlTokenizer) -> TomlToken {
  let start = self.pos
  while self.pos < self.len && is_bare_key_char(self.chars[self.pos]) {
    self.pos += 1
  }
  let value = String::from_array(self.chars[start:self.pos])
  if self.expect_value && (value == "true" || value == "false") {
    return { token_type: Bool, from: start, to: self.pos }
  }
  { token_type: Key, from: start, to: self.pos }
}

///|
pub fn TomlTokenizer::next_token(self : TomlTokenizer) -> TomlToken? {
  if self.pos >= self.len {
    return None
  }
  let start = self.pos
  let c = self.chars[self.pos]

  // Whitespace
  if c == ' ' || c == '\t' {
    while self.pos < self.len &&
          (self.chars[self.pos] == ' ' || self.chars[self.pos] == '\t') {
      self.pos += 1
    }
    return Some({ token_type: Whitespace, from: start, to: self.pos })
  }

  // Newline
  if c == '\n' {
    self.pos += 1
    self.at_line_start = true
    self.expect_value = false
    return Some({ token_type: Newline, from: start, to: self.pos })
  }

  // Comment
  if c == '#' {
    while self.pos < self.len && self.chars[self.pos] != '\n' {
      self.pos += 1
    }
    return Some({ token_type: Comment, from: start, to: self.pos })
  }

  // Table header
  if c == '[' && self.at_line_start {
    self.pos += 1
    if self.pos < self.len && self.chars[self.pos] == '[' {
      self.pos += 1
      while self.pos < self.len &&
            self.chars[self.pos] != ']' &&
            self.chars[self.pos] != '\n' {
        self.pos += 1
      }
      if self.pos < self.len && self.chars[self.pos] == ']' {
        self.pos += 1
      }
      if self.pos < self.len && self.chars[self.pos] == ']' {
        self.pos += 1
      }
      self.at_line_start = false
      return Some({ token_type: ArrayTable, from: start, to: self.pos })
    } else {
      while self.pos < self.len &&
            self.chars[self.pos] != ']' &&
            self.chars[self.pos] != '\n' {
        self.pos += 1
      }
      if self.pos < self.len && self.chars[self.pos] == ']' {
        self.pos += 1
      }
      self.at_line_start = false
      return Some({ token_type: TableHeader, from: start, to: self.pos })
    }
  }

  // Strings
  if c == '"' {
    self.at_line_start = false
    return Some(self.read_basic_string())
  }
  if c == '\'' {
    self.at_line_start = false
    return Some(self.read_literal_string())
  }

  // Number/datetime or key
  if is_digit(c) ||
    (
      (c == '+' || c == '-') &&
      self.pos + 1 < self.len &&
      is_digit(self.chars[self.pos + 1])
    ) {
    self.at_line_start = false
    if self.expect_value {
      return Some(self.read_number_or_datetime())
    } else {
      return Some(self.read_bare_key())
    }
  }

  // Bare key
  if is_bare_key_char(c) {
    self.at_line_start = false
    return Some(self.read_bare_key())
  }

  // Punctuation
  let token_type = match c {
    '=' => {
      self.expect_value = true
      Equals
    }
    '.' => Dot
    ',' => Comma
    '[' => BracketOpen
    ']' => BracketClose
    '{' => BraceOpen
    '}' => BraceClose
    _ => Unknown
  }
  self.pos += 1
  self.at_line_start = false
  Some({ token_type, from: start, to: self.pos })
}

///|
pub fn TomlTokenizer::tokenize_all(self : TomlTokenizer) -> Array[TomlToken] {
  let tokens : Array[TomlToken] = []
  while true {
    match self.next_token() {
      Some(token) =>
        match token.token_type {
          Whitespace | Newline => ()
          _ => tokens.push(token)
        }
      None => break
    }
  }
  tokens
}

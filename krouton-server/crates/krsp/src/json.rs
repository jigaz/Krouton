// MARK: - json.rs

//! A small, strict JSON codec for KRSP control and telemetry payloads.
//!
//! Control frames are tiny and come from authenticated peers, but they still cross a network, so
//! the parser is defensive: bounded input size, bounded nesting depth, no duplicate keys, UTF-8
//! only, and numbers are kept as `f64` (every integer the protocol sends fits in 2^53).
//! Output is deterministic (object keys keep insertion order) so tests can compare bytes.

use std::fmt::Write as _;

/// Largest control payload the parser accepts.
pub const MAX_JSON_BYTES: usize = 256 * 1024;
const MAX_DEPTH: usize = 16;

#[derive(Clone, Debug, PartialEq)]
pub enum Value {
    Null,
    Bool(bool),
    Number(f64),
    String(String),
    Array(Vec<Value>),
    /// Insertion-ordered; keys are unique (the parser rejects duplicates).
    Object(Vec<(String, Value)>),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum JsonError {
    TooLarge,
    TooDeep,
    InvalidUtf8,
    Syntax(usize),
    DuplicateKey(String),
}

impl std::fmt::Display for JsonError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::TooLarge => write!(f, "JSON payload exceeds {MAX_JSON_BYTES} bytes"),
            Self::TooDeep => write!(f, "JSON nesting exceeds {MAX_DEPTH} levels"),
            Self::InvalidUtf8 => write!(f, "JSON payload is not UTF-8"),
            Self::Syntax(at) => write!(f, "JSON syntax error at byte {at}"),
            Self::DuplicateKey(k) => write!(f, "duplicate JSON key {k:?}"),
        }
    }
}

impl std::error::Error for JsonError {}

// MARK: - Accessors

impl Value {
    #[must_use]
    pub fn get(&self, key: &str) -> Option<&Value> {
        match self {
            Self::Object(fields) => fields.iter().find(|(k, _)| k == key).map(|(_, v)| v),
            _ => None,
        }
    }

    #[must_use]
    pub fn as_str(&self) -> Option<&str> {
        match self {
            Self::String(s) => Some(s),
            _ => None,
        }
    }

    #[must_use]
    pub fn as_bool(&self) -> Option<bool> {
        match self {
            Self::Bool(b) => Some(*b),
            _ => None,
        }
    }

    #[must_use]
    pub fn as_f64(&self) -> Option<f64> {
        match self {
            Self::Number(n) => Some(*n),
            _ => None,
        }
    }

    /// Non-negative integer that is exactly representable (no fraction, at most 2^53).
    #[must_use]
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    pub fn as_u64(&self) -> Option<u64> {
        let n = self.as_f64()?;
        (n.is_finite() && n >= 0.0 && n.fract() == 0.0 && n <= 9_007_199_254_740_992.0).then_some(n as u64)
    }

    #[must_use]
    pub fn as_array(&self) -> Option<&[Value]> {
        match self {
            Self::Array(items) => Some(items),
            _ => None,
        }
    }

    /// Convenience for building objects: `Value::object([("a", 1.into())])`.
    #[must_use]
    pub fn object<const N: usize>(fields: [(&str, Value); N]) -> Self {
        Self::Object(fields.into_iter().map(|(k, v)| (k.to_owned(), v)).collect())
    }
}

impl From<&str> for Value {
    fn from(s: &str) -> Self {
        Self::String(s.to_owned())
    }
}
impl From<String> for Value {
    fn from(s: String) -> Self {
        Self::String(s)
    }
}
impl From<bool> for Value {
    fn from(b: bool) -> Self {
        Self::Bool(b)
    }
}
impl From<f64> for Value {
    fn from(n: f64) -> Self {
        Self::Number(n)
    }
}
impl From<u64> for Value {
    #[allow(clippy::cast_precision_loss)]
    fn from(n: u64) -> Self {
        Self::Number(n as f64)
    }
}
impl From<u32> for Value {
    fn from(n: u32) -> Self {
        Self::Number(f64::from(n))
    }
}
impl From<Vec<Value>> for Value {
    fn from(items: Vec<Value>) -> Self {
        Self::Array(items)
    }
}
impl<T: Into<Value>> From<Option<T>> for Value {
    fn from(v: Option<T>) -> Self {
        v.map_or(Self::Null, Into::into)
    }
}

// MARK: - Serialize

impl Value {
    #[must_use]
    pub fn to_json(&self) -> String {
        let mut out = String::new();
        self.write(&mut out);
        out
    }

    fn write(&self, out: &mut String) {
        match self {
            Self::Null => out.push_str("null"),
            Self::Bool(b) => out.push_str(if *b { "true" } else { "false" }),
            Self::Number(n) => write_number(*n, out),
            Self::String(s) => write_string(s, out),
            Self::Array(items) => {
                out.push('[');
                for (i, item) in items.iter().enumerate() {
                    if i > 0 {
                        out.push(',');
                    }
                    item.write(out);
                }
                out.push(']');
            }
            Self::Object(fields) => {
                out.push('{');
                for (i, (k, v)) in fields.iter().enumerate() {
                    if i > 0 {
                        out.push(',');
                    }
                    write_string(k, out);
                    out.push(':');
                    v.write(out);
                }
                out.push('}');
            }
        }
    }
}

fn write_number(n: f64, out: &mut String) {
    if !n.is_finite() {
        // JSON has no NaN/Infinity; Swift's JSONDecoder would reject them, so send null.
        out.push_str("null");
    } else if n.fract() == 0.0 && n.abs() < 9_007_199_254_740_992.0 {
        let _ = write!(out, "{n:.0}");
    } else {
        let _ = write!(out, "{n}");
    }
}

fn write_string(s: &str, out: &mut String) {
    out.push('"');
    for c in s.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if u32::from(c) < 0x20 => {
                let _ = write!(out, "\\u{:04x}", u32::from(c));
            }
            c => out.push(c),
        }
    }
    out.push('"');
}

// MARK: - Parse

/// Parses one JSON value; trailing non-whitespace is an error.
pub fn parse(bytes: &[u8]) -> Result<Value, JsonError> {
    if bytes.len() > MAX_JSON_BYTES {
        return Err(JsonError::TooLarge);
    }
    let text = std::str::from_utf8(bytes).map_err(|_| JsonError::InvalidUtf8)?;
    let mut p = Parser { s: text.as_bytes(), i: 0 };
    let value = p.value(0)?;
    p.ws();
    if p.i != p.s.len() {
        return Err(JsonError::Syntax(p.i));
    }
    Ok(value)
}

struct Parser<'a> {
    s: &'a [u8],
    i: usize,
}

impl Parser<'_> {
    fn peek(&self) -> Option<u8> {
        self.s.get(self.i).copied()
    }

    fn ws(&mut self) {
        while matches!(self.peek(), Some(b' ' | b'\t' | b'\n' | b'\r')) {
            self.i += 1;
        }
    }

    fn expect(&mut self, literal: &[u8]) -> Result<(), JsonError> {
        if self.s.get(self.i..self.i + literal.len()) == Some(literal) {
            self.i += literal.len();
            Ok(())
        } else {
            Err(JsonError::Syntax(self.i))
        }
    }

    fn value(&mut self, depth: usize) -> Result<Value, JsonError> {
        if depth > MAX_DEPTH {
            return Err(JsonError::TooDeep);
        }
        self.ws();
        match self.peek() {
            Some(b'n') => self.expect(b"null").map(|()| Value::Null),
            Some(b't') => self.expect(b"true").map(|()| Value::Bool(true)),
            Some(b'f') => self.expect(b"false").map(|()| Value::Bool(false)),
            Some(b'"') => self.string().map(Value::String),
            Some(b'[') => self.array(depth),
            Some(b'{') => self.object(depth),
            Some(b'-' | b'0'..=b'9') => self.number(),
            _ => Err(JsonError::Syntax(self.i)),
        }
    }

    fn array(&mut self, depth: usize) -> Result<Value, JsonError> {
        self.i += 1;
        let mut items = Vec::new();
        self.ws();
        if self.peek() == Some(b']') {
            self.i += 1;
            return Ok(Value::Array(items));
        }
        loop {
            items.push(self.value(depth + 1)?);
            self.ws();
            match self.peek() {
                Some(b',') => self.i += 1,
                Some(b']') => {
                    self.i += 1;
                    return Ok(Value::Array(items));
                }
                _ => return Err(JsonError::Syntax(self.i)),
            }
        }
    }

    fn object(&mut self, depth: usize) -> Result<Value, JsonError> {
        self.i += 1;
        let mut fields: Vec<(String, Value)> = Vec::new();
        self.ws();
        if self.peek() == Some(b'}') {
            self.i += 1;
            return Ok(Value::Object(fields));
        }
        loop {
            self.ws();
            if self.peek() != Some(b'"') {
                return Err(JsonError::Syntax(self.i));
            }
            let key = self.string()?;
            if fields.iter().any(|(k, _)| *k == key) {
                return Err(JsonError::DuplicateKey(key));
            }
            self.ws();
            self.expect(b":")?;
            let value = self.value(depth + 1)?;
            fields.push((key, value));
            self.ws();
            match self.peek() {
                Some(b',') => self.i += 1,
                Some(b'}') => {
                    self.i += 1;
                    return Ok(Value::Object(fields));
                }
                _ => return Err(JsonError::Syntax(self.i)),
            }
        }
    }

    fn number(&mut self) -> Result<Value, JsonError> {
        let start = self.i;
        if self.peek() == Some(b'-') {
            self.i += 1;
        }
        match self.peek() {
            Some(b'0') => self.i += 1,
            Some(b'1'..=b'9') => {
                while matches!(self.peek(), Some(b'0'..=b'9')) {
                    self.i += 1;
                }
            }
            _ => return Err(JsonError::Syntax(self.i)),
        }
        if self.peek() == Some(b'.') {
            self.i += 1;
            if !matches!(self.peek(), Some(b'0'..=b'9')) {
                return Err(JsonError::Syntax(self.i));
            }
            while matches!(self.peek(), Some(b'0'..=b'9')) {
                self.i += 1;
            }
        }
        if matches!(self.peek(), Some(b'e' | b'E')) {
            self.i += 1;
            if matches!(self.peek(), Some(b'+' | b'-')) {
                self.i += 1;
            }
            if !matches!(self.peek(), Some(b'0'..=b'9')) {
                return Err(JsonError::Syntax(self.i));
            }
            while matches!(self.peek(), Some(b'0'..=b'9')) {
                self.i += 1;
            }
        }
        let text =
            std::str::from_utf8(self.s.get(start..self.i).unwrap_or_default()).map_err(|_| JsonError::Syntax(start))?;
        text.parse::<f64>().map(Value::Number).map_err(|_| JsonError::Syntax(start))
    }

    fn hex4(&mut self) -> Result<u32, JsonError> {
        let digits = self.s.get(self.i..self.i + 4).ok_or(JsonError::Syntax(self.i))?;
        let text = std::str::from_utf8(digits).map_err(|_| JsonError::Syntax(self.i))?;
        let v = u32::from_str_radix(text, 16).map_err(|_| JsonError::Syntax(self.i))?;
        self.i += 4;
        Ok(v)
    }

    fn string(&mut self) -> Result<String, JsonError> {
        self.i += 1; // opening quote
        let mut out = String::new();
        loop {
            let start = self.i;
            while let Some(b) = self.peek() {
                if b == b'"' || b == b'\\' || b < 0x20 {
                    break;
                }
                self.i += 1;
            }
            // The input is valid UTF-8 and we only split at ASCII bytes, so this slice is valid.
            out.push_str(
                std::str::from_utf8(self.s.get(start..self.i).unwrap_or_default())
                    .map_err(|_| JsonError::InvalidUtf8)?,
            );
            match self.peek() {
                Some(b'"') => {
                    self.i += 1;
                    return Ok(out);
                }
                Some(b'\\') => {
                    self.i += 1;
                    let escape = self.peek().ok_or(JsonError::Syntax(self.i))?;
                    self.i += 1;
                    match escape {
                        b'"' => out.push('"'),
                        b'\\' => out.push('\\'),
                        b'/' => out.push('/'),
                        b'b' => out.push('\u{8}'),
                        b'f' => out.push('\u{c}'),
                        b'n' => out.push('\n'),
                        b'r' => out.push('\r'),
                        b't' => out.push('\t'),
                        b'u' => {
                            let first = self.hex4()?;
                            let code = if (0xD800..0xDC00).contains(&first) {
                                self.expect(b"\\u")?;
                                let second = self.hex4()?;
                                if !(0xDC00..0xE000).contains(&second) {
                                    return Err(JsonError::Syntax(self.i));
                                }
                                0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
                            } else {
                                first
                            };
                            out.push(char::from_u32(code).ok_or(JsonError::Syntax(self.i))?);
                        }
                        _ => return Err(JsonError::Syntax(self.i)),
                    }
                }
                _ => return Err(JsonError::Syntax(self.i)),
            }
        }
    }
}

#[cfg(test)]
#[allow(clippy::unwrap_used)]
mod tests {
    use super::*;

    #[test]
    fn round_trips_and_escapes() {
        let v = Value::object([
            ("type", "hello".into()),
            ("n", 42u64.into()),
            ("f", 0.5.into()),
            ("ok", true.into()),
            ("name", "Jörgen's \"Mac\"\n\u{1}".into()),
            ("list", vec![Value::Null, 1u32.into()].into()),
        ]);
        let text = v.to_json();
        assert_eq!(
            text,
            r#"{"type":"hello","n":42,"f":0.5,"ok":true,"name":"Jörgen's \"Mac\"\n\u0001","list":[null,1]}"#
        );
        assert_eq!(parse(text.as_bytes()).unwrap(), v);
    }

    #[test]
    fn parses_what_swift_jsonencoder_emits() {
        // JSONEncoder escapes "/" and may emit exponent forms and surrogate pairs.
        let v = parse(br#" {"a":"x\/y","b":1e3,"c":-0.25,"d":"\ud83d\udcbf","e":[]} "#).unwrap();
        assert_eq!(v.get("a").and_then(Value::as_str), Some("x/y"));
        assert_eq!(v.get("b").and_then(Value::as_u64), Some(1000));
        assert_eq!(v.get("c").and_then(Value::as_f64), Some(-0.25));
        assert_eq!(v.get("d").and_then(Value::as_str), Some("💿"));
    }

    #[test]
    fn rejects_hostile_or_malformed_input() {
        for bad in [
            &b"{"[..],
            b"{\"a\":1,}",
            b"[1,]",
            b"01",
            b"1.",
            b"\"\x01\"",
            b"{\"a\":1,\"a\":2}",
            b"tru",
            b"\"\\ud800\"",
            b"1 2",
            b"\xff",
        ] {
            assert!(parse(bad).is_err(), "accepted {:?}", String::from_utf8_lossy(bad));
        }
        let deep = "[".repeat(100) + &"]".repeat(100);
        assert_eq!(parse(deep.as_bytes()), Err(JsonError::TooDeep));
        assert_eq!(parse(&vec![b' '; MAX_JSON_BYTES + 1]), Err(JsonError::TooLarge));
    }

    #[test]
    fn non_finite_numbers_become_null_and_u64_is_exact() {
        assert_eq!(Value::Number(f64::NAN).to_json(), "null");
        assert_eq!(Value::Number(1.5).as_u64(), None);
        assert_eq!(Value::Number(-1.0).as_u64(), None);
    }
}

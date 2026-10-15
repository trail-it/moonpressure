///|
fn tokens(text : StringView) -> Array[String] {
  let result : Array[String] = []
  let word = StringBuilder()
  for ch in text {
    if ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' {
      if !word.is_empty() {
        result.push(word.to_string())
        word.reset()
      }
    } else {
      word.write_char(ch)
    }
  }
  if !word.is_empty() {
    result.push(word.to_string())
  }
  result
}

///|
fn bounded(text : String) -> Unit raise ParseError {
  guard text.length() <= 65536 else { raise Invalid("input exceeds 64 KiB") }
}

///|
/// Strict unsigned decimal in signed Int64 range; rejects signs and overflow.
pub fn parse_counter(text : String) -> Int64 raise ParseError {
  bounded(text)
  let words = tokens(text[:])
  guard words.length() == 1 else { raise Invalid("expected one counter") }
  let word = words[0]
  let mut value = 0L
  for c in word {
    guard c >= '0' && c <= '9' else { raise Invalid("non-decimal counter") }
    let digit = (c.to_int() - 48).to_int64()
    guard value <= (9223372036854775807L - digit) / 10L else {
      raise Invalid("counter overflow")
    }
    value = value * 10L + digit
  }
  value
}

///|
pub fn parse_limit(text : String) -> Limit raise ParseError {
  bounded(text)
  let words = tokens(text[:])
  guard words.length() == 1 else { raise Invalid("expected limit or max") }
  if words[0] == "max" {
    Unlimited
  } else {
    Finite(parse_counter(words[0]))
  }
}

///|
pub fn parse_cpu_max(text : String) -> CpuMax raise ParseError {
  bounded(text)
  let words = tokens(text[:])
  guard words.length() == 2 else { raise Invalid("cpu.max needs two fields") }
  let quota = parse_limit(words[0])
  let period_us = parse_counter(words[1])
  guard period_us > 0 && quota != Finite(0L) else {
    raise Invalid("zero CPU period or quota")
  }
  { quota, period_us, }
}

///|
fn percent(text : String) -> Double raise ParseError {
  guard text.length() > 0 else { raise Invalid("empty percent") }
  let mut dots = 0
  let mut digits = 0
  let mut value = 0.0
  let mut scale = 0.1
  for c in text {
    if c == '.' {
      dots += 1
      guard dots <= 1 else { raise Invalid("invalid percent") }
    } else if c >= '0' && c <= '9' {
      digits += 1
      let digit = (c.to_int() - 48).to_double()
      if dots == 0 {
        value = value * 10.0 + digit
      } else {
        value += digit * scale
        scale *= 0.1
      }
      guard value <= 100.0 else { raise Invalid("percent outside 0..100") }
    } else {
      raise Invalid("invalid percent")
    }
  }
  guard digits > 0 else { raise Invalid("invalid percent") }
  value
}

///|
fn required(
  fields : Map[String, String],
  key : String,
) -> String raise ParseError {
  match fields.get(key) {
    Some(value) => value
    None => raise Invalid("missing \{key}")
  }
}

///|
fn pressure_line(words : Array[String]) -> PressureLine raise ParseError {
  let fields : Map[String, String] = Map([])
  for i in 1..<words.length() {
    let pair = words[i].split("=").collect()
    guard pair.length() == 2 else { raise Invalid("invalid PSI field") }
    let key = pair[0].to_owned()
    guard !fields.contains(key) else { raise Invalid("duplicate PSI field") }
    fields[key] = pair[1].to_owned()
  }
  // Unknown key=value fields are ignored for forward compatibility.
  {
    avg10: percent(required(fields, "avg10")),
    avg60: percent(required(fields, "avg60")),
    avg300: percent(required(fields, "avg300")),
    total_us: parse_counter(required(fields, "total")),
  }
}

///|
pub fn parse_pressure(text : String) -> Pressure raise ParseError {
  bounded(text)
  let mut some : PressureLine? = None
  let mut full : PressureLine? = None
  for line in text.split("\n") {
    let words = tokens(line)
    if words.is_empty() {
      continue
    }
    match words[0] {
      "some" => {
        guard some is None else { raise Invalid("duplicate some line") }
        some = Some(pressure_line(words))
      }
      "full" => {
        guard full is None else { raise Invalid("duplicate full line") }
        full = Some(pressure_line(words))
      }
      _ => raise Invalid("unknown PSI line")
    }
  }
  guard some is Some(some) else { raise Invalid("missing some line") }
  { some, full, }
}

///|
fn counters(text : String) -> Map[String, Int64] raise ParseError {
  bounded(text)
  let fields : Map[String, Int64] = Map([])
  for line in text.split("\n") {
    let words = tokens(line)
    if words.is_empty() {
      continue
    }
    guard words.length() == 2 else { raise Invalid("expected key value line") }
    let key = words[0]
    guard !fields.contains(key) else {
      raise Invalid("duplicate counter \{key}")
    }
    fields[key] = parse_counter(words[1])
  }
  fields
}

///|
fn counter(fields : Map[String, Int64], key : String) -> Int64 raise ParseError {
  match fields.get(key) {
    Some(value) => value
    None => raise Invalid("missing \{key}")
  }
}

///|
pub fn parse_cpu_stat(text : String) -> CpuStat raise ParseError {
  let fields = counters(text)
  let present = fields.contains("nr_periods") ||
    fields.contains("nr_throttled") ||
    fields.contains("throttled_usec")
  let throttle = if present {
    let periods = counter(fields, "nr_periods")
    let throttled_periods = counter(fields, "nr_throttled")
    guard throttled_periods <= periods else {
      raise Invalid("throttled periods exceed periods")
    }
    Some({
      periods,
      throttled_periods,
      throttled_us: counter(fields, "throttled_usec"),
    })
  } else {
    None
  }
  { usage_us: counter(fields, "usage_usec"), throttle, }
}

///|
pub fn parse_memory_events(text : String) -> MemoryEvents raise ParseError {
  let fields = counters(text)
  {
    high: counter(fields, "high"),
    max: counter(fields, "max"),
    oom: counter(fields, "oom"),
    oom_kill: counter(fields, "oom_kill"),
  }
}

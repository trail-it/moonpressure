///|
pub(all) suberror ReadError {
  System(String, Int32)
  InvalidPath
  ChangedDuringRead
  ClockUnavailable
} derive(Debug, Eq)

///|
pub extend ReadError with Debug::{to_repr}

///|
pub extend ReadError with Eq::{equal, not_equal}

///|
#borrow(path)
extern "C" fn read_raw(path : Bytes) -> Bytes = "mp_read"

///|
#borrow(path)
extern "C" fn identity_raw(path : Bytes) -> Bytes = "mp_identity"

///|
extern "C" fn clock_raw() -> Int64 = "mp_clock"

///|
extern "C" fn sleep_raw(ms : Int32) -> Int32 = "mp_sleep"

///|
fn path_bytes(path : String) -> Bytes raise ReadError {
  guard path.length() > 0 && path.length() <= 4096 && !path.contains("\u0000") else {
    raise InvalidPath
  }
  @utf8.encode(path) + b"\x00"
}

///|
fn unframe(data : Bytes, path : String) -> String raise {
  guard data.length() >= 4 else { raise System(path, 5) }
  let error = data[0].to_int() |
    (data[1].to_int() << 8) |
    (data[2].to_int() << 16) |
    (data[3].to_int() << 24)
  guard error == 0 else { raise System(path, error) }
  @utf8.decode(data[4:])
}

///|
pub fn read_text(path : String) -> String raise {
  unframe(read_raw(path_bytes(path)), path)
}

///|
fn identity(path : String) -> String raise {
  unframe(identity_raw(path_bytes(path)), path)
}

///|
pub fn monotonic_us() -> Int64 raise ReadError {
  let value = clock_raw()
  guard value >= 0L else { raise ClockUnavailable }
  value
}

///|
pub fn sleep_ms(ms : Int32) -> Unit raise ReadError {
  let status = sleep_raw(ms)
  guard status == 0 else { raise System("nanosleep", status) }
}

import decode
import encode
import gbor.{type CBOR, Int, Map, Null, String}
import gleam/bit_array
import gleeunit

pub fn main() {
  gleeunit.main()
}

fn decode_hex(hex: String) {
  let assert Ok(data) = bit_array.base16_decode(hex)
  decode.decode(data)
}

pub fn decode_bool_test() {
  let assert Ok(#(v, <<>>)) = decode_hex("F5")
  assert v == gbor.Bool(True)

  let assert Ok(#(v, <<>>)) = decode_hex("F4")
  assert v == gbor.Bool(False)
}

pub fn decode_float_test() {
  let assert Ok(#(v, <<>>)) = decode_hex("fa47c35000")
  assert v == gbor.Float(100_000.0)
}

pub fn decode_uint_test() {
  let assert Ok(#(v, <<>>)) = decode_hex("1bffffffffffffffff")
  assert v == gbor.Int(18_446_744_073_709_551_615)
}

pub fn decode_int_test() {
  let assert Ok(#(v, <<>>)) = decode_hex("3903e7")
  assert v == gbor.Int(-1000)
}

pub fn decode_string_test() {
  let assert Ok(#(v, <<>>)) = decode_hex("63e6b0b4")
  assert v == gbor.String("水")
}

pub fn decode_bytes_test() {
  let assert Ok(#(v, <<>>)) = decode_hex("40")
  assert v == gbor.Binary(<<>>)

  let assert Ok(#(v, <<>>)) = decode_hex("4401020304")
  assert v == gbor.Binary(<<0x01, 0x02, 0x03, 0x04>>)
}

pub fn decode_array_test() {
  let assert Ok(#(gbor.Array(v), <<>>)) = decode_hex("8401020304")
  assert v == [gbor.Int(1), gbor.Int(2), gbor.Int(3), gbor.Int(4)]

  let assert Ok(#(gbor.Array(v), <<>>)) = decode_hex("8301820203820405")
  assert v
    == [
      gbor.Int(1),
      gbor.Array([gbor.Int(2), gbor.Int(3)]),
      gbor.Array([gbor.Int(4), gbor.Int(5)]),
    ]
}

fn round_trip(expected: CBOR, hex: String) {
  let assert Ok(binary) = bit_array.base16_decode(hex)
  let assert Ok(#(v, <<>>)) = decode.decode(binary)
  assert v == expected

  let assert Ok(encoded) = encode.to_bit_array(v)
  assert encoded == binary
}

pub fn decode_map_test() {
  let hex = "a56161614161626142616361436164614461656145"
  let expected =
    [
      #(gbor.String("a"), gbor.String("A")),
      #(gbor.String("b"), gbor.String("B")),
      #(gbor.String("c"), gbor.String("C")),
      #(gbor.String("d"), gbor.String("D")),
      #(gbor.String("e"), gbor.String("E")),
    ]
    |> Map

  round_trip(expected, hex)
}

pub fn decode_null_test() {
  round_trip(Null, "F6")
}

pub fn decode_taggded_test() {
  round_trip(
    gbor.Tagged(0, String("2013-03-21T20:04:00Z")),
    "c074323031332d30332d32315432303a30343a30305a",
  )

  round_trip(gbor.Tagged(1, Int(1_363_896_240)), "c11a514b67b0")
}

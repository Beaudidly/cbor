import gleam/bit_array
import gleeunit

import gbor as g
import gbor/decode as d
import gbor/encode as e

pub fn main() {
  gleeunit.main()
}

fn decode_hex(hex: String) {
  let assert Ok(data) = bit_array.base16_decode(hex)
  d.decode(data)
}

pub fn decode_bool_test() {
  let assert Ok(#(v, <<>>)) = decode_hex("F5")
  assert v == g.CBBool(True)

  let assert Ok(#(v, <<>>)) = decode_hex("F4")
  assert v == g.CBBool(False)
}

pub fn decode_float_test() {
  let assert Ok(#(v, <<>>)) = decode_hex("fa47c35000")
  assert v == g.CBFloat(100_000.0)
}

pub fn decode_uint_test() {
  let assert Ok(#(v, <<>>)) = decode_hex("1bffffffffffffffff")
  assert v == g.CBInt(18_446_744_073_709_551_615)
}

pub fn decode_int_test() {
  let assert Ok(#(v, <<>>)) = decode_hex("3903e7")
  assert v == g.CBInt(-1000)
}

pub fn decode_string_test() {
  let assert Ok(#(v, <<>>)) = decode_hex("63e6b0b4")
  assert v == g.CBString("水")
}

pub fn decode_bytes_test() {
  let assert Ok(#(v, <<>>)) = decode_hex("40")
  assert v == g.CBBinary(<<>>)

  let assert Ok(#(v, <<>>)) = decode_hex("4401020304")
  assert v == g.CBBinary(<<0x01, 0x02, 0x03, 0x04>>)
}

pub fn decode_array_test() {
  let assert Ok(#(g.CBArray(v), <<>>)) = decode_hex("8401020304")
  assert v == [g.CBInt(1), g.CBInt(2), g.CBInt(3), g.CBInt(4)]

  let assert Ok(#(g.CBArray(v), <<>>)) = decode_hex("8301820203820405")
  assert v
    == [
      g.CBInt(1),
      g.CBArray([g.CBInt(2), g.CBInt(3)]),
      g.CBArray([g.CBInt(4), g.CBInt(5)]),
    ]
}

fn round_trip(expected: g.CBOR, hex: String) {
  let assert Ok(binary) = bit_array.base16_decode(hex)
  let assert Ok(#(v, <<>>)) = d.decode(binary)
  assert v == expected

  let assert Ok(encoded) = e.to_bit_array(v)
  assert encoded == binary
}

pub fn decode_map_test() {
  let hex = "a56161614161626142616361436164614461656145"
  let expected =
    [
      #(g.CBString("a"), g.CBString("A")),
      #(g.CBString("b"), g.CBString("B")),
      #(g.CBString("c"), g.CBString("C")),
      #(g.CBString("d"), g.CBString("D")),
      #(g.CBString("e"), g.CBString("E")),
    ]
    |> g.CBMap

  round_trip(expected, hex)
}

pub fn decode_null_test() {
  round_trip(g.CBNull, "F6")
}

pub fn decode_taggded_test() {
  round_trip(
    g.CBTagged(0, g.CBString("2013-03-21T20:04:00Z")),
    "c074323031332d30332d32315432303a30343a30305a",
  )

  round_trip(g.CBTagged(1, g.CBInt(1_363_896_240)), "c11a514b67b0")
}

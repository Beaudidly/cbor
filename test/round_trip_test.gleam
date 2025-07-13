import gleam/bit_array
import gleam/bool
import gleam/dynamic/decode as gdd
import gleam/string
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
  //let assert Ok(_) = round_trip(g.CBFloat(0.0), "f90000")
  //let assert Ok(_) = round_trip(g.CBFloat(-0.0), "f98000")
  //let assert Ok(_) = round_trip(g.CBFloat(1.0), "f93c00")
  let assert Ok(_) = round_trip(g.CBFloat(1.1), "fb3ff199999999999a")
  //let assert Ok(_) = round_trip(g.CBFloat(1.5), "f93e00")
  //let assert Ok(_) = round_trip(g.CBFloat(65_504.0), "f97bff")
  //let assert Ok(_) = round_trip(g.CBFloat(3.4028234663852886e38), "fa7f7fffff")
  let assert Ok(_) = round_trip(g.CBFloat(1.0e300), "fb7e37e43c8800759c")
  //let assert Ok(_) = round_trip(g.CBFloat(5.960464477539063e-08), "f90001")
  //let assert Ok(_) = round_trip(g.CBFloat(6.103515625e-05), "f90400")
  //let assert Ok(_) = round_trip(g.CBFloat(-4.0), "f9c400")
  //let assert Ok(_) = round_trip(g.CBFloat(-4.1), "fbc010666666666666")
  //let assert Ok(_) = round_trip(g.CBFloat(Infinity), "f97c00")
  //let assert Ok(_) = round_trip(g.CBFloat(-Infinity), "f9fc00")
  //let assert Ok(_) = round_trip(g.CBFloat(NaN), "f97e00")
  //let assert Ok(_) = round_trip(g.CBFloat(-NaN), "f9fe00")
}

pub fn decode_uint_test() {
  let assert Ok(_) = round_trip(g.CBInt(0), "00")
  let assert Ok(_) = round_trip(g.CBInt(1), "01")
  let assert Ok(_) = round_trip(g.CBInt(10), "0a")
  let assert Ok(_) = round_trip(g.CBInt(23), "17")
  let assert Ok(_) = round_trip(g.CBInt(24), "1818")
  let assert Ok(_) = round_trip(g.CBInt(25), "1819")
  let assert Ok(_) = round_trip(g.CBInt(100), "1864")
  let assert Ok(_) = round_trip(g.CBInt(1000), "1903e8")
  let assert Ok(_) = round_trip(g.CBInt(1_000_000), "1a000f4240")
  let assert Ok(_) =
    round_trip(g.CBInt(1_000_000_000_000), "1b000000e8d4a51000")
  let assert Ok(_) =
    round_trip(g.CBInt(18_446_744_073_709_551_615), "1bffffffffffffffff")
}

pub fn decode_int_test() {
  let assert Ok(_) =
    round_trip(g.CBInt(-18_446_744_073_709_551_616), "3bffffffffffffffff")

  let assert Ok(_) = round_trip(g.CBInt(-1), "20")
  let assert Ok(_) = round_trip(g.CBInt(-10), "29")
  let assert Ok(_) = round_trip(g.CBInt(-100), "3863")
  let assert Ok(_) = round_trip(g.CBInt(-1000), "3903e7")
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

fn round_trip(expected: g.CBOR, hex: String) -> Result(Nil, String) {
  let assert Ok(binary) = bit_array.base16_decode(hex)
  let assert Ok(#(v, <<>>)) = d.decode(binary)
  use <- bool.guard(
    v != expected,
    Error(
      "CBOR mismatch: "
      <> string.inspect(v)
      <> " != "
      <> string.inspect(expected),
    ),
  )

  let assert Ok(encoded) = e.to_bit_array(v)
  case encoded == binary {
    True -> Ok(Nil)
    False -> {
      let encoded_hex = bit_array.base16_encode(encoded)
      Error("Binary mismatch, provided " <> hex <> " but got " <> encoded_hex)
    }
  }
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
  let assert Ok(payload) = bit_array.base16_decode("010000000000000000")
  let assert Ok(_) =
    round_trip(g.CBTagged(2, g.CBBinary(payload)), "c249010000000000000000")

  let assert Ok(payload) = bit_array.base16_decode("010000000000000000")
  let assert Ok(_) =
    round_trip(g.CBTagged(3, g.CBBinary(payload)), "c349010000000000000000")

  let assert Ok(_) =
    round_trip(
      g.CBTagged(0, g.CBString("2013-03-21T20:04:00Z")),
      "c074323031332d30332d32315432303a30343a30305a",
    )

  round_trip(g.CBTagged(1, g.CBInt(1_363_896_240)), "c11a514b67b0")
}

type Cat {
  Cat(name: String, dob: String)
}

pub fn decode_dynamic_test() {
  let assert Ok(bin) =
    bit_array.base16_decode(
      "A2646E616D6574323031332D30332D32315432303A30343A30305A63646F62C074323031332D30332D32315432303A30343A30305A",
    )

  let assert Ok(#(cbor_val, <<>>)) = d.decode(bin)
  let dyn_val = d.cbor_to_dynamic(cbor_val)

  let decoder = {
    use name <- gdd.field("name", gdd.string)
    use dob <- gdd.field("dob", d.tagged_decoder(0, gdd.string, "INVALID"))
    gdd.success(Cat(name, dob))
  }

  let assert Ok(v) = gdd.run(dyn_val, decoder)
  assert v == Cat("2013-03-21T20:04:00Z", "2013-03-21T20:04:00Z")

  let assert Ok(encoded) = e.to_bit_array(cbor_val)
  assert encoded == bin
}

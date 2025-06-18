import decode.{decode}
import gbor
import gleam/bit_array
import gleam/dict
import gleam/list
import gleam/result
import gleeunit
import gleeunit/should

import gleam/dynamic/decode as dy_decode

pub fn main() {
  gleeunit.main()
}

type Cat {
  Cat(name: String, lives: Int, nicknames: List(String))
}

pub fn decode_cat_test() {
  let cat_decoder = {
    use name <- dy_decode.field("name", dy_decode.string)
    use lives <- dy_decode.field("lives", dy_decode.int)
    use nicknames <- dy_decode.field(
      "nicknames",
      dy_decode.list(dy_decode.string),
    )
    dy_decode.success(Cat(name:, lives:, nicknames:))
  }

  let assert Ok(data) =
    bit_array.base16_decode(
      "A3646E616D65656461697379656C6976657309696E69636B6E616D657382697363686D6F6F6B6965656461697365",
    )
  decode.parse(from: data, using: cat_decoder)
  |> should.equal(Ok(Cat("daisy", 9, ["schmookie", "daise"])))
}

pub fn decode_array_test() {
  let assert Ok(data) = bit_array.base16_decode("8401020304")
  decode.parse(from: data, using: dy_decode.list(dy_decode.int))
  |> should.equal(Ok([1, 2, 3, 4]))
}
//pub fn decode_int_small_test() {
//  let assert Ok(data) = bit_array.base16_decode("3901F3")
//  let expected = -500
//
//  decode.decode(data)
//  |> should.equal(#(gbor.GInt(expected), <<>>))
//}
//
//pub fn decode_uint_64_test() {
//  let assert Ok(data) = bit_array.base16_decode("1BFFFFFFFFFFFFFFFF")
//  let expected = 0xffffffffffffffff
//
//  decode(data)
//  |> should.equal(#(gbor.GInt(expected), <<>>))
//}
//
//pub fn decode_float_test() {
//  let assert Ok(data) = bit_array.base16_decode("FB40091EB851EB851F")
//  let expected = 3.14
//
//  decode(data)
//  |> should.equal(#(gbor.GFloat(expected), <<>>))
//}
//
//pub fn decode_simple_test() {
//  let assert Ok(data) = bit_array.base16_decode("F4")
//  decode(data)
//  |> should.equal(#(gbor.GBool(False), <<>>))
//
//  let assert Ok(data) = bit_array.base16_decode("F5")
//  decode(data)
//  |> should.equal(#(gbor.GBool(True), <<>>))
//
//  let assert Ok(data) = bit_array.base16_decode("F6")
//  decode(data)
//  |> should.equal(#(gbor.GNull, <<>>))
//
//  let assert Ok(data) = bit_array.base16_decode("F7")
//  decode(data)
//  |> should.equal(#(gbor.GUndefined, <<>>))
//}
//
//pub fn decode_bytes_test() {
//  let assert Ok(data) = bit_array.base16_decode("49FFFFFFFFFFFFFFFFA1")
//  let expected = <<0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xa1>>
//
//  decode(data)
//  |> should.equal(#(gbor.GBinary(expected), <<>>))
//}
//
//pub fn decode_short_uint_array_test() {
//  let assert Ok(data) = bit_array.base16_decode("8401020304")
//  decode(data)
//  |> should.equal(
//    #(
//      gbor.GArray([gbor.GInt(1), gbor.GInt(2), gbor.GInt(3), gbor.GInt(4)]),
//      <<>>,
//    ),
//  )
//}
//
//pub fn decode_25_uint_array_test() {
//  let expected =
//    [1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 1, 2, 3, 4, 5]
//    |> list.map(fn(x) { gbor.GInt(x) })
//    |> gbor.GArray
//
//  let assert Ok(test_data) =
//    bit_array.base16_decode(
//      "981901020304050607080900010203040506070809000102030405",
//    )
//
//  decode(test_data)
//  |> should.equal(#(expected, <<>>))
//}
//
//pub fn decode_map_uint_key_uint_value_test() {
//  let assert Ok(data) = bit_array.base16_decode("A201050207")
//
//  let expected =
//    gbor.GMap(
//      dict.from_list([
//        #(gbor.GInt(1), gbor.GInt(5)),
//        #(gbor.GInt(2), gbor.GInt(7)),
//      ]),
//    )
//
//  decode(data)
//  |> should.equal(#(expected, <<>>))
//}
//
//pub fn decode_map_string_key_uint_value_test() {
//  let assert Ok(data) = bit_array.base16_decode("A2616101616202")
//
//  let expected =
//    gbor.GMap(
//      dict.from_list([
//        #(gbor.GString("a"), gbor.GInt(1)),
//        #(gbor.GString("b"), gbor.GInt(2)),
//      ]),
//    )
//
//  decode(data)
//  |> should.equal(#(expected, <<>>))
//}
//

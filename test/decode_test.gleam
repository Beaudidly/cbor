import decode.{decode}
import gbor
import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode as gdd
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

  todo
  //decode.decode(data)
  //|> should.equal(Ok(Cat("daisy", 9, ["schmookie", "daise"])))
}

pub fn decode_array_test() {
  let assert Ok(data) = bit_array.base16_decode("8401020304")
  let assert Ok(#(gbor.Array(v), <<>>)) = decode.decode(data)
  assert v == [gbor.Int(1), gbor.Int(2), gbor.Int(3), gbor.Int(4)]
}

pub fn decode_cbor_test() {
  let assert Ok(data) = bit_array.base16_decode("F6")

  let assert Ok(#(v, rest)) = decode.decode(data)

  assert v == gbor.Null
  assert rest == <<>>
}

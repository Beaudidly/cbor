//// TODO validate that theres either diagnostic or decoded

import decode.{type CborDecodeError, UnimplementedError}
import encode
import gbor
import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode as gdd
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleeunit
import gleeunit/should
import simplifile

pub fn main() {
  gleeunit.main()
}

type TestVector {
  TestVector(
    cbor: String,
    hex: String,
    roundtrip: Bool,
    decoded: option.Option(gdd.Dynamic),
    diagnostic: option.Option(String),
  )
}

type TestVectorError {
  TestVectorError(error: CborDecodeError, test_vector: TestVector)
  UnfinishedTest(info: String, test_vector: TestVector)
  RoundtripError(test_vector: TestVector, expected: BitArray, actual: BitArray)
  EncodeError(error: encode.EncodeError, test_vector: TestVector)
}

fn test_vector_decoder() -> gdd.Decoder(TestVector) {
  use cbor <- gdd.field("cbor", gdd.string)
  use hex <- gdd.field("hex", gdd.string)
  use roundtrip <- gdd.field("roundtrip", gdd.bool)
  use decoded <- gdd.optional_field("decoded", None, gdd.optional(gdd.dynamic))
  use diagnostic <- gdd.optional_field(
    "diagnostic",
    None,
    gdd.optional(gdd.string),
  )
  gdd.success(TestVector(cbor:, hex:, roundtrip:, decoded:, diagnostic:))
}

fn appendix_decoder() -> gdd.Decoder(List(TestVector)) {
  gdd.list(test_vector_decoder())
}

pub fn test_vectors_test() {
  let assert Ok(data) =
    simplifile.read_bits("test/test-vectors/appendix-a.json")
    |> result.map_error(fn(e) { Nil })
    |> result.try(fn(data) { bit_array.to_string(data) })

  let assert Ok(test_vectors) = json.parse(data, using: appendix_decoder())

  let results =
    test_vectors
    |> list.map(fn(test_vector) { run_test_vector(test_vector) })
    |> result.partition

  results.1
  |> list.map(fn(e) { echo e })

  echo "Number of errors: " <> string.inspect(list.length(results.1))

  Nil
}

fn run_test_vector(test_vector: TestVector) -> Result(Nil, TestVectorError) {
  // TODO we should move this to decode parse
  todo
  //let assert Ok(original_data) = bit_array.base64_decode(test_vector.cbor)
  //use #(cbor_decoded, rest) <- result.try(
  //  decode.decode(original_data)
  //  |> result.map_error(fn(e) { TestVectorError(error: e, test_vector:) }),
  //)

  //assert rest == <<>>

  //use _ <- result.try(case #(test_vector.decoded, test_vector.diagnostic) {
  //  #(Some(_), Some(_)) -> {
  //    panic as "Both decoded and diagnostic are present"
  //  }
  //  #(Some(decoded), None) -> {
  //    assert decoded == cbor_decoded
  //    Ok(Nil)
  //  }
  //  #(None, Some(diagnostic)) -> {
  //    Error(UnfinishedTest(
  //      info: "No diagnostic test vector support",
  //      test_vector:,
  //    ))
  //  }
  //  _ -> {
  //    // TODO handle null or undefined case for decoded
  //    Error(UnfinishedTest(info: "No decoded or diagnostic", test_vector:))
  //  }
  //})

  //case test_vector.roundtrip {
  //  True -> {
  //    let assert Ok(decoded_from_dy) =
  //      gdd.run(cbor_decoded, decode.cbor_decoder())
  //    use re_encoded <- result.try(
  //      encode.to_bit_array(decoded_from_dy)
  //      |> result.map_error(fn(e) { EncodeError(error: e, test_vector:) }),
  //    )

  //    case re_encoded == original_data {
  //      True -> Ok(Nil)
  //      False ->
  //        Error(RoundtripError(
  //          test_vector:,
  //          expected: re_encoded,
  //          actual: original_data,
  //        ))
  //    }
  //  }
  //  False -> Ok(Nil)
  //}
}

// Manual test vectors
pub fn null_test() {
  let vector =
    TestVector(
      cbor: "9g==",
      hex: "F6",
      roundtrip: True,
      decoded: Some(dynamic.nil()),
      diagnostic: None,
    )

  let assert Ok(Nil) = run_test_vector(vector)
  Nil
}

pub type Cat {
  Cat(
    name: String,
    lives: Int,
    nicknames: List(String),
    fav_num: Float,
    alive: Bool,
    password: BitArray,
  )
}

fn cat_encoder(cat: Cat) -> gbor.CBOR {
  encode.map([
    #(encode.string("name"), encode.string(cat.name)),
    #(encode.string("lives"), encode.int(cat.lives)),
    #(
      encode.string("nicknames"),
      encode.array(list.map(cat.nicknames, encode.string)),
    ),
    #(encode.string("fav_num"), encode.float(cat.fav_num)),
    #(encode.string("alive"), encode.bool(cat.alive)),
    #(encode.string("password"), encode.binary(cat.password)),
  ])
}

pub fn encode_and_decode_test_d() {
  let cat_decoder = {
    use name <- gdd.field("name", gdd.string)
    use lives <- gdd.field("lives", gdd.int)
    use nicknames <- gdd.field("nicknames", gdd.list(gdd.string))
    use fav_num <- gdd.field("fav_num", gdd.float)
    use alive <- gdd.field("alive", gdd.bool)
    use password <- gdd.field("password", gdd.bit_array)
    gdd.success(Cat(name:, lives:, nicknames:, fav_num:, alive:, password:))
  }

  let cat =
    Cat(
      name: "Fluffy",
      lives: 9,
      nicknames: ["Fluff", "Fluffers"],
      fav_num: 42.0,
      alive: True,
      password: bit_array.from_string("cheese"),
    )
  //let assert Ok(Ok(_)) =
  //  cat_encoder(cat)
  //  |> encode.to_bit_array
  //  |> result.map(fn(data) { decode.parse(data, using: cat_decoder) })
  todo
}

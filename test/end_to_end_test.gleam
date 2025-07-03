import decode.{type CborDecodeError, UnimplementedError}
import encode
import gbor
import gleam/bit_array
import gleam/dynamic
import gleam/dynamic/decode as dy_decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
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
    decoded: option.Option(dy_decode.Dynamic),
    diagnostic: option.Option(String),
  )
}

type TestVectorError {
  TestVectorError(error: CborDecodeError, test_vector: TestVector)
  UnfinishedTest(info: String, test_vector: TestVector)
  RoundtripError(test_vector: TestVector, expected: BitArray, actual: BitArray)
  EncodeError(error: encode.EncodeError, test_vector: TestVector)
}

fn test_vector_decoder() -> dy_decode.Decoder(TestVector) {
  use cbor <- dy_decode.field("cbor", dy_decode.string)
  use hex <- dy_decode.field("hex", dy_decode.string)
  use roundtrip <- dy_decode.field("roundtrip", dy_decode.bool)
  use decoded <- dy_decode.optional_field(
    "decoded",
    None,
    dy_decode.optional(dy_decode.dynamic),
  )
  use diagnostic <- dy_decode.optional_field(
    "diagnostic",
    None,
    dy_decode.optional(dy_decode.string),
  )
  dy_decode.success(TestVector(cbor:, hex:, roundtrip:, decoded:, diagnostic:))
}

fn appendix_decoder() -> dy_decode.Decoder(List(TestVector)) {
  dy_decode.list(test_vector_decoder())
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

  Nil
}

fn run_test_vector(test_vector: TestVector) -> Result(Nil, TestVectorError) {
  // TODO we should move this to decode parse
  let assert Ok(original_data) = bit_array.base64_decode(test_vector.cbor)
  use #(cbor_decoded, rest) <- result.try(
    decode.decode(original_data)
    |> result.map_error(fn(e) { TestVectorError(error: e, test_vector:) }),
  )

  assert rest == <<>>

  // TODO validate that theres either diagnostic or decoded
  use _ <- result.try(case #(test_vector.decoded, test_vector.diagnostic) {
    #(Some(_), Some(_)) -> {
      panic as "Both decoded and diagnostic are present"
    }
    #(Some(decoded), None) -> {
      assert decoded == cbor_decoded
      Ok(Nil)
    }
    #(None, Some(diagnostic)) -> {
      Error(UnfinishedTest(
        info: "No diagnostic test vector support",
        test_vector:,
      ))
    }
    _ -> {
      // TODO handle null or undefined case for decoded
      Error(UnfinishedTest(info: "No decoded or diagnostic", test_vector:))
    }
  })

  case test_vector.roundtrip {
    True -> {
      let assert Ok(decoded_from_dy) = decode.decode_cbor(cbor_decoded)
      use re_encoded <- result.try(
        encode.to_bit_array(decoded_from_dy)
        |> result.map_error(fn(e) { EncodeError(error: e, test_vector:) }),
      )

      case re_encoded == original_data {
        True -> Ok(Nil)
        False ->
          Error(RoundtripError(
            test_vector:,
            expected: re_encoded,
            actual: original_data,
          ))
      }
    }
    False -> Ok(Nil)
  }
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
    use name <- dy_decode.field("name", dy_decode.string)
    use lives <- dy_decode.field("lives", dy_decode.int)
    use nicknames <- dy_decode.field(
      "nicknames",
      dy_decode.list(dy_decode.string),
    )
    use fav_num <- dy_decode.field("fav_num", dy_decode.float)
    use alive <- dy_decode.field("alive", dy_decode.bool)
    use password <- dy_decode.field("password", dy_decode.bit_array)
    dy_decode.success(Cat(
      name:,
      lives:,
      nicknames:,
      fav_num:,
      alive:,
      password:,
    ))
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
  let assert Ok(Ok(_)) =
    cat_encoder(cat)
    |> encode.to_bit_array
    |> result.map(fn(data) { decode.parse(data, using: cat_decoder) })
}

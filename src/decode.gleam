import gbor.{type CBOR}
import gleam/bit_array
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode as gdd
import gleam/list
import gleam/result
import gleam/string
import ieee_float.{
  from_bytes_16_be, from_bytes_32_be, from_bytes_64_be, to_finite,
}

pub type CborDecodeError {
  DynamicDecodeError(List(gdd.DecodeError))
  MajorTypeError(Int)
  ReservedError
  UnimplementedError(String)
  UnassignedError
}

pub fn decode(data: BitArray) -> Result(#(CBOR, BitArray), CborDecodeError) {
  case data {
    <<0:3, min:5, rest:bits>> -> decode_uint(min, rest)
    <<1:3, min:5, rest:bits>> -> decode_int(min, rest)
    <<2:3, min:5, rest:bits>> -> decode_bytes(min, rest)
    <<3:3, min:5, rest:bits>> -> decode_string(min, rest)
    <<4:3, min:5, rest:bits>> -> decode_array(min, rest)
    <<5:3, min:5, rest:bits>> -> decode_map(min, rest)
    <<7:3, min:5, rest:bits>> -> decode_float_or_simple_value(min, rest)
    <<n:3, _:bits>> -> Error(MajorTypeError(n))
    <<>> -> {
      Error(
        DynamicDecodeError(gdd.decode_error(
          expected: "Expected data, but got none",
          found: dynamic.nil(),
        )),
      )
    }
    v -> {
      Error(UnimplementedError(
        "Didn't know how to handle parsing from data: " <> string.inspect(v),
      ))
    }
  }
}

fn decode_uint(
  min: Int,
  data: BitArray,
) -> Result(#(CBOR, BitArray), CborDecodeError) {
  case min, data {
    24, <<val:int-unsigned-size(8), rest:bits>> -> Ok(#(gbor.Int(val), rest))
    25, <<val:int-unsigned-size(16), rest:bits>> -> Ok(#(gbor.Int(val), rest))
    26, <<val:int-unsigned-size(32), rest:bits>> -> Ok(#(gbor.Int(val), rest))
    27, <<val:int-unsigned-size(64), rest:bits>> -> Ok(#(gbor.Int(val), rest))
    min, <<rest:bits>> if min <= 23 -> Ok(#(gbor.Int(min), rest))
    min, <<_rest:bits>> if 30 >= min && min >= 28 -> Error(ReservedError)
    min, v -> {
      let err = "Did not find a valid uint, min: " <> string.inspect(min)
      gdd.decode_error(expected: err, found: dynamic.bit_array(v))
      |> DynamicDecodeError
      |> Error
    }
  }
}

pub fn decode_int(
  min: Int,
  data: BitArray,
) -> Result(#(CBOR, BitArray), CborDecodeError) {
  use #(v, rest) <- result.try(case min, data {
    24, <<val:int-size(8), rest:bits>> -> Ok(#(val, rest))
    25, <<val:int-size(16), rest:bits>> -> Ok(#(val, rest))
    26, <<val:int-size(32), rest:bits>> -> Ok(#(val, rest))
    27, <<val:int-size(64), rest:bits>> -> Ok(#(val, rest))
    val, <<rest:bits>> if val < 24 -> Ok(#(val, rest))
    val, <<_:bits>> if 30 >= val && val >= 28 -> Error(ReservedError)
    val, v -> {
      let err = "Did not find a valid int, min: " <> string.inspect(val)
      gdd.decode_error(expected: err, found: dynamic.bit_array(v))
      |> DynamicDecodeError
      |> Error
    }
  })

  Ok(#(gbor.Int(-1 - v), rest))
}

pub fn decode_float_or_simple_value(
  min: Int,
  data: BitArray,
) -> Result(#(CBOR, BitArray), CborDecodeError) {
  case min, data {
    20, <<rest:bits>> -> Ok(#(gbor.Bool(False), rest))
    21, <<rest:bits>> -> Ok(#(gbor.Bool(True), rest))
    22, <<rest:bits>> -> Ok(#(gbor.Null, rest))
    // Undefined, TODO can we make a specific type for this?
    23, <<rest:bits>> -> Ok(#(gbor.Undefined, rest))
    25, <<v:bytes-size(2), rest:bits>> -> decode_float(v, rest)
    26, <<v:bytes-size(4), rest:bits>> -> decode_float(v, rest)
    27, <<v:bytes-size(8), rest:bits>> -> decode_float(v, rest)
    // Unassigned
    n, <<_v:bytes-size(min), _:bits>> if n <= 19 -> Error(UnassignedError)
    // Reserved
    n, <<_rest:bits>> if n >= 24 && n <= 31 -> Error(ReservedError)
    n, <<_rest:bits>> if n >= 32 -> Error(UnassignedError)
    n, v -> {
      let err =
        "Did not find a valid float or simple value, min: " <> string.inspect(n)
      gdd.decode_error(expected: err, found: dynamic.bit_array(v))
      |> DynamicDecodeError
      |> Error
    }
  }
}

pub fn decode_float(
  data: BitArray,
  rest: BitArray,
) -> Result(#(CBOR, BitArray), CborDecodeError) {
  use v <- result.try(case bit_array.bit_size(data) {
    16 -> Ok(from_bytes_16_be(data))
    32 -> Ok(from_bytes_32_be(data))
    64 -> Ok(from_bytes_64_be(data))
    n -> {
      gdd.decode_error(
        expected: "Did not find a valid float size",
        found: dynamic.int(n),
      )
      |> DynamicDecodeError
      |> Error
    }
  })

  case to_finite(v) {
    Ok(v) -> Ok(#(gbor.Float(v), rest))
    Error(_) -> {
      gdd.decode_error(
        expected: "Valid float, but got NaN/Inf",
        found: dynamic.nil(),
      )
      |> DynamicDecodeError
      |> Error
    }
  }
}

pub fn decode_bytes(
  min: Int,
  data: BitArray,
) -> Result(#(CBOR, BitArray), CborDecodeError) {
  use #(v, rest) <- result.try(decode_bytes_helper(min, data))
  Ok(#(gbor.Binary(v), rest))
}

pub fn decode_string(
  min: Int,
  data: BitArray,
) -> Result(#(CBOR, BitArray), CborDecodeError) {
  use #(v, rest) <- result.try(decode_bytes_helper(min, data))

  let v =
    bit_array.to_string(v)
    |> result.map(fn(s) { gbor.String(s) })
    |> result.map_error(fn(_) {
      DynamicDecodeError(gdd.decode_error(
        expected: "Expected a string",
        found: dynamic.bit_array(v),
      ))
    })
  use v <- result.try(v)

  Ok(#(v, rest))
}

pub fn decode_bytes_helper(
  min: Int,
  data: BitArray,
) -> Result(#(BitArray, BitArray), CborDecodeError) {
  case min, data {
    24, <<n:int-unsigned-size(8), v:bytes-size(n), rest:bits>> -> Ok(#(v, rest))
    25, <<n:int-unsigned-size(16), v:bytes-size(n), rest:bits>> ->
      Ok(#(v, rest))
    26, <<n:int-unsigned-size(32), v:bytes-size(n), rest:bits>> ->
      Ok(#(v, rest))
    27, <<n:int-unsigned-size(64), v:bytes-size(n), rest:bits>> ->
      Ok(#(v, rest))
    n, <<v:bytes-size(min), rest:bits>> if n < 24 -> Ok(#(v, rest))
    31, <<_v:bits>> ->
      Error(UnimplementedError("Indeterminate sizes not supported yet."))
    n, v -> {
      let err = "For byte/strings, handling minor: " <> string.inspect(n)
      gdd.decode_error(expected: err, found: dynamic.bit_array(v))
      |> DynamicDecodeError
      |> Error
    }
  }
}

pub fn decode_array(
  min: Int,
  data: BitArray,
) -> Result(#(CBOR, BitArray), CborDecodeError) {
  use #(n, rest) <- result.try(case min, data {
    24, <<n:int-unsigned-size(8), rest:bits>> -> Ok(#(n, rest))
    25, <<n:int-unsigned-size(16), rest:bits>> -> Ok(#(n, rest))
    26, <<n:int-unsigned-size(32), rest:bits>> -> Ok(#(n, rest))
    27, <<n:int-unsigned-size(64), rest:bits>> -> Ok(#(n, rest))
    // TODO break limited
    n, <<rest:bits>> if n < 24 -> Ok(#(n, rest))
    31, <<_rest:bits>> ->
      Error(UnimplementedError("Indeterminate lengths not supported yet."))
    n, v -> {
      let err =
        "Didn't know how to handle parsing an array from data: "
        <> string.inspect(v)
        <> " with min: "
        <> string.inspect(n)
      gdd.decode_error(expected: err, found: dynamic.bit_array(v))
      |> DynamicDecodeError
      |> Error
    }
  })

  use #(values, rest) <- result.try(decode_array_helper(rest, n, []))

  Ok(#(gbor.Array(list.reverse(values)), rest))
}

pub fn decode_array_helper(
  data: BitArray,
  n: Int,
  acc: List(CBOR),
) -> Result(#(List(CBOR), BitArray), CborDecodeError) {
  case n {
    0 -> Ok(#(acc, data))
    _ -> {
      use #(v, rest_data) <- result.try(decode(data))
      decode_array_helper(rest_data, n - 1, [v, ..acc])
    }
  }
}

pub fn decode_map(
  min: Int,
  data: BitArray,
) -> Result(#(CBOR, BitArray), CborDecodeError) {
  use #(n, rest) <- result.try(case min, data {
    24, <<n:int-unsigned-size(8), rest:bits>> -> Ok(#(n, rest))
    25, <<n:int-unsigned-size(16), rest:bits>> -> Ok(#(n, rest))
    26, <<n:int-unsigned-size(32), rest:bits>> -> Ok(#(n, rest))
    27, <<n:int-unsigned-size(64), rest:bits>> -> Ok(#(n, rest))
    // TODO break limited
    n, <<rest:bits>> if n < 24 -> Ok(#(n, rest))
    31, <<_rest:bits>> ->
      Error(UnimplementedError("Indeterminate lengths not supported yet."))
    n, v -> {
      let err =
        "Didn't know how to handle parsing a map from data: "
        <> string.inspect(v)
        <> " with min: "
        <> string.inspect(n)
      gdd.decode_error(expected: err, found: dynamic.bit_array(v))
      |> DynamicDecodeError
      |> Error
    }
  })

  use #(values, rest) <- result.try(decode_array_helper(rest, n * 2, []))

  // Combine items into a map
  let map =
    list.reverse(values)
    |> list.sized_chunk(2)
    |> list.try_map(fn(x) {
      case x {
        [k, v] -> Ok(#(k, v))
        // TODO check if values are even
        _ -> {
          Error(
            DynamicDecodeError(gdd.decode_error(
              expected: "Expected even number of values",
              found: dynamic.nil(),
            )),
          )
        }
      }
    })
    |> result.map(gbor.Map)
  use map <- result.try(map)

  Ok(#(map, rest))
}

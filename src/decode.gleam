import gbor.{type CBOR}
import gleam/bit_array
import gleam/dict
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode as gdd
import gleam/list
import gleam/result
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

pub fn parse(
  from bin: BitArray,
  using decoder: gdd.Decoder(t),
) -> Result(t, CborDecodeError) {
  use dy <- result.try(case decode(bin) {
    Ok(#(dy_value, <<>>)) -> Ok(dy_value)
    Ok(#(_, rest)) -> {
      gdd.decode_error(
        expected: "Expected no more data, but got more",
        found: dynamic.bit_array(rest),
      )
      |> DynamicDecodeError
      |> Error
    }
    Error(e) -> Error(e)
  })

  gdd.run(dy, decoder)
  |> result.map_error(fn(e) { DynamicDecodeError(e) })
}

pub fn cbor_decoder() -> gdd.Decoder(CBOR) {
  gdd.new_primitive_decoder("Custom", fn(data) { decode_cbor(data) })
}

pub fn decode_cbor(data: dynamic.Dynamic) -> Result(CBOR, CBOR) {
  let d =
    gdd.one_of(gdd.map(gdd.int, gbor.Int), [
      gdd.map(gdd.float, gbor.Float),
      gdd.map(gdd.string, gbor.String),
      gdd.map(gdd.list(cbor_decoder()), fn(v) { gbor.Array(v) }),
      gdd.map(gdd.bool, gbor.Bool),
      gdd.map(gdd.bit_array, gbor.Binary),
      gdd.map(gdd.dict(cbor_decoder(), cbor_decoder()), fn(v) {
        gbor.Map(dict.to_list(v))
      }),
    ])

  case gdd.run(data, d) {
    Ok(v) -> Ok(v)
    Error(_) -> Error(gbor.Undefined)
  }
}

pub fn decode(data: BitArray) -> Result(#(Dynamic, BitArray), CborDecodeError) {
  case data {
    <<0:3, rest:bits>> -> decode_uint(rest)
    <<1:3, rest:bits>> -> decode_int(rest)
    <<2:3, rest:bits>> -> decode_bytes(rest)
    <<3:3, rest:bits>> -> decode_string(rest)
    <<4:3, rest:bits>> -> decode_array(rest)
    <<5:3, rest:bits>> -> decode_map(rest)
    <<7:3, rest:bits>> -> decode_float_or_simple_value(rest)
    <<n:3, rest:bits>> -> Error(MajorTypeError(n))
    _ -> todo
  }
}

fn decode_uint(data: BitArray) -> Result(#(Dynamic, BitArray), CborDecodeError) {
  case data {
    <<24:5, val:int-unsigned-size(8), rest:bits>> ->
      Ok(#(dynamic.int(val), rest))
    <<25:5, val:int-unsigned-size(16), rest:bits>> ->
      Ok(#(dynamic.int(val), rest))
    <<26:5, val:int-unsigned-size(32), rest:bits>> ->
      Ok(#(dynamic.int(val), rest))
    <<27:5, val:int-unsigned-size(64), rest:bits>> ->
      Ok(#(dynamic.int(val), rest))
    <<val:int-size(5), rest:bits>> if val <= 23 -> Ok(#(dynamic.int(val), rest))
    <<val:int-size(5), rest:bits>> if 30 >= val && val >= 28 ->
      Error(ReservedError)
    v -> {
      gdd.decode_error(
        expected: "Did not find a valid uint",
        found: dynamic.bit_array(v),
      )
      |> DynamicDecodeError
      |> Error
    }
  }
}

pub fn decode_int(
  data: BitArray,
) -> Result(#(Dynamic, BitArray), CborDecodeError) {
  use #(v, rest) <- result.try(case data {
    <<24:5, val:int-size(8), rest:bits>> -> Ok(#(val, rest))
    <<25:5, val:int-size(16), rest:bits>> -> Ok(#(val, rest))
    <<26:5, val:int-size(32), rest:bits>> -> Ok(#(val, rest))
    <<27:5, val:int-size(64), rest:bits>> -> Ok(#(val, rest))
    <<val:int-size(5), rest:bits>> if val < 24 -> Ok(#(val, rest))
    <<val:int-size(5), _:bits>> if 30 >= val && val >= 28 ->
      Error(ReservedError)
    v -> {
      gdd.decode_error(
        expected: "Did not find a valid int",
        found: dynamic.bit_array(v),
      )
      |> DynamicDecodeError
      |> Error
    }
  })

  Ok(#(dynamic.int(-1 - v), rest))
}

pub fn decode_float_or_simple_value(
  data: BitArray,
) -> Result(#(Dynamic, BitArray), CborDecodeError) {
  case data {
    <<20:5, rest:bits>> -> Ok(#(dynamic.bool(False), rest))
    <<21:5, rest:bits>> -> Ok(#(dynamic.bool(True), rest))
    <<22:5, rest:bits>> -> Ok(#(dynamic.nil(), rest))
    // Undefined, TODO can we make a specific type for this?
    <<23:5, rest:bits>> -> Ok(#(dynamic.nil(), rest))
    <<25:5, v:bytes-size(2), rest:bits>> -> decode_float(v, rest)
    <<26:5, v:bytes-size(4), rest:bits>> -> decode_float(v, rest)
    <<27:5, v:bytes-size(8), rest:bits>> -> decode_float(v, rest)
    // Unassigned
    <<n:int-size(5), _:bytes-size(n), _:bits>> if n <= 19 ->
      Error(UnassignedError)
    // Reserved
    <<n:int-size(5), _:bits>> if n >= 24 && n <= 31 -> Error(ReservedError)
    <<n:int-size(5), _:bits>> if n >= 32 -> Error(UnassignedError)
    v -> {
      gdd.decode_error(
        expected: "Did not find a valid float or simple value",
        found: dynamic.bit_array(v),
      )
      |> DynamicDecodeError
      |> Error
    }
  }
}

pub fn decode_float(
  data: BitArray,
  rest: BitArray,
) -> Result(#(Dynamic, BitArray), CborDecodeError) {
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
    Ok(v) -> Ok(#(dynamic.float(v), rest))
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
  data: BitArray,
) -> Result(#(Dynamic, BitArray), CborDecodeError) {
  use #(v, rest) <- result.try(decode_bytes_helper(data))
  Ok(#(dynamic.bit_array(v), rest))
}

pub fn decode_string(
  data: BitArray,
) -> Result(#(Dynamic, BitArray), CborDecodeError) {
  use #(v, rest) <- result.try(decode_bytes_helper(data))

  // TODO handle error on parse
  let v =
    bit_array.to_string(v)
    |> result.unwrap("TODO")
    |> dynamic.string

  Ok(#(v, rest))
}

pub fn decode_bytes_helper(
  data: BitArray,
) -> Result(#(BitArray, BitArray), CborDecodeError) {
  case data {
    <<24:5, n:int-unsigned-size(8), v:bytes-size(n), rest:bits>> ->
      Ok(#(v, rest))
    <<n:int-size(5), v:bytes-size(n), rest:bits>> if n < 24 -> Ok(#(v, rest))
    <<31:5, v:bits>> ->
      Error(UnimplementedError("Indeterminate sizes not supported yet."))
    _ -> todo
  }
}

pub fn decode_array(
  data: BitArray,
) -> Result(#(Dynamic, BitArray), CborDecodeError) {
  use #(n, rest) <- result.try(case data {
    <<24:5, n:int-unsigned-size(8), rest:bits>> -> Ok(#(n, rest))
    <<25:5, n:int-unsigned-size(16), rest:bits>> -> Ok(#(n, rest))
    <<26:5, n:int-unsigned-size(32), rest:bits>> -> Ok(#(n, rest))
    <<27:5, n:int-unsigned-size(64), rest:bits>> -> Ok(#(n, rest))
    // TODO break limited
    <<n:int-size(5), rest:bits>> if n < 24 -> Ok(#(n, rest))
    <<31:5, _:bits>> ->
      Error(UnimplementedError("Indeterminate lengths not supported yet."))
    v -> {
      echo v
      todo
    }
  })

  use #(values, rest) <- result.try(decode_array_helper(rest, n, []))

  Ok(#(dynamic.list(list.reverse(values)), rest))
}

pub fn decode_array_helper(
  data: BitArray,
  n: Int,
  acc: List(Dynamic),
) -> Result(#(List(Dynamic), BitArray), CborDecodeError) {
  case n {
    0 -> Ok(#(acc, data))
    _ -> {
      use #(v, rest_data) <- result.try(decode(data))
      decode_array_helper(rest_data, n - 1, [v, ..acc])
    }
  }
}

pub fn decode_map(
  data: BitArray,
) -> Result(#(Dynamic, BitArray), CborDecodeError) {
  use #(n, rest) <- result.try(case data {
    <<24:5, n:int-unsigned-size(8), rest:bits>> -> Ok(#(n, rest))
    <<25:5, n:int-unsigned-size(16), rest:bits>> -> Ok(#(n, rest))
    <<26:5, n:int-unsigned-size(32), rest:bits>> -> Ok(#(n, rest))
    <<27:5, n:int-unsigned-size(64), rest:bits>> -> Ok(#(n, rest))
    // TODO break limited
    <<n:int-size(5), rest:bits>> if n < 24 -> Ok(#(n, rest))
    <<31:5, _:bits>> ->
      Error(UnimplementedError("Indeterminate lengths not supported yet."))
    v -> {
      echo v
      todo
    }
  })

  use #(values, rest) <- result.try(decode_array_helper(rest, n * 2, []))

  // Combine items into a map
  let map =
    list.reverse(values)
    |> list.sized_chunk(2)
    |> list.map(fn(x) {
      case x {
        [k, v] -> #(k, v)
        // TODO check if values are even
        _ -> todo
      }
    })
    |> dynamic.properties

  Ok(#(map, rest))
}

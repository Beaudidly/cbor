import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode as dy_decode
import gleam/int
import gleam/list
import gleam/result
import ieee_float.{
  from_bytes_16_be, from_bytes_32_be, from_bytes_64_be, to_finite,
}

pub fn parse(
  from bin: BitArray,
  using decoder: dy_decode.Decoder(t),
) -> Result(t, List(dy_decode.DecodeError)) {
  let dy_value = case decode(bin) {
    #(v, <<>>) -> Ok(v)
    _ ->
      Error(dy_decode.decode_error(
        expected: "Expected no more data, but got more",
        found: dynamic.nil(),
      ))
  }
  use dy_value <- result.try(dy_value)

  dy_decode.run(dy_value, decoder)
}

pub fn decode(data: BitArray) -> #(Dynamic, BitArray) {
  case data {
    <<0:3, rest:bits>> -> decode_uint(rest)
    <<1:3, rest:bits>> -> decode_int(rest)
    <<2:3, rest:bits>> -> decode_bytes(rest)
    <<3:3, rest:bits>> -> decode_string(rest)
    <<4:3, rest:bits>> -> decode_array(rest)
    <<5:3, rest:bits>> -> decode_map(rest)
    <<7:3, rest:bits>> -> decode_float_or_simple_value(rest)
    <<n:3, rest:bits>> -> {
      echo "Unknown major type" <> int.to_string(n)
      todo
    }
    _ -> todo
  }
}

fn decode_uint(data: BitArray) -> #(Dynamic, BitArray) {
  case data {
    <<24:5, val:int-unsigned-size(8), rest:bits>> -> #(dynamic.int(val), rest)
    <<25:5, val:int-unsigned-size(16), rest:bits>> -> #(dynamic.int(val), rest)
    <<26:5, val:int-unsigned-size(32), rest:bits>> -> #(dynamic.int(val), rest)
    <<27:5, val:int-unsigned-size(64), rest:bits>> -> #(dynamic.int(val), rest)
    <<val:int-size(5), rest:bits>> if val < 24 -> #(dynamic.int(val), rest)
    _ -> {
      todo
    }
  }
}

pub fn decode_int(data: BitArray) -> #(Dynamic, BitArray) {
  let #(v, rest) = case data {
    <<24:5, val:int-size(8), rest:bits>> -> #(val, rest)
    <<25:5, val:int-size(16), rest:bits>> -> #(val, rest)
    <<26:5, val:int-size(32), rest:bits>> -> #(val, rest)
    <<27:5, val:int-size(64), rest:bits>> -> #(val, rest)
    <<val:int-size(5), rest:bits>> if val < 24 -> #(val, rest)
    _ -> {
      todo
    }
  }

  #(dynamic.int(-1 - v), rest)
}

pub fn decode_float_or_simple_value(data: BitArray) -> #(Dynamic, BitArray) {
  case data {
    <<20:5, rest:bits>> -> #(dynamic.bool(False), rest)
    <<21:5, rest:bits>> -> #(dynamic.bool(True), rest)
    <<22:5, rest:bits>> -> #(dynamic.nil(), rest)
    // Undefined, TODO can we make a specific type for this?
    <<23:5, rest:bits>> -> #(dynamic.nil(), rest)
    <<25:5, v:bytes-size(2), rest:bits>> -> #(decode_float(v), rest)
    <<26:5, v:bytes-size(4), rest:bits>> -> #(decode_float(v), rest)
    <<27:5, v:bytes-size(8), rest:bits>> -> #(decode_float(v), rest)
    // Unassigned
    <<n:int-size(5), v:bytes-size(n), rest:bits>> if n <= 19 -> todo
    // Reserved
    <<n:int-size(5), rest:bits>> if n >= 24 && n <= 31 -> todo
    <<n:int-size(5), rest:bits>> if n >= 32 -> todo
    _ -> todo
  }
}

pub fn decode_float(data: BitArray) -> Dynamic {
  let v = case bit_array.bit_size(data) {
    16 -> from_bytes_16_be(data)
    32 -> from_bytes_32_be(data)
    64 -> from_bytes_64_be(data)
    _ -> todo
  }

  case to_finite(v) {
    Ok(v) -> dynamic.float(v)
    Error(_) -> todo
  }
}

pub fn decode_bytes(data: BitArray) -> #(Dynamic, BitArray) {
  let #(v, rest) = decode_bytes_helper(data)
  #(dynamic.bit_array(v), rest)
}

pub fn decode_string(data: BitArray) -> #(Dynamic, BitArray) {
  let #(v, rest) = decode_bytes_helper(data)

  // TODO handle error on parse
  let v =
    bit_array.to_string(v)
    |> result.unwrap("TODO")
    |> dynamic.string

  #(v, rest)
}

pub fn decode_bytes_helper(data: BitArray) -> #(BitArray, BitArray) {
  case data {
    <<24:5, n:int-unsigned-size(8), v:bytes-size(n), rest:bits>> -> #(v, rest)
    <<n:int-size(5), v:bytes-size(n), rest:bits>> if n < 24 -> #(v, rest)
    _ -> todo
  }
}

pub fn decode_array(data: BitArray) -> #(Dynamic, BitArray) {
  let #(n, rest) = case data {
    <<24:5, n:int-unsigned-size(8), rest:bits>> -> #(n, rest)
    <<25:5, n:int-unsigned-size(16), rest:bits>> -> #(n, rest)
    <<26:5, n:int-unsigned-size(32), rest:bits>> -> #(n, rest)
    <<27:5, n:int-unsigned-size(64), rest:bits>> -> #(n, rest)
    // TODO break limited
    <<n:int-size(5), rest:bits>> if n < 24 -> #(n, rest)
    _ -> todo
  }

  let #(values, rest) = decode_array_helper(rest, n, [])

  #(dynamic.list(list.reverse(values)), rest)
}

pub fn decode_array_helper(
  data: BitArray,
  n: Int,
  acc: List(Dynamic),
) -> #(List(Dynamic), BitArray) {
  case n {
    0 -> #(acc, data)
    _ -> {
      let #(v, rest_data) = decode(data)
      decode_array_helper(rest_data, n - 1, [v, ..acc])
    }
  }
}

pub fn decode_map(data: BitArray) -> #(Dynamic, BitArray) {
  let #(n, rest) = case data {
    <<24:5, n:int-unsigned-size(8), rest:bits>> -> #(n, rest)
    <<25:5, n:int-unsigned-size(16), rest:bits>> -> #(n, rest)
    <<26:5, n:int-unsigned-size(32), rest:bits>> -> #(n, rest)
    <<27:5, n:int-unsigned-size(64), rest:bits>> -> #(n, rest)
    // TODO break limited
    <<n:int-size(5), rest:bits>> if n < 24 -> #(n, rest)
    _ -> todo
  }

  let #(values, rest) = decode_array_helper(rest, n * 2, [])

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

  #(map, rest)
}

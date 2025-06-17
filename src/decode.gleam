////<<25:5, n:int-unsigned-size(16), rest:bits>> -> #(n, rest)
////<<26:5, n:int-unsigned-size(32), rest:bits>> -> #(n, rest)
////<<27:5, n:int-unsigned-size(64), rest:bits>> -> #(n, rest)
//// TODO break limited

import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/dynamic/decode as dy_decode
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import ieee_float.{
  from_bytes_16_be, from_bytes_32_be, from_bytes_64_be, to_finite,
}

import gbor.{
  type GborValue, GArray, GBinary, GBool, GFloat, GInt, GMap, GNull, GString,
  GUndefined,
}

pub fn parse(
  from bin: BitArray,
  using decoder: dy_decode.Decoder(t),
) -> Result(t, dy_decode.DecodeError) {
  let v =
    dynamic.properties([
      #(dynamic.string("name"), dynamic.string("daisy")),
      #(dynamic.string("lives"), dynamic.int(9)),
      #(
        dynamic.string("nicknames"),
        dynamic.list([dynamic.string("shmookie"), dynamic.string("daisy")]),
      ),
    ])

  echo dynamic.classify(v)

  let r = dy_decode.run(v, decoder)

  echo r
  todo
}

pub fn decode(data: BitArray) -> #(GborValue, BitArray) {
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

fn decode_uint(data: BitArray) -> #(GborValue, BitArray) {
  case data {
    <<24:5, val:int-unsigned-size(8), rest:bits>> -> #(GInt(val), rest)
    <<25:5, val:int-unsigned-size(16), rest:bits>> -> #(GInt(val), rest)
    <<26:5, val:int-unsigned-size(32), rest:bits>> -> #(GInt(val), rest)
    <<27:5, val:int-unsigned-size(64), rest:bits>> -> #(GInt(val), rest)
    <<val:int-size(5), rest:bits>> if val < 24 -> #(GInt(val), rest)
    _ -> {
      todo
    }
  }
}

pub fn decode_int(data: BitArray) -> #(GborValue, BitArray) {
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

  #(GInt(-1 - v), rest)
}

pub fn decode_float_or_simple_value(data: BitArray) -> #(GborValue, BitArray) {
  case data {
    <<20:5, rest:bits>> -> #(GBool(False), rest)
    <<21:5, rest:bits>> -> #(GBool(True), rest)
    <<22:5, rest:bits>> -> #(GNull, rest)
    <<23:5, rest:bits>> -> #(GUndefined, rest)
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

pub fn decode_float(data: BitArray) -> GborValue {
  let v = case bit_array.bit_size(data) {
    16 -> from_bytes_16_be(data)
    32 -> from_bytes_32_be(data)
    64 -> from_bytes_64_be(data)
    _ -> todo
  }

  case to_finite(v) {
    Ok(v) -> GFloat(v)
    Error(_) -> todo
  }
}

pub fn decode_bytes(data: BitArray) -> #(GborValue, BitArray) {
  let #(v, rest) = decode_bytes_helper(data)
  #(GBinary(v), rest)
}

pub fn decode_string(data: BitArray) -> #(GborValue, BitArray) {
  let #(v, rest) = decode_bytes_helper(data)

  // TODO handle error on parse
  let v =
    bit_array.to_string(v)
    |> result.unwrap("TODO")
    |> GString

  #(v, rest)
}

pub fn decode_bytes_helper(data: BitArray) -> #(BitArray, BitArray) {
  case data {
    <<24:5, n:int-unsigned-size(8), v:bytes-size(n), rest:bits>> -> #(v, rest)
    <<n:int-size(5), v:bytes-size(n), rest:bits>> if n < 24 -> #(v, rest)
    _ -> todo
  }
}

pub fn decode_array(data: BitArray) -> #(GborValue, BitArray) {
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

  #(GArray(list.reverse(values)), rest)
}

pub fn decode_array_helper(
  data: BitArray,
  n: Int,
  acc: List(GborValue),
) -> #(List(GborValue), BitArray) {
  case n {
    0 -> #(acc, data)
    _ -> {
      let #(v, rest_data) = decode(data)
      decode_array_helper(rest_data, n - 1, [v, ..acc])
    }
  }
}

pub fn decode_map(data: BitArray) -> #(GborValue, BitArray) {
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
    |> dict.from_list
    |> GMap

  #(map, rest)
}

import gbor.{type CBOR}
import gleam/bit_array
import gleam/list
import ieee_float

pub fn int(value: Int) -> CBOR {
  gbor.Int(value)
}

pub fn map(value: List(#(CBOR, CBOR))) -> CBOR {
  gbor.Map(value)
}

pub fn string(value: String) -> CBOR {
  gbor.String(value)
}

pub fn array(value: List(CBOR)) -> CBOR {
  gbor.Array(value)
}

pub fn bool(value: Bool) -> CBOR {
  gbor.Bool(value)
}

pub fn null() -> CBOR {
  gbor.Null
}

pub fn undefined() -> CBOR {
  gbor.Undefined
}

pub fn float(value: Float) -> CBOR {
  gbor.Float(value)
}

pub fn binary(value: BitArray) -> CBOR {
  gbor.Binary(value)
}

pub fn to_bit_array(value: CBOR) -> BitArray {
  case value {
    gbor.Int(v) if v >= 0 -> uint_encode(v)
    gbor.Int(v) if v < 0 -> int_encode(v)
    gbor.Float(v) -> float_encode(v)
    gbor.Binary(v) -> binary_encode(BinaryEncoding(v))
    gbor.String(v) -> binary_encode(StringEncoding(v))
    gbor.Array(v) -> array_encode(v)
    gbor.Map(v) -> map_encode(v)
    gbor.Bool(v) -> bool_encode(v)
    gbor.Null -> null_encode()
    gbor.Undefined -> undefined_encode()
    v -> {
      echo v
      todo
    }
  }
}

pub fn uint_encode(value: Int) -> BitArray {
  case value {
    v if v < 24 -> <<0:3, v:5>>
    // TODO verify limits
    v if v < 0x100 -> <<0:3, 24:5, v:8>>
    v if v < 0x10000 -> <<0:3, 25:5, v:16>>
    v if v < 0x100000000 -> <<0:3, 26:5, v:32>>
    v if v < 0x10000000000000000 -> <<0:3, 27:5, v:64>>
    _ -> todo
  }
}

pub fn int_encode(value: Int) -> BitArray {
  let value = { value * -1 } - 1
  case value {
    v if v < 24 -> <<1:3, v:5>>
    // TODO verify limits
    v if v < 0x100 -> <<1:3, 24:5, v:8>>
    v if v < 0x10000 -> <<1:3, 25:5, v:16>>
    v if v < 0x100000000 -> <<1:3, 26:5, v:32>>
    v if v < 0x10000000000000000 -> <<1:3, 27:5, v:64>>
    _ -> todo
  }
}

fn float_encode(value: Float) -> BitArray {
  let bytes =
    value
    |> ieee_float.finite
    |> ieee_float.to_bytes_64_be

  <<7:3, 27:5, bytes:bits>>
}

type BinaryEncoding {
  BinaryEncoding(BitArray)
  StringEncoding(String)
}

fn binary_encode(value: BinaryEncoding) -> BitArray {
  let #(value, major) = case value {
    BinaryEncoding(v) -> {
      #(bit_array.pad_to_bytes(v), 2)
    }
    StringEncoding(v) -> #(bit_array.from_string(v), 3)
  }

  let length = bit_array.byte_size(value)

  case length {
    v if v < 24 -> <<major:3, v:5, value:bits>>
    v if v < 0x100 -> <<major:3, 25:5, v:8, value:bits>>
    v if v < 0x10000 -> <<major:3, 26:5, v:16, value:bits>>
    v if v < 0x100000000 -> <<major:3, 27:5, v:32, value:bits>>
    v if v < 0x10000000000000000 -> <<major:3, 28:5, v:64, value:bits>>
    _ -> todo
  }
}

fn array_encode(value: List(CBOR)) -> BitArray {
  let length = list.length(value)

  let data =
    list.map(value, to_bit_array)
    |> bit_array.concat

  case length {
    v if v < 24 -> <<4:3, v:5, data:bits>>
    v if v < 0x100 -> <<4:3, 25:5, v:8, data:bits>>
    v if v < 0x10000 -> <<4:3, 26:5, v:16, data:bits>>
    v if v < 0x100000000 -> <<4:3, 27:5, v:32, data:bits>>
    v if v < 0x10000000000000000 -> <<4:3, 28:5, v:64, data:bits>>
    _ -> todo
  }
}

fn bool_encode(value: Bool) -> BitArray {
  case value {
    False -> <<0xf4>>
    True -> <<0xf5>>
  }
}

fn null_encode() -> BitArray {
  <<0xf6>>
}

fn undefined_encode() -> BitArray {
  <<0xf7>>
}

fn map_encode(value: List(#(CBOR, CBOR))) -> BitArray {
  let n_pairs = list.length(value)

  let data =
    list.fold_right(value, <<>>, fn(acc, a) {
      let k_data = to_bit_array(a.0)
      let v_data = to_bit_array(a.1)

      bit_array.concat([k_data, v_data, acc])
    })

  case n_pairs {
    v if v < 24 -> <<5:3, v:5, data:bits>>
    v if v < 0x100 -> <<5:3, 25:5, v:8, data:bits>>
    v if v < 0x10000 -> <<5:3, 26:5, v:16, data:bits>>
    v if v < 0x100000000 -> <<5:3, 27:5, v:32, data:bits>>
    v if v < 0x10000000000000000 -> <<5:3, 28:5, v:64, data:bits>>
    _ -> todo
  }
}

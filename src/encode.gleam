import gbor.{type CBOR}
import gleam/bit_array
import gleam/list
import gleam/result
import gleam/string
import ieee_float

pub type EncodeError {
  EncodeError(String)
}

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

pub fn to_bit_array(value: CBOR) -> Result(BitArray, EncodeError) {
  case value {
    gbor.Int(v) if v >= 0 -> uint_encode(v)
    gbor.Int(v) if v < 0 -> int_encode(v)
    gbor.Float(v) -> Ok(float_encode(v))
    gbor.Binary(v) -> binary_encode(BinaryEncoding(v))
    gbor.String(v) -> binary_encode(StringEncoding(v))
    gbor.Array(v) -> array_encode(v)
    gbor.Map(v) -> map_encode(v)
    gbor.Bool(v) -> Ok(bool_encode(v))
    gbor.Null -> Ok(null_encode())
    gbor.Undefined -> Ok(undefined_encode())
    v -> {
      Error(EncodeError("Unknown CBOR value: " <> string.inspect(v)))
    }
  }
}

pub fn uint_encode(value: Int) -> Result(BitArray, EncodeError) {
  case value {
    v if v < 24 -> Ok(<<0:3, v:5>>)
    // TODO verify limits
    v if v < 0x100 -> Ok(<<0:3, 24:5, v:8>>)
    v if v < 0x10000 -> Ok(<<0:3, 25:5, v:16>>)
    v if v < 0x100000000 -> Ok(<<0:3, 26:5, v:32>>)
    v if v < 0x10000000000000000 -> Ok(<<0:3, 27:5, v:64>>)
    v -> Error(EncodeError("Int value too large: " <> string.inspect(v)))
  }
}

pub fn int_encode(value: Int) -> Result(BitArray, EncodeError) {
  let value = { value * -1 } - 1
  case value {
    v if v < 24 -> Ok(<<1:3, v:5>>)
    // TODO verify limits
    v if v < 0x100 -> Ok(<<1:3, 24:5, v:8>>)
    v if v < 0x10000 -> Ok(<<1:3, 25:5, v:16>>)
    v if v < 0x100000000 -> Ok(<<1:3, 26:5, v:32>>)
    v if v < 0x10000000000000000 -> Ok(<<1:3, 27:5, v:64>>)
    v -> Error(EncodeError("Int value too large: " <> string.inspect(v)))
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

fn binary_encode(value: BinaryEncoding) -> Result(BitArray, EncodeError) {
  let #(value, major) = case value {
    BinaryEncoding(v) -> {
      #(bit_array.pad_to_bytes(v), 2)
    }
    StringEncoding(v) -> #(bit_array.from_string(v), 3)
  }

  let length = bit_array.byte_size(value)

  case length {
    v if v < 24 -> Ok(<<major:3, v:5, value:bits>>)
    v if v < 0x100 -> Ok(<<major:3, 24:5, v:8, value:bits>>)
    v if v < 0x10000 -> Ok(<<major:3, 25:5, v:16, value:bits>>)
    v if v < 0x100000000 -> Ok(<<major:3, 26:5, v:32, value:bits>>)
    v if v < 0x10000000000000000 -> Ok(<<major:3, 27:5, v:64, value:bits>>)
    _ -> Error(EncodeError("Binary length too large"))
  }
}

fn array_encode(value: List(CBOR)) -> Result(BitArray, EncodeError) {
  let length = list.length(value)

  use data <- result.try(list.try_map(value, to_bit_array))
  let data = bit_array.concat(data)

  case length {
    v if v < 24 -> Ok(<<4:3, v:5, data:bits>>)
    v if v < 0x100 -> Ok(<<4:3, 24:5, v:8, data:bits>>)
    v if v < 0x10000 -> Ok(<<4:3, 25:5, v:16, data:bits>>)
    v if v < 0x100000000 -> Ok(<<4:3, 26:5, v:32, data:bits>>)
    v if v < 0x10000000000000000 -> Ok(<<4:3, 27:5, v:64, data:bits>>)
    _ -> Error(EncodeError("Array length too large"))
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

fn map_encode(value: List(#(CBOR, CBOR))) -> Result(BitArray, EncodeError) {
  let n_pairs = list.length(value)

  use data <- result.try(
    list.try_fold(value, <<>>, fn(acc, a) {
      use k_data <- result.try(to_bit_array(a.0))
      use v_data <- result.try(to_bit_array(a.1))
      //Ok(bit_array.concat([k_data, v_data, acc]))
      Ok(bit_array.concat([acc, v_data, k_data]))
    }),
  )

  //let data = list.try

  //let data =
  //  list.fold_right(value, <<>>, fn(acc, a) {
  //    let k_data = to_bit_array(a.0)
  //    let v_data = to_bit_array(a.1)

  //    bit_array.concat([k_data, v_data, acc])
  //  })

  case n_pairs {
    v if v < 24 -> Ok(<<5:3, v:5, data:bits>>)
    v if v < 0x100 -> Ok(<<5:3, 25:5, v:8, data:bits>>)
    v if v < 0x10000 -> Ok(<<5:3, 26:5, v:16, data:bits>>)
    v if v < 0x100000000 -> Ok(<<5:3, 27:5, v:32, data:bits>>)
    v if v < 0x10000000000000000 -> Ok(<<5:3, 28:5, v:64, data:bits>>)
    _ -> Error(EncodeError("N pairs size too large"))
  }
}

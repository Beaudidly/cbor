# gbor

[![Package Version](https://img.shields.io/hexpm/v/gbor)](https://hex.pm/packages/gbor)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/gbor/)

A CBOR encoding/decoding library for Gleam.

# Installation
Add GitHub
```toml
[dependencies]
gbor = { git = "git@github.com:Beaudidly/gbor.git", ref = "main" }
```

# Usage
Please check out the encode/decode tests.

## Encode
```gleam
import gbor
import gleam/list

type Cat {
  Cat(name: String, lives: Int, nicknames: List(String))
}

fn cat_encoder(cat: Cat) -> BitArray {
  encode.map([
    #(encode.string("name"), encode.string(cat.name)),
    #(encode.string("lives"), encode.int(cat.lives)),
    #(
      encode.string("nicknames"),
      encode.array(list.map(cat.nicknames, encode.string)),
    ),
  ])
  |> encode.to_bit_array
}
```

## Decode
```gleam
import gbor
import gleam/dynamic/decode as dy_decode

fn decode_cat(data: BitArray) -> Result(Cat, List(dy_decode.DecodeError)) {
  let cat_decoder = {
    use name <- dy_decode.field("name", dy_decode.string)
    use lives <- dy_decode.field("lives", dy_decode.int)
    use nicknames <- dy_decode.field(
      "nicknames",
      dy_decode.list(dy_decode.string),
    )
    dy_decode.success(Cat(name:, lives:, nicknames:))
  }

  decode.parse(from: data, using: cat_decoder)
}
```

## Development

```sh
gleam test  # Run the tests
```

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
import gbor as g
import gbor/encode

import gleam/list

type Cat {
  Cat(name: String, lives: Int, nicknames: List(String))
}

fn cat_encoder(cat: Cat) -> Result(BitArray, encode.EncodeError) {
  g.CBMap([
    #(g.CBString("name"), g.CBString(cat.name)),
    #(g.CBString("lives"), g.CBInt(cat.lives)),
    #(g.CBString("nicknames"), g.CBArray(list.map(cat.nicknames, g.CBString))),
  ])
  |> encode.to_bit_array
}

pub fn main() {
  let assert Ok(bin) =
    Cat("Fluffy", 9, ["Fluff", "Fluffers"])
    |> cat_encoder
}
```

## Decode
```gleam
import gbor/decode as gbor_decode
import gleam/bit_array
import gleam/dynamic/decode as gdd

pub type Cat {
  Cat(name: String, lives: Int, nicknames: List(String))
}

fn decode_cat(data: BitArray) -> Result(Cat, List(gdd.DecodeError)) {
  let cat_decoder = {
    use name <- gdd.field("name", gdd.string)
    use lives <- gdd.field("lives", gdd.int)
    use nicknames <- gdd.field("nicknames", gdd.list(gdd.string))
    gdd.success(Cat(name:, lives:, nicknames:))
  }

  let assert Ok(cbor) = gbor_decode.from_bit_array(data)

  gdd.run(gbor_decode.cbor_to_dynamic(cbor), cat_decoder)
}

pub fn main() {
  let assert Ok(bin_cat) =
    bit_array.base64_decode(
      "o2RuYW1lZEx1Y3llbGl2ZXMIaW5pY2tuYW1lc4JqTHVja3kgTHVjeWNMdWM=",
    )
  assert Ok(Cat("Lucy", 8, ["Lucky Lucy", "Luc"])) == decode_cat(bin_cat)
}
```

## Development

```sh
gleam test  # Run the tests
```

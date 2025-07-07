import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode as gdd

@external(erlang, "cbor_ffi", "decode")
pub fn decode(data: BitArray) -> Dynamic

@external(erlang, "experiment_ffi", "tag")
pub fn tag(tag: Int, value: Dynamic) -> Dynamic

@external(erlang, "experiment_ffi", "is_tag")
pub fn is_tag(value: Dynamic) -> Bool

@external(erlang, "experiment_ffi", "check_tag")
pub fn check_tag(value: Dynamic) -> Result(#(Int, Dynamic), String)

pub fn tag_decoder(tag: Int) {
  gdd.new_primitive_decoder("tag", fn(d) {
    case check_tag(d) {
      Ok(#(tag_number, value)) -> {
        case tag_number == tag {
          True -> Ok(value)
          False -> Error(dynamic.nil())
        }
      }
      Error(_) -> Error(dynamic.nil())
    }
  })
}

import gleam/dynamic

@external(erlang, "erl_gbor", "to_tagged")
pub fn to_tagged(tag: Int, value: dynamic.Dynamic) -> dynamic.Dynamic

@external(erlang, "erl_gbor", "check_tagged")
pub fn check_tagged(
  tagged: dynamic.Dynamic,
) -> Result(#(Int, dynamic.Dynamic), String)

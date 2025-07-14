-module(erl_gbor).

-export([to_tagged/2]).

to_tagged(Tag, Value) ->
  {cbor_tagged__, Tag, Value}.

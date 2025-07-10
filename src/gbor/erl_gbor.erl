-module(erl_gbor).

-export([to_tagged/2, check_tagged/1]).

to_tagged(Tag, Value) ->
  {cbor_tagged__, Tag, Value}.


check_tagged(Tagged) ->
  case Tagged of
    {cbor_tagged__, Tag, Value} ->
      {ok, {Tag, Value}};
    _ ->
      {error, invalid_tagged_value}
  end.
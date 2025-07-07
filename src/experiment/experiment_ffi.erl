-module(experiment_ffi).

-export([tag/2, is_tag/1, check_tag/1]).

tag(Tag, Data) ->
    {tag, Tag, Data}.

is_tag(Data) ->
    is_tuple(Data) andalso tuple_size(Data) == 3 andalso element(1, Data) == tag.

check_tag(Data) ->
    case is_tag(Data) of
        true -> {ok, {element(2, Data), element(3, Data)}};
        false -> {error, not_a_tag}
    end.

-module(epmdless_dist_app).

-behaviour(application).

-export([start/0]).
-export([start/2, stop/1]).


start() ->
    application:start(?MODULE).


start(_StartType, _StartArgs) ->
    case epmdless_dist_sup:start_link() of
        {ok, _} = Ok -> Ok;
        {error, {already_started, Pid}} -> {ok, Pid}
    end.


stop(_State) ->
    ok.

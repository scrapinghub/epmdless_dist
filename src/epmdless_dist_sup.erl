-module(epmdless_dist_sup).

-behaviour(supervisor).

-export([start_link/0, init/1, stop/0]).
-export([start_child/3, map_children/1]).
-export([first_succcessful_or_last_failed_child/2,
         first_succcessful_or_last_failed_child/4]).
-export([children/0, called_children/0]).


start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    {ok, {{simple_one_for_one, 0, 1},
          [epmdless_client:child_spec()]}}.

stop() ->
    gen_server:stop(?MODULE).

start_child(Name, Port, Family) ->
    supervisor:start_child(?MODULE, [Name, Port, Family]).

map_children(Map) ->
    lists:map(Map, children()).

first_succcessful_or_last_failed_child(Fun, IsSuccessFul) ->
    first_succcessful_or_last_failed_child(Fun, IsSuccessFul, children(), []).

first_succcessful_or_last_failed_child(_Fun, _IsSuccessFul, [], []) ->
    no_children;
first_succcessful_or_last_failed_child(_Fun, _IsSuccessFul, [], Failures) ->
    hd(Failures);
first_succcessful_or_last_failed_child(Fun, IsSuccessFul, [Child|Rest], Failures) ->
    Applied = Fun(Child),
    case IsSuccessFul(Applied) of
        true -> Applied;
        _ -> first_succcessful_or_last_failed_child(Fun, IsSuccessFul, Rest, [Applied|Failures])
    end.

children() -> filter_children(fun epmdless_client:is_alive/1).

called_children() ->
    filter_children(fun(Child) ->
                            epmdless_client:is_alive(Child)
                            andalso
                            epmdless_client:is_caller(Child)
                    end).

filter_children(Filter) ->
    case is_pid(whereis(epmdless_alt_0)) of
        true ->
            [ Child || {undefined, Child, worker, [epmdless_client]}
               <- supervisor:which_children(?MODULE), Filter(Child) ];
        false ->
            epmdless_client:children(Filter)
    end.



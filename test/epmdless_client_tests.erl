-module(epmdless_client_tests).

-include_lib("eunit/include/eunit.hrl").

proxy_manager_test_() ->
    {setup,
     fun() ->
        application:set_env(epmdless_dist, node_list,
                            [{a,b,1},{e,b,1},{a,d,2},{e,d,3}]),
        epmdless_client:start_link()
     end,
     fun({ok, Pid}) ->
        true = unlink(Pid),
        ok = gen_server:call(Pid, stop)
     end,
     [
        {"register_node", fun register_node/0},
        {"get_info", fun get_info/0},
        {"node_please", fun node_please/0},
        {"host_please", fun host_please/0},
        {"port_please", fun port_please/0},
        {"add_node", fun add_node/0},
        {"remove_node", fun remove_node/0},
        {"list_nodes", fun list_nodes/0},
        {"names", fun names/0}
    ]}.

register_node() ->
    {ok, _} = epmdless_client:?FUNCTION_NAME(test_node, 10000, tcp),
    [
     {node,{node_key,a,b},'a@b',"b",1,_},
     {node,{node_key,a,d},'a@d',"d",2,_},
     {node,{node_key,e,b},'e@b',"b",1,_},
     {node,{node_key,e,d},'e@d',"d",3,_}
    ] = lists:sort(ets:tab2list(epmdless_dist_node_registry)),

    [
     {map,'a@b',{node_key,a,b}},
     {map,'a@d',{node_key,a,d}},
     {map,'e@b',{node_key,e,b}},
     {map,'e@d',{node_key,e,d}}
    ] = lists:sort(ets:tab2list(epmdless_dist_node_registry_atoms)),

    [
     {map,"b",b},
     {map,"d",d}
    ] = lists:sort(ets:tab2list(epmdless_dist_node_registry_hosts)),

    [
     {map,a,b},
     {map,a,d},
     {map,e,b},
     {map,e,d}
    ] = lists:sort(ets:tab2list(epmdless_dist_node_registry_parts)).

get_info() ->
    [{dist_port, 10000}] = epmdless_client:?FUNCTION_NAME().

node_please() ->
    %% should return the last added
    'a@d' = epmdless_client:?FUNCTION_NAME(a).

host_please() ->
    nohost = epmdless_client:?FUNCTION_NAME('not@exists'),
    {host, "b"} = epmdless_client:?FUNCTION_NAME('a@b').

port_please() ->
    noport = epmdless_client:?FUNCTION_NAME('not', 'exists'),
    noport = epmdless_client:?FUNCTION_NAME('not@exists', 'exists'),
    {port, 3, 5} = epmdless_client:?FUNCTION_NAME(e, d),
    {port, 3, 5} = epmdless_client:?FUNCTION_NAME('e@d', "d"),
    {port, 3, 5} = epmdless_client:?FUNCTION_NAME(e, "d").

add_node() ->
    ok = epmdless_client:?FUNCTION_NAME('i@j', 11111),
    ok = epmdless_client:?FUNCTION_NAME('i@j', {1,1,1,1}, 11111).

remove_node() ->
    ok = epmdless_client:?FUNCTION_NAME('not@exists'),
    ok = epmdless_client:?FUNCTION_NAME('a@d'),
    port_please().

list_nodes() ->
    [{'a@b',{"b",1}},
     {'e@b',{"b",1}},
     {'e@d',{"d",3}},
     {'i@j',{{1,1,1,1},11111}}] = lists:sort(epmdless_client:?FUNCTION_NAME()).

names() ->
    ['a@b', 'e@b'] = lists:sort(epmdless_client:?FUNCTION_NAME(b)),
    ['a@b', 'e@b'] = lists:sort(epmdless_client:?FUNCTION_NAME("b")),
    [] = epmdless_client:?FUNCTION_NAME().


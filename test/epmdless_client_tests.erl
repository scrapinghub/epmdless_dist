-module(epmdless_client_tests).

-include_lib("eunit/include/eunit.hrl").

proxy_manager_test_() ->
    {setup,
     fun() ->
        application:set_env(epmdless_dist, node_list,
                            [{a,b,1},{e,b,1},{a,d,2},{e,d,3},{l,localhost,4}]),
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
    {ok, _} = epmdless_client:?FUNCTION_NAME(test_node, 10000, inet_tcp),
    [
     {node,{node_key,a,b},'a@b',undefined,"b",1,_},
     {node,{node_key,a,d},'a@d',undefined,"d",2,_},
     {node,{node_key,e,b},'e@b',undefined,"b",1,_},
     {node,{node_key,e,d},'e@d',undefined,"d",3,_},
     {node,{node_key,l,localhost},'l@localhost',{127,0,0,1},"localhost",4,_},
     {node,{node_key,nonode,nohost}, 'nonode@nohost', undefined, "nohost", undefined, _}
    ] = lists:sort(ets:tab2list(epmdless_dist_node_registry)),

    [
     {map,'a@b',{node_key,a,b}},
     {map,'a@d',{node_key,a,d}},
     {map,'e@b',{node_key,e,b}},
     {map,'e@d',{node_key,e,d}},
     {map,'l@localhost',{node_key,l,localhost}},
     {map,nonode@nohost,{node_key,nonode,nohost}}
    ] = lists:sort(ets:tab2list(epmdless_dist_node_registry_atoms)),

    [
     {map,{127,0,0,1},localhost}
    ] = lists:sort(ets:tab2list(epmdless_dist_node_registry_addrs)),

    [
     {map,"b",b},
     {map,"d",d},
     {map,"localhost",localhost},
     {map,"nohost",nohost}
    ] = lists:sort(ets:tab2list(epmdless_dist_node_registry_hosts)),

    [
     {map,a,b},
     {map,a,d},
     {map,e,b},
     {map,e,d},
     {map,l,localhost},
     {map,nonode,nohost}
    ] = lists:sort(ets:tab2list(epmdless_dist_node_registry_parts)).

get_info() ->
    [{dist_port, 10000}] = epmdless_client:?FUNCTION_NAME().

node_please() ->
    %% should return the last added
    'a@d' = epmdless_client:?FUNCTION_NAME(a),
    %% should return undefined
    undefined = epmdless_client:?FUNCTION_NAME(non_existent).


host_please() ->
    nohost = epmdless_client:?FUNCTION_NAME('not@exists'),
    {host, "b"} = epmdless_client:?FUNCTION_NAME('a@b').

port_please() ->
    noport = epmdless_client:?FUNCTION_NAME('not', 'exists'),
    noport = epmdless_client:?FUNCTION_NAME('not@exists', 'exists'),
    {port, 3, 5} = epmdless_client:?FUNCTION_NAME(e, d),
    {port, 3, 5} = epmdless_client:?FUNCTION_NAME(e, "d"),
    {port, 3, 5} = epmdless_client:?FUNCTION_NAME("e", d),
    {port, 3, 5} = epmdless_client:?FUNCTION_NAME("e", "d"),
    {port, 3, 5} = epmdless_client:?FUNCTION_NAME('e@d', d),
    {port, 3, 5} = epmdless_client:?FUNCTION_NAME('e@d', "d"),
    {port, 3, 5} = epmdless_client:?FUNCTION_NAME("e@d", d),
    {port, 3, 5} = epmdless_client:?FUNCTION_NAME("e@d", "d"),
    {port, 4, 5} = epmdless_client:?FUNCTION_NAME("l", localhost),
    {port, 4, 5} = epmdless_client:?FUNCTION_NAME("l", {127,0,0,1}),
    {port, 4, 5} = epmdless_client:?FUNCTION_NAME("l@localhost", {127,0,0,1}),
    {port, 4, 5} = epmdless_client:?FUNCTION_NAME("l@localhost", localhost).

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
     {'i@j',{{1,1,1,1},11111}},
     {'l@localhost',{{127,0,0,1},4}},
     {nonode@nohost,{"nohost",undefined}}
    ] = lists:sort(epmdless_client:?FUNCTION_NAME()).

names() ->
    ['a@b', 'e@b'] = lists:sort(epmdless_client:?FUNCTION_NAME(b)),
    ['a@b', 'e@b'] = lists:sort(epmdless_client:?FUNCTION_NAME("b")),
    ['l@localhost'] = lists:sort(epmdless_client:?FUNCTION_NAME({127,0,0,1})),
    [] = epmdless_client:?FUNCTION_NAME().


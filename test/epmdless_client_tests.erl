-module(epmdless_client_tests).

-include_lib("eunit/include/eunit.hrl").

epmdless_test_() ->
    {setup,
     fun() ->
        Hostname = list_to_atom(epmdless_client:gethostname(inet_tcp)),
        ?debugVal(Hostname),
        SocksNodes = [ {Sock, {list_to_atom([LP]), Dom, Port}}
                       || LP <- lists:seq($a,$d),
                          Dom <- [Hostname, localhost],
                          {ok, Sock} <- [inet_tcp:listen(0, [])],
                          {ok, Port} <- [inet:port(Sock)] ],
        {Socks, Nodes} = lists:unzip(SocksNodes),
        ?debugVal(Nodes),
        application:set_env(epmdless_dist, node_list, Nodes),
        {ok, Pid} = epmdless_dist:start_link(),
        {ok, DistSock} = inet_tcp:listen(0, []),
        {ok, DistPort} = inet:port(DistSock),
        {Socks, Nodes, Pid, {DistSock, DistPort}}
     end,
     fun({Socks, _Ports, Pid, {DistSock, _DistPort}}) ->
        lists:foreach(fun inet_tcp:close/1, Socks),
        inet_tcp:close(DistSock),
        true = unlink(Pid),
        ok = gen_server:stop(Pid)
     end,
     {with,
       [fun register_node/1,
        fun get_info/1,
        fun node_please/1,
        fun local_part/1,
        fun host_please/1,
        fun port_please/1,
        fun add_node/1,
        fun remove_node/1,
        fun list_nodes/1,
        fun names/1]}
     }.

abstract_add_remove() ->
    fun([RemArgs|PortArgs], {_,{_, Port}}) ->
        fun() ->
        %dbg:tracer(), dbg:p(all,c),
        %dbg:tpl(epmdless_client, []),
        %dbg:tpl(ets, []),
        ?assertEqual(ok, apply(epmdless_dist, add_node, PortArgs++[Port])),
        timer:sleep(100),
        %?debugVal({PortArgs, Port}),
        ?assertEqual({port, Port, 5}, apply(epmdless_dist, port_please, PortArgs)),
        ?assertEqual(ok, apply(epmdless_dist, remove_node, [RemArgs])),
        ?assertEqual(noport, apply(epmdless_dist, port_please, PortArgs))
        end
    end.

add_remove_test_() ->
    {foreachx,
     fun(_Args) ->
        {ok, Pid} = epmdless_dist:start_link(),
        {ok, DistSock} = inet_tcp:listen(0, []),
        {ok, DistPort} = inet:port(DistSock),
        {ok, _} = epmdless_dist:register_node(test_node, DistPort, inet_tcp),
        {Pid, {DistSock, DistPort}}
     end,
     fun(_Args, {Pid, {DistSock, _}}) ->
        inet_tcp:close(DistSock),
        true = unlink(Pid),
        ok = gen_server:stop(Pid),
        exit(Pid, kill)
     end,
     [{['i@127.0.0.1',  'i@127.0.0.1'],              abstract_add_remove()},
      {['i@127.0.0.1',  'i@127.0.0.1', {127,0,0,1}], abstract_add_remove()},
      {['i@127.0.0.1',  i, "127.0.0.1"],             abstract_add_remove()},
      {['i@localhost',  'i@localhost'],              abstract_add_remove()},
      {['i@localhost',  'i@localhost', "localhost"], abstract_add_remove()},
      {['i@localhost',  'i@localhost', "127.0.0.1"], abstract_add_remove()},
      {['i@localhost',  'i@localhost', {127,0,0,1}], abstract_add_remove()},
      {['i@localhost',  i, localhost],               abstract_add_remove()},
      {['i@localhost',  i, "localhost"],             abstract_add_remove()}]
    }.


register_node({_Socks, Nodes, _Pid, {_DistSock, DistPort}}) ->
    {ok, _} = epmdless_dist:?FUNCTION_NAME(test_node, DistPort, inet_tcp),
    timer:sleep(1000),
    PA = get_port(a, localhost, Nodes),
    PB = get_port(b, localhost, Nodes),
    PC = get_port(c, localhost, Nodes),
    PD = get_port(d, localhost, Nodes),
    Hostname = epmdless_client:gethostname(inet_tcp),
    HostAtom = list_to_atom(Hostname),
    PAH = get_port(a, HostAtom, Nodes),
    PBH = get_port(b, HostAtom, Nodes),
    PCH = get_port(c, HostAtom, Nodes),
    PDH = get_port(d, HostAtom, Nodes),
    ?assertMatch(
       [{node,{node_key,a,_adomain}, _aname, {_,_,_,_}, Hostname, PAH, _},
        {node,{node_key,a,localhost},'a@localhost',{127,0,0,1},"localhost",PA,_},
        {node,{node_key,b,_bdomain}, _bname, {_,_,_,_}, Hostname, PBH, _},
        {node,{node_key,b,localhost},'b@localhost',{127,0,0,1},"localhost",PB,_},
        {node,{node_key,c,_cdomain}, _cname, {_,_,_,_}, Hostname, PCH, _},
        {node,{node_key,c,localhost},'c@localhost',{127,0,0,1},"localhost",PC,_},
        {node,{node_key,d,_ddomain}, _dname, {_,_,_,_}, Hostname, PDH, _},
        {node,{node_key,d,localhost},'d@localhost',{127,0,0,1},"localhost",PD,_},
        {node,{node_key,test_node,_testdomain}, _testname, _testip, _testhost, DistPort, _}],
       lists:sort(ets:tab2list(epmdless_inet))),

    ?assertMatch(
       [{map,_aname,{node_key,a,_adomain}},{map,'a@localhost',{node_key,a,localhost}},
        {map,_bname,{node_key,b,_bdomain}},{map,'b@localhost',{node_key,b,localhost}},
        {map,_cname,{node_key,c,_cdomain}},{map,'c@localhost',{node_key,c,localhost}},
        {map,_dname,{node_key,d,_ddomain}},{map,'d@localhost',{node_key,d,localhost}},
        {map,_testname,{node_key,test_node,_testdomain}}],
       lists:sort(ets:tab2list(epmdless_inet_atoms))),
    ?assertMatch(
       [{map,{127,0,0,1},localhost},
        {map,{  _,_,_,_},_testdomain}],
       lists:sort(ets:tab2list(epmdless_inet_addrs))),

    ?assertMatch(
       [{map,Hostname,HostAtom},
        {map,"localhost",localhost}],
       lists:sort(ets:tab2list(epmdless_inet_hosts))),

    ?assertMatch(
       [{map,a,HostAtom},{map,a,localhost},
        {map,b,HostAtom},{map,b,localhost},
        {map,c,HostAtom},{map,c,localhost},
        {map,d,HostAtom},{map,d,localhost},
        {map,test_node,_testdomain}],
       lists:sort(ets:tab2list(epmdless_inet_parts))).

get_info({_Socks, _Nodes, _Pid, {_DistSock, DistPort}}) ->
    [{dist_port, DistPort}] = epmdless_dist:?FUNCTION_NAME().

node_please(_) ->
    %% should return undefined
    undefined = epmdless_dist:?FUNCTION_NAME(non_existent),
    %% should return the last added
    'a@localhost' = epmdless_dist:?FUNCTION_NAME(a).

local_part(_) ->
    %% should return undefined
    undefined = epmdless_dist:?FUNCTION_NAME(non_existent),
    a = epmdless_dist:?FUNCTION_NAME('a@localhost').

host_please(_) ->
    nohost = epmdless_dist:?FUNCTION_NAME('not@exists'),
    {host, {127,0,0,1}} = epmdless_dist:?FUNCTION_NAME('a@localhost').

port_please({_Socks, Nodes, _Pid, {_DistSock, _DistPort}}) ->
    noport = epmdless_dist:?FUNCTION_NAME('not', 'exists'),
    noport = epmdless_dist:?FUNCTION_NAME('not@exists', 'exists'),
    [ begin
          LPStr = atom_to_list(LP),
          NodeStr = LPStr++[$@|"localhost"],
          NodeAtom = list_to_atom(NodeStr),
          ?assertEqual({port, P, 5}, epmdless_dist:?FUNCTION_NAME(LP, localhost)),
          ?assertEqual({port, P, 5}, epmdless_dist:?FUNCTION_NAME(LP, {127,0,0,1})),
          ?assertEqual({port, P, 5}, epmdless_dist:?FUNCTION_NAME(LPStr, localhost)),
          ?assertEqual({port, P, 5}, epmdless_dist:?FUNCTION_NAME(LPStr, {127,0,0,1})),
          ?assertEqual({port, P, 5}, epmdless_dist:?FUNCTION_NAME(NodeAtom, localhost)),
          ?assertEqual({port, P, 5}, epmdless_dist:?FUNCTION_NAME(NodeAtom, {127,0,0,1})),
          ?assertEqual({port, P, 5}, epmdless_dist:?FUNCTION_NAME(NodeStr, localhost)),
          ?assertEqual({port, P, 5}, epmdless_dist:?FUNCTION_NAME(NodeStr, {127,0,0,1}))
      end || {LP, localhost, P} <- Nodes ].

add_node({_Socks, _Nodes, _Pid, {_DistSock, DistPort}}) ->
    %% Tests with hostname
    Hostname = epmdless_client:gethostname(inet_tcp),
    NodeName = list_to_atom([$i, $@|Hostname]),

    ok = epmdless_dist:?FUNCTION_NAME(NodeName, DistPort),
    timer:sleep(100),
    {port, DistPort, 5} = epmdless_dist:port_please(i, Hostname),
    ok = epmdless_dist:remove_node(NodeName),
    noport = epmdless_dist:port_please(i, Hostname),

    ok = epmdless_dist:?FUNCTION_NAME(NodeName, Hostname, DistPort),
    timer:sleep(100),
    {port, DistPort, 5} = epmdless_dist:port_please(i, Hostname),
    ok = epmdless_dist:remove_node(NodeName),
    noport = epmdless_dist:port_please(i, Hostname),

    ok = epmdless_dist:?FUNCTION_NAME(i, list_to_atom(Hostname), DistPort),
    timer:sleep(100),
    {port, DistPort, 5} = epmdless_dist:port_please(i, Hostname),
    ok = epmdless_dist:remove_node(NodeName),
    noport = epmdless_dist:port_please(i, Hostname).

remove_node({_Socks, _Nodes, _Pid, {_DistSock, _DistPort}}) ->
    ok = epmdless_dist:?FUNCTION_NAME('not@exists'),

    {port, Port, 5} = epmdless_dist:port_please(a, localhost),
    ok = epmdless_dist:?FUNCTION_NAME('a@localhost'),
    noport = epmdless_dist:port_please(a, localhost),
    epmdless_dist:add_node(a, localhost, Port),
    timer:sleep(100),
    {port, Port, 5} = epmdless_dist:port_please(a, localhost),
    ok = epmdless_dist:?FUNCTION_NAME("a@localhost"),
    noport = epmdless_dist:port_please(a, localhost),
    epmdless_dist:add_node(a, localhost, Port),
    timer:sleep(100).

list_nodes({_Socks, Nodes, _Pid, {_DistSock, DistPort}}) ->
    PA = get_port(a, localhost, Nodes),
    PB = get_port(b, localhost, Nodes),
    PC = get_port(c, localhost, Nodes),
    PD = get_port(d, localhost, Nodes),
    Hostname = list_to_atom(epmdless_client:gethostname(inet_tcp)),
    PAH = get_port(a, Hostname, Nodes),
    PBH = get_port(b, Hostname, Nodes),
    PCH = get_port(c, Hostname, Nodes),
    PDH = get_port(d, Hostname, Nodes),
    ?assertMatch(
    [{_ahostnode, {_ahostip, PAH}},{'a@localhost',{{127,0,0,1},PA}},
     {_bhostnode, {_bhostip, PBH}},{'b@localhost',{{127,0,0,1},PB}},
     {_chostnode, {_chostip, PCH}},{'c@localhost',{{127,0,0,1},PC}},
     {_dhostnode, {_dhostip, PDH}},{'d@localhost',{{127,0,0,1},PD}},
     {_testname, {_testip, DistPort}}],
    lists:sort(epmdless_dist:?FUNCTION_NAME())).

names({_Socks, _Nodes, _Pid, {_DistSock, _DistPort}}) ->
    LocalNodes = ['a@localhost','b@localhost','c@localhost','d@localhost'],
    ?assertEqual(LocalNodes, lists:sort(epmdless_dist:?FUNCTION_NAME(localhost))),
    ?assertEqual(LocalNodes, lists:sort(epmdless_dist:?FUNCTION_NAME("localhost"))),
    ?assertEqual(LocalNodes, lists:sort(epmdless_dist:?FUNCTION_NAME({127,0,0,1}))),
    ?assertMatch([_,_,_,_,_], lists:sort(epmdless_dist:?FUNCTION_NAME())).

%% helpers

get_port(LocalPart, Domain, Nodes) ->
    [Port] = [P || {LP, D, P} <- Nodes, LP == LocalPart, D == Domain],
    Port.

-module(epmdless_dist_tests).
-include_lib("eunit/include/eunit.hrl").

dist_discovery_test_() ->
    {setup,
     fun() ->
             {ok, Sock} = inet_tcp:listen(0, []),
             {ok, Port} = inet:port(Sock),
             Val1 = #{<<"hostname">> => <<"h1">>, <<"ports">> => [1,2]},
             Val2 = #{<<"hostname">> => <<"localhost">>, <<"ports">> => [3,4],
                      <<"namedports">> => #{<<"dist">> => Port, <<"eless_tcp">> => 6}},
             Body = jiffy:encode([#{<<"Key">>   => <<"upstreams/n-1_node/xxx">>,
                                    <<"Value">> => base64:encode(jiffy:encode(Val1))},
                                  #{<<"Key">>   => <<"upstreams/test-node_node/xxx">>,
                                    <<"Value">> => base64:encode(jiffy:encode(Val2))}]),
             meck:expect(httpc, request, fun(_, _, _, _) -> {ok, {200, [], Body}} end),

             application:load(erlang_consul_node_discovery),
             application:set_env(erlang_consul_node_discovery, consul_url, "http://127.0.0.1:8000/"),
             application:set_env(erlang_consul_node_discovery, discovery_callback, epmdless_dist),
             application:set_env(erlang_consul_node_discovery, port_names, [{<<"dist">>, inet_tcp}]),
             {ok, EPid} = epmdless_dist:start_link(),
             {ok, DistSock} = inet_tcp:listen(0, []),
             {ok, DistPort} = inet:port(DistSock),
             {ok, _} = epmdless_dist:register_node(test_node, DistPort, inet_tcp),
             %dbg:tracer(), dbg:p(all,c),
             %dbg:tpl(epmdless_dist, [{'_',[],[{return_trace}]}]),
             %dbg:tpl(epmdless_client, [{'_',[],[{return_trace}]}]),
             {ok, CPid} = erlang_consul_node_discovery_worker:start_link(),
             {[EPid, CPid], [DistSock, Sock], [DistPort, Port]}
     end,
     fun({Pids, Socks, _}) ->
             lists:foreach(
               fun(P) -> true = unlink(P),
                         erlang:monitor(process, P),
                         erlang:exit(P, kill),
                         receive {'DOWN', _, _, P, _} -> ok end
               end,
               Pids),
             [inet_tcp:close(S) || S <- Socks],
             %dbg:stop_clear(),
             meck:unload()
     end,
     {with, [fun list_nodes/1]}
    }.

list_nodes({_, _, [DistPort, NodePort]}) ->
    [_] = lists:usort([N || _ <- lists:seq(1,5000),
                            N <- [epmdless_dist:node_please('test-node')],
                            N =/= undefined]),
    ?assertMatch(
       [{'test-node@localhost',{127,0,0,1},NodePort,inet_tcp},
        {_testnode,_testip,DistPort,inet_tcp}],
       lists:sort(epmdless_dist:?FUNCTION_NAME())).


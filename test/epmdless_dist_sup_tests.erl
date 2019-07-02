-module(epmdless_dist_sup_tests).

-include_lib("eunit/include/eunit.hrl").

children_test_() ->
    {setup,
     fun() ->
             %dbg:tracer(), dbg:p(all,c),
             meck:new(epmdless_client, [passthrough]),
             meck:expect(epmdless_client, protos,
                         fun() -> ["inet_tcp", "epmdless_tls"] end),
             %dbg:tpl(epmdless_client, [{'_',[],[{return_trace}]}]),
             {ok, Pid} = epmdless_dist:start_link(),
             {ok, InetSock} = inet_tcp:listen(0, []),
             {ok, ElessSock} = eless_tcp:listen(0, []),
             {ok, InetPort} = inet:port(InetSock),
             {ok, ElessPort} = inet:port(ElessSock),
             {ok, _} = epmdless_dist:register_node(test_node, InetPort, inet_tcp),
             {ok, _} = epmdless_dist:register_node(test_node, ElessPort, eless_tcp),
             {Pid, {InetSock, ElessSock}}
     end,
     fun({Pid, {InetSock, ElessSock}}) ->
             inet_tcp:close(InetSock),
             inet_tcp:close(ElessSock),
             true = unlink(Pid),
             ok = gen_server:stop(Pid),
             exit(Pid, kill),
             %dbg:stop_clear(),
             meck:unload()
     end,
     {with, [fun(_) -> ?assertEqual([eless_tcp, inet_tcp], epmdless_dist_sup:children()) end,
             fun(_) -> ?assertEqual([eless_tcp, inet_tcp], epmdless_tls_dist:epmd_children(children)) end,
             fun(_) -> ?assertEqual([eless_tcp], epmdless_tls_dist:epmd_children(called_children)) end]}
    }.

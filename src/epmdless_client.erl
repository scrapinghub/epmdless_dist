-module(epmdless_client).
-behaviour(gen_server).


-include_lib("stdlib/include/ms_transform.hrl").
-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-endif.


%% @doc
%% Module which used as a callback which passed to erlang vm via `-epmd_module` attribute
%% @end

-export([child_spec/0]).
%% erl_epmd callbacks
-export([start/3, start_link/3, stop/1,
         register_node/3, register_node/4,
         port_please/2, port_please/3, port_please/4,
         names/1, names/2]).
%% auxiliary extensions
-export([get_info/1, host_please/2,
         node_please/2, local_part/2,
         family/1]).
%% node maintenance functions
-export([add_node/3, add_node/4,
         remove_node/2, list_nodes/1]).
%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).
%% Utility function
-export([gethostname/1]).

-define(APP, epmdless_dist).
-define(MOD(F), case F of inet -> inet_tcp; inet6 -> inet6_tcp end).
-define(FAM(M), case M of inet_tcp -> inet; inet6_tcp -> inet6 end).
-define(REGISTRY(F), case F of inet  -> epmdless_inet;
                               inet6 -> epmdless_inet6
                     end).
-define(REG_ATOM(F), case F of inet  -> epmdless_inet_atoms;
                               inet6 -> epmdless_inet6_atoms
                     end).
-define(REG_ADDR(F), case F of inet  -> epmdless_inet_addrs;
                               inet6 -> epmdless_inet6_addrs
                     end).
-define(REG_HOST(F), case F of inet  -> epmdless_inet_hosts;
                               inet6 -> epmdless_inet6_hosts
                     end).
-define(REG_PART(F), case F of inet  -> epmdless_inet_parts;
                               inet6 -> epmdless_inet6_parts
                     end).

-define(ETS_OPTS(Type, KeyIdx), [Type, protected, named_table,
                                 {keypos, KeyIdx},
                                 {read_concurrency, true}]).
-define(NODE_MATCH(NodeKey), #node{key=NodeKey,
                                   name_atom='$3',
                                   addr='$5',
                                   host='$4',
                                   port='$1',
                                   added_ts='_'}).

-record(node_key, {
          %% using e-mail terminology: https://www.w3.org/Protocols/rfc822/#z8
          %% addr-spec   =  local-part "@" domain        ; global address
          local_part :: atom(),
          domain :: atom()
         }).

-record(node, {
          key :: #node_key{},
          name_atom :: atom(), %% formatted full node name as an atom
          addr :: inet:ip_address(),
          host :: inet:hostname(),
          port :: inet:port_number(),
          added_ts :: integer()
         }).

-record(map, {
          key,
          value
         }).

-record(state, {
    creation :: 1|2|3,
    name   :: atom(),
    port   :: inet:port_number(),
    family :: atom(),
    version = 5
}).

child_spec() ->
    #{id => ?MODULE,
      start => {?MODULE, start_link, []},
      restart => permanent,
      shutdown => 5000,
      type => worker,
      modules => [?MODULE]}.

% erl_epmd API

start(Name, DistPort, Family) ->
    gen_server:start(?MODULE, [Name, DistPort, Family], []).

start_link(Name, DistPort, Family) ->
    gen_server:start_link(?MODULE, [Name, DistPort, Family], []).

stop(Pid) ->
    gen_server:call(Pid, stop, infinity).


register_node(Pid, Name, PortNo) ->
    register_node(Pid, Name, PortNo, inet).

-spec register_node(Pid, Name, Port, Family) -> {ok, CreationId} when
      Pid        :: pid(),
      Name       :: atom(),
      Port       :: inet:port_number(),
      Family     :: atom(),
      CreationId :: 1..3.
register_node(Pid, Name, PortNo, inet_tcp) ->
    register_node(Pid, Name, PortNo, inet);
register_node(Pid, Name, PortNo, inet6_tcp) ->
    register_node(Pid, Name, PortNo, inet6);
register_node(Pid, Name, Port, Family) ->
    gen_server:call(Pid, {?FUNCTION_NAME, Name, Port, Family}, infinity).

port_please(Pid, Node) ->
    port_please(Pid, Node, undefined).

port_please(Pid, Node, Host) ->
    port_please(Pid, Node, Host, infinity).

-spec port_please(Pid, Name, Host, Timeout) -> {port, Port, Version} | noport when
      Pid     :: pid(),
      Name    :: list() | atom(),
      Host    :: list() | atom() | inet:hostname() | inet:ip_address(),
      Timeout :: integer() | infinity,
      Port    :: inet:port_number(),
      Version :: 5.
%% @doc
%% request port of node `Name`
%% @end
port_please(Pid, Name, Host, Timeout) ->
    gen_server:call(Pid, {?FUNCTION_NAME, Name, Host}, Timeout).


names(F) ->
    names(undefined, F).

%% @doc
%% List the Erlang nodes on a certain host.
%% @end
names(undefined, F) ->
    names(gethostname(F), F);
names(Domain, F) when is_atom(Domain) ->
    NodeKey = #node_key{local_part='_', domain=Domain},
    MatchSpec = [{?NODE_MATCH(NodeKey), [], ['$3']}],
    ets:select(?REGISTRY(F), MatchSpec);
names(Addr, F) when is_tuple(Addr) ->
    try ets:lookup_element(?REG_ADDR(F), Addr, #map.value) of
        Domain -> names(Domain, F)
    catch
        error:badarg -> []
    end;
names(Host, F) ->
    try ets:lookup_element(?REG_HOST(F), Host, #map.value) of
        Domain -> names(Domain, F)
    catch
        error:badarg -> []
    end.

%% auxiliary extensions

-spec get_info(Pid) -> Info when
      Pid  :: pid(),
      Info :: [{dist_port, inet:port_number()}].
get_info(Pid) ->
    gen_server:call(Pid, ?FUNCTION_NAME, infinity).

-spec host_please(Pid, Node) -> {host, Host} | nohost when
      Pid  :: pid(),
      Node :: atom(),
      Host :: inet:hostname() | inet:ip_address().
host_please(Pid, Node) ->
    gen_server:call(Pid, {?FUNCTION_NAME, Node}, infinity).

-spec node_please(LocalPart, F) -> Node | undefined when
      LocalPart :: atom(),
      F :: inet|inet6,
      Node :: atom().
node_please(LocalPart, F) ->
    case ets:member(?REG_ATOM(F), LocalPart) of
        % This means we got a NodeName instead of LocalPart,
        % so we'll just send it back.
        true -> LocalPart;
        false ->
            try ets:lookup_element(?REG_PART(F), LocalPart, #map.value) of
                [Domain] ->
                    ets:lookup_element(?REGISTRY(F),
                                       #node_key{local_part=LocalPart, domain=Domain},
                                       #node.name_atom);
                Domains when is_list(Domains) ->
                    {_Ts, Node} = lookup_last_added_node(LocalPart, Domains, F),
                    Node#node.name_atom
            catch
                error:badarg -> undefined
            end
    end.

-spec local_part(NodeName, F) -> LocalPart | undefined when
      NodeName :: atom(),
      F :: inet|inet6,
      LocalPart :: atom().
local_part(NodeName, F) ->
    case ets:lookup(?REG_ATOM(F), NodeName) of
        [#map{value=NK}] -> NK#node_key.local_part;
        [] -> undefined
    end.

%% node maintenance functions

-spec add_node(Pid, Node, Port) -> ok when
      Pid  :: pid(),
      Node :: atom(),
      Port :: inet:port_number().
add_node(Pid, Node, Port) ->
    ok = gen_server:cast(Pid, {?FUNCTION_NAME, Node, Port}).

-spec add_node(Pid, Node, Host, Port) -> ok when
      Pid  :: pid(),
      Node :: atom(),
      Host :: inet:hostname() | inet:ip_address(),
      Port :: inet:port_number().
add_node(Pid, Node, Host, Port) ->
    ok = gen_server:cast(Pid, {?FUNCTION_NAME, Node, Host, Port}).

-spec remove_node(Pid, Node) -> ok when
      Pid  :: pid(),
      Node :: atom().
remove_node(Pid, Node) ->
    ok = gen_server:cast(Pid, {?FUNCTION_NAME, Node}).

-spec list_nodes(Pid) -> [{Node, {Host, Port}}] when
      Pid  :: pid(),
      Node :: atom(),
      Host :: inet:hostname() | inet:ip_address(),
      Port :: inet:port_number().
list_nodes(Pid) ->
    gen_server:call(Pid, ?FUNCTION_NAME, infinity).

-spec family(Pid) -> Family when
      Pid    :: pid(),
      Family :: inet|inet6.
family(Pid) ->
    gen_server:call(Pid, ?FUNCTION_NAME, infinity).

%% gen_server callbacks

init([Name, DistPort, Family = F]) ->
    ets:new(?REGISTRY(F), ?ETS_OPTS(set, #node.key)),
    ets:new(?REG_ATOM(F), ?ETS_OPTS(set, #map.key)),
    ets:new(?REG_ADDR(F), ?ETS_OPTS(set, #map.key)),
    ets:new(?REG_HOST(F), ?ETS_OPTS(set, #map.key)),
    ets:new(?REG_PART(F), ?ETS_OPTS(bag, #map.key)),
    error_logger:info_msg("Starting erlang distribution at port ~p~n", [DistPort]),
    self() ! timeout,
    {ok, #state{creation = rand:uniform(3), name=Name, port=DistPort, family=Family}}.

handle_call({register_node, Name, DistPort, Family}, _From, State = #state{creation = Creation}) ->
    {_, NewState} = handle_cast({register_node, Name, DistPort, Family}, State),
    {reply, {ok, Creation}, NewState};

handle_call(get_info, _From, State = #state{port = DistPort}) ->
    {reply, [{dist_port, DistPort}], State};

handle_call({host_please, Node}, _From, State = #state{family = F}) when is_atom(Node) ->
    Reply =
    try
        NodeKey = ets:lookup_element(?REG_ATOM(F), Node, #map.value),
        ets:lookup(?REGISTRY(F), NodeKey)
    of
        [#node{addr=Addr}] when is_tuple(Addr) -> {host, Addr};
        [#node{host=Host}] when is_list(Host) -> {host, Host};
        _ -> nohost
    catch
        error:badarg ->
            error_logger:error_msg("No host found for node ~p~n", [Node]),
            nohost
    end,
    {reply, Reply, State};

handle_call({port_please, LocalPart, Host}, From, State)
  when is_list(LocalPart) ->
    handle_call({port_please, list_to_atom(LocalPart), Host}, From, State);
handle_call({port_please, LocalPart, Host}, _From, State = #state{version = Version})
  when is_atom(LocalPart) ->
    Reply =
    try lookup_port(self(), LocalPart, Host, State) of
        Port -> {port, Port, Version}
    catch
        error:badarg ->
            error_logger:error_msg("No port for ~p@~p~n", [LocalPart, Host]),
            noport
    end,
    {reply, Reply, State};

handle_call(list_nodes, _From, State = #state{family = F}) ->
    ResultHost = {{'$3', {{'$4', '$1'}}}},
    ResultAddr = {{'$3', {{'$5', '$1'}}}},
    NodeKey = #node_key{local_part='_', domain='_'},
    MatchSpec = [{?NODE_MATCH(NodeKey), [{'==', undefined, '$5'}], [ResultHost]},
                 {?NODE_MATCH(NodeKey), [{'/=', undefined, '$5'}], [ResultAddr]}],
    Reply = ets:select(?REGISTRY(F), MatchSpec),
    {reply, Reply, State};

handle_call({add_node, NodeName, Port}, _From, State) when is_atom(NodeName) ->
    {_, NewState} = handle_cast({add_node, NodeName, Port}, State),
    {reply, ok, NewState};

handle_call({add_node, NodeName, Host, Port}, _From, State) when is_atom(NodeName) ->
    {_, NewState} = handle_cast({add_node, NodeName, Host, Port}, State),
    {reply, ok, NewState};

handle_call({remove_node, NodeName}, _From, State) when is_atom(NodeName) ->
    {_, NewState} = handle_cast({remove_node, NodeName}, State),
    {reply, ok, NewState};

handle_call(stop, _From, State) ->
    {stop, shutdown, ok, State};

handle_call(family, _From, State) ->
    {reply, State#state.family, State};

handle_call(Msg, _From, State) ->
    error_logger:error_msg("Unexpected message: ~p~n", [Msg]),
    {reply, {error, {bad_msg, Msg}}, State}.

handle_cast({register_node, Name, DistPort, Family}, State = #state{family = Family}) ->
    handle_info(tuple_to_node({Name, gethostname(Family), DistPort}), State);

handle_cast({add_node, NodeName, Port}, State) when is_atom(NodeName) ->
    Node = atom_to_node(NodeName),
    handle_info(Node#node{port = Port}, State);

handle_cast({add_node, NodeName, Addr, Port}, State = #state{family = inet})
  when is_atom(NodeName) andalso is_tuple(Addr) andalso size(Addr) == 4 ->
    Node = atom_to_node(NodeName),
    % We have the IP address here, we still spawn a process to check the port.
    handle_info(Node#node{addr = Addr, port = Port}, State);
handle_cast({add_node, NodeName, Addr, Port}, State = #state{family = inet6})
  when is_atom(NodeName) andalso is_tuple(Addr) andalso size(Addr) == 8 ->
    Node = atom_to_node(NodeName),
    % We have the IP address here, we still spawn a process to check the port.
    handle_info(Node#node{addr = Addr, port = Port}, State);

handle_cast({add_node, NodeName, Host, Port}, State)
  when is_atom(NodeName) ->
    Node = atom_to_node(NodeName, Host),
    handle_info(Node#node{port = Port}, State);

handle_cast({remove_node, NodeName}, State) when is_list(NodeName) ->
    handle_cast({remove_node, list_to_atom(NodeName)}, State);
handle_cast({remove_node, NodeName}, State = #state{family = F}) when is_atom(NodeName) ->
    do_remove_node(NodeName, F),
    {noreply, State};

handle_cast({insert, N = #node{key=#node_key{}}}, State = #state{family = F}) ->
    insert_ignore(N, F),
    {noreply, State};
handle_cast({insert, {Error, {EAddr, EPort}}}, State) ->
    error_logger:error_msg("Port verification failed for ~p:~p due to ~p",
                          [EAddr, EPort, Error]),
    {noreply, State};
handle_cast({insert, {Error, EHost}}, State) ->
    error_logger:error_msg("IP resolution failed for ~p due to ~p",
                          [EHost, Error]),
    {noreply, State};

handle_cast(Msg, State) ->
    error_logger:error_msg("Unexpected message: ~p~n", [Msg]),
    {noreply, State}.


handle_info(timeout, State) ->
     [ handle_info(Node, State)
       || Node = #node{key = #node_key{}} <- node_list() ],
     {noreply, State};

handle_info(Node = #node{key=#node_key{}}, State = #state{family = F}) ->
    verify_insert(self(), Node, F),
    {noreply, State};

handle_info(Msg, State) ->
    error_logger:error_msg("Unexpected message: ~p~n", [Msg]),
    {noreply, State}.

terminate(_Reason, _State = #state{family=F}) ->
    ets:delete(?REGISTRY(F)),
    ets:delete(?REG_ATOM(F)),
    ets:delete(?REG_ADDR(F)),
    ets:delete(?REG_HOST(F)),
    ets:delete(?REG_PART(F)),
    ok.

code_change(_Old, State, _Extra) ->
    {ok, State}.


%% internal functions


lookup_port(_Pid, LocalPart, Domain, #state{family = F}) when is_atom(Domain) ->
    NodeKey =
    case ets:lookup(?REG_ATOM(F), LocalPart) of
        [#map{value=Value}] -> Value;
        [] -> #node_key{local_part=LocalPart, domain=Domain}
    end,
    ets:lookup_element(?REGISTRY(F), NodeKey, #node.port);
lookup_port(Pid, LocalPart, Addr, S = #state{family = F}) when is_tuple(Addr) ->
    try ets:lookup_element(?REG_ADDR(F), Addr, #map.value) of
        Domain -> lookup_port(Pid, LocalPart, Domain, S)
    catch
        error:badarg ->
            M = ?MOD(F),
            NewDiscoveries =
            [ begin
                  handle_cast({insert, Verification}, S),
                  Verification
              end || Node = #node{key = #node_key{local_part = LP}} <- node_list(),
                     not ets:member(?REG_PART(F), LP),
                     Verification <- [verify_port(set_address(Node, M), M)],
                     LP == LocalPart],
            case [N || N = #node{addr = A} <- NewDiscoveries, A == Addr] of
                [#node{port=Port}] -> Port;
                [] -> error(badarg);
                %% It's an error to have multiple node definitions
                %% with the name local_part and host / IP.
                [_|_] -> error(badarg)
            end
    end;
lookup_port(Pid, LocalPart, Host, S = #state{family = F}) ->
    Domain =
    case ets:lookup(?REG_HOST(F), Host) of
        [#map{value=Value}] -> Value;
        [] -> list_to_atom(Host)
    end,
    lookup_port(Pid, LocalPart, Domain, S).


lookup_last_added_node(LocalPart, Domains, F) ->
    lists:foldl(
      fun(Domain, {Max, _NodeAtom} = Acc) ->
              case ets:lookup(?REGISTRY(F), #node_key{local_part=LocalPart, domain=Domain}) of
                  [#node{added_ts=Ts} = N] when Max < Ts -> {Ts, N};
                  [#node{}] -> Acc
              end
      end,
      {0, undefined},
      Domains).

insert_ignore(Node = #node{ key = NK, addr = Addr, host = Host, port = Port}, F) ->
    case ets:lookup(?REGISTRY(F), NK) of
        % ignore if Address, Host and Port match
        [#node{addr = Addr, host = Host, port = Port}] -> false;
        % update Port if Address and Host match
        [#node{addr = Addr1, host = Host}] when Addr == undefined orelse
                                                Addr == Addr1 ->
            true = ets:insert(?REGISTRY(F), Node);
        % update Address and Host if only Port matches
        [#node{addr = A, host = H, port = Port}] ->
            true = case names(NK#node_key.domain, F) of
                       % Only delete the host mapping
                       % if there're no other nodes with the same domain.
                       [] ->
                           ets:delete(?REG_ADDR(F), A),
                           ets:delete(?REG_HOST(F), H);
                       _ -> true
                   end,
            case is_tuple(Addr) of
                true -> true = ets:insert(?REG_ADDR(F), #map{key=Addr, value=NK#node_key.domain});
                _ -> true
            end,
            true = ets:insert(?REG_HOST(F), #map{key=Host, value=NK#node_key.domain}),
            true = ets:insert(?REGISTRY(F), Node);
        % insert if Node doesn't exists yet
        [] ->
            true = ets:insert(?REG_ATOM(F), #map{key=Node#node.name_atom, value=NK}),
            case is_tuple(Addr) of
                true -> true = ets:insert(?REG_ADDR(F), #map{key=Addr, value=NK#node_key.domain});
                _ -> true
            end,
            true = ets:insert(?REG_HOST(F), #map{key=Host, value=NK#node_key.domain}),
            true = ets:insert(?REG_PART(F), #map{key=NK#node_key.local_part, value=NK#node_key.domain}),
            true = ets:insert(?REGISTRY(F), Node)
    end,
    Node.


do_remove_node(NodeName, F) when is_atom(NodeName) ->
    try
        [#map{value = NodeKey}] = ets:take(?REG_ATOM(F), NodeName),
        [#node{addr = Addr, host = Host}] = ets:take(?REGISTRY(F), NodeKey),
        {NodeKey, Addr, Host}
    of
        {NK = #node_key{domain = Domain}, A, H} ->
            true = case names(Domain, F) of
                       % Only delete the address and host mapping
                       % if there're no other nodes with the same domain.
                       [] ->
                           ets:delete(?REG_ADDR(F), A),
                           ets:delete(?REG_HOST(F), H);
                       _ -> true
                   end,
            true = ets:delete(?REG_PART(F), NK#node_key.local_part)
    catch
        error:_ -> ok
    end.


node_list() ->
    [ tuple_to_node(T)
      || {L, D, P} = T <- case application:get_env(?APP, ?FUNCTION_NAME) of
                              undefined -> get_os_env(?APP, ?FUNCTION_NAME);
                              {ok, Tuples} -> Tuples
                          end,
         is_atom(L) andalso is_atom(D) andalso is_integer(P) ].

atom_to_node(Atom, Host) when is_atom(Atom) ->
    case string_to_tuple(atom_to_list(Atom)) of
        {LocalPart, undefined, Port} -> tuple_to_node({LocalPart, Host, Port});
        Tuple -> tuple_to_node(Tuple)
    end.

atom_to_node(Atom) when is_atom(Atom) ->
    tuple_to_node(string_to_tuple(atom_to_list(Atom))).

string_to_tuple(String) when is_list(String) ->
    Tokens = string:tokens(String, "@:"),
    erlang:make_tuple(3, undefined,
                      lists:zip(lists:seq(1, length(Tokens)), Tokens)).

tuple_to_node({LocalPart, Domain, Port}) ->
    node_from_node_key(#node_key{local_part=LocalPart, domain=Domain},
                       #node{port=Port}).

%% First we set the name of the node as an atom,
%% join_list takes both atoms and strings as input.
node_from_node_key(NK = #node_key{local_part = LP, domain = D},
                   N = #node{name_atom = undefined}) ->
    NameAtom = list_to_atom(join_list($@, [LP, D])),
    node_from_node_key(NK, N#node{name_atom=NameAtom});
%% Second we check if the domain is a string,
%% if so we set the host to be the domain
%% while the domain itself is converted to and atom.
node_from_node_key(NK = #node_key{domain = D},
                   N) when is_list(D) ->
    node_from_node_key(NK#node_key{domain = list_to_atom(D)},
                       N#node{host=D});
%% Third we ensure the host is set even if domain was originally an atom.
node_from_node_key(NK = #node_key{domain = D},
                   N = #node{host = undefined}) when is_atom(D) ->
    node_from_node_key(NK,
                       N#node{host=atom_to_list(D)});
%% Fourth we convert the local_part to an atom if its a list.
node_from_node_key(NK = #node_key{local_part = LP},
                   N) when is_list(LP) ->
    node_from_node_key(NK#node_key{local_part = list_to_atom(LP)},
                       N);
%% Lastly we fill out the not yet defined fields of the node record.
node_from_node_key(NK = #node_key{local_part = LP, domain = D},
                   N) when is_atom(LP) andalso is_atom(D) ->
    N#node{added_ts = erlang:system_time(microsecond),
           key = NK}.

verify_insert(Pid, Node, Family) ->
    M = ?MOD(Family),
    spawn(
      fun() ->
        gen_server:cast(Pid, {insert, verify_port(set_address(Node, M), M)})
      end).

-spec set_address(Node, Module) -> NewNode | {{error, Reason}, EHost} when
      Node    :: #node{},
      Module :: inet_tcp|inet6_tcp,
      NewNode :: #node{addr::inet:ip_address()},
      Reason  :: term(),
      EHost :: any().
set_address(Node = #node{addr=Addr}, _) when is_tuple(Addr) -> Node;
set_address(Node = #node{host=Host}, M) ->
    case M:getaddr(Host) of
        {ok, Addr} -> Node#node{addr=Addr};
        Error -> {Error, Host}
    end.

-spec verify_port(Node|{{error, Reason}, EHost}, Module) -> NewNode | {{error, Reason}, EAddrPort} when
      Node    :: #node{},
      Module :: inet_tcp|inet6_tcp,
      NewNode :: #node{addr::inet:ip_address()},
      Reason  :: term(),
      EHost :: any(),
      EAddrPort :: {any(), any()}.
verify_port(Node = #node{addr=Addr, port=Port}, M)
  when is_tuple(Addr) andalso is_integer(Port) ->
    case catch M:connect(Addr, Port, [{active, false}, {reuseaddr, true}], 5000) of
        {ok, S} -> M:close(S), Node;
        {'EXIT', Reason} -> {error, Reason};
        Error -> {Error, {Addr, Port}}
    end;
verify_port(#node{addr=Addr, port=Port}, _) when is_tuple(Addr) ->
    {{error, invalid_port}, {Addr, Port}};
verify_port(#node{addr=Addr, port=Port}, _) when is_integer(Port) ->
    {{error, invalid_address}, {Addr, Port}};
verify_port(Error, _) -> Error.

get_os_env(App, EnvKey) ->
    get_os_env(join_list($_, [App, EnvKey])).

get_os_env(EnvKeyAtom) when is_atom(EnvKeyAtom) ->
    get_os_env(atom_to_list(EnvKeyAtom));
get_os_env(EnvKeyString) when is_list(EnvKeyString) ->
    String = os:getenv(string:to_upper(EnvKeyString), "[]."),
    {ok, Tokens, _} = erl_scan:string(String),
    {ok, Term} = erl_parse:parse_term(Tokens),
    Term.

join_list(_Chr, [String]) when is_list(String) -> String;
join_list(_Chr, [Atom]) when is_atom(Atom) -> atom_to_list(Atom);
join_list(Char, [Head|Tail]) ->
    join_list(Char, [Head]) ++ [Char|join_list(Char, Tail)].


gethostname(inet) -> gethostname(inet_udp);
gethostname(inet6) -> gethostname(inet6_udp);
gethostname(UDP) ->
    % Crawlera specific environment vars
    case os:getenv("HOST", os:getenv("HOSTNAME")) of
        false ->
            case UDP:open(0,[]) of
                {ok,U} ->
                    {ok,Res} = inet:gethostname(U),
                    UDP:close(U),
                    Res;
                _ ->
                    "nohost.nodomain"
            end;
        Host -> Host
    end.

-ifdef(TEST).
verify_port_test_() ->
    [fun verify_inet_port/0,
     fun verify_inet6_port/0].

verify_inet_port() ->
    {ok, Sock} = inet_tcp:listen(0, []),
    {ok, Port} = inet:port(Sock),
    Node = #node{host="localhost", port=Port},
    #node{addr={127,0,0,1}} = verify_port(set_address(Node, inet_tcp), inet_tcp),
    {{error, econnrefused}, {{0,0,0,0,0,0,0,1}, Port}} = verify_port(set_address(Node, inet6_tcp), inet6_tcp),
    inet_tcp:close(Sock).

verify_inet6_port() ->
    {ok, Sock} = inet6_tcp:listen(0, [{ipv6_v6only, true}]),
    {ok, Port} = inet:port(Sock),
    Node = #node{host="localhost", port=Port},
    {{error, econnrefused}, {{127,0,0,1}, Port}} = verify_port(set_address(Node, inet_tcp), inet_tcp),
    #node{addr={0,0,0,0,0,0,0,1}} = verify_port(set_address(Node, inet6_tcp), inet6_tcp),
    inet6_tcp:close(Sock).
-endif.


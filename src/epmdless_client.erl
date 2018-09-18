-module(epmdless_client).

-behaviour(gen_server).

%% @doc
%% Module which used as a callback which passed to erlang vm via `-epmd_module` attribute
%% @end

%% erl_epmd callbacks
-export([start/0, start_link/0, stop/0,
         register_node/2, register_node/3,
         port_please/2, port_please/3,
         names/0, names/1]).
-export([names_dirty/0, names_dirty/1]).
%% auxiliary extensions
-export([get_info/0, node_please/1, host_please/1]).
%% dirty auxiliary extensions
-export([node_please_dirty/1]).
%% node maintenance functions
-export([add_node/2, add_node/3, remove_node/1, list_nodes/0]).
%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(APP, epmdless_dist).
-define(REGISTRY, epmdless_dist_node_registry).
-define(REG_ATOM, epmdless_dist_node_registry_atoms).
-define(REG_ADDR, epmdless_dist_node_registry_addrs).
-define(REG_HOST, epmdless_dist_node_registry_hosts).
-define(REG_PART, epmdless_dist_node_registry_parts).
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


% erl_epmd API

start() ->
    gen_server:start({local, ?MODULE}, ?MODULE, [], []).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

stop() ->
    gen_server:call(?MODULE, stop, infinity).


register_node(Name, PortNo) ->
    register_node(Name, PortNo, inet).

-spec register_node(Name, Port, Family) -> {ok, CreationId} when
      Name       :: atom(),
      Port       :: inet:port_number(),
      Family     :: atom(),
      CreationId :: 1..3.
register_node(Name, PortNo, inet_tcp) ->
    register_node(Name, PortNo, inet);
register_node(Name, PortNo, inet6_tcp) ->
    register_node(Name, PortNo, inet6);
register_node(Name, Port, Family) ->
    gen_server:call(?MODULE, {?FUNCTION_NAME, Name, Port, Family}, infinity).


port_please(Node, Host) ->
  port_please(Node, Host, infinity).

-spec port_please(Name, Host, Timeout) -> {port, Port, Version} | noport when
      Name    :: list() | atom(),
      Host    :: list() | atom() | inet:hostname() | inet:ip_address(),
      Timeout :: integer() | infinity,
      Port    :: inet:port_number(),
      Version :: 5.
%% @doc
%% request port of node `Name`
%% @end
port_please(Name, Host, Timeout) ->
    gen_server:call(?MODULE, {?FUNCTION_NAME, Name, Host}, Timeout).


names() ->
    {ok, Host} = inet:gethostname(),
    names(Host).
%% @doc
%% List the Erlang nodes on a certain host.
%% @end
names(Hostname) ->
    gen_server:call(?MODULE, {?FUNCTION_NAME, Hostname}, infinity).


%% Dirty Extensions

names_dirty() ->
    {ok, Host} = inet:gethostname(),
    names_dirty(Host).

names_dirty(Host) ->
    names_dirty(Host, whereis(?MODULE)).

names_dirty(_Host, undefined) -> undefined;
names_dirty(Domain, EpmdClientPid) when is_pid(EpmdClientPid)
                                        andalso is_atom(Domain) ->
    NodeKey = #node_key{local_part='_', domain=Domain},
    MatchSpec = [{?NODE_MATCH(NodeKey), [], ['$3']}],
    ets:select(?REGISTRY, MatchSpec);
names_dirty(IP, EpmdClientPid) when is_pid(EpmdClientPid) andalso
                                    is_tuple(IP) ->
    try ets:lookup_element(?REG_ADDR, IP, #map.value) of
        Domain -> names_dirty(Domain, EpmdClientPid)
    catch
        error:badarg -> []
    end;
names_dirty(Host, EpmdClientPid) when is_pid(EpmdClientPid) ->
    try ets:lookup_element(?REG_HOST, Host, #map.value) of
        Domain -> names_dirty(Domain, EpmdClientPid)
    catch
        error:badarg -> []
    end.

%% auxiliary extensions

-spec get_info() -> Info when
      Info :: [{dist_port, inet:port_number()}].
get_info() ->
    gen_server:call(?MODULE, get_info, infinity).

-spec host_please(Node) -> {host, Host} | nohost when
      Node :: atom(),
      Host :: inet:hostname() | inet:ip_address().
host_please(Node) ->
    gen_server:call(?MODULE, {?FUNCTION_NAME, Node}, infinity).

-spec node_please(LocalPart) -> {node, Node} | nonode when
      LocalPart :: atom(),
      Node :: atom().
node_please(LocalPart) ->
    gen_server:call(?MODULE, {?FUNCTION_NAME, LocalPart}, infinity).


%% dirty auxiliary extensions

node_please_dirty(LocalPart) ->
    node_please_dirty(LocalPart, whereis(?MODULE)).

node_please_dirty(_LocalPart, undefined) -> undefined;
node_please_dirty(LocalPart, EpmdClientPid) when is_pid(EpmdClientPid) ->
    case ets:member(?REG_ATOM, LocalPart) of
        % This means we got a NodeName instead of LocalPart,
        % so we'll just send it back.
        true -> LocalPart;
        false ->
            try ets:lookup_element(?REG_PART, LocalPart, #map.value) of
                [Domain] ->
                    ets:lookup_element(?REGISTRY,
                                       #node_key{local_part=LocalPart, domain=Domain},
                                       #node.name_atom);
                Domains when is_list(Domains) ->
                    {_Ts, NodeAtom} = lookup_last_added_node(LocalPart, Domains),
                    NodeAtom
            catch
                error:badarg -> undefined 
            end
    end.


%% node maintenance functions

-spec add_node(Node, Port) -> ok when
      Node :: atom(),
      Port :: inet:port_number().
add_node(Node, Port) ->
    ok = gen_server:call(?MODULE, {?FUNCTION_NAME, Node, Port}, infinity).

-spec add_node(Node, Host, Port) -> ok when
      Node :: atom(),
      Host :: inet:hostname() | inet:ip_address(),
      Port :: inet:port_number().
add_node(Node, Host, Port) ->
    ok = gen_server:call(?MODULE, {?FUNCTION_NAME, Node, Host, Port}, infinity).

-spec remove_node(Node) -> ok when
      Node :: atom().
remove_node(Node) ->
    ok = gen_server:call(?MODULE, {?FUNCTION_NAME, Node}, infinity).

-spec list_nodes() -> [{Node, {Host, Port}}] when
      Node :: atom(),
      Host :: inet:hostname() | inet:ip_address(),
      Port :: inet:port_number().
list_nodes() ->
    gen_server:call(?MODULE, ?FUNCTION_NAME, infinity).


%% gen_server callbacks

init([]) ->
    ?REGISTRY = ets:new(?REGISTRY, ?ETS_OPTS(set, #node.key)),
    ?REG_ATOM = ets:new(?REG_ATOM, ?ETS_OPTS(set, #map.key)),
    ?REG_ADDR = ets:new(?REG_ADDR, ?ETS_OPTS(set, #map.key)),
    ?REG_HOST = ets:new(?REG_HOST, ?ETS_OPTS(set, #map.key)),
    ?REG_PART = ets:new(?REG_PART, ?ETS_OPTS(bag, #map.key)),
    {ok, #state{creation = rand:uniform(3)}}.

handle_call({register_node, Name, DistPort, Family}, _From, State = #state{creation = Creation}) ->
    %% In order to keep the init function lightweight,
    %% let's insert preconfigured node here.
    AddrGetter = addr_getter(Family),
    [insert_ignore(N) || N <- [atom_to_node(node(), AddrGetter)|node_list(AddrGetter)]],
    error_logger:info_msg("Starting erlang distribution at port ~p~n", [DistPort]),
    {reply, {ok, Creation}, State#state{name=Name, port=DistPort, family=Family}};

handle_call(get_info, _From, State = #state{port = DistPort}) ->
    {reply, [{dist_port, DistPort}], State};

handle_call({node_please, LocalPart}, _From, State) when is_atom(LocalPart) ->
    Reply = node_please_dirty(LocalPart, self()),
    {reply, Reply, State};

handle_call({host_please, Node}, _From, State) when is_atom(Node) ->
    Reply =
    try
        NodeKey = ets:lookup_element(?REG_ATOM, Node, #map.value),
        ets:lookup_element(?REGISTRY, NodeKey, #node.host)
    of
        Host -> {host, Host}
    catch
        error:badarg ->
            error_logger:info_msg("No host found for node ~p~n", [Node]),
            nohost
    end,
    {reply, Reply, State};

handle_call({port_please, LocalPart, Host}, From, State)
  when is_list(LocalPart) ->
    handle_call({port_please, list_to_atom(LocalPart), Host}, From, State);
handle_call({port_please, LocalPart, Host}, _From, State = #state{version = Version})
  when is_atom(LocalPart) ->
    Reply =
    try lookup_port(LocalPart, Host) of
        Port -> {port, Port, Version}
    catch
        error:badarg ->
            error_logger:info_msg("No port for ~p@~p~n", [LocalPart, Host]),
            noport
    end,
    {reply, Reply, State};

handle_call(list_nodes, _From, State) ->
    ResultHost = {{'$3', {{'$4', '$1'}}}},
    ResultAddr = {{'$3', {{'$5', '$1'}}}},
    NodeKey = #node_key{local_part='_', domain='_'},
    MatchSpec = [{?NODE_MATCH(NodeKey), [{'==', undefined, '$5'}], [ResultHost]},
                 {?NODE_MATCH(NodeKey), [{'/=', undefined, '$5'}], [ResultAddr]}],
    Reply = ets:select(?REGISTRY, MatchSpec),
    {reply, Reply, State};

handle_call({names, Host}, _From, State) ->
    Reply = names_dirty(Host, self()),
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

handle_call(Msg, _From, State) ->
    error_logger:error_msg("Unexpected message: ~p~n", [Msg]),
    {reply, {error, {bad_msg, Msg}}, State}.


handle_cast({add_node, NodeName, Port}, State) when is_atom(NodeName) ->
    Node = atom_to_node(NodeName, addr_getter(State#state.family)),
    insert_ignore(Node#node{port = Port}),
    {noreply, State};

handle_cast({add_node, NodeName, Addr, Port}, State) when is_atom(NodeName) andalso
                                                          is_tuple(Addr) ->
    Node = atom_to_node(NodeName, fun(_) -> Addr end),
    insert_ignore(Node#node{port = Port}),
    {noreply, State};
handle_cast({add_node, NodeName, Host, Port}, State) when is_atom(NodeName) ->
    AddrGetter = addr_getter(State#state.family),
    Node = atom_to_node(NodeName, AddrGetter),
    insert_ignore(Node#node{addr = AddrGetter(Host), host = Host, port = Port}),
    {noreply, State};

handle_cast({remove_node, NodeName}, State) when is_atom(NodeName) ->
    try
        [#map{value = NodeKey}] = ets:take(?REG_ATOM, NodeName),
        [#node{addr = Addr, host = Host}] = ets:take(?REGISTRY, NodeKey),
        {NodeKey, Addr, Host}
    of
        {NK = #node_key{domain = Domain}, A, H} ->
            true = case names_dirty(Domain, self()) of
                       % Only delete the address and host mapping
                       % if there're no other nodes with the same domain.
                       [] ->
                           ets:delete(?REG_ADDR, A),
                           ets:delete(?REG_HOST, H);
                       _ -> true
                   end,
            true = ets:delete(?REG_PART, NK#node_key.local_part)
    catch
        error:_ -> ok
    end,
    {noreply, State};

handle_cast(Msg, State) ->
    error_logger:error_msg("Unexpected message: ~p~n", [Msg]),
    {noreply, State}.

handle_info(Msg, State) ->
    error_logger:error_msg("Unexpected message: ~p~n", [Msg]),
    {noreply, State}.

terminate(_Reason, _State) ->
    ets:delete(?REGISTRY),
    ets:delete(?REG_ATOM),
    ets:delete(?REG_ADDR),
    ets:delete(?REG_HOST),
    ets:delete(?REG_PART),
    ok.

code_change(_Old, State, _Extra) ->
    {ok, State}.


%% internal functions

lookup_port(LocalPart, Domain) when is_atom(Domain) ->
    NodeKey =
    case ets:lookup(?REG_ATOM, LocalPart) of
        [#map{value=Value}] -> Value;
        [] -> #node_key{local_part=LocalPart, domain=Domain}
    end,
    ets:lookup_element(?REGISTRY, NodeKey, #node.port);
lookup_port(LocalPart, IP) when is_tuple(IP) ->
    Domain = ets:lookup_element(?REG_ADDR, IP, #map.value),
    lookup_port(LocalPart, Domain);
lookup_port(LocalPart, Host) ->
    Domain =
    case ets:lookup(?REG_HOST, Host) of
        [#map{value=Value}] -> Value;
        [] -> list_to_atom(Host) 
    end,
    lookup_port(LocalPart, Domain).


lookup_last_added_node(LocalPart, Domains) ->
    lists:foldl(
      fun(Domain, {Max, _NodeAtom} = Acc) ->
              case ets:lookup(?REGISTRY, #node_key{local_part=LocalPart, domain=Domain}) of
                  [#node{added_ts=Ts, name_atom=NA}] when Max < Ts -> {Ts, NA};
                  [#node{}] -> Acc
              end
      end,
      {0, undefined},
      Domains).

insert_ignore(Node = #node{ key = NK, addr = Addr, host = Host, port = Port}) ->
    case ets:lookup(?REGISTRY, NK) of
        % ignore if Address, Host and Port match
        [#node{addr = Addr, host = Host, port = Port}] -> false; 
        % update Port if Address and Host match
        [#node{addr = Addr, host = Host}] ->
            true = ets:insert(?REGISTRY, Node);
        % update Address and Host if only Port matches
        [#node{addr = A, host = H, port = Port}] ->
            true = case names_dirty(NK#node_key.domain, self()) of
                       % Only delete the host mapping
                       % if there're no other nodes with the same domain.
                       [] ->
                           ets:delete(?REG_ADDR, A),
                           ets:delete(?REG_HOST, H);
                       _ -> true
                   end,
            case is_tuple(Addr) of
                true -> true = ets:insert(?REG_ADDR, #map{key=Addr, value=NK#node_key.domain});
                _ -> true
            end,
            true = ets:insert(?REG_HOST, #map{key=Host, value=NK#node_key.domain}),
            true = ets:insert(?REGISTRY, Node);
        % insert if Node doesn't exists yet
        [] ->
            true = ets:insert(?REG_ATOM, #map{key=Node#node.name_atom, value=NK}),
            case is_tuple(Addr) of
                true -> true = ets:insert(?REG_ADDR, #map{key=Addr, value=NK#node_key.domain});
                _ -> true
            end,
            true = ets:insert(?REG_HOST, #map{key=Host, value=NK#node_key.domain}),
            true = ets:insert(?REG_PART, #map{key=NK#node_key.local_part, value=NK#node_key.domain}),
            true = ets:insert(?REGISTRY, Node)
    end.

node_list(AddrGetter) ->
    [ tuple_to_node(T, AddrGetter)
      || {L, D, P} = T <- case application:get_env(?APP, ?FUNCTION_NAME) of
                              undefined -> get_os_env(?APP, ?FUNCTION_NAME);
                              {ok, Tuples} -> Tuples 
                          end,
         is_atom(L) andalso is_atom(D) andalso is_integer(P) ].

atom_to_node(Atom, AddrGetter) when is_atom(Atom) ->    
    string_to_node(atom_to_list(Atom), AddrGetter).

string_to_node(String, AddrGetter) when is_list(String) ->
    Tokens = string:tokens(String, "@:"),
    Tuple = erlang:make_tuple(3, undefined,
                              lists:zip(lists:seq(1, length(Tokens)), Tokens)),
    tuple_to_node(Tuple, AddrGetter).

tuple_to_node({LocalPart, Domain, Port}, AddrGetter) ->
    node_from_node_key(#node_key{local_part=LocalPart, domain=Domain},
                       #node{port=Port},
                       AddrGetter).

%% First we set the name of the node as an atom,
%% join_list takes both atoms and strings as input.
node_from_node_key(NK = #node_key{local_part = LP, domain = D},
                   N = #node{name_atom = undefined},
                   AddrGetter) ->
    NameAtom = list_to_atom(join_list($@, [LP, D])),
    node_from_node_key(NK, N#node{name_atom=NameAtom}, AddrGetter);
%% Second we check if the domain is a string,
%% if so we set the host to be the domain
%% while the domain itself is converted to and atom.
node_from_node_key(NK = #node_key{domain = D},
                   N,
                   AddrGetter) when is_list(D) ->
    node_from_node_key(NK#node_key{domain = list_to_atom(D)},
                       N#node{addr=AddrGetter(D), host=D},
                       AddrGetter);
%% Third we ensure the host is set even if domain was originally an atom.
node_from_node_key(NK = #node_key{domain = D},
                   N = #node{host = undefined},
                   AddrGetter) when is_atom(D) ->
    node_from_node_key(NK,
                       N#node{addr=AddrGetter(D), host=atom_to_list(D)},
                       AddrGetter);
%% Fourth we convert the local_part to an atom if its a list.
node_from_node_key(NK = #node_key{local_part = LP},
                   N,
                   AddrGetter) when is_list(LP) ->
    node_from_node_key(NK#node_key{local_part = list_to_atom(LP)},
                       N,
                       AddrGetter);
%% Lastly we fill out the not yet defined fields of the node record.
node_from_node_key(NK = #node_key{local_part = LP, domain = D},
                   N,
                   _AddrGetter) when is_atom(LP) andalso is_atom(D) ->
    N#node{added_ts = erlang:system_time(microsecond),
           key = NK}.

addr_getter(AddressFamily) ->
    fun(Host) ->
            case inet:getaddr(Host, AddressFamily) of
                {ok, IPAddress} -> IPAddress;
                {error, PosixError} ->
                    error_logger:info_msg("No Address found for host ~p due to ~p~n",
                                          [Host, PosixError]),
                    undefined
            end
    end.


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


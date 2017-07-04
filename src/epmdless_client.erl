-module(epmdless_client).

%% @doc
%% Module which used as a callback which passed to erlang vm via `-epmd_module` attribute
%% @end

%% epmd callbacks
-export([start_link/0, register_node/3, port_please/2, names/1]).
%% gen server callbacks
-export([init/1, handle_info/2, handle_cast/2, handle_call/3, terminate/2, code_change/3]).
%% auxiliary  API
-export([add_node/2, remove_node/1, list_nodes/0]).

-record(state, {
    nodes = #{} :: map()
}).


start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


-spec register_node(Name, Port, Family) -> {ok, CreationId} when
      Name       :: atom(),
      Port       :: inet:port_number(),
      Family     :: atom(),
      CreationId :: 1..3.
%% @doc
%% registering self
%% @end
register_node(Name, Port, _Family) ->
    ok = add_node(Name, Port),
    {ok, rand:uniform(3)}.


-spec port_please(Name, Ip) -> {port, Port, Version} | noport when
      Name    :: atom(),
      Ip      :: inet:address(),
      Port    :: inet:port_number(),
      Version :: 5.
%% @doc
%% request port of node `Name` 
%% @end
port_please(Name, Ip) ->
    case gen_server:call(?MODULE, {port_please, Name, Ip}, infinity) of
        {ok, Port} ->
            error_logger:info_msg("Resolved port for ~p/~p to ~p~n", [Name, Ip, Port]),
            {port, Port, 5};
        {error, noport} ->
            error_logger:info_msg("No port for ~p/~p~n", [Name, Ip]),
            noport
    end.


-spec add_node(Node, Port) -> ok when
      Node :: atom(),
      Port :: inet:port_number().
add_node(Node, Port) ->
    ok = gen_server:call(?MODULE, {add_node, Node, Port}, infinity).


-spec list_nodes() -> [{Node, Port}] when
      Node :: atom(),
      Port :: inet:port_number().
list_nodes() ->
    Nodes = gen_server:call(?MODULE, list_nodes, infinity),
    maps:to_list(Nodes).


-spec remove_node(Node) -> ok when
      Node :: atom().
remove_node(Node) ->
    ok = gen_server:call(?MODULE, {remove_node, Node}, infinity).


%% @doc
%% List the Erlang nodes on a certain host. We don't need that
%% @end
names(_Hostname) ->
    {error, address}.


init([]) ->
    {ok, #state{}}.


handle_info(Msg, State) ->
    error_logger:error_msg("Unexpected message: ~p~n", [Msg]),
    {noreply, State}.


handle_cast(Msg, State) ->
    error_logger:error_msg("Unexpected message: ~p~n", [Msg]),
    {noreply, State}.


handle_call(list_nodes, _From, State) ->
    {reply, State#state.nodes, State};

handle_call({add_node, Node, Port}, _From, State) ->
    {reply, ok, State#state{nodes = maps:put(Node, Port, State#state.nodes)}};

handle_call({remove_node, Node}, _From, State) ->
    {reply, ok, State#state{nodes = maps:remove(Node, State#state.nodes)}};

handle_call({port_please, Node, Ip}, _From, State) ->
    Reply = case maps:find(node_ip_to_name(Node, Ip), State#state.nodes) of
        error   -> {error, noport};
        {ok, P} -> {ok, P}
    end,
    {reply, Reply, State};

handle_call(Msg, _From, State) ->
    error_logger:error_msg("Unexpected message: ~p~n", [Msg]),
    {reply, {error, {bad_msg, Msg}}, State}.


terminate(_Reason, _State) ->
    ok.


code_change(_Old, State, _Extra) ->
    {ok, State}.


%% internal funcs


-spec node_ip_to_name(Node, Ip) -> Name when
      Node :: atom(),
      Ip   :: term(),
      Name :: atom().
node_ip_to_name(Node, Ip) ->
    list_to_atom(lists:flatten(io_lib:format("~s@~s", [Node, inet:ntoa(Ip)]))).

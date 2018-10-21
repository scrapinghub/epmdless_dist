-module(epmdless_dist).

%% erl_epmd callbacks
-export([start/0, start_link/0, stop/0]).
-export([register_node/2, register_node/3]).
-export([port_please/1, port_please/2, port_please/3]).
-export([names/0, names/1]).

%% auxiliary extensions
-export([get_info/0, host_please/1, node_please/1, local_part/1]).

%% node maintenance functions
-export([add_node/2, add_node/3]).
-export([remove_node/1]).
-export([list_nodes/0]).

%% erl_epmd callbacks

start() -> start_link().

start_link() -> epmdless_dist_sup:start_link().

stop() -> epmdless_dist_sup:stop().

-spec register_node(Name, Port) -> {ok, CreationId} when
      Name       :: atom(),
      Port       :: inet:port_number(),
      CreationId :: 1..3.
register_node(Name, PortNo) ->
    register_node(Name, PortNo, inet_tcp).

-spec register_node(Name, Port, Driver) -> {ok, CreationId} when
      Name       :: atom(),
      Port       :: inet:port_number(),
      Driver     :: atom(),
      CreationId :: 1..3.
register_node(Name, Port, Driver) ->
    {ok, Pid} = epmdless_dist_sup:start_child(Name, Port, Driver),
    epmdless_client:register_node(Pid, Name, Port, Driver).

port_please(Node) ->
  port_please(Node, undefined).

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
    epmdless_dist_sup:first_succcessful_or_last_failed_child(
         fun(Child) -> epmdless_client:port_please(Child, Name, Host, Timeout)
         end,
         fun(noport) -> false;
            (_) -> true
         end).


names() -> names(undefined).

%% @doc
%% List the Erlang nodes on a certain host.
%% @end
names(Host) ->
    lists:flatten(
      epmdless_dist_sup:map_children(
        fun(Child) -> epmdless_client:names(
                        Host,
                        epmdless_client:driver(Child))
        end)).


%% auxiliary extensions

-spec get_info() -> Info when
      Info :: [{dist_port, inet:port_number()}].
get_info() ->
    lists:flatten(
      epmdless_dist_sup:map_children(
        fun(Child) -> epmdless_client:get_info(Child)
        end)).

-spec host_please(Node) -> {host, Host} | nohost when
      Node :: atom(),
      Host :: inet:hostname() | inet:ip_address().
host_please(Node) ->
    epmdless_dist_sup:first_succcessful_or_last_failed_child(
         fun(Child) -> epmdless_client:host_please(Child, Node)
         end,
         fun(nohost) -> false;
            (_) -> true
         end).

-spec node_please(LocalPart) -> Node | undefined when
      LocalPart :: atom(),
      Node :: atom().
node_please(LocalPart) ->
    epmdless_dist_sup:first_succcessful_or_last_failed_child(
         fun(Child) ->
                 epmdless_client:node_please(
                   LocalPart,
                   epmdless_client:driver(Child))
         end,
         fun(undefined) -> false;
            (_) -> true
         end).

-spec local_part(NodeName) -> LocalPart | undefined when
      NodeName :: atom(),
      LocalPart :: atom().
local_part(NodeName) ->
    epmdless_dist_sup:first_succcessful_or_last_failed_child(
         fun(Child) ->
                 epmdless_client:local_part(
                   NodeName,
                   epmdless_client:driver(Child))
         end,
         fun(undefined) -> false;
            (_) -> true
         end).

%% node maintenance functions

-spec add_node(Node, Port) -> ok when
      Node :: atom(),
      Port :: inet:port_number().
add_node(Node, Port) ->
    hd(epmdless_dist_sup:map_children(
         fun(Child) -> epmdless_client:add_node(Child, Node, Port)
         end)).


-spec add_node(Node, Host, Port) -> ok when
      Node :: atom(),
      Host :: inet:hostname() | inet:ip_address(),
      Port :: inet:port_number().
add_node(Node, Host, Port) ->
    hd(epmdless_dist_sup:map_children(
         fun(Child) -> epmdless_client:add_node(Child, Node, Host, Port)
         end)).


-spec remove_node(Node) -> ok when
      Node :: atom().
remove_node(Node) ->
    hd(epmdless_dist_sup:map_children(
         fun(Child) -> epmdless_client:remove_node(Child, Node)
         end)).


-spec list_nodes() -> [{Node, Port}] when
      Node :: atom(),
      Port :: inet:port_number().
list_nodes() ->
    lists:flatten(
      epmdless_dist_sup:map_children(
        fun(Child) -> epmdless_client:list_nodes(Child)
        end)).


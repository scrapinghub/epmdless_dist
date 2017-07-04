-module(epmdless_dist).

-export([add_node/2]).
-export([remove_node/1]).
-export([list_nodes/0]).
-export([set_nodes/1]).


-spec add_node(Node, Port) -> ok when
      Node :: atom(),
      Port :: inet:port_number().
add_node(Node, Port) ->
    epmdless_client:add_node(Node, Port).



-spec remove_node(Node) -> ok when
      Node :: atom().
remove_node(Node) ->
    epmdless_client:remove_node(Node).


-spec list_nodes() -> [{Node, Port}] when
      Node :: atom(),
      Port :: inet:port_number().
list_nodes() ->
    epmdless_client:list_nodes().



-spec set_nodes(Nodes) -> ok when
      Nodes :: [{Node, Port}],
      Node  :: atom(),
      Port  :: inet:port_number().
set_nodes(Nodes) ->
    _ = [remove_node(Node) || {Node, _} <- list_nodes()],
    _ = [add_node(Node, Port) || {Node, Port} <- Nodes],
    ok.

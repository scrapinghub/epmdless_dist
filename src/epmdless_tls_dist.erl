%%
%% %CopyrightBegin%
%%
%% Copyright Ericsson AB 2011-2016. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%
%% %CopyrightEnd%
%%

%%
-module(epmdless_tls_dist).

-export([childspecs/0, listen/1, accept/1, accept_connection/5,
	 setup/5, close/1, select/1, is_node_name/1]).

%% Generalized dist API
-export([gen_select/2]).

-ifdef(TEST).
-export([port_please/1, port_please/2,
         host_please/1, epmd_children/1]).
-endif.

-include_lib("kernel/include/net_address.hrl").
-include_lib("kernel/include/dist.hrl").
-include_lib("kernel/include/dist_util.hrl").

childspecs() ->
    inet_tls_dist:?FUNCTION_NAME().

select(Node) ->
    gen_select(eless_tcp, Node).

gen_select(Driver, Node) ->
    case split_node(atom_to_list(Node), $@, []) of
	[LP, Host] ->
	    case inet:getaddr(Host, Driver:family()) of
		{ok, _} ->
		    case application:get_env(epmdless_dist, tls_nodes) of
                {ok, NodePrefixList} -> lists:member(LP, NodePrefixList);
                undefined -> true
            end;
		_ -> false
	    end;
	_ ->
	    false
    end.

is_node_name(Node) when is_atom(Node) ->
    select(Node);
is_node_name(_) ->
    false.

listen(Name) ->
    inet_tls_dist:gen_listen(eless_tcp, Name).

accept(Listen) ->
    inet_tls_dist:gen_accept(eless_tcp, Listen).

accept_connection(AcceptPid, Socket, MyNode, Allowed, SetupTime) ->
    inet_tls_dist:gen_accept_connection(eless_tcp, AcceptPid, Socket, MyNode, Allowed, SetupTime).

setup(Node, Type, MyNode, LongOrShortNames,SetupTime) ->
    inet_tls_dist:gen_setup(eless_tcp, Node, Type, MyNode, LongOrShortNames,SetupTime).

close(Socket) ->
    inet_tls_dist:?FUNCTION_NAME(Socket).

split_node([Chr|T], Chr, Ack) ->
    [lists:reverse(Ack)|split_node(T, Chr, [])];
split_node([H|T], Chr, Ack) ->
    split_node(T, Chr, [H|Ack]);
split_node([], _, Ack) ->
    [lists:reverse(Ack)].

-ifdef(TEST).
port_please(Name) ->
    R = epmdless_dist:?FUNCTION_NAME(Name),
    spawn(fun()->ok end), %% produce side effect to force addition to stack-trace.
    R.
port_please(Name, Address) ->
    R = epmdless_dist:?FUNCTION_NAME(Name, Address),
    spawn(fun()->ok end), %% produce side effect to force addition to stack-trace.
    R.
host_please(Name) ->
    R = epmdless_dist:?FUNCTION_NAME(Name),
    spawn(fun()->ok end), %% produce side effect to force addition to stack-trace.
    R.
epmd_children(F) ->
    R = epmdless_dist_sup:F(),
    spawn(fun()->ok end), %% produce side effect to force addition to stack-trace.
    R.
-endif.

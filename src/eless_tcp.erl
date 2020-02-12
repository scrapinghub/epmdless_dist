-module(eless_tcp).

%% Socket server for TCP/IP

-export([connect/3, connect/4, listen/2, accept/1, accept/2, close/1]).
-export([send/2, send/3, recv/2, recv/3, unrecv/2]).
-export([shutdown/2]).
-export([controlling_process/2]).
-export([fdopen/2]).

-export([family/0, mask/2, parse_address/1]). % inet_tcp_dist
-export([getserv/1, getaddr/1, getaddr/2, getaddrs/1, getaddrs/2]).
-export([translate_ip/1]).

family() -> inet_tcp:family().

mask(Mask, Ip) -> inet_tcp:mask(Mask, Ip).

parse_address(Host) -> inet_tcp:parse_address(Host).

getserv(NamePort) -> inet_tcp:getserv(NamePort).

%% inet_tcp address lookup
getaddr(Address) -> inet_tcp:getaddr(Address).
getaddr(Address, Timer) -> inet_tcp:getaddr(Address, Timer).

%% inet_tcp address lookup
getaddrs(Address) -> inet_tcp:getaddrs(Address).
getaddrs(Address, Timer) -> inet_tcp:getaddrs(Address, Timer).

%% inet_udp special this side addresses
translate_ip(IP) -> inet_tcp:translate_ip(IP).


%%
%% Send data on a socket
%%
send(Socket, Packet, Opts) -> inet_tcp:send(Socket, Packet, Opts).
send(Socket, Packet) -> inet_tcp:send(Socket, Packet).

%%
%% Receive data from a socket (inactive only)
%%
recv(Socket, Length) -> inet_tcp:recv(Socket, Length).
recv(Socket, Length, Timeout) -> inet_tcp:recv(Socket, Length, Timeout).

unrecv(Socket, Data) -> inet_tcp:unrecv(Socket, Data).

%%
%% Shutdown one end of a socket
%%
shutdown(Socket, How) -> inet_tcp:shutdown(Socket, How).

%%
%% Close a socket (async)
%%
close(Socket) -> inet_tcp:close(Socket).

%%
%% Set controlling process
%%
controlling_process(Socket, NewOwner) ->
    inet_tcp:controlling_process(Socket, NewOwner).

%%
%% Connect
%%
connect(Address, Port, Opts) ->
    inet_tcp:connect(Address, Port, Opts).
connect(Address, Port, Opts, Timeout) ->
    inet_tcp:connect(Address, Port, Opts, Timeout).

%%
%% Listen
%%

listen(Port, Opts) -> inet_tcp:listen(Port, Opts).
%%
%% Accept
%%

accept(L) -> inet_tcp:accept(L).
accept(L, Timeout) -> inet_tcp:accept(L, Timeout).

%%
%% Create a port/socket from a file descriptor
%%
fdopen(Fd, Opts) -> inet_tcp:fdopen(Fd, Opts).

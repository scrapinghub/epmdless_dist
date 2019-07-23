# Epmd-less erlang distribution #

A key-value store (ETS) based Erlang Port Mapper Daemon replacement.

### Note ###
Unlike the default `epmd`, this client does not provide any service-discovery mechanism on its own.

Currently the `epmdless_dist` module integrates with [Consul KV](https://www.consul.io/docs/agent/kv.html) via a separate [node discovery project](https://bitbucket.org/scrapinghub/erlang_consul_node_discovery).

Alternatively The ports for the nodes can be added manually. Check `epmdless_dist` module API.

### Requirements ###
* Erlang >= 19.1

## Usage ##

Erlang VM needs 2 flags on start-up to override the default Erlang Port Mapper Daemon:
* One to disable epmd daemon startup: `-start_epmd false`
* Another to specify the epmd client callback module: `-epmd_module epmdless_dist`

Minimal set of options:
```
erl -start_epmd false -epmd_module epmdless_dist
```

### Dual distribution ###

By using `epmdless_dist`, Erlang Distribution can be run in a mode where both a TCP and SSL connection is open for nodes to connect to:
Here is an example configuration:
```
erl -start_epmd false \
    -epmd_module epmdless_dist \
	-boot start_sasl \
	-kernel inet_dist_listen_min 7113 \
	-kernel inet_dist_listen_max 7114 \
	-proto_dist inet_tcp epmdless_tls \
	-ssl_dist_optfile config/ss_dist.config \
	-name dual@localhost
```


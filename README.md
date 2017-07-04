# Epmd-less erlang distribution #

### App configuration ###

```
[
    {epmdless_dist, [
        {transport, tls},
        {listen_port, 7113},
        {ssl_dist_opt, [
            {client, [ssl:ssl_option()]},
            {server, [ssl:ssl_option()]}
        ]}
    ]}
].
```

##### Configuration keys #####

* transport: distribution transport, possible values `tcp` or `tls`
* listen_port: port used by distribution listener
* ssl_dist_opt: ssl options for tls-based distribution

### Usage ###

Erlang VM needs few extra flags on start to disable epmd daemon startup and override empd client callback module.

Minimal set of options:
```
erl -proto_dist epmdless_proto -start_epmd false -epmd_module epmdless_client 
```

**Note**: since epmd is disabled you need to populate epmd-client database manually.
Check `epmd_dist` module API.
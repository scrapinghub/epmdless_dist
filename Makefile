PROJECT = epmdless_dist
PROJECT_DESCRIPTION = A key-value store (ETS) based Erlang Port Mapper Daemon replacement.
PROJECT_VERSION = $(shell git describe --abbrev=0 --tags)

.DEFAULT_GOAL=all

DEPS = erlang_consul_node_discovery
dep_erlang_consul_node_discovery = git https://github.com/scrapinghub/erlang_consul_node_discovery.git a0ac2a0

TEST_DEPS = meck jiffy

devel: DEVEL_HOST ?= 127.0.0.1
devel: DEVEL_NODENAME ?= epmdless
devel: PORT_7113 ?= 7113
devel: PORT_7114 ?= 7114
devel: SSL_DIST_OPTFILE ?= config/ssl_dist.config
devel: all
	# Order of proto_dist module is significant:
	# inet_tcp will use the smaller port number,
	# epmdless_tls will take precedence when connecting to other nodes.
	erl -pa ebin \
		-boot start_sasl \
		-start_epmd false \
		-epmd_module ${PROJECT} \
		-kernel inet_dist_listen_min ${PORT_7113} \
		-kernel inet_dist_listen_max ${PORT_7114} \
		-proto_dist inet_tcp epmdless_tls \
		-ssl_dist_optfile ${SSL_DIST_OPTFILE} \
		-name ${DEVEL_NODENAME}@${DEVEL_HOST}

PLT_APPS = ssl
DIALYZER_OPTS = -Werror_handling -Wrace_conditions -Wno_match
include erlang.mk

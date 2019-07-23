PROJECT = epmdless_dist
PROJECT_DESCRIPTION = A key-value store (ETS) based Erlang Port Mapper Daemon replacement.
PROJECT_VERSION = $(shell git describe --abbrev=0 --tags)

DEVEL_HOST ?= 127.0.0.1
DEVEL_NODENAME ?= epmdless
PORT_7113 ?= 7113
PORT_7114 ?= 7114
SSL_DIST_OPTFILE ?= config/ssl_dist.config

ERLC_OPTS = +'{parse_transform, rewrite_logging}'

BUILD_DEPS = rewrite_logging
dep_rewrite_logging = git https://github.com/dmzmk/rewrite_logging 0.1.0

DEPS = erlang_consul_node_discovery
dep_erlang_consul_node_discovery = git https://bitbucket.org/scrapinghub/erlang_consul_node_discovery.git 0.2.2

TEST_DEPS = meck jiffy

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


include erlang.mk

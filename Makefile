PROJECT = epmdless_dist
PROJECT_DESCRIPTION = crypted epmd-less erlang distribution with tls based authentication
PROJECT_VERSION = 0.1.0

DEVEL_HOST ?= 127.0.0.1
DEVEL_NODENAME ?= "epmdless_devel"
PORT ?= 7113

ERLC_OPTS = +'{parse_transform, rewrite_logging}'


BUILD_DEPS = rewrite_logging
dep_rewrite_logging = git https://github.com/dmzmk/rewrite_logging 0.1.0

DEPS = jiffy erlang_consul_node_discovery
dep_jiffy = git git://github.com/davisp/jiffy.git 0.15.2
dep_erlang_consul_node_discovery = git https://bitbucket.org/scrapinghub/erlang_consul_node_discovery.git 0.2.2

TEST_DEPS = meck
dep_meck  = git git://github.com/eproxus/meck 0.8.12


compile: all


devel: all
	EPMDLESS_DIST_PORT=$(PORT) ERL_LIBS=$$ERL_LIBS:ebin/ erl -pa ebin \
			 -boot start_sasl \
			 -config config/devel.config \
			 -proto_dist epmdless_proto \
			 -start_epmd false \
			 -epmd_module epmdless_client \
			 -name $(DEVEL_NODENAME)@$(DEVEL_HOST)


include erlang.mk

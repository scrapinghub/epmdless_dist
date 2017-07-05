PROJECT = epmdless_dist
PROJECT_DESCRIPTION = crypted epmd-less erlang distribution with tls based authentication
PROJECT_VERSION = 0.0.2

DEVEL_HOST ?= 127.0.0.1
DEVEL_NODENAME ?= "epmdless_devel"
PORT ?= 7113

ERLC_OPTS = +'{parse_transform, rewrite_logging}'


BUILD_DEPS = rewrite_logging
dep_rewrite_logging = git https://github.com/dmzmk/rewrite_logging 0.1.0


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

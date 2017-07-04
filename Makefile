PROJECT = epmdless_dist
PROJECT_DESCRIPTION = crypted epmd-less erlang distribution with tls based authentication
PROJECT_VERSION = 0.0.1

DEVEL_NODENAME ?= "epmdless_devel"
PORT ?= 7113

devel: all
	ERL_LIBS=$$ERL_LIBS:ebin/ erl -pa ebin \
			 -boot start_sasl \
			 -config config/devel.config \
			 -proto_dist epmdless_proto \
			 -start_epmd false \
			 -epmd_module epmdless_client \
			 -name $(DEVEL_NODENAME)@127.0.0.1

include erlang.mk

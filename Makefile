include platform.mk

LUA_CLIB_PATH ?= luaclib
CSERVICE_PATH ?= cservice

SKYNET_BUILD_PATH ?= .

CFLAGS = -g -O2 -Wall -I$(LUA_INC) $(MYCFLAGS)
# CFLAGS += -DUSE_PTHREAD_LOCK

# lua

LUA_STATICLIB := 3rd/lua/liblua.a
LUA_LIB ?= $(LUA_STATICLIB)
LUA_INC ?= 3rd/lua

$(LUA_STATICLIB) :
	cd 3rd/lua && $(MAKE) CC='$(CC) -std=gnu99' $(PLAT)

# https : turn on TLS_MODULE to add https support

# openssl 1.1

OPENSSL11_LIBDIR    := 3rd/openssl
OPENSSL11_STATICLIB := 3rd/openssl/libcrypto.a 3rd/openssl/libssl.a
OPENSSL11_INC       := 3rd/openssl/include

# TLS_MODULE=ltls
TLS_LIB := $(OPENSSL11_LIBDIR)
TLS_INC := $(OPENSSL11_INC)

# jemalloc

JEMALLOC_STATICLIB := 3rd/jemalloc/lib/libjemalloc_pic.a
JEMALLOC_INC := 3rd/jemalloc/include/jemalloc


all : jemalloc openssl
	
.PHONY : jemalloc update3rd

MALLOC_STATICLIB := $(JEMALLOC_STATICLIB)

$(JEMALLOC_STATICLIB) : 3rd/jemalloc/Makefile
	cd 3rd/jemalloc && $(MAKE) CC=$(CC) 

3rd/jemalloc/autogen.sh :
	git submodule update --init

3rd/jemalloc/Makefile : | 3rd/jemalloc/autogen.sh
	cd 3rd/jemalloc && ./autogen.sh --with-jemalloc-prefix=je_ --enable-prof

jemalloc : $(MALLOC_STATICLIB)


$(OPENSSL11_STATICLIB) : 3rd/openssl/Makefile
	cd 3rd/openssl && $(MAKE) CC=$(CC)

3rd/openssl/config :
	git submodule update --init

3rd/openssl/Makefile : | 3rd/openssl/config
	cd 3rd/openssl && ./config no-asm no-shared no-dso no-tests

openssl : $(OPENSSL11_STATICLIB)

rm3rd :
	rm -rf 3rd/jemalloc 3rd/lua-cjson 3rd/kcp 3rd/openssl

update3rd : rm3rd
	git submodule update --init

# skynet

CSERVICE = snlua logger gate harbor
LUA_CLIB = skynet \
  client \
  bson md5 sproto lpeg \
  cjson lkcp extlib $(TLS_MODULE)

LUA_CLIB_SKYNET = \
  lua-skynet.c lua-seri.c \
  lua-socket.c \
  lua-mongo.c \
  lua-netpack.c \
  lua-memory.c \
  lua-multicast.c \
  lua-cluster.c \
  lua-crypt.c \
  lsha1.c \
  lua-sharedata.c \
  lua-stm.c \
  lua-debugchannel.c \
  lua-datasheet.c \
  lua-sharetable.c \

LUA_CLIB_EXTLIB = \
  mt19937-64/mt19937-64.c \
  mt19937-64/lua-mt19937.c \
  skiplist/skiplist.c \
  skiplist/lua-skiplist.c \
  lua-snowflake.c \
  \

SKYNET_SRC = skynet_main.c skynet_handle.c skynet_module.c skynet_mq.c \
  skynet_server.c skynet_start.c skynet_timer.c skynet_error.c \
  skynet_harbor.c skynet_env.c skynet_monitor.c skynet_socket.c socket_server.c \
  malloc_hook.c skynet_daemon.c skynet_log.c

all : \
  $(SKYNET_BUILD_PATH)/skynet \
  $(foreach v, $(CSERVICE), $(CSERVICE_PATH)/$(v).so) \
  $(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so) 

$(SKYNET_BUILD_PATH)/skynet : $(foreach v, $(SKYNET_SRC), skynet-src/$(v)) $(LUA_LIB) $(MALLOC_STATICLIB)
	$(CC) $(CFLAGS) -o $@ $^ -Iskynet-src -I$(JEMALLOC_INC) $(LDFLAGS) $(EXPORT) $(SKYNET_LIBS) $(SKYNET_DEFINES)

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

define CSERVICE_TEMP
  $$(CSERVICE_PATH)/$(1).so : service-src/service_$(1).c | $$(CSERVICE_PATH)
	$$(CC) $$(CFLAGS) $$(SHARED) $$< -o $$@ -Iskynet-src
endef

$(foreach v, $(CSERVICE), $(eval $(call CSERVICE_TEMP,$(v))))

$(LUA_CLIB_PATH)/skynet.so : $(addprefix lualib-src/,$(LUA_CLIB_SKYNET)) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src -Iservice-src -Ilualibssl -I$(OPENSSL11_INC) -L$(OPENSSL11_LIBDIR) -lcrypto

$(LUA_CLIB_PATH)/bson.so : lualib-src/lua-bson.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet-src $^ -o $@

$(LUA_CLIB_PATH)/md5.so : 3rd/lua-md5/md5.c 3rd/lua-md5/md5lib.c 3rd/lua-md5/compat-5.2.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-md5 $^ -o $@ 

$(LUA_CLIB_PATH)/client.so : lualib-src/lua-clientsocket.c lualib-src/lua-crypt.c lualib-src/lsha1.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I$(OPENSSL11_INC) -L$(OPENSSL11_LIBDIR)  $^ -o $@ -lpthread

$(LUA_CLIB_PATH)/sproto.so : lualib-src/sproto/sproto.c lualib-src/sproto/lsproto.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Ilualib-src/sproto $^ -o $@ 

$(LUA_CLIB_PATH)/ltls.so : lualib-src/ltls.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet-src -L$(TLS_LIB) -I$(TLS_INC) $^ -o $@ -lssl

$(LUA_CLIB_PATH)/lpeg.so : 3rd/lpeg/lpcap.c 3rd/lpeg/lpcode.c 3rd/lpeg/lpprint.c 3rd/lpeg/lptree.c 3rd/lpeg/lpvm.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lpeg $^ -o $@ 

$(LUA_CLIB_PATH)/cjson.so : 3rd/lua-cjson/fpconv.c 3rd/lua-cjson/strbuf.c 3rd/lua-cjson/lua_cjson.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I3rd/lua-cjson

$(LUA_CLIB_PATH)/lkcp.so : 3rd/kcp/ikcp.c lualib-src/lua-kcp.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src -I3rd/kcp

$(LUA_CLIB_PATH)/extlib.so : $(addprefix lualib-src/,$(LUA_CLIB_EXTLIB)) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src -Iservice-src -Ilualib-src


clean :
	rm -f $(SKYNET_BUILD_PATH)/skynet $(CSERVICE_PATH)/*.so $(LUA_CLIB_PATH)/*.so && \
  rm -rf $(SKYNET_BUILD_PATH)/*.dSYM $(CSERVICE_PATH)/*.dSYM $(LUA_CLIB_PATH)/*.dSYM

cleanall: clean
ifneq (,$(wildcard 3rd/jemalloc/Makefile))
	cd 3rd/jemalloc && $(MAKE) clean && rm Makefile
endif
ifneq (,$(wildcard 3rd/openssl/Makefile))
	cd 3rd/openssl && $(MAKE) distclean
endif
	cd 3rd/lua && $(MAKE) clean
	rm -f $(LUA_STATICLIB)


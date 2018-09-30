// lua-kcp.c
// lua binding for kcp (https://github.com/skywind3000/kcp)
// author:      korialuo
// create time: 2018/9/30

#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <assert.h>

#include "ikcp.h"
#include "skynet_malloc.h"

#define LKCP_MT ("com.korialuo.lkcp")
#define KCP_MTU 1080

struct kcpctx { 
    int32_t conv;
    int32_t ref;
    ikcpcb  *kcp;
    void    *ud;
};

static int
udp_output(const char *buf, int len, ikcpcb *kcp, void *user) {
    struct kcpctx *ctx = (struct kcpctx *)user;
    assert(ctx);
    lua_State *l = (lua_State *)ctx->ud;
    assert(l);

    lua_rawgeti(l, LUA_REGISTRYINDEX, ctx->ref);
    lua_pushlstring(l, buf, len);
    lua_call(l, 1, 0);

    return 0;
}

static int
lcreatekcp(lua_State *l) {
    lua_Integer conv = luaL_checkinteger(l, 1);
    int32_t ref = luaL_ref(l, LUA_REGISTRYINDEX);
    struct kcpctx *ctx = (struct kcpctx *)lua_newuserdata(l, sizeof(*ctx));
    assert(ctx);
    ctx->ud = (void *)l;
    ctx->conv = (int32_t)conv;
    ctx->ref = ref;
    ctx->kcp = ikcp_create(conv, ctx);
    assert(ctx->kcp);
    ikcp_nodelay(ctx->kcp, 0, 10, 0, 0);
    ikcp_setoutput(ctx->kcp, udp_output);

    luaL_getmetatable(l, LKCP_MT);
    lua_setmetatable(l, -2);

    return 1;
}

static int
ldestroykcp(lua_State *l) {
    struct kcpctx *ctx = (struct kcpctx *)luaL_checkudata(l, 1, LKCP_MT);
    if (!ctx)
        return luaL_argerror(l, 1, "parameter self invalid.");
    assert(ctx->kcp);
    luaL_unref(l, LUA_REGISTRYINDEX, ctx->ref);
    ikcp_release(ctx->kcp);
    ctx->kcp = NULL;
    ctx->ud = NULL;
    ctx->ref = 0;
    ctx->conv = 0;

    return 0;
}

static int
lupdatekcp(lua_State *l) {
    struct kcpctx *ctx = (struct kcpctx *)luaL_checkudata(l, 1, LKCP_MT);
    if (!ctx)
        return luaL_argerror(l, 1, "parameter self invalid.");
    assert(ctx->kcp);

    uint32_t tick = (uint32_t)luaL_checkinteger(l, 2);
    if (ikcp_check(ctx->kcp, tick) == tick)
        ikcp_update(ctx->kcp, tick);

    return 0;
}

static int
lsendkcp(lua_State *l) {
    struct kcpctx *ctx = (struct kcpctx *)luaL_checkudata(l, 1, LKCP_MT);
    if (!ctx)
        return luaL_argerror(l, 1, "parameter self invalid.");
    assert(ctx->kcp);

    size_t len;
    const char *buf = luaL_checklstring(l, 2, &len);
    int n = ikcp_send(ctx->kcp, buf, (int)len);
    lua_pushinteger(l, n);

    return 1;
}

static int
lrecvkcp(lua_State *l) {
    struct kcpctx *ctx = (struct kcpctx *)luaL_checkudata(l, 1, LKCP_MT);
    if (!ctx)
        return luaL_argerror(l, 1, "parameter self invalid.");
    assert(ctx->kcp);

    size_t len;
    const char *buf = luaL_checklstring(l, 2, &len);
    int n = ikcp_input(ctx->kcp, buf, (long)len);
    if (n < 0) {
        lua_pushinteger(l, n);
        return 1;
    }

    char recv_buf[KCP_MTU] = {0};
    n = ikcp_recv(ctx->kcp, recv_buf, KCP_MTU);
    lua_pushinteger(l, n);
    if (n < 0)
        return 1;
    lua_pushlstring(l, recv_buf, n);
    return 2;
}

LUAMOD_API int
luaopen_lkcp(lua_State *L) {
    luaL_checkversion(L);
    static int init = 0;
    if (!init) {
        init = 1;
        ikcp_allocator(skynet_malloc, skynet_free);
    }

    luaL_Reg lib[] = {
        {"create", lcreatekcp},
        {NULL, NULL},
    };

    luaL_Reg lib2[] = {
        {"__gc", ldestroykcp},
        {"update", lupdatekcp},
        {"send", lsendkcp},
        {"recv", lrecvkcp},
        {NULL, NULL},
    };

    if (luaL_newmetatable(L, LKCP_MT)) {
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        luaL_setfuncs(L, lib2, 0);
        lua_pop(L, 1);
    }

    luaL_newlib(L, lib);
    return 1;
}
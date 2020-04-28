// lua-kcp.c
// lua binding for kcp (https://github.com/skywind3000/kcp)
// author:      korialuo
// create time: 2018/9/30

#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <assert.h>

#include "ikcp.h"
#include "skynet_malloc.h"

#define LKCP_MT ("com.korialuo.lkcp")
#define KCP_MTU 1080

struct kcpctx {
    int32_t     conv;
    int32_t     ref;
    uint32_t    timeout;
    ikcpcb      *kcp;
    void        *ud;
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
lcreate(lua_State *l) {
    lua_Integer conv = luaL_checkinteger(l, 1);
    int32_t ref = luaL_ref(l, LUA_REGISTRYINDEX);
    struct kcpctx *ctx = (struct kcpctx *)lua_newuserdata(l, sizeof(*ctx));
    assert(ctx);
    ctx->ud = (void *)l;
    ctx->conv = (int32_t)conv;
    ctx->ref = ref;
    ctx->timeout = 0;
    ctx->kcp = ikcp_create(conv, ctx);
    assert(ctx->kcp);
    ikcp_nodelay(ctx->kcp, 0, 40, 0, 0); // normal mode
    ikcp_setoutput(ctx->kcp, udp_output);

    luaL_getmetatable(l, LKCP_MT);
    lua_setmetatable(l, -2);

    return 1;
}

static int
ldestroy(lua_State *l) {
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
    ctx->timeout = 0;

    return 0;
}

static int
lupdate(lua_State *l) {
    struct kcpctx *ctx = (struct kcpctx *)luaL_checkudata(l, 1, LKCP_MT);
    if (!ctx)
        return luaL_argerror(l, 1, "parameter self invalid.");
    assert(ctx->kcp);

    uint32_t tick = (uint32_t)luaL_checkinteger(l, 2);
    if (tick >= ctx->timeout) {
        ikcp_update(ctx->kcp, tick);
        ctx->timeout = ikcp_check(ctx->kcp, tick);
    }

    return 0;
}

static int
lsend(lua_State *l) {
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
lrecv(lua_State *l) {
    struct kcpctx *ctx = (struct kcpctx *)luaL_checkudata(l, 1, LKCP_MT);
    if (!ctx)
        return luaL_argerror(l, 1, "parameter self invalid.");
    assert(ctx->kcp);

    char recv_buf[KCP_MTU] = {0};
    int n = ikcp_recv(ctx->kcp, recv_buf, KCP_MTU);
    if (n < 0)
        lua_pushnil(l);
    else
        lua_pushlstring(l, recv_buf, n);
    lua_pushinteger(l, n);
    return 2;
}

static int
linput(lua_State *l) {
    struct kcpctx *ctx = (struct kcpctx *)luaL_checkudata(l, 1, LKCP_MT);
    if (!ctx)
        return luaL_argerror(l, 1, "parameter self invalid.");
    assert(ctx->kcp);

    size_t len;
    const char *buf = luaL_checklstring(l, 2, &len);
    int n = ikcp_input(ctx->kcp, buf, (long)len);
    lua_pushinteger(l, n);
    return 1;
}

static int
lflush(lua_State *l) {
    struct kcpctx *ctx = (struct kcpctx *)luaL_checkudata(l, 1, LKCP_MT);
    if (!ctx)
        return luaL_argerror(l, 1, "parameter self invalid.");
    assert(ctx->kcp);

    ikcp_flush(ctx->kcp);
    return 0;
}

static int
lnodelay(lua_State *l) {
    struct kcpctx *ctx = (struct kcpctx *)luaL_checkudata(l, 1, LKCP_MT);
    if (!ctx)
        return luaL_argerror(l, 1, "parameter self invalid.");
    assert(ctx->kcp);

    int nodelay = (int)luaL_optinteger(l, 2, 0);
    int interval = (int)luaL_optinteger(l, 3, 40);
    int resend = (int)luaL_optinteger(l, 4, 0);
    int nc = (int)luaL_optinteger(l, 5, 0);
    ikcp_nodelay(ctx->kcp, nodelay, interval, resend, nc);

    return 0;
}

static int
lwndsize(lua_State *l) {
    struct kcpctx *ctx = (struct kcpctx *)luaL_checkudata(l, 1, LKCP_MT);
    if (!ctx)
        return luaL_argerror(l, 1, "parameter self invalid.");
    assert(ctx->kcp);

    int snd = (int)luaL_optinteger(l, 2, 32);
    int rcv = (int)luaL_optinteger(l, 3, 32);
    ikcp_wndsize(ctx->kcp, snd, rcv);

    return 0;
}


LUAMOD_API int
luaopen_lkcp(lua_State *l) {
    luaL_checkversion(l);
    static int init = 0;
    if (!init) {
        init = 1;
        ikcp_allocator(skynet_malloc, skynet_free);
    }

    luaL_Reg lib[] = {
        {"create", lcreate},
        {NULL, NULL},
    };

    luaL_Reg lib2[] = {
        {"__gc", ldestroy},
        {"update", lupdate},
        {"send", lsend},
        {"recv", lrecv},
        {"input", linput},
        {"flush", lflush},
        {"nodelay", lnodelay},
        {"wndsize", lwndsize},
        {NULL, NULL},
    };

    if (luaL_newmetatable(l, LKCP_MT)) {
        lua_pushvalue(l, -1);
        lua_setfield(l, -2, "__index");
        luaL_setfuncs(l, lib2, 0);
        lua_pop(l, 1);
    }

    luaL_newlib(l, lib);
    return 1;
}

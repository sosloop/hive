-- redis_test.lua
local log_debug = logger.debug

local timer_mgr = hive.get("timer_mgr")

local RedisMgr = import("store/redis_mgr.lua")
local redis_mgr = RedisMgr()

timer_mgr:once(3000, function()
    local code, res = redis_mgr:execute("default", "get", "aaa")
    log_debug("db get code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "set", "aaa", 123)
    log_debug("db set code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "get", "aaa")
    log_debug("db get code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "del", "aaa")
    log_debug("db del code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "get", "aaa")
    log_debug("db get code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "hget", "bb", "k1")
    log_debug("db hget code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "hset", "bb", "k1", 2)
    log_debug("db hset code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "hget", "bb", "k1")
    log_debug("db hget code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "hdel", "bb", "k1")
    log_debug("db hdel code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "hget", "bb", "k1")
    log_debug("db hget code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "subscribe", "test")
    log_debug("db subscribe code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "publish", "test", 123)
    log_debug("db publish code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "sadd", "set1","one")
    log_debug("db sadd code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "scard", "set1")
    log_debug("db scard code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "sismember", "set1","one")
    log_debug("db sismember code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "sismember", "set1","two")
    log_debug("db sismember code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "smembers", "set1")
    log_debug("db smembers code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "spop", "set1")
    log_debug("db spop code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "zadd", "zset1",1,"one")
    log_debug("db zadd code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "zadd", "zset1",1,"uno")
    log_debug("db zadd code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "zadd", "zset1",2,"two")
    log_debug("db zadd code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "zadd", "zset1",3,"three")
    log_debug("db zadd code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "zcard", "zset1")
    log_debug("db zcard code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "zcount", "zset1",1,2)
    log_debug("db zcount code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "zrange", "zset1",0,2)
    log_debug("db zrange code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "zrank", "zset1","two")
    log_debug("db zrank code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "zscore", "zset1","two")
    log_debug("db zscore code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "zrange", "zset1", 0, 2, "WITHSCORES")
    log_debug("db zrange withscores code: %s, res = %s", code, res)
    code, res = redis_mgr:execute("default", "zrangebyscore", "zset1", 0, 2)
    log_debug("db zrange zrangebyscore code: %s, res = %s", code, res)
end)
--service.lua
--每个服务进程都有一个唯一的进程id，由4部分组成
--1、服务类型 0-63
--2、区服信息 0-1023
--3、分组信息 0-63
--4、实例编号 0-1023
--每个服务进程都有一个唯一的服务，由2部分组成
--1、服务类型 0-63
--2、实例编号 0-1023
--变量说明
--id：          进程id      32位数字
--group：       分组信息    6-3
--index：       实例编号    0-1023
--region:       分区信息    0-1023
--servcie:      服务类型    0-63
--servcie_id:   服务id      32位数字
--service_name: 服务名      lobby
--service_nick: 服务别名    lobby.1

import("kernel/config_mgr.lua")

local sformat       = string.format

--服务组常量
local SERVICES      = _ENV.SERVICES or {}
local SERVICE_NAMES = _ENV.SERVICE_NAMES or {}
local SERVICE_HASHS = _ENV.SERVICE_HASHS or {}

service             = {}

function service.make_node(port, domain)
    hive.node_info = {
        id           = hive.id,
        name         = hive.name,
        index        = hive.index,
        service_id   = hive.service_id,
        service_name = hive.service_name,
        port         = port or hive.index,
        host         = domain or hive.host,
    }
end

function service.init()
    --加载服务配置
    local config_mgr = hive.get("config_mgr")
    local service_db = config_mgr:init_table("service", "id")
    for _, conf in service_db:iterator() do
        SERVICES[conf.name]    = conf.id
        SERVICE_NAMES[conf.id] = conf.name
        SERVICE_HASHS[conf.id] = conf.hash
    end
    config_mgr:close_table("service")
    --初始化服务信息
    local name        = environ.get("HIVE_SERVICE")
    local index       = environ.number("HIVE_INDEX", 1)
    local service_id  = service.name2sid(name)
    hive.index        = index
    hive.id           = service.make_id(name, index)
    hive.service_name = name
    hive.service_id   = service_id
    hive.name         = sformat("%s_%s", name, index)
    hive.host         = environ.get("HIVE_HOST_IP")
    service.make_node()
end

--生成节点id
function service.make_id(name, index)
    if type(name) == "string" then
        name = SERVICES[name]
    end
    return (name << 16) | index
end

--生成服务id
function service.make_sid(service, index)
    return (service << 16) | index
end

function service.services()
    return SERVICES
end

--节点id获取服务id
function service.id2sid(hive_id)
    return (hive_id >> 16) & 0xff
end

--节点id获取服务index
function service.id2index(hive_id)
    return hive_id & 0x3ff
end

--节点id转服务名
function service.id2name(hive_id)
    return SERVICE_NAMES[hive_id >> 16]
end

--服务id转服务名
function service.sid2name(service_id)
    return SERVICE_NAMES[service_id]
end

--服务名转服务id
function service.name2sid(name)
    return SERVICES[name]
end

--节点id转服务昵称
function service.id2nick(hive_id)
    if hive_id == nil or hive_id == 0 then
        return "nil"
    end
    local index      = hive_id & 0x3ff
    local service_id = hive_id >> 16
    local sname      = service.sid2name(service_id)
    return sformat("%s_%s", sname, index)
end

--服务固定hash
function service.hash(service_id)
    return SERVICE_HASHS[service_id]
end

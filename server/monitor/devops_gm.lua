﻿---devops_gm_mgr.lua
local lstdfs        = require('lstdfs')
local lcodec        = require("lcodec")
local sdump         = string.dump
local log_err       = logger.err
local log_warn      = logger.warn
local log_debug     = logger.debug
local time_str      = datetime_ext.time_str
local ssplit        = string_ext.split
local sname2sid     = service.name2sid

local env_get       = environ.get
local check_failed  = hive.failed
local json_decode   = hive.json_decode

local gm_agent      = hive.get("gm_agent")
local monitor_mgr   = hive.get("monitor_mgr")
local timer_mgr     = hive.get("timer_mgr")
local thread_mgr    = hive.get("thread_mgr")
local mongo_agent   = hive.get("mongo_agent")
local http_client   = hive.get("http_client")

local GMType        = enum("GMType")
local ServiceStatus = enum("ServiceStatus")
local DevopsGmMgr   = singleton()

function DevopsGmMgr:__init()
    --注册GM指令
    self:register_gm()
end

function DevopsGmMgr:register_gm()
    local cmd_list = {
        { gm_type = GMType.DEV_OPS, name = "gm_set_log_level", desc = "设置日志等级", comment = "(all/全部,日志等级debug[1]-fatal[6])", args = "svr_name|string level|integer" },
        { gm_type = GMType.DEV_OPS, name = "gm_hotfix", desc = "代码热更新", args = "" },
        { gm_type = GMType.DEV_OPS, name = "gm_inject", desc = "代码注入",
          args    = "service_name|string index|integer file_name|string code_content|string" },
        { gm_type = GMType.DEV_OPS, name = "gm_set_server_status", desc = "设置服务器状态", comment = "[0运行1禁开局2强退],延迟(秒),服务/index",
          args    = "status|integer delay|integer service_name|string index|integer" },
        { gm_type = GMType.DEV_OPS, name = "gm_hive_quit", desc = "关闭服务器", comment = "强踢玩家并停服", args = "reason|integer" },
        { gm_type = GMType.DEV_OPS, name = "gm_cfg_reload", desc = "配置表热更新", comment = "(0 本地 1 远程)", args = "is_remote|integer" },
        { gm_type = GMType.DEV_OPS, name = "gm_collect_gc", desc = "lua全量gc", comment = "", args = "" },
        { gm_type = GMType.DEV_OPS, name = "gm_snapshot", desc = "lua内存快照", comment = "0开始1结束,服务/index", args = "snap|integer service_name|string index|integer" },
        { gm_type = GMType.DEV_OPS, name = "gm_count_obj", desc = "lua对象计数", comment = "最小个数,服务/index", args = "less_num|integer service_name|string index|integer" },
        --工具
        { gm_type = GMType.TOOLS, name = "gm_guid_view", desc = "guid信息", comment = "(拆解guid)", args = "guid|integer" },
        { gm_type = GMType.TOOLS, name = "gm_log_format", desc = "日志格式", comment = "0压缩,1格式化", args = "data|string swline|integer" },
        { gm_type = GMType.TOOLS, name = "gm_db_get", desc = "数据库查询",
          args    = "db_name|string table_name|string key_name|string key_value|string" },
        { gm_type = GMType.TOOLS, name = "gm_db_set", desc = "数据库更新",
          args    = "db_name|string table_name|string key_name|string key_value|string json_value|string" },
    }
    gm_agent:insert_command(cmd_list, self)
end

-- 设置日志等级
function DevopsGmMgr:gm_set_log_level(svr_name, level)
    log_warn("[DevopsGmMgr][gm_set_log_level] gm_set_log_level %s, %s", svr_name, level)
    if level < 1 or level > 6 then
        return { code = 1, msg = "level not in ragne 1~6" }
    end
    return monitor_mgr:broadcast("rpc_set_log_level", svr_name, level)
end

-- 热更新
function DevopsGmMgr:gm_hotfix()
    log_warn("[DevopsGmMgr][gm_hotfix]")
    monitor_mgr:broadcast("rpc_reload")
    return { code = 0 }
end

function DevopsGmMgr:gm_inject(service_name, index, file_name, code_content)
    log_debug("[DevopsGmMgr][gm_inject] svr_name:%s:%s, file_name:%s, code_content:%s", service_name, index, file_name, code_content)
    local func = nil
    if file_name ~= "" then
        func = loadfile(file_name)
    elseif code_content ~= "" then
        func = load(code_content)
    end
    if func and func ~= "" then
        if index == 0 then
            return monitor_mgr:broadcast("rpc_inject", service_name, sdump(func))
        else
            return self:call_target_rpc(service_name, index, "rpc_inject", sdump(func))
        end
    end
    log_err("[DevopsGmMgr][gm_inject] error file_name:%s, code_content:%s", file_name, code_content)
    return { code = -1 }
end

function DevopsGmMgr:gm_set_server_status(status, delay, service_name, index)
    log_warn("[DevopsGmMgr][gm_set_server_status]:%s,exe time:%s,service:%s,index:%s ",
             status, time_str(hive.now + delay), service_name, index)
    if status < ServiceStatus.RUN or status > ServiceStatus.STOP then
        return { code = 1, msg = "status is more than" }
    end
    local service_id = 0
    if service_name ~= "" then
        service_id = sname2sid(service_name)
        if not service_id then
            return { code = 1, msg = "the service_name is error" }
        end
    end

    timer_mgr:once(delay * 1000, function()
        if service_id > 0 and index ~= 0 then
            --指定目标
            local target_id = service.make_sid(service_id, index)
            return monitor_mgr:send_by_sid(target_id, "rpc_set_server_status", status)
        else
            monitor_mgr:broadcast("rpc_set_server_status", service_id, status)
        end
    end)
    return { code = 0 }
end

function DevopsGmMgr:gm_hive_quit(reason)
    log_warn("[DevopsGmMgr][gm_hive_quit] exit hive exe time:%s ", time_str(hive.now))
    monitor_mgr:broadcast("rpc_set_server_status", 0, ServiceStatus.STOP)
    thread_mgr:sleep(3000)
    monitor_mgr:broadcast("rpc_hive_quit", 0, reason)
    return { code = 0 }
end

function DevopsGmMgr:gm_cfg_reload(is_remote)
    log_debug("[DevopsGmMgr][gm_cfg_reload] is_remote:%s", is_remote)
    local flag = (is_remote == 1)
    if flag then
        local url = env_get("HIVE_CONFIG_RELOAD_URL", "")
        if url == "" then
            log_err("[DevopsGmMgr][gm_cfg_reload] HIVE_CONFIG_RELOAD_URL not set")
            return
        end
        -- 查看本地文件路径下的所有配置文件
        -- 遍历配置表，依次查询本地文件是否存在远端
        -- 存在则拉取并覆盖

        local current_path = lstdfs.current_path()
        local cfg_path     = current_path .. "/../server/config/"
        local cur_dirs     = lstdfs.dir(cfg_path)
        for _, file in pairs(cur_dirs) do
            thread_mgr:fork(function()
                local full_file_name  = file.name
                local split_arr       = ssplit(full_file_name, "/")
                local file_name       = split_arr[#split_arr]
                local remote_file_url = url .. "/" .. file_name
                local ok, status, res = http_client:call_get(remote_file_url)
                if ok and status == 200 then
                    io_ext.writefile(full_file_name, res)
                end
            end)
        end
    end

    local notify_time = flag and 10000 or 1
    timer_mgr:once(notify_time, function()
        monitor_mgr:broadcast("rpc_reload")
    end)

    return { code = 0 }
end

function DevopsGmMgr:gm_collect_gc()
    monitor_mgr:broadcast("rpc_collect_gc")
    return { code = 0 }
end

function DevopsGmMgr:gm_snapshot(snap, service_name, index)
    return self:call_target_rpc(service_name, index, "rpc_snapshot", snap)
end

function DevopsGmMgr:gm_count_obj(less_num, service_name, index)
    return self:call_target_rpc(service_name, index, "rpc_count_lua_obj", less_num)
end

function DevopsGmMgr:gm_guid_view(guid)
    local group, index, time = lcodec.guid_source(guid)
    local group_h, group_l   = (group >> 4) & 0xf, group & 0xf

    return { group = group, group_h = group_h, group_l = group_l, index = index, time = time_str(time) }
end

function DevopsGmMgr:gm_log_format(data, swline)
    if type(data) ~= "string" then
        return "格式错误"
    end
    if type(swline) ~= "number" then
        swline = 0
    end
    local data_t = lcodec.unserialize(data)
    return lcodec.serialize(data_t, swline)
end

function DevopsGmMgr:gm_db_get(db_name, table_name, key_name, key_value)
    log_debug("[DevopsGmMgr][gm_db_get] db_name:%s, table_name:%s, key_name:%s, key_value:%s", db_name, table_name, key_name, key_value)
    local ok, code, result = mongo_agent:find_one({ table_name, { [key_name] = key_value }, { _id = 0 } }, nil, db_name)
    if check_failed(code, ok) then
        log_err("[DevopsGmMgr][gm_db_get] failed: %s", code)
        return { code = -1 }
    else
        return { code = 0, data = result }
    end
end

function DevopsGmMgr:gm_db_set(db_name, table_name, key_name, key_value, json_str)
    log_debug("[DevopsGmMgr][gm_db_set] db_name:%s, table_name:%s, key_name:%s key_value:%s, json_str:%s",
              db_name, table_name, key_name, key_value, json_str)
    local ok1, value = json_decode(json_str, true)
    if not ok1 then
        return false
    end
    local ok, code, result = mongo_agent:update({ table_name, value, { [key_name] = key_value }, true }, nil, db_name)
    if check_failed(code, ok) then
        log_err("[DevopsGmMgr][gm_db_set] failed: code: %s, result: %s", code, result)
        return false
    end
    return true
end

function DevopsGmMgr:get_target_id(service_name, index)
    if service_name ~= "" and index ~= 0 then
        local service_id = sname2sid(service_name)
        if service_id then
            return service.make_sid(service_id, index)
        end
    end
end

function DevopsGmMgr:call_target_rpc(service_name, index, rpc, ...)
    local target_id = self:get_target_id(service_name, index)
    if not target_id then
        return { code = 1, msg = "the service_name is error" }
    end
    return monitor_mgr:call_by_sid(target_id, rpc, ...)
end

hive.devops_gm_mgr = DevopsGmMgr()

return DevopsGmMgr

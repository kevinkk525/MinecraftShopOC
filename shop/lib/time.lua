---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Kevin.
--- DateTime: 30.01.2020 21:32
---

local _update_interval = 600 -- every 10 minutes

local internet         = require "internet"
local os               = require "os"
local computer         = require "computer"
local json             = require "json"
local thread           = require "thread"
local _t_url           = "http://worldtimeapi.org/api/timezone/Europe/Berlin"
local _t               = 946684800
local _t_offs          = 0
local _last_update     = 0
local _last_uptime     = 0
local _tick_conversion = 72
local _sync_thread
local time             = {}

function time._error(message)
    print(message)
end

function time._info(message)
    print(message)
end

function time._debug(message)
    print(message)
end

function time._requestTime(url)
    local a    = computer.uptime()
    local s, r = pcall(internet.request, url)
    if not s then
        time._error(r .. " url")
        return false, nil, nil
    end
    s, r = pcall(r)
    if not s then
        time._error(r .. " on request")
        return false, nil, nil
    end
    r         = json.decode(r)
    local off = r.utc_offset
    off       = tonumber(off:sub(2, off:find(":") - 1)) + tonumber(off:sub(off:find(":") + 1, off:len())) / 60
    if r.utc_offset:sub(1, 1) == "-" then
        off = 0 - off
    end
    off          = off * 3600
    _last_update = os.time()
    _last_uptime = computer.uptime()
    time._debug("synced, took", _last_uptime - a, "s")
    return true, r.unixtime, off
end

function time._getTime()
    local tt      = computer.uptime()
    local s, t, o = time._requestTime(_t_url)
    if s then
        _t           = t
        _t_offs      = o
        _last_update = os.time()
        _last_uptime = tt
        return true
    end
    return false
end

function time.init(url, force, update_interval)
    if update_interval then
        _update_interval = update_interval
    end
    if not url then
        url = _t_url
    end
    local s, t, o = time._requestTime(url)
    if s or not s and force then
        _t_url = url
    end
    if s then
        _t      = t
        _t_offs = o
    end
    if _sync_thread then
        _sync_thread:kill()
    end
    _sync_thread = thread.create(time._sync)
end

function time._sync()
    local adjusted = 0
    os.sleep(60)
    while true do
        local last      = _last_update
        local last_time = _t
        if time._getTime() then
            time._debug("delta", (_last_update - last) / _tick_conversion, "delta synced", math.abs(_t - last_time))
            if (_last_update - last) / _tick_conversion < _update_interval * 3 and math.abs(_t - last_time) > 1 then
                -- don't calculate drift if last sync was 3*update_interval because the computer
                -- was probably unloaded or the server restarted or something.
                --print("_t", _t, "last_time", last_time, "_last_update", _last_update, "last", last, "_tick_conversion", _tick_conversion)
                local drift      = ((_last_update - last) / _tick_conversion) / (_t - last_time)
                _tick_conversion = _tick_conversion - (1 - drift) * _tick_conversion / 2 -- /2 to make the steps smaller
                time._debug("drifted by", drift, " new tick_conversion:", _tick_conversion)
                adjusted = adjusted + 1
            end
        else
            time._info("Sync didn't work")
        end
        if adjusted < 3 then
            os.sleep(60 * adjusted)
        else
            while os.time() - _last_update < _update_interval * _tick_conversion do
                os.sleep(5)
            end
        end
    end
end

function time.time()
    if not _sync_thread then
        time.init() -- not initialized
    end
    if _last_uptime == 0 then
        time.init(_t_url)
    end
    if os.time() - _last_update > (_update_interval + 20) * _tick_conversion then
        time._info("Not synced in time")
        if time._getTime() then
            return _t + _t_offs
        end
    end
    return _t + _t_offs + (os.time() - _last_update) / _tick_conversion
end

function time.present()
    while true do
        print(os.date("%X", time.time()))
        os.sleep(1)
    end
end

return time
---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Kevin.
--- DateTime: 22.12.2019 18:01
---

local log    = require("shop.logging")
local config = require("shop.config_stock")
log.init(config.path_logfile, nil, config.log_lines_textbox, config.max_filesize_log)
local thread    = require("thread")
local component = require("component")
component.gpu.setResolution(160, 50)
local gui      = require("shop.stockGUI")
local GUI      = require("GUI")
local computer = require("computer")
local json     = require("json")
local event    = require("event")

log.setTextBox(gui.textBox_logs)
local tunnel           = component.tunnel
local db               = component.database
local me               = component.proxy(config.address_me_storage)
local transposer       = component.proxy(config.address_transposer)

local should_terminate = false

----
local items            = {}
----


local function getStandardItemNBT(item)
    local item_copy = {}
    for key, value in pairs(item) do
        if config.identity_blacklist[key] == nil then
            item_copy[key] = value
        end
    end
    if config.getItemIdentityName(item) ~= config.getItemIdentityName(item_copy) then
        log.critical("Itemcopy is not equal to original")
        -- should actually never happen
    end
    return item_copy
end

local function newItem(it)
    local item        = {}
    item.ident        = it.ident
    item.amount       = it.amount
    item.nbt          = getStandardItemNBT(it.nbt)
    item.task         = nil
    item.time         = nil
    item.error        = nil
    items[#items + 1] = item
    return item
end

local function getAmountAvailable(nbt)
    nbt.size        = nil
    nbt.isCraftable = nil
    local item      = me.getItemsInNetwork(nbt)
    if item.n >= 1 then
        if item.n > 1 then
            log.warn("Found multiple entries in me for " .. config.getItemIdentityName(nbt))
        end
        return item[1].size
    end
    return 0
end

local function getCPUs()
    local cpus = me.getCpus()
    local busy = 0
    for i, cpu in pairs(cpus) do
        if i ~= "n" then
            if cpu.busy then
                busy = busy + 1
            end
        end
    end
    return cpus.n - busy > config.crafting_cpus_left
end

local function refresh_textbox_requested()
    gui.textBox_scheduled.lines = {}
    for i, item in pairs(items) do
        if not item.error and not item.task then
            gui.textBox_scheduled.lines[#gui.textBox_scheduled.lines + 1] = item.ident .. "    " .. tostring(item.amount)
        end
    end
    gui.application:draw()
end

local function refresh_textbox_errors()
    gui.textBox_errors.lines = {}
    for i, item in pairs(items) do
        if item.error then
            gui.textBox_errors.lines[#gui.textBox_errors.lines + 1] = item.ident .. "    " .. tostring(item.error)
        end
    end
    gui.application:draw()
end

local function refresh_textbox_crafting()
    gui.textBox_crafting.lines = {}
    for i, item in pairs(items) do
        if item.task then
            local amount = item.amount
            if item.amount > config.crafting_batch_size then
                amount = config.crafting_batch_size
            end
            gui.textBox_crafting.lines[#gui.textBox_crafting.lines + 1] = item.ident .. "  " .. tostring(amount)
        end
    end
    gui.application:draw()
end

local function removeFinishedTasks()
    local i = 1
    while items[i] do
        local item = items[i]
        if not item.task then
        
        elseif item.task.isDone() or item.task.isCanceled() then
            if item.task.isDone() then
            elseif item.task.isCanceled() then
                local available = getAmountAvailable(item.nbt)
                if available == 0 then
                    item.error = "Failed crafting"
                    refresh_textbox_errors()
                else
                    item.error = nil
                end
            end
            item.task = nil
            refresh_textbox_crafting()
            refresh_textbox_requested()
        elseif computer.uptime() - item.time > config.crafting_timeout then
            item.error = "Crafting takes too long, cancel manually!"
            refresh_textbox_errors()
        end
        i = i + 1
    end
    if i > #items then
        i = 1
    end
end

-------------------------------
-- GUI

gui.menu_exit.onTouch = function(application, object, e2, e3, e4, e5, e6, user)
    if user == config.owner then
        should_terminate = true
        gui.application:stop()
        return
    end
    --gui.on_alert = true
    GUI.notice(application, 5, "You are not authorized to terminate this program!")
    --gui.on_alert = false
end

-------------------------------
-- Items

local function startCrafting(item)
    if item.task then
        return false
    end
    local craft = me.getCraftables(item.nbt)
    if craft.n ~= 1 then
        log.error("Wrong craftable available for " .. item.ident .. ", n=" .. tostring(craft.n))
        item.error = "Wrong craftable available, n=" .. tostring(craft.n)
        refresh_textbox_errors()
        return false
    end
    local amount = item.amount
    if amount > config.crafting_batch_size then
        amount = config.crafting_batch_size
    end
    item.task = craft[1].request(amount)
    item.time = computer.uptime()
    refresh_textbox_crafting()
    refresh_textbox_requested()
    return true
end

local function modem_message(event_name, localAddress, remoteAddress, port, distance, message)
    --print("Got message on", localAddress, "from", remoteAddress, "on port", port, "distance", distance, "message:", message)
    -- message: {"ident":ident, "amount":50, "nbt"=NBT}
    local success, request = pcall(json.decode, message)
    if not success then
        log.error("Couldn't decode json message " .. message .. ", error:" .. request)
        return
    end
    if request.nbt == nil or request.amount == nil or request.ident == nil then
        log.error("Message incorrectly formatted: " .. message)
        return
    end
    for i, req in pairs(items) do
        if req.ident == request.ident then
            req.amount = request.amount
            refresh_textbox_requested()
            return
        end
    end
    -- if item is not found in active requests or errored requests, then add it
    newItem(request)
    refresh_textbox_requested()
end

local export_should_stop = false

local function exportItem(ident, item, size)
    export_should_stop = false
    gui.label_current_export.setValue(ident .. "    " .. tostring(size))
    db.clear(1)
    me.store(item, db.address, 1, 1)
    local fs, hs, s          = config.calculateExportActivations(item, size)
    local amount, error
    local exports            = {
        { ["iter"] = fs, ["addr"] = config.address_export_stack, ["side"] = config.side_export_stack, ["descr"] = "stack" },
        { ["iter"] = hs, ["addr"] = config.address_export_half, ["side"] = config.side_export_half, ["descr"] = "half" },
        { ["iter"] = s, ["addr"] = config.address_export_single, ["side"] = config.side_export_single, ["descr"] = "single" }
    }
    local export
    local amount_transferred = 0
    for _, ex in pairs(exports) do
        if ex.iter > 0 then
            export = component.proxy(ex.addr)
            if export.setExportConfiguration(ex.side, 1, db.address, 1) ~= true then
                log.error("Error configuring export bus " .. ex.descr)
                return false, 0
            end
            for _ = 1, ex.iter do
                amount, error = export.exportIntoSlot(ex.side)
                if amount == nil then
                    --log.error("Error exporting " .. ex.descr, error)
                    return false, amount_transferred
                end
                amount_transferred = amount_transferred + amount
                os.sleep(0)
                if export_should_stop then
                    --print("Got timeout exporting")
                    export_should_stop = false
                    return true, amount_transferred
                end
            end
        end
        os.sleep(0.1)
    end
    return true, amount_transferred
end

local function timeout_export(timeout)
    local st = computer.uptime()
    while computer.uptime() - st < timeout do
        os.sleep(5)
    end
    export_should_stop = true
    --print("Timeout reached")
end

local function item_loop()
    local i = 1
    while not should_terminate do
        if items[i] ~= nil then
            local item = items[i]
            if not item.task then
                local available = getAmountAvailable(item.nbt)
                if available > 0 then
                    local tmp_amount = item.amount
                    if available < item.amount then
                        item.amount = available
                    end
                    local timeout_thread              = thread.create(timeout_export, config.timeout_export)
                    local success, amount_transferred = exportItem(item.ident, item.nbt, item.amount)
                    gui.label_current_export.setValue("")
                    if success or amount_transferred > 0 then
                        local short = false
                        if item.amount ~= tmp_amount then
                            item.amount = tmp_amount
                            short       = true
                        elseif not success then
                            --print("waiting until empty")
                            local itemst = transposer.getAllStacks(config.side_transposer_transceiver).getAll()
                            while config.getItemIdentityName(itemst[16]) ~= config.identity_empty do
                                os.sleep(1)
                                itemst = transposer.getAllStacks(config.side_transposer_transceiver).getAll()
                            end
                            --print("waiting done")
                            short = true
                        end
                        item.amount = item.amount - amount_transferred
                        if item.amount == 0 then
                            table.remove(items, i)
                            i = i - 1
                        elseif short then
                            --print("Trying again, not enough items were available")
                        end
                    else
                        item.error = "Error exporting, exported " .. tostring(amount_transferred) .. " items"
                    end
                    timeout_thread:kill()
                else
                    local craft = me.getCraftables(item.nbt)
                    if craft.n == 1 then
                        if getCPUs() then
                            startCrafting(item)
                        else
                            item.error = "Waiting for CPU"
                        end
                    else
                        item.error = "No items available"
                    end
                end
            end
            refresh_textbox_errors()
            refresh_textbox_requested()
            i = i + 1
            os.sleep(1)
        else
            os.sleep(1)
            if i > #items then
                i = 1
            end
        end
    end
end

-------------------------------
-- Start everything

local function info()
    while not should_terminate do
        gui.label_uptime.text = "Uptime: " .. tostring(computer.uptime())
        gui.label_ram.text    = "RAM free: " .. string.format("%02.2f", tostring(computer.freeMemory() / 1024)) .. "kB"
        if not gui.on_alert then
            gui.application:draw()
        end
        os.sleep(2)
    end
    print("info exited")
end

local function wrap(name, func, ...)
    local no_interrupt = false
    if name == "info" then
        no_interrupt = true
    end
    while true and not should_terminate do
        local res, ret = pcall(func, ...)
        if not res and not no_interrupt then
            print(name, ret)
            log.critical(name .. ": " .. tostring(ret))
        end
        if not no_interrupt then
            return
        end
    end
end

local function gui_func()
    gui.application:start()
    event.ignore("modem_message", modem_message)
    print("GUI exited")
end

local function main_loop()
    while should_terminate == false do
        pcall(os.sleep, 5)
        -- do nothing but prevent hard interrupt CTRL+ALT+C from terminating program
        -- too many interrupts can however make the PC freeze.. would need an external WDT?
    end
    print("main exited")
end

local function scan_errors()
    while not should_terminate do
        st = computer.uptime()
        while computer.uptime() - st < config.scanning_interval do
            os.sleep(5)
            if should_terminate then
                return
            end
        end
        local i = 1
        while i <= #items and items[i] do
            local item      = items[i]
            local available = me.getItemsInNetwork(item.nbt)
            if available.n == 1 and available[1].size > 0 then
                -- will keep exporting
                item.error = nil
            elseif item.task then
                -- still crafting
            elseif me.getCraftables(item.nbt).n == 1 then
                if getCPUs() then
                    startCrafting(item)
                else
                    item.error = "Waiting for CPU"
                    refresh_textbox_errors()
                end
            end
            i = i + 1
        end
        if i > #items then
            i = 1
        end
    end
end

local function crafting_finished()
    while not should_terminate do
        os.sleep(5)
        removeFinishedTasks()
    end
end

local function init()
    refresh_textbox_errors()
    refresh_textbox_requested()
    event.listen("modem_message", modem_message)
    gui.application:draw(true)
    local thread_gui             = thread.create(wrap, "gui_func", gui_func)
    local thread_info            = thread.create(wrap, "info", info)
    local thread_loop            = thread.create(wrap, "item_loop", item_loop)
    local thread_scanning        = thread.create(wrap, "scan", scan_errors)
    local thread_crafting_finish = thread.create(wrap, "crafting_finished", crafting_finished)
    log.info("Started")
end

init()
main_loop()
--gui_func()

-- TODO: implement autocrafting, also in items.json to disable autocrafting
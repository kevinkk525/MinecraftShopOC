---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Kevin.
--- DateTime: 05.12.2019 17:56
---

local component  = require("component")
local config     = require("shop.config")
local accounts   = require("shop.accounts")
local log        = require("shop.logging")

local me_storage = component.proxy(config.address_me_storage)
local me_cell    = component.proxy(config.address_me_chest)
local db         = component.database
local drive      = component.proxy(config.address_disk_drive)

---
local backend    = {}
---


-------

function backend.checkCellSpace(size)
    -- currently not used anywhere since always using new cells instead of what the user inserts
    local amount_stored = 0
    local items         = me_cell.getItemsInNetwork()
    if items.n >= 27 then
        log.debug("Not enough space in cell, too many item types")
        return false
    end
    for _, item in pairs(items) do
        if _ ~= "n" then
            amount_stored = amount_stored + item.size
        end
    end
    if amount_stored + size > config.maxSize_portableCell then
        log.debug("Not enough space in cell, too many items stored")
        return false
    end
    return true
end

function backend.sortInputChest(buyer)
    local transposer           = component.proxy(config.address_transposer_input)
    local found                = false
    local actions              = "User " .. buyer.name .. " returned/inserted items:"
    local items                = transposer.getAllStacks(config.side_vacuum_input).getAll()
    local success, addr, value = accounts.loadMoneyFromDisk(buyer, true)
    if not success then
        -- drive is just empty as it should be
    else
        -- if shop previously ran into an error, a disk could be stuck in the drive
        found   = true
        actions = actions .. "\nAdded money disk " .. addr .. " worth " .. tostring(value) .. "$"
    end
    for i, item in pairs(items) do
        if config.getItemIdentityName(item, { "label" }) == config.identity_floppy_disk then
            if transposer.transferItem(config.side_vacuum_input, config.side_floppy, 1, i) ~= 1.0 then
                log.error("Error moving Floppy disk")
            else
                success, addr, value = accounts.loadMoneyFromDisk(buyer)
                if not success then
                    log.error("Error loading Money from disk, returning Floppy")
                    backend.returnFloppyDisk()
                else
                    found   = true
                    actions = actions .. "\nAdded money disk " .. addr .. " worth $" .. tostring(value)
                end
            end
        elseif config.getItemIdentityName(item) == config.identity_portable_cell then
            if accounts.hasPortableCellLeaseOpen(buyer) then
                local io_stacks = {}
                while true do
                    local empty = true
                    io_stacks   = transposer.getAllStacks(config.side_ioport_input).getAll()
                    for _, it in pairs(io_stacks) do
                        if config.getItemIdentityName(it) == config.identity_portable_cell then
                            empty = false
                            break
                        end
                    end
                    if empty then
                        break
                    else
                        os.sleep(0.1)
                    end
                end
                if transposer.transferItem(config.side_vacuum_input, config.side_ioport_input, 1, i) ~= 1.0 then
                    log.error("Error moving Storage cell into ioport")
                else
                    accounts.returnedPortableCellLease(buyer)
                    actions = actions .. "\nReturned portable storage cell for " .. tostring(config.price_lease_storage_cell) .. "$"
                    found   = true
                end
            else
                log.debug("no open cell leases for " .. buyer.name)
                actions = actions .. "\nNo open lease, returned Portable Cell to the buyer"
                if transposer.transferItem(config.side_vacuum_input, config.side_dropper_input, 1, i) ~= 1.0 then
                    log.error("Error moving Storage cell into dropper")
                end
                found = true
            end
        elseif config.getItemIdentityName(item) == config.identity_empty or item.name == "minecraft:air" then
            -- empty slot
        else
            log.debug("Found unused item " .. config.getItemIdentityName(item))
            transposer.transferItem(config.side_vacuum_input, config.side_dropper_input, item.size, i)
            -- actually no items should be in the system except floppy and portable cells if
            -- vacuum chest has proper filter
        end
    end
    return found, actions
end

function backend.returnFloppyDisk()
    local transposer = component.proxy(config.address_transposer_input)
    if drive.isEmpty() then
        log.debug("Drive empty, nothing to return")
        return true
    end
    if transposer.transferItem(config.side_floppy, config.side_dropper_input, 1, 1) ~= 1.0 then
        log.error("Can't move floppy to dropper")
        return false
    end
    return true
end

function backend.emptyRemainingInput()
    local transposer = component.proxy(config.address_transposer_input)
    local items      = transposer.getAllStacks(config.side_vacuum_input).getAll()
    for i, item in pairs(items) do
        transposer.transferItem(config.side_vacuum_input, config.side_dropper_input, item.size, i)
    end
end

local function ejectCell()
    local transposer_chest = component.proxy(config.address_transposer_me_chest)
    local items            = transposer_chest.getAllStacks(config.side_transposer_me_chest).getAll()
    local ident            = config.getItemIdentityName(items[1])
    if ident == config.identity_portable_cell or ident == config.identity_flushing_cell then
        if transposer_chest.transferItem(config.side_transposer_me_chest, config.side_transposer_me_chest_output, 1, 1) ~= 1.0 then
            log.error("Can't move Cell from ME chest to output")
            return false
        end
        log.debug("Removing cell successful")
        return true
    elseif ident == config.identity_empty then
        log.debug("ME_chest empty, can't eject Cell")
        return true
    else
        log.error("Unknown item in ME chest slot: " .. ident)
        return false
    end
    return true
end

function backend.ejectPortableCell()
    --[[
    if ejectCell() then
        backend.flush()
    end
    return true
    --]]
    return ejectCell()
end

--[[
local function checkFlushingDiskExists()
    local transposer_flushing = component.proxy(config.address_transposer_flushing)
    local items               = transposer_flushing.getAllStacks(config.side_chest_flushing).getAll()
    for i, item in pairs(items) do
        if config.getItemIdentityName(item) == config.identity_flushing_cell then
            return true
        end
    end
    return false
end

function backend.flush()
    local transposer_flushing = component.proxy(config.address_transposer_flushing)
    local transposer_chest    = component.proxy(config.address_transposer_me_chest)
    if checkFlushingDiskExists() == false then
        log.error("No flushing Disk available")
        return false
    end
    if transposer_flushing.transferItem(config.side_chest_flushing, config.side_mechest_flushing, 1, 1) ~= 1.0 then
        log.error("Unable to insert flushing Disk into chest")
        return false
    end
    local arrived = false
    local i       = 0
    while not arrived and i < 10 do
        local items = transposer_chest.getAllStacks(config.side_transposer_me_chest_input).getAll()
        local ident = config.getItemIdentityName(items[1])
        if ident == config.identity_flushing_cell then
            log.debug("Flushing cell arrived")
            arrived = true
            break
        elseif ident ~= config.identity_empty then
            log.error("Unknown item in ME chest slot: " .. ident)
        end
        os.sleep(0.2)
        i = i + 1
    end
    if not arrived then
        log.error("Flushing disk never arrived in input chest")
        return false
    end
    if transposer_chest.transferItem(config.side_transposer_me_chest_input, config.side_transposer_me_chest, 1, 1) ~= 1.0 then
        log.error("Couldn't move flushing disk into me chest")
        return false
    end
    os.sleep(1) -- TODO: check if flushed? currently always flushing although only needed after mass export
    ejectCell()
    for _ = 1, 20 do
        if checkFlushingDiskExists() then
            return true
        end
        os.sleep(0.2)
    end
    log.error("Flushing disk didn't return")
    return false
end
--]]

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

function backend.storeItemInDB(item)
    local item_copy = getStandardItemNBT(item)
    db.clear(1)
    me_storage.store(item_copy, db.address, 1, 1)
    return true
end

function backend.exportToDropper(item, size, progress_func)
    backend.storeItemInDB(item)
    local export             = component.proxy(config.address_export_single_dropper)
    local amount_transferred = 0
    if export.setExportConfiguration(config.side_export_dropper, 1, db.address, 1) ~= true then
        log.error("Error configuring dropper export bus")
        return false, 0
    end
    local amount, error
    for _ = 1, size do
        amount, error = export.exportIntoSlot(config.side_export_dropper)
        if amount == nil then
            log.error("Error exporting to dropper", error)
            return false, amount_transferred
        end
        amount_transferred = amount_transferred + amount
        if progress_func then
            progress_func(amount_transferred, size)
        end
    end
    return true, amount_transferred
end

function backend.exportPortableCell()
    local transposer_chest = component.proxy(config.address_transposer_me_chest)
    backend.storeItemInDB(config.nbt_portable_cell)
    local export = component.proxy(config.address_export_portable_cell)
    if export.setExportConfiguration(config.side_export_portable_cell, 1, db.address, 1) ~= true then
        log.error("Error configuring portable cell export bus")
        return false, 0
    end
    local items = transposer_chest.getAllStacks(config.side_transposer_me_chest_input).getAll()
    local ident = config.getItemIdentityName(items[1])
    if ident ~= config.identity_portable_cell then
        local amount, error = export.exportIntoSlot(config.side_export_portable_cell)
        if amount == nil then
            log.error("Error exporting portable cell", error)
            return false, 0
        end
    end
    if transposer_chest.transferItem(config.side_transposer_me_chest_input, config.side_transposer_me_chest, 1, 1) ~= 1.0 then
        log.error("Error moving portable cell to me chest")
        return false, 0
    end
    return true, 1
end

function backend.getAmountAvailable(nbt)
    local item = me_storage.getItemsInNetwork(nbt)
    if item.n >= 1 then
        if item.n > 1 then
            local ident = config.getItemIdentityName(nbt)
            item.n      = nil
            for i, it in pairs(item) do
                if config.getItemIdentityName(it) == ident then
                    --log.debug("Found multiple entries in me for " .. ident .. ", chose according to ident equality")
                    return it.size
                end
            end
            log.error("Found multiple entries in me for " .. config.getItemIdentityName(nbt) .. ", but found no ident match. Preventing crafting.")
            return math.huge
        end
        return item[1].size
    end
    return 0
end

function backend.getAmountItemsInNetwork()
    local items = me_storage.getItemsInNetwork()
    return items.n
end

function backend.exportIntoChest(item, size, progress_func)
    -- return: success, #items already exported
    backend.storeItemInDB(item)
    if progress_func then
        progress_func(0, size)
    end
    -- Mass export using redstone signal is disabled although a bit faster over with 2k items but
    -- code and setup are a lot easier without it as it would need flushing too.
    --[[
    if size >= config.maxSize_portableCell then
        local export = component.proxy(config.address_export_stack)
        if export.setExportConfiguration(config.side_export_stack, 1, db.address, 1) ~= true then
            log.error("Error configuring export bus stack for mass export")
            return false, 0
        end
        local redstone = component.proxy(config.address_redstone_export)
        redstone.setOutput(config.side_export_redstone, 255)
        local items
        local item_copy = getStandardItemNBT(item)
        for i = 1, config.timeout_export do
            items = me_cell.getItemsInNetwork(item_copy)[1]
            if items ~= nil then
                if items.size >= config.maxSize_portableCell then
                    redstone.setOutput(config.side_export_redstone, 0)
                    if progress_func then
                        progress_func(items.size, size)
                    end
                    return true, size
                elseif i == config.timeout_export then
                    log.error("Error mass exporting, only " .. tostring(items.size) .. " items exported")
                    redstone.setOutput(config.side_export_redstone, 0)
                    return false, items.size
                end
                if progress_func then
                    progress_func(items.size, size)
                end
            elseif i == config.timeout_export then
                log.error("Error mass exporting, no items exported")
                redstone.setOutput(config.side_export_redstone, 0)
                return false, 0
            end
            os.sleep(1)
        end
        log.critical("Should never go here")
    end
    --]]
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
                    log.error("Error exporting " .. ex.descr, error)
                    return false, amount_transferred
                end
                amount_transferred = amount_transferred + amount
                if progress_func then
                    progress_func(amount_transferred, size)
                end
            end
        end
        os.sleep(0.1)
    end
    return true, amount_transferred
end

return backend
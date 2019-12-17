---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Kevin.
--- DateTime: 05.12.2019 20:59
---

local component   = require("component")
local config      = require("shop.config")
local drive       = component.proxy(config.address_disk_drive)
local transposer  = component.proxy(config.address_transposer_drive)
local fs          = require("filesystem")
local json        = require("json")
local log         = require("shop.logging")
local fs          = require("filesystem")

local accs        = {}
local money_disks = {}

if fs.exists(config.path_money_disks) then
    local f     = io.open(config.path_money_disks, "r")
    money_disks = json.decode(f:read("*a"))
    f:close()
end

local function newBuyer(name)
    local buyer                 = {}
    buyer.name                  = name
    buyer.money                 = config.buyer_start_money
    buyer.amount_leased_cells   = 0 -- lease amount
    buyer.value_of_leased_cells = 0 -- lease value
    return buyer
end
local current_buyer = newBuyer("")


---------


function accs.getMoneyDiskValue(addr)
    return money_disks[addr]
end

function accs.removeMoneyDiskFromTable(addr)
    log.transaction("Removed money disk " .. addr .. " with value " .. tostring(accs.getMoneyDiskValue(addr)))
    money_disks[addr] = nil
    accs.saveMoneyDiskTable()
end

function accs.addMoneyDiskToTable(addr, value)
    log.transaction("Added money disk " .. addr .. " with value " .. tostring(value))
    money_disks[addr] = value
    accs.saveMoneyDiskTable()
end

function accs.createMoneyDisk(value)
    local drive = component.proxy(config.address_disk_drive_money)
    if drive.isEmpty() then
        log.error("Can't create money disk, drive empty")
        return false
    end
    local disk = component.proxy(drive.media())
    if disk.setLabel(tostring(value) .. "$ " .. config.shop_name) ~= tostring(value) .. "$ " .. config.shop_name then
        log.error("Couldn't set label of floppy")
    end
    if disk.getLabel() ~= tostring(value) .. "$ " .. config.shop_name then
        log.error("Couldn't read label of floppy")
    end
    accs.addMoneyDiskToTable(drive.media(), value)
    os.sleep(1)
    return true
end

function accs.saveMoneyDiskTable()
    local f = io.open(config.path_money_disks, "w")
    f:write(json.encode(money_disks))
    f:close()
end

function accs.loadMoneyFromDisk(buyer)
    if drive.isEmpty() then
        log.error("Drive is empty, can't load")
        return false
    end
    local addr  = drive.media()
    local disk  = component.proxy(addr)
    local value = accs.getMoneyDiskValue(addr)
    log.debug("Got drive addr" .. addr .. " with label " .. tostring(disk.getLabel()) .. " and value " .. tostring(value))
    if value then
        log.transaction("Adding " .. tostring(value) .. " to account of " .. buyer.name .. " from disk " .. addr)
        accs.addMoneyToBuyer(buyer, value)
        accs.removeMoneyDiskFromTable(addr)
    end
    if transposer.transferItem(config.side_drive_transposer_eject, config.side_drive_chest_eject, 1, 1) ~= 1.0 then
        log.error("Couldn't eject Floppy Disk")
    end
    return true, addr, value
end

function accs.getMoneyDisksDict()
    return money_disks
end

------

function accs.addMoneyToBuyer(buyer, amount)
    buyer.money = buyer.money + amount
    accs.saveBuyer(buyer)
end

function accs.removeMoneyFromBuyer(buyer, amount)
    buyer.money = buyer.money - amount
    accs.saveBuyer(buyer)
end

function accs.returnedPortableCellLease(buyer)
    log.transaction(buyer.name .. " returned a portable cell for " .. config.price_lease_storage_cell .. "$")
    buyer.amount_leased_cells   = buyer.amount_leased_cells - 1
    buyer.value_of_leased_cells = buyer.amount_leased_cells * config.price_lease_storage_cell
    buyer.money                 = buyer.money + config.price_lease_storage_cell
    accs.saveBuyer(buyer)
end

function accs.refundedLeasedCells(buyer, amount)
    buyer.amount_leased_cells   = buyer.amount_leased_cells - amount
    buyer.value_of_leased_cells = buyer.amount_leased_cells * config.price_lease_storage_cell
    -- refund happens outside, therefore no money movements in here
    accs.saveBuyer(buyer)
end

function accs.hasPortableCellLeaseOpen(buyer)
    return buyer.amount_leased_cells > 0
end

function accs.leaseCells(buyer, amount)
    buyer.amount_leased_cells   = buyer.amount_leased_cells + amount
    buyer.value_of_leased_cells = buyer.amount_leased_cells * config.price_lease_storage_cell
    accs.saveBuyer(buyer)
end

function accs.saveBuyer(buyer)
    local st = json.encode(buyer)
    local f  = io.open(config.path_accounts .. buyer.name, "w")
    f:write(st)
    f:close()
end

function accs.getBuyer(name)
    local f
    local buyer
    if current_buyer.name == name then
        return current_buyer
    end
    if fs.exists(config.path_accounts .. name) then
        f     = io.open(config.path_accounts .. name, "r")
        buyer = f:read("*a")
        f:close()
        buyer = json.decode(buyer)
    else
        f     = io.open(config.path_accounts .. name, "w")
        buyer = newBuyer(name)
        f:write(json.encode(buyer))
        f:close()
        log.info("Created new buyer " .. name)
    end
    current_buyer = buyer
    return buyer
end

function accs.displayBuyerInformation(name, textBox, application)
    buyer            = accs.getBuyer(name)
    textBox.lines    = {}
    textBox.lines[1] = { text = buyer.name, color = 0x0049BF }
    for key, value in pairs(buyer) do
        if key ~= "name" then
            textBox.lines[#textBox.lines + 1] = key .. ": " .. value
        end
    end
    application:draw()
end

if not fs.exists(config.path_accounts) then
    if not fs.makeDirectory(config.path_accounts) then
        log.critical("Error creating accounts directory")
    end
end

return accs

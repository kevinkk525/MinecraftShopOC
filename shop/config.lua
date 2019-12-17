---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Kevin.
--- DateTime: 05.12.2019 17:57
---

local sides  = require("sides")
local json   = require("json")
local config = {}

------- helper functions
function config.getItemIdentityName(item, blacklist)
    -- still has problems with some IC2 items that suddenly have hasTag=false after crafting
    -- but are supposed to have hasTag=True before crafting..
    -- affected: "ic2:lapotron_crystal", "ic2:advanced_re_battery","ic2:re_battery", etc
    local name = ""
    local keys = {}
    if blacklist == nil then
        blacklist = {}
    end
    for key, value in pairs(item) do
        if key ~= "label" and key ~= "name" and key ~= "size" then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    table.insert(keys, 1, "label")
    table.insert(keys, 2, "name")
    for i, k in pairs(blacklist) do
        table.remove(keys, i)
    end
    for _, key in pairs(keys) do
        local it = item[key]
        if type(it) == "number" then
            it = it + .0 -- to enforce float representation on all numbers
        end
        it   = tostring(it)
        name = name .. it .. ";"
    end
    return name
end

local function calculateCellsNeeded(trans)
    local cells             = 0
    local cell_slots_used   = config.maxSlots_portableCell
    local cell_items_stored = config.maxSize_portableCell
    table.sort(trans.item_pairs, function(a, b) return a.size > b.size end)
    for i, item in pairs(trans.item_pairs) do
        if item.size == config.maxSize_portableCell then
            cells = cells + 1
        else
            if cell_items_stored + item.size > config.maxSize_portableCell then
                cells             = cells + 1
                cell_slots_used   = 1
                cell_items_stored = item.size
            else
                cell_slots_used   = cell_slots_used + 1
                cell_items_stored = cell_items_stored + item.size
                if cell_slots_used >= config.maxSlots_portableCell then
                    cells             = cells + 1
                    cell_slots_used   = 0
                    cell_items_stored = 0
                end
            end
        end
    end
    trans.leased_cells      = cells
    trans.lease_value       = cells * config.price_lease_storage_cell
    trans.transaction_value = trans.item_value + trans.lease_value
end

function config.newTransaction()
    local trans             = {}
    trans.amount_items      = 0
    trans.item_value        = 0
    trans.lease_value       = 0
    trans.leased_cells      = 0
    trans.transaction_value = 0
    trans.item_pairs        = {}
    trans.buyer             = nil
    trans.addItem           = function(ident, item, size, price)
        local found = false
        for i, item in pairs(trans.item_pairs) do
            if item.ident == ident and item.size + size <= config.maxSize_portableCell then
                item.size  = item.size + size
                item.price = item.price + price
                found      = true
                break
            end
        end
        if not found then
            trans.item_pairs[#trans.item_pairs + 1] = { ["ident"] = ident, ["item"] = item, ["size"] = size, ["price"] = price }
        end
        trans.amount_items = trans.amount_items + size
        trans.item_value   = trans.item_value + price
        calculateCellsNeeded(trans)
    end
    trans.removeItem        = function(ident, size)
        for i, item in pairs(trans.item_pairs) do
            if item.ident == ident and item.size == size then
                trans.amount_items = trans.amount_items - size
                trans.item_value   = trans.item_value - item.price
                calculateCellsNeeded(trans)
                table.remove(trans.item_pairs, i)
                return true
            end
        end
        print("Item doesn't exist", ident, size)
        return false
    end
    trans.toJson            = function()
        local list      = {}
        local blacklist = { addItem    = true, removeItem = true, toJson = true,
                            item_pairs = true, getAmountOfItem = true }
        for key, value in pairs(trans) do
            if not blacklist[key] then
                list[key] = value
            end
        end
        list["item_pairs"] = {}
        for i, item in pairs(trans.item_pairs) do
            list.item_pairs[#list.item_pairs + 1] = { ["ident"] = item.ident, ["size"] = item.size, ["price"] = item.price }
        end
        return json.encode(list)
    end
    trans.getAmountOfItem   = function(ident)
        local amount = 0
        for i, item in pairs(trans.item_pairs) do
            if item.ident == ident then
                amount = amount + item.size
            end
        end
        return amount
    end
    return trans
end

-- ME controller Item storage
config.address_me_storage              = "6ffbe891-07b7-4516-ab54-857b267cbe60"
-- ME controller for ME Chest
config.address_me_chest                = "9fd21c13-4d1b-42d8-9c25-06c357868558"
-- ME controller Money
config.address_me_money                = "22f7f7a0-e848-40d6-a662-9cb2141aa083"
-- ME exportbus chest
config.address_export_stack            = "b4caa6ca-0fc1-41bd-98f4-cc99c3621a02"
config.side_export_stack               = sides.west
config.address_export_half             = "d31ef119-48ec-4e49-a5bc-8168aa71fbe2"
config.side_export_half                = sides.east
config.address_export_single           = "f5f40931-ab84-467a-bd3f-201529d3b181"
config.side_export_single              = sides.up
-- ME exportbus single item
config.address_export_single_dropper   = "b7492057-30f0-489b-aff4-3a789786eb5f"
config.side_export_dropper             = sides.west
-- ME exportbus portable cell
config.address_export_portable_cell    = "3eccea41-6dc1-4a0b-bfe0-6a95af472093"
config.side_export_portable_cell       = sides.east

-- Redstone block export bus
config.address_redstone_export         = "2034c414-14a8-4acb-9040-6ed55f7f6db6"
config.side_export_redstone            = sides.north
-- Redstone block vacuum chest
config.address_redstone_vacuum_chest   = "de3545bb-c12e-4341-beee-01568f24df3e"
config.side_redstone_vacuum_chest      = sides.south

-- Transposer
config.address_transposer              = "0e07e3ae-1ecf-4c87-85a9-cabfd1742f09"
config.side_chest_cell_input           = sides.up -- not used for user input anymore
config.side_floppy                     = sides.north
config.side_vacuum_input               = sides.west
config.side_dropper_transposer         = sides.east
config.side_ioport_input               = sides.down

-- Transposer for system flushing (remainder of export to 4k)
config.address_transposer_flushing     = "58ff08c5-eb2a-4f66-911e-e4d1bc35cf7d"
config.side_chest_flushing             = sides.up
config.side_ioport_flushing            = sides.east
config.side_mechest_flushing           = sides.down

-- Transposer ME Chest export
config.address_transposer_me_chest     = "8415091f-ca1a-4ab6-908d-c0ab643cadbd"
config.side_transposer_me_chest        = sides.north
config.side_transposer_me_chest_input  = sides.south
config.side_transposer_me_chest_output = sides.up

-- Transposer Disk Drive
config.address_transposer_drive        = "89504ea6-f8a7-4a0c-92c3-ce92cb52566c"
config.side_drive_transposer_eject     = sides.up
config.side_drive_chest_eject          = sides.west

-- Transposer Money Disk Drive
config.address_transposer_money_drive  = "2296cb15-7497-47c8-895f-77eaba721594"
config.side_money_drive                = sides.down
config.side_money_disk_input           = sides.up


-- Disk Drive input for money
config.address_disk_drive              = "e955d3da-8190-4d2c-92e8-563d37e11793"

-- Disk Drive creating money
config.address_disk_drive_money        = "6ce0fd56-5956-4439-8691-755b8d2893f4"

-- Identity configurations
config.identity_blacklist              = { ["isCraftable"] = true, ["size"] = true,
                                           ["amounts"]     = true, ["label_friendly"] = true,
                                           ["categories"]  = true }
config.identity_empty                  = "Air;minecraft:air;0.0;false;0.0;64.0;"
config.identity_portable_cell          = "Portable Cell;appliedenergistics2:portable_cell;0.0;true;32.0;1.0;"
config.nbt_portable_cell               = {
    ["maxDamage"] = 32, ["name"] = "appliedenergistics2:portable_cell", ["damage"] = 0,
    ["label"]     = "Portable Cell", ["maxSize"] = 1, ["hasTag"] = true }
config.identity_floppy_disk            = "opencomputers:storage;1.0;true;0.0;64.0;"
config.identity_flushing_cell          = "1k ME Storage Cell;appliedenergistics2:storage_cell_1k;0.0;true;0.0;1.0;"

--
config.maxSize_portableCell            = 4032
config.maxSlots_portableCell           = 63
config.maxSlots_money_storage          = 63 * 2

-- Timeouts
config.timeout_buyer                   = 30 -- timeout for keeping buyer valid, might have left or new buyer not recognized
config.timeout_export                  = 60
config.price_lease_storage_cell        = 10


--
config.path_file_items                 = "/home/shop/items.json"
config.path_accounts                   = "/mnt/59b/accounts/"
config.path_money_disks                = "/mnt/59b/money_disks.json"
config.path_logfile                    = "/mnt/59b/shop.log"
config.path_logfile_transactions       = "/mnt/59b/transactions.log"
config.log_lines_textbox               = 500
config.max_filesize_log                = 4 * 1024 * 1024 --4 MB
config.buyer_start_money               = 1000
config.owner                           = "kevinkk525"
config.shop_name                       = "KK's Shop"


-- Notes ingame:
-- GriefPrevention allows access to screen with:
-- /cf interact-block-secondary opencomputers:screen3 true
-- not sure about primary, didn't work with that (only) but secondary alone works:
-- /cf interact-block-primary opencomputers:screen3 true
-- shift clicking works without screen access
-- make a subclaim for these permissions with /claimsubdivide and /cuboidclaims so
-- other screens are not accessible
-- except for with shift click, so be careful with GUIs on other screens

-- install GUI library from: pastebin run ryhyXUKZ
-- OpenOS updater: pastebin run -f icKy25PF

return config
---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Kevin.
--- DateTime: 22.12.2019 18:02
---

local sides                        = require("sides")
local json                         = require("json")
local shopconfig                   = require("shop.config")
local config                       = {}

------- helper functions
config.getItemIdentityName         = shopconfig.getItemIdentityName
config.calculateExportActivations  = shopconfig.calculateExportActivations


-- ME controller Item storage
config.address_me_storage          = "8bbf3451-d03e-4e85-ad4c-b3155ff0fae5"
-- ME exportbus chest
config.address_export_stack        = "0b526c21-3110-43ab-8098-a65e4ca576e0"
config.side_export_stack           = sides.west
config.address_export_half         = "e53565f5-5401-4b4a-982c-1dd8c22f5fe2"
config.side_export_half            = sides.east
config.address_export_single       = "83e7fdeb-40a9-4175-ac86-43851ebacd49"
config.side_export_single          = sides.up

-- Transposer Transceiver
config.address_transposer          = "930947ae-a1f9-4cc2-9111-15f7bbbdc92b"
config.side_transposer_transceiver = sides.north

-- Identity configurations
config.identity_blacklist          = shopconfig.identity_blacklist
config.identity_empty              = shopconfig.identity_empty

-- Timeouts
config.timeout_export              = 60
config.crafting_timeout            = 300 -- 5 minutes, only for error message, no actions

--
config.path_logfile                = "/home/stock.log"
config.log_lines_textbox           = 500
config.max_filesize_log            = 1 * 1024 * 1024 --1 MB
config.owner                       = "kevinkk525"
config.shop_name                   = "KK's Stock Software"
config.version                     = "0.4Beta"
config.scanning_interval           = 120 -- 2 minutes
config.crafting_cpus_left          = 3
config.crafting_batch_size         = 32
config.time_sync_url               = shopconfig.time_sync_url
config.time_sync_interval          = shopconfig.time_sync_interval

-- install GUI library from: pastebin run EVWjkBxg
-- OpenOS updater: pastebin run -f icKy25PF

return config
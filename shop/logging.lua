---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Kevin.
--- DateTime: 08.12.2019 18:28
---

local os                   = require("os")
local config               = require("shop.config")
local fs                   = require("filesystem")

local logfile              = io.open(config.path_logfile, "a")
local logfile_transactions = io.open(config.path_logfile_transactions, "a")
local colors               = { debug = 0x4B4B4B, info = 0x1E1E1E, warn = 0x332440, error = 0x660000, critical = 0xCC0040 }

local log                  = {}
local textbox
local textbox_transactions

local function date()
    return os.date()
end

function log.setTextBox(text)
    textbox = text
end

function log.setTextBoxTransactinos(text)
    textbox_transactions = text
end

function log._log(level, message)
    logfile:write("[" .. date() .. "][" .. level .. "] " .. message .. "\n")
    if textbox then
        textbox.lines[#textbox.lines + 1] = { text = "[" .. date() .. "][" .. level .. "] " .. message, color = colors[level] }
        if #textbox.lines > config.log_lines_textbox then
            table.remove(textbox.lines, 1)
        end
        textbox:scrollToEnd()
    end
    if fs.size(config.path_logfile) > config.max_filesize_log then
        print("Logfile is too big! Please notify admin")
    end
end

function log.debug(message)
    log._log("debug", message)
end

function log.info(message)
    log._log("info", message)
end

function log.warn(message)
    log._log("warn", message)
end

function log.error(message)
    log._log("error", message)
end

function log.critical(message)
    log._log("critical", message)
end

function log.transaction(message)
    logfile_transactions:write("[" .. date() .. "] " .. message .. "\n")
    if textbox_transactions then
        textbox_transactions.lines[#textbox_transactions.lines + 1] = "[" .. date() .. "] " .. message
        if #textbox_transactions.lines > config.log_lines_textbox then
            table.remove(textbox_transactions.lines, 1)
        end
        textbox_transactions:scrollToEnd()
    end
    log.info(message)
    if fs.size(config.path_logfile_transactions) > config.max_filesize_log then
        print("Logfile is too big! Please notify admin")
    end
end

return log
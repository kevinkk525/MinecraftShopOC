---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Kevin.
--- DateTime: 08.12.2019 18:28
---

local os                = require("os")
local fs                = require("filesystem")
local time

local logfile
local logfile_transactions
local log_lines_textbox = 1
local path_logfile
local path_logfile_transactions
local max_filesize_log

local colors            = { debug = 0x4B4B4B, info = 0x1E1E1E, warn = 0x332440, error = 0x660000, critical = 0xCC0040 }

local log               = {}
local textbox
local textbox_transactions

function log.init(path, path_transactions, lines_textbox, filesize_log, sync_time)
    path_logfile              = path
    path_logfile_transactions = path_transactions
    max_filesize_log          = filesize_log
    log_lines_textbox         = lines_textbox
    logfile                   = io.open(path_logfile, "a")
    if path_logfile_transactions ~= nil then
        logfile_transactions = io.open(path_logfile_transactions, "a")
        if logfile_transactions == nil then
            print("Error opening the logfile transactions!")
            return false
        end
    end
    if logfile == nil then
        print("Error opening the logfile!")
        return false
    end
    if sync_time then
        print("syncing time")
        time = require("time")
    else
        print("using local time")
    end
    return true
end

local function date()
    if time then
        return os.date("%y/%m/%d %H:%M:%S", time.time())
    else
        return os.date("%y/%m/%d %H:%M:%S")
    end
end

function log.setTextBox(text)
    textbox = text
end

function log.setTextBoxTransactions(text)
    textbox_transactions = text
end

function log._log(level, message)
    logfile:write("[" .. date() .. "][" .. level .. "] " .. message .. "\n")
    if textbox then
        textbox.lines[#textbox.lines + 1] = { text = "[" .. date() .. "][" .. level .. "] " .. message, color = colors[level] }
        if #textbox.lines > log_lines_textbox then
            table.remove(textbox.lines, 1)
        end
        textbox:scrollToEnd()
    end
    if fs.size(path_logfile) > max_filesize_log then
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
        if #textbox_transactions.lines > log_lines_textbox then
            table.remove(textbox_transactions.lines, 1)
        end
        textbox_transactions:scrollToEnd()
    end
    log.info(message)
    if fs.size(path_logfile_transactions) > max_filesize_log then
        print("Logfile is too big! Please notify admin")
    end
end

return log
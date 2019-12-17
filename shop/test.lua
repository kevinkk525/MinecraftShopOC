---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Kevin.
--- DateTime: 10.12.2019 12:40
---

local thread    = require("thread")
local component = require("component")
component.gpu.setResolution(160, 50)
local gui                    = require("shop.shopGUI")
local GUI                    = require("GUI")
local computer               = require("computer")
local json                   = require("json")
local config                 = require("shop.config")
local notice                 = require("shop.gui_notice")

local application            = gui.application
local panel                  = application:addChild(GUI.panel(1, 2, application.width, application.height, 0xFFFFFF, 0.5))
panel.hidden                 = true

gui.menu_exit.onTouch        = function(application, object, e2, e3, e4, e5, e6, user)
    if user == config.owner then
        should_terminate = true
        gui.application:stop()
        return
    end
    gui.on_alert = true
    GUI.alert("You are not authorized to terminate this program!")
    gui.on_alert = false
end

gui.menu_money_disks.onTouch = function()
    --panel.hidden = not panel.hidden
    --application:draw()
    GUI.notice(application, 10, "Testing new alert!\nWith lots of lines\napparently", "tough so..")
    GUI.notice(application, 5, "Testing new alert above!\nWith lots of lines\napparently", "tough so..")
end

gui.application:draw(true)
gui.application:start()
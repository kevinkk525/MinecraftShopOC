---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by Kevin.
--- DateTime: 24.11.2019 21:34
---

local dir_name = "shop"
local sub_dirs = {} --["mqtt"] = "/lib/"
local files    = {} -- [filename] = "/path/to/destination"

local shell    = require("shell")

local wd       = shell.getWorkingDirectory()
shell.setWorkingDirectory("/home/" .. dir_name)
shell.execute("mkdir /home/lib")
shell.execute("cp -r -f bin /home/")
shell.execute("cp -r -f lib /home/")
-- Custom subdirectories
for orig, target in pairs(sub_dirs) do
    shell.execute("cp -r -f " .. orig .. " " .. target)
end
-- Custom files
for orig, target in pairs(files) do
    shell.execute("cp " .. orig .. " " .. target)
end
shell.setWorkingDirectory(wd)
print("Installed/Updated " .. dir_name)


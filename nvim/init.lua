local function scandir(directory)
  local i, t, popen = 0, {}, io.popen
  local pfile = popen('ls -a "' .. directory .. '"')
  for filename in pfile:lines() do
    i = i + 1
    t[i] = filename
  end
  pfile:close()
  return t
end

require("settings")
require("keymaps")
require("plugins/packer")
-- Dynamicaly load plugin configuration
local plugin_dir = "/home/" .. os.getenv("USER") .. "/.config/nvim/lua/plugins"
for _, cfg in ipairs(scandir(plugin_dir)) do
  if not string.find(cfg, "init.lua") and not string.find(cfg, "packer.lua") then
    local plugin = cfg:gsub("[.]lua", ""):gsub("[.]", "")
    if plugin:len() > 0 then
      require("plugins/" .. plugin)
    end
  end
end

local theme = require("onedark")
theme.setup({ style = "cool" })
theme.load()

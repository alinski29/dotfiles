require('settings')
require('keymaps')

-- Load plugin configuration
require('plugins/packer')
-- local config_files = vim.fn.globpath('lua/plugins', '*.lua'):gmatch("([^\n]*)\n?")
-- for config_file in config_files do
--   print(config_file)
--   if not string.find(config_file, "init.lua") and not string.find(config_file, 'packer.lua') then
--     local file = config_file:gsub('lua/', ''):gsub("[.]lua", "")
--     if file:len() > 0 then require(file) end
--   end
-- end

local plugins = {'autopairs', 'bufferline', 'cmp', 'comment', 'lspconfig', 'lspkind', 'lualine', 'nvimtree', 'telescope', 'treesitter', 'toggleterm', 'metals'}
for _, plugin in ipairs(plugins) do
  --print("plugins/" .. plugin)
  require("plugins/" .. plugin)
end

require('onedark').setup {
  style = 'cool'
}
require('onedark').load()
-- require('rose-pine').set('dawn')

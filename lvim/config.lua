reload "user.options"
reload "user.keymaps"
reload "user.plugins"
reload "user.metals"
reload "user.telescope"
reload "user.lsp.lsp"

lvim.log.level = "warn"
lvim.lsp.diagnostics.float.focusable = true
lvim.builtin.terminal.active = true
lvim.builtin.breadcrumbs.active = true
lvim.builtin.dap.active = true
lvim.builtin.nvimtree.setup.renderer.group_empty = true
lvim.builtin.project.manual_mode = true
lvim.builtin.indentlines.active = false

lvim.colorscheme = "catppuccin"
require("catppuccin").setup({ flavour = "mocha", })

local dap_status_ok, dap = pcall(require, "dap")
if not dap_status_ok then
  return
end

dap.configurations.scala = {
  {
    type = "scala",
    request = "launch",
    name = "Run or Test Target",
    metals = {
      runType = "runOrTestFile",
    },
  },
  {
    type = "scala",
    request = "launch",
    name = "Test Target",
    metals = {
      runType = "testTarget",
    },
  },
}

return {
  "folke/snacks.nvim",
  opts = {
    explorer = {
      -- Keep Snacks Explorer enabled, but don't auto-open it on startup
      -- or when opening Neovim with a directory.
      replace_netrw = false,
    },
    picker = {
      sources = {
        files = {
          hidden = true,
          ignored = true,
        },
        grep = {
          hidden = true,
          ignored = true,
        },
        explorer = {
          hidden = true,
          ignored = true,
          layout = { preset = "right", preview = false },
          actions = {
            -- Yank paths relative to the explorer cwd
            explorer_yank_relpath = function(picker)
              local cwd = (picker:cwd() or vim.fn.getcwd()):gsub("/$", "")
              local files = {}
              if vim.fn.mode():find("^[vV]") then
                picker.list:select()
              end
              for _, item in ipairs(picker:selected({ fallback = true })) do
                local path = Snacks.picker.util.path(item)
                if path:sub(1, #cwd + 1) == cwd .. "/" then
                  path = path:sub(#cwd + 2)
                end
                files[#files + 1] = path
              end
              picker.list:set_selected()
              vim.fn.setreg(vim.v.register or "+", table.concat(files, "\n"), "l")
              Snacks.notify.info("Yanked " .. #files .. " files (relative)")
            end,
          },
          win = {
            list = {
              keys = {
                ["y"] = { "explorer_yank_relpath", mode = { "n", "x" } },
                ["Y"] = { "explorer_yank", mode = { "n", "x" } },
              },
            },
          },
        },
      },
    },
  },
}

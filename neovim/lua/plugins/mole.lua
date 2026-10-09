return {
  "zion-off/mole.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  opts = {
    -- fallback when no buffer file is open
    session_dir = "/tmp/mole-annotations",

    -- store session in .mole/ next to the annotated file
    -- session_name = function()
    --   local file = vim.api.nvim_buf_get_name(0)
    --   if file == "" then
    --     return nil -- use session_dir fallback
    --   end
    --   local dir = vim.fn.fnamemodify(file, ":p:h")  -- absolute dir
    --   local mole_dir = dir .. "/.mole"
    --   vim.fn.mkdir(mole_dir, "p")
    --   -- strip leading / so it's a safe path component under session_dir
    --   local safe = mole_dir:gsub("^/", "")
    --   return safe .. "/session"
    -- end,
    session_name = nil,

    -- "location" = file path + line range
    -- "snippet" = file path + line range + selected text in a fenced code block
    capture_mode = "snippet",

    -- open the side panel automatically when starting a session
    auto_open_panel = true,

    -- show vim.notify messages
    notify = true,

    -- show numbered gutter signs and EOL virtual text on annotated lines (opt-in)
    virtual_text = true,

    -- picker for resume: "auto" (telescope → snacks → vim.ui.select), "telescope", "snacks", or "select"
    picker = "snacks",

    -- keybindings
    keys = {
      annotate = "<leader>ma", -- visual mode
      start_session = "<leader>ms", -- normal mode
      stop_session = "<leader>mq", -- normal mode
      resume_session = "<leader>mr", -- normal mode
      toggle_window = "<leader>mw", -- normal mode
      jump_to_location = { "<CR>", "gd" }, -- in side panel
      next_annotation = "]a", -- in side panel
      prev_annotation = "[a", -- in side panel
    },

    -- side panel
    window = {
      width = 0.3, -- fraction of editor width
    },

    -- inline input popup
    input = {
      width = 50,
      border = "rounded",
      expand_key = "<C-e>", -- expand to a multiline floating buffer
    },

    -- callbacks that return lines written to the session file
    -- each receives an info table and must return a table of strings (lines)
    -- return {} to skip a section entirely
    format = {
      -- info: { title, file_path, cwd, timestamp }
      header = function(info)
        return {
          -- "# " .. info.title,
          -- "",
          -- "**File:** " .. info.file_path,
          -- "**Started:** " .. info.timestamp,
          -- "**Project:** " .. info.cwd, -- used to resolve file paths when jumping to locations from a different project
          -- "",
          "Here's my feedback. If clarifications are still needed, resolve them first with me before doing any modifications.",
          "",
          "---",
        }
      end,
      -- info: { timestamp }
      footer = function(info)
        return {
          -- "",
          -- "---",
          -- "",
          -- "**Ended:** " .. info.timestamp,
        }
      end,
      -- info: { timestamp }
      resumed = function(info)
        return {
          "",
          "---",
          "",
          "**Resumed:** " .. info.timestamp,
          "",
          "---",
          "",
        }
      end,
    },
  },
}

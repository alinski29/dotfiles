local actions = require("telescope.actions")
require("telescope").setup({
  defaults = {
    file_ignore_patterns = {
      "venv",
      "node_modules",
      "*/__pycache__/*",
      "*.pyc",
      "*.parquet",
      "**/*.parquet",
      "*.arrow",
      "**/*.arrow",
      "*/.vscode/*",
      "*/.idea/*",
    },
    prompt_prefix = "$ ",
    mappings = {
      n = {
        ["<C-h>"] = actions.select_horizontal,
      },
      i = {
        ["<C-h>"] = actions.select_horizontal,
      },
    },
  },
})

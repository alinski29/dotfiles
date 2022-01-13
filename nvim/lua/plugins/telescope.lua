require('telescope').setup{
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
    prompt_prefix = '$ '
  }
}

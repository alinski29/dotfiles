lvim.plugins = {
	{
		"catppuccin/nvim",
		name = "catappucin",
		priority = 1000,
		confing = function()
			require("catppuccin").setup({ flavour = "mocha" })
		end,
	},
	"rebelot/kanagawa.nvim",
	"lewis6991/gitsigns.nvim",
	"olexsmir/gopher.nvim",
	"AckslD/swenv.nvim",
	"stevearc/dressing.nvim",
	"nvim-tree/nvim-web-devicons",
	"nvim-treesitter/nvim-treesitter",
	"kdheepak/JuliaFormatter.vim",
	{
		"scalameta/nvim-metals",
		config = function()
			require("user.metals").config()
		end,
	},
}

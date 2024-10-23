lvim.plugins = {
	-- Themes
	{
		"catppuccin/nvim",
		name = "catappucin",
		priority = 1000,
		confing = function()
			require("catppuccin").setup({ flavour = "macchiato" })
		end,
	},
	"rebelot/kanagawa.nvim",
	{ "folke/tokyonight.nvim", lazy = false, priority = 1000, opts = {} },
	{ "EdenEast/nightfox.nvim", lazy = false, priority = 1000 },
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

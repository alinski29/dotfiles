local cmp = require'cmp'
local lspkind = require'lspkind'

local has_words_before = function()
  local line, col = unpack(vim.api.nvim_win_get_cursor(0))
  return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

cmp.setup({
	completion = {
		completeopt = "menu,menuone,noselect",
	},
	sources = {
		{ name = "nvim_lsp" },
		{ name = "nvim_lua", keyword_length = 5 },
		{ name = "treesitter", keyword_length = 5 },
		{ name = "luasnip" },
		{ name = "path" },
		{ name = "buffer", keyword_length = 5 },
	},
	formatting = {
		format = lspkind.cmp_format({
			with_text = false, -- do not show text alongside icons
			maxwidth = 50, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
			menu = {
				buffer = "[buff]",
				nvim_lsp = "[lsp]",
				nvim_lua = "[api]",
				treesitter = "[tree]",
				luasnip = "[snip]",
				path = "[path]",
			},
		}),
	},
	mapping = {
		["<Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_next_item()
			elseif has_words_before() then
				cmp.complete()
			else
				fallback()
			end
		end, { "i", "s" }),
		["<S-Tab>"] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			else
				fallback()
			end
		end, { "i", "s" }),
		-- Select suggestion using enter
		["<CR>"] = cmp.mapping({
			i = cmp.mapping.confirm({ select = true }),
			c = cmp.mapping.confirm({ select = false }),
		}),
		-- Close suggestions
		["<C-h>"] = cmp.mapping({
			i = cmp.mapping.abort(),
			c = cmp.mapping.close(),
		}),
		["<C-k>"] = cmp.mapping.select_prev_item(),
		["<C-j>"] = cmp.mapping.select_next_item(),
	},
	snippet = {
		expand = function(args)
			require("luasnip").lsp_expand(args.body)
		end,
	},
	experimental = {
		native_menu = false,
		ghost_text = true,
	},
})

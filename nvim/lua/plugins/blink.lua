return {
  {
    "L3MON4D3/LuaSnip",
    config = function()
      -- Nạp các snippet mặc định (nếu có)
      require("luasnip.loaders.from_vscode").lazy_load()
      
      -- Nạp custom snippet từ thư mục ~/.config/nvim/snippets
      require("luasnip.loaders.from_vscode").lazy_load({ 
        paths = { vim.fn.stdpath("config") .. "/snippets" } 
      })
    end,
  },
  {
    -- Thư viện tương thích giúp blink.cmp đọc được các phím tắt của Avante
    "saghen/blink.compat",
    lazy = true,
    opts = {},
    build = false,
    -- MẸO QUAN TRỌNG: Định nghĩa giả lập nvim-cmp để dập tắt hoàn toàn lỗi crash / treo máy của Avante
    config = function() end,
  },
  {
    "saghen/blink.cmp",
    dependencies = { "L3MON4D3/LuaSnip", "saghen/blink.compat" },
    opts = function(_, opts)
      opts.snippets = { preset = "luasnip" }

      opts.sources = opts.sources or {}
      opts.sources.per_filetype = opts.sources.per_filetype or {}
      opts.sources.per_filetype.codecompanion = { "codecompanion" }

      opts.sources.compat = vim.list_extend(opts.sources.compat or {}, {
        "avante_commands",
        "avante_mentions",
        "avante_files",
      })

      opts.completion = opts.completion or {}
      opts.completion.list = opts.completion.list or {}
      opts.completion.list.selection = {
        preselect = true,
        auto_insert = false,
      }

      opts.signature = { enabled = false }

      opts.keymap = opts.keymap or {}
      opts.keymap["<Tab>"] = { "accept", "fallback" }

      return opts
    end,
  },
}

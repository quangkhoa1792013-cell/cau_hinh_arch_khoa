return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size = function(term)
          if term.direction == "horizontal" then
            return 10
          elseif term.direction == "vertical" then
            return 65
          end
        end,
        open_mapping = [[<c-\>]],
        direction = "horizontal",
        persist_size = true,
        persist_mode = true,
        on_open = function(term)
          vim.cmd("startinsert!")
          vim.api.nvim_buf_set_keymap(term.bufnr, "t", "<C-n>", [[<C-\><C-n>]], { silent = true, noremap = true })
          vim.api.nvim_buf_set_keymap(term.bufnr, "n", "a", "<cmd>startinsert<CR>", { silent = true, noremap = true })
          vim.api.nvim_buf_set_keymap(term.bufnr, "t", "<C-S>", [[<C-\><C-n>:close<CR>]], { silent = true, noremap = true })
          vim.api.nvim_buf_set_keymap(term.bufnr, "n", "<C-S>", ":close<CR>", { silent = true, noremap = true })
          vim.api.nvim_buf_set_keymap(term.bufnr, "n", "<Tab>", "<cmd>lua _cycle_terminal(1)<CR>", { silent = true, noremap = true })
          vim.api.nvim_buf_set_keymap(term.bufnr, "n", "<S-Tab>", "<cmd>lua _cycle_terminal(-1)<CR>", { silent = true, noremap = true })
        end,
      })

      -- Terminal counter for creating new terminals
      vim.g.term_count = 0

      function _add_terminal()
        vim.g.term_count = vim.g.term_count + 1
        vim.cmd("ToggleTerm " .. vim.g.term_count)
      end

      function _cycle_terminal(dir)
        local terms = {}
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local buf = vim.api.nvim_win_get_buf(win)
          local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
          if bt == "terminal" then
            table.insert(terms, win)
          end
        end
        if #terms == 0 then
          return
        end
        local cur = vim.api.nvim_get_current_win()
        local idx = nil
        for i, w in ipairs(terms) do
          if w == cur then
            idx = i
            break
          end
        end
        if idx then
          local target = ((idx - 1 + dir) % #terms) + 1
          vim.api.nvim_set_current_win(terms[target])
        elseif #terms > 0 then
          vim.api.nvim_set_current_win(terms[1])
        end
      end

      function _toggle_terminal_panel()
        local has_term = false
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local buf = vim.api.nvim_win_get_buf(win)
          local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
          if bt == "terminal" then
            has_term = true
            break
          end
        end
        if has_term then
          vim.cmd("ToggleTerm")
        else
          _add_terminal()
        end
      end

      -- Keymaps
      vim.keymap.set("n", "<leader>tt", _toggle_terminal_panel, { desc = "Toggle Terminal" })
      vim.keymap.set("n", "<C-`>", _toggle_terminal_panel, { desc = "Toggle Terminal" })
      vim.keymap.set("n", "<C-S-a>", _add_terminal, { desc = "Add Terminal" })
      vim.keymap.set("n", "<leader>td", "<cmd>TermSelect<CR>", { desc = "Terminal Dropdown" })

      -- Tab context-aware: terminal = cycle, editor = buffer
      vim.keymap.set("n", "<Tab>", function()
        local buf = vim.api.nvim_get_current_buf()
        local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
        if bt == "terminal" then
          _cycle_terminal(1)
        else
          vim.cmd("bnext")
        end
      end, { desc = "Next buffer / Terminal" })

      vim.keymap.set("n", "<S-Tab>", function()
        local buf = vim.api.nvim_get_current_buf()
        local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })
        if bt == "terminal" then
          _cycle_terminal(-1)
        else
          vim.cmd("bprevious")
        end
      end, { desc = "Prev buffer / Terminal" })

      -- ==============================
      -- EXISTING STUFF (Agy + Opencode)
      -- ==============================

      local Terminal = require("toggleterm.terminal").Terminal

      local function get_dynamic_dir()
        local current_file = vim.api.nvim_buf_get_name(0)
        if current_file ~= "" and not current_file:match("toggleterm") and not current_file:match("neo%-tree") then
          return vim.fn.fnamemodify(current_file, ":p:h")
        else
          local ok, neotree_sources = pcall(require, "neo-tree.sources.manager")
          if ok then
            local state = neotree_sources.get_state("filesystem")
            if state and state.path then
              return state.path
            end
          end
          return vim.fn.getcwd()
        end
      end

      local agy_chat_float = Terminal:new({
        cmd = "agy chat",
        direction = "float",
        dir = "git_dir",
        float_opts = { border = "double" },
        on_open = function(term)
          vim.cmd("startinsert!")
          vim.api.nvim_buf_set_keymap(term.bufnr, "t", "<C-n>", [[<C-\><C-n>]], { silent = true, noremap = true })
          vim.api.nvim_buf_set_keymap(term.bufnr, "n", "a", "<cmd>startinsert<CR>", { silent = true, noremap = true })
        end,
      })

      local agy_chat_side = Terminal:new({
        cmd = "agy chat",
        direction = "vertical",
        dir = "git_dir",
        on_open = function(term)
          vim.cmd("startinsert!")
          vim.api.nvim_buf_set_keymap(term.bufnr, "t", "<C-n>", [[<C-\><C-n>]], { silent = true, noremap = true })
          vim.api.nvim_buf_set_keymap(term.bufnr, "n", "a", "<cmd>startinsert<CR>", { silent = true, noremap = true })
        end,
      })

      local opencode_terms = { float = nil, vertical = nil }

      local function clean_term_ref(key)
        opencode_terms[key] = nil
      end

      local function create_opencode_term(cmd, direction, on_close_cb)
        local target_dir = vim.fn.getcwd()
        local float_opts = direction == "float" and { border = "double" } or nil
        local term = Terminal:new({
          cmd = cmd,
          direction = direction,
          dir = target_dir,
          close_on_exit = false,
          persist_mode = true,
          float_opts = float_opts,
          on_open = function(t)
            vim.cmd("startinsert!")
            vim.api.nvim_buf_set_keymap(t.bufnr, "t", "<C-n>", [[<C-\><C-n>]], { silent = true, noremap = true })
            vim.api.nvim_buf_set_keymap(t.bufnr, "n", "a", "<cmd>startinsert<CR>", { silent = true, noremap = true })
          end,
          on_close = function()
            if on_close_cb then
              on_close_cb()
            end
          end,
        })
        return term
      end

      local function toggle_opencode(key, cmd, direction)
        if opencode_terms[key] then
          opencode_terms[key]:toggle()
        else
          opencode_terms[key] = create_opencode_term(cmd, direction, function()
            clean_term_ref(key)
          end)
          opencode_terms[key]:toggle()
        end
      end

      function _agy_chat_float_toggle()
        agy_chat_float.dir = get_dynamic_dir()
        agy_chat_float:toggle()
      end

      function _agy_chat_side_toggle()
        agy_chat_side.dir = get_dynamic_dir()
        agy_chat_side:toggle()
      end

      function _opencode_float_toggle()
        toggle_opencode("float", "opencode", "float")
      end

      function _opencode_side_toggle()
        toggle_opencode("vertical", "opencode", "vertical")
      end

      vim.keymap.set({ "n", "t" }, "<leader>ag", "<cmd>lua _agy_chat_float_toggle()<CR>", { desc = "Toggle Antigravity Floating Chat" })
      vim.keymap.set({ "n", "t" }, "<leader>as", "<cmd>lua _agy_chat_side_toggle()<CR>", { desc = "Toggle Antigravity Sidebar Chat" })
      vim.keymap.set("n", "<leader>og", function() _opencode_float_toggle() end, { desc = "OpenCode Floating Chat" })
      vim.keymap.set("n", "<leader>os", function() _opencode_side_toggle() end, { desc = "OpenCode Sidebar Chat" })
    end,
  },
}

--- window-groups.lua: Tabpage-based groups (VSCode-style) + Layout manager + Keymaps

-- Per-tabpage data stored in vim.t (tabpage-local)
--   vim.t.group_locked   : boolean
--   vim.t.neo_tree_win   : window ID
--   vim.t.editor_win     : window ID

local M = {}

local function setup_layout_for_tab()
  local cur_tab = vim.api.nvim_tabpage_get_number(0)

  -- Set up neo-tree (left sidebar)
  require("neo-tree.command").execute({
    dir = vim.fn.getcwd(),
    toggle = false,
    reveal = false,
  })

  -- Find the neo-tree window and editor window
  local wins = vim.api.nvim_tabpage_list_wins(0)
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
    if ft == "neo-tree" then
      vim.t[cur_tab] = vim.t[cur_tab] or {}
      vim.t[cur_tab].neo_tree_win = win
    else
      vim.t[cur_tab] = vim.t[cur_tab] or {}
      vim.t[cur_tab].editor_win = win
    end
  end

  -- Init locked state
  vim.t[cur_tab] = vim.t[cur_tab] or {}
  if vim.t[cur_tab].group_locked == nil then
    vim.t[cur_tab].group_locked = false
  end

  return vim.t[cur_tab].editor_win
end

local function get_editor_win()
  local cur_tab = vim.api.nvim_tabpage_get_number(0)
  if vim.t[cur_tab] and vim.t[cur_tab].editor_win then
    if vim.api.nvim_win_is_valid(vim.t[cur_tab].editor_win) then
      return vim.t[cur_tab].editor_win
    end
  end
  -- Fallback: find the first non-neo-tree window
  local wins = vim.api.nvim_tabpage_list_wins(0)
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
    if ft ~= "neo-tree" then
      vim.t[cur_tab] = vim.t[cur_tab] or {}
      vim.t[cur_tab].editor_win = win
      return win
    end
  end
  return vim.api.nvim_get_current_win()
end

local function is_terminal_buf(buf)
  local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
  return ft == "toggleterm" or vim.api.nvim_get_option_value("buftype", { buf = buf }) == "terminal"
end

--- Move current buffer to next tabpage (right group)
function _move_buffer_right()
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_tab = vim.fn.tabpagenr()
  local total_tabs = vim.fn.tabpagenr("$")

  if is_terminal_buf(cur_buf) then
    return
  end

  local new_tab_created = false
  local target_tab = cur_tab + 1
  if target_tab > total_tabs then
    vim.cmd("tabnew")
    setup_layout_for_tab()
    new_tab_created = true
  else
    vim.cmd("tabnext " .. target_tab)
  end

  -- Open buffer in target tab's editor window
  local target_win = get_editor_win()
  if target_win then
    vim.api.nvim_win_set_buf(target_win, cur_buf)
    vim.api.nvim_set_current_win(target_win)
  end

  -- Go back to old tab, replace buffer with scratch
  local old_tab = cur_tab
  vim.cmd("tabnext " .. old_tab)
  local cur_win = vim.api.nvim_get_current_win()
  local alt_buf = vim.fn.bufnr("#")
  if alt_buf <= 0 or alt_buf == cur_buf then
    alt_buf = vim.api.nvim_create_buf(true, false)
  end
  if vim.api.nvim_win_is_valid(cur_win) then
    vim.api.nvim_win_set_buf(cur_win, alt_buf)
  end

  vim.cmd("tabnext " .. target_tab)
end

--- Move current buffer to previous tabpage (left group)
function _move_buffer_left()
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_tab = vim.fn.tabpagenr()
  local total_tabs = vim.fn.tabpagenr("$")

  if is_terminal_buf(cur_buf) then
    return
  end

  local new_tab_at_front = false
  local target_tab = cur_tab - 1
  if target_tab < 1 then
    vim.cmd("0tabnew")
    setup_layout_for_tab()
    new_tab_at_front = true
    target_tab = vim.fn.tabpagenr()
  else
    vim.cmd("tabnext " .. target_tab)
  end

  local target_win = get_editor_win()
  if target_win then
    vim.api.nvim_win_set_buf(target_win, cur_buf)
    vim.api.nvim_set_current_win(target_win)
  end

  -- After 0tabnew, old tab shifted right by 1
  local old_tab = new_tab_at_front and (cur_tab + 1) or cur_tab
  vim.cmd("tabnext " .. old_tab)
  local cur_win = vim.api.nvim_get_current_win()
  local alt_buf = vim.fn.bufnr("#")
  if alt_buf <= 0 or alt_buf == cur_buf then
    alt_buf = vim.api.nvim_create_buf(true, false)
  end
  if vim.api.nvim_win_is_valid(cur_win) then
    vim.api.nvim_win_set_buf(cur_win, alt_buf)
  end

  vim.cmd("tabnext " .. target_tab)
end

--- Toggle lock for current group
function _toggle_group_lock()
  local cur_tab = vim.api.nvim_tabpage_get_number(0)
  vim.t[cur_tab] = vim.t[cur_tab] or {}
  vim.t[cur_tab].group_locked = not vim.t[cur_tab].group_locked
  local state = vim.t[cur_tab].group_locked and "LOCKED" or "unlocked"
  vim.notify("Group " .. cur_tab .. " " .. state, vim.log.levels.INFO)
end

--- Redirect buffers opened in locked groups
local function setup_lock_redirect()
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = vim.api.nvim_create_augroup("GroupLockRedirect", { clear = true }),
    desc = "Redirect new buffer in locked group",
    callback = function(args)
      local cur_tab = vim.api.nvim_tabpage_get_number(0)
      if not (vim.t[cur_tab] and vim.t[cur_tab].group_locked) then
        return
      end

      local buf = args.buf
      local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
      local bt = vim.api.nvim_get_option_value("buftype", { buf = buf })

      -- Skip special buffers
      if ft == "neo-tree" or ft == "toggleterm" or bt ~= "" then
        return
      end

      -- Skip if we're already handling a redirected buffer
      if vim.b._redirecting then
        return
      end

      -- Find unlocked tab
      local total_tabs = vim.fn.tabpagenr("$")
      for i = 1, total_tabs do
        if not (vim.t[i] and vim.t[i].group_locked) then
          vim.schedule(function()
            vim.cmd("tabnext " .. i)
            local editor_win = nil
            if vim.t[i] and vim.t[i].editor_win and vim.api.nvim_win_is_valid(vim.t[i].editor_win) then
              editor_win = vim.t[i].editor_win
            else
              local wins = vim.api.nvim_tabpage_list_wins(0)
              for _, win in ipairs(wins) do
                local bft = vim.api.nvim_get_option_value("filetype", { buf = vim.api.nvim_win_get_buf(win) })
                if bft ~= "neo-tree" then
                  editor_win = win
                  break
                end
              end
            end
            if editor_win then
              vim.b._redirecting = true
              vim.api.nvim_win_set_buf(editor_win, buf)
              vim.api.nvim_set_current_win(editor_win)
              vim.b._redirecting = nil
            end
          end)
          break
        end
      end
    end,
  })
end

--- Close buffer with Snacks.bufdelete (keep layout)
function _close_buffer()
  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
  if ft ~= "neo-tree" and ft ~= "toggleterm" then
    require("snacks").bufdelete(buf)
  end
end

--- Setup layout on startup
local function setup_on_startup()
  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("GroupLayoutInit", { clear = true }),
    desc = "Setup VSCode-like layout on startup",
    once = true,
    callback = function()
      -- Create the initial neo-tree + editor layout
      vim.schedule(function()
        local args = vim.fn.argv(0)
        local is_dir = false
        if args ~= "" then
          local stats = vim.uv.fs_stat(args)
          if stats and stats.type == "directory" then
            is_dir = true
          end
        end

        -- Open neo-tree and set up the layout
        require("neo-tree.command").execute({
          dir = is_dir and args or vim.fn.getcwd(),
          toggle = false,
          reveal = not is_dir,
          find = not is_dir,
        })

        local cur_tab = vim.api.nvim_tabpage_get_number(0)
        local wins = vim.api.nvim_tabpage_list_wins(0)
        for _, win in ipairs(wins) do
          local buf = vim.api.nvim_win_get_buf(win)
          local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
          vim.t[cur_tab] = vim.t[cur_tab] or {}
          if ft == "neo-tree" then
            vim.t[cur_tab].neo_tree_win = win
          elseif vim.t[cur_tab].editor_win == nil then
            vim.t[cur_tab].editor_win = win
          end
        end
        vim.t[cur_tab].group_locked = false
      end)
    end,
  })

  -- Setup layout for new tabpages
  vim.api.nvim_create_autocmd("TabNew", {
    group = vim.api.nvim_create_augroup("GroupLayoutNew", { clear = true }),
    desc = "Setup layout on new tabpage",
    callback = function()
      vim.schedule(function()
        local cur_tab = vim.api.nvim_tabpage_get_number(0)
        vim.t[cur_tab] = { group_locked = false, neo_tree_win = nil, editor_win = nil }

        -- Open neo-tree in new tab
        require("neo-tree.command").execute({
          dir = vim.fn.getcwd(),
          toggle = false,
          reveal = false,
        })

        -- Identify neo-tree and editor windows
        local wins = vim.api.nvim_tabpage_list_wins(0)
        for _, win in ipairs(wins) do
          local buf = vim.api.nvim_win_get_buf(win)
          local ft = vim.api.nvim_get_option_value("filetype", { buf = buf })
          if ft == "neo-tree" then
            vim.t[cur_tab].neo_tree_win = win
          elseif vim.t[cur_tab].editor_win == nil then
            vim.t[cur_tab].editor_win = win
          end
        end
      end)
    end,
  })
end

--- Setup global keymaps
local function setup_keymaps()
  -- ==== GROUP NAVIGATION ====
  -- Move buffer to right group
  vim.keymap.set("n", "<C-S-Right>", function()
    local buf = vim.api.nvim_get_current_buf()
    if not is_terminal_buf(buf) then
      _move_buffer_right()
    end
  end, { desc = "Move buffer to right group" })

  -- Move buffer to left group
  vim.keymap.set("n", "<C-S-Left>", function()
    local buf = vim.api.nvim_get_current_buf()
    if not is_terminal_buf(buf) then
      _move_buffer_left()
    end
  end, { desc = "Move buffer to left group" })

  -- Switch to next/prev group (tabpage)
  vim.keymap.set("n", "<C-Right>", function()
    if vim.fn.tabpagenr("$") > 1 then
      vim.cmd("tabnext")
    end
  end, { desc = "Next group" })

  vim.keymap.set("n", "<C-Left>", function()
    if vim.fn.tabpagenr("$") > 1 then
      vim.cmd("tabprevious")
    end
  end, { desc = "Prev group" })

  -- ==== GROUP LOCK ====
  vim.keymap.set("n", "<C-S-A-g>", _toggle_group_lock, { desc = "Toggle group lock" })

  -- ==== CLOSE BUFFER (keep layout) ====
  vim.keymap.set("n", "<leader>bd", _close_buffer, { desc = "Close buffer (keep layout)" })
  vim.keymap.set("n", "<leader>bc", _close_buffer, { desc = "Close buffer (keep layout)" })
end

--- Initialize
function M.setup()
  setup_on_startup()
  setup_lock_redirect()
  setup_keymaps()
end

M.setup()

return M

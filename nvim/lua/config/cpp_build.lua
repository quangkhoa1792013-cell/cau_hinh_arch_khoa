local M = {}

-- ==============================
-- MODE: "overlay" | "terminal"
-- overlay  = bang giua man hinh (hien tai)
-- terminal = terminal build roi terminal run
-- ==============================
local build_mode = "overlay"

-- ==============================
-- CLANG++ TURBO FLAGS
-- ==============================
local turbo_flags = "-g -O3 -march=native -Wall -Wextra -stdlib=libstdc++ -fuse-ld=lld"

-- ==============================
-- COMPILER DETECTION
-- ==============================
local config_path = vim.fn.stdpath("config") .. "/cpp_build_config.json"

local function detect_compilers()
  local candidates = { "g++", "clang++", "c++", "gcc", "clang" }
  local found = {}
  local seen = {}
  for _, name in ipairs(candidates) do
    if vim.fn.executable(name) == 1 then
      local path = vim.fn.exepath(name)
      if not seen[path] then
        seen[path] = true
        local version_handle = io.popen(path .. " --version 2>/dev/null | head -1")
        local version = ""
        if version_handle then
          version = version_handle:read("*l") or ""
          version_handle:close()
        end
        table.insert(found, { name = name, path = path, version = version })
      end
    end
  end
  return found
end

local function save_config(config)
  vim.fn.writefile({ vim.json.encode(config) }, config_path)
end

local function load_config()
  local ok, data = pcall(function()
    local lines = vim.fn.readfile(config_path)
    return vim.json.decode(table.concat(lines, "\n"))
  end)
  if ok and data then return data end
  return nil
end

function _choose_compiler()
  local compilers = detect_compilers()
  if #compilers == 0 then
    vim.notify("No C++ compiler found in $PATH!", vim.log.levels.ERROR)
    return
  end
  local items = {}
  for _, c in ipairs(compilers) do
    local v = c.version ~= "" and " (" .. c.version .. ")" or ""
    table.insert(items, c.name .. v)
  end
  vim.ui.select(items, {
    prompt = "Chọn C++ compiler mặc định:",
  }, function(choice, idx)
    if choice and idx then
      local config = {
        compiler_path = compilers[idx].path,
        compiler_name = compilers[idx].name,
        flags = { "-std=c++20", "-O3", "-march=native", "-Wall", "-Wextra", "-Wpedantic", "-Wshadow", "-Wcast-align", "-Wconversion", "-Wsign-conversion", "-g", "-fdiagnostics-color=always" },
        detected_at = os.time(),
      }
      save_config(config)
      vim.notify("Compiler set to: " .. compilers[idx].path, vim.log.levels.INFO)
    end
  end)
end

-- ==============================
-- LEGACY BUILD & RUN (keep)
-- ==============================
local build_term = nil
local run_terms = {}

function _build_and_run()
  vim.cmd("write")
  local file = vim.fn.expand("%")
  local file_path = vim.fn.expand("%:p")
  local file_dir = vim.fn.expand("%:p:h")
  local file_name = vim.fn.expand("%:t:r")
  local ext = vim.fn.expand("%:e")
  local cpp_exts = { cpp = true, cc = true, cxx = true, c = true, h = true, hpp = true }
  if not cpp_exts[ext] then
    vim.notify("Not a C/C++ file", vim.log.levels.WARN)
    return
  end
  local config = load_config()
  if not config then
    local compilers = detect_compilers()
    if #compilers == 0 then
      vim.notify("No C++ compiler found! Install g++ or clang++", vim.log.levels.ERROR)
      return
    end
    if #compilers == 1 then
      config = { compiler_path = compilers[1].path, compiler_name = compilers[1].name, flags = {}, detected_at = os.time() }
      save_config(config)
    else
      _choose_compiler()
      config = load_config()
      if not config then return end
    end
  end
  local compiler = config.compiler_path
  local output = file_dir .. "/" .. file_name
  local flag_str = table.concat(config.flags or {}, " ")
  local compile_cmd = string.format("%s %s %s -o %s", compiler, flag_str, file_path, output)
  local run_cmd = string.format("cd %s && %s", file_dir, output)
  local start_time = vim.loop.now()
  local Terminal = require("toggleterm.terminal").Terminal
  local function term_on_open(t)
    vim.cmd("startinsert!")
    vim.api.nvim_buf_set_keymap(t.bufnr, "t", "<C-n>", [[<C-\><C-n>]], { silent = true, noremap = true })
    vim.api.nvim_buf_set_keymap(t.bufnr, "n", "a", "<cmd>startinsert<CR>", { silent = true, noremap = true })
    vim.api.nvim_buf_set_keymap(t.bufnr, "t", "<C-S>", [[<C-\><C-n>:close<CR>]], { silent = true, noremap = true })
    vim.api.nvim_buf_set_keymap(t.bufnr, "n", "<C-S>", ":close<CR>", { silent = true, noremap = true })
    vim.api.nvim_buf_set_keymap(t.bufnr, "n", "<Tab>", "<cmd>lua _cycle_terminal(1)<CR>", { silent = true, noremap = true })
    vim.api.nvim_buf_set_keymap(t.bufnr, "n", "<S-Tab>", "<cmd>lua _cycle_terminal(-1)<CR>", { silent = true, noremap = true })
  end
  if not build_term then
    build_term = Terminal:new({ id = 1, cmd = compile_cmd, direction = "horizontal", close_on_exit = false, on_open = term_on_open })
  else
    build_term:shutdown()
    build_term = Terminal:new({ id = 1, cmd = compile_cmd, direction = "horizontal", close_on_exit = false, on_open = term_on_open })
  end
  build_term.dir = file_dir
  build_term:toggle()
  local run_label = "run:" .. file_name
  vim.defer_fn(function()
    local elapsed = (vim.loop.now() - start_time) / 1000
    local output_stat = vim.uv.fs_stat(output)
    if output_stat then
      vim.notify(string.format("Build OK (%.2fs)", elapsed), vim.log.levels.INFO)
      local run_term = run_terms[run_label]
      if not run_term then
        run_term = Terminal:new({ id = #vim.tbl_keys(run_terms) + 101, cmd = run_cmd, direction = "horizontal", close_on_exit = true, on_open = function(t)
          vim.cmd("startinsert!")
          vim.api.nvim_buf_set_keymap(t.bufnr, "t", "<C-n>", [[<C-\><C-n>]], { silent = true, noremap = true })
          vim.api.nvim_buf_set_keymap(t.bufnr, "n", "a", "<cmd>startinsert<CR>", { silent = true, noremap = true })
          vim.api.nvim_buf_set_keymap(t.bufnr, "t", "<C-S>", [[<C-\><C-n>:close<CR>]], { silent = true, noremap = true })
          vim.api.nvim_buf_set_keymap(t.bufnr, "n", "<C-S>", ":close<CR>", { silent = true, noremap = true })
        end, on_close = function() run_terms[run_label] = nil end })
        run_terms[run_label] = run_term
      end
      run_term.dir = file_dir
      run_term:toggle()
    else
      vim.notify(string.format("Build FAILED (%.2fs)", elapsed), vim.log.levels.ERROR)
    end
  end, 1000)
end

-- ==============================
-- NEW: BUILD & RUN
-- ==============================
local Terminal = require("toggleterm.terminal").Terminal

local function term_keys(t)
  vim.api.nvim_buf_set_keymap(t.bufnr, "t", "<C-n>", [[<C-\><C-n>]], { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(t.bufnr, "n", "a", "<cmd>startinsert<CR>", { silent = true, noremap = true })
  vim.api.nvim_buf_set_keymap(t.bufnr, "n", "<C-S>", ":close<CR>", { silent = true, noremap = true })
end

-- ==============================
-- MODE 2: OVERLAY (bang giua man hinh)
-- ==============================
local main_term = Terminal:new({
  id = 100,
  direction = "float",
  close_on_exit = true,
  hidden = true,
  float_opts = {
    border = "curved",
    width = math.floor(vim.o.columns * 0.85),
    height = math.floor(vim.o.lines * 0.85),
  },
  on_open = function(t) term_keys(t); vim.cmd("startinsert!") end,
})

function _build_cpp_overlay()
  vim.cmd("write")

  local file_path = vim.fn.expand("%:p")
  local file_dir = vim.fn.expand("%:p:h")
  local file_name = vim.fn.expand("%:t:r")
  local ext = vim.fn.expand("%:e")

  local cpp_exts = { cpp = true, cc = true, cxx = true, c = true }
  if not cpp_exts[ext] then
    vim.notify("Not a C/C++ file", vim.log.levels.WARN)
    return
  end

  local compiler = "clang++"
  if vim.fn.executable(compiler) ~= 1 then
    vim.notify("clang++ not found in PATH!", vim.log.levels.ERROR)
    return
  end

  local output = file_dir .. "/" .. file_name
  local wait = 'read -n 1 -s -r -p "Press any key to close..."'
  local cmd = string.format(
    'clang++ %s "%s" -o "%s" 2>&1; if [ $? -eq 0 ]; then clear; echo "=== RUNNING ==="; "%s"; echo ""; %s; else echo ""; %s; fi; exit',
    turbo_flags, file_path, output, output, wait, wait
  )

  vim.cmd("silent! cclose")

  if main_term:is_open() then
    main_term:close()
    vim.defer_fn(function()
      main_term:open()
      main_term:send("cd " .. file_dir)
      main_term:send("clear && " .. cmd)
    end, 100)
  else
    main_term:open()
    main_term:send("cd " .. file_dir)
    main_term:send("clear && " .. cmd)
  end
end

-- ==============================
-- MODE 1: TERMINAL (build roi run)
-- ==============================
local build_t = nil
local run_t = nil
local build_out = ""
local build_dir = ""
local build_pending = false

local function term_on_close()
  if not build_pending then return end
  build_pending = false
  vim.schedule(function()
    local stat = vim.uv.fs_stat(build_out)
    if stat then
      vim.notify("Build OK", vim.log.levels.INFO)
      run_t = Terminal:new({
        id = 61,
        cmd = "cd " .. build_dir .. " && clear && echo '=== RUNNING ===' && " .. build_out,
        direction = "horizontal",
        close_on_exit = false,
        on_open = function(t) term_keys(t); vim.cmd("startinsert!") end,
      })
      run_t:toggle()
    else
      vim.notify("Build FAILED", vim.log.levels.ERROR)
    end
  end)
end

function _build_cpp_terminal()
  vim.cmd("write")

  local file_path = vim.fn.expand("%:p")
  local file_dir = vim.fn.expand("%:p:h")
  local file_name = vim.fn.expand("%:t:r")
  local ext = vim.fn.expand("%:e")

  local cpp_exts = { cpp = true, cc = true, cxx = true, c = true }
  if not cpp_exts[ext] then
    vim.notify("Not a C/C++ file", vim.log.levels.WARN)
    return
  end

  local compiler = "clang++"
  if vim.fn.executable(compiler) ~= 1 then
    vim.notify("clang++ not found in PATH!", vim.log.levels.ERROR)
    return
  end

  build_out = file_dir .. "/" .. file_name
  build_dir = file_dir
  local compile_cmd = compiler .. " " .. turbo_flags .. ' "' .. file_path .. '" -o "' .. build_out .. '"'
  local wait = 'read -n 1 -s -r -p "Press any key to close..."'

  -- Kill run terminal cu neu dang chay
  if run_t then
    run_t:shutdown()
    run_t = nil
  end

  -- Build terminal (debug: chi show output, ko ghi duoc gi)
  if build_t then
    build_pending = false
    build_t:shutdown()
  end
  build_pending = true
  build_t = Terminal:new({
    id = 60,
    cmd = compile_cmd .. ' 2>&1; echo ""; ' .. wait .. '; exit',
    direction = "horizontal",
    close_on_exit = true,
    on_open = function(t) term_keys(t); vim.cmd("startinsert!") end,
    on_close = term_on_close,
  })
  build_t:toggle()
end

-- ==============================
-- DISPATCH
-- ==============================
local function build_dispatch()
  if build_mode == "terminal" then
    _build_cpp_terminal()
  else
    _build_cpp_overlay()
  end
end

function _toggle_build_mode()
  if build_mode == "terminal" then
    build_mode = "overlay"
  else
    build_mode = "terminal"
  end
  if main_term:is_open() then main_term:close() end
  if build_t and build_t:is_open() then build_t:close() end
  if run_t and run_t:is_open() then run_t:close() end
  vim.notify("C++ build mode: " .. build_mode, vim.log.levels.INFO)
end

-- ==============================
-- COMMANDS
-- ==============================
vim.api.nvim_create_user_command("CppChooseCompiler", _choose_compiler, { desc = "Choose C++ compiler" })
vim.api.nvim_create_user_command("CppBuildRun", _build_and_run, { desc = "Build & Run C++ (legacy)" })
vim.api.nvim_create_user_command("CppToggleBuildMode", _toggle_build_mode, { desc = "Toggle build mode: overlay / terminal" })

-- ==============================
-- KEYMAP
-- ==============================
-- Dang ky ngay + lai sau VeryLazy de LazyVim's `<C-S>` save khong ghi de
vim.keymap.set("n", "<C-S>", build_dispatch, { desc = "Build & Run C++ (clang++)" })
vim.api.nvim_create_autocmd("User", {
  pattern = "VeryLazy",
  callback = function()
    vim.keymap.set("n", "<C-S>", build_dispatch, { desc = "Build & Run C++ (clang++)" })
  end,
})

-- ==============================
-- INIT
-- ==============================
local config = load_config()
if not config then
  vim.defer_fn(function()
    local compilers = detect_compilers()
    if #compilers > 0 then
      _choose_compiler()
    end
  end, 2000)
end

return M

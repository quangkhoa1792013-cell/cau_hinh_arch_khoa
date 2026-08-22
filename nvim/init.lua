-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")
require("config.keymaps")

-- Auto save
vim.api.nvim_create_autocmd({ "FocusLost", "InsertLeave" }, {
  pattern = "*",
  command = "silent! wall",
})

-- Terminal normal mode exit
vim.keymap.set("t", "<C-n>", [[<C-\><C-n>]], { silent = true })

-- VSCode-like window groups + layout
require("config.window-groups")

-- C++ Build system (loads after UI is ready)
vim.defer_fn(function()
  require("config.cpp_build")
end, 500)

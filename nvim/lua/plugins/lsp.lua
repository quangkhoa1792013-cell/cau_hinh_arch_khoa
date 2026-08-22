-- Tat hoan toan hover doc va signature help
vim.lsp.handlers["textDocument/hover"] = function() end
vim.lsp.handlers["textDocument/signatureHelp"] = function() end

return {
  {
    "nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
      servers = {
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=never",
            "--query-driver=/usr/bin/g++",
            "--query-driver=/usr/bin/clang++",
          },
        },
      },
    },
  },
}

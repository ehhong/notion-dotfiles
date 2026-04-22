return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      tsserver = { enabled = false },
      vtsls = { enabled = false },
      tsgo = {
        cmd = { "tsgo", "--lsp", "--stdio" },
        filetypes = {
          "javascript",
          "javascriptreact",
          "javascript.jsx",
          "typescript",
          "typescriptreact",
          "typescript.tsx",
        },
        root_markers = {
          "tsconfig.json",
          "jsconfig.json",
          "package.json",
          ".git",
          "tsconfig.base.json",
        },
        enabled = true,
      },
    },
  },
}

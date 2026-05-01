return {
  -- GitHub Darkテーマ
  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 1000,
    config = function()
      require("github-theme").setup({
        groups = {
          github_dark_default = {
            -- 変更のないファイル/ディレクトリは白
            Directory = { fg = "#e6edf3" },

            -- Snacks Explorer/Picker Git status colors
            SnacksPickerGitStatusAdded = { fg = "#3fb950" },
            SnacksPickerGitStatusModified = { fg = "#d29922" },
            SnacksPickerGitStatusDeleted = { fg = "#f85149" },
            SnacksPickerGitStatusRenamed = { fg = "#3fb950" },
            SnacksPickerGitStatusCopied = { fg = "#3fb950" },
            SnacksPickerGitStatusUntracked = { fg = "#8b949e" },
            SnacksPickerGitStatusIgnored = { fg = "#484f58" },
            SnacksPickerGitStatusUnmerged = { fg = "#f85149" },
            SnacksPickerGitStatusStaged = { fg = "#3fb950" },
          },
        },
      })
      vim.cmd.colorscheme("github_dark_default")
    end,
  },
}

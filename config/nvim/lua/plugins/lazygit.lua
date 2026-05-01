return {
  {
    "snacks.nvim",
    opts = {
      lazygit = {
        configure = false,
        config = {
          gui = {
            theme = {
              -- GitHub Dark Default palette
              activeBorderColor = { "#388bfd", "bold" },
              inactiveBorderColor = { "#30363d" },
              optionsTextColor = { "#8b949e" },
              selectedLineBgColor = { "#161b22" },
              cherryPickedCommitBgColor = { "#238636" },
              cherryPickedCommitFgColor = { "#c9d1d9" },
              unstagedChangesColor = { "#da3633" },
              defaultFgColor = { "#8b949e" },
            },
            showIcons = true,
            nerdFontsVersion = "3",
          },
        },
      },
    },
  },
}

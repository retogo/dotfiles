return {
  {
    "mistweaverco/kulala.nvim",
    ft = "http",
    opts = {
      split_direction = "vertical",
      default_view = "body",
    },
    keys = {
      { "<leader>rs", function() require("kulala").run() end, desc = "Send request" },
      { "<leader>ra", function() require("kulala").run_all() end, desc = "Send all requests" },
      { "<leader>rp", function() require("kulala").jump_prev() end, desc = "Previous request" },
      { "<leader>rn", function() require("kulala").jump_next() end, desc = "Next request" },
      { "<leader>ri", function() require("kulala").inspect() end, desc = "Inspect request" },
      { "<leader>rt", function() require("kulala").toggle_view() end, desc = "Toggle body/headers" },
      { "<leader>rc", function() require("kulala").copy() end, desc = "Copy as cURL" },
    },
  },
}

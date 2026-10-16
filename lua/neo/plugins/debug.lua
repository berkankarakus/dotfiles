-- .NET debugging (the project discovery lives in neo.dotnet_debug).
return {
  {
    "mfussenegger/nvim-dap",
    event = "BufReadPost *.cs",
    keys = {
      { "<F5>", desc = "Debug: Continue" },
      { "<F10>", desc = "Debug: Step over" },
      { "<F11>", desc = "Debug: Step into" },
      { "<F12>", desc = "Debug: Step out" },
      { "<leader>b", desc = "Debug: Toggle breakpoint" },
      { "<leader>bc", desc = "Debug: Clear all breakpoints" },
      { "<leader>B", desc = "Debug: Conditional breakpoint" },
      { "<leader>dr", desc = "Debug: Open REPL" },
      { "<leader>du", desc = "Debug: Toggle UI" },
    },
    dependencies = {
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" }, opts = {} },
      { "Cliffback/netcoredbg-macOS-arm64.nvim" },
      { "jay-babu/mason-nvim-dap.nvim", opts = { ensure_installed = { "netcoredbg" }, automatic_installation = true } },
      { "Weissle/persistent-breakpoints.nvim" },
    },
    config = function()
      local dap = require("dap")
      dap.set_log_level("INFO")
      local dapui = require("dapui")
      require("persistent-breakpoints").setup({ load_breakpoints_event = { "BufReadPost" } })
      local persistent_breakpoints = require("persistent-breakpoints.api")
      local netcoredbg = vim.fn.stdpath("data") .. "/lazy/netcoredbg-macOS-arm64.nvim/netcoredbg/netcoredbg"
      local dotnet = require("neo.dotnet_debug")
      local launch_context = dotnet.launch_context_cache(dotnet.resolve_launch_context)
      local function current_launch_context()
        return launch_context.get()
      end
      dap.adapters.coreclr = { type = "executable", command = netcoredbg, args = { "--interpreter=vscode" } }
      dap.configurations.cs = {
        {
          type = "coreclr", name = "Launch .NET project", request = "launch",
          program = function() return current_launch_context().program end,
          args = function() return current_launch_context().profile.args end,
          cwd = function() return current_launch_context().profile.cwd end,
          env = function() return current_launch_context().profile.env end,
          stopAtEntry = false,
        },
      }
      dap.listeners.after.event_initialized["dapui"] = function()
        local browser_url = current_launch_context().profile.browser_url
        dapui.open()
        if browser_url then
          vim.defer_fn(function() vim.ui.open(browser_url) end, 1500)
        end
      end
      local terminal_bundle_ids = {
        Apple_Terminal = "com.apple.Terminal",
        Ghostty = "com.mitchellh.ghostty",
        ghostty = "com.mitchellh.ghostty",
        iTerm = "com.googlecode.iterm2",
        iTerm2 = "com.googlecode.iterm2",
        WezTerm = "com.github.wez.wezterm",
      }
      local terminal_bundle_id = terminal_bundle_ids[vim.env.TERM_PROGRAM]
      local terminal_notifier = vim.fn.exepath("terminal-notifier")
      dap.listeners.after.event_stopped["debug-notification"] = function(_, body)
        if body.reason ~= "breakpoint" then return end

        local message = "Breakpoint reached."
        vim.notify(message, vim.log.levels.INFO, { title = "Neovim Debugger" })

        if terminal_notifier ~= "" then
          local command = { terminal_notifier, "-title", "Neovim Debugger", "-message", message }
          if terminal_bundle_id then
            vim.list_extend(command, { "-activate", terminal_bundle_id })
          end
          vim.fn.jobstart(command, { detach = true })
        end
      end
      local function close_debug_ui()
        launch_context.reset()
        dapui.close()
      end
      dap.listeners.before.event_terminated["dapui"] = close_debug_ui
      dap.listeners.before.event_exited["dapui"] = close_debug_ui
      vim.keymap.set("n", "<F5>", function()
        if not dap.session() then launch_context.reset() end
        dap.continue()
      end, { desc = "Debug: Continue" })
      vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: Step over" })
      vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: Step into" })
      vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: Step out" })
      vim.keymap.set("n", "<leader>b", persistent_breakpoints.toggle_breakpoint, { desc = "Debug: Toggle breakpoint" })
      vim.keymap.set("n", "<leader>bc", persistent_breakpoints.clear_all_breakpoints, { desc = "Debug: Clear all breakpoints" })
      vim.keymap.set("n", "<leader>B", persistent_breakpoints.set_conditional_breakpoint, { desc = "Debug: Conditional breakpoint" })
      vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Debug: Open REPL" })
      vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debug: Toggle UI" })
    end,
  },
}

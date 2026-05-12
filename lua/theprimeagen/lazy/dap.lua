return {
    {
        "mfussenegger/nvim-dap",
        dependencies = {
            "rcarriga/nvim-dap-ui",
            "nvim-neotest/nvim-nio",
            'leoluz/nvim-dap-go',
        },
        tag = "0.10.0",
        config = function()
            require("dapui").setup()
            require("dap-go").setup()

            local dap = require("dap")
            local ui = require("dapui")

            vim.keymap.set("n", "<space>b", dap.toggle_breakpoint)
            vim.keymap.set("n", "<space>gb", dap.run_to_cursor)
            vim.keymap.set("n", "<F1>", dap.step_over)
            vim.keymap.set("n", "<F2>", dap.step_into)
            vim.keymap.set("n", "<F3>", dap.continue)
            vim.keymap.set("n", "<F4>", dap.step_out)
            vim.keymap.set("n", "<F12>", dap.restart)
            -- Eval var under cursor
            vim.keymap.set("n", "<space>?", function()
                require("dapui").eval(nil, { enter = true })
            end)

            dap.listeners.before.attach.dapui_config = function()
                ui.open()
            end
            dap.listeners.before.launch.dapui_config = function()
                ui.open()
            end
            dap.listeners.before.event_terminated.dapui_config = function()
                ui.close()
            end
            dap.listeners.before.event_exited.dapui_config = function()
                ui.close()
            end
        end,
    }
}

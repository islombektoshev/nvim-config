return {
    {
        'milanglacier/minuet-ai.nvim',
        config = function()
            local minuet = require 'minuet'

            -- local api_key = vim.env.OPENROUTER_NEOVIM_AUTOCOMPLETE_KEY
            minuet.setup {
                provider = 'openai_compatible',
                notify = 'debug',
                request_timeout = 2.5,
                throttle = 2000, -- Increase to reduce costs and avoid rate limits
                debounce = 400,  -- Increase to reduce costs and avoid rate limits
                -- nvim-cmp stays for LSP/snippets only; AI goes through virtual text
                cmp = { enable_auto_complete = false },
                virtualtext = {
                    auto_trigger_ft = { '*' },
                    keymap = {
                        -- <Tab> mapped manually below so it falls back to normal Tab
                        accept = nil,
                        accept_line = '<C-l>',
                        next = '<C-j>',
                        prev = '<C-k>',
                        dismiss = '<C-x>',
                    },
                    show_on_completion_menu = false,
                },
                provider_options = {
                    openai_compatible = {
                        api_key = 'OPENROUTER_NEOVIM_AUTOCOMPLETE_KEY',
                        end_point = 'https://openrouter.ai/api/v1/chat/completions',
                        model = 'mistralai/codestral-2508',
                        -- model='deepseek/deepseek-v4-flash',
                        name = 'Openrouter',
                        optional = {
                            max_tokens = 56,
                            top_p = 0.9,
                            provider = {
                                -- Prioritize throughput for faster completion
                                sort = 'throughput',
                            },
                            -- disable thinking to avoid first token latency
                            reasoning_effort = 'none'
                        },
                    },
                },
            }

            local vt = require('minuet.virtualtext').action
            vim.keymap.set('i', '<Tab>', function()
                if vt.is_visible() then
                    vt.accept()
                else
                    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Tab>', true, false, true), 'n', false)
                end
            end, { desc = 'Accept minuet suggestion or insert Tab' })
        end,
    },
    { 'hrsh7th/nvim-cmp' },
}

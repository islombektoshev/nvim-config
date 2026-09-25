return {
    {
        'milanglacier/minuet-ai.nvim',
        config = function()
            local minuet = require 'minuet'
            local guard = require 'theprimeagen.minuet_guard'

            -- Extra prompt context: the 10 most recently used files this session.
            -- Costs extra input tokens per request; tune caps below.
            local recent_files_max = 10
            local recent_lines_per_file = 60
            local recent_total_chars = 16000

            local function recent_files_context()
                local current = vim.api.nvim_get_current_buf()
                local bufs = vim.fn.getbufinfo { buflisted = 1 }
                table.sort(bufs, function(a, b)
                    return a.lastused > b.lastused
                end)

                local chunks, total, count = {}, 0, 0
                for _, buf in ipairs(bufs) do
                    if count >= recent_files_max or total >= recent_total_chars then
                        break
                    end
                    local ok = buf.bufnr ~= current
                        and buf.name ~= ''
                        and vim.bo[buf.bufnr].buftype == ''
                        and vim.fn.filereadable(buf.name) == 1
                        and guard.allowed(buf.name)
                    if ok then
                        local lines
                        if buf.loaded == 1 then
                            lines = vim.api.nvim_buf_get_lines(buf.bufnr, 0, recent_lines_per_file, false)
                        else
                            local read_ok, content = pcall(vim.fn.readfile, buf.name, '', recent_lines_per_file)
                            lines = read_ok and content or {}
                        end
                        local text = table.concat(lines, '\n')
                        if #text > 0 then
                            local rel = vim.fn.fnamemodify(buf.name, ':.')
                            table.insert(chunks, string.format('<file path="%s">\n%s\n</file>', rel, text))
                            total = total + #text
                            count = count + 1
                        end
                    end
                end

                if #chunks == 0 then
                    return ''
                end
                return '<recentlyOpenedFiles>\n' .. table.concat(chunks, '\n') .. '\n</recentlyOpenedFiles>'
            end

            local chat_input = vim.deepcopy(require('minuet.config').default_chat_input_prefix_first)
            chat_input.template = '{{{recent_files}}}\n' .. chat_input.template
            chat_input.recent_files = function(_, _, _)
                return recent_files_context()
            end

            -- local api_key = vim.env.OPENROUTER_NEOVIM_AUTOCOMPLETE_KEY
            minuet.setup {
                provider = 'openai_compatible',
                notify = 'debug',
                request_timeout = 2.5,
                throttle = 2000, -- Increase to reduce costs and avoid rate limits
                debounce = 400,  -- Increase to reduce costs and avoid rate limits
                -- nvim-cmp stays for LSP/snippets only; AI goes through virtual text
                cmp = { enable_auto_complete = false },
                -- Trim completion tail that duplicates text after cursor (e.g. closing '}').
                -- Default 15 is too high for single-char braces.
                after_cursor_filter_length = 1,
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
                        chat_input = chat_input,
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

            -- After minuet.setup() so the guard's FileType autocmd runs after
            -- minuet's own one and wins.
            guard.setup()

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

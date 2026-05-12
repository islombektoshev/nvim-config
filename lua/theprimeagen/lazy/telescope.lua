return {
    "nvim-telescope/telescope.nvim",

    tag = "0.1.5",

    dependencies = {
        "nvim-lua/plenary.nvim"
    },

    config = function()
        local telescope = require('telescope')
        local builtin = require('telescope.builtin')

        telescope.setup({
            defaults = {
                path_display = 'tail',
            }
        })


        vim.keymap.set('n', '<leader>pf', function()
            builtin.find_files({ path_display = { "truncate" } });
        end, {})
        vim.keymap.set('n', '<C-p>', builtin.git_files, {})
        vim.keymap.set('n', '<leader>pb', builtin.buffers, {})
        vim.keymap.set('n', '<leader>pd', function()
            builtin.lsp_document_symbols({ symbol_width = 60 })
        end, {})
        vim.keymap.set('n', '<leader>pa', function()
            builtin.lsp_dynamic_workspace_symbols({
                fname_width = 0,
                show_line = false,
                symbol_width = 60,
                path_display = 'tail'
            })
        end, {})
        vim.keymap.set('n', '<leader>pws', function()
            local word = vim.fn.expand("<cword>")
            builtin.grep_string({ search = word })
        end)
        vim.keymap.set('n', '<leader>pWs', function()
            local word = vim.fn.expand("<cWORD>")
            builtin.grep_string({ search = word })
        end)
        vim.keymap.set('n', '<leader>ps', builtin.live_grep, {});
        vim.keymap.set('n', '<leader>vh', builtin.help_tags, {})
    end
}

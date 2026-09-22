return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "hrsh7th/cmp-path",
        "hrsh7th/cmp-cmdline",
        "hrsh7th/nvim-cmp",
        "L3MON4D3/LuaSnip",
        "saadparwaiz1/cmp_luasnip",
        "j-hui/fidget.nvim",
    },

    config = function()
        local cmp = require('cmp')
        local cmp_lsp = require("cmp_nvim_lsp")
        local capabilities = vim.tbl_deep_extend(
            "force",
            {},
            vim.lsp.protocol.make_client_capabilities(),
            cmp_lsp.default_capabilities())

        require("fidget").setup({})
        require("mason").setup()

        require("mason-lspconfig").setup({
            ensure_installed = { "lua_ls", "superhtml", "gopls", "ts_ls", "vtsls" },
            automatic_enable = false,
        })

        vim.lsp.config("*", { capabilities = capabilities })

        vim.lsp.config("lua_ls", {
            settings = {
                Lua = {
                    runtime = { version = "Lua 5.1" },
                    diagnostics = { globals = { "bit", "vim", "it", "describe", "before_each", "after_each" } },
                    workspace = {
                        library = vim.api.nvim_get_runtime_file("", true),
                        checkThirdParty = false,
                    },
                }
            },
        })

        vim.lsp.config('jdtls', {
            flags = { debounce_text_changes = 200 },
            root_markers = { '.git', 'gradlew' },
            -- without this jdtls returns no location for classes inside jars
            init_options = { extendedClientCapabilities = { classFileContentsSupport = true } },
            settings = {
                java = {
                    autobuild = { enabled = false },
                    referencesCodeLens = { enabled = false },
                    implementationsCodeLens = { enabled = false },
                    contentProvider = { preferred = 'fernflower' },
                    maven = { downloadSources = true },
                    eclipse = { downloadSources = true },
                },
            },
        })

        -- jdtls returns jdt:// URIs for classes inside jars. Neovim can't read that
        -- scheme, so fetch the (decompiled) source via java/classFileContents.
        vim.api.nvim_create_autocmd('BufReadCmd', {
            pattern = 'jdt://*',
            callback = function(ev)
                local client = vim.lsp.get_clients({ name = 'jdtls' })[1]
                if not client then
                    vim.notify('jdtls not running, cannot open ' .. ev.match, vim.log.levels.WARN)
                    return
                end
                local buf = ev.buf
                vim.bo[buf].modifiable = true
                vim.bo[buf].swapfile = false
                vim.bo[buf].buftype = 'nofile'
                vim.bo[buf].filetype = 'java'
                local done = false
                client:request('java/classFileContents', { uri = ev.match }, function(err, content)
                    done = true
                    if err or not content then
                        vim.notify('classFileContents failed: ' .. vim.inspect(err), vim.log.levels.ERROR)
                        return
                    end
                    if not vim.api.nvim_buf_is_valid(buf) then return end
                    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, '\n', { plain = true }))
                    vim.bo[buf].modifiable = false
                    vim.bo[buf].modified = false
                    -- attach so go-to-definition keeps working inside library code
                    vim.lsp.buf_attach_client(buf, client.id)
                end, buf)
                -- block until content arrives: the jump sets the cursor right after
                -- BufReadCmd returns, and an empty buffer would clamp it to line 1
                if not vim.wait(5000, function() return done end) then
                    vim.notify('timeout fetching ' .. ev.match, vim.log.levels.WARN)
                end
            end,
        })
        vim.lsp.config('php_lsp', {
            cmd = { 'php-lsp' },
            filetypes = { 'php' },
            root_markers = { 'composer.json', '.git' },
            cmd_env = { RUST_LOG = 'php_lsp=debug' },
            includePaths = {
                'framework',
                'protected/vendor',
                'protected/vendors',
            },
            stubDirs = { 'framework' },
            init_options = {
                phpVersion = '7.4',
                excludePaths = { 'vendor/*', 'assets/*', 'protected/runtime/*' },
            },
        })
        vim.lsp.enable('php_lsp')

        vim.lsp.config("zls", {
            settings = { zls = { enable_inlay_hints = true, enable_snippets = true, warn_style = true } },
        })
        vim.g.zig_fmt_autosave = 0


        local cmp_select = { behavior = cmp.SelectBehavior.Select }

        cmp.setup({
            snippet = {
                expand = function(args)
                    require('luasnip').lsp_expand(args.body) -- For `luasnip` users.
                end,
            },
            mapping = cmp.mapping.preset.insert({
                ['<C-p>'] = cmp.mapping.select_prev_item(cmp_select),
                ['<C-n>'] = cmp.mapping.select_next_item(cmp_select),
                ['<C-y>'] = cmp.mapping.confirm({ select = true }),
                ['<CR>'] = cmp.mapping.confirm({ select = true }),
                ["<C-Space>"] = cmp.mapping.complete(),
            }),
            sources = cmp.config.sources({
                { name = 'nvim_lsp' },
                { name = 'luasnip' }, -- For luasnip users.
            }, {
                { name = 'buffer' },
            })
        })

        vim.diagnostic.config({
            -- update_in_insert = true,
            float = {
                focusable = false,
                style = "minimal",
                border = "rounded",
                source = "always",
                header = "",
                prefix = "",
            },
        })

        vim.lsp.enable({
            "lua_ls",
            "rust_analyzer",
            "gopls",
            "zls",
            "superhtml",
            "ols",
            "vtsls",
            "cssls",
            "jdtls",
            "groovyls",
        })
    end
}

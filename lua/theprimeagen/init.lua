require("theprimeagen.set")
require("theprimeagen.remap")
require("theprimeagen.lazy_init")
require("theprimeagen.snippets")
require('nvim-autopairs').setup {}


-- DO.not
-- DO NOT INCLUDE THIS

-- If i want to keep doing lsp debugging
-- function restart_htmx_lsp()
--     require("lsp-debug-tools").restart({ expected = {}, name = "htmx-lsp", cmd = { "htmx-lsp", "--level", "DEBUG" }, root_dir = vim.loop.cwd(), });
-- end

-- DO NOT INCLUDE THIS
-- DO.not

local augroup = vim.api.nvim_create_augroup
local ThePrimeagenGroup = augroup('ThePrimeagen', {})

local autocmd = vim.api.nvim_create_autocmd
local yank_group = augroup('HighlightYank', {})

function R(name)
    require("plenary.reload").reload_module(name)
end

vim.filetype.add({
    extension = {
        templ = 'templ',
    }
})

autocmd('TextYankPost', {
    group = yank_group,
    pattern = '*',
    callback = function()
        vim.highlight.on_yank({
            higroup = 'IncSearch',
            timeout = 40,
        })
    end,
})

vim.api.nvim_create_user_command("LspLog", function()
    local fname = vim.lsp.log.get_filename()
    vim.cmd.edit(fname)
end, {})
autocmd({ "BufWritePre" }, {
    group = ThePrimeagenGroup,
    pattern = "*",
    command = [[%s/\s\+$//e]],
})

autocmd('BufEnter', {
    group = ThePrimeagenGroup,
    callback = function()
        -- if vim.bo.filetype == "zig" then
        --     vim.cmd.colorscheme("tokyonight-night")
        -- else
        --     vim.cmd.colorscheme("rose-pine-moon")
        -- end
    end
})


autocmd('LspAttach', {
    group = ThePrimeagenGroup,
    callback = function(e)
        local opts = { buffer = e.buf }
        vim.keymap.set("n", "gd", function() vim.lsp.buf.definition() end, opts)
        vim.keymap.set("n", "gi", function() vim.lsp.buf.implementation() end, opts)
        vim.keymap.set("n", "K", function() vim.lsp.buf.hover() end, opts)
        vim.keymap.set("n", "<leader>vws", function() vim.lsp.buf.workspace_symbol() end, opts)
        vim.keymap.set("n", "<leader>vd", function() vim.diagnostic.open_float() end, opts)
        vim.keymap.set("n", "<leader>vca", function() vim.lsp.buf.code_action() end, opts)
        vim.keymap.set("n", "<leader>vrr", function() vim.lsp.buf.references() end, opts)
        vim.keymap.set("n", "<leader>vrn", function() vim.lsp.buf.rename() end, opts)
        vim.keymap.set("i", "<C-h>", function() vim.lsp.buf.signature_help() end, opts)
        vim.keymap.set("n", "[d", function() vim.diagnostic.jump({ count = 1, on_jump = vim.diagnostic.open_float }) end,
            opts)
        vim.keymap.set("n", "]d", function() vim.diagnostic.jump({ count = -1, on_jump = vim.diagnostic.open_float }) end,
            opts)
    end
})

autocmd("FileType", {
    pattern = { "yaml", "python" },
    callback = function()
        vim.opt_local.list = true
        vim.opt_local.listchars = { space = "·", tab = "»·" }
    end,
})
autocmd("FileType", {
    pattern = { "md", "markdown" },
    callback = function()
        vim.opt_local.colorcolumn = '100'
    end,
})

vim.g.netrw_browse_split = 0
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 25
vim.cmd.colorscheme('tokyonight-moon')
-- vim.cmd.colorscheme('retrobox')
--
vim.lsp.config('gopls', { cmd = { 'gopls' } })

vim.opt.runtimepath:prepend("/Users/islombek/Projects/experimental/lua/line-comment.nvim")

local function only_child(path)
    local h = vim.uv.fs_scandir(path)
    if not h then return nil end
    local name, typ = vim.uv.fs_scandir_next(h)
    if not name or typ ~= 'directory' then return nil end
    if vim.uv.fs_scandir_next(h) then return nil end
    return name
end

local function chain(path, name)
    local rel, p = name, path
    local child = only_child(p)
    while child do
        p, rel = p .. '/' .. child, rel .. '/' .. child
        child = only_child(p)
    end
    return (rel ~= name) and rel or false
end

local runs = 0 -- debug counter

local function add_groups(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local dir = vim.b[buf].netrw_curdir
    if not dir then return end

    -- same folder + same content as last time? skip
    local key = dir .. ':' .. vim.api.nvim_buf_get_changedtick(buf)
    if vim.b[buf].groups_key == key then return end
    runs = runs + 1

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local changed = false

    for i = #lines, 1, -1 do
        local name = lines[i]:match('^([^/"]+)/$')
        if name and name ~= '.' and name ~= '..' then
            local rel = chain(dir .. '/' .. name, name)
            if rel and lines[i + 1] ~= rel .. '/' then
                if not changed then
                    vim.bo[buf].readonly = false
                    vim.bo[buf].modifiable = true
                    changed = true
                end
                vim.api.nvim_buf_set_lines(buf, i, i, false, { rel .. '/' })
            end
        end
    end

    if changed then
        vim.bo[buf].modifiable = false
        vim.bo[buf].modified = false
        vim.bo[buf].readonly = true
    end

    -- save key AFTER our edits (inserts change the tick)
    vim.b[buf].groups_key = dir .. ':' .. vim.api.nvim_buf_get_changedtick(buf)
end

local timers = {}

local function debounce(buf)
    local t = timers[buf]
    if t then
        t:stop()
    else
        t = vim.uv.new_timer()
        timers[buf] = t
    end
    t:start(30, 0, vim.schedule_wrap(function() add_groups(buf) end))
end

vim.api.nvim_create_autocmd('FileType', {
    pattern = 'netrw',
    callback = function(ev)
        debounce(ev.buf)

        if vim.b[ev.buf].groups_map then return end
        vim.b[ev.buf].groups_map = true
        vim.keymap.set('n', '<CR>', function()
            local line = vim.api.nvim_get_current_line()
            if line:match('^[^"].*/.+/$') then
                local path = vim.b.netrw_curdir .. '/' .. line
                return '<Cmd>Explore ' .. vim.fn.fnameescape(path) .. '<CR>'
            end
            return '<Plug>NetrwLocalBrowseCheck'
        end, { buffer = ev.buf, expr = true, remap = true })
    end,
})

-- free timer when buffer is gone
vim.api.nvim_create_autocmd('BufWipeout', {
    callback = function(ev)
        local t = timers[ev.buf]
        if t then t:close(); timers[ev.buf] = nil end
    end,
})

vim.api.nvim_create_user_command('NetrwGroupsRuns', function() print(runs) end, {})

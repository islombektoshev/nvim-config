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
-- vim.cmd.colorscheme('tokyonight-moon')
vim.cmd.colorscheme('retrobox')
--
vim.lsp.config('gopls', { cmd = { 'gopls' } })

vim.opt.runtimepath:prepend("/Users/islombek/Projects/experimental/lua/line-comment.nvim")
vim.opt.errorformat = "%E%f:%l: error: %m,%W%f:%l: warning: %m,%-G%.%#"

--
-- Explore optimzaiton code here
--
-- name of the only child folder, or nil
local function only_child(path)
    local h = vim.uv.fs_scandir(path)
    if not h then return nil end
    local name, typ = vim.uv.fs_scandir_next(h)
    if not name or typ ~= 'directory' then return nil end
    if vim.uv.fs_scandir_next(h) then return nil end
    return name
end

-- "bin" → "bin/generated-sources/annotations", or false
local function chain(path, name)
    local rel, p = name, path
    local child = only_child(p)
    while child do
        p, rel = p .. '/' .. child, rel .. '/' .. child
        child = only_child(p)
    end
    return (rel ~= name) and rel or false
end

local function add_groups(win)
    if not vim.api.nvim_win_is_valid(win) then return end
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype ~= 'netrw' then return end
    local dir = vim.b[buf].netrw_curdir
    if not dir then return end

    -- skip if this window already processed this exact content
    local key = buf .. ':' .. dir .. ':' .. vim.api.nvim_buf_get_changedtick(buf)
    if vim.w[win].groups_key == key then return end

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local changed = false
    local function unlock()
        if changed then return end
        vim.bo[buf].readonly = false
        vim.bo[buf].modifiable = true
        changed = true
    end

    -- forward groups (bottom-up)
    local up_idx
    for i = #lines, 1, -1 do
        if lines[i] == '../' then up_idx = i end
        local name = lines[i]:match('^([^/"]+)/$')
        if name and name ~= '.' and name ~= '..' then
            local rel = chain(dir .. '/' .. name, name)
            if rel and lines[i + 1] ~= rel .. '/' then
                unlock()
                vim.api.nvim_buf_set_lines(buf, i, i, false, { rel .. '/' })
            end
        end
    end

    -- backlink: climb while parent holds only one folder
    if up_idx then
        local up, p = '..', vim.fs.dirname(dir)
        while p ~= '/' and only_child(p) do
            p = vim.fs.dirname(p)
            up = up .. '/..'
        end
        if up ~= '..' and lines[up_idx + 1] ~= up .. '/' then
            unlock()
            vim.api.nvim_buf_set_lines(buf, up_idx, up_idx, false, { up .. '/' })
        end
    end

    if changed then
        vim.bo[buf].modifiable = false
        vim.bo[buf].modified = false
        vim.bo[buf].readonly = true
    end

    vim.w[win].groups_key = buf .. ':' .. dir .. ':' .. vim.api.nvim_buf_get_changedtick(buf)
end

local timers = {} -- window id → timer

local function debounce(win)
    local t = timers[win]
    if t then
        t:stop()
    else
        t = vim.uv.new_timer()
        timers[win] = t
    end
    t:start(30, 0, vim.schedule_wrap(function() add_groups(win) end))
end

vim.api.nvim_create_autocmd('FileType', {
    pattern = 'netrw',
    callback = function(ev)
        debounce(vim.api.nvim_get_current_win())

        -- keymaps are buffer-local, so this flag stays on the buffer
        if vim.b[ev.buf].groups_map then return end
        vim.b[ev.buf].groups_map = true
        vim.keymap.set('n', '<CR>', function()
            local line = vim.api.nvim_get_current_line()
            if line:match('^[^"].*/.+/$') then
                local path = vim.fn.simplify(vim.b.netrw_curdir .. '/' .. line)
                return '<Cmd>Explore ' .. vim.fn.fnameescape(path) .. '<CR>'
            end
            return '<Plug>NetrwLocalBrowseCheck'
        end, { buffer = ev.buf, expr = true, remap = true })
    end,
})

-- free timer when window closes
vim.api.nvim_create_autocmd('WinClosed', {
    callback = function(ev)
        local win = tonumber(ev.match)
        local t = timers[win]
        if t then
            t:close(); timers[win] = nil
        end
    end,
})

-- jdtls house: settings + :JdtlsSync / :JdtlsNuke / :JdtlsInfo
--
-- Why: jdtls caches the resolved Gradle classpath in
--   stdpath('cache')/jdtls/workspace/<root basename>   (same formula nvim-lspconfig uses)
-- and on startup only checks the ROOT build files' mtime. A subproject build.gradle edited
-- while jdtls was off => stale classpath => bogus "cannot be resolved" errors while Gradle is fine.

local M = {}

local ROOT_MARKERS = { 'gradlew', 'settings.gradle', 'settings.gradle.kts', 'mvnw', 'pom.xml', '.git' }

-- merged into the jdtls config defined in lazy/lsp.lua
vim.lsp.config('jdtls', {
    settings = {
        java = {
            -- re-sync Gradle classpath when build.gradle changes while jdtls runs
            -- (default 'interactive' asks via showMessageRequest, easy to miss in nvim)
            configuration = { updateBuildConfiguration = 'automatic' },
        },
    },
})

local function client()
    return vim.lsp.get_clients({ name = 'jdtls' })[1]
end

local function root_dir()
    local c = client()
    if c then return c.config.root_dir or c.root_dir end
    return vim.fs.root(0, ROOT_MARKERS)
end

function M.workspace_dir(root)
    return vim.fn.stdpath('cache') .. '/jdtls/workspace/' .. vim.fn.fnamemodify(root, ':p:h:t')
end

-- re-attach jdtls to every loaded java buffer (vim.lsp.enable toggle does not re-attach; :edit does)
local function restart()
    local cur = vim.api.nvim_get_current_win()
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype == 'java' and not vim.bo[b].modified then
            vim.api.nvim_buf_call(b, function() vim.cmd('silent! edit') end)
        end
    end
    pcall(vim.api.nvim_set_current_win, cur)
end

--- :JdtlsSync -- force Gradle re-sync (java/projectConfigurationUpdate).
--- Use when build.gradle changed while jdtls was not running.
function M.sync()
    local c = client()
    if not c then
        vim.notify('jdtls not running', vim.log.levels.WARN)
        return
    end
    local root = c.config.root_dir or c.root_dir
    local f = root .. '/settings.gradle'
    if vim.fn.filereadable(f) == 0 then f = root .. '/build.gradle' end
    c:notify('java/projectConfigurationUpdate', { uri = vim.uri_from_fname(f) })
    vim.notify('jdtls: Gradle sync requested for ' .. root)
end

--- :JdtlsNuke -- delete THIS project's workspace cache and restart jdtls (full re-import).
--- Other projects' caches untouched.
function M.nuke()
    local root = root_dir()
    if not root then
        vim.notify('jdtls: cannot determine project root', vim.log.levels.ERROR)
        return
    end
    local ws = M.workspace_dir(root)
    if vim.fn.isdirectory(ws) == 0 then
        vim.notify('jdtls: no cache at ' .. ws, vim.log.levels.WARN)
        return
    end
    for _, c in ipairs(vim.lsp.get_clients({ name = 'jdtls' })) do c:stop(true) end
    vim.fn.delete(ws, 'rf')
    vim.notify('jdtls: nuked ' .. ws)
    vim.defer_fn(restart, 500)
end

-- ---------------------------------------------------------------- :JdtlsInfo

local function ago(t)
    if t <= 0 then return '—' end
    local d = os.time() - t
    if d < 60 then return d .. 's ago' end
    if d < 3600 then return math.floor(d / 60) .. 'm ago' end
    if d < 86400 then return math.floor(d / 3600) .. 'h ago' end
    return math.floor(d / 86400) .. 'd ago'
end

local function dir_size(d)
    if vim.fn.isdirectory(d) == 0 then return '—' end
    return vim.trim(vim.split(vim.fn.system({ 'du', '-sh', d }), '\t')[1] or '?')
end

-- {rel, mark, state} for every subproject build file (root first)
local function freshness(root)
    local files = vim.fs.find(function(n) return n == 'build.gradle' or n == 'build.gradle.kts' end,
        { path = root, type = 'file', limit = math.huge })
    table.sort(files)
    local rows = {}
    for _, bf in ipairs(files) do
        local dir = vim.fs.dirname(bf)
        if not dir:find('/build/', 1, true) then
            local cp = dir .. '/.classpath'
            local rel = dir == root and '<root>' or dir:sub(#root + 2)
            local row
            if vim.fn.filereadable(cp) == 0 then
                row = { rel, '○ no .classpath', 'none' }
            elseif vim.fn.getftime(bf) > vim.fn.getftime(cp) then
                row = { rel, '✗ STALE  build.gradle newer than .classpath', 'stale' }
            else
                row = { rel, '✓ synced ' .. ago(vim.fn.getftime(cp)), 'ok' }
            end
            if rel == '<root>' then table.insert(rows, 1, row) else rows[#rows + 1] = row end
        end
    end
    return rows
end

local NOISE = { 'does not resolve to a ICompilationUnit', 'Gradle sha256 checksum' }

local function log_errors(log, n)
    if vim.fn.filereadable(log) == 0 then return nil end
    local errs, lines = {}, vim.fn.readfile(log)
    for i, l in ipairs(lines) do
        if l:match('^!ENTRY .* 4 ') then
            local msg = (lines[i + 1] or ''):gsub('^!MESSAGE ', '')
            local noise = false
            for _, p in ipairs(NOISE) do if msg:find(p, 1, true) then noise = true end end
            if not noise then
                errs[#errs + 1] = (l:match('(%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d)') or '') .. '  ' .. msg:sub(1, 90)
            end
        end
    end
    return vim.list_slice(errs, math.max(1, #errs - n + 1), #errs)
end

local function render(L)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, L)
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = 'wipe'
    local w = 0
    for _, l in ipairs(L) do w = math.max(w, vim.fn.strdisplaywidth(l)) end
    w = math.min(w + 2, vim.o.columns - 4)
    local h = math.min(#L, vim.o.lines - 4)
    local win = vim.api.nvim_open_win(buf, true, {
        relative = 'editor', style = 'minimal', border = 'rounded',
        width = w, height = h,
        row = math.floor((vim.o.lines - h) / 2), col = math.floor((vim.o.columns - w) / 2),
        title = ' JdtlsInfo ', title_pos = 'center',
    })
    vim.wo[win].wrap = false
    for _, k in ipairs({ 'q', '<Esc>' }) do
        vim.keymap.set('n', k, '<cmd>close<cr>', { buffer = buf, nowait = true })
    end
    local ns = vim.api.nvim_create_namespace('jdtls_info')
    for i, l in ipairs(L) do
        local hl = l:match('^▍') and 'Title'
            or l:match('STALE') and 'DiagnosticError'
            or l:match('✓') and 'DiagnosticOk'
            or l:match('^  ⚠') and 'DiagnosticWarn'
            or l:match('^  %d%d%d%d%-') and 'DiagnosticError'
        if hl then vim.api.nvim_buf_add_highlight(buf, ns, hl, i - 1, 0, -1) end
    end
end

--- :JdtlsInfo -- jdtls-only status: client, workspace cache, Gradle sync freshness, projects, log errors.
function M.info()
    local c = client()
    local root = root_dir()
    if not root then
        vim.notify('jdtls: cannot determine project root', vim.log.levels.ERROR)
        return
    end
    local ws = M.workspace_dir(root)
    local log = ws .. '/.metadata/.log'

    local L = {}
    local function add(s) L[#L + 1] = s end
    local function section(t) add(''); add('▍ ' .. t); add(string.rep('─', 62)) end
    local function kv(k, v) add(string.format('  %-22s %s', k, tostring(v))) end

    add('  jdtls · ' .. vim.fn.fnamemodify(root, ':t'))

    section('Client')
    if c then
        kv('status', '● running  (id ' .. c.id .. ')')
        kv('root', root)
        kv('buffers', vim.tbl_count(c.attached_buffers or {}))
        kv('build sync', vim.tbl_get(c.config, 'settings', 'java', 'configuration', 'updateBuildConfiguration')
            or 'interactive (default)')
        kv('autobuild', tostring(vim.tbl_get(c.config, 'settings', 'java', 'autobuild', 'enabled')))
    else
        kv('status', '○ not running')
        kv('root', root)
    end

    section('Workspace cache')
    kv('path', ws)
    kv('exists', vim.fn.isdirectory(ws) == 1 and 'yes' or 'no')
    kv('size', dir_size(ws))
    kv('created', ago(vim.fn.getftime(ws)))
    kv('log', log)

    section('Gradle sync freshness')
    local stale = 0
    for _, r in ipairs(freshness(root)) do
        kv(r[1], r[2])
        if r[3] == 'stale' then stale = stale + 1 end
    end
    local sg = root .. '/settings.gradle'
    if vim.fn.filereadable(sg) == 1 then kv('settings.gradle', 'modified ' .. ago(vim.fn.getftime(sg))) end
    if stale > 0 then
        add('')
        add('  ⚠ ' .. stale .. ' stale → :JdtlsSync   (or :JdtlsNuke for full re-import)')
    end

    section('Log errors (last 5)')
    local errs = log_errors(log, 5)
    if not errs then
        add('  no log file')
    elseif #errs == 0 then
        add('  none (ignoring checksum / ICompilationUnit noise)')
    else
        for _, e in ipairs(errs) do add('  ' .. e) end
    end

    if not c then return render(L) end
    c:request('workspace/executeCommand', { command = 'java.project.getAll', arguments = {} }, function(err, res)
        section('Imported projects (from jdtls)')
        if err or type(res) ~= 'table' then
            add('  ' .. (err and err.message or 'no response'))
        else
            table.sort(res)
            for _, uri in ipairs(res) do
                local p = vim.uri_to_fname(uri):gsub('/$', '')
                add('  • ' .. (p == root and '<root>' or p:sub(#root + 2)))
            end
        end
        render(L)
    end, 0)
end

vim.api.nvim_create_user_command('JdtlsSync', M.sync, { desc = 'jdtls: force Gradle re-sync' })
vim.api.nvim_create_user_command('JdtlsNuke', M.nuke, { desc = 'jdtls: delete this project workspace cache, restart' })
vim.api.nvim_create_user_command('JdtlsInfo', M.info, { desc = 'jdtls: status window' })

return M

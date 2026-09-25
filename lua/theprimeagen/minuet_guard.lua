-- Decides which buffers minuet may send to OpenRouter.
-- Two layers: the file must live inside `allow_dirs` AND must not match any
-- deny pattern. Everything else is never sent. A false positive only means
-- no AI completion in that buffer, so patterns err on the blocking side.
local M = {}

local allow_dirs = {
    '~/Projects',
    '~/go',
    '~/.config/nvim',
}

-- Directory segments that mark a path as sensitive even inside allowed dirs.
local deny_dir_segments = {
    '/%.ssh/',
    '/%.aws/',
    '/%.gnupg/',
    '/%.kube/',
    '/%.password%-store/',
    '/secrets/',
}

-- Basename patterns (lua patterns, matched against the lowercased basename).
local deny_name_patterns = {
    '^%.env', -- .env, .env.local, .envrc
    '%.env$', -- prod.env
    '%.properties$',
    '^application[%w%-_.]*%.ya?ml$', -- application.yml, application-dev.yaml, application-prod.yml
    '^bootstrap[%w%-_.]*%.ya?ml$', -- Spring Cloud bootstrap.yml, bootstrap-dev.yaml
    'secret',
    'credential',
    '%.pem$',
    '%.key$',
    '%.p12$',
    '%.pfx$',
    '%.jks$',
    '%.keystore$',
    '%.kdbx$',
    '%.gpg$',
    '%.age$',
    '%.token$',
    '^id_rsa',
    '^id_ed25519',
    '^id_ecdsa',
    '^%.netrc$',
    '^%.pgpass$',
    '^%.npmrc$',
    '^%.pypirc$',
}

local expanded_allow = nil
local function allow_prefixes()
    if not expanded_allow then
        expanded_allow = {}
        for _, d in ipairs(allow_dirs) do
            table.insert(expanded_allow, vim.fs.normalize(vim.fn.expand(d)):lower())
        end
    end
    return expanded_allow
end

---@param path string buffer name (any form; empty/nil means not allowed)
---@return boolean allowed, string reason
function M.check(path)
    if not path or path == '' then
        return false, 'unnamed buffer'
    end
    local abs = vim.fs.normalize(vim.fn.fnamemodify(path, ':p')):lower()

    local inside = false
    for _, prefix in ipairs(allow_prefixes()) do
        if abs == prefix or abs:sub(1, #prefix + 1) == prefix .. '/' then
            inside = true
            break
        end
    end
    if not inside then
        return false, 'outside allowlisted dirs'
    end

    for _, seg in ipairs(deny_dir_segments) do
        if abs:find(seg) then
            return false, 'sensitive directory: ' .. seg:gsub('%%', '')
        end
    end

    local name = vim.fs.basename(abs)
    for _, pat in ipairs(deny_name_patterns) do
        if name:find(pat) then
            return false, 'sensitive name pattern: ' .. pat
        end
    end

    return true, 'allowed'
end

function M.allowed(path)
    return (M.check(path))
end

-- Force-disable minuet auto trigger in disallowed buffers. Must run after
-- minuet.setup() so this FileType autocmd fires after minuet's own one that
-- sets the flag to true.
function M.setup()
    vim.api.nvim_create_autocmd({ 'FileType', 'BufEnter' }, {
        group = vim.api.nvim_create_augroup('MinuetGuard', { clear = true }),
        callback = function(ev)
            if not M.allowed(vim.api.nvim_buf_get_name(ev.buf)) then
                vim.b[ev.buf].minuet_virtual_text_auto_trigger = false
            end
        end,
    })

    vim.api.nvim_create_user_command('MinuetGuard', function()
        local name = vim.api.nvim_buf_get_name(0)
        local ok, reason = M.check(name)
        vim.notify(('minuet %s here: %s (%s)'):format(ok and 'ENABLED' or 'BLOCKED', reason, name))
    end, { desc = 'Show whether minuet may send this buffer to OpenRouter' })
end

return M

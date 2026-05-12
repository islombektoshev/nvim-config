return {
    "alvan/vim-closetag",
    ft = {
        "html",
        "xhtml",
        "xml",
        "javascriptreact",
        "typescriptreact",
        "templ",
    },
    config = function()
        vim.g.closetag_filenames = "*.html,*.xhtml,*.phtml,*.jsx,*.tsx,*.js,*.ts,*.templ"
        vim.g.closetag_filetypes = "html,xhtml,phtml,javascriptreact,typescriptreact,templ"
        vim.g.closetag_emptyTags_caseSensitive = 1
        vim.g.closetag_regions = {
            ["typescript.tsx"] = "jsxRegion,tsxRegion",
            ["javascript.jsx"] = "jsxRegion",
        }
        vim.g.closetag_shortcut = ">"
        vim.g.closetag_close_shortcut = "<leader>>"
    end,
}

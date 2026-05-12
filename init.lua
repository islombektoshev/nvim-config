require("theprimeagen")
vim.opt.clipboard:append { 'unnamed' }
vim.api.nvim_create_autocmd("FileType", {
    pattern = "java",
    callback = function()
        vim.cmd("setlocal cmdheight=2")
    end,
})


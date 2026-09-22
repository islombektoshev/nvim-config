return {
    "mfussenegger/nvim-jdtls",
    -- not lazy: it must own BufReadCmd jdt://* and LspAttach before the first
    -- java buffer; ft-lazy-loading races with them (nvim-jdtls #639, #666)
    lazy = false,
}

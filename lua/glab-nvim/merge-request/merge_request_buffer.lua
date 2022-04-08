local render = require("glab-nvim.view.render")

local M = {}

_G.glab_nvim_buffers = {}

function M.create(merge_request)
    local bufnr = vim.api.nvim_create_buf(true, true)
    M.render(bufnr, merge_request)
    local this = {
        bufnr = bufnr,
        merge_request = merge_request,
        id = merge_request.iid
    }
    glab_nvim_buffers[this.bufnr] = this

    return this
end

function M.render(bufnr, merge_request)
    render.mr_view(bufnr, merge_request)
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_option(bufnr, "syntax", "lua")
    vim.api.nvim_buf_set_option(bufnr, "buftype", "acwrite")
    vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
    vim.api.nvim_buf_set_option(bufnr, "modified", false)
    vim.cmd(string.format("file glab_nvim://MR_%s", merge_request.iid))
end

function M.open_diff()
    local bufnr = vim.api.nvim_get_current_buf()
    local mr_buffer = glab_nvim_buffers[bufnr]
    local merge_request = mr_buffer.merge_request
    vim.cmd("DiffviewOpen " .. merge_request.sourceBranch .. ".." .. merge_request.targetBranch)
end

return M

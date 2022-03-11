local previewers = require "telescope.previewers"
local utils = require "glab-nvim.utils"

local M = {}

function M.mr_preview()
    return previewers.new_buffer_previewer {
        get_buffer_by_name = function(_, entry)
            return entry.name
        end,
        define_preview = function(self, entry)
            local bufnr = self.state.bufnr
            if self.state.bufname ~= entry.name or vim.api.nvim_buf_line_count(bufnr) == 1 then
                local lines = utils.splitlines(vim.inspect(entry.merge_request))
                local winnr = vim.fn.bufwinnr(bufnr)
                local winid = vim.fn.win_getid(winnr)
                vim.api.nvim_win_set_option(winid, "wrap", true)
                vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            end
        end
    }
end

return M

local previewers = require "telescope.previewers"
local config = require("glab-nvim.config")

local api = require("glab-nvim.api.gitlab.api")
local render = require("glab-nvim.view.render")

local M = {}

function M.mr_preview()
  return previewers.new_buffer_previewer {
    get_buffer_by_name = function(_, entry)
      return entry.name
    end,
    define_preview = function(self, entry)
      local bufnr = self.state.bufnr
      local project = config.get_project()
      if self.state.bufname ~= entry.name or vim.api.nvim_buf_line_count(bufnr) == 1 then
        api.get_merge_request(
          project.owner,
          project.name,
          entry.merge_request.iid,
          function(merge_request)
            render.mr_preview(bufnr, merge_request)
          end
        )
      end
    end
  }
end

return M

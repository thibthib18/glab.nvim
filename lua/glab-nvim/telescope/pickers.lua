local actions = require "telescope.actions"
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local action_state = require "telescope.actions.state"
local action_set = require "telescope.actions.set"
local conf = require "telescope.config".values
local glab_previewers = require "glab-nvim.telescope.previewers"
local entry_maker = require "glab-nvim.telescope.entry_maker"
local merge_request_buffer = require "glab-nvim.merge-request.merge_request_buffer"
local api = require("glab-nvim.api.gitlab.api")
local config = require("glab-nvim.config").get_config()

local M = {}

function M.merge_request_picker(merge_requests)
    local picker_opts = {}
    picker_opts.preview_title = "Preview"
    picker_opts.prompt_title = ""
    picker_opts.results_title = "Merge Requests"
    pickers.new(
        picker_opts,
        {
            finder = finders.new_table {
                results = merge_requests,
                entry_maker = entry_maker.gen_from_merge_request(4)
            },
            sorter = conf.generic_sorter(picker_opts),
            previewer = glab_previewers.mr_preview(),
            attach_mappings = function(_, map)
                action_set.select:replace(
                    function(prompt_bufnr, type)
                        actions.close(prompt_bufnr)
                        local entry = action_state.get_selected_entry()
                        api.get_merge_request(
                            config.project.owner,
                            config.project.name,
                            entry.merge_request.iid,
                            function(merge_request)
                                merge_request_buffer.create(merge_request)
                            end
                        )
                    end
                )
                --map("i", "<c-b>", open())
                return true
            end
        }
    ):find()
end

return M

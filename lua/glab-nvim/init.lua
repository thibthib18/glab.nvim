local config = require("glab-nvim.config")
local api = require("glab-nvim.api.gitlab.api")
local pickers = require "glab-nvim.telescope.pickers"

local M = {}

function M.pick_merge_requests()
    local function on_result(output)
        pickers.merge_request_picker(output)
    end
    local project = config.get_config().project
    api.get_merge_requests(project.owner, project.name, on_result)
end

function M.setup(user_config)
    for key, value in pairs(user_config) do
        if value ~= nil then
            config.config[key] = value
        end
    end
end

return M

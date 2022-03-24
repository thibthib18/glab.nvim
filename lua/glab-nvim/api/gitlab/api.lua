local graphql = require("glab-nvim.api.gitlab.graphql")
local glab = require("glab-nvim.api.gitlab.glab-job")
local utils = require("glab-nvim.utils")

local M = {}

local function run_job(query, on_result)
    glab.run(
        {
            args = {"api", "graphql", "--paginate", "-f", string.format("query=%s", query)},
            cb = function(output, stderr)
                if stderr and not utils.is_blank(stderr) then
                    vim.api.nvim_err_writeln(stderr)
                elseif output then
                    on_result(output)
                end
            end
        }
    )
end

function M.get_merge_requests(owner, name, on_result)
    local filter = "state: opened"
    local query = graphql("merge_requests_query", owner, name, filter)
    local on_result_cb = function(output)
        local resp = utils.aggregate_pages(output, "data.project.mergeRequests.nodes")
        -- local resp = vim.fn.json_decode(output)
        local obj = resp.data.project.mergeRequests.nodes
        on_result(obj)
    end
    run_job(query, on_result_cb)
end

function M.get_merge_request(owner, name, number, on_result)
    local query = graphql("merge_request_query", owner, name, number)
    local on_result_cb = function(output)
        local resp = utils.aggregate_pages(output, string.format("data.project.%s.discussions.nodes", "mergeRequest"))
        local obj = resp.data.project.mergeRequest
        on_result(obj)
    end
    run_job(query, on_result_cb)
end

return M

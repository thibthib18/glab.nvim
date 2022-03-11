-- package.loaded["glab-nvim"] = nil
package.loaded["glab-nvim.api.gitlab.api"] = nil
package.loaded["glab-nvim.api.gitlab.graphql"] = nil
package.loaded["glab-nvim.api.gitlab.glab-job"] = nil
package.loaded["glab-nvim.utils"] = nil

local api = require("glab-nvim.api.gitlab.api")
local owner = "thibthib"
local name = "test-project"

local pickers = require "glab-nvim.telescope.pickers"

local function on_result(output)
    print(vim.inspect(output))
    pickers.merge_request_picker(output)
end

api.get_merge_requests(owner, name, on_result)
-- api.get_merge_request(owner, name, 2, on_result)

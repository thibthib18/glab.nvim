describe(
    "glab",
    function()
        it(
            "can be required",
            function()
                require("glab-nvim.api.gitlab.api")
                local api = require("glab-nvim.api.gitlab.api")
                local owner = "thibthib"
                local name = "test-project"
                local function on_result(output)
                    print(vim.inspect(output))
                end
                api.get_merge_requests(owner, name, on_result)
                api.get_merge_request(owner, name, 2, on_result)
            end
        )
    end
)

local M = {}

M.config = {
    provider_hostname = "",
    username = "thibthib",
    project = {
        owner = "thibthib",
        name = "test-project"
    }
}

function M.get_config()
    return M.config
end

return M

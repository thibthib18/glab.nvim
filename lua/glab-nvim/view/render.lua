local writers = require("glab-nvim.view.writers")
local M = {}

function M.mr_preview(bufnr, merge_request)
    print(vim.inspect(merge_request))
    writers.write_title(bufnr, merge_request.title, 1)
    writers.write_mr_details(bufnr, merge_request)
    writers.write_mr_body(bufnr, merge_request)
    writers.write_state(bufnr, merge_request.state:upper(), merge_request.iid)
end

return M

local entry_display = require "telescope.pickers.entry_display"

local M = {}

function M.gen_from_merge_request(max_width)
  local make_display = function(entry)
    if not entry then
      return nil
    end

    local columns = {
      {entry.merge_request.iid, "TelescopeResultsNumber"},
      {entry.merge_request.title}
    }

    local displayer =
      entry_display.create {
      separator = " ",
      items = {
        {width = max_width},
        {remaining = true}
      }
    }

    return displayer(columns)
  end

  return function(merge_request)
    if not merge_request or vim.tbl_isempty(merge_request) then
      return nil
    end

    return {
      value = merge_request.iid,
      ordinal = merge_request.iid .. " " .. merge_request.title,
      display = make_display,
      merge_request = merge_request
    }
  end
end



return M

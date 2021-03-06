local date = require "glab-nvim.date"

local M = {}

function M.is_blank(s)
    return not (s ~= nil and s ~= vim.NIL and string.match(s, "%S") ~= nil)
end

function M.get_pages(text)
    local responses = {}
    while true do
        local idx = string.find(text, '}{"data"')
        if not idx then
            table.insert(responses, vim.fn.json_decode(text))
            break
        end
        local resp = string.sub(text, 0, idx)
        table.insert(responses, vim.fn.json_decode(resp))
        text = string.sub(text, idx + 1)
    end
    return responses
end

function M.tbl_slice(tbl, first, last, step)
    local sliced = {}
    for i = first or 1, last or #tbl, step or 1 do
        sliced[#sliced + 1] = tbl[i]
    end
    return sliced
end

function M.get_nested_prop(obj, prop)
    while true do
        local parts = vim.split(prop, "%.")
        if #parts == 1 then
            break
        else
            local part = parts[1]
            local remaining = table.concat(M.tbl_slice(parts, 2, #parts), ".")
            return M.get_nested_prop(obj[part], remaining)
        end
    end
    return obj[prop]
end

function M.aggregate_pages(text, aggregation_key)
    -- aggregation key can be at any level (eg: comments)
    -- take the first response and extend it with elements from the
    -- subsequent responses
    local responses = M.get_pages(text)
    local base_resp = responses[1]
    if #responses > 1 then
        local base_page = M.get_nested_prop(base_resp, aggregation_key)
        for i = 2, #responses do
            local extra_page = M.get_nested_prop(responses[i], aggregation_key)
            vim.list_extend(base_page, extra_page)
        end
    end
    return base_resp
end

function M.splitlines(s)
    local function splitlines_it(s)
        if s:sub(-1) ~= "\n" then
            s = s .. "\n"
        end
        return s:gmatch("(.-)\n")
    end

    local lines = {}
    for line in splitlines_it(s) do
        table.insert(lines, line)
    end
    return lines
end

function M.format_date(date_string)
    local time_bias = date():getbias() * -1
    local d = date(date_string):addminutes(time_bias)
    local now = date(os.time())
    local diff = date.diff(now, d)
    if diff:spandays() > 0 and diff:spandays() > 30 and now:getyear() ~= d:getyear() then
        return string.format("%s %s %d", d:getyear(), d:fmt("%b"), d:getday())
    elseif diff:spandays() > 0 and diff:spandays() > 30 and now:getyear() == d:getyear() then
        return string.format("%s %d", d:fmt("%b"), d:getday())
    elseif diff:spandays() > 0 and diff:spandays() <= 30 then
        return tostring(math.floor(diff:spandays())) .. " days ago"
    elseif diff:spanhours() > 0 then
        return tostring(math.floor(diff:spanhours())) .. " hours ago"
    elseif diff:spanminutes() > 0 then
        return tostring(math.floor(diff:spanminutes())) .. " minutes ago"
    elseif diff:spanseconds() > 0 then
        return tostring(math.floor(diff:spanswconds())) .. " seconds ago"
    else
        return string.format("%s %s %d", d:getyear(), d:fmt("%b"), d:getday())
    end
end

return M

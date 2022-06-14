local BodyMetadata = require "octo.model.body-metadata".BodyMetadata
local TitleMetadata = require "octo.model.title-metadata".TitleMetadata
local bubbles = require "octo.ui.bubbles"
local constants = require "octo.constants"
local utils = require "octo.utils"
local config = require("glab-nvim.config")

require "glab-nvim.view.colors".setup()

octo_buffers = {}

local M = {}

function M.write_virtual_text(bufnr, ns, line, chunks, mode)
    if vim.api.nvim_buf_line_count(bufnr) - 1 < line then
        print(
            "Error! Trying to write VT at: " .. line .. "; while lines count is: " .. vim.api.nvim_buf_line_count(bufnr)
        )
        print("The following virtual text will not be added:")
        print(vim.inspect(chunks))
    end
    mode = mode or "extmark"
    local ok
    if mode == "extmark" then
        ok = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, line, 0, {virt_text = chunks, virt_text_pos = "overlay"})
    elseif mode == "vt" then
        ok = pcall(vim.api.nvim_buf_set_virtual_text, bufnr, ns, line, chunks, {})
    end
end

function M.write_block(bufnr, lines, line, mark)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    line = line or vim.api.nvim_buf_line_count(bufnr) + 1
    mark = mark or false

    if type(lines) == "string" then
        lines = vim.split(lines, "\n", true)
    end

    -- write content lines
    vim.api.nvim_buf_set_lines(bufnr, line - 1, line - 1 + #lines, false, lines)

    -- set extmarks
    if mark then
        -- (empty line) start ext mark at 0
        -- start line
        -- ...
        -- end line
        -- (empty line)
        -- (empty line) end ext mark at 0
        --
        -- (except for title where we cant place initial mark on line -1)

        local start_line = line
        local end_line = line
        local count = start_line + #lines
        for i = count, start_line, -1 do
            local text = vim.fn.getline(i) or ""
            if "" ~= text then
                end_line = i
                break
            end
        end

        return vim.api.nvim_buf_set_extmark(
            bufnr,
            constants.OCTO_COMMENT_NS,
            math.max(0, start_line - 1 - 1),
            0,
            {
                end_line = math.min(end_line + 2 - 1, vim.api.nvim_buf_line_count(bufnr)),
                end_col = 0
            }
        )
    end
end

local function add_details_line(details, label, value, kind)
    if type(value) == "function" then
        value = value()
    end
    if value ~= vim.NIL and value ~= nil then
        if kind == "date" then
            value = utils.format_date(value)
        end
        local vt = {{label .. ": ", "OctoDetailsLabel"}}
        if kind == "label" then
            vim.list_extend(vt, bubbles.make_label_bubble(value.name, value.color, {right_margin_width = 1}))
        elseif kind == "labels" then
            for _, v in ipairs(value) do
                vim.list_extend(vt, bubbles.make_label_bubble(v.name, v.color, {right_margin_width = 1}))
            end
        else
            vim.list_extend(vt, {{tostring(value), "OctoDetailsValue"}})
        end
        table.insert(details, vt)
    end
end

function M.write_title(bufnr, title, line)
    local title_mark = M.write_block(bufnr, {title, ""}, line, true)
    vim.api.nvim_buf_add_highlight(bufnr, -1, "OctoIssueTitle", 0, 0, -1)
    local buffer = octo_buffers[bufnr]
    if buffer then
        buffer.titleMetadata =
            TitleMetadata:new(
            {
                savedBody = title,
                body = title,
                dirty = false,
                extmark = tonumber(title_mark)
            }
        )
    end
end

function M.write_mr_details(bufnr, mr, update)
    -- clear virtual texts
    vim.api.nvim_buf_clear_namespace(bufnr, constants.OCTO_DETAILS_VT_NS, 0, -1)

    local details = {}
    local buffer = octo_buffers[bufnr]

    -- repo
    if buffer then
        local repo_vt = {
            {"Repo: ", "OctoDetailsLabel"},
            {" " .. buffer.repo, "OctoDetailsValue"} -- TODO: change to gitlab icon
        }
        table.insert(details, repo_vt)
    end

    -- author
    local author_vt = {{"Created by: ", "OctoDetailsLabel"}}
    local conf = config.get_config()
    local author_bubble = bubbles.make_user_bubble(mr.author.name, mr.author.username == conf.username)

    vim.list_extend(author_vt, author_bubble)
    table.insert(details, author_vt)

    add_details_line(details, "Created", mr.createdAt, "date")
    if mr.state == "closed" then -- TODO:make enums for those states
        if mr.closedAt then -- closedAt is only for issues not for MRs
            add_details_line(details, "Closed", mr.closedAt, "date")
        end
    else
        add_details_line(details, "Updated", mr.updatedAt, "date")
    end

    -- assignees
    local assignees_vt = {
        {"Assignees: ", "OctoDetailsLabel"}
    }
    if mr.assignees and #mr.assignees.nodes > 0 then
        for _, assignee in ipairs(mr.assignees.nodes) do
            local isViewer = true
            local user_bubble = bubbles.make_user_bubble(assignee.name, isViewer, {margin_width = 1})
            vim.list_extend(assignees_vt, user_bubble)
        end
    else
        table.insert(assignees_vt, {"No one assigned ", "OctoMissingDetails"})
    end
    table.insert(details, assignees_vt)

    -- labels
    local labels_vt = {
        {"Labels: ", "OctoDetailsLabel"}
    }
    if #mr.labels.nodes > 0 then
        for _, label in ipairs(mr.labels.nodes) do
            local label_bubble = bubbles.make_label_bubble(label.title, label.color, {right_margin_width = 1})
            vim.list_extend(labels_vt, label_bubble)
        end
    else
        table.insert(labels_vt, {"None yet", "OctoMissingDetails"})
    end
    table.insert(details, labels_vt)

    -- additional details for pull requests
    if mr.diffStatsSummary.fileCount then
        -- reviewers
        local reviewers = {}
        local collect_reviewer = function(name, state)
            --if vim.g.octo_viewer ~= name then
            if not reviewers[name] then
                reviewers[name] = {state}
            else
                local states = reviewers[name]
                if not vim.tbl_contains(states, state) then
                    table.insert(states, state)
                end
                reviewers[name] = states
            end
            --end
        end
        -- collect reviewers
        for _, reviewer in ipairs(mr.reviewers.nodes) do
            -- TODO: review states are pretty different between GH and GL
            local state = "COMMENTED"
            if reviewer.mergeRequestInteraction.reviewState == "UNREVIEWED" then
                state = "REVIEW_REQUIRED"
            end
            collect_reviewer(reviewer.name, state)
        end

        -- collect assignees
        for _, assignee in ipairs(mr.assignees.nodes) do
            collect_reviewer(assignee.name, "PENDING")
        end

        local reviewers_vt = {
            {"Reviewers: ", "OctoDetailsLabel"}
        }
        if #vim.tbl_keys(reviewers) > 0 then
            for _, name in ipairs(vim.tbl_keys(reviewers)) do
                local strongest_review = utils.calculate_strongest_review_state(reviewers[name])
                local reviewer_vt = {
                    {name, "OctoUser"},
                    {" "},
                    {utils.state_icon_map[strongest_review], utils.state_hl_map[strongest_review]},
                    {" "}
                }
                vim.list_extend(reviewers_vt, reviewer_vt)
            end
        else
            table.insert(reviewers_vt, {"No reviewers", "OctoMissingDetails"})
        end
        table.insert(details, reviewers_vt)

        -- merged_by
        if mr.state == "merged" then
            local merged_by_vt = {{"Merged by: ", "OctoDetailsLabel"}}
            local name = mr.mergeUser.name
            local is_viewer = conf.username == name
            local user_bubble = bubbles.make_user_bubble(name, is_viewer)
            vim.list_extend(merged_by_vt, user_bubble)
            table.insert(details, merged_by_vt)
        end

        -- from/into branches
        local branches_vt = {
            {"From: ", "OctoDetailsLabel"},
            {mr.sourceBranch, "OctoDetailsValue"},
            {" Into: ", "OctoDetailsLabel"},
            {mr.targetBranch, "OctoDetailsValue"}
        }
        table.insert(details, branches_vt)

        -- changes
        local changes_vt = {
            {"Commits: ", "OctoDetailsLabel"},
            {tostring(mr.commitCount), "OctoDetailsValue"},
            {" Changed files: ", "OctoDetailsLabel"},
            {tostring(mr.diffStatsSummary.fileCount), "OctoDetailsValue"},
            {" (", "OctoDetailsLabel"},
            {string.format("+%d ", mr.diffStatsSummary.additions), "OctoDiffstatAdditions"},
            {string.format("-%d ", mr.diffStatsSummary.deletions), "OctoDiffstatDeletions"}
        }
        local diffstat =
            utils.diffstat({additions = mr.diffStatsSummary.additions, deletions = mr.diffStatsSummary.deletions})
        if diffstat.additions > 0 then
            table.insert(changes_vt, {string.rep("■", diffstat.additions), "OctoDiffstatAdditions"})
        end
        if diffstat.deletions > 0 then
            table.insert(changes_vt, {string.rep("■", diffstat.deletions), "OctoDiffstatDeletions"})
        end
        if diffstat.neutral > 0 then
            table.insert(changes_vt, {string.rep("■", diffstat.neutral), "OctoDiffstatNeutral"})
        end
        table.insert(changes_vt, {")", "OctoDetailsLabel"})
        table.insert(details, changes_vt)
    end

    local line = 3
    -- write #details + empty lines
    -- because virt_text needs empty lines?
    if not update then
        local empty_lines = {}
        for _ = 1, #details + 1 do
            table.insert(empty_lines, "")
        end
        M.write_block(bufnr, empty_lines, line)
    end

    -- write details as virtual text
    for _, d in ipairs(details) do
        M.write_virtual_text(bufnr, constants.OCTO_DETAILS_VT_NS, line - 1, d)
        line = line + 1
    end
end

function M.write_mr_body(bufnr, mr, line)
    local body = vim.fn.trim(mr.description)
    if vim.startswith(body, constants.NO_BODY_MSG) or utils.is_blank(body) then
        body = " "
    end
    local description = body:gsub("\r\n", "\n")
    local lines = vim.split(description, "\n", true)
    vim.list_extend(lines, {""})
    local desc_mark = M.write_block(bufnr, lines, line, true)
    local buffer = octo_buffers[bufnr]
    if buffer then
        buffer.bodyMetadata =
            BodyMetadata:new(
            {
                savedBody = description,
                body = description,
                dirty = false,
                extmark = desc_mark,
                viewerCanUpdate = mr.userPermissions.updateMergeRequest
            }
        )
    end
end

function M.write_state(bufnr, state, number)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local buffer = octo_buffers[bufnr]
    state = state or buffer.node.state
    number = number or buffer.number

    -- clear virtual texts
    vim.api.nvim_buf_clear_namespace(bufnr, constants.OCTO_TITLE_VT_NS, 0, -1)

    -- title virtual text
    local title_vt = {
        {tostring(number), "OctoIssueId"},
        {string.format(" [%s] ", state), utils.state_hl_map[state]}
    }

    -- PR virtual text
    if buffer and buffer:isPullRequest() then
        if buffer.node.isDraft then
            table.insert(title_vt, {"[DRAFT] ", "OctoIssueId"})
        end
    end
    vim.api.nvim_buf_set_virtual_text(bufnr, constants.OCTO_TITLE_VT_NS, 0, title_vt, {})
end

-- M.write_discussions(bufnr, merge_request.discussions.nodes)
function M.write_user_note(bufnr, note, line)
    local start_line = line
    -- header: author and date
    local header_vt = {
        {note.author.name .. " ", "OctoDetailsLabel"},
        {note.author.username .. " ", "OctoUser"},
        {" " .. utils.format_date(note.createdAt), "OctoDate"}
    }
    -- local author_bubble = bubbles.make_user_bubble(note.author.name, false) -- is_viewer=false, only affects highlight
    -- vim.list_extend(author_vt, author_bubble)
    local comment_vt_ns = vim.api.nvim_create_namespace("")
    M.write_block(bufnr, {""}, line)
    M.write_virtual_text(bufnr, comment_vt_ns, line - 1, header_vt)
    M.write_block(bufnr, {""}, line + 1)
    line = line + 2
    -- body
    local note_body = vim.fn.trim(string.gsub(note.body, "\r\n", "\n"))
    if vim.startswith(note_body, constants.NO_BODY_MSG) or utils.is_blank(note_body) then
        note_body = " "
    end
    local content = vim.split(note_body, "\n", true)
    vim.list_extend(content, {""})
    local comment_mark = M.write_block(bufnr, content, line, true)
    line = line + #content

    -- Note: here missing the comment metadata part used in octo

    return start_line, line
end

function M.write_system_note(bufnr, note, line, extended)
    local start_line = line
    local icon_names = {}
    icon_names["user"] = "🧑"
    icon_names["commit"] = ""
    icon_names["pencil-square"] = "✏️"
    icon_names["fork"] = "🇾"
    icon_names["comment"] = "📝"
    icon_names["git-merge"] = "↗️"
    icon_names["approval"] = "✅"

    -- extract and clean body
    local note_body = vim.fn.trim(string.gsub(note.body, "\r\n", "\n"))
    if vim.startswith(note_body, constants.NO_BODY_MSG) or utils.is_blank(note_body) then
        note_body = " "
    end
    local content = vim.split(note_body, "\n", true)
    vim.list_extend(content, {""})

    -- create note header virtual text
    local note_vt = {
        {" " .. icon_names[note.systemNoteIconName] .. " ", "OctoUser"},
        {" " .. note.author.name, "OctoUser"},
        {" " .. content[1], "OctoUser"}
    }
    table.remove(content, 1) -- remove first as already used
    local comment_vt_ns = vim.api.nvim_create_namespace("")
    M.write_block(bufnr, {""}, line)
    M.write_virtual_text(bufnr, comment_vt_ns, line - 1, note_vt)
    M.write_block(bufnr, {""}, line + 1)

    line = line + 1

    -- rest of body if needed
    if extended then
        for _, value in ipairs(content) do
            M.write_block(bufnr, {""}, line)
            M.write_virtual_text(bufnr, comment_vt_ns, line - 1, {{value, "OctoUser"}})
            line = line + 1
        end
    end

    return start_line, line
end

function M.write_discussion(bufnr, line, discussion)
    local start_line = line
    local is_system = discussion.notes.nodes[1].system

    if not is_system then
        -- NTH: insert a thread box for threads (user notes)
        local delimiter = string.rep("_", 40) .. "Thread Start" .. string.rep("_", 40)
        local mark = M.write_block(bufnr, delimiter, line)
        M.write_block(bufnr, "", line + 1)
        line = line + 2
    else
        M.write_block(bufnr, "", line)
        line = line + 1
    end

    for _, note in ipairs(discussion.notes.nodes) do
        if note.system then
            _, line = M.write_system_note(bufnr, note, line)
        else
            _, line = M.write_user_note(bufnr, note, line)
        end
    end
    if not is_system then
        -- NTH: insert a thread box for threads (user notes)
        local delimiter = string.rep("_", 40) .. "Thread End" .. string.rep("_", 40)
        local mark = M.write_block(bufnr, delimiter, line)
        M.write_block(bufnr, "", line + 1)
        line = line + 2
    end
    return start_line, vim.api.nvim_buf_line_count(bufnr)
end

function M.write_discussions(bufnr, discussions, line)
    M.write_block(bufnr, "", line) -- write initial additional line in case first is VT
    local start_line = line
    for _, discussion in ipairs(discussions) do
        _, line = M.write_discussion(bufnr, line, discussion)
    end
    return start_line, line
end

return M

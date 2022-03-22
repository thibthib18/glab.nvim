local BodyMetadata = require "octo.model.body-metadata".BodyMetadata
local TitleMetadata = require "octo.model.title-metadata".TitleMetadata
local bubbles = require "octo.ui.bubbles"
local constants = require "octo.constants"
local utils = require "octo.utils"
local config = require("glab-nvim.config")

require "octo.colors".setup()

octo_buffers = {}

local M = {}

function M.write_virtual_text(bufnr, ns, line, chunks, mode)
    mode = mode or "extmark"
    local ok
    if mode == "extmark" then
        ok = pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, line, 0, {virt_text = chunks, virt_text_pos = "overlay"})
    elseif mode == "vt" then
        ok = pcall(vim.api.nvim_buf_set_virtual_text, bufnr, ns, line, chunks, {})
    end
    --if not ok then
    --print(vim.inspect(chunks))
    --end
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
    local empty_lines = {}
    for _ = 1, #details + 1 do
        table.insert(empty_lines, "")
    end
    if not update then
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

return M

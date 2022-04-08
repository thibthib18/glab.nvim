--[[
-- Table of various graphql queries
-- Returns a function that takes:
-- * a query name (e.g. `merge_requests_query`)
-- * its arguments (e.g. repo, number, etc..)
-- returns the query formatted with these arguments
--]]
local M = {}

M.merge_requests_query =
    [[
query($endCursor: String) {
  project(fullPath: "%s/%s"){
    mergeRequests(first: 10, after: $endCursor, %s) {
      nodes {
        iid
        title
        webUrl
        state
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}
]]

M.merge_request_query =
    [[
query($endCursor: String) {
  project(fullPath: "%s/%s"){
    mergeRequest(iid: "%d") {
      id
      iid
      state
      title
      commitCount
      description
      createdAt
      updatedAt
      sourceBranch
      targetBranch
      discussions(first: 100, after: $endCursor) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          id
          resolved
          notes {
            nodes {
              createdAt
              author {
                name
                username
              }
              body
              system
              systemNoteIconName
              position {
                positionType
                newLine
                oldLine
                filePath
              }
              userPermissions {
                createNote
              }
            }
          }
        }
      }
      diffStatsSummary {
        additions
        deletions
        changes
        fileCount
      }
      webUrl
      assignees(first: 10){
        nodes {
          id
          name
          username
        }
      }
      userPermissions {
        updateMergeRequest
      }
      diffStats{
        path
        additions
        deletions
      }
      mergeUser {
        id
      }
      participants(first:10) {
        nodes {
          id
        }
      }
      commitCount

      author {
        id
        name
        username
      }
      labels{
        nodes {
          title
          color
        }
      }
      reviewers(first:10){
        nodes {
          name
          mergeRequestInteraction {
            reviewState
          }
        }
      }
      mergeUser {
        name
      }
    }
  }
}
]]

local function escape_chars(string)
    local escaped, _ =
        string.gsub(
        string,
        '["\\]',
        {
            ['"'] = '\\"',
            ["\\"] = "\\\\"
        }
    )
    return escaped
end

return function(query, ...)
    local opts = {escape = true}
    for _, v in ipairs {...} do
        if type(v) == "table" then
            opts = vim.tbl_deep_extend("force", opts, v)
            break
        end
    end
    local escaped = {}
    for _, v in ipairs {...} do
        if type(v) == "string" and opts.escape then
            local encoded = escape_chars(v)
            table.insert(escaped, encoded)
        else
            table.insert(escaped, v)
        end
    end
    return string.format(M[query], unpack(escaped))
end

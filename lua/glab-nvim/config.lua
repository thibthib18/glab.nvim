local M = {}

M.config = {
  provider_hostname = "",
  username = "thibthib",
}

function M.get_config()
  return M.config
end

local function split(text, delimiter)
  local chunks = {}
  for chunk in string.gmatch(text, "([^" .. delimiter .. "]+)") do
    table.insert(chunks, chunk)
  end
  return chunks
end

local function get_project_from_url(url)
  local isHttp = string.match(url, 'https://') ~= nil
  if isHttp then
    local chunks = split(url, '/')
    print(vim.inspect(chunks))
    local host = chunks[2]
    if host ~= 'gitlab.com' then
      error("Non Gitlab projects aren't supported")
    end
    local owner = chunks[3]
    local project_git = chunks[4]
    local project_name = string.match(project_git, '(.*)%.git')
    print(host, owner, project_name)
    return { host = host, owner = owner, name = project_name }
  else
    local _, rest = unpack(split(url, '@'))
    local host, rest = unpack(split(rest, ':'))
    local owner, project_git = unpack(split(rest, '/'))
    local project_name = string.match(project_git, '(.*)%.git')
    return { host = host, owner = owner, name = project_name }
  end
end

function M.get_project()
  local command = 'git config --get remote.origin.url'
  local url = vim.fn.system(command)
  return get_project_from_url(url)
end

return M

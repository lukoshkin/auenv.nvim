local json = require "json"
local base_prefix = require("auenv.core").base_prefix
local M = {}

local function shellcmd_capture(cmd)
  --- 'r' is the default mode.
  local f = assert(io.popen(cmd, "r"))
  local s = assert(f:read "*a")
  f:close()

  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  s = string.gsub(s, "[\n\r]+", " ")
  return s
end

local function conda_envs_list()
  local s = shellcmd_capture "conda env list --json"
  local bp = base_prefix()

  local envs_raw = json.decode(s)["envs"]
  local envs = {}

  for _, e in pairs(envs_raw) do
    e = e:gsub("^" .. bp, "")
    e = e:gsub("^/envs/", "")
    e = e:match "%S+" or "base"
    table.insert(envs, e)
  end

  return envs
end

local function word_count(sentence)
  local cnt = 0
  for _ in sentence:gmatch "%S+%s+" do
    cnt = cnt + 1
  end
  return cnt
end

function M.tab_completion(arg_lead, whole_line)
  if whole_line:match "^%s*AuEnv%s+set%s+" then
    if word_count(whole_line) > 2 then
      return {}
    end
    return vim.tbl_filter(function(env)
      return env:match("^" .. arg_lead)
    end, conda_envs_list())
  end
  if word_count(whole_line) > 1 then
    return {}
  end

  arg_lead = arg_lead:match "^%s*(.-)%s*$"
  local api_cmds = require("auenv.api").possible_cmds
  local opts = vim.tbl_filter(function(cmd)
    return cmd:match("^" .. arg_lead)
  end, api_cmds)
  return opts
end

return M

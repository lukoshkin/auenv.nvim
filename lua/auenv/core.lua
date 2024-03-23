local fn = vim.fn
local ve = vim.env
local api = vim.api

local json = require "json"
local lspconf = require "lspconfig.configs"

local auenv = {}
auenv._lsp_set = {}

function auenv.read()
  local fd = io.open(auenv.datafile)

  if not fd then
    auenv.dict = {}
    return
  end

  auenv.dict = json.decode(fd:read "*a")
end

function auenv.find(path2check)
  local assets = { env = nil, i = nil, full_match = nil }
  local maxpath = ""

  for env, paths in pairs(auenv.dict) do
    for i, path in ipairs(paths) do
      if #path <= #path2check then
        if path2check:sub(1, #path) == path then
          if #path > #maxpath then
            maxpath = path
            assets.env = env
            assets.i = i
          end
        end
      end
    end
  end

  assets.full_match = maxpath == path2check
  return assets
end

function auenv.init_term()
  --- Opening terminal with bterm.nvim starts a non-interactive shell,
  --- that is, rc-files are not sourced, and 'base' conda env is always
  --- activated on startup.

  if ve.CONDA_DEFAULT_ENV == "base" then
    return
  end

  local ok, tji = pcall(api.nvim_buf_get_var, 0, "terminal_job_id")
  if not ok then
    return
  end

  local cmd = "conda activate " .. ve.CONDA_DEFAULT_ENV
  api.nvim_chan_send(tji, cmd .. " && clear\n")
end

function auenv.add(env)
  if env == nil then
    --- Base case scenario:
    --- :AuEnv set some_env
    --- :AuEnv add
    env = ve.CONDA_DEFAULT_ENV
  end

  if env == "base" then
    print "Do not register 'base' environment."
    return
  end

  local path = fn.input(
    "Activate " .. env .. " when loading the content of ",
    vim.loop.cwd(),
    "file"
  )
  print " " -- required to break the line after the prompt

  if path == "" then
    print "You haven't entered anything!"
    return
  elseif path == "." then
    path = fn.expand "%:p:h"
  elseif path == ".." then
    path = fn.expand "%:p:h:h"
  end

  local assets = auenv.find(path)

  if assets.full_match then
    if assets.env == env then
      print "This rule is already in effect!"
      return
    end

    print(
      "For the folder " .. path .. ", " .. assets.env .. " is already in use."
    )
    local yn = fn.input("Override " .. assets.env .. "? [yN]: ")
    print " " -- required to break the line after the prompt

    --- better than `yn:lower() == 'y'` ─ less work on average
    if yn ~= "y" and yn ~= "Y" then
      print "Aborted."
      return
    end

    auenv.remove(path)
  end

  auenv.dict[env] = auenv.dict[env] or {}
  table.insert(auenv.dict[env], path)
  print("New env added for the folder " .. path)
  auenv.sync()
end

function auenv.base_prefix()
  local prefix = os.getenv "CONDA_PREFIX_1"
  if prefix == nil then
    prefix = os.getenv "CONDA_PREFIX"
    --- Make sure you get the desired result.
    --- This action is only needed if you change CONDA_PREFIX
    --- in the `auenv.sync` fn call and do not set CONDA_PREFIX_1.
    -- prefix = prefix:gsub('/envs/%S+', '')
  end

  return prefix
end

function auenv.set(env)
  local bp = auenv.base_prefix()
  local env_prefix = bp .. "/envs/" .. env
  ve.PATH = ve.PATH:gsub(ve.CONDA_PREFIX .. "/bin", env_prefix .. "/bin")

  ve.CONDA_DEFAULT_ENV = env
  ve.CONDA_PREFIX = env_prefix
  ve.CONDA_PREFIX_1 = bp
end

function auenv.unset()
  local bp = auenv.base_prefix()
  ve.PATH = ve.PATH:gsub(ve.CONDA_PREFIX .. "/bin", bp .. "/bin")

  ve.CONDA_DEFAULT_ENV = "base"
  ve.CONDA_PREFIX = bp
  ve.CONDA_PREFIX_1 = nil
end

function auenv.sync()
  if vim.b.auenv_manually_set_env ~= nil then
    if ve.CONDA_DEFAULT_ENV ~= vim.b.auenv_manually_set_env then
      auenv.set(vim.b.auenv_manually_set_env)
    end
    return
  end

  local parent_dir = fn.expand "%:p:h"
  local assets = auenv.find(parent_dir)
  local bh = api.nvim_win_get_buf(0)

  local env = assets.env
  if env ~= nil then
    if env ~= ve.CONDA_DEFAULT_ENV then
      auenv.set(env)
      auenv._lsp_set[bh] = false
      --- Mark for diagnostics update.
    end
  else
    if ve.CONDA_DEFAULT_ENV ~= "base" then
      auenv.unset()
      auenv._lsp_set[bh] = false
      --- Mark for diagnostics update.
    end
  end

  if not auenv._lsp_set[bh] then
    auenv.update_diagnostics()
  end
end

local function is_buf_type_python()
  return api.nvim_buf_get_option(0, "filetype") == "python"
end

function auenv.update_diagnostics()
  --- Do nothing if lspconfig is not set up.
  if lspconf == nil then
    return
  end

  local bufname = api.nvim_buf_get_name(0)
  local clients = vim.lsp.buf_get_clients(0)

  if next(clients) == nil then
    return
  end

  --- A modified version of ':LspRestart' function.
  --- NOTE: Previously, 'https://github.com/neovim/nvim-lspconfig' implemented
  --- ':LspRestart' with the use of `defer_fn`, now they switched to
  --- `uv.new_timer` and `schedule_wrap`.
  for _, client in pairs(clients) do
    --- We don't want to restart python LSP clients in non-python buffers,
    --- since it will lead to pollution by irrelevant diagnostics.
    if not is_buf_type_python() then
      --- Since a user can switch to another window, we check this
      --- condition within the for loop, before restarting each client.
      return
    end

    local handler = lspconf[client.name]
    --- Similarly, we don't want to get for Python code diagnostics
    --- of LSP clients targeting other filetypes. Moreover, 'auenv.nvim'
    --- is intended for better in-Vim management of Python environments,
    --- therefore, it more focused on correctly rendering diagnostics
    --- of Python code specifically.
    if handler and fn.index(handler.filetypes, "python") >= 0 then
      client.stop()
      vim.defer_fn(function()
        if is_buf_type_python() then
          handler.launch()
        end
      end, 500)
    end
  end

  vim.defer_fn(function()
    --- Clear highlights, extmarks, virtual text.
    api.nvim_buf_clear_namespace(0, -1, 0, -1)
    --- If a user have not just switched to another
    --- buffer or begun editing within 500ms, then
    if
      bufname == api.nvim_buf_get_name(0)
      and fn.getbufinfo("%")[1].changed == 0
    then
      --- Reload the file (thus, refreshing its diagnostics).
      --- May be relevant only to LSP clients configured via null-ls.
      vim.cmd ":edit"
      auenv._lsp_set[api.nvim_win_get_buf(0)] = true
    end
  end, 500)
end

function auenv.remove(path)
  --- Either a user specifies an abs path or nothing.
  if path == nil then
    path = fn.expand "%:p:h"
  end

  local assets = auenv.find(path)
  local env, i = assets.env, assets.i

  if env == nil then
    print("No registered env for " .. path)
    return
  end

  -- auenv.dict[env][i] = nil
  --- `table.remove` reindexes elements after removal. This is what we need,
  --- but NOTE: it deteriorates efficiency for big arrays.
  table.remove(auenv.dict[env], i)
  auenv.sync()
end

function auenv.write()
  local str = json.encode(auenv.dict)
  local fd = assert(io.open(auenv.datafile, "w"))
  --- `init.lua` takes care of the parent dir's creation.
  fd:write(str)
  fd:close()
end

return auenv

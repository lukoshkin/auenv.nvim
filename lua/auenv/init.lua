local api = vim.api
local fn = vim.fn

local auenv = require'auenv.core'
local M = {}


local function auenv_api (spec)
  local cmd = spec.fargs[1]
  local arg = spec.fargs[2]
  --- More robust than using `unpack`
  --- which is also `table.unpack` since Lua 5.2.

  local requires_arg = { 'add', 'edit', 'set' }

  if vim.tbl_contains(requires_arg, cmd)
      and #spec.fargs ~= 2 then
    print("AuEnv's " .. cmd .. '-command requires exactly one argument.')
    print('Usage: AuEnv <'.. cmd .. '> <arg>')
    return
  end

  if cmd == 'add' then
    auenv.add(arg)
  elseif cmd == 'rm' then
    auenv.remove(arg)
  elseif cmd == 'print' then
    print(vim.inspect(auenv.dict))
  elseif cmd == 'edit' then
    vim.cmd(':edit ' .. auenv.datafile)

  elseif cmd == 'set' then
    if arg == 'base' then
      auenv.unset()
      return
    end

    auenv.set(arg)
    vim.b.auenv_manually_set_env = arg
    auenv.update_diagnostics()
    --- Force-update diagnostics.

  elseif cmd == 'unset' then
    auenv.unset()
    vim.b.auenv_manually_set_env = 'base'
    auenv.update_diagnostics()
    --- Force-update diagnostics.
  else
    print(string.format('No API for %s command', cmd))
  end
end


api.nvim_create_user_command('AuEnv', auenv_api, {nargs='+'})
local aug_ae = api.nvim_create_augroup('AuEnv', {clear=true})

api.nvim_create_autocmd('BufEnter', {
  callback = auenv.sync,
  pattern = '*.py',
  group = aug_ae,
})

api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    auenv.write()
  end,
  group = aug_ae,
})

vim.api.nvim_create_autocmd('TermOpen', {
  callback = function()
    auenv.init_term()
  end,
  group = aug_ae,
})


function M.setup (conf)
  conf = conf or {}

  local default_path = fn.stdpath'data' .. '/auenv/envs.json'
  local parent = fn.fnamemodify(default_path, ':h')
  os.execute('mkdir -p ' .. parent)

  auenv.datafile = conf.auenv_datafile or default_path
  auenv._wellcoming_env = vim.env.CONDA_DEFAULT_ENV
  auenv.read()
end


return M

local api = vim.api
local fn = vim.fn

local auenv = require'auenv.core'
local M = {}


local function auenv_api (spec)
  local cmd = spec.fargs[1]
  local arg = spec.fargs[2]
  --- More robust than using `unpack`
  --- which is also `table.unpack` since Lua 5.2.

  --- In case, there are more commands
  --- requiring an arg, as it was before :)
  local requires_arg = { 'set' }

  if vim.tbl_contains(requires_arg, cmd) and #spec.fargs ~= 2 then
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
    auenv.write() -- Update with `auenv.dict`.
    vim.cmd(':edit ' .. auenv.datafile)

  elseif cmd == 'set' and arg ~= 'base' then
    auenv.set(arg)
    vim.b.auenv_manually_set_env = arg
    auenv.update_diagnostics()
    --- Force-update diagnostics.

  elseif cmd == 'unset' or cmd == 'set' then
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

--- Update `auenv.dict` after editing `auenv.datafile`.
api.nvim_create_autocmd('BufWritePost', {
  callback = auenv.read,
  pattern = auenv.datafile,
  group = aug_ae,
})

api.nvim_create_autocmd('VimLeavePre', {
  callback = auenv.write,
  group = aug_ae,
})

vim.api.nvim_create_autocmd('TermOpen', {
  callback = auenv.init_term,
  group = aug_ae,
})


function M.setup (conf)
  conf = conf or {}

  local default_path = fn.stdpath'data' .. '/auenv/envs.json'
  local parent = fn.fnamemodify(default_path, ':h')
  os.execute('mkdir -p ' .. parent)

  auenv.datafile = conf.auenv_datafile or default_path
  auenv.read()
end


return M

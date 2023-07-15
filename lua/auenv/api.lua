local auenv = require'auenv.core'
local M = {}

M.requires_arg = { 'set' }
M.possible_cmds = {
  'add',
  'rm',
  'print',
  'edit',
  'set',
  'unset',
}


function M.auenv_api (spec)
  local cmd = spec.fargs[1]
  local arg = spec.fargs[2]
  --- More robust than using `unpack`
  --- which is also `table.unpack` since Lua 5.2.

  if vim.tbl_contains(M.requires_arg, cmd) and #spec.fargs ~= 2 then
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


return M

local auenv = require'auenv.core'
local M = {}


local function auenv_api (spec)
  local cmd = spec.fargs[1]
  local arg = spec.fargs[2]
  --- More robust than using `unpack`
  --- which is also `table.unpack` since Lua 5.2.

  if cmd == 'add' then
    if #spec.fargs ~= 2 then
      print("AuEnv's add-command requires exactly one argument.")
      print('Usage: AuEnv add <env>')
      return
    end

    auenv.add(arg)
  elseif cmd == 'rm' then
    auenv.remove(arg)
  elseif cmd == 'print' then
    print(vim.inspect(auenv.dict))
  elseif cmd == 'edit' then
    vim.cmd(':edit ' .. auenv.datafile)
  else
    print(string.format('No API for %s command', cmd))
  end
end


vim.api.nvim_create_user_command('AuEnv', auenv_api, {nargs='+'})
local aug_ae = vim.api.nvim_create_augroup('AuEnv', {clear=true})

vim.api.nvim_create_autocmd('BufEnter', {
  callback = auenv.sync,
  pattern = '*.py',
  group = aug_ae,
})

vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = function()
    auenv.write()
  end,
  group = aug_ae,
})


function M.setup (conf)
  conf = conf or {}

  local default_opt = vim.fn.stdpath'data' .. '/auenv/envs.json'
  auenv.datafile = conf.auenv_datafile or default_opt
  auenv.read()
end

return M

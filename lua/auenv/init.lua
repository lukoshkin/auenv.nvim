local auenv = require'auenv.core'
local M = {}

local function auenv_api (opts)
  local words = {}
  for word in opts.args:gmatch('%S+') do
    table.insert(words, word)
  end

  if #words ~= 2 then
    print('AuEnv requires exactly 2 parameters.')
    print('Usage: AuEnv <add/rm> <env/path>')
    return
  end

  local cmd, arg = unpack(words)
  if cmd == 'add' then auenv.add(arg)
  elseif cmd == 'rm' then auenv.add(arg)
  else print(string.format('No API for %s command', cmd))
  end
end


--- For a plugin to work, it is not necessary to create a setup function - and
--- wrap it up into a module like it is done here. The key point is to specify
--- `setup` keyword in - the plugins installation with packer:
---
---   `config = function () require'plugin_name'.setup() end`
---
--- Here it's used only for structuring the code better.
function M.setup ()
  local default_opt = vim.fn.stdpath 'data' .. '/auenv/envs.json'
  vim.g.auenv_file = vim.g.auenv_file or default_opt
  vim.g.auenv_dict = auenv.read(vim.g.auenv_file)

  vim.api.nvim_create_user_command('AuEnv', auenv_api, {nargs=1})
  local aug_ae = vim.api.nvim_create_augroup('AuEnv', {clear=true})

  vim.api.nvim_create_autocmd('BufEnter,WinEnter', {
    callback = auenv.sync,
    pattern = '*.py',
    group = aug_ae,
  })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      auenv.write(vim.g.auenv_file)
    end,
    group = aug_ae,
  })
end

return M

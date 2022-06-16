local auenv = require'core'

local aug_ae = vim.api.nvim_create_augroup('AuEnv', {clear=true})
vim.api.nvim_create_autocmd('VimEnter', {
  callback = auenv.read,
  pattern = 'python',
  group = aug_ae,
})

vim.api.nvim_create_autocmd({'BufWinEnter', 'WinEnter'}, {
  callback = auenv.auenv,
  pattern = 'python',
  group = aug_ae,
})

vim.api.nvim_create_autocmd('VimLeavePre', {
  callback = auenv.write,
  pattern = 'python',
  group = aug_ae,
})


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

vim.api.nvim_create_user_command('AuEnv', auenv_api, {nargs=1})

local api = vim.api
local fn = vim.fn

local auenv = require'auenv.core'
local M = {}


api.nvim_create_user_command('AuEnv',
  require'auenv.api'.auenv_api, {
  nargs='+', complete=require'auenv.completion'.tab_completion
})

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

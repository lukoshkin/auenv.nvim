local json = require'json'
local auenv = {}


function auenv.read (file)
  local fd = assert(io.open(file))
  vim.g.auenv_dict = json.decode(fd:read('*a'))
  auenv.dict = vim.g.auenv_dict or {} -- FIXME
end


function auenv.find (path2check)
  local cut = #path2check
  local assets = { env=nil, i=nil, full_match=nil }
  local maxpath = ''

  for env, paths in pairs(auenv.dict) do
    for i, path in ipairs(paths) do
      if #path <= cut then
        if path:sub(1, cut) == path2check then
          if #path > #maxpath then
            assets['env'] = env
            assets['i'] = i
            maxpath = path
          end
        end
      end
    end
  end

  assets['full_match'] = maxpath == path2check
  return assets
end


function auenv.add (env)
  if env == 'base' then
    print("Do not register 'base' environment.")
    return
  end

  local cwd = vim.fn.getcwd()
  local path = vim.fn.input(
    'Activate ' .. env .. ' when working with content of ', cwd)
  print(' ') -- required to break the line after the prompt

  if path == '' then
    print("You haven't entered anything!")
    return
  elseif path == '.' then
    path = vim.fn.expand('%:h')
  elseif path == '..' then
    path = vim.fn.expand('%:h:h')
  end

  local assets = auenv.find(path)

  if assets['full_match'] then
    print('For the folder ' .. path ..
      ', ' .. assets['env'] .. ' is already in use.')
    local yn = vim.fn.input('Override ' .. assets['env'] .. '? [yN]: ')
    print(' ') -- required to break the line after the prompt

    --- better than `yn:lower() == 'y'` ─ less work on average
    if yn ~= 'y' and yn ~= 'Y' then
      print('Aborted.')
      return
    end

    auenv.remove(path)
  end

  auenv.dict[env] = auenv.dict[env] or {}
  table.insert(auenv.dict[env], path)
  print('New env added for folder ' .. path)
end


function auenv.auenv ()
  local parent_dir = vim.fn.expand('%:h')
  local assets = auenv.find(parent_dir)

  local base_prefix = os.getenv('CONDA_PREFIX_1')
  if base_prefix == nil then
    base_prefix = os.getenv('CONDA_PREFIX')
  end

  local env = assets['env']
  if env ~= nil then
    if env ~= vim.env.CONDA_DEFAULT_ENV then
      if vim.env.CONDA_DEFAULT_ENV == 'base' then
        vim.env.PATH = vim.env.PATH:gsub(
          base_prefix .. 'bin',
          base_prefix .. 'envs/' .. env ..'/bin')
      else
        vim.env.PATH = vim.env.PATH:gsub(
          base_prefix .. 'envs/' .. vim.env.CONDA_DEFAULT_ENV .. '/bin',
          base_prefix .. 'envs/' .. env ..'/bin')
      end

      vim.env.CONDA_DEFAULT_ENV = env
    end
  else
    if vim.env.CONDA_DEFAULT_ENV ~= 'base' then
      vim.env.PATH = vim.env.PATH:gsub(
        base_prefix .. 'envs/' .. vim.env.CONDA_DEFAULT_ENV .. '/bin',
        base_prefix .. 'bin')


      vim.env.CONDA_DEFAULT_ENV = 'base'
    end
  end

  --- Probably it requries to restart LSP server.
  -- vim.lsp.stop_client(vim.lsp.get_active_clients())
  -- vim.cmd ':edit'
end


function auenv.remove (path)
  local assets = auenv.find(path)
  local env, i = assets['env'], assets['i']

  if env ~= nil then
    auenv.dict[env][i] = nil
  end
end


function auenv.write (fname)
  local str = json.encode(auenv.dict)
  local fd = assert(io.open(fname, 'w'))
  fd:write(str)
  fd:close()
end


---------------------------------
-- local function print_ae_dict()
--   for k, v in pairs(auenv.dict) do
--     print(k)
--     for i, p in ipairs(v) do
--       print(i, p)
--     end
--   end
-- end

return auenv

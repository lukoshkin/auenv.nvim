local lspconf = require'lspconfig.configs'
local json = require'auenv.json'
local auenv = {}


function auenv.read (file)
  local fd = assert(io.open(file))
  auenv.dict = json.decode(fd:read('*a')) or {}
  return auenv.dict
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
    path = vim.fn.expand('%:p:h')
  elseif path == '..' then
    path = vim.fn.expand('%:p:h:h')
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
  print('New env added for the folder ' .. path)
  auenv.sync()
end


local function base_prefix ()
  local prefix = os.getenv('CONDA_PREFIX_1')
  if prefix == nil then
    prefix = os.getenv('CONDA_PREFIX')
    --- Make sure you get the desired result.
    --- This action is only needed if you change CONDA_PREFIX
    --- in the `auenv.sync` function call.
    -- prefix = prefix:gsub('/envs/%S+', '')
  end

  return prefix
end


function auenv.sync ()
  local parent_dir = vim.fn.expand('%:p:h')
  local assets = auenv.find(parent_dir)

  local base_prefix = base_prefix()

  local env = assets['env']
  if env ~= nil then
    if env ~= vim.env.CONDA_DEFAULT_ENV then
      if vim.env.CONDA_DEFAULT_ENV == 'base' then
        vim.env.PATH = vim.env.PATH:gsub(
          base_prefix .. '/bin',
          base_prefix .. '/envs/' .. env ..'/bin')
      else
        vim.env.PATH = vim.env.PATH:gsub(
          base_prefix .. '/envs/' .. vim.env.CONDA_DEFAULT_ENV .. '/bin',
          base_prefix .. '/envs/' .. env ..'/bin')
      end

      vim.env.CONDA_DEFAULT_ENV = env
    end
  else
    if vim.env.CONDA_DEFAULT_ENV ~= 'base' then
      vim.env.PATH = vim.env.PATH:gsub(
        base_prefix .. '/envs/' .. vim.env.CONDA_DEFAULT_ENV .. '/bin',
        base_prefix .. '/bin')

      vim.env.CONDA_DEFAULT_ENV = 'base'
    end
  end

  if vim.b.auenv_lsp_set ~= true then
    auenv.update_diagnostics()
  end
end


function auenv.update_diagnostics ()
  --- Do nothing if lspconfig is not set up.
  if lspconf == nil then
    return
  end

  local bufname = vim.api.nvim_buf_get_name(0)

  --- A modified version of ':LspRestart' function.
  -- for _, client in pairs(vim.lsp.get_active_clients()) do
  for _, client in pairs(vim.lsp.buf_get_clients(0)) do
    --- We don't want to restart python LSP clients in non-python buffers,
    --- since it will lead to pollution by irrelevant diagnostics.
    if vim.api.nvim_buf_get_option(0, 'filetype') ~= 'python' then
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
    if handler and vim.fn.index(
      handler.filetypes, 'python') >= 0 then
      client.stop()
      vim.defer_fn(function()
        handler.launch()
      end, 500)
    end
  end

  vim.defer_fn(
    function ()
      --- If user haven't just switched to another buffer within 500ms
      --- (e.g., switching too quickly to the Telescope window leads to
      --- execution of ':e' on it; thus, requiring answer the prompt ─
      --- 'Save changes to "Untitled"?')
      if bufname == vim.api.nvim_buf_get_name(0) then
        --- Reload the file (thus, refreshing its diagnostics).
        vim.cmd ':edit'
        --- While it is refreshing, we have time to
        --- clear highlights, extmarks, virtual text.
        vim.api.nvim_buf_clear_namespace(0, -1, 0, -1)

        --- Don't hurry to set `auenv_lsp_set` flag.
        vim.defer_fn(function ()
          vim.b.auenv_lsp_set = true
        end, 100)
      end
    end, 500)
  --- If you can't get proper diagnostics, try to play
  --- with the delays in `defer_fn` calls.
end


function auenv.remove (path)
  --- Either a user specifies an abs path or nothing.
  if path == nil then
    path = vim.fn.expand('%:p:h')
  end

  local assets = auenv.find(path)
  local env, i = assets['env'], assets['i']

  if env == nil then
    print('No registered env for ' .. path)
    return
  end

  auenv.dict[env][i] = nil
  auenv.sync()
end


function auenv.write (file)
  local str = json.encode(auenv.dict)
  local fd = assert(io.open(file, 'w'))
  fd:write(str)
  fd:close()
end


return auenv

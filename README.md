# Conda Auto-Environment for Neovim

`AuEnv` automatically activates 'known' environments (see [usage
section](#usage)), thus making terminal sessions and buffer diagnostics more
relevant to a user project they work on.

`AuEnv` ensures that a terminal session opened from Vim will have a proper
conda environment. However, it does not guarantee that after it updates buffer
diagnostics and removes irrelevant ones, none of relevant will be removed. The
latter may depend on how well one sets up their LSP clients.


## Installation

With [**Packer**](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'rxi/json.lua',
  run = 'mkdir -p lua/json && mv json.lua lua/json/init.lua',
}

use {
  'lukoshkin/auenv.nvim',
  requires = 'rxi/json.lua',
  config = function ()
    require'auenv'.setup {
      --- The only available customization.
      -- auenv_datafile = /where/to/keep/dict/with/registered/envs
      --- By default, it is vim.fn.stdpath'data' .. '/auenv/envs.json'
    }
  end
}
```


## Usage

```vim
:AuEnv add <env_name>
:AuEnv rm [path]

" <env_name> is a name of an existing conda environment.
" If omitting `[path]`, the folder of the current buffer is used.
" To display the dict with the registered envs and edit it manually,
" one can use the following two commands.

:AuEnv print
:AuEnv edit

" To mannually change a conda environment
" (and freeze it for the current buffer), use

:AuEnv set <env_name>
:AuEnv unset                         " set to 'base'
:unlet b:auenv_manually_set_env      " unfreeze

" Deletion of keys that correspond to removed conda environments or
" those having empty dict values is done with

:AuEnv maintain
" (not implemented yet)
" Whether to name it 'prune' or 'maintain' is still debatable.
```

After registering a conda environment for some _path_ with `AuEnv`'s `add`
command, the environment will be activated automatically when opening any
Python file in the deepest directory of the _path_ hierarchy.

Remembering not a folder but exactly a file where the command was run is a
possible future enhancement (that currently is not available though easy to
add).

## Future Development

- [ ] `maintain` (or `prune`) command (see [usage](#usage))
- [ ] Integration with shell's `conda-autoenv`
- [ ] Per file environment (see [usage](#usage))
- [x] `set/unset` API commands
- [ ] Tab completion/expansion

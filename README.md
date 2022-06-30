# Conda Auto-Environment for Neovim

`AuEnv` automatically activates 'known' environments (see [usage
section](#usage)), thus making terminal sessions and buffer diagnostics more
relevant to a user project they work on.

`AuEnv` ensures that a terminal session opened from Vim will have a proper
conda environment. However, it does not guarantee that after it updates buffer
diagnostics and removes irrelevant ones, none of relevant will be removed.


## Installation

With [**packer**](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'lukoshkin/auenv.nvim',
  branch = 'develop',
  run = './install.sh',
  config = function ()
    require'auenv'.setup()
  end
}
```

**TODO:** Think on moving from `./install.sh` to keeping `json.lua` library as
a submodule.


## Usage

```vim
:AuEnv add <env_name>
:AuEnv rm [path]
:AuEnv edit

" The latter command is not implemented yet.
" <env_name> is a name of an existing conda environment.
" If omitting `[path]`, the folder of the current buffer is used.
```

After adding a conda environment with `AuEnv`'s `add` command, the environment
will be activated automatically when opening any Python file in a directory
that contains the file where the command was initially executed.

Remembering not a folder but exactly a file from which buffer the command was
run is a possible future enhancement (that currently is not available, though
easy to add).

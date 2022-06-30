#!/usr/bin/env bash

repo=https://github.com/rxi/json.lua.git
link=https://raw.githubusercontent.com/rxi/json.lua/master/json.lua
install_dir=lua/auenv/json.lua

if command -v curl > /dev/null; then
  curl -o $install_dir $link
elif command -v wget > /dev/null; then
  wget -O $install_dir $link
elif command -v git > /dev/null; then
  git clone $repo /tmp/json-lua
  cp /tmp/json-lua/json.lua $install_dir
else
  echo Unable to install with "$0"
  echo Download mannually or copy the content of
  echo -e "\n$link\n"
  echo and save it under the name $install_dir
fi

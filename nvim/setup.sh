#!/bin/bash

base_distribution=$(cat /etc/os-release | grep "ID_LIKE" | cut -d'=' -f2)
echo $base_distribution
if [[ base_distribution == 'arch' ]]; then
  packer_path="/usr/share/nvim/site/pack/packer"
else 
  packer_path="/home/$USER/.local/share/nvim/site/pack/packer"
fi
echo $packer_path

function check_packer_installation() {
  if [[ -d "$packer_path" ]]; then
    echo "Packer already installed"
  #  if [[ ! -d "$local_path" ]] && [[ ! -L $local_path ]]; then 
  #    [ ! -d "~/.local/share/nvim/site/pack" ] && mkdir ~/.local/share/nvim/site/pack
  #    ln -s $global_path $local_path
  #  fi
    packer_installed=1
  else 
    echo "Packer is not installed. Will attempt to install it"
    packer_installed=0
  fi
}

function install_packer() {
  if [[ $base_distribution == "arch" ]]; then
   # Check if arch package is installed
   echo 'Found arch-based distro. Will install packer from AUR using pacman'
   git clone https://aur.archlinux.org/nvim-packer-git.git
   cd nvim-packer-git
   makepkg -si
   cd .. && rm -rf nvim-packer-git
   sudo chmod -R 775 $packer_path
   local_dir="/home/$USER/.local/share/nvim/site/pack/packer" 
   [ -d $local_dir ] && rm -rf $local_dir 
   echo "Packer sucesfully installed!"
  else
   echo 'Found non arch-based distro. Will install packer from git'
   git clone --depth 1 https://github.com/wbthomason/packer.nvim "$packer_path"/start/packer.nvim
  fi
}

function install_ripgrep() {
  if [ ! -x "$(command -v rg)" ]; then
    echo "ripgrep command binary could not be found. Will install it"
    if [[ $base_distribution == 'arch' ]]; then
      pacman -S ripgrep
    else
      sudo apt-get install ripgrep
    fi
  else
    echo "ripgrep already installed."
  fi 
}

lsp_dir="/home/$USER/.local/share/language-servers"
[ ! -d $lsp_dir ] && mkdir $lsp_dir

function julia_lsp_setup() {
  if [ ! -x "$(command -v julia)" ]; then
    echo "julia binary could not be found"
  else 
    lsp_path="${lsp_dir}/julia"
    url="https://github.com/julia-vscode/LanguageServer.jl"
    if [[ ! -d $lsp_path ]]; then
      echo "Will clone julia language server repository into '$lsp_path'..."
      git clone $url $lsp_path
      julia --project=$lsp_path -e 'using Pkg; Pkg.add("LanguageServer")'
    fi
    cd $lsp_path
    if [[ ! $(git rev-parse HEAD) == $(git rev-parse @{u}) ]]; then
      echo "Changes detected on upstream branch for ${url}. Will pull them and rebuild julia language server."
      cd $lsp_path && git pull origin master
      julia --project=$lsp_path -e 'using Pkg; Pkg.update()'
    else 
      echo "No new upstream git changes for $url"
    fi
  fi
}

function bash_lsp_setup() {
  url="https://github.com/bash-lsp/bash-language-server"
  lsp_path="${lsp_dir}/bash"
  if [[ ! -x "$(command -v bash-language-server)" ]]; then
    echo "Will clone julia language server repository into '$lsp_path'..."
    git clone $url $lsp_path
    sudo npm i -g bash-language-server
  else
    echo "bash-language-server already installed."
  fi
  cd $lsp_path
  if [[ ! $(git rev-parse HEAD) == $(git rev-parse @{u}) ]]; then
    echo "Changes detected on upstream branch for ${url}. Will pull them and rebuild bash language server."
    cd $lsp_path && git pull origin master
    sudo npm i -g bash-language-server
  else 
    echo "No new upstream git changes for $url"
  fi
}

function lua_lsp_setup() {
  # Use package manager
  url="https://aur.archlinux.org/lua-language-server-git.git"
  lsp_path="${lsp_dir}/lua"
  if [[ ! -x "$(command -v lua-language-server)" ]]; then 
    if [[ $base_distribution == "arch" ]]; then 
      git clone $url $lsp_path
      cd $lsp_path
      makepkg -si
      ln -s "${lsp_path}/pkg/lua-language-server-git/usr/bin/lua-language-server" /home/$USER/.local/bin/lua-language-server
    else
      [ ! -x "$(command -v ninja)" ] && sudo apt install ninja-build
      git clone "https://github.com/sumneko/lua-language-server" $lsp_path
      cd $lsp_path
      git submodule update --init --recursive
      cd 3rd/luamake
      ./compile/install.sh
      cd ../..
      ./3rd/luamake/luamake rebuild
      [ -f "/home/$USER/.local/bin/lua-language-server" ] && rm -rf /home/$USER/.local/bin/lua-language-server
      cp -s $lsp_path/bin-Linux/lua-language-server /home/$USER/.local/bin/lua-language-server
    fi
  else 
    echo "lua-language-server already installed"
  fi
}

function go_lsp_setup() {
  if [[ ! -x "$(command -v gopls)" ]]; then
    go install golang.org/x/tools/gopls@latest
  else
    echo "go language server (gopls) already installed."
  fi
}


check_packer_installation
echo $packer_installed
if [[ packer_installed -eq 0 ]]; then 
  install_packer
fi
install_ripgrep
echo "Now enter nvim and run :PackerSync"
julia_lsp_setup
bash_lsp_setup
lua_lsp_setup
go_lsp_setup

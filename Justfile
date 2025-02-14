set shell := ["bash", "-c"]
set windows-shell := ["pwsh", "-Command"]

# Even in Windows, use XDG_DATA_HOME if it is set
local := if env_var("XDG_DATA_HOME") != "" {env_var("XDG_DATA_HOME")} \
    else if env_var("LOCALAPPDATA") != "" {env_var("LOCALAPPDATA")} \
    else if os() != "windows" {env_var("HOME") + "/.local/share"} \
    else {"C:\\Users\\" + env_var("USERNAME") + "\\AppData\\Local"}

rime_install := \
    if os() == "windows" {".\\rime-install.bat"} \
    else if os() == "macos" {"bash rime-install"} \
    else if os() == "linux" {"rime_frontend=fcitx5-rime bash rime-install"} \
    else {"echo 'Unsupported OS' && exit 1"}

[private]
default:
    @just --list

init:
    git remote add upstream https://github.com/amzxyz/rime_wanxiang_pro.git
sync:
    git fetch upstream
    git merge upstream/master

clone_plum:
    cd {{local}} && git clone https://github.com/rime/plum.git --depth=1

[windows]
install_rime:
    winget install --id=Rime.Weasel -e

[macos]
install_rime:
    command -v brew > /dev/null || echo "Make sure you have installed homebrew"
    brew install squirrel

[linux]
install_rime:
    sudo pacman -S fcitx5-rime

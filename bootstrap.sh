#!/bin/sh
#
# This script prepares a productive environment for a user.

set -e

DOTFILES_ROOT=$(pwd -P)

usage() {
  printf "usage: %s [aspect...] \n" $(basename $0)
  echo
  echo "aspects"
  echo
  echo "    system       adjust system defaults for productivity"
  echo "    homebrew     setup Homebrew and install bundled packages"
  echo "    dotfiles     setup dotfiles and install plugins"
  echo "    zsh          setup Zsh as login shell"
  echo
  echo "without any arguments, all aspects will be setup (in the above order)"
  echo
}

log() {
  yellow="\e[0;33m"
  magenta="\e[0;35m"
  red="\e[0;31m"
  reset="\e[0;0m"
  printf "$magenta>$red>$yellow>$reset %s\n" "$*" 1>&2
}

# Keeps sudo priviledge alive throughout the execution of this script.
enter_sudo_mode() {
  if ! sudo -n true 2> /dev/null; then
    log "please enter your password to maintain a sudo session"
    sudo -v
    while true; do
      sudo -n true
      sleep 60
      kill -0 "$$" || exit
    done 2>/dev/null &
  fi
}

setup_homebrew() {
  if which brew > /dev/null 2>&1; then
    log "upgrading existing Homebrew packages"
    brew upgrade
  elif which ruby > /dev/null 2>&1; then
    log "installing Homebrew"
    ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  else
    log "cannot install Homebrew (ruby not found)"
    exit 1
  fi
  log "installing bundled Homebrew packages"
  brew bundle "--file=$(dirname "$0")/Brewfile" || true
  brew cleanup
}

setup_zsh() {
  log "setting Zsh as login shell"
  zsh=$(which zsh)
  if ! fgrep -q "$zsh" /etc/shells; then
    log "adding $zsh to /etc/shells"
    echo "$zsh" | sudo tee -a /etc/shells > /dev/null
  fi
  sudo chsh -s "$zsh" $USER
}


link_file () {
  local src=$1 dst=$2

  local overwrite= backup= skip=
  local action=

  if [ -f "$dst" -o -d "$dst" -o -L "$dst" ]
  then

    if [ "$overwrite_all" == "false" ] && [ "$backup_all" == "false" ] && [ "$skip_all" == "false" ]
    then

      local currentSrc="$(readlink $dst)"

      if [ "$currentSrc" == "$src" ]
      then

        skip=true;

      else

        user "File already exists: $dst ($(basename "$src")), what do you want to do?\n\
        [s]kip, [S]kip all, [o]verwrite, [O]verwrite all, [b]ackup, [B]ackup all?"
        read -n 1 action

        case "$action" in
          o )
            overwrite=true;;
          O )
            overwrite_all=true;;
          b )
            backup=true;;
          B )
            backup_all=true;;
          s )
            skip=true;;
          S )
            skip_all=true;;
          * )
            ;;
        esac

      fi

    fi

    overwrite=${overwrite:-$overwrite_all}
    backup=${backup:-$backup_all}
    skip=${skip:-$skip_all}

    if [ "$overwrite" == "true" ]
    then
      rm -rf "$dst"
      success "removed $dst"
    fi

    if [ "$backup" == "true" ]
    then
      mv "$dst" "${dst}.backup"
      success "moved $dst to ${dst}.backup"
    fi

    if [ "$skip" == "true" ]
    then
      success "skipped $src"
    fi
  fi

  if [ "$skip" != "true" ]  # "false" or empty
  then
    ln -s "$1" "$2"
    success "linked $1 to $2"
  fi
}

install_dotfiles () {
  log 'installing dotfiles'

  local overwrite_all=false backup_all=false skip_all=false
  # log "$DOTFILES_ROOT/dotfiles"
  declare -a FILES_TO_SYMLINK=$(find -H "$DOTFILES_ROOT/dotfiles" -type f -maxdepth 1 -name ".*" -not -name .DS_Store -not -name .git -not -name .osx | sed -e 's|//|/|' | sed -e 's|./.|.|')

  for src in ${FILES_TO_SYMLINK[@]}
  do
    # log "$src"
    dst="$HOME/.$(basename "${src%.*}")"
    link_file "$src" "$dst"
  done
}

main() {
  if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
  fi
  command=$1
  if [ "$command" = "system" ] || [ -z "$command" ]; then
    log "performing software update"
    sudo softwareupdate -i -a > /dev/null 2>&1
    log "installing XCode comand line developer tools"
    xcode-select --install > /dev/null 2>&1 || true
  fi
  if [ "$command" = "homebrew" ] || [ -z "$command" ]; then
    setup_homebrew
  fi
  if [ "$command" = "dotfiles" ] || [ -z "$command" ]; then
    install_dotfiles
  fi
  if [ "$command" = "zsh" ] || [ -z "$command" ]; then
    setup_zsh
  fi
}

main "$@"
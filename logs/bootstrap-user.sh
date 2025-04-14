#!/usr/bin/env bash
set -euo pipefail

PYTHON_VERSION="3.11"
NEED_GROUP_REFRESH=false

info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

cleanup() {
  echo
  error "User bootstrap aborted."
  exit 1
}
trap cleanup INT TERM ERR

# ─── Prevent Misuse From /mnt/ ──────────────────────────────────
if [[ "$PWD" == /mnt/* ]]; then
  error "This script is running from a Windows-mounted path: $PWD"
  echo "Please run it from your Linux home directory:"
  echo "  cd ~ && ./bootstrap-user.sh"
  exit 1
fi

# ─── Install Tools ──────────────────────────────────────────────
install_mise() {
  if [ ! -x "$HOME/.local/bin/mise" ]; then
    info "Installing mise..."
    curl https://mise.run | bash
  else
    info "mise already installed."
  fi

  if ! grep -q 'mise activate' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo 'eval "$($HOME/.local/bin/mise activate bash)"' >> "$HOME/.bashrc"
  fi

  export PATH="$HOME/.local/bin:$PATH"
  eval "$($HOME/.local/bin/mise activate bash)"
}

install_python() {
  info "Installing Python $PYTHON_VERSION via mise..."
  mise install python@$PYTHON_VERSION
  mise use python@$PYTHON_VERSION
  mise use -g python@$PYTHON_VERSION

  # Refresh shims and shell environment
  hash -r
  eval "$($HOME/.local/bin/mise activate bash)"  # Apply shims to current shell session

  info "Upgrading pip using mise Python..."
  if ! command -v python &>/dev/null; then
    error "Python command not found after mise install. Check mise installation and shims."
    exit 1
  fi

  python -m ensurepip --upgrade
  python -m pip install --upgrade pip
  success "pip upgraded successfully."
}

install_pipx_and_ansible() {
  info "Installing pipx using upgraded pip..."
  python -m pip install --user pipx
  python -m pipx ensurepath

  export PATH="$HOME/.local/bin:$PATH"

  info "Installing Ansible via pipx..."
  pipx install ansible-core
  success "Ansible installed successfully with pipx."
}

add_user_to_docker_group() {
  if getent group docker &>/dev/null; then
    if id -nG "$USER" | grep -qw docker; then
      info "User '$USER' is already in the docker group."
    else
      info "Adding user '$USER' to the docker group..."
      sudo usermod -aG docker "$USER"
      success "User '$USER' added to docker group."
      NEED_GROUP_REFRESH=true
    fi
  else
    echo -e "\n\033[1;33m⚠️  Docker group not found.\033[0m"
    echo "Make sure Docker Desktop has been launched at least once with WSL integration enabled:"
    echo -e "  → \033[1;36mDocker Desktop → Settings → Resources → WSL Integration\033[0m"
    echo "  → Enable your WSL distro and re-run this script:"
    echo -e "     \033[1;32m./bootstrap-user.sh\033[0m"
  fi
}

save_version_lockfiles_to_root() {
  local lock_dir="/opt/onboarding/logs"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  info "Refreshing environment to lock versions..."
  hash -r
  rehash 2>/dev/null || true
  eval "$($HOME/.local/bin/mise activate bash)"

  info "Saving version lock files to $lock_dir"
  sudo mkdir -p "$lock_dir"

  mise current > /tmp/.tool-versions
  echo "# Timestamp: $timestamp" >> /tmp/.tool-versions
  sudo mv /tmp/.tool-versions "$lock_dir/tool-versions.user.lock"

  pipx_ver=$(pipx --version)
  ansible_ver=$(ansible-playbook --version)

  {
    echo "# Timestamp: $timestamp"
    echo "pipx: \"$pipx_ver\""
    echo "ansible-core: |"
    echo "$ansible_ver" | sed 's/^/  /'
  } | sudo tee "$lock_dir/versions.user.lock.yml" > /dev/null

  sudo cp -- "$0" "$lock_dir/bootstrap-user.sh"

  success "User version locks saved in $lock_dir"
}

print_success_message() {
  success "✅ User bootstrap complete."
  echo
  echo -e "\033[1;36m🎯 Refresh your environment once to make installed tools available:\033[0m"
  echo -e "  → Run: \033[1;32mexec \$SHELL\033[0m"
  echo -e "  → Or close and reopen your terminal"
  echo
  echo "After refreshing, try running:"
  echo "  mise current"
  echo "  python --version"
  echo "  ansible-playbook --version"

  if [[ "$NEED_GROUP_REFRESH" == true ]]; then
    echo
    echo -e "\033[1;36m🌀 To apply your new docker group membership:\033[0m"
    echo -e "  → Run: \033[1;32mnewgrp docker\033[0m"
    echo -e "  → Or restart your shell: \033[1;32mexec \$SHELL\033[0m"
  fi


}

mark_user_bootstrap_done() {
  sudo touch /opt/onboarding/.bootstrap-user-done
}

main() {
  install_mise
  install_python
  install_pipx_and_ansible
  add_user_to_docker_group
  save_version_lockfiles_to_root
  print_success_message
  mark_user_bootstrap_done
}

main "$@"

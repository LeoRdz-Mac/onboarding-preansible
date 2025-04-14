#!/usr/bin/env bash
set -euo pipefail

# ─── Styled Output ───────────────────────────────────────────────
info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
error()   { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# ─── Trap Cleanup ────────────────────────────────────────────────
cleanup() {
  echo
  error "Setup aborted. No partial changes should persist."
  exit 1
}
trap cleanup INT TERM ERR

# ─── Restart Guidance ────────────────────────────────────────────
print_shell_restart_hint() {
  echo
  echo -e "\033[1;36m🎯 Final step:\033[0m"
  echo -e "  🔁 To apply all environment changes, run:"
  echo -e "     \033[1;32mexec \$SHELL\033[0m (reloads your shell)"
  echo -e "     or close and reopen your terminal."
}

# ─── Interactive Prompts ─────────────────────────────────────────
prompt_username() {
  local input
  while true; do
    read -rp "Enter a username (lowercase, alphanumeric, -, _, max 32 chars): " input
    if [[ -z "$input" ]]; then
      error "Username cannot be empty. Try again."
    elif [[ ! "$input" =~ ^[a-z0-9_-]{1,32}$ ]]; then
      error "Invalid username. Use only lowercase letters, numbers, -, or _, max 32 chars."
    else
      USERNAME="$input"
      break
    fi
  done
}

prompt_password() {
  while true; do
    read -rsp "Enter password for $USERNAME: " password
    echo
    read -rsp "Confirm password: " confirm
    echo
    if [[ "$password" == "$confirm" && -n "$password" ]]; then
      PASSWORD="$password"
      break
    else
      error "Passwords don't match or are empty. Try again."
    fi
  done
}

# ─── User + Dependencies ─────────────────────────────────────────
create_user() {
  if id "$USERNAME" &>/dev/null; then
    info "User '$USERNAME' already exists."
  else
    info "Creating user '$USERNAME'"
    encrypted_pw=$(openssl passwd -6 "$PASSWORD")
    useradd -m -d "/home/$USERNAME" -s /bin/bash -G sudo -p "$encrypted_pw" "$USERNAME"
    success "User '$USERNAME' created and added to sudo group."
  fi
}

install_system_dependencies() {
  info "Installing base system packages..."
  apt update
  apt install -y \
    sudo curl git zsh build-essential \
    libssl-dev libffi-dev ca-certificates \
    software-properties-common apt-transport-https \
    lsb-release libfuse2
  success "System dependencies installed."
}

save_version_lockfile() {
  local lock_dir="/opt/onboarding/logs"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  mkdir -p "$lock_dir"

  info "Saving package versions to lock file..."
  dpkg-query -W -f='${binary:Package} ${Version}\n' \
    sudo curl git zsh build-essential \
    libssl-dev libffi-dev ca-certificates \
    software-properties-common apt-transport-https \
    lsb-release libfuse2 \
    > "$lock_dir/bootstrap-root-install-log.lock"

  echo "# Timestamp: $timestamp" >> "$lock_dir/bootstrap-root-install-log.lock"
}

copy_bootstrap_user_to_user_home() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local src_file="$script_dir/bootstrap-user.sh"
  local dest_file="/home/$USERNAME/bootstrap-user.sh"

  if [[ ! -f "$src_file" ]]; then
    error "Source script 'bootstrap-user.sh' not found in $script_dir"
    exit 1
  fi

  info "Copying bootstrap-user.sh to /home/$USERNAME/"
  cp "$src_file" "$dest_file"
  chown "$USERNAME:$USERNAME" "$dest_file"
  chmod +x "$dest_file"
  success "bootstrap-user.sh copied and made executable in /home/$USERNAME/"
}

create_user_motd_template() {
  local target_dir="/home/$USERNAME/.profile.d"
  local target_file="$target_dir/onboarding-user.sh"
  local template_file="/opt/onboarding/templates/onboarding-user.sh"

  info "Copying onboarding MOTD script from template..."

  if [[ ! -f "$template_file" ]]; then
    error "MOTD template not found at $template_file"
    exit 1
  fi

  mkdir -p "$target_dir"
  cp "$template_file" "$target_file"
  chown "$USERNAME:$USERNAME" "$target_file"
  chmod +x "$target_file"

  # Ensure required shell init files exist and source the MOTD
  for rcfile in .bashrc .profile .zshrc .zprofile; do
    local rcpath="/home/$USERNAME/$rcfile"

    # Create file if it doesn't exist
    if [ ! -f "$rcpath" ]; then
      touch "$rcpath"
      chown "$USERNAME:$USERNAME" "$rcpath"
    fi

    # Add sourcing line only if not present
    if ! grep -q '.profile.d/onboarding-user.sh' "$rcpath"; then
      echo 'test -f ~/.profile.d/onboarding-user.sh && . ~/.profile.d/onboarding-user.sh' >> "$rcpath"
    fi
  done

  chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.profile.d"

  success "Onboarding MOTD installed and sourced in shell init files."
}


print_next_steps() {
  success "Bootstrap (root) complete."
  echo
  echo "Now switch to the user:"
  echo "  su - $USERNAME"
  echo "Then run:"
  echo "  ./bootstrap-user.sh"
}

mark_root_bootstrap_done() {
  echo "✅ Onboarding (root) complete."
  touch /opt/onboarding/.bootstrap-root-done
}

main() {
  prompt_username
  prompt_password
  create_user
  install_system_dependencies
  save_version_lockfile
  copy_bootstrap_user_to_user_home
  create_user_motd_template
  print_next_steps
  mark_root_bootstrap_done
}

main "$@"

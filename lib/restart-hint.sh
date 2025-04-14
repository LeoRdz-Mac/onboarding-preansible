#!/bin/bash

print_restart_hint() {
  local with_docker_group="${1:-false}"

  echo
  echo -e "\033[1;36m🎯 Final step:\033[0m"

  if [[ "$with_docker_group" == "true" ]]; then
    echo -e "  🐳 You were added to the \033[1;33mdocker\033[0m group."
    echo -e "     → Please run: \033[1;32mnewgrp docker\033[0m to activate it immediately"
    echo -e "     → Or simply restart your shell"
  fi

  echo -e "  🔁 To apply all environment changes, run:"
  echo -e "     \033[1;32mexec \$SHELL\033[0m (reloads your shell without logout)"
  echo -e "     Or close and reopen your terminal"
  echo
}

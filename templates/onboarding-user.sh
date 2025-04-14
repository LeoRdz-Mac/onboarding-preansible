#!/bin/bash

# ─── Prevent Double Execution ───────────────────────────────────
# Ensure MOTD runs only once per shell session
if [[ -n "$ONBOARDING_MOTD_SHOWN" ]]; then
  return 0 2>/dev/null || exit 0
fi
export ONBOARDING_MOTD_SHOWN=true

# ─── Only Run in Interactive Shells ─────────────────────────────
case "$-" in
  *i*) ;;
  *) return 0 2>/dev/null || exit 0 ;;
esac

# ─── Show Message If Onboarding Not Complete ────────────────────
FLAG="/opt/onboarding/.bootstrap-user-done"
SCRIPT="$HOME/bootstrap-user.sh"

if [ ! -f "$FLAG" ]; then
  echo -e "\n\033[1;33m🧪 User setup not yet completed.\033[0m"
  echo -e "\033[1;36mRun:\033[0m \033[1;32m$SCRIPT\033[0m"
  echo -e "This message will disappear once onboarding is completed.\n"
fi

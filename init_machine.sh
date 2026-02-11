#!/bin/bash

###################
#
# TO use: curl -sSL -H 'Expires: 0'  https://raw.githubusercontent.com/hcoohb/init_machine/main/init_machine.sh | bash
#
###################

set -euo pipefail

# 1. Install GitHub CLI
echo "--- Installing GitHub CLI ---"
sudo pacman -S --needed github-cli openssh curl --noconfirm

# 2. Generate SSH Key (ED25519)
SSH_DIR="$HOME/.ssh"
SSH_KEY="$SSH_DIR/id_github_ed25519"
mkdir -p "$SSH_DIR/include.d"
chmod 700 "$SSH_DIR"

if [ ! -f "$SSH_KEY" ]; then
    echo "--- Generating new ED25519 SSH key ---"
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "arch-machine-$(date +%F)"
fi

# 3. Configure SSH for GitHub
echo "--- Configuring SSH for GitHub ---"
cat <<EOT > "$SSH_DIR/include.d/github"
Host github.com
    HostName github.com
    User git
    IdentityFile $SSH_KEY
    IdentitiesOnly yes
EOT
chmod 600 "$SSH_DIR/include.d/github"

TOUCH_CONFIG="$SSH_DIR/config"
INCLUDE_LINE="Include ~/.ssh/include.d/github"

# Ensure Include line is present at the top exactly once
if [ ! -f "$TOUCH_CONFIG" ]; then
    echo "$INCLUDE_LINE" > "$TOUCH_CONFIG"
elif ! grep -qxF "$INCLUDE_LINE" "$TOUCH_CONFIG"; then
    # Prepend the line
    tmpfile="$(mktemp)"
    { echo "$INCLUDE_LINE"; cat "$TOUCH_CONFIG"; } > "$tmpfile"
    cat "$tmpfile" > "$TOUCH_CONFIG"
    rm -f "$tmpfile"
fi
chmod 600 "$TOUCH_CONFIG"

# 4. Authenticate with GitHub (only if not already authenticated)
echo "--- Checking GitHub authentication status ---"
if gh auth status -h github.com >/dev/null 2>&1; then
    echo "--- Already authenticated to GitHub ---"
else
    echo "--- Starting GitHub Authentication ---"
    # Use device code flow in the terminal; avoid opening a browser
    BROWSER=false gh auth login \
        --hostname github.com \
        --git-protocol ssh \
        --scopes admin:public_key \
        --skip-ssh-key

    echo "--- Authentication completed ---"
fi

# 4b. Upload the SSH key only if not already present
echo "--- Ensuring SSH key is uploaded to GitHub ---"
PUBKEY_CONTENT="$(cat "${SSH_KEY}.pub" | awk '{print $1" "$2}')"

# Query existing SSH keys and check for an exact key match (by content)

if gh api -H "Accept: application/vnd.github+json" /user/keys \
    | jq -r '.[].key' \
    | cut -d' ' -f1-2 \
    | grep -qxF "$PUBKEY_CONTENT"; then
  echo "--- SSH public key already present on GitHub; skipping upload ---"
else
  gh ssh-key add "${SSH_KEY}.pub" --title "Arch Machine $(hostname)"
  echo "--- SSH key uploaded to GitHub ---"
fi


# Verify authentication
gh auth status -h github.com


echo "--- Verifying SSH connectivity to GitHub ---"
# Avoid script exit on non-zero from ssh
set +e
ssh -T git@github.com || echo "Note: SSH test non-zero exit code is normal."
set -e

# 5. Clone private repo and run post-install script
echo "--- Cloning dotfiles repo ---"
cd ~
if [ -d "dotfiles/.git" ]; then
    echo "--- dotfiles already cloned; pulling latest ---"
    git -C dotfiles pull --ff-only
else
    git clone git@github.com:hcoohb/dotfiles.git
fi

echo "--- Launching post-install script ---"
chmod +x "dotfiles/post_install.sh"
bash "dotfiles/post_install.sh"

echo "--- Setup complete! ---"
``

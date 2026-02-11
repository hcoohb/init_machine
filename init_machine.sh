#!/bin/bash


###################
#
# TO use: curl -sSL https://raw.githubusercontent.com/hcoohb/init_machine/main/init_machine.sh | bash
#
###################




set -e

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
    # Ensure SSH agent is running and add the key
    # eval "$(ssh-agent -s)"
    # ssh-add "$SSH_KEY"
fi

# 3. Configure SSH for GitHub
echo "--- Configuring SSH for GitHub ---"
# Create the specific include file
cat <<EOT > "$SSH_DIR/include.d/github"
Host github.com
    HostName github.com
    User git
    IdentityFile $SSH_KEY
    IdentitiesOnly yes
EOT
chmod 600 "$SSH_DIR/include.d/github"

# Ensure the main config includes our new file
TOUCH_CONFIG="$SSH_DIR/config"
INCLUDE_LINE="Include ~/.ssh/include.d/github"

# Create file if missing; use >> to append securely if content is needed
if [ ! -f "$TOUCH_CONFIG" ]; then
    echo "$INCLUDE_LINE" > "$TOUCH_CONFIG"
elif ! grep -q "$INCLUDE_LINE" "$TOUCH_CONFIG"; then
    # Using a temporary file ensures the line is at the top even for empty files
    echo -e "$INCLUDE_LINE\n$(cat "$TOUCH_CONFIG")" > "$TOUCH_CONFIG"
fi
chmod 600 "$TOUCH_CONFIG"


# 4. Authenticate with GitHub
echo "--- Starting GitHub Authentication ---"
# This triggers the interactive login flow
BROWSER=false gh auth login --git-protocol ssh -h github.com -s admin:public_key --skip-ssh-key

# Upload the specific key we just created
echo "--- Uploading SSH key to GitHub ---"
gh ssh-key add "${SSH_KEY}.pub" --title "Arch Machine $(hostname)"

# Verify authentication
gh auth status

# Verify connection
ssh -T git@github.com || echo "Note: SSH test exit code is normal."


# Enable SSH
sudo systemctl enable --now sshd.service


# 5. Optional: Clone private repo and run post-install script
# git clone git@github.com:hcoohb/dotfiles.git
#
echo "--- Cloning dotfiles repo ---"
cd ~
git clone git@github.com:hcoohb/dotfiles.git


echo "--- Launching post-install script ---"
chmod +x "dotfiles/post_install.sh"
bash "dotfiles/post_install.sh"

echo "--- Setup complete! ---"

#!/bin/bash


###################
#
# TO use: curl -sSL https://raw.githubusercontent.com | bash
#
###################




set -e

# 1. Install GitHub CLI
echo "--- Installing GitHub CLI ---"
sudo pacman -S --needed github-cli openssh --noconfirm

# 2. Generate SSH Key (ED25519)
SSH_KEY="$HOME/.ssh/id_github_ed25519"
if [ ! -f "$SSH_KEY" ]; then
    echo "--- Generating new ED25519 SSH key ---"
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "arch-machine-$(date +%F)"
    # Ensure SSH agent is running and add the key
    eval "$(ssh-agent -s)"
    ssh-add "$SSH_KEY"
fi

# 3. Authenticate with GitHub
echo "--- Starting GitHub Authentication ---"
echo "Select 'SSH' as the protocol when prompted."
# This triggers the interactive login flow
BROWSER=false gh auth login --git-protocol ssh -h github.com -s admin:public_key --skip-ssh-key

# Upload the specific key we just created
echo "--- Uploading SSH key to GitHub ---"
gh ssh-key add "${SSH_KEY}.pub" --title "Arch Machine $(hostname)"

# Verify authentication
gh auth status

# 4. Optional: Clone private repo and run post-install script
read -p "Do you want to clone a private repo and run an install script? (y/n): " confirm
if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
    read -p "Enter the private repo (e.g., username/my-private-config): " PRIVATE_REPO
    read -p "Enter the path to the script within that repo: " SCRIPT_PATH

    TARGET_DIR="$HOME/$(basename "$PRIVATE_REPO")"

    echo "--- Cloning private repository ---"
    gh repo clone "$PRIVATE_REPO" "$TARGET_DIR"

    if [ -f "$TARGET_DIR/$SCRIPT_PATH" ]; then
        echo "--- Executing $SCRIPT_PATH ---"
        chmod +x "$TARGET_DIR/$SCRIPT_PATH"
        bash "$TARGET_DIR/$SCRIPT_PATH"
    else
        echo "Error: Script $SCRIPT_PATH not found in $TARGET_DIR"
    fi
fi

echo "--- Setup complete! ---"

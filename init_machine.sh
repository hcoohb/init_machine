#!/bin/bash


###################
#
# TO use: curl -sSL https://raw.githubusercontent.com/hcoohb/init_machine/main/init_machine.sh | bash
#
###################




set -e

# 1. Install GitHub CLI
echo "--- Installing GitHub CLI ---"
sudo pacman -S --needed github-cli openssh --noconfirm

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

# 5. Optional: Clone private repo and run post-install script
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

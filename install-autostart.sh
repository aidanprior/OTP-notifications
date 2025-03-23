#!/bin/sh

# This script creates a LaunchAgent to automatically start the OTP monitor at login

# Install Go and goimapnotify
if ! command -v go &> /dev/null; then
    echo "Installing Go..."
    brew install go
fi

if ! command -v goimapnotify &> /dev/null; then
    echo "Installing goimapnotify..."
    go install gitlab.com/shackra/goimapnotify@latest
fi

# Ensure ~/go/bin is in PATH for the current session
export PATH="$PATH:$HOME/go/bin"

# Add ~/go/bin to the appropriate shell configuration file if not already present
# Determine which shell the user is using
current_shell=$(basename "$SHELL")

# Set the appropriate config file based on the shell
case "$current_shell" in
    bash)
        config_file="$HOME/.bashrc"
        # Also check .bash_profile for macOS
        if [ -f "$HOME/.bash_profile" ]; then
            config_file="$HOME/.bash_profile"
        fi
        ;;
    zsh)
        config_file="$HOME/.zshrc"
        ;;
    fish)
        config_file="$HOME/.config/fish/config.fish"
        # For fish shell, the syntax is different
        path_export='set -x PATH $PATH $HOME/go/bin'
        ;;
    *)
        # Default to .profile for other shells
        config_file="$HOME/.profile"
        ;;
esac

# Default path export line for bash/zsh/other shells
if [ -z "$path_export" ]; then
    path_export='export PATH="$PATH:$HOME/go/bin"'
fi

# Check if the path is already in the config file
if [ -f "$config_file" ] && ! grep -q "PATH.*go/bin" "$config_file"; then
    echo "Adding Go binaries to PATH in $config_file"
    echo "$path_export" >> "$config_file"
    echo "✅ PATH updated for future terminal sessions."
else
    echo "Go binaries PATH already configured or config file not found."
fi

CONFIG_DIR="$HOME/.config"
CONFIG_FILE="$CONFIG_DIR/goimapnotify.json"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Prompt for email configuration
echo "=== Email OTP Extractor Configuration ==="
echo "Please enter your email configuration details:"
echo ""

# Default values
DEFAULT_HOST="imap.gmail.com"
DEFAULT_PORT="993"
DEFAULT_MAILBOX="INBOX"

# Get IMAP server details
read -p "IMAP Server [$DEFAULT_HOST]: " IMAP_HOST
IMAP_HOST=${IMAP_HOST:-$DEFAULT_HOST}

read -p "IMAP Port [$DEFAULT_PORT]: " IMAP_PORT
IMAP_PORT=${IMAP_PORT:-$DEFAULT_PORT}

# Get authentication details
read -p "Email Address: " EMAIL_USERNAME
while [ -z "$EMAIL_USERNAME" ]; do
    echo "Email address is required."
    read -p "Email Address: " EMAIL_USERNAME
done

read -p "Password or App Password: " -s EMAIL_PASSWORD
echo ""
while [ -z "$EMAIL_PASSWORD" ]; do
    echo "Password is required."
    read -p "Password or App Password: " -s EMAIL_PASSWORD
    echo ""
done

# Get mailbox to monitor
read -p "Mailbox to Monitor [$DEFAULT_MAILBOX]: " EMAIL_MAILBOX
EMAIL_MAILBOX=${EMAIL_MAILBOX:-$DEFAULT_MAILBOX}

# Create config file with user values
cat > "$CONFIG_FILE" << EOF
{
  "host": "$IMAP_HOST",
  "port": $IMAP_PORT,
  "tls": true,
  "username": "$EMAIL_USERNAME",
  "password": "$EMAIL_PASSWORD",
  "boxes": ["$EMAIL_MAILBOX"],
  "onNewMail": "curl -s --user \"$GOIMAPNOTIFY_USERNAME:$GOIMAPNOTIFY_PASSWORD\" --url \"imaps://$GOIMAPNOTIFY_HOST:993/$GOIMAPNOTIFY_BOX;UID=$1?FETCH=BODY[]\" > /tmp/email-content.$$ && \\
    grep -oE '[0-9]{4,8}' /tmp/email-content.$$ | head -n 1 | pbcopy && \\
    FROM_LINE=\$(grep -i '^From:' /tmp/email-content.$$ | sed 's/^From:\\s*//i') && \\
    OTP_CODE=\$(grep -oE '[0-9]{4,8}' /tmp/email-content.$$ | head -n 1) && \\
    osascript -e \"display notification \\\"The One-Time-Passcode has been copied to the clipboard\\\" with title \\\"From: \$FROM_LINE\\\" subtitle \\\"OTP: \$OTP_CODE\\\"\" && \\
    echo \"From: \$FROM_LINE OTP: \$OTP_CODE\" && \\
    rm -f /tmp/email-content.$$"
}
EOF

# Create LaunchAgent plist file
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_FILE="$LAUNCH_AGENT_DIR/com.user.imap-otp.plist"

# Make sure LaunchAgents directory exists
mkdir -p "$LAUNCH_AGENT_DIR"

# Create the plist file using the config file
cat > "$LAUNCH_AGENT_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.imap-otp</string>
    <key>ProgramArguments</key>
    <array>
        <string>$(which goimapnotify)</string>
        <string>-conf</string>
        <string>$CONFIG_FILE</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/.logs/imap-otp.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.logs/imap-otp.error.log</string>
</dict>
</plist>
EOF

# Create logs directory
mkdir -p "$HOME/.logs"

# Ask if user wants to start the service now
echo ""
echo "✅ OTP monitor has been configured!"
read -p "Would you like to start the service now? (y/n): " START_NOW
if [[ $START_NOW == "y" || $START_NOW == "Y" ]]; then
    launchctl unload "$LAUNCH_AGENT_FILE" 2>/dev/null
    launchctl load "$LAUNCH_AGENT_FILE"
    echo "✅ OTP monitor service started!"
else
    echo ""
    echo "To start the service manually:"
    echo "   launchctl load $LAUNCH_AGENT_FILE"
fi

echo ""
echo "Configuration file: $CONFIG_FILE"
echo "To run manually for testing:"
echo "   goimapnotify -conf \"$CONFIG_FILE\""
echo ""
echo "To disable autostart:"
echo "   launchctl unload $LAUNCH_AGENT_FILE"

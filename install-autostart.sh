#!/bin/sh

# This script creates a service to automatically start the OTP monitor
# Works on both macOS and Linux

# Determine OS
OS="$(uname -s)"
case "$OS" in
    Darwin*)
        IS_MACOS=true
        ;;
    Linux*)
        IS_MACOS=false
        ;;
    *)
        echo "Unsupported operating system"
        exit 1
        ;;
esac

# Install dependencies
if [ "$IS_MACOS" = true ]; then
    # macOS: Install Go and goimapnotify using Homebrew
    if ! command -v go > /dev/null 2>&1; then
        echo "Installing Go..."
        brew install go
    fi
else
    # Linux: Check for package managers and install Go
    if ! command -v go > /dev/null 2>&1; then
        echo "Installing Go..."
        if command -v apt-get > /dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y golang
        elif command -v dnf > /dev/null 2>&1; then
            sudo dnf install -y golang
        elif command -v pacman > /dev/null 2>&1; then
            sudo pacman -S --noconfirm go
        elif command -v zypper > /dev/null 2>&1; then
            sudo zypper install -y go
        else
            echo "Couldn't install Go. Please install Go manually and run this script again."
            exit 1
        fi
    fi
    
    # Install clipboard tools if not present
    if ! command -v xclip > /dev/null 2>&1 && ! command -v xsel > /dev/null 2>&1 && ! command -v wl-copy > /dev/null 2>&1; then
        echo "Installing clipboard tools..."
        if command -v apt-get > /dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y xclip
        elif command -v dnf > /dev/null 2>&1; then
            sudo dnf install -y xclip
        elif command -v pacman > /dev/null 2>&1; then
            sudo pacman -S --noconfirm xclip
        elif command -v zypper > /dev/null 2>&1; then
            sudo zypper install -y xclip
        fi
    fi
    
    # Install notification tools if not present
    if ! command -v notify-send > /dev/null 2>&1 && ! command -v zenity > /dev/null 2>&1; then
        echo "Installing notification tools..."
        if command -v apt-get > /dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y libnotify-bin
        elif command -v dnf > /dev/null 2>&1; then
            sudo dnf install -y libnotify
        elif command -v pacman > /dev/null 2>&1; then
            sudo pacman -S --noconfirm libnotify
        elif command -v zypper > /dev/null 2>&1; then
            sudo zypper install -y libnotify
        fi
    fi
fi

# Install goimapnotify if not present
if ! command -v goimapnotify > /dev/null 2>&1; then
    echo "Installing goimapnotify..."
    go install gitlab.com/shackra/goimapnotify@latest
fi

# Ensure go binaries are in PATH
GOBIN=$(go env GOPATH)/bin
export PATH="$PATH:$GOBIN"

# Add go bin to the appropriate shell configuration file if not already present
# Determine which shell the user is using
current_shell=$(basename "$SHELL")

# Set the appropriate config file based on the shell
case "$current_shell" in
    bash)
        config_file="$HOME/.bashrc"
        # Also check .bash_profile for macOS
        if [ "$IS_MACOS" = true ] && [ -f "$HOME/.bash_profile" ]; then
            config_file="$HOME/.bash_profile"
        fi
        path_export="export PATH=\"\$PATH:$(go env GOPATH)/bin\""
        ;;
    zsh)
        config_file="$HOME/.zshrc"
        path_export="export PATH=\"\$PATH:$(go env GOPATH)/bin\""
        ;;
    fish)
        config_file="$HOME/.config/fish/config.fish"
        # For fish shell, the syntax is different
        path_export="set -x PATH \$PATH $(go env GOPATH)/bin"
        ;;
    *)
        # Default to .profile for other shells
        config_file="$HOME/.profile"
        path_export="export PATH=\"\$PATH:$(go env GOPATH)/bin\""
        ;;
esac

# Check if the path is already in the config file
if [ -f "$config_file" ] && ! grep -q "PATH.*go/bin\|PATH.*$(go env GOPATH)/bin" "$config_file"; then
    echo "Adding Go binaries to PATH in $config_file"
    echo "$path_export" >> "$config_file"
    echo "✅ PATH updated for future terminal sessions."
else
    echo "Go binaries PATH already configured or config file not found."
fi

CONFIG_DIR="$HOME/.config"
CONFIG_FILE="$CONFIG_DIR/goimapnotify.json"
OTP_SCRIPT_PATH="$CONFIG_DIR/extract-otp.sh"

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Download the OTP extraction script
echo "Downloading OTP extraction script..."
curl -s -o "$OTP_SCRIPT_PATH" "https://raw.githubusercontent.com/aidanprior/OTP-notifications/main/extract-otp.sh"

# Make the script executable
chmod +x "$OTP_SCRIPT_PATH"

# Prompt for email configuration
echo "=== Email OTP Extractor Configuration ==="
echo "Please enter your email configuration details:"
echo ""

# Default values
DEFAULT_HOST="imap.gmail.com"
DEFAULT_PORT="993"
DEFAULT_MAILBOX="INBOX"

# Get IMAP server details
printf "IMAP Server [%s]: " "$DEFAULT_HOST"
read -r IMAP_HOST
IMAP_HOST=${IMAP_HOST:-$DEFAULT_HOST}

printf "IMAP Port [%s]: " "$DEFAULT_PORT"
read -r IMAP_PORT
IMAP_PORT=${IMAP_PORT:-$DEFAULT_PORT}

# Get authentication details
printf "Email Address: "
read -r EMAIL_USERNAME
while [ -z "$EMAIL_USERNAME" ]; do
    echo "Email address is required."
    printf "Email Address: "
    read -r EMAIL_USERNAME
done

printf "Password or App Password: "
stty -echo
read -r EMAIL_PASSWORD
stty echo
echo ""
while [ -z "$EMAIL_PASSWORD" ]; do
    echo "Password is required."
    printf "Password or App Password: "
    stty -echo
    read -r EMAIL_PASSWORD
    stty echo
    echo ""
done

# Get mailbox to monitor
printf "Mailbox to Monitor [%s]: " "$DEFAULT_MAILBOX"
read -r EMAIL_MAILBOX
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
  "onNewMail": "$OTP_SCRIPT_PATH '$EMAIL_USERNAME' '$EMAIL_PASSWORD' '$IMAP_HOST' '$IMAP_PORT' '$EMAIL_MAILBOX' '\$1'"
}
EOF

# Create logs directory
LOGS_DIR="$HOME/.logs"
mkdir -p "$LOGS_DIR"

# Set up the service based on platform
if [ "$IS_MACOS" = true ]; then
    # macOS: Set up LaunchAgent
    LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
    LAUNCH_AGENT_FILE="$LAUNCH_AGENT_DIR/com.user.imap-otp.plist"
    
    # Make sure LaunchAgents directory exists
    mkdir -p "$LAUNCH_AGENT_DIR"
    
    # Create the plist file
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
    <string>$LOGS_DIR/imap-otp.log</string>
    <key>StandardErrorPath</key>
    <string>$LOGS_DIR/imap-otp.error.log</string>
</dict>
</plist>
EOF
    
    # Ask if user wants to start the service now
    echo ""
    echo "✅ OTP monitor has been configured!"
    printf "Would you like to start the service now? (y/n): "
    read -r START_NOW
    if [ "$START_NOW" = "y" ] || [ "$START_NOW" = "Y" ]; then
        launchctl unload "$LAUNCH_AGENT_FILE" 2>/dev/null
        launchctl load "$LAUNCH_AGENT_FILE"
        echo "✅ OTP monitor service started!"
    else
        echo ""
        echo "To start the service manually:"
        echo "   launchctl load \"$LAUNCH_AGENT_FILE\""
    fi
    
    echo ""
    echo "To disable autostart:"
    echo "   launchctl unload \"$LAUNCH_AGENT_FILE\""
    
else
    # Linux: Set up Systemd user service
    SYSTEMD_DIR="$HOME/.config/systemd/user"
    SYSTEMD_FILE="$SYSTEMD_DIR/imap-otp.service"
    
    # Create systemd directory if it doesn't exist
    mkdir -p "$SYSTEMD_DIR"
    
    # Create systemd service file
    cat > "$SYSTEMD_FILE" << EOF
[Unit]
Description=IMAP OTP Extractor Service
After=network.target

[Service]
ExecStart=$(which goimapnotify) -conf $CONFIG_FILE
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF
    
    # Reload systemd to recognize the new service
    systemctl --user daemon-reload
    
    # Ask if user wants to start the service now
    echo ""
    echo "✅ OTP monitor has been configured!"
    printf "Would you like to start the service now? (y/n): "
    read -r START_NOW
    if [ "$START_NOW" = "y" ] || [ "$START_NOW" = "Y" ]; then
        systemctl --user enable imap-otp.service
        systemctl --user start imap-otp.service
        echo "✅ OTP monitor service started!"
    else
        echo ""
        echo "To start the service manually:"
        echo "   systemctl --user enable imap-otp.service"
        echo "   systemctl --user start imap-otp.service"
    fi
    
    echo ""
    echo "To disable autostart:"
    echo "   systemctl --user disable imap-otp.service"
    echo "   systemctl --user stop imap-otp.service"
fi

echo ""
echo "Configuration file: $CONFIG_FILE"
echo "To run manually for testing:"
echo "   goimapnotify -conf \"$CONFIG_FILE\""

#!/bin/bash
# Installation script for OTP Email Checker

echo "OTP Email Checker Installer"
echo "---------------------------"
echo

# Make the script executable
chmod +x otp_check.sh

# ==== Check for dependencies ====

# Check if openssl is installed
check_install_openssl() {
    if ! command -v openssl &> /dev/null; then
        echo "OpenSSL is not installed. Installing OpenSSL..."
        
        if command -v brew &> /dev/null; then
            brew install openssl
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y openssl
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y openssl
        elif command -v yum &> /dev/null; then
            sudo yum install -y openssl
        elif command -v pacman &> /dev/null; then
            sudo pacman -S openssl --noconfirm
        else
            echo "Could not detect package manager. Please install OpenSSL manually."
            return 1
        fi
    fi
    
    if command -v openssl &> /dev/null; then
        echo "✅ OpenSSL installed successfully"
        return 0
    else
        echo "❌ OpenSSL installation failed. Please install OpenSSL manually."
        return 1
    fi
}

# Check if crontab is installed
check_install_cron() {
    if ! command -v crontab &> /dev/null; then
        echo "Crontab is not installed. Installing cron..."
        
        if [ "$(uname)" = "Darwin" ]; then
            # macOS has cron built-in, just make sure it's enabled
            sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.cron.plist
        elif command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y cron
            sudo systemctl enable cron.service
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y cronie
            sudo systemctl enable crond.service
        elif command -v yum &> /dev/null; then
            sudo yum install -y cronie
            sudo systemctl enable crond.service
        elif command -v pacman &> /dev/null; then
            sudo pacman -S cronie --noconfirm
            sudo systemctl enable cronie.service
        else
            echo "Could not detect package manager. Please install cron manually."
            return 1
        fi
    fi
    
    if command -v crontab &> /dev/null; then
        echo "✅ Cron installed successfully"
        return 0
    else
        echo "❌ Cron installation failed. Please install cron manually."
        return 1
    fi
}

# Install required dependencies
check_install_openssl || exit 1
check_install_cron || exit 1

# ==== Get email configuration ====
echo
echo "Email Configuration"
echo "------------------"
read -p "Email Address: " EMAIL
read -sp "Password/App Password: " PASSWORD
echo
read -p "IMAP Server [imap.gmail.com]: " SERVER
SERVER=${SERVER:-imap.gmail.com}
read -p "Mailbox [INBOX]: " MAILBOX
MAILBOX=${MAILBOX:-INBOX}

# ==== Create directory structure ====
# Directory structure following XDG standards
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/email-otp-monitor"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
SECRETS_DIR="${HOME}/.local/share/email-otp-monitor"

mkdir -p "$CACHE_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$SECRETS_DIR"

# Ensure secure permissions on secrets directory
chmod 700 "$SECRETS_DIR"

# ==== Encrypt email password ====
echo "Setting up OpenSSL encryption for password..."
PASSPHRASE="email-otp-monitor"  # Default passphrase to encrypt/decrypt

# Encrypt the password to the secure location
echo -n "$PASSWORD" | openssl enc -aes-256-cbc -e -out "${SECRETS_DIR}/password.enc" -pass pass:"$PASSPHRASE" -pbkdf2

# Ensure secure permissions on the password file
chmod 600 "${SECRETS_DIR}/password.enc"

# Check if encryption was successful
if [ $? -eq 0 ]; then
    echo "✅ Password encrypted successfully"
else
    echo "❌ Failed to encrypt password"
    exit 1
fi

# ==== Set up cron job ====
echo
echo "Scheduling"
echo "----------"
read -p "How often should we check for OTPs (minutes) [1]: " INTERVAL
INTERVAL=${INTERVAL:-1}

echo "Setting up automated checks..."

# Get absolute path for script to use in scheduler
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/otp_check.sh"

# Use crontab for both macOS and Linux
(crontab -l 2>/dev/null | grep -v "otp_check.sh"; 
 echo "*/$INTERVAL * * * * $SCRIPT_PATH \"$EMAIL\" \"$SERVER\" \"$MAILBOX\"") | crontab -
echo "✅ Added to crontab - will check every $INTERVAL minute(s)"

echo
echo "🎉 Installation complete!"
echo

#!/bin/bash
# OTP Email Checker
# A simple script to check for OTP codes in email and copy them to clipboard
# Run this script with cron to check periodically

# ==== Configuration ====
# Command line arguments
USERNAME="$1"      # Email address
SERVER="${2:-imap.gmail.com}"  # IMAP server with default
MAILBOX="${3:-INBOX}"         # Mailbox name with default

# Directory structure following XDG standards
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/email-otp-monitor"
LAST_UID_FILE="${CACHE_DIR}/last_uid"
SECRETS_DIR="${HOME}/.local/share/email-otp-monitor"
PASSWORD_FILE="${SECRETS_DIR}/password.enc"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}"
LOG_FILE="${LOG_DIR}/email-otp-monitor.log"

# Fixed passphrase for password decryption
PASSPHRASE="email-otp-monitor"

# ==== Setup ====
# Ensure directories exist with proper permissions
mkdir -p "$CACHE_DIR"
mkdir -p "$SECRETS_DIR"
mkdir -p "$LOG_DIR"

# Ensure secure permissions on secrets directory (only owner can read/write)
chmod 700 "$SECRETS_DIR"

# ==== Logging function ====
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    # Show log message in console if DEBUG is enabled
    [ "$DEBUG" = "true" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# ==== Load encrypted password ====
log "Loading password using OpenSSL"
PASSWORD=$(openssl enc -aes-256-cbc -d -in "$PASSWORD_FILE" -pass pass:"$PASSPHRASE" -pbkdf2 2>/dev/null)

if [ -z "$PASSWORD" ]; then
    log "Error: Failed to decrypt password"
    exit 1
fi

# ==== IMAP connection function ====
# This function handles the IMAP protocol communication using OpenSSL
imap_command() {
    local server="$1"
    local username="$2"
    local password="$3"
    local commands="$4"
    
    log "Connecting to IMAP server: $server"
    
    # Create temporary file for commands with secure permissions
    TMPFILE=$(mktemp)
    chmod 600 "$TMPFILE"
    
    # Add authentication and commands
    cat > "$TMPFILE" << EOF
a LOGIN "$username" "$password"
b SELECT "$MAILBOX"
$commands
c LOGOUT
EOF
    
    # Connect to server and send commands
    RESPONSE=$(openssl s_client -connect "${server}:993" -crlf -quiet 2>/dev/null << EOF
$(cat "$TMPFILE")
EOF
    )
    
    # Clean up temporary file
    rm -f "$TMPFILE"
    
    echo "$RESPONSE"
}

# ==== Get last processed UID ====
# Read the last seen UID from file, if it exists
LAST_UID=$(cat "$LAST_UID_FILE" 2>/dev/null)

if [ -z "$LAST_UID" ]; then
    log "No previous UID found, getting the most recent message UID"
    
    
    # Extract the highest UID value
    MOST_RECENT=$(imap_command "$SERVER" "$USERNAME" "$PASSWORD" "c FETCH * (UID)"| grep -o "UID [0-9]*" | awk '{print $2}' | sort -n | tail -1)
    
    if [ -n "$MOST_RECENT" ]; then
        LAST_UID=$MOST_RECENT
        log "Setting initial UID to most recent message: $LAST_UID"
        echo "$LAST_UID" > "$LAST_UID_FILE"
    else
        LAST_UID=0
        log "Could not determine most recent message UID, starting from 0"
    fi
fi

log "Checking for new emails with UID > $LAST_UID"

# ==== Fetch new emails ====
FETCH_COMMAND="d UID FETCH $((LAST_UID+1)):* (BODY.PEEK[TEXT] UID)"
EMAIL_DATA=$(imap_command "$SERVER" "$USERNAME" "$PASSWORD" "$FETCH_COMMAND")

# Check for IMAP errors
if [[ "$EMAIL_DATA" == *"BAD"* ]] || [[ "$EMAIL_DATA" == *"NO"* ]]; then
    log "Error in IMAP command: $EMAIL_DATA"
    exit 1
fi

# ==== Process emails and extract OTP codes ====
# Parse IMAP response to extract message bodies and UIDs
echo "$EMAIL_DATA" | awk '/\* [0-9]+ FETCH/,/^[a-z] OK/' | while read -r line; do
    if [[ "$line" =~ UID\ ([0-9]+) ]]; then
        # Found a UID line
        CURR_UID=${BASH_REMATCH[1]}
        log "Found message with UID: $CURR_UID"
        
        # Update last UID if this one is higher
        if [ "$CURR_UID" -gt "$LAST_UID" ]; then
            LAST_UID=$CURR_UID
            echo "$LAST_UID" > "$LAST_UID_FILE"
            log "Updated last UID to $LAST_UID"
        fi
        
        # Reset for next message body
        MESSAGE_BODY=""
        CAPTURE=false
    elif [[ "$CAPTURE" == true ]]; then
        # We're in the body section
        if [[ "$line" =~ ^\)$ ]]; then
            # End of body section
            CAPTURE=false
            
            # Process the message body for OTP codes (4-8 digits)
            OTP=$(echo "$MESSAGE_BODY" | grep -o -E '\b[0-9]{4,8}\b' | head -1)
            
            if [ -n "$OTP" ]; then
                log "Found OTP code: $OTP"
                
                # Copy to clipboard and send notification
                if command -v pbcopy > /dev/null; then
                    # macOS
                    echo "$OTP" | pbcopy
                    osascript -e "display notification \"OTP: $OTP has been copied to clipboard\" with title \"OTP Code Found\""
                elif command -v xclip > /dev/null; then
                    # Linux with xclip
                    echo "$OTP" | xclip -selection clipboard
                    notify-send "OTP Code Found" "OTP: $OTP has been copied to clipboard" 2>/dev/null
                elif command -v xsel > /dev/null; then
                    # Linux with xsel
                    echo "$OTP" | xsel --clipboard
                    notify-send "OTP Code Found" "OTP: $OTP has been copied to clipboard" 2>/dev/null
                else
                    log "No clipboard utility found. OTP code: $OTP"
                fi
            fi
        else
            # Add line to the message body
            MESSAGE_BODY+="$line"$'\n'
        fi
    elif [[ "$line" =~ BODY\[TEXT\]\ \{ ]]; then
        # Start of body section
        CAPTURE=true
    fi
done

# ==== Finish ====
[ "$LAST_UID" -gt 0 ] && log "Updated last UID to $LAST_UID" || log "No new OTP codes found"
exit 0

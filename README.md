# Email OTP Checker

A simple shell script that checks your email for OTP codes and copies them to the clipboard.

## Features

- Lightweight shell script with minimal dependencies
- Automatically extracts numeric OTP codes (4-8 digits)
- Copies the code to your clipboard
- Shows desktop notifications
- Remembers which emails it has already checked
- Works on macOS and Linux systems
- Runs via cron for scheduled checking
- Secure password storage using OpenSSL encryption

## Requirements

- OpenSSL for secure IMAP communication and password encryption
- Cron for scheduled execution
- Clipboard utility (pbcopy, xclip, or xsel)
- Email account with IMAP support
- For macOS: Homebrew (recommended for automatic dependency installation)

## Quick Install

You can install the Email OTP Checker with a single command:

```bash
curl -sSL https://raw.githubusercontent.com/aidanprior/email-otp-checker/main/install.sh | sh
```

The installer will:

1. Check for and install OpenSSL if necessary
2. Check for and enable cron if necessary
3. Ask for your email credentials
4. Encrypt your password with OpenSSL
5. Set up scheduled execution with cron
6. Create all necessary directories with appropriate permissions

## Manual Usage

If you need to run the script manually or want to understand the command-line arguments:

```bash
./otp_check.sh [USERNAME] [SERVER] [MAILBOX]
```

### Arguments

1. `USERNAME` - Your email address (required)
2. `SERVER` - IMAP server address (default: imap.gmail.com)
3. `MAILBOX` - The mailbox to check (default: INBOX)

### Examples

Checking a Gmail account:

```bash
./otp_check.sh "your.email@gmail.com" "imap.gmail.com" "INBOX"
```

Checking a Yahoo account:

```bash
./otp_check.sh "your.email@yahoo.com" "imap.mail.yahoo.com" "INBOX"
```

Checking a specific folder for Outlook:

```bash
./otp_check.sh "your.email@outlook.com" "outlook.office365.com" "OTP"
```

### Debug Mode

You can enable debug mode to see more information about what the script is doing:

```bash
DEBUG=true ./otp_check.sh "your.email@example.com" "imap.gmail.com" "INBOX"
```

## How It Works

1. The script connects to your email server using the IMAP protocol via OpenSSL
2. It looks for new emails that arrived since the last check
3. For each new email, it extracts 4-8 digit numbers which are likely to be OTP codes
4. When an OTP code is found, it is copied to your clipboard and a notification is shown
5. The script remembers which emails it has already checked to avoid duplicates

## Security

Your email password is stored with the following precautions:

- Encrypted using OpenSSL AES-256-CBC encryption
- Stored in a directory with restricted permissions (700)
- The password file itself has restricted permissions (600)

## File Locations

The script follows XDG Base Directory Specification:

- **Cache**: `~/.cache/email-otp-monitor/` - Stores the last processed email UID
- **Secrets**: `~/.local/share/email-otp-monitor/` - Stores your encrypted password
- **Logs**: `~/.local/state/email-otp-monitor.log` - Activity logs

## Troubleshooting

If the script doesn't work as expected:

1. Run it in debug mode to see detailed logs: `DEBUG=true ./otp_check.sh ...`
2. Check the log file at `~/.local/state/email-otp-monitor.log`
3. Ensure your email provider allows IMAP access
4. For Gmail, you may need to create an App Password instead of using your regular password

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

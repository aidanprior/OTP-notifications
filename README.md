# Email OTP Extractor

Text and Email OTPs are not as secure as other Muli-Factor Authentication methods, yet they are very common. They often are the most annoying to use as well, requiring you to pick up your phone or check your inbox.

This tool monitors a specified Email folder for new emails containing OTP codes, extracts the codes, and copies them to your clipboard automatically. It uses IMAP IDLE for efficient monitoring without constant polling.

## Requirements

- macOS
- HomeBrew

## Installation

Run the following command to download and run the install wizard:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/aidanprior/OTP-notifications/main/install-autostart.sh)"
```

The installer will:

- Check for and install required dependencies (Go and goimapnotify)
- Add Go binaries to your PATH if needed
- Prompt you for your email configuration details
- Create the configuration file with your settings
- Set up a LaunchAgent for running the service at login
- Offer to start the service immediately

During setup, you'll be asked for:

- IMAP server address (defaults to imap.gmail.com)
- IMAP port (defaults to 993)
- Your email address
- Your password or app password (recommended)
- Which mailbox to monitor (defaults to INBOX)

## App Passwords

For security reasons, many email providers no longer support using your regular account password for third-party apps. Instead, you should create an "app password" - a special password that gives limited access to your email account.

### What is an App Password?

- A unique 16-character password that allows a less secure app or device to access your email account
- Limited to specific purposes and can be revoked without changing your main password
- More secure than using your primary account password

### How to Generate App Passwords

**For Gmail:**

1. Go to your [Google Account](https://myaccount.google.com/)
2. Select "Security"
3. Under "Signing in to Google," select "App passwords" (requires 2-Step Verification to be enabled)
4. Select "Mail" as the app and your device type
5. Click "Generate"

**For Yahoo Mail:**

1. Go to your [Account security settings](https://login.yahoo.com/account/security)
2. Click "Generate app password"
3. Select "Other app" and name it "Email OTP Extractor"
4. Click "Generate"

**For Outlook/Hotmail:**

1. Sign in to your [Microsoft account](https://account.microsoft.com/)
2. Go to "Security" > "Advanced security options"
3. Under "App passwords," select "Create a new app password"

### Other Email Providers

- Most IMAP-compatible email providers support app passwords
- Check your email provider's security or account settings

## Setting Up Email Filters (Optional)

For better organization, you can create filters in your email service to automatically move OTP messages to a dedicated folder that the OTP extractor will monitor.

### Why Create a Filter?

- Keeps your inbox cleaner
- Improves reliability of OTP detection
- Allows you to use a dedicated mailbox instead of scanning all incoming mail (which will mean this script won't run on every new email)

### Gmail Filters

1. Go to Gmail settings (gear icon) > "See all settings"
2. Select the "Filters and Blocked Addresses" tab
3. Click "Create a new filter"
4. Set up your search criteria (examples below)
5. Click "Create filter"
6. Select "Apply the label" and choose or create an "OTP" label
7. Optionally check "Skip the Inbox" to move messages out of the inbox
8. Click "Create filter"

Search criteria examples:

- Subject: `verification code OR security code OR one-time OR OTP OR passcode`
- From: Add common services that send you OTPs
- Has the words: `verification code OR security code OR one-time password OR OTP`

### Outlook/Hotmail Filters

1. Go to Settings (gear icon) > "View all Outlook settings"
2. Go to "Mail" > "Rules"
3. Click "Add new rule"
4. Name your rule (e.g., "OTP Messages")
5. Add conditions (examples below)
6. Add actions: "Move to" > select or create an "OTP" folder
7. Save the rule

Condition examples:

- Subject includes: `code, verification, security, one-time, passcode, OTP`
- Body includes: `verification code, security code, one-time password`

### Yahoo Mail Filters

1. Go to Settings (gear icon) > "More Settings"
2. Select "Filters" > "Add new filters"
3. Name your filter (e.g., "OTP Messages")
4. Set conditions (examples below)
5. Choose "Move to folder" and select or create an "OTP" folder
6. Click "Save"

Condition examples:

- Subject contains: `code, verification, security, passcode, OTP`
- Sender contains: Add services that send you OTPs
- Body contains: `verification code, one-time password, security code`

### After Creating Filters

Remember to update your OTP extractor configuration to monitor the specific folder where your OTP messages will be filtered:

```bash
nano ~/.config/goimapnotify.json
```

Change the "boxes" setting to match your OTP folder name.

## Usage

The service runs in the background once started. No further action is needed.

To run manually (for testing):

```sh
goimapnotify -conf ~/.config/goimapnotify.json
```

To disable autostart:

```sh
launchctl unload ~/Library/LaunchAgents/com.user.imap-otp.plist
```

## How It Works

The script uses goimapnotify to monitor your email folder using IMAP IDLE protocol. When a new email arrives:

1. The script extracts the OTP code (4-8 digits)
2. Copies it to your clipboard
3. Displays a notification with sender info and the code

## Troubleshooting

Logs are written to:

- `~/.logs/imap-otp.log`
- `~/.logs/imap-otp.error.log`

If you need to check the status of the service, run:

```sh
launchctl list | grep com.user.imap-otp
```

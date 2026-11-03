# Prevent Sleep - Commercial Distribution & Monetization Guide

This guide walks you through distributing **Prevent Sleep** directly to customers outside the Mac App Store using your own website, Gumroad, Lemon Squeezy, or Paddle.

---

## 1. When Do You Need an Apple Developer Account?

> [!IMPORTANT]
> **Summary:**
> - **During Development & Local Testing:** You do **NOT** need a paid Apple Developer Account. The local build scripts and `./scripts/package-dmg.sh` sign ad-hoc (`-`) or with your free Apple Development certificate, allowing it to run smoothly on your own Mac.
> - **When Selling to Paying Customers:** You **DO** need an **Apple Developer Account ($99 USD / year)** before uploading the `.dmg` to your store or website.

### Why Is It Required for Public Sales?
When users download an app from the web (Safari, Chrome, etc.), macOS automatically flags it with the `com.apple.quarantine` extended attribute.

When opened:
- **If signed with Developer ID & Notarized:** Gatekeeper displays a trusted, standard prompt: *"Prevent Sleep is an app downloaded from the Internet. Are you sure you want to open it?"* with your name/company listed as a verified developer.
- **If not notarized:** macOS displays scary blocking errors: *"Prevent Sleep is damaged and can't be opened"* or *"Apple cannot check it for malicious software"*.

---

## 2. Setting Up Your Apple Developer Account

Once you are ready to launch publicly, follow these steps:

### Step 1: Enroll in the Apple Developer Program
1. Visit [developer.apple.com/programs/enroll](https://developer.apple.com/programs/enroll/).
2. Sign in with your Apple ID and complete the enrollment ($99/year). Individual or Organization accounts both work.

### Step 2: Create a Developer ID Application Certificate
1. Open **Xcode → Settings → Accounts**.
2. Sign in with your paid Apple Developer Account.
3. Select your team and click **Manage Certificates...**.
4. Click the **+** (plus) button in the lower-left and select **Developer ID Application**.
5. Xcode will automatically generate the certificate and install it into your macOS Keychain.

You can verify that your certificate is active by running:
```bash
security find-identity -v -p codesigning
```
You should see an entry like:
```text
1) XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX "Developer ID Application: Your Name (TEAMID)"
```

### Step 3: Configure Apple Notarytool Credentials
To allow the automated packaging script to notarize your DMG with Apple, store your credentials once in your macOS Keychain:

```bash
xcrun notarytool store-credentials "preventsleep-notary" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID"
```
*(You will be prompted to enter an App-Specific Password, which you can generate at [appleid.apple.com](https://appleid.apple.com) under Sign-In and Security → App-Specific Passwords).*

---

## 3. Building & Packaging the Release DMG

We provide an automated, all-in-one packaging script: `scripts/package-dmg.sh`.

### Local Testing Build (No Developer Account needed yet)
```bash
./scripts/package-dmg.sh
```
This automatically compiles the Release binary, applies Hardened Runtime flags, packages `PreventSleep.app` alongside an `/Applications` shortcut, and produces `build/PreventSleep.dmg`.

### Production Build (Signed & Notarized with Apple)
```bash
./scripts/package-dmg.sh --notarize preventsleep-notary
```
This script will:
1. Compile the Release application.
2. Sign the privileged helper, dylibs, and app bundle with your **Developer ID Application** certificate and Hardened Runtime.
3. Build the compressed `PreventSleep.dmg`.
4. Sign the DMG disk image.
5. Upload the DMG to Apple's Notary Service and wait for approval (~30-60 seconds).
6. **Staple** the notarization ticket to the DMG so customers can verify it even while offline.

The resulting `build/PreventSleep.dmg` is 100% production-ready for distribution!

---

## 4. Selling & Monetization Options

To sell direct without managing complicated merchant sales tax/VAT compliance yourself, use a **Merchant of Record (MoR)**:

### Recommended Payment Platforms
1. **[Lemon Squeezy](https://www.lemonsqueezy.com)** (Very popular for Mac utilities):
   - Handles global VAT, sales tax, fraud, Apple Pay, credit cards, PayPal.
   - Built-in license key generation and activation API if you want to lock the app with license keys.
   - Fees: ~5% + $0.50 per transaction (vs. Apple's 15% - 30%).
2. **[Gumroad](https://gumroad.com)**:
   - Extremely fast setup (takes 5 minutes).
   - Allows hosting the `.dmg` directly for customers to download immediately upon payment.
   - Built-in license keys.
3. **[Paddle](https://www.paddle.com)**:
   - Enterprise-grade MoR for desktop software with subscription and one-time billing options.

---

## 5. The "Crazy Easy" Customer Experience

With the improvements implemented in this project:

```
[Customer buys on your site]
        │
        ▼
[Downloads PreventSleep.dmg]
        │
        ▼
[Opens DMG]
  ├── Can drag icon to Applications
  └── OR double-clicks PreventSleep.app directly!
        │
        ▼
[Smart Relocation Triggered]
  • App detects it is running from disk image or Downloads
  • One-click dialog: "Move to Applications Folder?"
  • Copies itself to /Applications, relaunches, and unmounts DMG cleanly!
        │
        ▼
[Live Auto-Detecting Onboarding]
  • Shows friendly 2-step visual setup guide
  • Click "Open Login Items Settings"
  • User turns toggle ON
  • App detects approval automatically in real-time (<0.5s)
  • Shows animated "✓ All Set!" and is instantly ready in the menu bar (☕️)
```
EOF

# DockFinity - Setup Guide

## Quick Start

### 1. Install dockutil

DockFinity requires `dockutil` to manipulate the macOS Dock.

**Using Homebrew (Recommended):**

```bash
brew install dockutil
```

**Verify installation:**

```bash
dockutil --version
```

### 2. Open Project in Xcode

```bash
cd apps/dockfinity
open dockfinity.xcodeproj
```

### 3. Configure Signing

1. Select the `dockfinity` project in the navigator
2. Select the `dockfinity` target
3. Go to "Signing & Capabilities"
4. Select your development team
5. Ensure the bundle identifier is unique (default: `de.nick-friedrich.dockfinity`)

### 4. Configure CloudKit (Optional)

CloudKit is already configured in the entitlements file. The container will be created automatically when you build with your Apple Developer account.

**Container ID**: `iCloud.de.nick-friedrich.dockfinity` (or your bundle identifier)

To verify CloudKit is working:

1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
2. Look for your container
3. It will be created on first launch

### 5. Build and Run

1. Select your Mac as the destination (not a simulator)
2. Press Cmd+R or click the Run button
3. The app will launch and create a "Default" profile from your current Dock

## Project Structure

```
apps/dockfinity/dockfinity/
├── Models/
│   ├── Profile.swift        # Profile data model
│   └── DockItem.swift        # Dock item data model
├── Services/
│   ├── DockUtilService.swift     # Dock manipulation
│   └── DockStateManager.swift    # State coordination
├── Views/
│   ├── ProfileListView.swift     # Sidebar profile list
│   ├── ProfileDetailView.swift   # Profile details
│   └── ProfileFormView.swift     # Create/edit forms
├── ContentView.swift         # Main app view
├── dockfinityApp.swift      # App entry point
└── dockfinity.entitlements  # Permissions
```

## Permissions & Entitlements

The app requires these entitlements (already configured):

- **App Sandbox**: Enabled for security
- **File Access**: Read/write to user-selected files and home directory
- **Apple Events**: To communicate with Dock.app
- **Automation**: To send Apple Events
- **Network**: For CloudKit sync
- **CloudKit**: For profile syncing

## Troubleshooting Setup

### Build Errors

**"No such module 'SwiftData'"**

- Ensure you're building for macOS 15.0 or later
- Check deployment target in project settings

**Signing errors**

- Select a valid development team
- Ensure you have a valid provisioning profile

### Runtime Issues

**"dockutil: command not found"**

- Install dockutil via Homebrew
- Ensure `/opt/homebrew/bin` is in your PATH

**CloudKit errors**

- Ensure you're signed in to iCloud on your Mac
- Check that CloudKit is enabled in iCloud settings
- The container will be created automatically on first launch

### Permission Denied Errors

The app needs permission to:

- Execute commands (for dockutil)
- Read/write Dock preferences
- Send Apple Events to Dock.app

If you see permission errors:

1. Go to System Settings → Privacy & Security
2. Check "Automation" and "Apple Events" sections
3. Ensure DockFinity has necessary permissions

## Development Tips

### Testing Without dockutil

For development/testing without modifying your actual Dock, the app will fall back to reading the Dock plist directly. However, applying profiles requires dockutil.

### Debugging

Enable more verbose output:

1. Edit scheme (Product → Scheme → Edit Scheme)
2. Add environment variable: `DEBUG=1`
3. Check Console.app for detailed logs

### Testing CloudKit Sync

1. Build and run on one Mac
2. Create/modify profiles
3. Build and run on another Mac with same Apple ID
4. Profiles should sync automatically (may take a few moments)

## Next Steps

See the main [README.md](README.md) for usage instructions and [features.md](../../features.md) for the development roadmap.

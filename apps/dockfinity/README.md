# DockFinity

A macOS application for managing and switching between different Dock profiles/layouts.

## Features (MVP)

- ✅ Create, rename, and delete Dock profiles
- ✅ Capture current Dock state into profiles
- ✅ Apply profiles to instantly change your Dock layout
- ✅ Refresh profiles from current Dock state
- ✅ Duplicate profiles for quick variations
- ✅ CloudKit sync support (profiles sync across your Macs)
- ✅ Automatic "Default" profile creation on first launch

## Requirements

### System Requirements

- macOS 15.0 or later
- Xcode 16.0 or later (for development)

### Dependencies

#### dockutil (Required)

DockFinity **requires** `dockutil` to safely manipulate the Dock using standard macOS APIs. The app will not work without it.

**Installation via Homebrew (Required):**

```bash
brew install dockutil
```

**Why is it required?**

- Safely reads and writes Dock configuration
- Prevents corruption of Dock preferences
- Industry-standard tool used by many Dock managers
- Handles edge cases and macOS version differences

**Verification:**

```bash
which dockutil
# Should output: /opt/homebrew/bin/dockutil (Apple Silicon)
# or: /usr/local/bin/dockutil (Intel Mac)
```

**Without dockutil:**
The app will show a clear error message prompting you to install it.

## Setup

1. Clone the repository
2. Install dockutil (see above)
3. Open `apps/dockfinity/dockfinity.xcodeproj` in Xcode
4. Select your development team in the project settings
5. Build and run

## Permissions

DockFinity requires the following permissions:

- **Process execution**: To run dockutil commands
- **File system access**: To read Dock preferences
- **CloudKit**: Optional, for syncing profiles across devices

The app is sandboxed but configured to allow necessary Dock manipulation operations.

## Usage

### First Launch

On first launch, DockFinity will automatically capture your current Dock layout and save it as a "Default" profile. This ensures you can always return to your original setup.

### Creating Profiles

1. Click the "+" button in the sidebar
2. Enter a name for your profile
3. Click "Save"

### Populating Profiles

- **From current Dock**: Select a profile and click "Refresh from Dock" to capture your current Dock state
- **Duplicate existing**: Right-click a profile and select "Duplicate"

### Applying Profiles

- Click the "Apply Profile" button in the toolbar, or
- Right-click a profile and select "Apply Profile"

Your Dock will be updated instantly with the selected profile's items.

### Managing Profiles

- **Rename**: Right-click → Rename
- **Duplicate**: Right-click → Duplicate
- **Delete**: Right-click → Delete (cannot delete Default profile)

## Architecture

### Data Models

- `Profile`: Represents a Dock layout with metadata
- `DockItem`: Individual items (apps, folders, URLs, spacers) in a profile

### Services

- `DockUtilService`: Low-level Dock manipulation using dockutil
- `DockStateManager`: Coordinates between SwiftData and Dock operations

### UI Components

- `ProfileListView`: Sidebar listing all profiles
- `ProfileDetailView`: Shows items in selected profile
- `ProfileFormView`: Create/edit profile names
- `ContentView`: Main split-view layout

## CloudKit Sync

Profiles automatically sync via CloudKit to your other Macs logged in with the same Apple ID. Note:

- First sync may take a few moments
- Requires iCloud to be enabled
- Uses private database (data is not shared publicly)

## Troubleshooting

### "dockutil not found" error

Install dockutil using Homebrew: `brew install dockutil`

### Dock doesn't change after applying profile

- Check Console.app for error messages
- Ensure dockutil is installed and in PATH
- Try manually restarting Dock: `killall Dock`

### Profile seems empty after refresh

- Ensure you have items in your Dock
- Check that dockutil is working: `dockutil --list`

## Development Roadmap

See `features.md` in the project root for the full feature roadmap.

### Completed (MVP)

- Profile CRUD operations
- Dock state capture and application
- CloudKit sync
- First-launch setup

### Planned (v2)

- Global hotkeys for profile switching
- Custom icons and colors
- Automatic/contextual switching
- Import/export profiles
- Menu bar mode

## License

TBD

## Contributing

TBD

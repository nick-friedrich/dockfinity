## 1.0.5

- **CRITICAL FIX**: Resolved profile persistence issue where saved dock profiles were disappearing after app restart
- Fixed SwiftData configuration to use local-only storage with explicit CloudKit disabling
- Profiles now reliably persist across app restarts and system reboots
- Addresses data loss issue caused by CloudKit to local-only storage migration

## 1.0.4

- Added automatic update notifications from GitHub releases
- App checks for updates on launch and displays notification when new version is available
- Manual update check available in menu bar and Settings
- Shows current version and last update check time in Settings

- Fixed bug where folders next to Trash (persistentOthers section) disappeared when switching profiles
- App now properly saves and restores all dock sections (apps and others)
- Folders like Applications, Downloads, etc. will now persist across profile changes
- Added section toggle for folders to switch between "Apps" and "Others" placement in the Dock

## 1.0.3

- Fixed profile persistence issue (profiles no longer disappear after restart)
- Added "Launch at Login" option in Settings

## 1.0.2

- Added Settings window
- Added Setting to hide DockFinity icon in Dock
- Added ability to add folders to a profile

# DockFinity Troubleshooting Guide

## Issues Fixed

### ✅ Sendable Conformance Warning

Fixed - Models now properly conform to Sendable protocol.

### ✅ Better Error Messages

Added LocalizedError conformance to DockUtilError with helpful messages.

### ✅ Debug Logging

Added extensive debug logging to track dock reading process.

## Current Issue: Empty Default Profile

If the Default profile is empty when you first launch the app, follow these steps:

### Step 1: Check Console Output

1. In Xcode, open the **Console** (View → Debug Area → Activate Console)
2. Look for these debug messages:
   - `🚀 Creating default profile...`
   - `🔍 Checking for dockutil...`
   - `📖 Reading Dock from plist:`
   - `📱 Found X persistent apps`

### Step 2: Common Issues

#### A. dockutil Not Installed

If you see: `⚠️ dockutil not found, using plist fallback`

**Solution:**

```bash
brew install dockutil
```

Then restart the app.

#### B. Plist Reading Failed

If you see: `❌ Failed to read plist data`

**Solution:**

1. Check that `~/Library/Preferences/com.apple.dock.plist` exists
2. Try restarting the Dock: `killall Dock`
3. Delete the app and reinstall

#### C. Permissions Issue

The app might not have permission to read the Dock plist.

**Solution:**

1. Go to **System Settings → Privacy & Security**
2. Check **Full Disk Access** - add DockFinity if needed
3. Restart the app

### Step 3: Reset the App

If the Default profile was created empty, you need to reset it:

1. **Quit the app completely**
2. **Delete app data:**

   ```bash
   # Delete UserDefaults
   defaults delete de.nick-friedrich.dockfinity

   # Delete SwiftData storage
   rm -rf ~/Library/Containers/de.nick-friedrich.dockfinity/
   ```

3. **Restart the app**
4. **Check Console output** to see if it reads the Dock correctly

### Step 4: Manual Profile Creation

If automatic detection still fails, you can:

1. Create a new profile manually
2. Add apps to your Dock manually
3. Click "Refresh from Dock" on that profile
4. Check Console output for any errors

## Menu Bar Mode (Not Yet Implemented)

**Note:** The current MVP is a **regular windowed app**, not a menu bar app.

The plan specified building a windowed app first (option 1b). Menu bar mode is planned for v2.

### Expected Behavior (Current):

- App shows a normal window
- App icon in Dock (like any regular app)
- No menu bar icon

### Future Feature:

- Menu bar icon with quick profile switching
- Option to hide Dock icon
- Global hotkeys

This will be added in Phase 2B of development.

## Verifying Dock Reading Works

Run this test:

1. **Check your current Dock** - note which apps are there
2. **Open Terminal** and run:
   ```bash
   defaults read com.apple.dock persistent-apps | grep file-label
   ```
   This shows what's in the plist
3. **Launch DockFinity** with Console open
4. **Look for the debug output** showing what it read
5. **Compare** - does the output match your Dock?

If the Terminal command shows apps but DockFinity doesn't read them, check the Console for specific error messages.

## Apply Profile Fails

If you get: `Failed to apply profile: dockutil is not installed`

**This is expected** - dockutil is required to modify the Dock (not just read it).

**Solution:**

```bash
brew install dockutil
```

**Why?**

- Reading the Dock: Can use plist (no dockutil needed)
- Writing to the Dock: Requires dockutil for safety

## Still Having Issues?

1. Check Console output for specific errors
2. Verify dockutil: `which dockutil`
3. Verify Dock plist exists: `ls -la ~/Library/Preferences/com.apple.dock.plist`
4. Try the reset steps above
5. Build the app fresh (Clean Build Folder: Shift+Cmd+K)

## Next Steps After Fixing

Once the Default profile loads correctly:

1. ✅ View your apps in the Default profile
2. ✅ Create a new profile ("Work", "Gaming", etc.)
3. ✅ Modify your Dock manually
4. ✅ Click "Refresh from Dock" on the new profile
5. ✅ Switch between profiles using "Apply Profile"

---

**Remember:**

- Install dockutil: `brew install dockutil`
- Check Console output in Xcode
- Reset app data if Default profile is empty

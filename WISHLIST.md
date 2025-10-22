# DockFinity Feature Wishlist

## Core Features (In Progress)

### Profile Management

- [ ] Add apps, URLs, folders in a profile
- [ ] Smart Web links: include website shortcuts (fetch favicon automatically or custom icons)
- [ ] Custom icons & colors for tiles
- [ ] Profile sidebar + menu bar access
- [ ] Works offline, no cloud dependency, runs locally
- [ ] Saves a "Default" profile (original Dock) so you can revert
- [ ] Optionally "spacers" or separators

### Icon & Tile Customization

- [ ] Choose custom icons or colors per tile (for visual theming)
- [ ] Fetch favicon automatically for URL items

### Keyboard Shortcuts

- [ ] Hotkeys for profile switching
  - For each profile, allow the user to assign a global hotkey (e.g. Cmd+1, Cmd+2, etc)
  - Pressing the hotkey changes the Dock to that profile
- [ ] Hotkeys for opening apps/items
  - In addition to profile hotkeys, allow mapping hotkeys to individual Dock items (apps/URLs)
  - If that item is already in the Dock/current profile, bring it forward or open it

### Conflict & Error Handling

- [ ] If an app in the profile isn't installed, show warning/skip it
- [ ] If applying a profile fails partially, notify user
- [ ] Optionally prompt before removing an app from Dock during switch

### Import/Export

- [ ] Export profile data (JSON or similar) to share or backup
- [ ] Import someone else's profile or a JSON

## Advanced Features (Future)

### Automatic/Contextual Switching

- [ ] Trigger profile switch automatically on events:
  - Connect to external display
  - Change Focus mode
  - Time of day
- [ ] Option to "watch" system states

### Cloud Sync

- [ ] Optional cloud sync (through iCloud, Dropbox, etc) for profiles
- [ ] Sync across multiple Macs

### Profile Versioning

- [ ] Keep change history so user can revert to earlier versions
- [ ] Profile versioning/history

### Performance Optimization

- [ ] Conditional/progressive switching
  - For large profiles, allow staged application (load essential items first, rest after)
  - Or only switch if difference is beyond a threshold
- [ ] Fast switching/minimal latency
  - The switch should feel instant — minimal flicker or delay

### Advanced Profile Features

- [ ] Partial merges/overlay profiles
  - Overlay "extra items" on top of a base profile
  - Merge two profiles (e.g. base + extra)

### Multi-Display Support

- [ ] Support for macOS Spaces/multiple displays
  - If Dock items differ per display/screen configuration, enable detecting which display is active and adjust
  - Manage how profiles behave with multiple monitors

### UI/UX Polish

- [ ] Theming/UI polish
  - Light/dark mode
  - Animation transitions when applying profile
  - Hide or auto-hide icon of the app itself

### Automation & Integration

- [ ] Accessibility/scripting/automation support
  - Allow scripting/CLI support
  - AppleScript support
  - Shortcuts support
  - Provide accessibility support for keyboard users

## Technical Challenges & Edge Cases

### Security & Permissions

- [ ] Handle macOS security/permissions for modifying Dock layout
- [ ] Test compatibility across macOS versions (especially newer ones)

### System Integration

- [ ] Dealing with "persistent apps" or system apps that always appear in Dock
- [ ] Handling apps that are currently running vs not installed
- [ ] Ensuring transitions don't cause flicker, dock crash, or user data loss

### Conflict Management

- [ ] Hotkey conflicts (user might already have Cmd+1 assigned elsewhere)
- [ ] Managing icon caches (if custom icons are used)
- [ ] Undo/rollback if something goes wrong

## Feature Requests from Users

- [ ] Hotkey assignment for profiles
- [ ] Automatic switching tied to system state or context (Focus mode, etc)

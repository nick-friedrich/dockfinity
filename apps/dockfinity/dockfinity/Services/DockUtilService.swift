//
//  DockUtilService.swift
//  dockfinity
//
//  Created by Nick Friedrich on 18.10.25.
//

import Foundation

enum DockUtilError: Error, LocalizedError {
    case dockutilNotFound
    case commandFailed(String)
    case parsingFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .dockutilNotFound:
            return "dockutil is not installed. Please install it with: brew install dockutil"
        case .commandFailed(let message):
            return "Dock command failed: \(message)"
        case .parsingFailed:
            return "Failed to read Dock configuration"
        case .permissionDenied:
            return "Permission denied. Please grant necessary permissions in System Settings."
        }
    }
}

struct DockItemInfo {
    let type: DockItemType
    let name: String
    let path: String
}

class DockUtilService {
    static let shared = DockUtilService()
    
    private var dockutilPath: String?
    
    private init() {}
    
    // MARK: - Read Dock State
    
    /// Reads the current Dock configuration and returns an array of DockItemInfo
    func readCurrentDock() async throws -> [DockItemInfo] {
        print("🔍 Checking for dockutil...")
        
        // Check if dockutil is available
        guard await isDockutilAvailable() else {
            print("❌ dockutil not found!")
            throw DockUtilError.dockutilNotFound
        }
        
        print("✅ dockutil found, reading Dock...")
        let output = try await runDockutilCommand(["--list"])
        let items = try parseDockutilOutput(output)
        print("📊 Read \(items.count) items from Dock")
        return items
    }
    
    // MARK: - Apply Profile to Dock
    
    /// Applies a profile to the Dock by clearing current items and adding profile items
    func applyProfile(items: [DockItem]) async throws {
        // Ensure dockutil is available before attempting to apply
        guard await isDockutilAvailable() else {
            print("❌ dockutil not found when trying to apply profile!")
            throw DockUtilError.dockutilNotFound
        }
        
        let validItems = items.filter { item in
            switch item.type {
            case .app, .folder:
                let ok = FileManager.default.fileExists(atPath: item.path)
                if !ok { print("🚫 Skipping missing \(item.type) '\(item.name)' at \(item.path)") }
                return ok
            case .url, .spacer:
                return true
            }
        }
        
        if validItems.count != items.count {
            print("⚠️ Some items were skipped due to invalid paths. Proceeding with \(validItems.count) valid items…")
        }
        
        // First, remove all current items and kill cfprefsd to clear cache
        try await clearDock()
        
        // Sort items by position
        let sortedItems = validItems.sorted(by: { $0.position < $1.position })
        
        for (i, item) in sortedItems.enumerated() {
            print("  [\(i + 1)/\(validItems.count)] Adding \(item.name)...")
            try await addItemToDock(item, noRestart: true)
            try await Task.sleep(nanoseconds: 50_000_000) // 0.2s between items

        }

        // Restart Dock to commit the batch
        print("🔄 Restarting Dock to commit batch...")
        try await restartDock()
        
        // Final verification
        print("⏳ Performing final verification...")
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Count how many items are actually in the Dock
        do {
            let currentItems = try await readCurrentDock()
            print("✅ Profile applied! \(currentItems.count) items now in Dock (expected \(validItems.count))")
            
            if currentItems.count < validItems.count {
                print("⚠️ Warning: Some items may not have been added successfully")
                print("   Expected: \(validItems.count), Got: \(currentItems.count)")
            }
        } catch {
            print("⚠️ Could not verify final Dock state: \(error.localizedDescription)")
        }
    }
    
    /// Clears all items from the Dock
    private func clearDock() async throws {
        print("🧹 Clearing all items from Dock...")
        _ = try await runDockutilCommand(["--remove", "all", "--no-restart", "--verbose"])
        print("✅ Dock cleared")
    }
    
    /// Kills the cfprefsd daemon to force preference cache refresh
    private func killCfprefsd() async throws {
        _ = try? await runShellCommand("/usr/bin/killall", arguments: ["cfprefsd"])
        // cfprefsd will automatically restart when needed
    }
    
    /// Verifies that an item was actually added to the Dock
    private func verifyItemAdded(_ item: DockItem, maxAttempts: Int = 3) async -> Bool {
        for attempt in 0..<maxAttempts {
            if await dockContains(item) {
                print("    ✓ Verified: \(item.name) is in Dock")
                return true
            }
            if attempt < maxAttempts - 1 {
                print("    ⏳ Verification attempt \(attempt + 1) failed, retrying...")
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
        print("    ✗ Could not verify \(item.name) after \(maxAttempts) attempts")
        return false
    }
    
    /// Wait until Dock responds to dockutil (avoids "connection interrupted" races)
    private func waitForDockReady(timeoutSeconds: Int = 10) async {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        while Date() < deadline {
            do {
                _ = try await runDockutilCommand(["--list"]) // succeeds when Dock is ready
                return
            } catch {
                // Keep waiting
            }
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        }
    }
    
    /// Adds a single item to the Dock
    private func addItemToDock(_ item: DockItem, noRestart: Bool = true) async throws {
        // Validate target exists for app/folder to avoid silent dockutil no-ops
        if item.type == .app || item.type == .folder {
            if !FileManager.default.fileExists(atPath: item.path) {
                print("❌ Path does not exist: \(item.path). Skipping \(item.name)")
                throw DockUtilError.commandFailed("Target path not found: \(item.path)")
            }
        }
        
        var args: [String] = []
        
        switch item.type {
        case .app:
            // Explicitly add to apps section to avoid going to "others"
            args = ["--add", item.path, "--section", "apps"]
        case .folder:
            // Folders should go to "others" section by default, but we'll put them in apps
            args = ["--add", item.path, "--view", "auto", "--display", "folder", "--section", "apps"]
        case .url:
            args = ["--add", item.path, "--label", item.name, "--section", "apps"]
        case .spacer:
            args = ["--add", "", "--type", "spacer", "--section", "apps"]
        }
        
        // Add --no-restart flag if requested
        if noRestart {
            args.append("--no-restart")
        }
        
        _ = try await runDockutilCommand(args)
    }
    
    /// Restarts the Dock to apply changes
    func restartDock() async throws {
        _ = try await runShellCommand("/usr/bin/killall", arguments: ["Dock"])
        // Wait for Dock process to come back online and accept commands
        await waitForDockReady(timeoutSeconds: 12)
    }
    
    /// Check if a Dock item is present (by exact path for apps/folders, by label for URLs)
    private func dockContains(_ item: DockItem) async -> Bool {
        do {
            let output = try await runDockutilCommand(["--list"])        
            let infos = try parseDockutilOutput(output)
            switch item.type {
            case .app, .folder:
                return infos.contains { $0.path == item.path }
            case .url:
                // dockutil --list shows the label in the first column
                return infos.contains { $0.name == item.name }
            case .spacer:
                // spacers are not listed by --list; assume success after add
                return true
            }
        } catch {
            return false
        }
    }
    
    /// Verifies that the Dock plist was recently modified (useful for debugging)
    private func verifyDockPlistModified() {
        let dockPlistPath = "\(NSHomeDirectory())/Library/Preferences/com.apple.dock.plist"
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: dockPlistPath)
            if let modDate = attributes[.modificationDate] as? Date {
                let formatter = DateFormatter()
                formatter.timeStyle = .medium
                print("🧾 Dock plist last modified: \(formatter.string(from: modDate))")
                
                // Warn if plist hasn't been modified in the last 5 seconds
                if Date().timeIntervalSince(modDate) > 5 {
                    print("⚠️ Warning: Dock plist modification is stale (>5 seconds ago)")
                }
            }
        } catch {
            print("⚠️ Could not verify Dock plist modification: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Checks if dockutil is available on the system and caches its path
    private func isDockutilAvailable() async -> Bool {
        // Check common installation paths
        let possiblePaths = [
            "/opt/homebrew/bin/dockutil",  // Apple Silicon Homebrew
            "/usr/local/bin/dockutil",     // Intel Homebrew
            "/usr/bin/dockutil"            // System install
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                print("✅ Found dockutil at: \(path)")
                dockutilPath = path
                return true
            }
        }
        
        // Fallback: try using 'which'
        do {
            let output = try await runShellCommand("/usr/bin/which", arguments: ["dockutil"])
            let trimmedPath = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedPath.isEmpty && FileManager.default.fileExists(atPath: trimmedPath) {
                print("✅ Found dockutil via which: \(trimmedPath)")
                dockutilPath = trimmedPath
                return true
            }
        } catch {
            print("❌ dockutil not found in PATH")
        }
        
        return false
    }
    
    /// Runs a dockutil command and returns output
    private func runDockutilCommand(_ arguments: [String]) async throws -> String {
        guard let dockutilPath else {
            throw DockUtilError.dockutilNotFound
        }
        return try await runShellCommand(dockutilPath, arguments: arguments)
    }
    
    /// Runs a shell command and returns output
    /// Uses /bin/sh as a wrapper to properly handle environment and paths
    private func runShellCommand(_ command: String, arguments: [String]) async throws -> String {
        print("🔧 Executing: \(command) \(arguments.joined(separator: " "))")
        
        // Verify the command file exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: command) else {
            print("❌ File does not exist at path: \(command)")
            throw DockUtilError.commandFailed("File does not exist: \(command)")
        }
        
        // Build the full command string for shell execution
        // Escape arguments properly
        let escapedArgs = arguments.map { arg in
            // Escape special shell characters
            let escaped = arg.replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "\"", with: "\\\"")
                            .replacingOccurrences(of: "$", with: "\\$")
                            .replacingOccurrences(of: "`", with: "\\`")
            return "\"\(escaped)\""
        }
        
        let fullCommand = "\(command) \(escapedArgs.joined(separator: " "))"
        print("📝 Shell command: \(fullCommand)")
        
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        // Use /bin/sh to execute the command
        // This handles PATH, environment, and dynamic libraries correctly
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", fullCommand]
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
            
            // Check for errors in stderr even if exit status is 0
            // dockutil sometimes reports "Dock connection error" but still exits successfully
            let hasConnectionError = errorOutput.lowercased().contains("dock connection error") ||
                                    errorOutput.lowercased().contains("connection interrupted")
            
            if process.terminationStatus != 0 {
                print("❌ Process failed with status \(process.terminationStatus): \(errorOutput)")
                throw DockUtilError.commandFailed(errorOutput)
            } else if hasConnectionError {
                print("⚠️ Warning: Dock connection issue detected: \(errorOutput)")
                // Don't throw - these are often transient warnings that don't prevent success
            }
            
            if !errorOutput.isEmpty && !hasConnectionError {
                print("⚠️ Process stderr: \(errorOutput)")
            }
            
            print("✅ Process completed successfully")
            return output
        } catch let error as NSError {
            print("❌ Failed to run process: \(error.localizedDescription) (code: \(error.code))")
            throw DockUtilError.commandFailed("Failed to execute via shell: \(error.localizedDescription)")
        }
    }
    
    /// Parses dockutil --list output into DockItemInfo array
    private func parseDockutilOutput(_ output: String) throws -> [DockItemInfo] {
        var items: [DockItemInfo] = []
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        for line in lines {
            // dockutil --list output format: "Name\tfile://path/\tpersistentApps\tplist\tbundle_id"
            let components = line.components(separatedBy: "\t")
            guard components.count >= 3 else { continue }
            
            let name = components[0]
            let path = components[1]
            let section = components[2] // "persistentApps" or "persistentOthers"
            
            // Only include pinned apps (persistentApps), skip recent/others
            guard section == "persistentApps" else {
                print("  ⏭️  Skipping non-pinned item: \(name)")
                continue
            }
            
            // Clean up the path (remove file:// prefix and trailing slash, but keep leading /)
            var cleanPath = path.replacingOccurrences(of: "file://", with: "")
            
            // Remove trailing slashes but preserve leading slash
            while cleanPath.hasSuffix("/") && cleanPath.count > 1 {
                cleanPath.removeLast()
            }
            
            // Decode URL encoding (e.g., %20 -> space)
            if let decodedPath = cleanPath.removingPercentEncoding {
                cleanPath = decodedPath
            }
            
            // Determine type based on path
            let type: DockItemType
            if cleanPath.hasSuffix(".app") {
                type = .app
            } else if cleanPath.starts(with: "http://") || cleanPath.starts(with: "https://") {
                type = .url
            } else if cleanPath.contains("spacer") {
                type = .spacer
            } else {
                type = .folder
            }
            
            items.append(DockItemInfo(type: type, name: name, path: cleanPath))
        }
        
        print("✅ Parsed \(items.count) pinned apps (filtered out non-pinned items)")
        return items
    }
}

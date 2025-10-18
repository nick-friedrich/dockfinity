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
        
        print("📝 Applying profile with \(items.count) items...")
        
        // First, remove all current items
        try await clearDock()
        
        // Then add items from the profile in order
        for item in items.sorted(by: { $0.position < $1.position }) {
            try await addItemToDock(item)
        }
        
        // Restart Dock to apply changes
        try await restartDock()
        
        print("✅ Profile applied successfully!")
    }
    
    /// Clears all items from the Dock
    private func clearDock() async throws {
        _ = try await runDockutilCommand(["--remove", "all"])
    }
    
    /// Adds a single item to the Dock
    private func addItemToDock(_ item: DockItem) async throws {
        switch item.type {
        case .app:
            _ = try await runDockutilCommand(["--add", item.path, "--no-restart"])
        case .folder:
            _ = try await runDockutilCommand(["--add", item.path, "--view", "auto", "--display", "folder", "--no-restart"])
        case .url:
            // For URLs, we might need special handling
            _ = try await runDockutilCommand(["--add", item.path, "--label", item.name, "--no-restart"])
        case .spacer:
            _ = try await runDockutilCommand(["--add", "", "--type", "spacer", "--section", "apps", "--no-restart"])
        }
    }
    
    /// Restarts the Dock to apply changes
    func restartDock() async throws {
        _ = try await runShellCommand("/usr/bin/killall", arguments: ["Dock"])
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
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("❌ Process failed with status \(process.terminationStatus): \(errorOutput)")
                throw DockUtilError.commandFailed(errorOutput)
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


//
//  DockUtilService.swift
//  dockfinity
//
//  Created by Nick Friedrich on 18.10.25.
//

import Foundation

enum DockUtilError: Error {
    case dockutilNotFound
    case commandFailed(String)
    case parsingFailed
    case permissionDenied
}

struct DockItemInfo {
    let type: DockItemType
    let name: String
    let path: String
}

class DockUtilService {
    static let shared = DockUtilService()
    
    private init() {}
    
    // MARK: - Read Dock State
    
    /// Reads the current Dock configuration and returns an array of DockItemInfo
    func readCurrentDock() async throws -> [DockItemInfo] {
        // Check if dockutil is available
        guard await isDockutilAvailable() else {
            // Fallback to plist reading if dockutil is not available
            return try readDockFromPlist()
        }
        
        let output = try await runDockutilCommand(["--list"])
        return try parseDockutilOutput(output)
    }
    
    /// Reads Dock items from the com.apple.dock.plist file directly
    private func readDockFromPlist() throws -> [DockItemInfo] {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let plistPath = homeDirectory.appendingPathComponent("Library/Preferences/com.apple.dock.plist")
        
        guard let plistData = try? Data(contentsOf: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let persistentApps = plist["persistent-apps"] as? [[String: Any]] else {
            throw DockUtilError.parsingFailed
        }
        
        var items: [DockItemInfo] = []
        
        for app in persistentApps {
            if let tileData = app["tile-data"] as? [String: Any] {
                if let fileData = tileData["file-data"] as? [String: Any],
                   let filePath = fileData["_CFURLString"] as? String,
                   let fileName = tileData["file-label"] as? String {
                    
                    let type: DockItemType = filePath.hasPrefix("file://") ? .app : .url
                    let cleanPath = filePath.replacingOccurrences(of: "file://", with: "")
                    
                    items.append(DockItemInfo(type: type, name: fileName, path: cleanPath))
                }
            }
        }
        
        // Also read folders from persistent-others
        if let persistentOthers = plist["persistent-others"] as? [[String: Any]] {
            for other in persistentOthers {
                if let tileData = other["tile-data"] as? [String: Any],
                   let fileData = tileData["file-data"] as? [String: Any],
                   let filePath = fileData["_CFURLString"] as? String,
                   let fileName = tileData["file-label"] as? String {
                    
                    let cleanPath = filePath.replacingOccurrences(of: "file://", with: "")
                    items.append(DockItemInfo(type: .folder, name: fileName, path: cleanPath))
                }
            }
        }
        
        return items
    }
    
    // MARK: - Apply Profile to Dock
    
    /// Applies a profile to the Dock by clearing current items and adding profile items
    func applyProfile(items: [DockItem]) async throws {
        // First, remove all current items
        try await clearDock()
        
        // Then add items from the profile in order
        for item in items.sorted(by: { $0.position < $1.position }) {
            try await addItemToDock(item)
        }
        
        // Restart Dock to apply changes
        try await restartDock()
    }
    
    /// Clears all items from the Dock
    private func clearDock() async throws {
        if await isDockutilAvailable() {
            _ = try await runDockutilCommand(["--remove", "all"])
        } else {
            // Use defaults command to clear
            _ = try await runShellCommand("/usr/bin/defaults", arguments: ["write", "com.apple.dock", "persistent-apps", "-array"])
            _ = try await runShellCommand("/usr/bin/defaults", arguments: ["write", "com.apple.dock", "persistent-others", "-array"])
        }
    }
    
    /// Adds a single item to the Dock
    private func addItemToDock(_ item: DockItem) async throws {
        guard await isDockutilAvailable() else {
            // For now, require dockutil for adding items
            throw DockUtilError.dockutilNotFound
        }
        
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
    
    /// Checks if dockutil is available on the system
    private func isDockutilAvailable() async -> Bool {
        do {
            _ = try await runShellCommand("/usr/bin/which", arguments: ["dockutil"])
            return true
        } catch {
            return false
        }
    }
    
    /// Runs a dockutil command and returns output
    private func runDockutilCommand(_ arguments: [String]) async throws -> String {
        return try await runShellCommand("dockutil", arguments: arguments)
    }
    
    /// Runs a shell command and returns output
    private func runShellCommand(_ command: String, arguments: [String]) async throws -> String {
        let process = Process()
        let pipe = Pipe()
        let errorPipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw DockUtilError.commandFailed(errorOutput)
        }
        
        return output
    }
    
    /// Parses dockutil --list output into DockItemInfo array
    private func parseDockutilOutput(_ output: String) throws -> [DockItemInfo] {
        var items: [DockItemInfo] = []
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        for line in lines {
            // dockutil --list output format: "Label	path"
            let components = line.components(separatedBy: "\t")
            guard components.count >= 2 else { continue }
            
            let name = components[0]
            let path = components[1]
            
            // Determine type based on path
            let type: DockItemType
            if path.hasSuffix(".app") {
                type = .app
            } else if path.starts(with: "http://") || path.starts(with: "https://") {
                type = .url
            } else if path.contains("spacer") {
                type = .spacer
            } else {
                type = .folder
            }
            
            items.append(DockItemInfo(type: type, name: name, path: path))
        }
        
        return items
    }
}


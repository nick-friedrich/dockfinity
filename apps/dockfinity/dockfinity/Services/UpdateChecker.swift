//
//  UpdateChecker.swift
//  dockfinity
//
//  Service to check for app updates from GitHub releases
//

import Foundation
import AppKit
import Combine

@MainActor
class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    
    @Published var isUpdateAvailable = false
    @Published var latestVersion: String = ""
    @Published var releaseURL: String = ""
    @Published var isChecking = false
    @Published var lastCheckDate: Date?
    
    private let githubRepo = "nick-friedrich/dockfinity" // Update this to your actual GitHub repo
    private let lastCheckKey = "DockFinity_LastUpdateCheck"
    
    private init() {
        self.lastCheckDate = UserDefaults.standard.object(forKey: lastCheckKey) as? Date
    }
    
    /// Get the current app version from Bundle
    var currentVersion: String {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return version
        }
        return "0.0.0"
    }
    
    /// Check for updates from GitHub releases
    func checkForUpdates(silent: Bool = false, notify: Bool = true) async {
        guard !isChecking else { return }
        
        isChecking = true
        defer { isChecking = false }
        
        do {
            let latest = try await fetchLatestRelease()
            
            // Save last check date
            lastCheckDate = Date()
            UserDefaults.standard.set(lastCheckDate, forKey: lastCheckKey)
            
            // Compare versions
            if compareVersions(current: currentVersion, latest: latest.version) {
                latestVersion = latest.version
                releaseURL = latest.url
                // Only set isUpdateAvailable if notify is true (to trigger sheet)
                if notify {
                    isUpdateAvailable = true
                }
            } else if !silent {
                // Only show "up to date" message if not silent
                latestVersion = latest.version
                if notify {
                    isUpdateAvailable = false
                }
            }
        } catch {
            if !silent {
                print("Error checking for updates: \(error)")
            }
        }
    }
    
    /// Check for updates and return result without triggering notifications
    func checkForUpdatesAndGetResult() async -> (isUpdateAvailable: Bool, latestVersion: String) {
        await checkForUpdates(silent: false, notify: false)
        return (compareVersions(current: currentVersion, latest: latestVersion), latestVersion)
    }
    
    /// Fetch latest release from GitHub API
    private func fetchLatestRelease() async throws -> (version: String, url: String) {
        let urlString = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        guard let url = URL(string: urlString) else {
            throw UpdateError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UpdateError.networkError
        }
        
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        
        // Remove 'v' prefix if present
        let version = release.tagName.replacingOccurrences(of: "v", with: "")
        
        return (version: version, url: release.htmlURL)
    }
    
    /// Compare version strings (returns true if latest > current)
    func compareVersions(current: String, latest: String) -> Bool {
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(currentComponents.count, latestComponents.count)
        
        for i in 0..<maxLength {
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0
            let latestPart = i < latestComponents.count ? latestComponents[i] : 0
            
            if latestPart > currentPart {
                return true
            } else if latestPart < currentPart {
                return false
            }
        }
        
        return false
    }
    
    /// Open the releases page in the default browser
    func openReleasePage() {
        if let url = URL(string: releaseURL.isEmpty ? "https://github.com/\(githubRepo)/releases" : releaseURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Reset update notification
    func dismissUpdate() {
        isUpdateAvailable = false
    }
}

// MARK: - GitHub API Models

struct GitHubRelease: Codable {
    let tagName: String
    let htmlURL: String
    let name: String
    let body: String?
    let publishedAt: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case name
        case body
        case publishedAt = "published_at"
    }
}

enum UpdateError: Error {
    case invalidURL
    case networkError
    case invalidResponse
}


import Foundation

struct FileRepositoryStore: RepositoryStore {
    private let fileURL: URL

    init(fileName: String = "repositories.json") {
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let bundleID = Bundle.main.bundleIdentifier ?? "SourceBySfxx"
        let directory = supportURL?.appendingPathComponent(bundleID, isDirectory: true)
        self.fileURL = directory?.appendingPathComponent(fileName) ?? URL(fileURLWithPath: fileName)

        if let directory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    func load() throws -> [RepositoryRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([RepositoryRecord].self, from: data)
    }

    func save(_ records: [RepositoryRecord]) throws {
        let data = try JSONEncoder().encode(records)
        try data.write(to: fileURL, options: [.atomic])
    }
}

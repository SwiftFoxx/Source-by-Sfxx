import Foundation

struct RepositoryAccess {
    struct Resolution {
        let url: URL
        let refreshedBookmark: Data?
    }

    func resolve(from bookmark: Data) throws -> Resolution {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        let refreshed = isStale ? try url.bookmarkData(options: [.withSecurityScope]) : nil
        return Resolution(url: url, refreshedBookmark: refreshed)
    }

    func withAccess<T>(from bookmark: Data, _ body: (URL) throws -> T) throws -> (T, Data?) {
        let resolution = try resolve(from: bookmark)
        let didAccess = resolution.url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                resolution.url.stopAccessingSecurityScopedResource()
            }
        }
        let value = try body(resolution.url)
        return (value, resolution.refreshedBookmark)
    }

    func withAccess<T>(from bookmark: Data, _ body: (URL) async throws -> T) async throws -> (T, Data?) {
        let resolution = try resolve(from: bookmark)
        let didAccess = resolution.url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                resolution.url.stopAccessingSecurityScopedResource()
            }
        }
        let value = try await body(resolution.url)
        return (value, resolution.refreshedBookmark)
    }
}

import Foundation
import Observation
#if os(macOS)
import AppKit
#endif

@Observable
@MainActor
final class AppModel {
    var repositories: [Repository]
    var activity: [ActivityItem]
    var selectedRepositoryID: Repository.ID?
    var sidebarSelection: SidebarItem
    var autoFetchEnabled: Bool
    var autoFetchIntervalMinutes: Int
    var backgroundFetchPolicy: BackgroundFetchPolicy

    private let gitClient: GitClient
    private let gitMonitor: GitMonitoring
    private let repositoryStore: RepositoryStore
    private let repositoryAccess: RepositoryAccess

    @ObservationIgnored private var monitoringTasks: [Repository.ID: Task<Void, Never>] = [:]
    @ObservationIgnored private var repositoryBookmarks: [Repository.ID: Data] = [:]
    @ObservationIgnored private var lastRefreshByRepository: [Repository.ID: Date] = [:]
    @ObservationIgnored private var autoFetchTask: Task<Void, Never>?
    @ObservationIgnored private var autoFetchInFlight = false
    @ObservationIgnored private var isUpdatingInterval = false
    #if os(macOS)
    @ObservationIgnored private var backgroundScheduler: NSBackgroundActivityScheduler?
    #endif

    private enum DefaultsKey {
        static let autoFetchEnabled = "autoFetchEnabled"
        static let autoFetchIntervalMinutes = "autoFetchIntervalMinutes"
        static let backgroundFetchPolicy = "backgroundFetchPolicy"
    }

    init(
        gitClient: GitClient,
        gitMonitor: GitMonitoring,
        repositoryStore: RepositoryStore,
        repositoryAccess: RepositoryAccess
    ) {
        let defaults = UserDefaults.standard
        let savedInterval = defaults.integer(forKey: DefaultsKey.autoFetchIntervalMinutes)
        let interval = savedInterval > 0 ? savedInterval : 15
        let savedPolicyRaw = defaults.string(forKey: DefaultsKey.backgroundFetchPolicy)
        let savedPolicy = BackgroundFetchPolicy(rawValue: savedPolicyRaw ?? "")
        let defaultPolicy: BackgroundFetchPolicy = {
            #if os(macOS)
            return .systemScheduled
            #else
            return .appActiveOnly
            #endif
        }()

        self.gitClient = gitClient
        self.gitMonitor = gitMonitor
        self.repositoryStore = repositoryStore
        self.repositoryAccess = repositoryAccess
        self.repositories = []
        self.activity = []
        self.sidebarSelection = .repositories
        self.autoFetchEnabled = defaults.object(forKey: DefaultsKey.autoFetchEnabled) as? Bool ?? true
        self.autoFetchIntervalMinutes = interval
        self.backgroundFetchPolicy = savedPolicy ?? defaultPolicy

        loadRepositories()
        normalizeFetchPolicy()
        configureAutoFetch()
    }

    convenience init() {
        self.init(
            gitClient: GitShellClient(),
            gitMonitor: FileWatcherGitMonitor(),
            repositoryStore: FileRepositoryStore(),
            repositoryAccess: RepositoryAccess()
        )
    }

    func loadRepositories() {
        do {
            let records = try repositoryStore.load()
            repositoryBookmarks = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.bookmarkData) })
            repositories = records.map { record in
                Repository(
                    id: record.id,
                    name: record.name,
                    path: "",
                    remote: record.remote,
                    status: StatusSummary(branch: "unknown", ahead: 0, behind: 0, dirtyFiles: 0),
                    isValid: true
                )
            }
            if selectedRepositoryID == nil {
                selectedRepositoryID = repositories.first?.id
            }
            Task { await validateRepositories() }
        } catch {
            appendActivity(
                ActivityItem(
                    id: UUID(),
                    repositoryID: nil,
                    title: "Failed to load repositories",
                    detail: error.localizedDescription,
                    timestamp: Date(),
                    kind: .error
                )
            )
        }
    }

    func addRepositories(from urls: [URL]) {
        var records = (try? repositoryStore.load()) ?? []
        var newRepos: [Repository] = []

        for url in urls {
            guard url.hasDirectoryPath else { continue }

            let name = url.lastPathComponent
            let didAccess = url.startAccessingSecurityScopedResource()
            let isValid = isGitRepository(at: url)
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
            if !isValid {
                appendActivity(
                    ActivityItem(
                        id: UUID(),
                        repositoryID: nil,
                        title: "Invalid repository",
                        detail: "No .git directory found at \(url.lastPathComponent).",
                        timestamp: Date(),
                        kind: .warning
                    )
                )
            }

            do {
                let bookmark = try url.bookmarkData(options: [.withSecurityScope])
                let record = RepositoryRecord(
                    id: UUID(),
                    name: name,
                    remote: "",
                    bookmarkData: bookmark
                )
                records.append(record)

                let repo = Repository(
                    id: record.id,
                    name: name,
                    path: url.path,
                    remote: "",
                    status: StatusSummary(branch: "unknown", ahead: 0, behind: 0, dirtyFiles: 0),
                    isValid: isValid
                )
                newRepos.append(repo)
                repositoryBookmarks[record.id] = bookmark
            } catch {
                appendActivity(
                    ActivityItem(
                        id: UUID(),
                        repositoryID: nil,
                        title: "Failed to save repository",
                        detail: error.localizedDescription,
                        timestamp: Date(),
                        kind: .error
                    )
                )
            }
        }

        repositories.append(contentsOf: newRepos)
        if selectedRepositoryID == nil {
            selectedRepositoryID = repositories.first?.id
        }

        do {
            try repositoryStore.save(records)
        } catch {
            appendActivity(
                ActivityItem(
                    id: UUID(),
                    repositoryID: nil,
                    title: "Failed to persist repositories",
                    detail: error.localizedDescription,
                    timestamp: Date(),
                    kind: .error
                )
            )
        }
    }

    func removeRepository(_ repository: Repository) {
        repositories.removeAll { $0.id == repository.id }
        repositoryBookmarks[repository.id] = nil
        lastRefreshByRepository[repository.id] = nil

        if let task = monitoringTasks.removeValue(forKey: repository.id) {
            task.cancel()
        }

        if selectedRepositoryID == repository.id {
            selectedRepositoryID = repositories.first?.id
        }

        persistBookmarks()
    }

    func renameRepository(_ repository: Repository, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let index = repositories.firstIndex(where: { $0.id == repository.id }) {
            repositories[index].name = trimmed
        }

        persistBookmarks()
    }

    func startMonitoring() {
        for repo in repositories {
            guard monitoringTasks[repo.id] == nil else { continue }
            monitoringTasks[repo.id] = Task { [weak self] in
                await self?.startMonitoringRepository(repo)
            }
        }
    }

    func stopMonitoring() {
        for (_, task) in monitoringTasks {
            task.cancel()
        }
        monitoringTasks.removeAll()
    }

    func refreshStatus(for repository: Repository) async {
        do {
            let status = try await withRepositoryAccess(repository) { resolvedRepository in
                try await gitClient.status(for: resolvedRepository)
            }
            if let index = repositories.firstIndex(where: { $0.id == repository.id }) {
                repositories[index].status = status
            }
        } catch {
            appendActivity(
                ActivityItem(
                    id: UUID(),
                    repositoryID: repository.id,
                    title: "Status refresh failed",
                    detail: error.localizedDescription,
                    timestamp: Date(),
                    kind: .error
                )
            )
        }
    }

    func perform(_ action: GitAction, on repository: Repository) async {
        do {
            try await withRepositoryAccess(repository) { resolvedRepository in
                switch action {
                case .pull:
                    try await gitClient.pull(resolvedRepository)
                case .push:
                    try await gitClient.push(resolvedRepository)
                case .fetch:
                    try await gitClient.fetch(resolvedRepository)
                case .commit(let message):
                    try await gitClient.commit(resolvedRepository, message: message, amend: false, sign: false)
                case .checkout(let branch):
                    try await gitClient.checkout(resolvedRepository, branch: branch)
                case .createBranch(let name):
                    try await gitClient.createBranch(resolvedRepository, name: name)
                case .deleteBranch(let name):
                    try await gitClient.deleteBranch(resolvedRepository, name: name)
                case .stash(let message):
                    try await gitClient.stash(resolvedRepository, message: message)
                case .popStash:
                    try await gitClient.popStash(resolvedRepository)
                case .discardChanges:
                    try await gitClient.discardChanges(resolvedRepository)
                }
                return ()
            }
        } catch {
            appendActivity(
                ActivityItem(
                    id: UUID(),
                    repositoryID: repository.id,
                    title: "Action failed: \(action.title)",
                    detail: error.localizedDescription,
                    timestamp: Date(),
                    kind: .error
                )
            )
        }
    }

    private func startMonitoringRepository(_ repository: Repository) async {
        do {
            let resolvedRepository = try await resolveRepository(repository)
            if let index = repositories.firstIndex(where: { $0.id == repository.id }) {
                repositories[index].path = resolvedRepository.path
                repositories[index].isValid = resolvedRepository.isValid
            }
            await listenToEvents(for: resolvedRepository)
        } catch {
            appendActivity(
                ActivityItem(
                    id: UUID(),
                    repositoryID: repository.id,
                    title: "Monitoring failed",
                    detail: error.localizedDescription,
                    timestamp: Date(),
                    kind: .error
                )
            )
        }
    }

    private func listenToEvents(for repository: Repository) async {
        let bookmark = repositoryBookmarks[repository.id]
        for await event in gitMonitor.events(for: repository, bookmark: bookmark, access: repositoryAccess) {
            if Task.isCancelled { break }
            appendActivity(
                ActivityItem(
                    id: UUID(),
                    repositoryID: repository.id,
                    title: event.title,
                    detail: event.detail,
                    timestamp: event.timestamp,
                    kind: event.kind
                )
            )
            await refreshIfNeeded(for: repository)
        }
    }

    func loadBranches(for repository: Repository) async throws -> [Branch] {
        try await withRepositoryAccess(repository) { resolvedRepository in
            try await gitClient.branches(for: resolvedRepository)
        }
    }

    func loadCommits(for repository: Repository, limit: Int = 20) async throws -> [Commit] {
        try await withRepositoryAccess(repository) { resolvedRepository in
            try await gitClient.log(for: resolvedRepository, limit: limit)
        }
    }

    func loadStagedFiles(for repository: Repository) async throws -> [FileChange] {
        try await withRepositoryAccess(repository) { resolvedRepository in
            try await gitClient.stagedFiles(for: resolvedRepository)
        }
    }

    func loadUnstagedFiles(for repository: Repository) async throws -> [FileChange] {
        try await withRepositoryAccess(repository) { resolvedRepository in
            try await gitClient.unstagedFiles(for: resolvedRepository)
        }
    }

    func loadStagedDiff(for repository: Repository) async throws -> String {
        try await withRepositoryAccess(repository) { resolvedRepository in
            try await gitClient.stagedDiff(for: resolvedRepository)
        }
    }

    func loadDiff(for repository: Repository, path: String, staged: Bool) async throws -> String {
        try await withRepositoryAccess(repository) { resolvedRepository in
            try await gitClient.diff(for: resolvedRepository, path: path, staged: staged)
        }
    }

    func stageFile(_ path: String, in repository: Repository) async throws {
        try await withRepositoryAccess(repository) { resolvedRepository in
            try await gitClient.stageFile(resolvedRepository, path: path)
            return ()
        }
    }

    func unstageFile(_ path: String, in repository: Repository) async throws {
        try await withRepositoryAccess(repository) { resolvedRepository in
            try await gitClient.unstageFile(resolvedRepository, path: path)
            return ()
        }
    }

    func commitChanges(
        message: String,
        amend: Bool,
        sign: Bool,
        in repository: Repository
    ) async throws {
        try await withRepositoryAccess(repository) { resolvedRepository in
            try await gitClient.commit(resolvedRepository, message: message, amend: amend, sign: sign)
            return ()
        }
    }

    func createBranch(_ name: String, in repository: Repository) async throws {
        try await withRepositoryAccess(repository) { resolvedRepository in
            try await gitClient.createBranch(resolvedRepository, name: name)
            return ()
        }
    }

    func deleteBranch(_ name: String, in repository: Repository) async throws {
        try await withRepositoryAccess(repository) { resolvedRepository in
            try await gitClient.deleteBranch(resolvedRepository, name: name)
            return ()
        }
    }

    func updateAutoFetchEnabled(_ isEnabled: Bool) {
        autoFetchEnabled = isEnabled
        persistAutoFetchSettings()
        configureAutoFetch()
    }

    func updateAutoFetchInterval(_ minutes: Int) {
        guard !isUpdatingInterval else { return }
        let clamped = max(5, min(120, minutes))
        isUpdatingInterval = true
        autoFetchIntervalMinutes = clamped
        isUpdatingInterval = false
        persistAutoFetchSettings()
        configureAutoFetch()
    }

    func updateBackgroundFetchPolicy(_ policy: BackgroundFetchPolicy) {
        backgroundFetchPolicy = policy
        normalizeFetchPolicy()
        persistAutoFetchSettings()
        configureAutoFetch()
    }

    private func refreshIfNeeded(for repository: Repository) async {
        let now = Date()
        if let lastRefresh = lastRefreshByRepository[repository.id], now.timeIntervalSince(lastRefresh) < 1.0 {
            return
        }
        lastRefreshByRepository[repository.id] = now
        await refreshStatus(for: repository)
    }

    private func resolveRepository(_ repository: Repository) async throws -> Repository {
        guard let bookmark = repositoryBookmarks[repository.id] else { return repository }
        let (url, refreshed) = try await repositoryAccess.withAccess(from: bookmark) { url async throws in
            return url
        }
        if let refreshed {
            repositoryBookmarks[repository.id] = refreshed
            persistBookmarks()
        }
        var updated = repository
        updated.path = url.path
        updated.isValid = isGitRepository(at: url)

        guard updated.isValid else {
            throw GitClientError.commandFailed("The selected folder is not a git repository.")
        }

        return updated
    }

    private func withRepositoryAccess<T>(
        _ repository: Repository,
        operation: (Repository) async throws -> T
    ) async throws -> T {
        guard let bookmark = repositoryBookmarks[repository.id] else {
            return try await operation(repository)
        }

        var latestPath = repository.path
        var latestValid = repository.isValid
        let (value, refreshed) = try await repositoryAccess.withAccess(from: bookmark) { url async throws in
            var updated = repository
            updated.path = url.path
            updated.isValid = isGitRepository(at: url)
            latestPath = updated.path
            latestValid = updated.isValid

            guard updated.isValid else {
                throw GitClientError.commandFailed("The selected folder is not a git repository.")
            }

            return try await operation(updated)
        }

        if let refreshed {
            repositoryBookmarks[repository.id] = refreshed
            persistBookmarks()
        }

        if let index = repositories.firstIndex(where: { $0.id == repository.id }) {
            repositories[index].path = latestPath
            repositories[index].isValid = latestValid
        }

        return value
    }

    private func configureAutoFetch() {
        stopAutoFetch()

        guard autoFetchEnabled else { return }

        let interval = max(5, autoFetchIntervalMinutes)
        let policy = effectiveFetchPolicy

        #if os(macOS)
        if policy == .systemScheduled {
            let scheduler = NSBackgroundActivityScheduler(identifier: "com.sfxx.source.autofetch")
            scheduler.repeats = true
            scheduler.interval = TimeInterval(interval * 60)
            scheduler.tolerance = TimeInterval(interval * 60) * 0.2
            scheduler.schedule { [weak self] completion in
                Task {
                    await self?.runAutoFetchOnce()
                    completion(.finished)
                }
            }
            backgroundScheduler = scheduler
            return
        }
        #endif

        autoFetchTask = Task { [weak self] in
            guard let self else { return }
            await self.runAutoFetchLoop(intervalMinutes: interval)
        }
    }

    private func stopAutoFetch() {
        autoFetchTask?.cancel()
        autoFetchTask = nil
        #if os(macOS)
        backgroundScheduler?.invalidate()
        backgroundScheduler = nil
        #endif
    }

    private var effectiveFetchPolicy: BackgroundFetchPolicy {
        #if os(macOS)
        return backgroundFetchPolicy
        #else
        return .appActiveOnly
        #endif
    }

    private func normalizeFetchPolicy() {
        if !BackgroundFetchPolicy.supportedPolicies.contains(backgroundFetchPolicy) {
            #if os(macOS)
            backgroundFetchPolicy = .systemScheduled
            #else
            backgroundFetchPolicy = .appActiveOnly
            #endif
        }
    }

    private func runAutoFetchLoop(intervalMinutes: Int) async {
        await runAutoFetchOnce()
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(Double(intervalMinutes) * 60))
            } catch {
                break
            }
            await runAutoFetchOnce()
        }
    }

    private func runAutoFetchOnce() async {
        guard !autoFetchInFlight else { return }
        autoFetchInFlight = true
        defer { autoFetchInFlight = false }

        let repos = repositories
        for repo in repos where repo.isValid {
            await perform(.fetch, on: repo)
            await refreshStatus(for: repo)
        }
    }

    private func persistAutoFetchSettings() {
        let defaults = UserDefaults.standard
        defaults.set(autoFetchEnabled, forKey: DefaultsKey.autoFetchEnabled)
        defaults.set(autoFetchIntervalMinutes, forKey: DefaultsKey.autoFetchIntervalMinutes)
        defaults.set(backgroundFetchPolicy.rawValue, forKey: DefaultsKey.backgroundFetchPolicy)
    }

    private func validateRepositories() async {
        for index in repositories.indices {
            let repo = repositories[index]
            guard let bookmark = repositoryBookmarks[repo.id] else { continue }
            do {
                let resolution = try repositoryAccess.resolve(from: bookmark)
                let url = resolution.url
                if let refreshed = resolution.refreshedBookmark {
                    repositoryBookmarks[repo.id] = refreshed
                }
                repositories[index].path = url.path
                repositories[index].isValid = isGitRepository(at: url)
            } catch {
                repositories[index].isValid = false
                appendActivity(
                    ActivityItem(
                        id: UUID(),
                        repositoryID: repo.id,
                        title: "Repository validation failed",
                        detail: error.localizedDescription,
                        timestamp: Date(),
                        kind: .warning
                    )
                )
            }
        }

        persistBookmarks()
    }

    private func isGitRepository(at url: URL) -> Bool {
        let gitURL = url.appendingPathComponent(".git")
        return FileManager.default.fileExists(atPath: gitURL.path)
    }

    private func persistBookmarks() {
        do {
            let records = repositories.compactMap { repo -> RepositoryRecord? in
                guard let bookmark = repositoryBookmarks[repo.id] else { return nil }
                return RepositoryRecord(id: repo.id, name: repo.name, remote: repo.remote, bookmarkData: bookmark)
            }
            try repositoryStore.save(records)
        } catch {
            appendActivity(
                ActivityItem(
                    id: UUID(),
                    repositoryID: nil,
                    title: "Failed to persist repositories",
                    detail: error.localizedDescription,
                    timestamp: Date(),
                    kind: .error
                )
            )
        }
    }

    private func appendActivity(_ item: ActivityItem) {
        activity.insert(item, at: 0)
    }
}

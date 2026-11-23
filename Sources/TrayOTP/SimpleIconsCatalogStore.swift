import Foundation
import OTPCore

/// Public catalog metadata. User token data never leaves the matching code on the Mac.
actor SimpleIconsCatalogStore {
    static let shared = SimpleIconsCatalogStore()

    private static let maxBytes = 1024 * 1024
    private let file: URL
    private var catalog: SimpleIconsCatalog?
    private var loading: Task<SimpleIconsCatalog?, Never>?

    init(directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.outerstudio.trayotp", isDirectory: true)) {
        file = directory.appendingPathComponent("simple-icons-\(SimpleIconsCatalog.version).json")
    }

    func load() async -> SimpleIconsCatalog? {
        if let catalog { return catalog }
        if let loading { return await loading.value }
        let task = Task { await loadCatalog() }
        loading = task
        let result = await task.value
        catalog = result
        loading = nil
        return result
    }

    private func loadCatalog() async -> SimpleIconsCatalog? {
        if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= Self.maxBytes,
           let data = try? Data(contentsOf: file), let catalog = try? SimpleIconsCatalog(data: data) {
            return catalog
        }

        let url = SimpleIconsCatalog.catalogURL
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 12
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        guard let (bytes, response) = try? await session.bytes(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url == url, http.mimeType == "application/json", http.expectedContentLength <= Self.maxBytes
        else { return nil }

        var data = Data()
        do {
            for try await byte in bytes {
                guard data.count < Self.maxBytes else { return nil }
                data.append(byte)
            }
            let catalog = try SimpleIconsCatalog(data: data)
            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: file, options: .atomic)
            return catalog
        } catch { return nil }
    }
}

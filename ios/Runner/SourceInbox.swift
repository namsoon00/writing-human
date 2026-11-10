import Foundation

struct SourceDelivery: Codable {
  let id: String
  let text: String
}

/// The extension and host coordinate the same private file. Confirmation in
/// Flutter is acknowledged only after the actual library save succeeds.
struct SourceInbox {
  static let group = "group.com.writinghuman.writingHuman"
  static let textLimit = 50_000
  private let file: URL

  enum InboxError: Error {
    case unavailable, invalidText, full, coordination
  }

  init(file: URL? = nil) throws {
    if let file = file {
      self.file = file
    } else if let directory = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: Self.group
    ) {
      self.file = directory.appendingPathComponent("source-inbox.json")
    } else {
      throw InboxError.unavailable
    }
  }

  private func read(_ url: URL) throws -> [SourceDelivery] {
    do {
      return try JSONDecoder().decode([SourceDelivery].self, from: Data(contentsOf: url))
    } catch CocoaError.fileReadNoSuchFile {
      return []
    }
  }

  func pending() throws -> [SourceDelivery] {
    if !FileManager.default.fileExists(atPath: file.path) { return [] }
    var error: NSError?
    var result: Result<[SourceDelivery], Error>?
    NSFileCoordinator().coordinate(readingItemAt: file, options: [], error: &error) { url in
      result = Result { try read(url) }
    }
    if let error = error { throw error }
    guard let result = result else { throw InboxError.coordination }
    return try result.get()
  }

  private func update(_ edit: ([SourceDelivery]) throws -> [SourceDelivery]) throws {
    var error: NSError?
    var result: Result<Void, Error>?
    NSFileCoordinator().coordinate(writingItemAt: file, options: .forMerging, error: &error) { url in
      result = Result {
        let items = try edit(read(url))
        try JSONEncoder().encode(items).write(to: url, options: .atomic)
      }
    }
    if let error = error { throw error }
    guard let result = result else { throw InboxError.coordination }
    try result.get()
  }

  func append(_ raw: String) throws {
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty && text.utf16.count <= Self.textLimit else {
      throw InboxError.invalidText
    }
    try update { items in
      guard items.count < 20 else { throw InboxError.full }
      return items + [SourceDelivery(id: UUID().uuidString, text: text)]
    }
  }

  func acknowledge(_ id: String) throws {
    try update { $0.filter { $0.id != id } }
  }
}

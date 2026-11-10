import Foundation

// Run on macOS: swiftc ios/Runner/SourceInbox.swift tool/check_source_inbox.swift -o /tmp/source-inbox-check
@main
struct CheckSourceInbox {
  static func main() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("source-inbox.json")
    let inbox = try SourceInbox(file: file)
    let initially = try inbox.pending()
    precondition(initially.isEmpty)
    try inbox.append(" 첫 문단 \n")
    try inbox.append("둘째 문단")
    let restored = try SourceInbox(file: file).pending()
    precondition(restored.map(\.text) == ["첫 문단", "둘째 문단"])
    precondition(restored[0].id != restored[1].id)
    try inbox.acknowledge(restored[0].id)
    let remaining = try SourceInbox(file: file).pending()
    precondition(remaining.map(\.id) == [restored[1].id])
    do {
      try inbox.append(String(repeating: "한", count: SourceInbox.textLimit + 1))
      fatalError("Oversize delivery was accepted")
    } catch SourceInbox.InboxError.invalidText {}
    let malformed = Data("not-json".utf8)
    try malformed.write(to: file)
    do {
      try inbox.append("원문")
      fatalError("Unreadable inbox was overwritten")
    } catch is DecodingError {}
    let retained = try Data(contentsOf: file)
    precondition(retained == malformed)
    print("Source inbox: file reopen, per-delivery acknowledgement and corruption protection passed")
  }
}

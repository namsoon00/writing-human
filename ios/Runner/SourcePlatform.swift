import Flutter
import ImageIO
import UIKit
import Vision

final class SourcePlatform: NSObject, FlutterPlugin {
  private static let inboxQueue = DispatchQueue(label: "writing_human.source.inbox")
  private static let photoQueue = DispatchQueue(label: "writing_human.source.photo", qos: .userInitiated)

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "writing_human/source", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SourcePlatform(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let finish: (Any?) -> Void = { value in DispatchQueue.main.async { result(value) } }
    switch call.method {
    case "pendingShares", "acknowledgeShare":
      Self.inboxQueue.async {
        do {
          let inbox = try SourceInbox()
          if call.method == "pendingShares" {
            finish(try inbox.pending().map { ["id": $0.id, "text": $0.text] })
          } else if let id = call.arguments as? String {
            try inbox.acknowledge(id)
            finish(nil)
          } else {
            finish(FlutterError(code: "inbox", message: "Missing delivery ID", details: nil))
          }
        } catch SourceInbox.InboxError.unavailable {
          // Unsigned local builds can use the editor without an App Group.
          if call.method == "pendingShares" { finish([]) }
          else { finish(FlutterError(code: "inbox", message: "App Group unavailable", details: nil)) }
        } catch {
          finish(FlutterError(code: "inbox", message: "Could not open the source inbox", details: nil))
        }
      }
    case "scan":
      guard #available(iOS 16.0, *), let bytes = call.arguments as? FlutterStandardTypedData else {
        finish(FlutterError(code: "unsupported", message: "Korean recognition requires iOS 16", details: nil))
        return
      }
      Self.photoQueue.async {
        do { finish(try Self.recognize(bytes.data)) }
        catch {
          finish(FlutterError(code: "recognition", message: "Could not read the photo", details: nil))
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 16.0, *)
  private static func recognize(_ bytes: Data) throws -> [[[String: Any]]] {
    guard let source = CGImageSourceCreateWithData(bytes as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw SourceInbox.InboxError.invalidText
    }
    let request = VNRecognizeTextRequest()
    request.revision = VNRecognizeTextRequestRevision3
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["ko-KR", "en-US"]
    request.usesLanguageCorrection = true
    try VNImageRequestHandler(cgImage: image).perform([request])
    func box(_ rect: CGRect) -> [Double] {
      [Double(rect.minX), Double(1 - rect.maxY), Double(rect.maxX), Double(1 - rect.minY)]
    }
    var paragraphs: [[[String: Any]]] = []
    var lines: [[String: Any]] = []
    var previous: CGRect?
    for observation in request.results ?? [] {
      guard let candidate = observation.topCandidates(1).first, !candidate.string.isEmpty else { continue }
      let bounds = observation.boundingBox
      if let last = previous {
        let gap = last.minY - bounds.maxY
        let movedUp = bounds.midY > last.midY + last.height * 0.5
        let separateColumn = bounds.minX > last.maxX || bounds.maxX < last.minX
        if gap > max(bounds.height, last.height) * 0.9 || movedUp || separateColumn {
          if !lines.isEmpty { paragraphs.append(lines) }
          lines.removeAll(keepingCapacity: true)
        }
      }
      var words: [[String: Any]] = []
      candidate.string.enumerateSubstrings(in: candidate.string.startIndex..<candidate.string.endIndex,
                                           options: .byWords) { text, range, _, _ in
        guard let text, let rect = try? candidate.boundingBox(for: range) else { return }
        words.append(["text": text, "bounds": box(rect.boundingBox)])
      }
      lines.append([
        "text": candidate.string, "bounds": box(bounds),
        "confidence": Double(candidate.confidence), "words": words,
      ])
      previous = bounds
    }
    if !lines.isEmpty { paragraphs.append(lines) }
    return paragraphs
  }
}

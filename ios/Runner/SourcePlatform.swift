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
    case "recognize":
      guard #available(iOS 16.0, *), let path = call.arguments as? String else {
        finish(FlutterError(code: "unsupported", message: "Korean recognition requires iOS 16", details: nil))
        return
      }
      Self.photoQueue.async {
        do { finish(try Self.recognize(path)) }
        catch {
          finish(FlutterError(code: "recognition", message: "Could not read the photo", details: nil))
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 16.0, *)
  private static func recognize(_ path: String) throws -> [String] {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2400,
          ] as CFDictionary) else { throw SourceInbox.InboxError.invalidText }
    let request = VNRecognizeTextRequest()
    request.revision = VNRecognizeTextRequestRevision3
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["ko-KR", "en-US"]
    request.usesLanguageCorrection = true
    try VNImageRequestHandler(cgImage: image).perform([request])
    var paragraphs: [String] = []
    var lines: [String] = []
    var previous: CGRect?
    for observation in request.results ?? [] {
      guard let line = observation.topCandidates(1).first?.string, !line.isEmpty else { continue }
      let bounds = observation.boundingBox
      if let last = previous {
        let gap = last.minY - bounds.maxY
        let movedUp = bounds.midY > last.midY + last.height * 0.5
        let separateColumn = bounds.minX > last.maxX || bounds.maxX < last.minX
        if gap > max(bounds.height, last.height) * 0.9 || movedUp || separateColumn {
          if !lines.isEmpty { paragraphs.append(lines.joined(separator: "\n")) }
          lines.removeAll(keepingCapacity: true)
        }
      }
      lines.append(line)
      previous = bounds
    }
    if !lines.isEmpty { paragraphs.append(lines.joined(separator: "\n")) }
    return paragraphs
  }
}

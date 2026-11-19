import Social
import UIKit

final class ShareViewController: SLComposeServiceViewController {
  private var saving = false
  private var loadingPhoto = false
  private var photo: Data?

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "원문 보관"
    placeholder = "옮겨 쓸 구절"
    navigationItem.rightBarButtonItem?.title = "보관"
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
    if let image = providers.first(where: { $0.hasItemConformingToTypeIdentifier("public.image") }) {
      loadingPhoto = true
      image.loadFileRepresentation(forTypeIdentifier: "public.image") { [weak self] url, _ in
        let data: Data? = url.flatMap { file in
          guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                size > 0 && size <= SourceInbox.photoLimit else { return nil }
          return try? Data(contentsOf: file)
        }
        DispatchQueue.main.async {
          guard let self = self else { return }
          self.loadingPhoto = false
          self.photo = data
          if data == nil { self.showError("20MB보다 작은 사진을 골라 주세요.") }
          self.validateContent()
        }
      }
    }
    guard (contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    let type = providers.contains { $0.hasItemConformingToTypeIdentifier("public.plain-text") }
      ? "public.plain-text" : "public.url"
    guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type) }) else { return }
    provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, _ in
      let text = (item as? URL)?.absoluteString ?? item as? String
        ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
      DispatchQueue.main.async {
        guard let self = self, let text = text,
              (self.contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        self.textView.text = text
        self.validateContent()
      }
    }
  }

  override func isContentValid() -> Bool {
    let text = (contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return !saving && !loadingPhoto && (!text.isEmpty || photo != nil)
      && text.utf16.count <= SourceInbox.textLimit
  }

  override func didSelectPost() {
    guard isContentValid() else { return }
    saving = true
    validateContent()
    let text = contentText ?? ""
    let image = photo
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      do {
        try SourceInbox().append(text, photo: image)
        DispatchQueue.main.async { self?.extensionContext?.completeRequest(returningItems: nil) }
      } catch {
        DispatchQueue.main.async {
          guard let self = self else { return }
          self.saving = false
          self.validateContent()
          self.showError("쓰는 인간에서 받아둔 원문을 확인하고 다시 시도해 주세요.")
        }
      }
    }
  }

  private func showError(_ message: String) {
    let alert = UIAlertController(
      title: "원문을 보관하지 못했어요",
      message: message,
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "확인", style: .default))
    present(alert, animated: true)
  }

  override func configurationItems() -> [Any]! { [] }
}

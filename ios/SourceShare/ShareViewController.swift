import Social
import UIKit

final class ShareViewController: SLComposeServiceViewController {
  private var saving = false

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "원문 보관"
    placeholder = "옮겨 쓸 구절"
    navigationItem.rightBarButtonItem?.title = "보관"
    guard (contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
      .flatMap { $0.attachments ?? [] }
    guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier("public.plain-text") }) else { return }
    provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] item, _ in
      let text = item as? String ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
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
    return !saving && !text.isEmpty && text.utf16.count <= SourceInbox.textLimit
  }

  override func didSelectPost() {
    guard isContentValid() else { return }
    saving = true
    validateContent()
    let text = contentText ?? ""
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      do {
        try SourceInbox().append(text)
        DispatchQueue.main.async { self?.extensionContext?.completeRequest(returningItems: nil) }
      } catch {
        DispatchQueue.main.async {
          guard let self = self else { return }
          self.saving = false
          self.validateContent()
          let alert = UIAlertController(
            title: "원문을 보관하지 못했어요",
            message: "쓰는 인간에서 받아둔 글을 확인하거나, 문장을 복사해 붙여넣어 주세요.",
            preferredStyle: .alert
          )
          alert.addAction(UIAlertAction(title: "확인", style: .default))
          self.present(alert, animated: true)
        }
      }
    }
  }

  override func configurationItems() -> [Any]! { [] }
}

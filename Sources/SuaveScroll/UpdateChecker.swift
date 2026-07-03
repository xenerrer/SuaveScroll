import AppKit
import Foundation

/// Consulta a API de releases do GitHub periodicamente e informa quando existe
/// uma versão mais nova. Não instala nada sozinho: como o app não é notarizado,
/// o caminho seguro é levar o usuário à página de download.
final class UpdateChecker {
    static let shared = UpdateChecker()

    private static let apiURL = URL(string: "https://api.github.com/repos/xenerrer/SuaveScroll/releases/latest")!
    static let downloadPageURL = URL(string: "https://github.com/xenerrer/SuaveScroll/releases/latest")!

    /// Última versão publicada (ex.: "0.1.1"). Lida e escrita na main thread.
    private(set) var latestVersion: String?

    var updateAvailable: Bool {
        guard let latest = latestVersion,
              let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        else { return false }
        return latest.compare(current, options: .numeric) == .orderedDescending
    }

    func startPeriodicChecks() {
        check()
        Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    private func check() {
        var request = URLRequest(url: Self.apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String
            else { return }
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            DispatchQueue.main.async {
                self?.latestVersion = version
                if self?.updateAvailable == true {
                    DiagLog.write("atualização disponível: \(version)")
                }
            }
        }.resume()
    }
}

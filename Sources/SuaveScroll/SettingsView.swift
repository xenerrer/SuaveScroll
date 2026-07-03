import AppKit
import SwiftUI
import UniformTypeIdentifiers

final class SettingsModel: ObservableObject {
    @Published var stepSize: Double {
        didSet { Settings.shared.stepSize = stepSize }
    }
    @Published var durationMs: Double {
        didSet { Settings.shared.durationMs = durationMs }
    }
    @Published var reverseDirection: Bool {
        didSet { Settings.shared.reverseDirection = reverseDirection }
    }
    @Published var excluded: [String] {
        didSet { Settings.shared.excludedBundleIds = excluded }
    }

    init() {
        stepSize = Settings.shared.stepSize
        durationMs = Settings.shared.durationMs
        reverseDirection = Settings.shared.reverseDirection
        excluded = Settings.shared.excludedBundleIds
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel

    var body: some View {
        Form {
            Section("Rolagem") {
                VStack(alignment: .leading) {
                    Text("Distância por clique da rodinha: \(Int(model.stepSize)) px")
                    Slider(value: $model.stepSize, in: 20...200, step: 5)
                }
                VStack(alignment: .leading) {
                    Text("Duração do deslize: \(Int(model.durationMs)) ms")
                    Slider(value: $model.durationMs, in: 80...600, step: 20)
                }
                Toggle("Inverter direção da rolagem", isOn: $model.reverseDirection)
            }

            Section("Aplicativos excluídos") {
                if model.excluded.isEmpty {
                    Text("A rolagem é suavizada em todos os aplicativos.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.excluded, id: \.self) { bundleId in
                    HStack {
                        Text(bundleId)
                        Spacer()
                        Button {
                            model.excluded.removeAll { $0 == bundleId }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button("Adicionar Aplicativo…") { addApplication() }
            }

            Section {
                Text("Gestos do trackpad e do Magic Mouse nunca são afetados. A rodinha do mouse é suavizada mesmo com drivers como o Logi Options+ instalados.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 460)
    }

    private func addApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let bundleId = Bundle(url: url)?.bundleIdentifier,
               !model.excluded.contains(bundleId) {
                model.excluded.append(bundleId)
            }
        }
    }
}

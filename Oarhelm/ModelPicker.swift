import SwiftUI

struct CapyModelPicker: View {
    @Environment(AppRouter.self) private var router
    @Binding var selection: String
    var allowsDefault = true
    @State private var presented = false
    @State private var search = ""
    @State private var openDocs = false

    private var filtered: [CapyModel] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return CapyModelCatalog.models }
        return CapyModelCatalog.models.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.id.localizedCaseInsensitiveContains(query) || $0.provider.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Button { presented = true } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 7) {
                    ProviderMark(provider: CapyModelCatalog.provider(for: selection)).accessibilityHidden(true)
                    Text(selection.isEmpty && !allowsDefault ? "Choose model" : CapyModelCatalog.displayName(for: selection)).fixedSize(horizontal: true, vertical: false)
                    chevron
                }
                HStack(spacing: 7) { ProviderMark(provider: CapyModelCatalog.provider(for: selection)).accessibilityHidden(true); chevron }
            }.font(VikingTheme.font(12, weight: .medium)).padding(.horizontal, 8).padding(.vertical, 6)
        }.vikingSecondary(compact: true)
            .accessibilityLabel("Model: \(CapyModelCatalog.displayName(for: selection))")
            .sheet(isPresented: $presented, onDismiss: {
                if openDocs { openDocs = false; router.browse(URL(string: "https://docs.capy.ai/models-and-pricing")!) }
            }) {
                NavigationStack {
                    List {
                        if !selection.isEmpty {
                            Section("Selected") {
                                HStack(spacing: 12) {
                                    ProviderMark(provider: CapyModelCatalog.provider(for: selection), size: 22).accessibilityHidden(true)
                                    Text(CapyModelCatalog.displayName(for: selection)).foregroundStyle(VikingTheme.ink).fixedSize(horizontal: false, vertical: true)
                                }.padding(.vertical, 6)
                            }.textCase(nil)
                        }
                        if allowsDefault && (search.isEmpty || "Default".localizedCaseInsensitiveContains(search)) {
                            Button { choose("") } label: { row("Default", selected: selection.isEmpty) }
                        }
                        ForEach(Array(Set(filtered.map(\.provider))).sorted(), id: \.self) { provider in
                            Section(CapyModelCatalog.providerName(provider)) {
                                ForEach(filtered.filter { $0.provider == provider }) { model in
                                    Button { choose(model.id) } label: { row(model.name, provider: model.provider, selected: selection == model.id) }
                                }
                            }.textCase(nil)
                        }
                        if filtered.isEmpty && !CapyModelCatalog.models.isEmpty { Text("No matching models").foregroundStyle(VikingTheme.secondary) }
                        if CapyModelCatalog.models.isEmpty { Text("Model catalog unavailable.").foregroundStyle(VikingTheme.secondary) }
                        Section {
                            Button("Model guide", systemImage: "book") { openDocs = true; presented = false }
                        } footer: {
                            if let date = CapyModelCatalog.fetchedAt { Text("Updated \(date)") }
                        }
                    }
                    .searchable(text: $search, prompt: "Search models")
                    .font(VikingTheme.font(14))
                    .vikingList()
                    .navigationTitle("Model")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { presented = false } } }
                }.tint(VikingTheme.accent).preferredColorScheme(.dark)
            }
    }

    private func choose(_ id: String) { selection = id; presented = false; search = "" }
    private var chevron: some View { Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold)) }
    private func row(_ title: String, provider: String = "capy", selected: Bool) -> some View {
        HStack(spacing: 12) { ProviderMark(provider: provider).accessibilityHidden(true); Text(title).foregroundStyle(VikingTheme.ink).fixedSize(horizontal: false, vertical: true); Spacer(); if selected { Image(systemName: "checkmark").foregroundStyle(VikingTheme.accent) } }
            .contentShape(Rectangle())
    }
}

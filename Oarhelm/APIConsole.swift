import SwiftUI

struct APIConsoleView: View {
    @State private var search = ""
    var body: some View {
        List {
            Section { Text("All public API actions.").foregroundStyle(.secondary) }
            ForEach(Array(Set(Catalog.operations.map(\.group))).sorted(), id: \.self) { group in
                let items = Catalog.operations.filter { $0.group == group && (search.isEmpty || "\($0.title) \($0.id)".localizedCaseInsensitiveContains(search)) }
                if !items.isEmpty { Section(group.capitalized) { ForEach(items) { op in NavigationLink(op.title, value: AppRoute.operation(op.id, [:])) } } }
            }
        }.vikingList().navigationTitle("Advanced controls").searchable(text: $search)
            .font(.custom("PaperMono-Regular", size: 14))
    }
}

private struct SchemaField: View {
    let name: String
    let schema: JSONValue
    @Binding var value: JSONValue
    @State private var variant = 0
    @State private var newMapKey = ""
    @State private var expanded = true
    private var s: JSONValue { Catalog.resolve(schema) }
    var body: some View { AnyView(content) }
    @ViewBuilder private var content: some View {
        if let variants = (s["anyOf"] ?? s["oneOf"])?.arrayValue, !variants.isEmpty {
            VStack(alignment: .leading) {
                Picker(name + " type", selection: $variant) {
                    ForEach(variants.indices, id: \.self) { i in
                        Text(variantName(variants[i], index: i)).tag(i)
                    }
                }.onChange(of: variant) { _, i in value = Catalog.initial(variants[i]) }
                SchemaField(name: name, schema: variants[min(variant,variants.count-1)], value: $value)
            }
        } else if let choices = s["enum"]?.arrayValue {
            Picker(name, selection: $value) { ForEach(choices, id: \.self) { item in Text(item.stringValue ?? item.prettyText).tag(item) } }
        } else if s["type"]?.stringValue == "object", case .object(let properties) = s["properties"] {
            DisclosureGroup(name, isExpanded: $expanded) {
                ForEach(properties.keys.sorted(), id: \.self) { key in
                    let required = s["required"]?.arrayValue?.contains(.string(key)) == true
                    VStack(alignment: .leading, spacing: 8) {
                        if !required {
                            Toggle("Include \(key)", isOn: Binding(get: { value[key] != nil }, set: { enabled in
                                var object = objectValue; object[key] = enabled ? Catalog.initial(properties[key]!) : nil; value = .object(object)
                            }))
                        }
                        if required || value[key] != nil {
                            SchemaField(name: key, schema: properties[key]!, value: child(key, schema: properties[key]!))
                            if let description = properties[key]?["description"]?.stringValue { DisclosureGroup("Help") { Text(description).font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary).fixedSize(horizontal: false, vertical: true) } }
                        }
                    }
                }
            }
        } else if s["type"]?.stringValue == "object" {
            DisclosureGroup(name, isExpanded: $expanded) {
                ForEach(objectValue.keys.sorted(), id: \.self) { key in
                    SchemaField(name: key, schema: s["additionalProperties"] ?? .object(["type": .string("string")]), value: child(key, schema: s["additionalProperties"] ?? .null))
                    Button("Remove \(key)", role: .destructive) { var o = objectValue; o.removeValue(forKey: key); value = .object(o) }
                }
                TextField("New key", text: $newMapKey).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Add field") { var o = objectValue; o[newMapKey] = Catalog.initial(s["additionalProperties"] ?? .null); value = .object(o); newMapKey = "" }.disabled(newMapKey.isEmpty || objectValue[newMapKey] != nil)
            }
        } else if s["type"]?.stringValue == "array" {
            DisclosureGroup(name, isExpanded: $expanded) {
                let items = value.arrayValue ?? []
                ForEach(items.indices, id: \.self) { index in
                    SchemaField(name: "Item \(index + 1)", schema: s["items"] ?? .null, value: Binding(get: { (value.arrayValue ?? []).indices.contains(index) ? value.arrayValue![index] : .null }, set: { v in var a = value.arrayValue ?? []; if a.indices.contains(index) { a[index] = v; value = .array(a) } }))
                    Button("Remove item \(index + 1)", role: .destructive) { var a = value.arrayValue ?? []; if a.indices.contains(index) { a.remove(at:index); value = .array(a) } }
                }
                Button("Add item") { value = .array((value.arrayValue ?? []) + [Catalog.initial(s["items"] ?? .null)]) }
            }
        } else if name == "modelId" {
            CapyModelPicker(selection: Binding(get: { value.stringValue ?? "" }, set: { value = .string($0) }), allowsDefault: false)
        } else if s["type"]?.stringValue == "boolean" {
            Toggle(name, isOn: Binding(get: { value == .bool(true) }, set: { value = .bool($0) }))
        } else if ["integer", "number"].contains(s["type"]?.stringValue ?? "") {
            TextField(name, value: Binding(get: { if case .number(let n) = value { return n }; return 0 }, set: { value = .number($0) }), format: .number).keyboardType(.numbersAndPunctuation)
        } else if s["type"]?.stringValue == "null" { Text("\(name): clear value").foregroundStyle(.secondary) }
        else {
            TextField(name, text: Binding(get: { value.stringValue ?? "" }, set: { value = .string($0) }), axis: .vertical).textInputAutocapitalization(.never).autocorrectionDisabled()
        }
    }
    private var objectValue: [String:JSONValue] { if case .object(let o) = value { return o }; return [:] }
    private func child(_ key: String, schema: JSONValue) -> Binding<JSONValue> { Binding(get: { value[key] ?? Catalog.initial(schema) }, set: { v in var o = objectValue; o[key] = v; value = .object(o) }) }
    private func variantName(_ schema: JSONValue, index: Int) -> String {
        let resolved = Catalog.resolve(schema)
        return resolved["title"]?.stringValue ?? resolved["properties"]?["_tag"]?["enum"]?.arrayValue?.first?.stringValue ?? resolved["properties"]?["type"]?["enum"]?.arrayValue?.first?.stringValue ?? resolved["properties"]?["kind"]?["enum"]?.arrayValue?.first?.stringValue ?? resolved["type"]?.stringValue.map { $0.capitalized + " \(index + 1)" } ?? "Option \(index + 1)"
    }
}

struct JSONTree: View {
    let name: String
    let value: JSONValue
    var body: some View {
        AnyView(Group {
            switch value {
            case .object(let object):
                DisclosureGroup(name) { ForEach(object.keys.sorted(), id: \.self) { key in JSONTree(name: key, value: object[key]!) } }
            case .array(let array):
                DisclosureGroup("\(name) (\(array.count))") { ForEach(array.indices, id: \.self) { i in JSONTree(name: "\(i + 1)", value: array[i]) } }
            default: VStack(alignment: .leading, spacing: 5) { Text(name).foregroundStyle(.secondary); Text(value.stringValue ?? value.prettyText).textSelection(.enabled) }.padding(.vertical, 4)
            }
        })
    }
}

struct OperationView: View {
    @Environment(CapyStore.self) private var store
    let operationID: String
    var defaults: [String:String] = [:]
    @Environment(AppRouter.self) private var router
    @State private var form = OperationDraft()
    private var parameters: [String:String] { get { form.parameters } nonmutating set { form.parameters = newValue } }
    private var requestBody: JSONValue { get { form.requestBody } nonmutating set { form.requestBody = newValue } }
    private var advanced: Bool { get { form.advanced } nonmutating set { form.advanced = newValue } }
    private var bodyText: String { get { form.bodyText } nonmutating set { form.bodyText = newValue } }
    private var formKey: String { operationID + JSONValue.object(defaults.mapValues(JSONValue.string)).prettyText }
    @State private var response: JSONValue?
    @State private var error = ""
    @State private var confirm = false
    @State private var task: Task<Void,Never>?
    @State private var executionID: UUID?
    private var operation: ConsoleOperation? { Catalog.operations.first { $0.id == operationID } }
    var body: some View {
        Group {
            if let op = operation {
                VikingScreen {
                    if !store.isConnected { VikingFormSection { Text("Connect to Capy to continue.").foregroundStyle(.secondary) } }
                    if let params = op.spec["parameters"]?.arrayValue, !params.isEmpty {
                        VikingFormSection("Details") {
                            ForEach(Array(params.enumerated()), id: \.offset) { _, p in
                                if let name = p["name"]?.stringValue {
                                    TextField(name + (p["required"] == .bool(true) ? " (required)" : ""), text: Binding(get: { parameters[name] ?? "" }, set: { parameters[name] = $0 })).textInputAutocapitalization(.never).autocorrectionDisabled()
                                }
                            }
                        }
                    }
                    if let schema = op.spec["requestBody"]?["content"]?["application/json"]?["schema"] {
                        VikingFormSection("Details") {
                            Toggle("Edit JSON", isOn: Binding(get: { advanced }, set: { advanced = $0 })).onChange(of: advanced) { _, yes in if yes { bodyText = requestBody.prettyText } else if let parsed = try? JSONDecoder().decode(JSONValue.self, from: Data(bodyText.utf8)) { requestBody = parsed } }
                            if advanced { TextEditor(text: Binding(get: { bodyText }, set: { bodyText = $0 })).frame(minHeight: 200) }
                            else { SchemaField(name: op.title, schema: schema, value: Binding(get: { requestBody }, set: { requestBody = $0 })) }
                        }
                    }
                    VikingFormSection {
                        Button(op.isStream ? "Watch events" : op.title) { if op.needsConfirmation { confirm = true } else { execute(op) } }.vikingPrimary().disabled(!store.isConnected || task != nil)
                        if task != nil { Button("Stop") { task?.cancel() }.vikingSecondary() }
                    }
                    if !error.isEmpty { VikingFormSection("Couldn’t complete action") { Text(error).textSelection(.enabled) } }
                    if let response {
                        VikingFormSection("Result") {
                            ShareLink("Share result", item: response.prettyText)
                            JSONTree(name: "Details", value: response)
                            DisclosureGroup("JSON") { Text(response.prettyText).font(.custom("PaperMono-Regular", size: 12)).textSelection(.enabled) }
                            if let cursor = (response["cursor"] ?? response["nextCursor"])?.stringValue {
                                Button("Load next page") { let params = op.spec["parameters"]?.arrayValue ?? []; let key = params.contains { $0["name"] == .string("cursor") } ? "cursor" : "after"; parameters[key] = cursor; execute(op) }.disabled(task != nil)
                            }
                            if let cursor = response["beforeCursor"]?.stringValue { Button("Load older") { parameters["before"] = cursor; execute(op) }.disabled(task != nil) }
                            if let url = response["url"]?.stringValue.flatMap(URL.init(string:)), url.scheme == "https" { Link("Open file", destination: url) }
                        }
                    }
                    if op.isStream { VikingFormSection("Events") { ForEach(Array(store.streamEvents.enumerated()), id: \.offset) { _, event in StreamEventRow(raw: event) } } }
                }.navigationTitle(op.title).navigationBarTitleDisplayMode(.inline)
                .confirmationDialog("\(op.title)?", isPresented: $confirm, titleVisibility: .visible) {
                    Button("Continue", role: op.method == "DELETE" || op.id.contains("delete") ? .destructive : nil) { execute(op) }
                } message: { Text("Updates your Capy workspace.") }
                .onAppear {
                    if let retained = router.operationDrafts[formKey] { form = retained } else { router.operationDrafts[formKey] = form }
                    guard !form.initialized else { return }; form.initialized = true; parameters = defaults
                    if let schema = op.spec["requestBody"]?["content"]?["application/json"]?["schema"] { requestBody = Catalog.initial(schema, defaults: defaults.merging(["projectId": store.selectedProjectID]) { a,_ in a }) }
                }.onDisappear { task?.cancel() }
            } else { ContentUnavailableView("Control unavailable", systemImage: "exclamationmark.triangle") }
        }.font(.custom("PaperMono-Regular", size: 14))
    }
    private func execute(_ op: ConsoleOperation) {
        guard task == nil else { return }
        let id = UUID(); executionID = id
        error = ""
        task = Task {
            defer { if executionID == id { task = nil; executionID = nil } }
            do {
                var path = op.path; var query: [String:String] = [:]
                for p in op.spec["parameters"]?.arrayValue ?? [] {
                    guard let name = p["name"]?.stringValue else { continue }
                    let value = parameters[name] ?? ""
                    if p["required"] == .bool(true), value.isEmpty { throw CapyError(message: "Enter \(name).") }
                    if p["in"] == .string("path") { var allowed = CharacterSet.urlPathAllowed; allowed.remove(charactersIn: "/?#%"); path = path.replacingOccurrences(of: "{\(name)}", with: value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "") }
                    else if !value.isEmpty { query[name] = value }
                }
                var body: JSONValue?
                if let schema = op.spec["requestBody"]?["content"]?["application/json"]?["schema"] {
                    body = advanced ? try JSONDecoder().decode(JSONValue.self, from: Data(bodyText.utf8)) : requestBody
                    try Catalog.validate(body!, schema: schema)
                    if case .object(var object) = body {
                        var logical = object; logical.removeValue(forKey: "requestId"); logical.removeValue(forKey: "clientKey")
                        let payload = JSONValue.object(logical)
                        if let old = form.lastPayload, old != payload {
                            for key in ["requestId", "clientKey"] where object[key] != nil { object[key] = .string(UUID().uuidString) }
                            body = .object(object); requestBody = body!; if advanced { bodyText = body!.prettyText }
                        }
                        form.lastPayload = payload
                    }
                }
                if op.isStream { try await store.stream(op.method, path, query: query, body: body) }
                else {
                    let result = try await store.request(op.method, path, query: query, body: body)
                    guard !Task.isCancelled, executionID == id else { return }
                    response = result
                    if case .object(var object) = body {
                        for key in ["requestId", "clientKey"] where object[key] != nil { object[key] = .string(UUID().uuidString) }
                        requestBody = .object(object); form.lastPayload = nil
                        if advanced { bodyText = requestBody.prettyText }
                    }
                }
            } catch is CancellationError {} catch { if !Task.isCancelled, executionID == id { self.error = error.localizedDescription } }
        }
    }
}

private struct StreamEventRow: View {
    let raw: String
    var body: some View {
        let frame = SSEFrame(lines: raw.components(separatedBy: "\n"))
        let value = try? JSONDecoder().decode(JSONValue.self, from: Data(frame.data.utf8))
        VStack(alignment: .leading, spacing: 8) {
            Text(frame.event.replacingOccurrences(of: "_", with: " ").capitalized).foregroundStyle(.secondary)
            if let text = value?["text"]?.stringValue { Text(text).textSelection(.enabled) }
            else if let status = value?["status"]?.stringValue { Text(status.capitalized) }
            else if let value { JSONTree(name: "Details", value: value) }
            else { Text(frame.data).textSelection(.enabled) }
        }
    }
}

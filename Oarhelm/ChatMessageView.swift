import SwiftUI

struct ChatMessageView: View {
    let message: JSONValue
    let threadID: String
    private var user: Bool { message["source"] == .string("user") }
    private var text: String { message["text"]?.stringValue ?? "" }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if message["source"] == .string("tool") {
                DisclosureGroup(message["tool"]?.stringValue ?? "Tool activity") {
                    Text(text).textSelection(.enabled).font(VikingTheme.font(12)).fixedSize(horizontal: false, vertical: true)
                }.font(VikingTheme.font(12)).foregroundStyle(VikingTheme.secondary)
            } else if !text.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    if user { Spacer(minLength: 24) }
                    VStack(alignment: .leading, spacing: 10) {
                        ChatText(text: text).padding(user ? 16 : 0)
                            .background(user ? VikingTheme.surface.opacity(0.9) : .clear, in: RoundedRectangle(cornerRadius: 22))
                        if user, let event = message["id"]?.stringValue {
                            Menu {
                                NavigationLink("Cancel if queued", value: AppRoute.operation("messages.cancel", ["threadId": threadID, "eventId": event]))
                                NavigationLink("Send now", value: AppRoute.operation("messages.sendNow", ["threadId": threadID, "eventId": event]))
                                NavigationLink("Versions", value: AppRoute.operation("messages.versions", ["threadId": threadID, "eventId": event]))
                            } label: { Label("Message actions", systemImage: "ellipsis").font(VikingTheme.font(11)) }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    if !user { Spacer(minLength: 0) }
                }
            }
            if let attachments = message["attachments"]?.arrayValue {
                ForEach(Array(attachments.enumerated()), id: \.offset) { _, attachment in
                    if let file = attachment["file"], let id = file["fileId"]?.stringValue {
                        NavigationLink(value: AppRoute.operation("attachments.download", ["threadId": threadID, "fileId": id])) {
                            Label(file["name"]?.stringValue ?? "Attachment", systemImage: "paperclip").font(VikingTheme.font(12))
                        }
                    }
                }
            }
        }
    }
}

struct ChatText: View {
    let text: String
    var body: some View {
        let blocks = text.components(separatedBy: "```")
        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks.indices, id: \.self) { index in
                if index.isMultiple(of: 2) {
                    Text((try? AttributedString(markdown: blocks[index], options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(blocks[index]))
                        .font(VikingTheme.font(14)).lineSpacing(6).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                } else {
                    let block = blocks[index]
                    let code = block.contains("\n") ? block.components(separatedBy: "\n").dropFirst().joined(separator: "\n") : block
                    ScrollView(.horizontal) { Text(code).font(VikingTheme.font(12)).textSelection(.enabled).padding(14) }
                        .background(VikingTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

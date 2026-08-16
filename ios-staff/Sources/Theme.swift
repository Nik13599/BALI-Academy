import SwiftUI

enum BALITheme {
    static let accent = Color(red: 0.90, green: 1.0, blue: 0.38)
    static let panel = Color(red: 0.085, green: 0.095, blue: 0.11)
    static let panel2 = Color(red: 0.11, green: 0.12, blue: 0.14)
}

struct BALIInfoBlock: View {
    let title: String
    let body: String
    var bodyView: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption.bold()).foregroundStyle(.secondary)
            Text(body).font(.body).lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(BALITheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 15))
    }
    var body: some View { bodyView }
}

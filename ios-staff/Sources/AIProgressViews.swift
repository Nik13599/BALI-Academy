import SwiftUI

struct MyProgressView: View {
    @EnvironmentObject var session: SessionStore
    @State private var progress: ProgressResponse?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let progress {
                    HStack {
                        ScoreBox(title: "Средний", value: "\(progress.stats.avg)%")
                        ScoreBox(title: "Лучший", value: "\(progress.stats.best)%")
                        ScoreBox(title: "Тестов", value: "\(progress.stats.totalAttempts)")
                    }
                    Text("По категориям").font(.title3.bold())
                    ForEach(progress.stats.categories.sorted(by: { $0.key < $1.key }), id: \.key) { item in
                        HStack {
                            Text(item.key)
                            Spacer()
                            Text("\(item.value)%").fontWeight(.bold)
                                .foregroundStyle(item.value < 70 ? .orange : BALITheme.accent)
                        }
                        .padding(12).background(BALITheme.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text("Последние попытки").font(.title3.bold()).padding(.top, 6)
                    ForEach(progress.attempts) { attempt in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(attempt.category).fontWeight(.semibold)
                                Text(attempt.completedAt ?? "").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(attempt.percent)%").font(.title3.bold())
                                .foregroundStyle(attempt.percent >= 90 ? BALITheme.accent : .white)
                        }
                        .padding(13).background(BALITheme.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                } else if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else {
                    HStack { Spacer(); SwiftUI.ProgressView(); Spacer() }.padding(.top, 50)
                }
            }.padding(20)
        }
        .background(Color.black)
        .navigationTitle("Мой прогресс")
        .task { await load() }
    }

    private func load() async {
        guard let token = session.token else { return }
        do { progress = try await APIClient.shared.progress(token: token) }
        catch { errorMessage = error.localizedDescription }
    }
}

struct ScoreBox: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 6) {
            Text(value).font(.title2.bold()).foregroundStyle(BALITheme.accent)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(14).background(BALITheme.panel).clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct ChatLine: Identifiable {
    let id = UUID()
    let role: String
    let text: String
}

struct AITrainerView: View {
    @EnvironmentObject var session: SessionStore
    @State private var mode = "ask"
    @State private var input = ""
    @State private var lines: [ChatLine] = [
        .init(role: "assistant", text: "Я AI-тренер BALI. Спроси про продукт, коктейль, подачу или попроси потренировать продажу. Можно писать с опечатками и на русском/английском.")
    ]
    @State private var options: [AIOption] = []
    @State private var busy = false

    private let modes = [("ask", "Спросить"), ("explain", "Объяснить"), ("sales", "Продажи"), ("quiz", "Проверить")]

    var body: some View {
        VStack(spacing: 0) {
            Picker("Режим", selection: $mode) {
                ForEach(modes, id: \.0) { pair in Text(pair.1).tag(pair.0) }
            }.pickerStyle(.segmented).padding()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(lines) { line in
                            Text(line.text)
                                .padding(12)
                                .background(line.role == "user" ? BALITheme.accent.opacity(0.18) : BALITheme.panel)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .frame(maxWidth: .infinity, alignment: line.role == "user" ? .trailing : .leading)
                                .id(line.id)
                        }
                        if !options.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Выберите правильное название:").font(.caption).foregroundStyle(.secondary)
                                ForEach(options) { option in
                                    Button(option.name) {
                                        input = option.name
                                        options = []
                                        send()
                                    }.buttonStyle(.bordered)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if busy { SwiftUI.ProgressView().padding() }
                    }.padding()
                }
                .onChange(of: lines.count) { _, _ in
                    if let last = lines.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            HStack(spacing: 10) {
                TextField("макалан / macalan / long iland…", text: $input, axis: .vertical)
                    .textFieldStyle(.plain).padding(12).background(BALITheme.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                Button { send() } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title).foregroundStyle(BALITheme.accent)
                }.disabled(busy || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding()
        }
        .background(Color.black)
        .navigationTitle("AI-тренер")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !busy, let token = session.token else { return }
        input = ""
        lines.append(.init(role: "user", text: text))
        busy = true
        Task {
            do {
                let response = try await APIClient.shared.askAI(message: text, mode: mode, token: token)
                await MainActor.run {
                    if response.type == "clarification" {
                        lines.append(.init(role: "assistant", text: response.message ?? "Нашёл несколько похожих вариантов."))
                        options = response.options ?? []
                    } else {
                        lines.append(.init(role: "assistant", text: response.text ?? "Нет ответа."))
                    }
                    busy = false
                }
            } catch {
                await MainActor.run {
                    lines.append(.init(role: "assistant", text: "Ошибка: \(error.localizedDescription)"))
                    busy = false
                }
            }
        }
    }
}

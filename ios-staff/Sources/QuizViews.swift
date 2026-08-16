import SwiftUI

struct QuizSetupView: View {
    @EnvironmentObject var session: SessionStore
    @State private var content: ContentResponse?
    @State private var count = 10
    @State private var level = 0
    @State private var category = "Все"
    private let counts = [10, 20, 30, 50, 100]

    private var pool: [TestQuestion] {
        (content?.tests ?? []).filter {
            $0.type == "single" && (level == 0 || $0.level == level) && (category == "Все" || $0.category == category)
        }
    }

    private var categories: [String] {
        ["Все"] + Array(Set((content?.tests ?? []).filter { $0.type == "single" }.map { $0.category })).sorted()
    }

    var body: some View {
        Form {
            Section("Количество вопросов") {
                Picker("Количество", selection: $count) {
                    ForEach(counts, id: \.self) { Text("\($0)").tag($0) }
                }.pickerStyle(.segmented)
            }
            Section("Категория") {
                Picker("Категория", selection: $category) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
            }
            Section("Уровень") {
                Picker("Уровень", selection: $level) {
                    Text("Смешанный").tag(0)
                    ForEach(1...5, id: \.self) { Text("Уровень \($0)").tag($0) }
                }
            }
            Section {
                NavigationLink(destination: QuizRunView(source: pool, count: min(count, pool.count), category: category, level: level)) {
                    HStack {
                        Spacer()
                        Text(pool.isEmpty ? "НЕТ ВОПРОСОВ" : "НАЧАТЬ • \(min(count, pool.count))").fontWeight(.black)
                        Spacer()
                    }
                }.disabled(pool.isEmpty)
            } footer: {
                Text("В тренировке ошибка сразу разбирается, но ответ остаётся засчитан как неправильный. Тест можно пересдавать неограниченно.")
            }
        }
        .navigationTitle("Новый тест")
        .task {
            guard let token = session.token else { return }
            if let loaded = try? await APIClient.shared.content(token: token) { content = loaded }
        }
    }
}

private struct PreparedOption: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let isCorrect: Bool
}

private struct PreparedQuestion: Identifiable {
    let id: String
    let source: TestQuestion
    let options: [PreparedOption]
}

struct QuizRunView: View {
    @EnvironmentObject var session: SessionStore
    @State private var questions: [PreparedQuestion]
    @State private var index = 0
    @State private var selected: PreparedOption?
    @State private var correctCount = 0
    @State private var errors: [QuizErrorPayload] = []
    @State private var answers: [QuizAnswerPayload] = []
    @State private var finished = false
    @State private var syncText = "Синхронизация…"

    private let category: String
    private let level: Int
    private let startedAt: String

    init(source: [TestQuestion], count: Int, category: String, level: Int) {
        let chosen = Array(source.shuffled().prefix(max(0, count)))
        _questions = State(initialValue: chosen.map { question in
            let options = question.options.enumerated().map { index, value in
                PreparedOption(text: value, isCorrect: question.correct.contains(index))
            }.shuffled()
            return PreparedQuestion(id: question.id, source: question, options: options)
        })
        self.category = category
        self.level = level
        self.startedAt = ISO8601DateFormatter().string(from: Date())
    }

    var body: some View {
        Group {
            if finished { resultView }
            else if questions.indices.contains(index) { questionView(questions[index]) }
            else { ContentUnavailableView("Нет вопросов", systemImage: "questionmark.circle") }
        }
        .navigationTitle(finished ? "Результат" : "Тест")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func questionView(_ question: PreparedQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("\(index + 1) / \(questions.count)").font(.caption.bold()).foregroundStyle(BALITheme.accent)
                    Spacer()
                    Text(question.source.category).font(.caption).foregroundStyle(.secondary)
                }
                SwiftUI.ProgressView(value: Double(index), total: Double(max(questions.count, 1))).tint(BALITheme.accent)
                Text(question.source.question).font(.title2.bold()).padding(.vertical, 10)

                ForEach(question.options) { option in
                    Button { choose(option, for: question) } label: {
                        HStack(alignment: .top) {
                            Text(option.text).foregroundStyle(.white).multilineTextAlignment(.leading)
                            Spacer()
                            if let selected {
                                if option.id == selected.id {
                                    Image(systemName: option.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(option.isCorrect ? .green : .red)
                                } else if !selected.isCorrect && option.isCorrect {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                }
                            }
                        }
                        .padding(15).background(optionBackground(option)).clipShape(RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain).disabled(selected != nil)
                }

                if let selected {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selected.isCorrect ? "✅ ВЕРНО" : "❌ НЕВЕРНО")
                            .font(.headline).foregroundStyle(selected.isCorrect ? .green : .red)
                        if !selected.isCorrect, let correct = question.options.first(where: { $0.isCorrect }) {
                            Text("Правильно: \(correct.text)").fontWeight(.bold)
                        }
                        Text(question.source.explanation).foregroundStyle(.secondary).lineSpacing(3)
                    }
                    .padding(16).background(BALITheme.panel).clipShape(RoundedRectangle(cornerRadius: 14))

                    Button(index == questions.count - 1 ? "ЗАВЕРШИТЬ" : "СЛЕДУЮЩИЙ ВОПРОС") {
                        if index == questions.count - 1 { finish() }
                        else { index += 1; self.selected = nil }
                    }
                    .fontWeight(.black).frame(maxWidth: .infinity).padding(15)
                    .background(BALITheme.accent).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }.padding(20)
        }.background(Color.black)
    }

    private func optionBackground(_ option: PreparedOption) -> Color {
        guard let selected else { return BALITheme.panel }
        if option.id == selected.id { return option.isCorrect ? Color.green.opacity(0.18) : Color.red.opacity(0.18) }
        if !selected.isCorrect && option.isCorrect { return Color.green.opacity(0.12) }
        return BALITheme.panel
    }

    private func choose(_ option: PreparedOption, for question: PreparedQuestion) {
        guard selected == nil else { return }
        selected = option
        answers.append(.init(questionId: question.id, correct: option.isCorrect))
        if option.isCorrect {
            correctCount += 1
        } else {
            errors.append(.init(
                questionId: question.id,
                topic: question.source.category,
                selected: option.text,
                correct: question.options.first(where: { $0.isCorrect })?.text ?? ""
            ))
        }
    }

    private func finish() {
        finished = true
        let total = questions.count
        let percent = total > 0 ? Int((Double(correctCount) / Double(total) * 100).rounded()) : 0
        let payload = QuizResultPayload(
            id: UUID().uuidString,
            mode: "training",
            category: category,
            level: level,
            total: total,
            correct: correctCount,
            percent: percent,
            errors: errors,
            answers: answers,
            startedAt: startedAt,
            completedAt: ISO8601DateFormatter().string(from: Date())
        )
        guard let token = session.token else { syncText = "Нет активной сессии"; return }
        Task {
            do {
                try await APIClient.shared.submit(result: payload, token: token)
                await MainActor.run { syncText = "Результат сохранён и виден администратору" }
            } catch {
                await MainActor.run { syncText = "Не удалось синхронизировать: \(error.localizedDescription)" }
            }
        }
    }

    private var resultView: some View {
        let total = questions.count
        let percent = total > 0 ? Int((Double(correctCount) / Double(total) * 100).rounded()) : 0
        return ScrollView {
            VStack(spacing: 20) {
                Image(systemName: percent >= 90 ? "trophy.fill" : "chart.bar.fill")
                    .font(.system(size: 56)).foregroundStyle(BALITheme.accent)
                Text("\(percent)%").font(.system(size: 52, weight: .black))
                Text("\(correctCount) из \(total) правильных").foregroundStyle(.secondary)
                Text(syncText).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)

                if !errors.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ошибки").font(.title3.bold())
                        ForEach(Array(errors.enumerated()), id: \.offset) { _, error in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(error.topic).font(.caption).foregroundStyle(BALITheme.accent)
                                Text("Вы: \(error.selected)")
                                Text("Правильно: \(error.correct)").fontWeight(.bold)
                            }
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(BALITheme.panel).clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }.padding(24)
        }.background(Color.black)
    }
}

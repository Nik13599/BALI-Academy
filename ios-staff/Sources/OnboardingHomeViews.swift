import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var session: SessionStore
    @State private var fio = ""
    @State private var role: StaffRole = .bartender

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 0.07, green: 0.10, blue: 0.06)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Spacer(minLength: 40)
                    Text("BALI").font(.system(size: 48, weight: .black, design: .rounded)).tracking(8).foregroundStyle(BALITheme.accent)
                    Text("ACADEMY").font(.headline).tracking(4).foregroundStyle(.secondary)
                    Text("Обучение персонала").font(.largeTitle.bold()).padding(.top, 12)
                    Text("На новом устройстве введите ФИО и выберите должность. Система привяжет обучение и тесты к вашему персональному профилю.")
                        .foregroundStyle(.secondary).lineSpacing(4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("ФИО").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("Иванов Иван Иванович", text: $fio)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .padding(15).background(BALITheme.panel).clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("ДОЛЖНОСТЬ").font(.caption.bold()).foregroundStyle(.secondary)
                        ForEach(StaffRole.allCases) { item in
                            Button { role = item } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: item == .bartender ? "wineglass" : "person.crop.rectangle").font(.title2).frame(width: 36)
                                    VStack(alignment: .leading) {
                                        Text(item.title).font(.headline)
                                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: role == item ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(role == item ? BALITheme.accent : .secondary)
                                }
                                .padding(16)
                                .background(BALITheme.panel)
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(role == item ? BALITheme.accent.opacity(0.7) : .gray.opacity(0.2)))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain)
                        }
                    }

                    if let error = session.errorMessage { Text(error).foregroundStyle(.red).font(.footnote) }
                    Button { Task { await session.login(fio: fio, role: role) } } label: {
                        HStack {
                            Spacer()
                            if session.isBusy { SwiftUI.ProgressView().tint(.black) }
                            else { Text("ВОЙТИ В BALI ACADEMY").fontWeight(.black) }
                            Spacer()
                        }
                        .padding(16).background(BALITheme.accent).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius: 14))
                    }.disabled(session.isBusy)
                }.padding(24)
            }
        }
    }
}

struct StaffHomeView: View {
    @EnvironmentObject var session: SessionStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("BALI ACADEMY").font(.caption.bold()).tracking(2).foregroundStyle(BALITheme.accent)
                            Text(session.employee?.fio ?? "").font(.title2.bold())
                            Text(session.role?.title ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { session.logout() } label: { Image(systemName: "rectangle.portrait.and.arrow.right").font(.title3) }
                    }
                    if session.role == .bartender { bartenderGrid } else { waiterGrid }

                    Text("Ежедневная практика").font(.title3.bold()).padding(.top, 6)
                    NavigationLink(destination: QuizSetupView()) { FeatureCard(icon: "bolt.fill", title: "Быстрый тест", subtitle: "10 / 20 / 30 / 50 / 100 случайных вопросов") }
                    NavigationLink(destination: AITrainerView()) { FeatureCard(icon: "sparkles", title: "AI-тренер", subtitle: "Спросить • объяснить • проверить • продажи") }
                    NavigationLink(destination: MyProgressView()) { FeatureCard(icon: "chart.line.uptrend.xyaxis", title: "Мой прогресс", subtitle: "Результаты и история попыток") }
                }.padding(20)
            }
            .background(Color.black)
            .navigationBarHidden(true)
        }
    }

    @ViewBuilder private var bartenderGrid: some View {
        Text("Бармен").font(.largeTitle.bold())
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            NavigationLink(destination: KnowledgeView()) { SmallCard(icon: "books.vertical.fill", title: "Алкоголь", subtitle: "Происхождение и подача") }
            NavigationLink(destination: CocktailListView()) { SmallCard(icon: "takeoutbag.and.cup.and.straw.fill", title: "Коктейли", subtitle: "Классика и техкарты") }
            NavigationLink(destination: LessonsView(categoryFilter: "Матчасть")) { SmallCard(icon: "wrench.and.screwdriver.fill", title: "Матчасть", subtitle: "Инструменты и техника") }
            NavigationLink(destination: LessonsView(categoryFilter: "Продажи")) { SmallCard(icon: "bubble.left.and.bubble.right.fill", title: "Продажи", subtitle: "Коммуникация с гостем") }
        }
    }

    @ViewBuilder private var waiterGrid: some View {
        Text("Официант").font(.largeTitle.bold())
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            NavigationLink(destination: KnowledgeView()) { SmallCard(icon: "menucard.fill", title: "Меню и цены", subtitle: "Ассортимент и наличие") }
            NavigationLink(destination: LessonsView(categoryFilter: "Сервис официанта")) { SmallCard(icon: "person.2.fill", title: "Сервис", subtitle: "Меню и обслуживание") }
            NavigationLink(destination: LessonsView(categoryFilter: "Продажи")) { SmallCard(icon: "chart.bar.fill", title: "Продажи", subtitle: "Premium и upsell") }
            NavigationLink(destination: KnowledgeView()) { SmallCard(icon: "wineglass.fill", title: "Алкоголь", subtitle: "Что и как рекомендовать") }
        }
    }
}

struct SmallCard: View {
    let icon: String, title: String, subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(BALITheme.accent)
            Text(title).font(.headline).foregroundStyle(.white)
            Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .padding(16).background(BALITheme.panel).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct FeatureCard: View {
    let icon: String, title: String, subtitle: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(BALITheme.accent).frame(width: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }.padding(16).background(BALITheme.panel).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

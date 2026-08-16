import SwiftUI

private let baliAccent = Color(red: 0.90, green: 1.0, blue: 0.38)
private let baliPanel = Color(red: 0.085, green: 0.095, blue: 0.11)

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
                    Text("BALI").font(.system(size: 48, weight: .black, design: .rounded)).tracking(8).foregroundStyle(baliAccent)
                    Text("ACADEMY").font(.headline).tracking(4).foregroundStyle(.secondary)
                    Text("Обучение персонала").font(.largeTitle.bold()).padding(.top, 12)
                    Text("Введите ФИО и выберите должность. На новом устройстве система найдёт или создаст ваш персональный профиль и синхронизирует дальнейшие результаты обучения.")
                        .foregroundStyle(.secondary).lineSpacing(4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("ФИО").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("Иванов Иван Иванович", text: $fio)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .padding(15).background(baliPanel).clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("ДОЛЖНОСТЬ").font(.caption.bold()).foregroundStyle(.secondary)
                        ForEach(StaffRole.allCases) { item in
                            Button {
                                role = item
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: item == .bartender ? "wineglass" : "person.crop.rectangle")
                                        .font(.title2).frame(width: 36)
                                    VStack(alignment: .leading) {
                                        Text(item.title).font(.headline)
                                        Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: role == item ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(role == item ? baliAccent : .secondary)
                                }
                                .padding(16).background(baliPanel).overlay(RoundedRectangle(cornerRadius: 16).stroke(role == item ? baliAccent.opacity(0.7) : .gray.opacity(0.2))).clipShape(RoundedRectangle(cornerRadius: 16))
                            }.buttonStyle(.plain)
                        }
                    }

                    if let error = session.errorMessage {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }

                    Button {
                        Task { await session.login(fio: fio, role: role) }
                    } label: {
                        HStack { Spacer(); if session.isBusy { ProgressView().tint(.black) } else { Text("ВОЙТИ В BALI ACADEMY").fontWeight(.black) }; Spacer() }
                            .padding(16).background(baliAccent).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius: 14))
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
                            Text("BALI ACADEMY").font(.caption.bold()).tracking(2).foregroundStyle(baliAccent)
                            Text(session.employee?.fio ?? "").font(.title2.bold())
                            Text(session.role?.title ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { session.logout() } label: { Image(systemName: "rectangle.portrait.and.arrow.right").font(.title3) }
                    }
                    .padding(.bottom, 6)

                    if session.role == .bartender { bartenderGrid } else { waiterGrid }

                    Text("Ежедневная практика").font(.title3.bold()).padding(.top, 6)
                    NavigationLink(destination: QuizSetupView()) { FeatureCard(icon: "bolt.fill", title: "Быстрый тест", subtitle: "10 / 20 / 30 / 50 / 100 случайных вопросов") }
                    NavigationLink(destination: AITrainerView()) { FeatureCard(icon: "sparkles", title: "AI-тренер", subtitle: "Спросить • объяснить • проверить • потренировать продажи") }
                    NavigationLink(destination: ProgressView()) { FeatureCard(icon: "chart.line.uptrend.xyaxis", title: "Мой прогресс", subtitle: "Результаты, категории и история попыток") }
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
    let icon: String; let title: String; let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.title2).foregroundStyle(baliAccent)
            Text(title).font(.headline).foregroundStyle(.white)
            Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }.frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading).padding(16).background(baliPanel).clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

struct FeatureCard: View {
    let icon: String; let title: String; let subtitle: String
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(baliAccent).frame(width: 40)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline).foregroundStyle(.white); Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }.padding(16).background(baliPanel).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct KnowledgeView: View {
    @EnvironmentObject var session: SessionStore
    @State private var content: ContentResponse?
    @State private var search = ""
    @State private var error: String?

    private var filtered: [Product] {
        guard let products = content?.products else { return [] }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return products }
        return products.filter { p in
            ([p.name, p.category, p.country ?? ""] + (p.aliases ?? [])).joined(separator: " ").lowercased().contains(q)
        }
    }

    var body: some View {
        List {
            if let error { Text(error).foregroundStyle(.red) }
            ForEach(filtered) { product in
                NavigationLink(destination: ProductDetailView(product: product)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name).font(.headline)
                        Text([product.category, product.country].compactMap{$0}.joined(separator: " • ")).font(.caption).foregroundStyle(.secondary)
                        if session.role == .waiter, let price = product.price { PriceLine(price: price) }
                    }.padding(.vertical, 4)
                }
            }
        }
        .searchable(text: $search, prompt: "Название, страна, категория")
        .navigationTitle(session.role == .waiter ? "Меню и продукты" : "База продуктов")
        .task { await load() }
    }

    private func load() async {
        guard content == nil, let token = session.token else { return }
        do { content = try await APIClient.shared.content(token: token) }
        catch { self.error = error.localizedDescription }
    }
}

struct PriceLine: View {
    let price: [String:Int]
    var body: some View {
        HStack(spacing: 10) {
            if let v = price["portion40BYN"] { Text("40 мл \(v) BYN") }
            if let v = price["glass125BYN"] { Text("125 мл \(v) BYN") }
            if let v = price["serveBYN"] { Text("Порция \(v) BYN") }
            if let v = price["bottleBYN"] { Text("Бутылка \(v) BYN") }
        }.font(.caption.bold()).foregroundStyle(baliAccent)
    }
}

struct ProductDetailView: View {
    @EnvironmentObject var session: SessionStore
    let product: Product
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(product.category.uppercased()).font(.caption.bold()).foregroundStyle(baliAccent)
                Text(product.name).font(.largeTitle.bold())
                if let country = product.country { Label(country, systemImage: "globe.europe.africa") }
                if session.role == .waiter, let price = product.price { PriceLine(price: price).padding(.vertical, 5) }
                if let short = product.short { InfoBlock(title: "Что это", body: short) }
                if let taste = product.taste, !taste.isEmpty { InfoBlock(title: "Профиль", body: taste.joined(separator: " • ")) }
                if let service = product.service { InfoBlock(title: "Подача", body: service) }
                if session.role == .bartender, let b = product.bartender { InfoBlock(title: "Бармену", body: b) }
                if session.role == .waiter, let sales = product.sales { InfoBlock(title: "Как продать", body: sales) }
            }.padding(20)
        }.background(Color.black).navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }
}

struct InfoBlock: View {
    let title: String; let body: String
    var body: some View { VStack(alignment: .leading, spacing: 7) { Text(title).font(.caption.bold()).foregroundStyle(.secondary); Text(body).font(.body).lineSpacing(4) }.frame(maxWidth: .infinity, alignment: .leading).padding(16).background(baliPanel).clipShape(RoundedRectangle(cornerRadius: 15)) }
}

struct LessonsView: View {
    @EnvironmentObject var session: SessionStore
    let categoryFilter: String
    @State private var lessons: [Lesson] = []
    var body: some View {
        List(lessons.filter { $0.category == categoryFilter }) { lesson in
            VStack(alignment: .leading, spacing: 7) { Text(lesson.title).font(.headline); Text(lesson.body).foregroundStyle(.secondary).lineSpacing(3); Text("Уровень \(lesson.level)").font(.caption.bold()).foregroundStyle(baliAccent) }.padding(.vertical, 8)
        }.navigationTitle(categoryFilter).task { if let token = session.token, let c = try? await APIClient.shared.content(token: token) { lessons = c.lessons } }
    }
}

struct CocktailListView: View {
    @EnvironmentObject var session: SessionStore
    @State private var cocktails: [Cocktail] = []
    @State private var search = ""
    private var visible: [Cocktail] { search.isEmpty ? cocktails : cocktails.filter { ([ $0.name ] + ($0.aliases ?? [])).joined(separator:" ").lowercased().contains(search.lowercased()) } }
    var body: some View {
        List(visible) { c in NavigationLink(destination: CocktailDetailView(cocktail: c)) { VStack(alignment:.leading){ Text(c.name).font(.headline); Text(c.method ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1) } } }
            .searchable(text:$search,prompt:"Negroni / негрони / negrony")
            .navigationTitle("Коктейли")
            .task { if let token = session.token, let c = try? await APIClient.shared.content(token: token) { cocktails = c.cocktails } }
    }
}

struct CocktailDetailView: View {
    let cocktail: Cocktail
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:16){ Text(cocktail.name).font(.largeTitle.bold()); if cocktail.operationalRecipe != true { Text("УЧЕБНАЯ КЛАССИКА • ТЕХКАРТА BALI ИМЕЕТ ПРИОРИТЕТ").font(.caption.bold()).foregroundStyle(.orange) }
            if let ingredients = cocktail.ingredients { InfoBlock(title:"Ингредиенты",body:ingredients.map{ item in item.ml.map { "\(item.name) — \(Int($0)) мл" } ?? item.name }.joined(separator:"\n")) }
            if let m = cocktail.method { InfoBlock(title:"Метод",body:m) }; if let g = cocktail.glass { InfoBlock(title:"Стекло",body:g) }; if let g = cocktail.garnish { InfoBlock(title:"Garnish",body:g) }
        }.padding(20)}.background(Color.black)
    }
}

struct QuizSetupView: View {
    @EnvironmentObject var session: SessionStore
    @State private var content: ContentResponse?
    @State private var count = 10
    @State private var level = 0
    @State private var category = "Все"
    let counts = [10,20,30,50,100]

    private var pool: [TestQuestion] {
        (content?.tests ?? []).filter { $0.type == "single" && (level == 0 || $0.level == level) && (category == "Все" || $0.category == category) }
    }
    private var categories: [String] { ["Все"] + Array(Set((content?.tests ?? []).map{$0.category})).sorted() }

    var body: some View {
        Form {
            Section("Количество") { Picker("Вопросов", selection:$count){ ForEach(counts,id:\.self){Text("\($0)").tag($0)} }.pickerStyle(.segmented) }
            Section("Категория") { Picker("Категория", selection:$category){ ForEach(categories,id:\.self){Text($0).tag($0)} } }
            Section("Уровень") { Picker("Уровень", selection:$level){ Text("Смешанный").tag(0); ForEach(1...5,id:\.self){Text("Уровень \($0)").tag($0)} } }
            Section { NavigationLink(destination: QuizRunView(source: pool, count: min(count,pool.count), category: category, level: level)) { HStack{Spacer();Text(pool.isEmpty ? "Нет вопросов" : "НАЧАТЬ • \(min(count,pool.count))").fontWeight(.black);Spacer()} }.disabled(pool.isEmpty) }
        }.navigationTitle("Новый тест").task { if let token=session.token, let c=try? await APIClient.shared.content(token:token){content=c} }
    }
}

private struct PreparedOption: Identifiable, Hashable { let id = UUID(); let text: String; let isCorrect: Bool }
private struct PreparedQuestion: Identifiable { let id: String; let source: TestQuestion; let options: [PreparedOption] }

struct QuizRunView: View {
    @EnvironmentObject var session: SessionStore
    @State private var questions: [PreparedQuestion]
    @State private var index = 0
    @State private var selected: PreparedOption?
    @State private var correctCount = 0
    @State private var errors: [QuizErrorPayload] = []
    @State private var answers: [QuizAnswerPayload] = []
    @State private var finished = false
    @State private var synced = false
    private let category: String
    private let level: Int
    private let startedAt = ISO8601DateFormatter().string(from: Date())

    init(source: [TestQuestion], count: Int, category: String, level: Int) {
        let chosen = Array(source.shuffled().prefix(max(0,count)))
        _questions = State(initialValue: chosen.map { q in
            let opts = q.options.enumerated().map { PreparedOption(text:$0.element,isCorrect:q.correct.contains($0.offset)) }.shuffled()
            return PreparedQuestion(id:q.id,source:q,options:opts)
        })
        self.category = category
        self.level = level
    }

    var body: some View {
        Group {
            if finished { resultView }
            else if questions.indices.contains(index) { questionView(questions[index]) }
            else { ContentUnavailableView("Нет вопросов", systemImage:"questionmark.circle") }
        }.navigationBarBackButtonHidden(!finished)
    }

    private func questionView(_ q: PreparedQuestion) -> some View {
        ScrollView {
            VStack(alignment:.leading,spacing:18){
                HStack{Text("\(index+1) / \(questions.count)").font(.caption.bold()).foregroundStyle(baliAccent);Spacer();Text(q.source.category).font(.caption).foregroundStyle(.secondary)}
                ProgressView(value:Double(index),total:Double(max(questions.count,1))).tint(baliAccent)
                Text(q.source.question).font(.title2.bold()).padding(.vertical,10)
                ForEach(q.options) { option in
                    Button { choose(option, for:q) } label: {
                        HStack(alignment:.top){Text(option.text).foregroundStyle(.white);Spacer(); if let selected { if option.id==selected.id { Image(systemName:option.isCorrect ? "checkmark.circle.fill":"xmark.circle.fill").foregroundStyle(option.isCorrect ? .green:.red) } else if !selected.isCorrect && option.isCorrect { Image(systemName:"checkmark.circle.fill").foregroundStyle(.green) } }}
                            .padding(15).background(optionBackground(option)).clipShape(RoundedRectangle(cornerRadius:14))
                    }.buttonStyle(.plain).disabled(selected != nil)
                }
                if let selected {
                    VStack(alignment:.leading,spacing:7){Text(selected.isCorrect ? "✅ ВЕРНО" : "❌ НЕВЕРНО").font(.headline).foregroundStyle(selected.isCorrect ? .green:.red); if !selected.isCorrect, let correct=q.options.first(where:{$0.isCorrect}) { Text("Правильно: \(correct.text)").fontWeight(.bold) }; Text(q.source.explanation).foregroundStyle(.secondary).lineSpacing(3)}
                        .padding(16).background(baliPanel).clipShape(RoundedRectangle(cornerRadius:14))
                    Button(index == questions.count-1 ? "ЗАВЕРШИТЬ" : "СЛЕДУЮЩИЙ ВОПРОС") { if index == questions.count-1 { finish() } else { index += 1; self.selected=nil } }
                        .fontWeight(.black).frame(maxWidth:.infinity).padding(15).background(baliAccent).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius:14))
                }
            }.padding(20)
        }.background(Color.black).navigationTitle("Тест").navigationBarTitleDisplayMode(.inline)
    }

    private func optionBackground(_ option: PreparedOption) -> Color {
        guard let selected else { return baliPanel }
        if option.id == selected.id { return option.isCorrect ? Color.green.opacity(0.18) : Color.red.opacity(0.18) }
        if !selected.isCorrect && option.isCorrect { return Color.green.opacity(0.12) }
        return baliPanel
    }

    private func choose(_ option: PreparedOption, for q: PreparedQuestion) {
        guard selected == nil else { return }
        selected = option
        answers.append(.init(questionId:q.id,correct:option.isCorrect))
        if option.isCorrect { correctCount += 1 }
        else { errors.append(.init(questionId:q.id,topic:q.source.category,selected:option.text,correct:q.options.first(where:{$0.isCorrect})?.text ?? "")) }
    }

    private func finish() {
        finished = true
        let total = questions.count
        let percent = total > 0 ? Int((Double(correctCount)/Double(total)*100).rounded()) : 0
        let payload = QuizResultPayload(id:UUID().uuidString,mode:"training",category:category,level:level,total:total,correct:correctCount,percent:percent,errors:errors,answers:answers,startedAt:startedAt,completedAt:ISO8601DateFormatter().string(from:Date()))
        if let token=session.token { Task { do { try await APIClient.shared.submit(result:payload,token:token); await MainActor.run{synced=true} } catch {} } }
    }

    private var resultView: some View {
        let total = questions.count
        let percent = total > 0 ? Int((Double(correctCount)/Double(total)*100).rounded()) : 0
        return ScrollView { VStack(spacing:20){ Image(systemName:percent>=90 ? "trophy.fill":"chart.bar.fill").font(.system(size:56)).foregroundStyle(baliAccent); Text("\(percent)%").font(.system(size:52,weight:.black)); Text("\(correctCount) из \(total) правильных").foregroundStyle(.secondary); Label(synced ? "Результат синхронизирован" : "Синхронизация результата…",systemImage:synced ? "checkmark.icloud.fill":"icloud.and.arrow.up").font(.caption).foregroundStyle(.secondary)
            if !errors.isEmpty { VStack(alignment:.leading,spacing:10){Text("Ошибки").font(.title3.bold());ForEach(Array(errors.enumerated()),id:\.offset){_,e in VStack(alignment:.leading,spacing:4){Text(e.topic).font(.caption).foregroundStyle(baliAccent);Text("Вы: \(e.selected)");Text("Правильно: \(e.correct)").fontWeight(.bold)}.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(baliPanel).clipShape(RoundedRectangle(cornerRadius:12))}} }
        }.padding(24)}.background(Color.black).navigationTitle("Результат")
    }
}

struct ProgressView: View {
    @EnvironmentObject var session: SessionStore
    @State private var progress: ProgressResponse?
    @State private var error: String?
    var body: some View {
        ScrollView { VStack(alignment:.leading,spacing:18){
            if let p=progress { HStack{ScoreBox(title:"Средний",value:"\(p.stats.avg)%");ScoreBox(title:"Лучший",value:"\(p.stats.best)%");ScoreBox(title:"Тестов",value:"\(p.stats.totalAttempts)")}
                Text("По категориям").font(.title3.bold()); ForEach(p.stats.categories.sorted(by:{$0.key<$1.key}),id:\.key){k,v in HStack{Text(k);Spacer();Text("\(v)%").fontWeight(.bold).foregroundStyle(v<70 ? .orange:baliAccent)}.padding(12).background(baliPanel).clipShape(RoundedRectangle(cornerRadius:12))}
                Text("Последние попытки").font(.title3.bold()).padding(.top,6); ForEach(p.attempts){a in HStack{VStack(alignment:.leading){Text(a.category).fontWeight(.semibold);Text(a.completedAt ?? "").font(.caption).foregroundStyle(.secondary)};Spacer();Text("\(a.percent)%").font(.title3.bold()).foregroundStyle(a.percent>=90 ? baliAccent:.white)}.padding(13).background(baliPanel).clipShape(RoundedRectangle(cornerRadius:12))}
            } else if let error { Text(error).foregroundStyle(.red) } else { ProgressView() }
        }.padding(20)}.background(Color.black).navigationTitle("Мой прогресс").task{guard let token=session.token else{return};do{progress=try await APIClient.shared.progress(token:token)}catch{self.error=error.localizedDescription}}
    }
}

struct ScoreBox: View { let title:String;let value:String;var body:some View{VStack(spacing:6){Text(value).font(.title2.bold()).foregroundStyle(baliAccent);Text(title).font(.caption).foregroundStyle(.secondary)}.frame(maxWidth:.infinity).padding(14).background(baliPanel).clipShape(RoundedRectangle(cornerRadius:14))} }

private struct ChatLine: Identifiable { let id=UUID(); let role:String; let text:String }

struct AITrainerView: View {
    @EnvironmentObject var session: SessionStore
    @State private var mode="ask"
    @State private var input=""
    @State private var lines:[ChatLine]=[.init(role:"assistant",text:"Я AI-тренер BALI. Спроси про продукт, коктейль, подачу или попроси потренировать продажу.")]
    @State private var options:[AIOption]=[]
    @State private var busy=false
    private let modes=[("ask","Спросить"),("explain","Объяснить"),("sales","Продажи"),("quiz","Проверить")]

    var body: some View {
        VStack(spacing:0){
            Picker("Режим",selection:$mode){ForEach(modes,id:\.0){Text($0.1).tag($0.0)}}.pickerStyle(.segmented).padding()
            ScrollViewReader{proxy in ScrollView{LazyVStack(alignment:.leading,spacing:10){ForEach(lines){line in Text(line.text).padding(12).background(line.role=="user" ? baliAccent.opacity(.18):baliPanel).clipShape(RoundedRectangle(cornerRadius:14)).frame(maxWidth:.infinity,alignment:line.role=="user" ? .trailing:.leading)}
                if !options.isEmpty { VStack(alignment:.leading,spacing:8){Text("Возможно, вы имели в виду:").font(.caption).foregroundStyle(.secondary);ForEach(options){o in Button(o.name){input=o.name;options=[];send()} .buttonStyle(.bordered)}}.frame(maxWidth:.infinity,alignment:.leading) }
                if busy{ProgressView().padding()}
            }.padding()}.onChange(of:lines.count){_,_ in if let last=lines.last{proxy.scrollTo(last.id,anchor:.bottom)}}}
            HStack{TextField("макалан / macalan / Long Island…",text:$input,axis:.vertical).textFieldStyle(.plain).padding(12).background(baliPanel).clipShape(RoundedRectangle(cornerRadius:12));Button{send()}label:{Image(systemName:"arrow.up.circle.fill").font(.title).foregroundStyle(baliAccent)}}.padding()
        }.background(Color.black).navigationTitle("AI-тренер").navigationBarTitleDisplayMode(.inline)
    }

    private func send(){let text=input.trimmingCharacters(in:.whitespacesAndNewlines);guard !text.isEmpty,!busy,let token=session.token else{return};input="";lines.append(.init(role:"user",text:text));busy=true;Task{do{let r=try await APIClient.shared.askAI(message:text,mode:mode,token:token);await MainActor.run{if r.type=="clarification"{lines.append(.init(role:"assistant",text:r.message ?? "Выберите вариант"));options=r.options ?? []}else{lines.append(.init(role:"assistant",text:r.text ?? "Нет ответа"))};busy=false}}catch{await MainActor.run{lines.append(.init(role:"assistant",text:"Ошибка: \(error.localizedDescription)"));busy=false}}}}
}

import SwiftUI

struct KnowledgeView: View {
    @EnvironmentObject var session: SessionStore
    @State private var content: ContentResponse?
    @State private var search = ""
    @State private var errorMessage: String?

    private var filtered: [Product] {
        guard let products = content?.products else { return [] }
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return products }
        return products.filter { product in
            ([product.name, product.category, product.country ?? ""] + (product.aliases ?? []))
                .joined(separator: " ").lowercased().contains(q)
        }
    }

    var body: some View {
        List {
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            ForEach(filtered) { product in
                NavigationLink(destination: ProductDetailView(product: product)) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(product.name).font(.headline)
                        Text([product.category, product.country].compactMap { $0 }.joined(separator: " • "))
                            .font(.caption).foregroundStyle(.secondary)
                        if session.role == .waiter, let price = product.price { PriceLine(price: price) }
                    }.padding(.vertical, 5)
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
        catch { errorMessage = error.localizedDescription }
    }
}

struct PriceLine: View {
    let price: [String: Int]
    var body: some View {
        HStack(spacing: 10) {
            if let v = price["portion40BYN"] { Text("40 мл \(v) BYN") }
            if let v = price["glass125BYN"] { Text("125 мл \(v) BYN") }
            if let v = price["serveBYN"] { Text("Порция \(v) BYN") }
            if let v = price["bottleBYN"] { Text("Бутылка \(v) BYN") }
        }.font(.caption.bold()).foregroundStyle(BALITheme.accent)
    }
}

struct ProductDetailView: View {
    @EnvironmentObject var session: SessionStore
    let product: Product

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(product.category.uppercased()).font(.caption.bold()).foregroundStyle(BALITheme.accent)
                Text(product.name).font(.largeTitle.bold())
                if let country = product.country { Label(country, systemImage: "globe.europe.africa") }
                if session.role == .waiter, let price = product.price { PriceLine(price: price).padding(.vertical, 5) }
                if let short = product.short { BALIInfoBlock(title: "Что это", body: short) }
                if let taste = product.taste, !taste.isEmpty { BALIInfoBlock(title: "Профиль", body: taste.joined(separator: " • ")) }
                if let service = product.service { BALIInfoBlock(title: "Подача", body: service) }
                if session.role == .bartender, let info = product.bartender { BALIInfoBlock(title: "Бармену", body: info) }
                if session.role == .waiter, let sales = product.sales { BALIInfoBlock(title: "Как рекомендовать", body: sales) }
            }.padding(20)
        }.background(Color.black).navigationBarTitleDisplayMode(.inline)
    }
}

struct LessonsView: View {
    @EnvironmentObject var session: SessionStore
    let categoryFilter: String
    @State private var lessons: [Lesson] = []

    var body: some View {
        List(lessons.filter { $0.category == categoryFilter }) { lesson in
            VStack(alignment: .leading, spacing: 8) {
                Text(lesson.title).font(.headline)
                Text(lesson.body).foregroundStyle(.secondary).lineSpacing(3)
                Text("Уровень \(lesson.level)").font(.caption.bold()).foregroundStyle(BALITheme.accent)
            }.padding(.vertical, 8)
        }
        .navigationTitle(categoryFilter)
        .task {
            guard let token = session.token else { return }
            if let content = try? await APIClient.shared.content(token: token) { lessons = content.lessons }
        }
    }
}

struct CocktailListView: View {
    @EnvironmentObject var session: SessionStore
    @State private var cocktails: [Cocktail] = []
    @State private var search = ""

    private var visible: [Cocktail] {
        let q = search.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return cocktails }
        return cocktails.filter { cocktail in
            ([cocktail.name] + (cocktail.aliases ?? [])).joined(separator: " ").lowercased().contains(q)
        }
    }

    var body: some View {
        List(visible) { cocktail in
            NavigationLink(destination: CocktailDetailView(cocktail: cocktail)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cocktail.name).font(.headline)
                    Text(cocktail.method ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }.padding(.vertical, 4)
            }
        }
        .searchable(text: $search, prompt: "Negroni / негрони / negrony")
        .navigationTitle("Коктейли")
        .task {
            guard let token = session.token else { return }
            if let content = try? await APIClient.shared.content(token: token) { cocktails = content.cocktails }
        }
    }
}

struct CocktailDetailView: View {
    let cocktail: Cocktail
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(cocktail.name).font(.largeTitle.bold())
                if cocktail.operationalRecipe != true {
                    Text("УЧЕБНАЯ КЛАССИКА • ТЕХКАРТА BALI ИМЕЕТ ПРИОРИТЕТ")
                        .font(.caption.bold()).foregroundStyle(.orange)
                }
                if let ingredients = cocktail.ingredients {
                    let text = ingredients.map { item in
                        if let ml = item.ml { return "\(item.name) — \(Int(ml)) мл" }
                        return item.name + ((item.optional ?? false) ? " — опционально" : "")
                    }.joined(separator: "\n")
                    BALIInfoBlock(title: "Ингредиенты", body: text)
                }
                if let method = cocktail.method { BALIInfoBlock(title: "Метод", body: method) }
                if let glass = cocktail.glass { BALIInfoBlock(title: "Стекло", body: glass) }
                if let garnish = cocktail.garnish { BALIInfoBlock(title: "Garnish", body: garnish) }
                if let note = cocktail.note { Text(note).font(.footnote).foregroundStyle(.secondary) }
            }.padding(20)
        }.background(Color.black).navigationBarTitleDisplayMode(.inline)
    }
}

import Foundation

enum StaffRole: String, Codable, CaseIterable, Identifiable {
    case bartender
    case waiter
    var id: String { rawValue }
    var title: String { self == .bartender ? "БАРМЕН" : "ОФИЦИАНТ" }
    var subtitle: String { self == .bartender ? "Продукт • техника • коктейли" : "Меню • сервис • продажи" }
}

struct Employee: Codable, Identifiable {
    let id: String
    let fio: String
    let role: StaffRole
}

struct RegistrationResponse: Codable {
    let employee: Employee
    let token: String
}

struct Product: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let country: String?
    let aliases: [String]?
    let short: String?
    let service: String?
    let taste: [String]?
    let available: Bool
    let price: [String: Int]?
    let sales: String?
    let bartender: String?
}

struct CocktailIngredient: Codable, Hashable {
    let name: String
    let ml: Double?
    let optional: Bool?
}

struct Cocktail: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let aliases: [String]?
    let trainingRecipe: Bool?
    let operationalRecipe: Bool?
    let ingredients: [CocktailIngredient]?
    let method: String?
    let glass: String?
    let garnish: String?
    let note: String?
    let price: [String: Int]?
}

struct Lesson: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let roles: [String]?
    let level: Int
    let body: String
}

struct TestQuestion: Codable, Identifiable, Hashable {
    let id: String
    let category: String
    let roles: [String]?
    let level: Int
    let type: String
    let question: String
    let options: [String]
    let correct: [Int]
    let explanation: String
}

struct ContentResponse: Codable {
    let schemaVersion: Int?
    let role: String
    let categories: [String]
    let products: [Product]
    let cocktails: [Cocktail]
    let tests: [TestQuestion]
    let lessons: [Lesson]
}

struct QuizErrorPayload: Codable {
    let questionId: String
    let topic: String
    let selected: String
    let correct: String
}

struct QuizAnswerPayload: Codable {
    let questionId: String
    let correct: Bool
}

struct QuizResultPayload: Codable {
    let id: String
    let mode: String
    let category: String
    let level: Int
    let total: Int
    let correct: Int
    let percent: Int
    let errors: [QuizErrorPayload]
    let answers: [QuizAnswerPayload]
    let startedAt: String
    let completedAt: String
}

struct Attempt: Codable, Identifiable {
    let id: String
    let mode: String
    let category: String
    let level: Int
    let total: Int
    let correct: Int
    let percent: Int
    let completedAt: String?
}

struct ProgressStats: Codable {
    let totalAttempts: Int
    let avg: Int
    let best: Int
    let categories: [String: Int]
}

struct ProgressResponse: Codable {
    let employee: Employee
    let attempts: [Attempt]
    let stats: ProgressStats
}

struct AIOption: Codable, Identifiable {
    let type: String
    let id: String
    let name: String
}

struct AIResponse: Codable {
    let type: String
    let message: String?
    let text: String?
    let options: [AIOption]?
    let groundedEntities: [AIOption]?
}

struct AIRequest: Codable {
    let message: String
    let mode: String
}

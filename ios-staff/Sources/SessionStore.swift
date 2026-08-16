import Foundation
import Security

@MainActor
final class SessionStore: ObservableObject {
    @Published var employee: Employee?
    @Published var token: String?
    @Published var isBusy = false
    @Published var errorMessage: String?

    private let tokenKey = "bali.staff.session.token"
    private let employeeKey = "bali.staff.employee"
    private let deviceKey = "bali.staff.device.id"

    init() {
        token = KeychainStore.read(tokenKey)
        if let data = UserDefaults.standard.data(forKey: employeeKey) {
            employee = try? JSONDecoder().decode(Employee.self, from: data)
        }
    }

    var isLoggedIn: Bool { token != nil && employee != nil }
    var role: StaffRole? { employee?.role }

    func login(fio: String, role: StaffRole) async {
        guard fio.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ").count >= 2 else {
            errorMessage = "Введите ФИО полностью."
            return
        }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let response = try await APIClient.shared.register(fio: fio, role: role, deviceId: deviceId())
            employee = response.employee
            token = response.token
            KeychainStore.save(response.token, for: tokenKey)
            if let data = try? JSONEncoder().encode(response.employee) { UserDefaults.standard.set(data, forKey: employeeKey) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        KeychainStore.delete(tokenKey)
        UserDefaults.standard.removeObject(forKey: employeeKey)
        token = nil
        employee = nil
    }

    private func deviceId() -> String {
        if let existing = UserDefaults.standard.string(forKey: deviceKey) { return existing }
        let value = UUID().uuidString.lowercased()
        UserDefaults.standard.set(value, forKey: deviceKey)
        return value
    }
}

enum KeychainStore {
    static func save(_ value: String, for key: String) {
        delete(key)
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(_ key: String) {
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key] as CFDictionary)
    }
}

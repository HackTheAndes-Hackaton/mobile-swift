import SwiftUI
import UserNotifications
import CoreText

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner, .sound]) }
}
@main struct TiskzApp: App {
    @Environment(\.scenePhase) private var phase
    @StateObject private var settings: Settings
    @StateObject private var session = CallSession()
    @StateObject private var history: History
    private let notifications = NotificationDelegate()
    init() {
        if let fontURL = Bundle.main.url(forResource:"Roboto-Regular",withExtension:"ttf",subdirectory:"Fonts") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL,.process,nil)
        }
        let settings = Settings(); _settings = StateObject(wrappedValue:settings); _history = StateObject(wrappedValue:History(enabled:settings.keepHistory))
        UNUserNotificationCenter.current().delegate = notifications
    }
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(settings).environmentObject(session).environmentObject(history)
                .onAppear { session.onFinish = { a, start, mode in history.append(a, start:start, mode:mode, enabled:settings.keepHistory) } }
                .onChange(of:phase) { _, new in if new == .background { session.stop(reason:"Tiskz se pausó al ir al fondo. Reconecta para continuar.") } }
        }
    }
}

import SwiftUI
import KKSoftiOSSDK
import FirebaseCrashlytics

struct GameTrackingTestView: View {
    // MARK: - Game Parameters
    @State private var gameUUID: String = "game_uuid_12345"
    @State private var characterID: String = "character_001"
    @State private var characterName: String = "PlayerOne"
    @State private var serverID: String = "1"
    @State private var serverName: String = "Server Alpha"

    // MARK: - Tracking Inputs
    @State private var level: String = "50"
    @State private var vipLevel: String = "5"
    @State private var onlineTime: String = "30"

    // MARK: - UI
    @State private var showToast: Bool = false
    @State private var toastText: String = ""
    @State private var showCrashAlert: Bool = false
    @State private var crashTypeToTrigger: CrashType? = nil
    
    private enum CrashType { case testCrash, nullPointer }
        
    let onClose: () -> Void
    let onLogPlayGame: (_ gameUUID: String, _ characterId: String, _ characterName: String, _ serverId: Int, _ serverName: String) -> Void
    let onLogTutorialCompletedS1: (_ gameUUID: String, _ characterId: String, _ characterName: String, _ serverId: Int, _ serverName: String) -> Void
    let onLogLevelUp: (_ level: Level, _ gameUUID: String, _ characterId: String, _ characterName: String, _ serverId: Int, _ serverName: String) -> Void
    let onLogVIPLevel: (_ level: VIPLevel, _ gameUUID: String, _ characterId: String, _ characterName: String, _ serverId: Int, _ serverName: String) -> Void
    let onLogOnlineTime: (_ time: OnlineTime, _ gameUUID: String, _ characterId: String, _ characterName: String, _ level: Level, _ serverId: Int, _ serverName: String) -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {

                // Header
                HStack {
                    Text("Game Tracking Test")
                        .font(.system(size: 30, weight: .bold))
                    Spacer()
                    Button(action: {
                        onClose()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: 32, height: 32)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
                
                // Game Parameters
                Group {
                    Text("Game Parameters")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.top, 6)

                    LabeledInput(title: "Game UUID", text: $gameUUID)
                    LabeledInput(title: "Character ID", text: $characterID)
                    LabeledInput(title: "Character Name", text: $characterName)
                    LabeledInput(title: "Server ID", text: $serverID)
                    LabeledInput(title: "Server Name", text: $serverName)
                }

                // Level / VIP / Online Time (like your screenshot near bottom)
                Group {
                    LabeledInput(title: "Level (10, 20, 30, 40, 50, 60, 70, 80, 90, 100)", text: $level, keyboard: .numberPad)
                    LabeledInput(title: "VIP Level (1-10)", text: $vipLevel, keyboard: .numberPad)
                    LabeledInput(title: "Online Time (minutes: 5, 10, 30, 60)", text: $onlineTime, keyboard: .numberPad)
                }

                // Tracking Functions
                Text("Tracking Functions")
                    .font(.system(size: 26, weight: .bold))
                    .padding(.top, 12)

                VStack(spacing: 14) {
                    SecondaryActionButton("LOG PLAY GAME") { log(.playGame) }
                    SecondaryActionButton("LOG TUTORIAL COMPLETED S1") { log(.tutorialS1) }
                    SecondaryActionButton("LOG LEVEL UP") { log(.levelUp) }
                    SecondaryActionButton("LOG VIP LEVEL") { log(.vipLevel) }
                    SecondaryActionButton("LOG ONLINE TIME") { log(.onlineTime) }
                }

                PrimaryActionButton("TEST ALL FUNCTIONS") {
                    toast("Testing all tracking functions…")
                    // Call all logs in sequence (replace with your SDK calls)
                    log(.playGame)
                    log(.tutorialS1)
                    log(.levelUp)
                    log(.vipLevel)
                    log(.onlineTime)
                }
                .padding(.top, 8)

                // Crash Testing
                Text("Crash Testing (WARNING: Will crash app!)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.red)
                    .padding(.top, 22)

                VStack(spacing: 14) {
                    // Non-fatal exception log
                    Button(action: {
                        // Simulate logging a non-fatal exception
                        let error = NSError(domain: "com.example.tracking", code: 999, userInfo: [NSLocalizedDescriptionKey: "Test non-fatal exception"])
                        debugPrint("[CrashTesting] Non-fatal exception: \(error)")
                        Crashlytics.crashlytics().record(error: error)
                        toast("Logged non-fatal exception")
                    }) {
                        Text("LOG NON-FATAL EXCEPTION")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(radius: 1, y: 1)
                    }
                    .buttonStyle(.plain)

                    // Trigger test crash
                    Button(action: {
                        crashTypeToTrigger = .testCrash
                        showCrashAlert = true
                    }) {
                        Text("TRIGGER TEST CRASH (WILL CRASH!)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(radius: 1, y: 1)
                    }
                    .buttonStyle(.plain)

                    // Trigger null pointer crash
                    Button(action: {
                        crashTypeToTrigger = .nullPointer
                        showCrashAlert = true
                    }) {
                        Text("TRIGGER NULLPOINTER CRASH (WILL CRASH!)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .shadow(radius: 1, y: 1)
                    }
                    .buttonStyle(.plain)
                }

            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .navigationTitle("Game Tracking Test")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) {
            if showToast {
                ToastView(text: toastText)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("Are you sure? This will crash the app.", isPresented: $showCrashAlert) {
            Button("Cancel", role: .cancel) {
                crashTypeToTrigger = nil
            }
            Button("Crash", role: .destructive) {
                switch crashTypeToTrigger {
                case .testCrash:
                    fatalError("Intentional test crash triggered from GameTrackingTestView")
                case .nullPointer:
                    let value: String! = nil
                    _ = value.count // Force unwrap crash
                case .none:
                    break
                }
            }
        } message: {
            Text("This action is for testing crash reporting only.")
        }
    }

    // MARK: - Actions

    enum LogAction {
        case playGame, tutorialS1, levelUp, vipLevel, onlineTime
    }

    private func log(_ action: LogAction) {
        let parsedServerID = Int(serverID) ?? 1

        switch action {
        case .playGame:
            onLogPlayGame(gameUUID, characterID, characterName, parsedServerID, serverName)
        case .tutorialS1:
            onLogTutorialCompletedS1(gameUUID, characterID, characterName, parsedServerID, serverName)
        case .levelUp:
            onLogLevelUp(Level(rawValue: Int(level) ?? 10) ?? .level10, gameUUID, characterID, characterName, parsedServerID, serverName)
        case .vipLevel:
            onLogVIPLevel(VIPLevel(rawValue: Int(vipLevel) ?? 1) ?? .level1, gameUUID, characterID, characterName, parsedServerID, serverName)
        case .onlineTime:
            onLogOnlineTime(OnlineTime(rawValue: Int(onlineTime) ?? 5) ?? .OL5minutes, gameUUID, characterID, characterName, Level(rawValue: Int(level) ?? 10) ?? .level10, parsedServerID, serverName)
        }
        toast("Logged: \(label(for: action))")
    }

    private func label(for action: LogAction) -> String {
        switch action {
        case .playGame: return "Play Game"
        case .tutorialS1: return "Tutorial S1"
        case .levelUp: return "Level Up"
        case .vipLevel: return "VIP Level"
        case .onlineTime: return "Online Time"
        }
    }

    private func toast(_ text: String) {
        if showToast { return }
        toastText = text
        withAnimation(.easeOut(duration: 0.2)) { showToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.2)) { showToast = false }
        }
    }
}

// MARK: - Building Blocks

private struct LabeledInput: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
                .font(.system(size: 16))

            TextField("", text: $text)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct SecondaryActionButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color(.systemGray4))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(radius: 1, y: 1)
        }
        .buttonStyle(.plain)
    }
}

private struct PrimaryActionButton: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color.green.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(radius: 2, y: 2)
        }
        .buttonStyle(.plain)
    }
}

private struct ToastView: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cube.transparent")
                .font(.system(size: 18, weight: .semibold))
            Text(text)
                .font(.system(size: 17, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 4, y: 2)
        .padding(.horizontal, 18)
    }
}

// MARK: - Preview

#Preview {
    GameTrackingTestView(
        onClose: {},
        onLogPlayGame: { gameUUID, characterId, characterName, serverId, serverName in },
        onLogTutorialCompletedS1: { gameUUID, characterId, characterName, serverId, serverName in },
        onLogLevelUp: { level, gameUUID, characterId, characterName, serverId, serverName in },
        onLogVIPLevel: { level, gameUUID, characterId, characterName, serverId, serverName in },
        onLogOnlineTime: { time, gameUUID, characterId, characterName, level, serverId, serverName in }
    )
}

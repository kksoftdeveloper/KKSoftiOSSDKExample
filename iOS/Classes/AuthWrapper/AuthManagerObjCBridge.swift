//
//  AuthManagerObjCBridge.swift
//  Unity-iPhone
//
//  Created by Admin on 8/5/25.
//

import Foundation
import KKSoftiOSSDK
import Combine
import SwiftUI
import UIKit

@objc public protocol AuthResultDelegate: AnyObject {
    func didLogout(data: Any?)
    func didAuthenticated(data: Any?)
    func didChangedGameServer(data: Any?)
    func didDeactivateAccount(data: Any?)
    func didRefreshedToken(data: Any?)
    func didGetLatestSession(data: Any?)
    func didLinkAccount(data: Any?)
    func didClose()
}

@MainActor
@objc public class AuthManagerObjCBridge: NSObject {
    
    @objc public weak var delegate: AuthResultDelegate?
    private weak var hostingController: UIHostingController<AnyView>?
    
    @objc private var packageName: String?
    @objc private var appVersionName: String?
    
    private let manager: AuthManager
    private var autoLinkTimer: Timer?
    private var autoLinkPopupInterval: Int = 60 // Default, or change as needed
    private var autoLinkRemainingSeconds: Int = 60
    private var lastGuestToken: String?
    private var isAutoLinkDialogShowing: Bool = false

    private var cancellables = Set<AnyCancellable>()
    
    @objc public override init() {
        debugPrint("Init AuthManagerObjCBridge")
        manager = AuthServiceProvider.Builder().build().authManager
        debugPrint("Init manager")
    }
    
    @MainActor @objc public func showLoginView() -> UIViewController {
        debugPrint("Show Login View")
        let view = WelcomeView(
            authManager: manager,
            packageName: packageName!,
            appVersionName: appVersionName!,
            serverId: 1,
            onSuccess: { data in
                let map = data.asDictionary()
                
                debugPrint("Client App: Login Success: \(map)")
                if data.gameUUID == nil {
                    self.showGameServerView(data: map)
                } else {
                    self.delegate?.didAuthenticated(data: map)
                    if data.loginReminderResponse?.isGuestUser == true {
                        self.startAutoLinkAccountLoop(
                            timeToRemindInSeconds: (map["loginAfterSeconds"] as? Int) ?? 60,
                            guestToken: data.accessToken) { result, error in };
                    }
                }
            },
            onRefreshedToken: { data in
                let map = data.asDictionary()
                
                debugPrint("Client App: Refreshed Token Success: \(map)")
                self.delegate?.didRefreshedToken(data: map)
            },
            onFailure: { errorMessage in
                debugPrint("Client App: Login failed: \(errorMessage)")
                self.delegate?.didAuthenticated(data: nil)
            },
            onClose: {
                debugPrint("Client App: Login Close")
                self.delegate?.didClose()
            }
        )
        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller
        return controller
    }
    
    @objc public func initSDKWithPackageName(
        _ packageName: String,
        appVersion: String,
        serverId: String,
        completion: @escaping (NSDictionary?, NSString?, NSError?) -> Void
    ) {
        self.packageName = packageName
        self.appVersionName = appVersion
        manager.initSDK(packageName: packageName, appVersion: appVersion, serverId: Int(serverId) ?? 1)
            .receive(on: DispatchQueue.main)
            .flatMap { [weak self] gameInfo -> AnyPublisher<AuthSessionResponse, Error> in
                guard let self = self else { return Empty().eraseToAnyPublisher() }
                let versionInfo = gameInfo.versionInfo
                
                if versionInfo.forceUpdate {
                    completion(nil, "forceUpdate", nil)
                    return Empty().eraseToAnyPublisher()
                }
                let session = self.manager.getAuthSesssion()
                return session
            }
            .sink(
                receiveCompletion: { completionStatus in
                    if case .failure(let error) = completionStatus {
                        completion(nil, nil, error as NSError)
                    }
                },
                receiveValue: { session in
                    self.delegate?.didAuthenticated(data: session.asDictionary())
                    if session.loginReminderResponse?.isGuestUser == true {
                        self.startAutoLinkAccountLoop(
                            timeToRemindInSeconds: (session.asDictionary()["loginAfterSeconds"] as? Int) ?? 60,
                            guestToken: session.accessToken) { result, error in };
                    }
                    
                    if !session.accessToken.isEmpty {
                        let dict = session.asDictionary()
                        completion(dict, nil, nil)
                    } else {
                        completion(nil, "wellcome", nil)
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    @MainActor @objc public func showForceUpdateView(appStoreId: String, from presentingVC: UIViewController) {
        let forceUpdateView = ForceUpdateView(appStoreId: appStoreId)
        let controller = UIHostingController(rootView: AnyView(forceUpdateView))
        controller.modalPresentationStyle = .overFullScreen
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        presentingVC.present(controller, animated: true, completion: nil)
    }
    
    @MainActor @objc private func showGameServerView(data: Any) {
        let gameServerView = GameServerView(
            authManager: self.manager,
            onUpdatedGameServer: { selectedGameServerId, gameUUID in
                self.delegate?.didAuthenticated(data: data)
            }
        )
        let controller = UIHostingController(rootView: AnyView(gameServerView))
        controller.modalPresentationStyle = .overCurrentContext // or .overFullScreen
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController?.present(controller, animated: true, completion: nil)
//        self.hostingController?.rootView = AnyView(gameServerView)
    }
    
    @MainActor @objc public func showGameServerViewWithCompletion(
        _ completion: @escaping (NSDictionary?, NSError?) -> Void
    ) -> UIViewController {
        debugPrint("Show Game Server View")
        let view = GameServerView(
            authManager: self.manager,
            onUpdatedGameServer: { selectedGameServerId, gameUUID in
                var mapData: [String: Any] = [String:Any]()
                mapData["selectedGameServerId"] = selectedGameServerId
                mapData["gameUID"] = gameUUID
                self.delegate?.didChangedGameServer(data: mapData as NSDictionary)
                completion(mapData as NSDictionary, nil)
                // dismiss the view
                self.hostingController?.dismiss(animated: true, completion: nil)
            }
        )
        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.modalPresentationStyle = .overCurrentContext
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller
        return controller
    }
    
    @objc public func refreshTokenWithCompletion(
        _ completion: @escaping (NSDictionary?, NSError?) -> Void
    ) {
        manager.refreshToken()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completionStatus in
                    if case .failure(let error) = completionStatus {
                        completion(nil, error as NSError)
                    }
                },
                receiveValue: { data in
                    // Optionally: Save to keychain here, or let ObjC call a save method.
                    self.delegate?.didRefreshedToken(data: data)
                    let dict = data.asDictionary()
                    completion(dict, nil)
                }
            )
            .store(in: &cancellables)
    }
    
    @objc public func getLatestSessionWithCompletion(
        _ completion: @escaping (NSDictionary?, NSError?) -> Void
    ) {
        manager.getAuthSesssion()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completionStatus in
                    if case .failure(let error) = completionStatus {
                        completion(nil, error as NSError)
                    }
                },
                receiveValue: { data in
                    self.delegate?.didGetLatestSession(data: data)
                    let dict = data.asDictionary()
                    completion(dict, nil)
                }
            )
            .store(in: &cancellables)
    }
    
    @MainActor @objc public func showLogoutWithCompletion(
        _ completion: @escaping (NSDictionary?, NSError?) -> Void
    ) -> UIViewController {
        debugPrint("Show Logout View")
        let view = LogoutConfirmView(
            onClose: {
                self.delegate?.didClose()
                completion(nil, nil)
                self.hostingController?.dismiss(animated: true, completion: nil)
            },
            onConfirm: {
                debugPrint("Logout API")
                self.manager.logout()
                    .receive(on: DispatchQueue.main)
                    .sink(
                        receiveCompletion: { completionStatus in
                            if case .failure(let error) = completionStatus {
                                completion(nil, error as NSError)
                            }
                            
                            self.hostingController?.dismiss(animated: true, completion: nil)
                        },
                        receiveValue: { data in
                            self.delegate?.didLogout(data: nil)
                            completion([:], nil)
                            self.hostingController?.dismiss(animated: true, completion: nil)
                        }
                    )
                    .store(in: &self.cancellables)
            }
        )
        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.modalPresentationStyle = .overFullScreen
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller
        return controller
    }
    
    @MainActor @objc public func showDeactivateAccountWithCompletion(
        _ completion: @escaping (NSDictionary?, NSError?) -> Void
    ) -> UIViewController {
        debugPrint("Show Deactivate Account View")
        let view = DeactivateAccountView(
            onClose: {
                self.delegate?.didClose()
                completion(nil, nil)
                self.hostingController?.dismiss(animated: true, completion: nil)
            },
            onSuccess: {
                self.delegate?.didDeactivateAccount(data: [:])
                completion([:], nil)
                self.hostingController?.dismiss(animated: true, completion: nil)
            },
            onFailure: {
                let nsError = NSError(
                    domain: "com.i.auth",
                    code: -1
                )
                completion(nil, nsError)
                self.hostingController?.dismiss(animated: true, completion: nil)
            },
            authManager: self.manager
        )
        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.modalPresentationStyle = .overCurrentContext
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller
        return controller
    }
    
     @objc public func startAutoLinkAccountLoop(timeToRemindInSeconds: Int = 60, guestToken: String,
                                                _ completion: @escaping (NSDictionary?, NSError?) -> Void) {
         stopAutoLinkAccountLoop()

         autoLinkPopupInterval = timeToRemindInSeconds
         autoLinkRemainingSeconds = autoLinkPopupInterval
         lastGuestToken = guestToken

         // Use selector-based Timer to avoid @Sendable closure capture
         let box = CompletionBox(completion: completion, guestToken: guestToken)
         let timer = Timer(
             timeInterval: 1.0,
             target: self,
             selector: #selector(handleAutoLinkTick(_:)),
             userInfo: box,
             repeats: true
         )
         RunLoop.main.add(timer, forMode: .common)
         autoLinkTimer = timer

    }
    
    // Helper to carry values without capturing them in a @Sendable context
       private final class CompletionBox: NSObject {
           let completion: (NSDictionary?, NSError?) -> Void
           let guestToken: String
           init(completion: @escaping (NSDictionary?, NSError?) -> Void, guestToken: String) {
               self.completion = completion
               self.guestToken = guestToken
           }
       }
    
    @objc private func handleAutoLinkTick(_ timer: Timer) {
            guard !isAutoLinkDialogShowing else { return }

            if autoLinkRemainingSeconds > 0 {
                autoLinkRemainingSeconds -= 1
                debugPrint("⏳ Link popup in \(autoLinkRemainingSeconds)s")
                return
            }

            debugPrint("🔔 Showing LinkAccountView now")
            isAutoLinkDialogShowing = true
            autoLinkRemainingSeconds = autoLinkPopupInterval

            let box = timer.userInfo as? CompletionBox
            let completion = box?.completion
            guard let guestToken = box?.guestToken ?? lastGuestToken else {
                completion?(nil, NSError(domain: "com.i.auth", code: -1))
                stopAutoLinkAccountLoop()
                return
            }

            // Present UI (we're on @MainActor)
            var controller: UIHostingController<AnyView>?

            let view = LinkAccountView(
                authManager: self.manager,
                guestToken: guestToken,
                onSuccess: { [weak self] data in
                    guard let self else { return }
                    self.delegate?.didLinkAccount(data: data)
                    completion?([:], nil)
                    self.isAutoLinkDialogShowing = false
                    controller?.dismiss(animated: true)
                    self.stopAutoLinkAccountLoop()
                },
                onFailure: { [weak self] _ in
                    guard let self else { return }
                    let nsError = NSError(domain: "com.i.auth", code: -1)
                    completion?(nil, nsError)
                    self.isAutoLinkDialogShowing = false
                    controller?.dismiss(animated: true)
                },
                onClose: { [weak self] in
                    guard let self else { return }
                    self.delegate?.didClose()
                    completion?(nil, nil)
                    self.isAutoLinkDialogShowing = false
                    controller?.dismiss(animated: true)
                }
            )

            controller = UIHostingController(rootView: AnyView(view))
            controller?.overrideUserInterfaceStyle = .light
            controller?.modalPresentationStyle = .overCurrentContext
            controller?.view.backgroundColor = UIColor(white: 0, alpha: 0.3)

            if let topVC = self.getRootViewController() {
                var visibleVC = topVC
                while let presented = visibleVC.presentedViewController {
                    visibleVC = presented
                }
                if let controller { visibleVC.present(controller, animated: true) }
            } else {
                debugPrint("❌ Could not find root view controller to present LinkAccountView!")
                // If presenting fails, allow another attempt later
                self.isAutoLinkDialogShowing = false
            }
        }

    
    @objc public func stopAutoLinkAccountLoop() {
        autoLinkTimer?.invalidate()
        autoLinkTimer = nil
    }
    
    @MainActor func getRootViewController() -> UIViewController? {
        // Try the key window's root view controller
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController
        } else {
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }
    
}

extension AuthSessionResponse {
    func asDictionary() -> NSDictionary {
        var dict = [String: Any]()
        dict["accessToken"] = self.accessToken
        dict["gameUID"] = self.gameUUID
        dict["serverId"] = self.serverId
        dict["refreshToken"] = self.refreshToken
        dict["isNewUser"] = self.isNewUser
        dict["isGuestUser"] = self.loginReminderResponse?.isGuestUser ?? false
        dict["loginAfterSeconds"] = self.loginReminderResponse?.loginAfterSeconds ?? 0
        return dict as NSDictionary
    }
}

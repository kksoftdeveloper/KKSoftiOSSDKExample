//
//  KKSoftPrxoy.swift
//  UnityFramework
//
//  Created by Admin on 8/7/25.
//

import Foundation
import SwiftUI
import UIKit
import Combine
import KKSoftiOSSDK

@MainActor
@objc public class KKSOFTProxy : NSObject {
    static let ResponseCodes : [ String : Int ] = [
        "INITIALIZE" : 1,
        "AUTH" : 2,
        "LOGOUT" : 3,
        "UPDATE_GAME_SERVER" : 4,
        "DELETE_ACCOUNT" : 5,
        "REFRESH_TOKEN" : 6,
        "GET_LATEST_SESSION" : 7,
        "USER_BLOCKED" : 8,
        "FORCE_UPDATE" : 9,
        "TOKEN_EXPIRED" : 10,
        "LINK_ACCOUNT": 11,
        "IAP" : 12,

    ]

    static let ResultCodes : [ String : Int ] = [
        "FAIL" : -1,
        "CANCEL" : 0,
        "SUCCESS" : 1
    ]

    func Callback ( jsonPairs : [ String : Any ] ) {
        NSLog ( "---- KKSOFT: proxy Callback" );

        do
        {
            let jsonData = try JSONSerialization.data (
                withJSONObject : jsonPairs,
                options : []
            )
            let finalJSON = String ( data : jsonData, encoding : .utf8 ) ?? ""

            print ( "Final JSON for callback: \( finalJSON )" )

            onCallback? ( finalJSON )

        } catch
        {
            print ( "Error serializing JSON: \( error )" )
        }
    }


    @MainActor @objc public static let shared = KKSOFTProxy()

    public typealias OnCallback = @convention(c) (UnsafePointer<CChar>?) -> Void
    private var onCallback: OnCallback?

    let authService = AuthServiceProvider.Builder()

    var authManager : AuthManager?

    // TrackingSDK manager
    var trackingManager: TrackingManager?

    weak var hostingController : UIHostingController<AnyView>?
    @objc public var presentingVC: UIViewController?

    // Link Account pops up automatically
    private var autoLinkTimer: Timer?
    private var autoLinkPopupInterval: Int = 60 // Default, or change as needed
    private var autoLinkRemainingSeconds: Int = 60
    private var lastGuestToken: String?
    private var isAutoLinkDialogShowing: Bool = false

    // ServerId
    private var serverId = 1

    public override init() {
        authManager = AuthServiceProvider.Builder().build().authManager
    }

    private var cancellables = Set<AnyCancellable>()

    @MainActor @objc public func Initialize (_ unityVC: UIViewController, _ onCallback : @escaping OnCallback )
    {
        NSLog ( "---- KKSOFT Proxy Initialize" )
#if Debug
        let bundleId = Bundle.main.bundleIdentifier
        NSLog ( "---- KKSOFT debug bundle-id = \(bundleId)")
#else
        let bundleId = Bundle.main.bundleIdentifier
        NSLog ( "---- KKSOFT release bundle-id = \(bundleId ?? "")")
#endif

        self.onCallback = onCallback
        self.presentingVC = unityVC

        // Initialize TrackingSDK
        initializeTrackingSDK()

        authManager?.initSDK(
            packageName: Bundle.main.bundleIdentifier ?? "com.kksoft.vn.ts3",
            appVersion: Bundle.main.infoDictionary? [ "CFBundleShortVersionString" ] as? String ?? "1.0.0",
            serverId: serverId
        )
        .receive(on: DispatchQueue.main)
        .flatMap { [weak self] gameInfo -> AnyPublisher<AuthSessionResponse, Error> in
            guard let self = self, let authManager = self.authManager else { return Empty().eraseToAnyPublisher() }
            let versionInfo = gameInfo.versionInfo

            NSLog ("---- KKSOFT Proxy Init before forceUpdate")
            if versionInfo.forceUpdate {
                NSLog ("---- KKSOFT Proxy Init forceUpdate")
                DispatchQueue.main.async {
                    self.showForceUpdateView()
                }
                return Empty().eraseToAnyPublisher()
            }
            NSLog ("---- KKSOFT Proxy Init after forceUpdate")
            return authManager.getAuthSesssion()
        }
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { completionStatus in
                NSLog ("---- KKSOFT Proxy Init completionStatus \(completionStatus)")
                if case .failure(let error) = completionStatus {
                    if (error is AuthErrorResponse && (error as? AuthErrorResponse)?.code == AuthErrorCodeResponse.Unauthorized) {
                        NSLog ("---- KKSOFT Proxy Init Unauthentication")
                        DispatchQueue.main.async {
                            self.Auth()
                        }
                    } else {
                        var jsonPairs : [ String : Any ]
                        jsonPairs = [ : ]
                        jsonPairs [ "ResponseCode" ] = KKSOFTProxy
                            .ResponseCodes [ "INITIALIZE" ]
                        jsonPairs [ "ResultCode" ] = KKSOFTProxy
                            .ResultCodes [ "FAIL" ]

                        if error is AuthErrorResponse {
                            jsonPairs [ "Code" ] = (
                                error as? AuthErrorResponse
                            )?.code.id
                            jsonPairs [ "Message" ] = (
                                error as? AuthErrorResponse
                            )?.message
                        }
                        self.Callback ( jsonPairs : jsonPairs )
                        self.showMenu(session: nil)
                    }
                }
            },
            receiveValue: {  session in
                NSLog ( "---- KKSOFT Proxy Init receiveValue \(session)" )
                if session.loginReminderResponse?.isGuestUser == true {
                    self.startAutoLinkAccountLoop(
                        timeToRemindInSeconds: (
                            session.asDictionary()["loginAfterSeconds"] as? Int
                        ) ?? 60,
                        guestToken: session.accessToken
                    ) { result, error in };
                }
                if !session.accessToken.isEmpty {
                    if session.userBlocked == true {
                        self.showUserBlockedView(data: session)

                    } else  if session.gameUUID == nil {
                        self.showGameServerView(data: session)
                    } else {
                        self.Callback(jsonPairs : session.toDictionnary(responseCode: "INITIALIZE"))
                        DispatchQueue.main.async {
                            self.showMenu(session: session)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.Auth()
                    }
                }
            }
        )
        .store(in: &cancellables)
    }

    @MainActor @objc public func Auth() {
        NSLog ( "---- KKSOFT Proxy Auth" )
        guard let authManager = authManager else {return}
        
        let view = WelcomeView (
            authManager : authManager,
            packageName : Bundle.main.bundleIdentifier ?? "com.kksoft.vn.ts3",
            appVersionName : Bundle.main.infoDictionary? [ "CFBundleShortVersionString" ] as? String ?? "1.0.0",
            serverId: serverId,
            onSuccess: { data in
                NSLog ( "---- KKSOFT Proxy Auth onSuccess" )
                // guard let self = self else { return }

                self.Callback(
                    jsonPairs: data.toDictionnary(responseCode: "AUTH")
                )
                if data.userBlocked == true {
                    self.showUserBlockedView(data: data)

                } else if data.gameUUID == nil {
                    self.showGameServerView(data: data)

                } else {
                    self.getRootViewController()?.dismiss(animated: true, completion: {
                        self.showMenu(session: data)
                    })
                }
            },
            onRefreshedToken: { [weak self] data in
                NSLog ( "---- KKSOFT Proxy Auth onSuccess" )
                guard let self = self else { return }
                self.Callback(
                    jsonPairs: data.toDictionnary(responseCode: "REFRESH_TOKEN")
                )
                self.hostingController?.dismiss(animated: true, completion: nil)
            },
            onFailure: { [weak self] authErrorResponse in
                NSLog ( "---- KKSOFT Proxy Auth onFailure" )
                guard let self = self else { return }
                var jsonPairs = [String : Any]()
                jsonPairs [ "ResponseCode" ] = KKSOFTProxy.ResponseCodes [ "AUTH" ]
                jsonPairs [ "ResultCode" ] = KKSOFTProxy.ResultCodes [ "FAIL" ]
                jsonPairs [ "Message" ] = authErrorResponse.message
                jsonPairs [ "Code" ] = authErrorResponse.code.id

                self.Callback ( jsonPairs : jsonPairs )

                //                self.hostingController?.dismiss(
                //                    animated: true,
                //                    completion: {
                //                        self.showMenu(
                //                            session: nil,
                //                            error: authErrorResponse.message
                //                        )
                //                    })
            },
            onClose: {
                NSLog ( "---- KKSOFT Proxy Auth onClose" )
                self.Callback ( jsonPairs : "AUTH".toDictionnary() )
                self.hostingController?.dismiss(animated: true, completion: {
                    self.showMenu(session: nil)
                })
            }
        )

        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller

        let nav = UINavigationController ( rootViewController : controller )
        nav.modalPresentationStyle = .overFullScreen

        //        presentingVC?.present ( nav, animated : true, completion : nil )

        self.getRootViewController()?.present(nav, animated: true, completion: nil)
    }

    @MainActor public func showLogout(session: AuthSessionResponse?) {
        debugPrint("Show Logout View")
        guard let authManager = authManager else {return}

        // Track screen view when logout screen opens
        trackScreen("Logout-Screen", parameters: [
            "user_id": session?.gameUUID ?? "unknown",
            "is_guest": authManager.isGuestUser()
        ])

        let view = LogoutConfirmView(
            onClose: {
                "LOGOUT".toDictionnary()
                self.hostingController?.dismiss(animated: true, completion: {
                    self.showMenu(session: session)
                })
            },
            onConfirm: {
                debugPrint("Logout API")
                authManager.logout()
                    .receive(on: DispatchQueue.main)
                    .sink(
                        receiveCompletion: {  completionStatus in

                            if case .failure(_) = completionStatus {
                                var jsonPairs : [ String : Any ]
                                jsonPairs = [ : ]
                                jsonPairs [ "ResponseCode" ] = KKSOFTProxy
                                    .ResponseCodes [ "LOGOUT" ]
                                jsonPairs [ "ResultCode" ] = KKSOFTProxy
                                    .ResultCodes [ "FAIL" ]

                                self.Callback ( jsonPairs : jsonPairs )
                                self.hostingController?
                                    .dismiss(
                                        animated: true,
                                        completion: {
                                            self.showMenu(
                                                session: session,
                                                error: "Log out failed."
                                            )
                                        })
                            }

                        },
                        receiveValue: {  data in

                            var jsonPairs : [ String : Any ]
                            jsonPairs = [ : ]
                            jsonPairs [ "ResponseCode" ] = KKSOFTProxy
                                .ResponseCodes [ "LOGOUT" ]
                            jsonPairs [ "ResultCode" ] = KKSOFTProxy
                                .ResultCodes [ "SUCCESS" ]
                            self.Callback (
                                jsonPairs : session?
                                    .toDictionnary(
                                        responseCode: "LOGOUT"
                                    ) ?? jsonPairs
                            )

                            self.hostingController?
                                .dismiss(animated: true, completion: {
                                    self.showMenu(session: nil)
                                })
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
        self.presentingVC?.present(controller, animated: false, completion: nil)
    }

    @MainActor public func showGameServerView(session: AuthSessionResponse?) {
        debugPrint("Show Game Server View")
        guard let authManager = authManager else {return}
        let view = GameServerView(
            authManager: authManager,
            isShownCloseButton: true,
            onClose: {
                let json = "UPDATE_GAME_SERVER".toDictionnary();
                self.Callback(jsonPairs: json)
                self.hostingController?.dismiss(animated: true, completion: {
                    self.showMenu(session: session)
                })
            },
            onUpdatedGameServer: { [weak self] selectedGameServerId, gameUUID in
                                guard let self = self else { return }
                //                let json = session?.copy(
                //                    gameUUID: gameUUID, serverId: selectedGameServerId
                //                ).toDictionnary(responseCode: "UPDATE_GAME_SERVER")
                //                self.Callback(jsonPairs: json!)
                //
                //                self.hostingController?.dismiss(animated: true, completion: {
                //                    self.showMenu(session: session)
                //                })
            }
        )
        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.modalPresentationStyle = .overFullScreen
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller
        self.presentingVC?.present(controller, animated: false, completion: nil)
    }

    @MainActor public func showPackageItems(session: AuthSessionResponse) {
        debugPrint("Show Game Server View")
        guard let authManager = authManager else {return}
        //        let view = PackageListView(
        //            viewModel: <#T##PackageListViewModel#>, onCloseClick: <#T##() -> Void#>)(
        //            authManager: self.authManager,
        //            isShownCloseButton: true,
        //            onClose: {
        //                let json = "UPDATE_GAME_SERVER".toDictionnary();
        //                self.Callback(jsonPairs: json)
        //                self.hostingController?.dismiss(animated: true, completion: {
        //                    self.showMenu(session: session)
        //                })
        //            },
        //            onUpdatedGameServer: { [weak self] selectedGameServerId, gameUUID in
        //                guard let self = self else { return }
        //                let json = session?.copy(
        //                    gameUUID: gameUUID, serverId: selectedGameServerId
        //                ).toDictionnary(responseCode: "UPDATE_GAME_SERVER")
        //                self.Callback(jsonPairs: json!)
        //
        //                self.hostingController?.dismiss(animated: true, completion: {
        //                    self.showMenu(session: session)
        //                })
        //            }
        //        )
        debugPrint("server-id = \(serverId)")
        debugPrint("game-id = \(authManager.getGameId() ?? 1)")
        debugPrint("is-guest-user = \(authManager.isGuestUser())")
        let view = PackageListView(
            onCloseClick: {
                self.Callback(jsonPairs: "IAP".toDictionnary())
                self.getRootViewController()?.dismiss(animated: true, completion: {
                    self.showMenu(session: session)
                })
            },
            packageName: Bundle.main.bundleIdentifier ?? "com.kksoft.vn.ts3",
            gameId: authManager.getGameId() ?? 1,
            deviceId: authManager.getDeviceID(),
            osVersion: "15.0",
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            phoneNumber: authManager.getPhoneNumber(),
            appVersion: Bundle.main.infoDictionary? [ "CFBundleShortVersionString" ] as? String ?? "1.0.0",
            serverId: serverId,
            gameUUID: "\(session.gameUUID ?? "")",
            isGuestUser: authManager.isGuestUser()
        )
        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.modalPresentationStyle = .overCurrentContext
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller
        self.presentingVC?.present(controller, animated: false, completion: nil)
    }

    @MainActor public func showDeactivateAccount(session: AuthSessionResponse?) {
        debugPrint("Show Deactivate Account View")
        guard let authManager = authManager else {return}
        let view = DeactivateAccountView(
            onClose: {
                self.Callback(jsonPairs: "DELETE_ACCOUNT".toDictionnary())
                self.hostingController?.dismiss(animated: true, completion: {
                    self.showMenu(session: session)
                })
            },
            onSuccess: {
                var jsonPairs : [ String : Any ]
                jsonPairs = [ : ]
                jsonPairs [ "ResponseCode" ] = KKSOFTProxy.ResponseCodes [ "DELETE_ACCOUNT" ]
                jsonPairs [ "ResultCode" ] = KKSOFTProxy.ResultCodes [ "SUCCESS" ]
                self.Callback(jsonPairs: jsonPairs)

                self.hostingController?.dismiss(animated: true, completion: {
                    self.showMenu(session: nil)
                })
            },
            onFailure: {
                var jsonPairs : [ String : Any ]
                jsonPairs = [ : ]
                jsonPairs [ "ResponseCode" ] = KKSOFTProxy.ResponseCodes [ "DELETE_ACCOUNT" ]
                jsonPairs [ "ResultCode" ] = KKSOFTProxy.ResultCodes [ "FAIL" ]
                self.Callback(jsonPairs: jsonPairs)

                self.hostingController?.dismiss(animated: true, completion: {
                    self.showMenu(session: session, error: "Delete account error")
                })
            },
            authManager: authManager
        )
        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.modalPresentationStyle = .overCurrentContext
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller
        self.presentingVC?.present(controller, animated: false, completion: nil)
    }

    @MainActor public func showLinkAccount(session: AuthSessionResponse?) {
        debugPrint("Show Link Account View")
        guard let authManager = authManager else {return}

        // 1) Safely unwrap the token
        guard let guestToken = session?.accessToken, !guestToken.isEmpty else {
            self.showMenu(session: session, error: "Missing guest token")
            return
        }

        // 2) Build the SwiftUI view (explicit type helps the compiler)
        let view: LinkAccountView = LinkAccountView(
            authManager: authManager,
            guestToken: guestToken,
            onSuccess: { _ in
                var jsonPairs: [String: Any] = [:]
                jsonPairs["ResponseCode"] = KKSOFTProxy.ResponseCodes["LINK_ACCOUNT"]
                jsonPairs["ResultCode"]   = KKSOFTProxy.ResultCodes["SUCCESS"]
                self.Callback(jsonPairs: jsonPairs)

                self.hostingController?.dismiss(animated: true, completion: {
                    self.showMenu(session: nil)
                })
            },
            onFailure: { _ in
                var jsonPairs: [String: Any] = [:]
                jsonPairs["ResponseCode"] = KKSOFTProxy.ResponseCodes["LINK_ACCOUNT"]
                jsonPairs["ResultCode"]   = KKSOFTProxy.ResultCodes["FAIL"]
                self.Callback(jsonPairs: jsonPairs)

                self.hostingController?.dismiss(animated: true, completion: {
                    self.showMenu(session: session, error: "link account error")
                })
            },
            onClose: {
                self.Callback(jsonPairs: "LINK_ACCOUNT".toDictionnary())
                if self.hostingController != nil {
                    self.hostingController?.dismiss(animated: true, completion: {
                        self.showMenu(session: session)
                    })
                } else {
                    self.presentingVC?.dismiss(animated: true, completion: {
                        self.showMenu(session: session)
                    })
                }
            }
        )

        // 3) Present it
        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.modalPresentationStyle = .overCurrentContext
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller
        self.presentingVC?.present(controller, animated: false, completion: nil)
    }

    public func refreshToken(session: AuthSessionResponse?) {
        guard let authManager = authManager else {return}
        authManager.refreshToken()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completionStatus in
                    guard let self = self else { return }
                    if case .failure(let error) = completionStatus {
                        var jsonPairs = [String : Any]()
                        jsonPairs [ "ResponseCode" ] = KKSOFTProxy.ResponseCodes [ "REFRESH_TOKEN" ]
                        jsonPairs [ "ResultCode" ] = KKSOFTProxy.ResultCodes [ "FAIL" ]

                        if error is AuthErrorResponse {
                            jsonPairs [ "Message" ] = (error as? AuthErrorResponse)?.message
                            jsonPairs [ "Code" ] = (error as? AuthErrorResponse)?.code.id
                        }
                        self.Callback(jsonPairs: jsonPairs)
                    }
                },
                receiveValue: { [weak self] data in
                    guard let self = self else { return }
                    let dict = data.toDictionnary(responseCode: "REFRESH_TOKEN")
                    self.Callback(jsonPairs: dict)
                }
            )
            .store(in: &cancellables)
    }

    @objc public func getLatestSession() {
        guard let authManager = authManager else {return}
        authManager.getAuthSesssion()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completionStatus in
                    guard let self = self else { return }
                    if case .failure(let error) = completionStatus {
                        var jsonPairs = [String : Any]()
                        jsonPairs [ "ResponseCode" ] = KKSOFTProxy.ResponseCodes [ "GET_LATEST_SESSION" ]
                        jsonPairs [ "ResultCode" ] = KKSOFTProxy.ResultCodes [ "FAIL" ]

                        if error is AuthErrorResponse {
                            jsonPairs [ "Message" ] = (error as? AuthErrorResponse)?.message
                            jsonPairs [ "Code" ] = (error as? AuthErrorResponse)?.code.id
                        }
                        self.Callback(jsonPairs: jsonPairs)
                    }
                },
                receiveValue: { [weak self] data in
                    guard let self = self else { return }
                    let dict = data.toDictionnary(responseCode: "GET_LATEST_SESSION")
                    self.Callback(jsonPairs: dict)
                }
            )
            .store(in: &cancellables)
    }

    @MainActor
    @objc public func startAutoLinkAccountLoop(timeToRemindInSeconds: Int = 60, guestToken: String,
                                               _ completion: @escaping (NSDictionary?, NSError?) -> Void) {
        guard authManager != nil else { return }
        stopAutoLinkAccountLoop()
        autoLinkPopupInterval = timeToRemindInSeconds
        autoLinkRemainingSeconds = autoLinkPopupInterval
        lastGuestToken = guestToken
        autoLinkTimer = Timer
            .scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    if self.isAutoLinkDialogShowing { return }
                    if self.autoLinkRemainingSeconds > 0 {
                        self.autoLinkRemainingSeconds -= 1
                        debugPrint("⏳ Link popup in \(self.autoLinkRemainingSeconds)s")
                    } else {
                        debugPrint("🔔 Showing LinkAccountView now")
                        self.isAutoLinkDialogShowing = true
                        guard let authManager = self.authManager else { return }
                        debugPrint("Show Link Account View")

                        var controller: UIHostingController<AnyView>? = nil
                        let view = LinkAccountView(
                            authManager: authManager,
                            guestToken: guestToken,
                            onSuccess: { data in
                                self.Callback(
                                    jsonPairs: data
                                        .toDictionnary(responseCode: "AUTH")
                                )
                                self.isAutoLinkDialogShowing = false
                                controller?
                                    .dismiss(animated: true, completion: nil)
                                self.stopAutoLinkAccountLoop()
                            },
                            onFailure: { [weak self] error in
                                guard let self = self else { return }
                                _ = NSError(
                                    domain: "com.i.auth",
                                    code: -1
                                )
                                self.isAutoLinkDialogShowing = false
                                controller?
                                    .dismiss(animated: true, completion: nil)
                                self.Callback(jsonPairs: error.toDictionary())
                            },
                            onClose: {
                                "AUTH".toDictionnary()
                                self.isAutoLinkDialogShowing = false
                                controller?
                                    .dismiss(animated: true, completion: nil)
                            }
                        )
                        controller = UIHostingController(
                            rootView: AnyView(view)
                        )
                        controller?.overrideUserInterfaceStyle = .light
                        controller?.modalPresentationStyle = .overCurrentContext // or .overFullScreen
                        controller?.view.backgroundColor = UIColor(
                            white: 0,
                            alpha: 0.3
                        )
                        if let topVC = self.getRootViewController() {
                            var visibleVC = topVC
                            while let presented = visibleVC.presentedViewController {
                                visibleVC = presented
                            }
                            visibleVC
                                .present(
                                    controller!,
                                    animated: true,
                                    completion: nil
                                )
                        } else {
                            print(
                                "❌ Could not find root view controller to present LinkAccountView!"
                            )
                        }
                        self.autoLinkRemainingSeconds = self.autoLinkPopupInterval
                    }
                }
            }
    }

    @objc public func stopAutoLinkAccountLoop() {
        autoLinkTimer?.invalidate()
        autoLinkTimer = nil
    }

    @MainActor private func showMenu(
        session: AuthSessionResponse?,
        error: String? = nil
    ) {
        // Get IDFV from tracking manager
        let idfv = trackingManager?.getIDFV()

        let menuView = MenuView(
            accessToken: session?.accessToken,
            refreshToken: session?.refreshToken,
            error: error,
            afIDFV: idfv,
            enableGameTracking: self.trackingManager != nil,
            onClickSignIn: {
                DispatchQueue.main.async {
                    self.getRootViewController()?
                        .dismiss(animated: true, completion: {
                            DispatchQueue.main.async {
                                self.Auth()
                            }
                        })
                }
            },
            onClickSignOut: {
                DispatchQueue.main.async {
                    self.hostingController?
                        .dismiss(animated: true, completion: {
                            self.showLogout(session: session)
                        })
                }
            },
            onClickItems: {
                DispatchQueue.main.async {
                    self.hostingController?
                        .dismiss(animated: true, completion: {
                            self.showPackageItems(session: session!)
                        })
                }
            },
            onClickGetGameServers: {
                DispatchQueue.main.async {
                    self.hostingController?
                        .dismiss(animated: true, completion: {
                            self.showGameServerView(session: session)
                        })
                }
            },
            onClickLatestSession: {
                self.getLatestSession()
            },
            onClickRefreshToken: {
                self.refreshToken(session: session)
            },
            onClickUserBlocked: {
                if let session = session {
                    self.showUserBlockedView(data: session)
                }
            },
            onClickTokenExpiration: {
                if session != nil {
                    self.showTokenExpiration(/*session: session*/)
                }
            },
            onClickDeleteAccount: {
                DispatchQueue.main.async {
                    self.hostingController?
                        .dismiss(animated: true, completion: {
                            self.showDeactivateAccount(session: session)
                        })
                }
            },
            onClickLinkAccount: {
                DispatchQueue.main.async {
                    self.hostingController?
                        .dismiss(animated: true, completion: {
                            self.showLinkAccount(session: session)
                        })
                }
            },
            onClickGameTracking: {
                DispatchQueue.main.async {
                    self.hostingController?
                        .dismiss(animated: true, completion: {
                            self.showGameTrackingView(session: session)
                        })

                }
            }
        )
        let controller = UIHostingController(rootView: AnyView(menuView))
        controller.modalPresentationStyle = .overFullScreen
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)

        self.hostingController = controller // ✅ store for later dismissal
        self.presentingVC?.present(controller, animated: true, completion: nil)
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

    @MainActor public func showUserBlockedView(data: AuthSessionResponse) {
        let view = UserBlockedView(
            phoneNumber: "+84398686854",
            fanpage: "https://www.facebook.com/profile.php?id=61574162151534",
            onClose: {
                NSLog ( "---- KKSOFT Proxy Auth User Blocked" )
                let ret = "USER_BLOCKED".toDictionnary()
                self.Callback ( jsonPairs : ret )

                self.getRootViewController()?.dismiss(animated: true, completion: {
                    self.showMenu(session: nil)}
                )
            }
        )
        let ret = data.toDictionnary(responseCode: "USER_BLOCKED")
        self.Callback ( jsonPairs : ret )

        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.modalPresentationStyle = .overFullScreen
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller
        self.presentingVC?.dismiss(animated: true, completion: {
            self.presentingVC?.present(controller, animated: false, completion: nil)
        })
    }

    @MainActor @objc public func showTokenExpiration(/*session: AuthSessionResponse*/) {
        let view = TokenExpirationView() {
            DispatchQueue.main.async {
                self.presentingVC?.dismiss(animated: true, completion: {
                    self.Auth()
                })
            }
        }
        //        let ret = session.toDictionnary(responseCode: "TOKEN_EXPIRED")
        //        self.Callback ( jsonPairs : ret )

        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.modalPresentationStyle = .overFullScreen
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller
        self.presentingVC?.dismiss(animated: true, completion: {
            self.presentingVC?.present(controller, animated: false, completion: nil)
        })
    }

    /*
    @MainActor @objc public func onRefreshedToken(refreshedToken: AuthSessionOutput) {
        let view = TokenExpirationView() {
            DispatchQueue.main.async {
                self.presentingVC?.dismiss(animated: true, completion: {
                    self.Auth()
                })
            }
        }
        //        let ret = session.toDictionnary(responseCode: "TOKEN_EXPIRED")
        //        self.Callback ( jsonPairs : ret )

        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.modalPresentationStyle = .overFullScreen
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller
        self.presentingVC?.dismiss(animated: true, completion: {
            self.presentingVC?.present(controller, animated: false, completion: nil)
        })
    }
     */

    @MainActor @objc public func showServerMaintaince() {
        let view = ServerMaintenanceView(
            phoneNumber: "+84398686854",
            fanpage: "https://www.facebook.com/profile.php?id=61574162151534"
        ) { _,_ in

        }
        //        let ret = session.toDictionnary(responseCode: "TOKEN_EXPIRED")
        //        self.Callback ( jsonPairs : ret )

        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.modalPresentationStyle = .overFullScreen
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller
        self.presentingVC?.dismiss(animated: true, completion: {
            self.presentingVC?.present(controller, animated: false, completion: nil)
        })
    }

    @MainActor private func showGameServerView(data: AuthSessionResponse) {
        guard let authManager = authManager else {return}
        let view = GameServerView (
            authManager : authManager,
            onUpdatedGameServer: { gameServerId, gameUUID in
                //                NSLog ( "---- KKSOFT Proxy UPDATE_GAME_SERVER " )
                //                let ret = data.copy(gameUUID: gameUUID,serverId: gameServerId)
                //                    .toDictionnary(responseCode: "UPDATE_GAME_SERVER")
                //                self.Callback ( jsonPairs : ret )
                //                self.hostingController?.dismiss(animated: true, completion: { self.showMenu(session: data)})
            }
        )
        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.modalPresentationStyle = .overFullScreen
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.hostingController = controller
        self.presentingVC?.dismiss(animated: true, completion: {
            self.presentingVC?.present(controller, animated: false, completion: nil)
        })
    }

    @MainActor private func showForceUpdateView() {
        var jsonPairs : [ String : Any ]
        jsonPairs = [ : ]
        jsonPairs [ "ResponseCode" ] = KKSOFTProxy.ResponseCodes [ "FORCE_UPDATE" ]
        jsonPairs [ "ResultCode" ] = KKSOFTProxy.ResultCodes [ "SUCCESS" ]
        self.Callback(jsonPairs: jsonPairs)

        let forceUpdateView = ForceUpdateView(appStoreId: "123")
        let controller = UIHostingController(rootView: AnyView(forceUpdateView))
        controller.modalPresentationStyle = .overFullScreen
        controller.overrideUserInterfaceStyle = .light
        controller.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        self.presentingVC?.present(controller, animated: true, completion: nil)
    }

    @MainActor private func showGameTrackingView(session: AuthSessionResponse?) {
        let view = GameTrackingTestView {
            self.hostingController?.dismiss(animated: true, completion: {
                self.showMenu(session: session)
            })
        } onLogPlayGame: { gameUUID, characterId, characterName, serverId, serverName in
            IngameEventTracking.trackPlayGame(gameUUID: gameUUID, characterId: characterId, characterName: characterName, serverId: serverId, serverName: serverName)
        } onLogTutorialCompletedS1: { gameUUID, characterId, characterName, serverId, serverName in
            IngameEventTracking.trackTutorialCompletedS1(gameUUID: gameUUID, characterId: characterId, characterName: characterName, serverId: serverId, serverName: serverName)
        } onLogLevelUp: { level, gameUUID, characterId, characterName, serverId, serverName in
            IngameEventTracking.trackLevelUp(level: level, gameUUID: gameUUID, characterId: characterId, characterName: characterName, serverId: serverId, serverName: serverName)
        } onLogVIPLevel: { level, gameUUID, characterId, characterName, serverId, serverName in
            IngameEventTracking.trackVIPLevel(level: level, gameUUID: gameUUID, characterId: characterId, characterName: characterName, serverId: serverId, serverName: serverName)
        } onLogOnlineTime: { time, gameUUID, characterId, characterName, level, serverId, serverName in
            IngameEventTracking.trackOnlineTime(time: time, gameUUID: gameUUID, characterId: characterId, characterName: characterName, level: level, serverId: serverId, serverName: serverName)
        }

        let controller = UIHostingController(rootView: AnyView(view))
        controller.overrideUserInterfaceStyle = .light
        controller.modalPresentationStyle = .overFullScreen
        self.hostingController = controller
        self.presentingVC?.dismiss(animated: true, completion: {
            self.presentingVC?.present(controller, animated: false, completion: nil)
        })
    }

    // MARK: - TrackingSDK Initialization

    @MainActor private func initializeTrackingSDK() {
        NSLog("---- KKSOFT Proxy Initialize TrackingSDK")

        // Initialize TrackingSDK with AppFlyers
        let builder = TrackingServiceProvider.Builder()
//            .enableAppFlyers(
//                appID: Bundle.main.infoDictionary?[ "AppFlyersId" ] as? String ?? ""
//                devKey: Bundle.main.infoDictionary?[ "AppFlyersDevKey" ] as? String ?? ""
//            )
//            .enableAdjust(
//                appID: Bundle.main.infoDictionary?[ "AdjustId" ] as? String ?? "",
//                appToken: Bundle.main.infoDictionary?[ "AdjustToken" ] as? String ?? ""
//            )
//            .enableTikTok(
//                accessToken: Bundle.main.infoDictionary?[ "TiktokAccessToken" ] as? String ?? "",
//                appID: Bundle.main.bundleIdentifier ?? "com.kksoft.vn.ts3",
//                tiktokAppID: Bundle.main.infoDictionary?[ "TiktokAppID" ] as? String ?? ""
//            )
//            .enableMeta(
//                appID: Bundle.main.infoDictionary?[ "FacebookAppID" ] as? String ?? "",
//                clientToken: Bundle.main.infoDictionary?[ "FacebookClientToken" ] as? String ?? ""
//            )

        let env = Environment.production
//        let env = (Bundle.main.infoDictionary?[ "APP_ENV" ] as? String)?.lowercased() == "staging" ? Environment.staging : Environment.production

        if Bundle.main.url(forResource: "GoogleService-Info-\(env == .production ? "Production" : "Staging")", withExtension: "plist") != nil {
            let firebaseAppID = Bundle.main.object(forInfoDictionaryKey: "FirebaseAppID") as? String
            _ = builder.enableFirebaseAnalytics(appID: firebaseAppID ?? "")
            _ = builder.enableFirebaseCrashlytics()
            NSLog("---- KKSOFT Proxy Firebase Analytics Enabled \(firebaseAppID ?? "")")
        } else if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            let firebaseAppID = Bundle.main.object(forInfoDictionaryKey: "FirebaseAppID") as? String
            _ = builder.enableFirebaseAnalytics(appID: firebaseAppID ?? "")
            _ = builder.enableFirebaseCrashlytics()
            NSLog("---- KKSOFT Proxy Firebase Analytics Enabled \(firebaseAppID ?? "")")
        } else {
            NSLog("---- KKSOFT Proxy Firebase Analytics skipped (GoogleService-Info.plist not found)")
        }

        let trackingService = builder.build()

        self.trackingManager = trackingService.trackingManager
        
//        if let manager = trackingManager {
//            AuthTrackingConfigurator.configure(with: manager)
//            PaymentTrackingConfigurator.configure(with: manager)
//            IngameEventTrackingConfigurator.configure(with: manager)
//        }
        NSLog("---- KKSOFT Proxy TrackingSDK Initialized")
    }

    // MARK: - TrackingSDK Screen Tracking

    /// Track a screen view event
    /// - Parameters:
    ///   - screenName: Name of the screen being viewed (e.g., "Logout-Screen", "Login-Screen")
    ///   - parameters: Optional dictionary of screen-specific parameters
    @MainActor @objc public func trackScreen(_ screenName: String, parameters: [String: Any]? = nil) {
        guard let manager = trackingManager else {
            NSLog("---- KKSOFT Proxy trackScreen: TrackingManager not initialized")
            return
        }

        NSLog("---- KKSOFT Proxy trackScreen: \(screenName)")
        manager.trackScreen(screenName, parameters: parameters)
    }

    /// Track a screen view event with JSON string parameters (for Unity/C interop)
    /// - Parameters:
    ///   - screenName: Name of the screen being viewed
    ///   - jsonParameters: Optional JSON string containing parameters (e.g., "{\"user_type\":\"premium\"}")
    @MainActor @objc public func trackScreen(_ screenName: String, jsonParameters: String?) {
        var parameters: [String: Any]? = nil

        if let jsonString = jsonParameters, !jsonString.isEmpty {
            if let jsonData = jsonString.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                parameters = jsonObject
            } else {
                NSLog("---- KKSOFT Proxy trackScreen: Failed to parse JSON parameters: \(jsonString)")
            }
        }

        trackScreen(screenName, parameters: parameters)
    }
}

extension String {
    @MainActor func toDictionnary() -> [String: Any] {
        var jsonPairs : [ String : Any ]
        jsonPairs = [ : ]
        jsonPairs [ "ResponseCode" ] = KKSOFTProxy.ResponseCodes [ self ]
        jsonPairs [ "ResultCode" ] = KKSOFTProxy.ResultCodes [ "CANCEL" ]
        return jsonPairs
    }
}

extension AuthErrorResponse {
    @MainActor func toDictionary() -> [String: Any] {
        var jsonPairs = [String : Any]()
        jsonPairs [ "ResponseCode" ] = KKSOFTProxy.ResponseCodes [ "AUTH" ]
        jsonPairs [ "ResultCode" ] = KKSOFTProxy.ResultCodes [ "FAIL" ]
        jsonPairs [ "Code" ] = self.code.id
        jsonPairs [ "Message" ] = self.message
        return jsonPairs
    }
}

extension AuthSessionResponse {
    @MainActor func toDictionnary(responseCode: String) -> [String: Any] {
        var jsonPairs : [ String : Any ]
        jsonPairs = [ : ]
        jsonPairs [ "ResponseCode" ] = KKSOFTProxy
            .ResponseCodes [ responseCode ]
        jsonPairs [ "ResultCode" ] = KKSOFTProxy.ResultCodes [ "SUCCESS" ]
        jsonPairs [ "GameUUID" ] =  self.gameUUID
        jsonPairs [ "ServerID" ] =  self.serverId
        jsonPairs [ "AccessToken" ] =  self.accessToken
        jsonPairs [ "RefreshToken" ] =  self.refreshToken
        jsonPairs [ "UserBlocked" ] =  self.userBlocked
        jsonPairs [ "GameBlocked" ] =  self.gameBlocked
        jsonPairs [ "ServerBlocked" ] =  self.serverBlocked
        return jsonPairs
    }
}


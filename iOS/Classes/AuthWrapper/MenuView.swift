//
//  MenuView.swift
//  UnityFramework
//
//  Created by Admin on 8/7/25.
//

import Foundation
import SwiftUI
import KKSoftiOSSDK

struct MenuView : View {
    var accessToken: String?
    var refreshToken: String?
    var error: String?
    var afIDFV: String?
    var enableGameTracking: Bool
    
    let onClickSignIn: () -> Void
    let onClickSignOut: () -> Void
    let onClickItems: () -> Void
    let onClickGetGameServers: () -> Void
    let onClickLatestSession: () -> Void
    let onClickRefreshToken: () -> Void
    let onClickUserBlocked: () -> Void
    let onClickTokenExpiration: () -> Void
    let onClickDeleteAccount: () -> Void
    let onClickLinkAccount: () -> Void
    let onClickGameTracking: () -> Void
        
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 20) {
                VStack (spacing: 16) {
                    button(action: {
                        debugPrint("Click Sign Up & Login")
                        onClickSignIn()
                    },
                           label: "Sign Up & Login",
                           systemIcon: "person.fill.badge.plus",
                           isEnabled: accessToken == nil || refreshToken == nil
                    )
                    
                    button(action: {
                        onClickLinkAccount()
                    },
                           label: "Link Account",
                           systemIcon: "arrow.trianglehead.2.clockwise.rotate.90",
                           isEnabled: (accessToken != nil || refreshToken != nil)
                    )
                    button(action: {
                        onClickGetGameServers()
                    },
                           label: "Get Game Server",
                           systemIcon: "arrow.trianglehead.2.clockwise.rotate.90",
                           isEnabled: accessToken != nil || refreshToken != nil
                    )
                    
                    button(action: {
                        onClickUserBlocked()
                    },
                           label: "User Blocked",
                           systemIcon: "arrow.trianglehead.2.clockwise.rotate.90",
                           isEnabled: refreshToken != nil || accessToken != nil
                    )
                    
    //                button(action: {
    //                    onClickRefreshToken()
    //                },
    //                       label: "Refresh Token",
    //                       systemIcon: "arrow.trianglehead.2.clockwise.rotate.90",
    //                       isEnabled: refreshToken != nil || accessToken != nil
    //                )
                    
    //                button(action: {
    //                    onClickLatestSession()
    //                },
    //                       label: "Get Latest Session",
    //                       systemIcon: "arrow.trianglehead.2.clockwise.rotate.90",
    //                       isEnabled: refreshToken != nil || accessToken != nil
    //                )
                    
                    //                button(action:{
                    //
                    //                },
                    //                       label: "Buy Items",
                    //                       systemIcon: "rectangle.portrait.and.trolley.fill",
                    //                       isEnabled: viewModel.displayInfo != nil
                    //                )
                    
                    button(action:{
                        onClickTokenExpiration()
                        
                    },
                           label: "Token Expiration",
                           systemIcon: "rectangle.portrait.and.arrow.right",
                           isEnabled: refreshToken != nil || accessToken != nil
                    )
                    
                    button(action:{
                        onClickSignOut()
                        
                    },
                           label: "Logout",
                           systemIcon: "rectangle.portrait.and.arrow.right",
                           isEnabled: refreshToken != nil || accessToken != nil
                    )
                    
                    button(action: {
                        onClickItems()
                    },
                           label: "Buy Items",
                           systemIcon: "rectangle.portrait.and.arrow.close",
                           isEnabled: refreshToken != nil || accessToken != nil
                    )
                    
                    button(action: {
                        onClickDeleteAccount()
                    },
                           label: "Delete Account",
                           systemIcon: "rectangle.portrait.and.arrow.close",
                           isEnabled: refreshToken != nil || accessToken != nil
                    )
                    
                    button(action:{
                        onClickGameTracking()
                    },
                           label: "Game Tracking",
                           systemIcon: "chart.line.uptrend.xyaxis",
                           isEnabled: enableGameTracking && (refreshToken != nil || accessToken != nil)
                    )
                }
                
                if let error = error {
                    VStack (alignment: .leading, spacing: 8)  {
                        Text("Error:")
                            .fontWeight(.semibold)
                            .foregroundColor(Color.init(uiColor: .darkGray))
                        
                        Text("\(error)")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(.gray.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                            .multilineTextAlignment(.leading)
                        
                    }
                    .padding()
                    .background(.white)
                    .cornerRadius(8)
                }
                if let token = accessToken {
                    VStack (alignment: .leading, spacing: 8)  {
                        Text("Access Token")
                            .fontWeight(.semibold)
                            .foregroundColor(Color.init(uiColor: .darkGray))
                        
                        Text(token)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(.gray.opacity(0.2))
                        //                        .fontWeight(.semibold)
                            .foregroundColor(.black)
                            .cornerRadius(8)
                            .multilineTextAlignment(.leading)
                        
                    }
                    .padding()
                    .background(.white)
                    .cornerRadius(8)
                }
                
                if let idfv = afIDFV {
                    VStack (alignment: .leading, spacing: 8)  {
                        HStack {
                            Text("AppsFlyer IDFV")
                                .fontWeight(.semibold)
                                .foregroundColor(Color.init(uiColor: .darkGray))
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = idfv
                                debugPrint("✅ IDFV copied to clipboard: \(idfv)")
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 14))
                                    Text("Copy")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                            }
                        }
                        
    //                    Text(idfv)
    //                        .frame(maxWidth: .infinity, alignment: .leading)
    //                        .padding(8)
    //                        .background(.gray.opacity(0.2))
    //                        .foregroundColor(.black)
    //                        .cornerRadius(8)
    //                        .multilineTextAlignment(.leading)
    //                        .font(.system(.body, design: .monospaced))
    //
    //                    Text("💡 Copy this IDFV and add it to AppsFlyer dashboard for testing")
    //                        .font(.caption)
    //                        .foregroundColor(.blue)
    //                        .padding(.top, 4)
                        
                    }
                    .padding()
                    .background(.white)
                    .cornerRadius(8)
                }
                
    //            if refreshToken == refreshToken {
    //                VStack (alignment: .leading, spacing: 8)  {
    //                    Text("Refresh Token")
    //                        .fontWeight(.semibold)
    //                        .foregroundColor(Color.init(uiColor: .darkGray))
    //
    //                    Text("\(refreshToken ?? "")")
    //                        .frame(maxWidth: .infinity, alignment: .leading)
    //                        .padding(8)
    //                        .background(.gray.opacity(0.2))
    //                    //                        .font(.semibold)
    //                        .foregroundColor(.black)
    //                        .cornerRadius(8)
    //                        .multilineTextAlignment(.leading)
    //
    //                }
    //                .padding()
    //                .background(.white)
    //                .cornerRadius(8)
    //
    //            }
                
            }
            .padding()
            .background(.gray.opacity(0.1))
        }
    }
    
    private func button(
        action: @escaping @MainActor () -> Void,
        label: String,
        systemIcon: String = "",
        isEnabled: Bool = true
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                if !systemIcon.isEmpty {
                    Image(systemName: systemIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
                
                Text(label)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isEnabled ? Color.primaryText : Color.gray)
            .padding()
            .frame(maxWidth: .infinity)
            .background(isEnabled ? Color.buttonBackground : Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
        .padding(.horizontal, 8)
        .disabled(!isEnabled)
    }
}

extension Color {
    static var primaryText: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? .black :  .white
        })
    }
    
    static var buttonBackground: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? .white : .black
        })
    }
}

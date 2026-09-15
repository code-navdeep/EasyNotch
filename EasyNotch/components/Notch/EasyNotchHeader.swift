//
//  EasyNotchHeader.swift
//  EasyNotch
//

import Defaults
import SwiftUI

struct EasyNotchHeader: View {
    @EnvironmentObject var vm: EasyNotchViewModel
    @ObservedObject var coordinator = EasyNotchViewCoordinator.shared
    var body: some View {
        HStack(spacing: 0) {
            HStack {
                EmptyView()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)

            if vm.notchState == .open {
                Rectangle()
                    .fill(NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top ?? 0 > 0 ? .black : .clear)
                    .frame(width: vm.closedNotchSize.width)
                    .mask {
                        NotchShape()
                    }
            }

            HStack(spacing: 4) {
                if vm.notchState == .open {
                    if Defaults[.enableLyrics] {
                        Button(action: {
                            withAnimation(.smooth) {
                                coordinator.currentView = coordinator.currentView == .lyrics ? .home : .lyrics
                            }
                        }) {
                            Capsule()
                                .fill(.black)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Image(systemName: "quote.bubble")
                                        .foregroundColor(coordinator.currentView == .lyrics ? .effectiveAccent : .white)
                                        .padding()
                                        .imageScale(.medium)
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    if Defaults[.settingsIconInNotch] {
                        Button(action: {
                            DispatchQueue.main.async {
                                SettingsWindowController.shared.showWindow()
                            }
                        }) {
                            Capsule()
                                .fill(.black)
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Image(systemName: "gear")
                                        .foregroundColor(.white)
                                        .padding()
                                        .imageScale(.medium)
                                }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
    }
}

#Preview {
    EasyNotchHeader().environmentObject(EasyNotchViewModel())
}

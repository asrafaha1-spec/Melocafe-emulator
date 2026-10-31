//
//  EmulationView.swift
//  MeloCafe
//
//  Created by Stossy11 on 9/4/2026.
//

import SwiftUI
import Melo_Controller

struct EmulationView: View {
    let cemuView: MetalView
    let cemuPadView: MetalView
    @StateObject private var controllerManager = ControllerManager.shared
    @StateObject private var controllerHandler = VirtualControllerHandler()
    @AppStorage("showSwapButton") private var showSwapButton = true
    @AppStorage("screenLayout") private var screenLayout = ScreenLayout.initialValue
    @State private var swapped = false
    @State private var showingEmulatedDevices = false
    @AppStorage("showMenuButton") private var showMenuButton = true
    @State private var confirmingQuit = false
    @ObservedObject private var configManager = ConfigManager.shared
    @ObservedObject private var air = Air.shared
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    private var visibleScreens: [Bool] {
        if air.connected { return [false] }
        if screenLayout.showsBothScreens { return swapped ? [false, true] : [true, false] }
        return [!swapped]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geometry in
                let portrait = geometry.size.height >= geometry.size.width
                let phonePortrait =
                    UIDevice.current.userInterfaceIdiom == .phone && portrait

                if phonePortrait {
                    screensSizeLayout(in: geometry.size)
                } else {
                    ZStack {
                        if screenLayout == .smallGamePadTopRight && !air.connected {
                            let padWidth = geometry.size.width * 0.25
                            let padHeight = min(
                                padWidth * 9 / 16,
                                geometry.size.height
                            )

                            HStack(alignment: .top, spacing: 0) {
                                MetalViewContainer(metalView: cemuView)
                                    .frame(
                                        width: geometry.size.width - padWidth,
                                        height: geometry.size.height
                                    )

                                MetalViewContainer(metalView: cemuPadView)
                                    .frame(width: padWidth, height: padHeight)
                            }
                        } else if portrait {
                            VStack(spacing: 0) { screens }
                        } else {
                            HStack(spacing: 0) { screens }
                        }
                        
                        Spacer()
                            .allowsHitTesting(false)
                            .frame(minWidth: 0, minHeight: 0)
                    }
                }
            }
            .ignoresSafeArea(
                .all,
                edges: verticalSizeClass == .regular ? .horizontal : .all
            )
            
            if controllerManager.hasVirtual() {
                ControllerView(
                    controller: controllerHandler,
                    isEditing: false
                )
            }

        }
        .overlay(alignment: .topLeading) {
            if showSwapButton && screenLayout == .singleScreen && !air.connected {
                Button {
                    swapped.toggle()
                } label: {
                    ButtonView(controller: controllerHandler, disabled: true, button: .swap, opacity: 0.8)
                }
                .accessibilityLabel("Swap TV and GamePad") // i'm not sure who would need this because you would need to be able to see the screen itself but might as well -stossy11
                .padding(10)
            }
        }
        .overlay(alignment: .top) {
            if showMenuButton && !(UIDevice.current.userInterfaceIdiom == .phone && verticalSizeClass == .regular) {
                menuButton
                    .padding(10)
            }
        }
        .statusBarHidden(true)
        .overlay(alignment: .topTrailing) {
            if configManager.emulateSkylanderPortal.wrappedValue ||
                configManager.emulateInfinityBase.wrappedValue ||
                configManager.emulateDimensionsToypad.wrappedValue {
                Button {
                    showingEmulatedDevices = true
                } label: {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.black.opacity(0.6), in: Circle())
                }
                .accessibilityLabel("Emulated Devices")
                .sheet(isPresented: $showingEmulatedDevices) {
                    EmulatedDevicesView()
                }
                .padding(10)
            }
        }
        .confirmationDialog("Quit Game?", isPresented: $confirmingQuit, titleVisibility: .visible) {
            Button("Quit MeloCafe", role: .destructive) { quitGame() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This shuts the game down and closes the app. Unsaved progress is lost.")
        }
        .onAppear {
            updateVisibleOutputs()
            Air.play(AnyView(MetalViewContainer(metalView: cemuView)))
        }
        .onChange(of: swapped) { _ in updateVisibleOutputs() }
        .onChange(of: screenLayout) { _ in updateVisibleOutputs() }
        .onChange(of: air.connected) { _ in updateVisibleOutputs() }
        .onDisappear {
            Air.stop()
            CemuUIKit_SetVisibleOutputs(false, false)
        }
    }
    
    private func screensSizeLayout(in size: CGSize) -> some View {
        let screenHeight = size.width * 9.0 / 16.0

        return VStack(spacing: 0) {
            ForEach(visibleScreens, id: \.self) { main in
                MetalViewContainer(
                    metalView: main ? cemuView : cemuPadView
                )
                .frame(width: size.width, height: screenHeight)
            }

            if showMenuButton {
                HStack {
                    Spacer()
                    menuButton
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
            }

            if controllerManager.hasVirtual() {
                ControllerView(
                    controller: controllerHandler,
                    isEditing: false
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(
            width: size.width,
            height: size.height,
            alignment: .top
        )
    }
    
    private var screens: some View {
        ForEach(visibleScreens, id: \.self) { main in
            MetalViewContainer(metalView: main ? cemuView : cemuPadView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private var emulatedDevicesEnabled: Bool {
        configManager.emulateSkylanderPortal.wrappedValue ||
            configManager.emulateInfinityBase.wrappedValue ||
            configManager.emulateDimensionsToypad.wrappedValue
    }

    /// Always-visible menu button. Styled like the other overlay buttons on this screen.
    private var menuButton: some View {
        Menu {
            if screenLayout == .singleScreen && !air.connected {
                Button {
                    swapped.toggle()
                } label: {
                    Label("Swap TV and GamePad", systemImage: "rectangle.2.swap")
                }
            }

            if emulatedDevicesEnabled {
                Button {
                    showingEmulatedDevices = true
                } label: {
                    Label("Emulated Devices", systemImage: "externaldrive.connected.to.line.below")
                }
            }

            Button(role: .destructive) {
                confirmingQuit = true
            } label: {
                Label("Quit Game", systemImage: "power")
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.6), in: Circle())
        }
        .accessibilityLabel("Menu")
    }

    /// There is no way to stop one title and start another (the core's shutdown tears the whole system down), so
    /// quitting means shutting the core down cleanly and then closing the app.
    private func quitGame() {
        ControllerManager.shared.isRunning = false
        ControllerManager.shared.detachAllFromCore()

        // The core's shutdown can take a while, so it runs off the main thread (like CemuRun does).
        Thread.detachNewThread {
            CemuShutdown()
            DispatchQueue.main.async { exit(0) }
        }

        // Never leave the player stuck on a shutdown that hangs.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { exit(0) }
    }

    private func updateVisibleOutputs() {
        let both = air.connected || screenLayout.showsBothScreens
        
        CemuUIKit_SetVisibleOutputs(both || !swapped, both || swapped)
        
        if !both && !swapped { cemuPadView.cancelActiveTouches() }
    }
}

extension VirtualControllerButton {
    static var swap = Self("swap", systemName: "rectangle.2.swap", small: true)
}

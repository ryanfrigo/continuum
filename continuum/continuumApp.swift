//
//  continuumApp.swift
//  continuum
//
//  Created by Ryan Frigo on 10/6/25.
//

import SwiftUI
import SwiftData
#if DEBUG
import Combine
#endif
#if canImport(Inject)
import Inject
#endif

#if DEBUG
// Fallback injection support when the Inject SPM package isn't added.
private struct DevInjectionModifier: ViewModifier {
    @State private var injectionCounter = 0
    private let injectionPublisher = NotificationCenter.default.publisher(for: Notification.Name("INJECTION_BUNDLE_NOTIFICATION"))

    func body(content: Content) -> some View {
        content
            .id(injectionCounter)
            .onReceive(injectionPublisher) { _ in
                injectionCounter += 1
            }
    }
}

extension View {
    func enableDevInjection() -> some View {
        self.modifier(DevInjectionModifier())
    }
}
#endif

@main
struct continuumApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .fontDesign(.monospaced)
            #if DEBUG
                #if canImport(Inject)
                .enableInjection()
                #else
                .enableDevInjection()
                #endif
            #endif
        }
        .modelContainer(for: Habit.self)
    }
}

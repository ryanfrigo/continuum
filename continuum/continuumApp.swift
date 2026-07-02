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

    /// SwiftData container with iCloud (CloudKit) sync.
    /// Falls back to a local-only store if the CloudKit-backed container
    /// can't be created (e.g. capability missing), so the app never crashes
    /// or loses data because of sync availability.
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([Habit.self])

        let cloudConfig = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.orionlabs.continuum")
        )
        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            // Visible in Console.app on production devices — without this,
            // a CloudKit misconfiguration silently ships as "no sync".
            print("Continuum: CloudKit container unavailable, using local-only store: \(error)")
        }

        // Fallback: local-only (same on-disk store, no sync)
        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

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
        .modelContainer(Self.sharedModelContainer)
    }
}

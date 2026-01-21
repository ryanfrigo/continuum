import SwiftUI

struct AddHabitSheet: View {
    @Binding var newHabitName: String
    var onSave: (String) -> Void
    var onCancel: () -> Void
    @FocusState private var isNameFocused: Bool

    @State private var showContent = false
    @State private var selectedSuggestion: String? = nil
    @State private var cursorBlink = false

    private let suggestions = [
        "Exercise",
        "Read",
        "Meditate",
        "Hydrate",
        "Sleep Protocol",
        "Journal",
        "Learn",
        "Nutrition"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                // Subtle grid background
                GridPattern()
                    .opacity(0.03)
                    .ignoresSafeArea()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        // Geometric icon
                        ZStack {
                            Circle()
                                .stroke(.orange.opacity(0.3), lineWidth: 1)
                                .frame(width: 70, height: 70)

                            Image(systemName: "plus")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(.orange)
                        }
                        .scaleEffect(showContent ? 1 : 0.5)
                        .opacity(showContent ? 1 : 0)

                        Text("NEW PROTOCOL")
                            .font(.title3.weight(.bold).monospaced())
                            .foregroundStyle(.white)
                            .tracking(4)
                            .opacity(showContent ? 1 : 0)

                        Text("DEFINE HABIT PARAMETERS")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.gray)
                            .tracking(2)
                            .opacity(showContent ? 1 : 0)
                    }
                    .padding(.top, 20)

                    // Text field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PROTOCOL NAME")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.gray)
                            .tracking(1)

                        HStack {
                            TextField("", text: $newHabitName, prompt: Text("Enter identifier").foregroundStyle(.gray.opacity(0.5)))
                                .font(.body.monospaced())
                                .foregroundStyle(.white)
                                .tint(.orange)
                                .submitLabel(.done)
                                .onSubmit { attemptSave() }
                                .focused($isNameFocused)

                            // Cursor indicator
                            Rectangle()
                                .fill(.orange)
                                .frame(width: 2, height: 20)
                                .opacity(isNameFocused && cursorBlink ? 1 : 0)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.06, green: 0.06, blue: 0.07))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isNameFocused ? Color.orange : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                    }
                    .padding(.horizontal, 24)

                    // Suggestions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("QUICK SELECT")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.gray)
                            .tracking(1)
                            .padding(.horizontal, 24)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            ForEach(suggestions, id: \.self) { name in
                                SuggestionChip(
                                    name: name,
                                    isSelected: selectedSuggestion == name
                                ) {
                                    SoundManager.shared.triggerSelectionHaptic()
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedSuggestion = name
                                        newHabitName = name
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)

                    Spacer()

                    // Save button
                    Button {
                        attemptSave()
                    } label: {
                        HStack(spacing: 8) {
                            Text("REGISTER")
                                .font(.subheadline.monospaced().weight(.bold))
                                .tracking(2)
                            Image(systemName: "arrow.right")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(canSave ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(canSave ? Color.orange : Color.gray.opacity(0.2))
                        )
                    }
                    .disabled(!canSave)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                    .opacity(showContent ? 1 : 0)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") {
                        onCancel()
                    }
                    .font(.caption.monospaced())
                    .foregroundStyle(.gray)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isNameFocused = true
            }
            // Cursor blink
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                cursorBlink = true
            }
        }
        .onChange(of: newHabitName) { _, newValue in
            if !suggestions.contains(newValue) {
                selectedSuggestion = nil
            }
        }
    }

    private var canSave: Bool {
        !newHabitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func attemptSave() {
        let trimmed = newHabitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        SoundManager.shared.playCompletionBeep()
        SoundManager.shared.triggerCompletionHaptic()

        onSave(trimmed)
    }
}

struct SuggestionChip: View {
    let name: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(name.uppercased())
                .font(.caption.monospaced())
                .tracking(1)
                .foregroundStyle(isSelected ? .black : .white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.orange : Color(red: 0.08, green: 0.08, blue: 0.09))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.orange : Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddHabitSheet(newHabitName: .constant(""), onSave: { _ in }, onCancel: {})
}

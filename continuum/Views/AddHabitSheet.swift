import SwiftUI

struct AddHabitSheet: View {
    @Binding var newHabitName: String
    var healthColor: Color = .orange
    var onSave: (String) -> Void
    var onCancel: () -> Void
    @FocusState private var isNameFocused: Bool

    @State private var showContent = false
    @State private var selectedSuggestion: String? = nil

    private let suggestions = [
        "Exercise",
        "Read",
        "Meditate",
        "Hydrate",
        "Journal",
        "Learn",
        "Sleep Early",
        "Eat Healthy"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                // Clean dark slate background
                Color(red: 0.06, green: 0.07, blue: 0.09)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .stroke(healthColor.opacity(0.2), lineWidth: 1)
                                    .frame(width: 80, height: 80)

                                Circle()
                                    .fill(healthColor.opacity(0.1))
                                    .frame(width: 64, height: 64)

                                Image(systemName: "plus")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(healthColor)
                            }
                            .scaleEffect(showContent ? 1 : 0.5)
                            .opacity(showContent ? 1 : 0)

                            VStack(spacing: 6) {
                                Text("New Habit")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)

                                Text("What do you want to build?")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.white.opacity(0.5))
                            }
                            .opacity(showContent ? 1 : 0)
                        }
                        .padding(.top, 24)

                        // Text field
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Habit name")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.4))

                            TextField("", text: $newHabitName, prompt: Text("Enter a name").foregroundStyle(Color.white.opacity(0.3)))
                                .font(.system(size: 17))
                                .foregroundStyle(.white)
                                .tint(healthColor)
                                .submitLabel(.done)
                                .onSubmit { attemptSave() }
                                .focused($isNameFocused)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isNameFocused ? healthColor.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .padding(.horizontal, 24)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                        // Suggestions
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Suggestions")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.4))
                                .padding(.horizontal, 24)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(suggestions, id: \.self) { name in
                                    SuggestionChip(
                                        name: name,
                                        isSelected: selectedSuggestion == name,
                                        healthColor: healthColor
                                    ) {
                                        SoundManager.shared.triggerSelectionHaptic()
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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

                        Spacer(minLength: 40)

                        // Save button - clean, no gradient
                        Button {
                            attemptSave()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Create Habit")
                                    .font(.system(size: 17, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(canSave ? .black : Color.white.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(canSave ? healthColor : Color.white.opacity(0.08))
                            )
                        }
                        .disabled(!canSave)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                        .opacity(showContent ? 1 : 0)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(Color.white.opacity(0.6))
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

// MARK: - Suggestion Chip

struct SuggestionChip: View {
    let name: String
    let isSelected: Bool
    var healthColor: Color = .orange
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .black : Color.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? healthColor : Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? healthColor : Color.white.opacity(0.08), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    AddHabitSheet(newHabitName: .constant(""), onSave: { _ in }, onCancel: {})
}

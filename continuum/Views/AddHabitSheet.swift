import SwiftUI

struct AddHabitSheet: View {
    @Binding var newHabitName: String
    var onSave: (String) -> Void
    var onCancel: () -> Void
    @FocusState private var isNameFocused: Bool

    @State private var showContent = false
    @State private var selectedSuggestion: String? = nil

    private let suggestions = [
        ("🏃", "Exercise"),
        ("📚", "Read"),
        ("🧘", "Meditate"),
        ("💧", "Drink Water"),
        ("😴", "Sleep 8hrs"),
        ("📝", "Journal"),
        ("🎯", "Learn"),
        ("🥗", "Eat Healthy")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.orange)
                            .scaleEffect(showContent ? 1 : 0.5)
                            .opacity(showContent ? 1 : 0)

                        Text("New Habit")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .opacity(showContent ? 1 : 0)

                        Text("What do you want to build?")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .opacity(showContent ? 1 : 0)
                    }
                    .padding(.top, 20)

                    // Text field
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Enter habit name", text: $newHabitName)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white)
                            .tint(.orange)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(red: 0.1, green: 0.1, blue: 0.11))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isNameFocused ? Color.orange : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .submitLabel(.done)
                            .onSubmit { attemptSave() }
                            .focused($isNameFocused)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)
                    }
                    .padding(.horizontal, 24)

                    // Suggestions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SUGGESTIONS")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 24)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(suggestions, id: \.1) { emoji, name in
                                SuggestionChip(
                                    emoji: emoji,
                                    name: name,
                                    isSelected: selectedSuggestion == name
                                ) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        selectedSuggestion = name
                                        newHabitName = name
                                    }
                                    // Haptic
                                    #if os(iOS)
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    #endif
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
                        Text("Create Habit")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(canSave ? .black : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(canSave ? Color.orange : Color.gray.opacity(0.3))
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
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundStyle(.gray)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = true
            }
            // Delay focus to allow animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isNameFocused = true
            }
        }
        .onChange(of: newHabitName) { _, newValue in
            // Clear suggestion if user types something different
            if !suggestions.contains(where: { $0.1 == newValue }) {
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

        // Haptic
        #if os(iOS)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        #endif

        onSave(trimmed)
    }
}

struct SuggestionChip: View {
    let emoji: String
    let name: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.title3)
                Text(name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .black : .white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.orange : Color(red: 0.1, green: 0.1, blue: 0.11))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.orange : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddHabitSheet(newHabitName: .constant(""), onSave: { _ in }, onCancel: {})
}

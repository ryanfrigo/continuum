import SwiftUI

struct RenameHabitSheet: View {
    @Binding var habitName: String
    var onSave: (String) -> Void
    var onCancel: () -> Void
    @FocusState private var isNameFocused: Bool

    @State private var showContent = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.orange)
                            .scaleEffect(showContent ? 1 : 0.5)
                            .opacity(showContent ? 1 : 0)

                        Text("Rename Habit")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .opacity(showContent ? 1 : 0)

                        Text("Give your habit a new name")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                            .opacity(showContent ? 1 : 0)
                    }
                    .padding(.top, 40)

                    // Text field
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Enter habit name", text: $habitName)
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

                    Spacer()

                    // Save button
                    Button {
                        attemptSave()
                    } label: {
                        Text("Save Changes")
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isNameFocused = true
            }
        }
    }

    private var canSave: Bool {
        !habitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func attemptSave() {
        let trimmed = habitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        #if os(iOS)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        #endif

        onSave(trimmed)
    }
}

#Preview {
    RenameHabitSheet(habitName: .constant("Exercise"), onSave: { _ in }, onCancel: {})
}

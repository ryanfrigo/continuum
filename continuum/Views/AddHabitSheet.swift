import SwiftUI

struct AddHabitSheet: View {
    @Binding var newHabitName: String
    var onSave: (String) -> Void
    var onCancel: () -> Void
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                
                TextField("Habit name", text: $newHabitName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.orange)
                    .tint(.orange)
                    .submitLabel(.done)
                    .onSubmit { attemptSave() }
                    .focused($isNameFocused)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .fontDesign(.monospaced)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { attemptSave() }
                        .disabled(newHabitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            // Use a very small delay to ensure the sheet is fully presented
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            isNameFocused = true
        }
    }

    private func attemptSave() {
        let trimmed = newHabitName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSave(trimmed)
    }
}

#Preview {
    AddHabitSheet(newHabitName: .constant(""), onSave: { _ in }, onCancel: {})
}







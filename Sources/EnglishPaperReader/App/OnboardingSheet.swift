import SwiftUI

struct OnboardingSheet: View {
    let onDismiss: () -> Void

    @State private var currentStep = 0

    private let steps: [OnboardingStep] = [
        OnboardingStep(
            symbol: "graduationcap.fill",
            symbolColor: .indigo,
            title: "Welcome to\nEnglish Paper Reader",
            description: "Read academic papers and build your English vocabulary at the same time. Every unfamiliar word becomes a learning opportunity."
        ),
        OnboardingStep(
            symbol: "sidebar.left",
            symbolColor: .blue,
            title: "Open PDFs",
            description: "Import your papers from the sidebar on the left. Organize them into folders to keep your library tidy."
        ),
        OnboardingStep(
            symbol: "text.cursor",
            symbolColor: .green,
            title: "Register Words",
            description: "Select any text in the PDF to open the Quick Register sheet. Add a definition and save — the word is highlighted from then on."
        ),
        OnboardingStep(
            symbol: "rectangle.bottomthird.inset.filled",
            symbolColor: .orange,
            title: "Review Your Vocabulary",
            description: "The word list at the bottom tracks everything you've registered. Click any word to see its details and add example sentences."
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            let step = steps[currentStep]

            Image(systemName: step.symbol)
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(step.symbolColor)
                .padding(.bottom, 24)

            Text(step.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            Text(step.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)

            Spacer()

            HStack(spacing: 6) {
                ForEach(0 ..< steps.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .animation(.easeInOut(duration: 0.2), value: currentStep)
                }
            }
            .padding(.bottom, 20)

            HStack {
                Button("Skip") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button(currentStep < steps.count - 1 ? "Next" : "Get Started") {
                    if currentStep < steps.count - 1 {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStep += 1
                        }
                    } else {
                        onDismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .frame(width: 480, height: 380)
    }
}

private struct OnboardingStep {
    let symbol: String
    let symbolColor: Color
    let title: String
    let description: String
}

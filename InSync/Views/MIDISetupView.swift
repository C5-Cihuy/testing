import SwiftUI
import UniformTypeIdentifiers

// MARK: - MIDI Setup

struct MIDISetupView: View {
    // MARK: State

    @Environment(\.dismiss) private var dismiss

    /// A single optional identifier keeps the accordion mutually exclusive.
    @State private var expandedStepID: Int?
    @State private var isFileImporterPresented = false
    @State private var importedFileName: String?
    @State private var importErrorMessage = ""
    @State private var isImportErrorPresented = false

    private let steps = MIDISetupStep.previewSteps

    // MARK: Initialization

    init(expandedStepID: Int? = nil) {
        _expandedStepID = State(initialValue: expandedStepID)
    }

    // MARK: View

    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()

            VStack(spacing: 16) {
                MIDISetupHeader(onClose: { dismiss() })

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        MIDIConnectionCard(
                            importedFileName: importedFileName,
                            onImport: { isFileImporterPresented = true }
                        )

                        MIDISetupGuideHeader(stepCount: steps.count)

                        LazyVStack(spacing: 12) {
                            ForEach(steps) { step in
                                MIDISetupStepCard(
                                    step: step,
                                    isExpanded: expandedStepID == step.id,
                                    onToggle: { toggle(step) }
                                )
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(16)
        }
        .toolbar(.hidden, for: .navigationBar)
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.midi]
        ) { result in
            handleFileImport(result)
        }
        .alert("Unable to Import MIDI File", isPresented: $isImportErrorPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
    }

    // MARK: Actions

    private func toggle(_ step: MIDISetupStep) {
        withAnimation(.snappy) {
            expandedStepID = expandedStepID == step.id ? nil : step.id
        }
    }

    private func handleFileImport(_ result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            // Parsing and persistence will be connected with the MIDI backend.
            importedFileName = url.lastPathComponent

        case .failure(let error):
            importErrorMessage = error.localizedDescription
            isImportErrorPresented = true
        }
    }
}

// MARK: - Presentation Model

private struct MIDISetupStep: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let points: [String]
    let note: String?
}

// MARK: - Components

private struct MIDISetupHeader: View {
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(AppColors.primaryForeground)
                    .frame(width: 58, height: 58)
                    .background(AppColors.primary, in: Circle())
            }
            .accessibilityLabel("Close MIDI setup")

            Spacer()

            VStack(spacing: 12) {
                Text("MIDI Setup")
                    .font(.largeTitle.bold())
                    .underline()
                    .foregroundStyle(AppColors.cardForeground)

                Text("Sync is optional. Without it, the leader changes sections by tapping.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.mutedForeground)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Balances the close button so the title stays centered.
            Color.clear
                .frame(width: 58, height: 58)
                .accessibilityHidden(true)
        }
    }
}

private struct MIDIConnectionCard: View {
    let importedFileName: String?
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                MIDIConnectionLabel(
                    number: 1,
                    title: "Import Markers",
                    subtitle: importedFileName
                        ?? "MIDI file exported from the Digital Audio Workstation project"
                )

                Spacer()

                Button(action: onImport) {
                    Label("Import file", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.secondary)
                .foregroundStyle(AppColors.secondaryForeground)
                .accessibilityHint("File importing will be connected later")
            }
            .padding(16)

            Divider()

            HStack(spacing: 16) {
                MIDIConnectionLabel(
                    number: 2,
                    title: "Connect Logic to this iPad",
                    subtitle: "Cable setup in Audio MIDI Setup on the Mac"
                )

                Spacer()

                Label("Connected", systemImage: "circle.fill")
                    .font(.body)
                    .foregroundStyle(AppColors.mutedForeground)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.green, AppColors.mutedForeground)
            }
            .padding(16)
        }
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.mutedForeground.opacity(0.35), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

private struct MIDIConnectionLabel: View {
    let number: Int
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Text(number, format: .number)
                Text(title)
                    .fontWeight(.semibold)
            }
            .font(.headline)
            .foregroundStyle(AppColors.cardForeground)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AppColors.mutedForeground)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct MIDISetupGuideHeader: View {
    let stepCount: Int

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Setup Guide")
                    .font(.title2.bold())
                    .foregroundStyle(AppColors.cardForeground)

                Text("Follow these steps to sync your Digital Audio Workstation with the app.")
                    .font(.body)
                    .foregroundStyle(AppColors.mutedForeground)
            }

            Spacer()

            Text("\(stepCount) steps")
                .foregroundStyle(AppColors.mutedForeground)
        }
    }
}

private struct MIDISetupStepCard: View {
    let step: MIDISetupStep
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 12) {
                    Text(step.id, format: .number)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.cardForeground)

                        Text(step.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.mutedForeground)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.headline)
                        .foregroundStyle(AppColors.cardForeground)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .font(.headline)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Step \(step.id), \(step.title)")
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "Collapses this step" : "Expands this step")

            if isExpanded {
                Divider()
                    .padding(.vertical, 12)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(step.points, id: \.self) { point in
                        Label {
                            Text(point)
                                .foregroundStyle(AppColors.cardForeground)
                        } icon: {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(AppColors.cardForeground)
                        }
                    }

                    if let note = step.note {
                        Label(note, systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.mutedForeground.opacity(0.35), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Preview Data

private extension MIDISetupStep {
    static let previewSteps: [MIDISetupStep] = [
        MIDISetupStep(
            id: 1,
            title: "Prepare your Digital Audio Workstation project",
            subtitle: "Set up your sequencer and section markers",
            points: [
                "Open the related sequencer project in your Digital Audio Workstation (DAW)",
                "Make sure your sequencer is ready and each song section has a marker."
            ],
            note: nil
        ),
        MIDISetupStep(
            id: 2,
            title: "Connect your iPad to your Mac",
            subtitle: "Establish a wired MIDI connection",
            points: [
                "Connect your iPad to your Mac using a cable",
                "On your Mac, open Audio MIDI Setup",
                "From the menu bar, select Window → Show Audio Devices",
                "Find your iPad and click Enable to activate the IDAM connection",
                "Open the app on your iPad to verify the connection"
            ],
            note: "If you disconnect your iPad, repeat this step after reconnecting it."
        ),
        MIDISetupStep(
            id: 3,
            title: "Enable MIDI Clock",
            subtitle: "Synchronize timing between Digital Audio Workstation and your iPad",
            points: [
                "In your Digital Audio Workstation, open File → Project Settings → Synchronization → MIDI",
                "Add your iPad as a MIDI destination",
                "Enable the Clock checkbox"
            ],
            note: nil
        ),
        MIDISetupStep(
            id: 4,
            title: "Set Up MIDI Track",
            subtitle: "Prepare MIDI data for synchronization",
            points: [
                "Create a new Software Instrument MIDI track",
                "Create a MIDI region and extend it across your sequencer",
                "Open the Piano Roll (you can use hotkey ‘P’) and add one random MIDI note"
            ],
            note: nil
        ),
        MIDISetupStep(
            id: 5,
            title: "Export and Upload MIDI File",
            subtitle: "Transfer your sequencer’s markers to the app",
            points: [
                "In your Digital Audio Workstation, select File → Export → All MIDI Tracks as MIDI File",
                "Save the exported MIDI file",
                "AirDrop the .midi file to your iPad",
                "On your iPad, select the MIDI file from Files or iCloud Drive",
                "The app will detect and import the section markers"
            ],
            note: nil
        ),
        MIDISetupStep(
            id: 6,
            title: "Confirm Synchronization",
            subtitle: "Make sure synchronization between the Digital Audio Workstation and iPad is established and working",
            points: [
                "Try start sharing on the InSync app",
                "Start playback in your Digital Audio Workstation",
                "The app will follow the MIDI timing and display the corresponding song sections",
                "Check that the displayed sections match the sequencer’s playback",
                "And, you’re all set!"
            ],
            note: nil
        )
    ]
}

// MARK: - Previews

#Preview("Collapsed") {
    MIDISetupView()
}

#Preview("Expanded step") {
    MIDISetupView(expandedStepID: 2)
}

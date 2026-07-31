//
//  MultiAudioMemoView.swift
//  EcoJournal
//
//  Created by David Contreras on 5/19/26.
//

import SwiftUI
import SwiftData

/// Component for managing multiple audio memos in a log entry
struct MultiAudioMemoView: View {
    @Binding var audioMemos: [AudioMemo]
    @Environment(\.modelContext) private var modelContext

    @StateObject private var audioService = AudioRecorderService()
    @StateObject private var transcriptionService = AudioTranscriptionService()

    @State private var isRecording = false
    @State private var recordingURL: URL?
    @State private var showingTitlePrompt = false
    @State private var newMemoTitle = ""
    @State private var selectedMemo: AudioMemo?
    @State private var playingMemoId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("AUDIO MEMOS")
                    .font(.label(10, weight: .bold))
                    .foregroundColor(.tertiary)
                    .tracking(1.5)

                Spacer()

                if !audioMemos.isEmpty {
                    Text("\(audioMemos.count) memo\(audioMemos.count == 1 ? "" : "s")")
                        .font(.label(10, weight: .bold))
                        .foregroundColor(.onSurfaceVariant)
                }
            }

            // List of existing memos
            if !audioMemos.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(audioMemos.enumerated()), id: \.element.id) { index, memo in
                        AudioMemoCard(
                            memo: memo,
                            index: index + 1,
                            isPlaying: playingMemoId == memo.id,
                            onPlay: {
                                playAudio(memo)
                            },
                            onDelete: {
                                deleteMemo(memo)
                            }
                        )
                    }
                }
            }

            // Add new memo button / Recording state
            if isRecording {
                recordingCard
            } else {
                addMemoButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .alert("Name Your Memo", isPresented: $showingTitlePrompt) {
            TextField("e.g., Soil Moisture, Weather Notes", text: $newMemoTitle)
            Button("Cancel", role: .cancel) {
                // Cleanup recording if cancelled
                if let url = recordingURL {
                    audioService.deleteAudio(at: url)
                }
                recordingURL = nil
                newMemoTitle = ""
            }
            Button("Save") {
                saveNewMemo()
            }
        } message: {
            Text("Give this audio memo a descriptive title")
        }
    }

    // MARK: - Recording Card

    private var recordingCard: some View {
        Button(action: stopRecording) {
            HStack(spacing: 16) {
                // Animated microphone icon
                ZStack {
                    Circle()
                        .fill(Color.error.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.error)
                }
                .scaleEffect(audioService.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: audioService.isRecording)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Recording...")
                        .font(.body(16, weight: .bold))
                        .foregroundColor(.onSurface)

                    Text(audioService.formatTime(audioService.recordingDuration))
                        .font(.display(20, weight: .black))
                        .foregroundColor(.error)
                        .monospacedDigit()
                }

                Spacer()

                Text("TAP TO STOP")
                    .font(.label(10, weight: .bold))
                    .foregroundColor(.error)
                    .tracking(1.2)
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.error, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Memo Button

    private var addMemoButton: some View {
        Button(action: startRecording) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.primaryColor)

                Text("Add Voice Memo")
                    .font(.body(16, weight: .semibold))
                    .foregroundColor(.onSurface)

                Spacer()
            }
            .padding(16)
            .background(Color.surfaceContainer)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.outlineVariant, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func startRecording() {
        isRecording = true
        recordingURL = audioService.startRecording()
    }

    private func stopRecording() {
        isRecording = false
        recordingURL = audioService.stopRecording()

        // Show title prompt
        showingTitlePrompt = true
    }

    private func saveNewMemo() {
        guard let url = recordingURL else { return }

        let title = newMemoTitle.isEmpty ? "Voice Memo" : newMemoTitle
        let duration = audioService.getDuration(for: url) ?? 0

        let newMemo = AudioMemo(
            title: title,
            audioURL: url,
            duration: duration
        )

        // Add to array
        audioMemos.append(newMemo)

        // Start transcription
        transcribeAudio(for: newMemo)

        // Reset state
        recordingURL = nil
        newMemoTitle = ""
    }

    private func transcribeAudio(for memo: AudioMemo) {
        Task {
            do {
                let text = try await transcriptionService.transcribe(audioURL: memo.audioURL)
                memo.transcription = text
            } catch {
                print("Transcription failed: \(error.localizedDescription)")
            }
        }
    }

    private func playAudio(_ memo: AudioMemo) {
        if playingMemoId == memo.id && audioService.isPlaying {
            audioService.stopPlayback()
            playingMemoId = nil
        } else {
            audioService.playAudio(from: memo.audioURL)
            playingMemoId = memo.id
        }
    }

    private func deleteMemo(_ memo: AudioMemo) {
        // Delete audio file
        audioService.deleteAudio(at: memo.audioURL)

        // Remove from array
        audioMemos.removeAll { $0.id == memo.id }

        // Delete from model context if it's persisted
        modelContext.delete(memo)
    }
}

// MARK: - Audio Memo Card (Compact)

struct AudioMemoCard: View {
    let memo: AudioMemo
    let index: Int
    let isPlaying: Bool
    let onPlay: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Memo #\(index) • \(memo.title)")
                    .font(.label(11, weight: .bold))
                    .foregroundColor(.onSurface)
                    .tracking(0.5)

                Spacer()

                // Delete button
                Button(action: { showingDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.error)
                }
            }

            // Playback controls
            HStack(spacing: 12) {
                Button(action: onPlay) {
                    Circle()
                        .fill(Color.primaryColor)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.onPrimary)
                        }
                }

                // Duration
                Text(formattedDuration(memo.duration))
                    .font(.label(12))
                    .foregroundColor(.onSurfaceVariant)
                    .monospacedDigit()

                Spacer()

                // Transcription badge
                if memo.transcription != nil {
                    Text("TRANSCRIBED")
                        .font(.label(8, weight: .bold))
                        .foregroundColor(.primaryColor)
                        .tracking(0.8)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.primaryColor.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            // Transcription preview
            if let transcription = memo.transcription, !transcription.isEmpty {
                Text(transcription)
                    .font(.body(12))
                    .italic()
                    .foregroundColor(.onSurfaceVariant)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(6)
            }
        }
        .padding(14)
        .background(Color.surfaceContainer)
        .cornerRadius(10)
        .alert("Delete Memo?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("This will permanently delete \"\(memo.title)\" and its transcription.")
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview("Multiple Memos") {
    @Previewable @State var memos: [AudioMemo] = [
        AudioMemo(
            title: "Soil Moisture",
            audioURL: URL(string: "file:///memo1.m4a")!,
            transcription: "Observed significant moisture levels in the soil samples.",
            duration: 42
        ),
        AudioMemo(
            title: "Weather Notes",
            audioURL: URL(string: "file:///memo2.m4a")!,
            transcription: nil,
            duration: 75
        ),
        AudioMemo(
            title: "Sample Analysis",
            audioURL: URL(string: "file:///memo3.m4a")!,
            transcription: "Three distinct layers identified in core sample.",
            duration: 58
        )
    ]

    return ScrollView {
        MultiAudioMemoView(audioMemos: $memos)
            .padding()
    }
}

#Preview("Empty State") {
    @Previewable @State var memos: [AudioMemo] = []

    return ScrollView {
        MultiAudioMemoView(audioMemos: $memos)
            .padding()
    }
}

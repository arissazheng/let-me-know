import AVKit
import CoreLocation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// F4: describe an incident at the pinned location, optionally with a photo or video.
struct NewReportSheet: View {
    var coordinate: CLLocationCoordinate2D
    var onSubmit: (String, PickedMedia?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var media: PickedMedia?
    @State private var previewImage: Image?
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("What happened?", text: $text, axis: .vertical)
                        .lineLimit(4...8)
                } footer: {
                    Text("Reported at the pin you placed. Visible to signed-in students for 24 hours.")
                }

                Section {
                    PhotosPicker(selection: $pickerItem, matching: .any(of: [.images, .videos])) {
                        Label(media == nil ? "Add Photo or Video" : "Replace Media", systemImage: "photo.on.rectangle")
                    }
                    if let media {
                        HStack {
                            if let previewImage {
                                previewImage.resizable().scaledToFill().frame(width: 56, height: 56).clipShape(.rect(cornerRadius: 8))
                            } else {
                                Image(systemName: "video.fill").frame(width: 56, height: 56)
                            }
                            Text(media.type == .video ? "Video attached" : "Photo attached")
                            Spacer()
                            Button("Remove", role: .destructive) {
                                pickerItem = nil
                                self.media = nil
                                previewImage = nil
                            }
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit", systemImage: "checkmark") { Task { await submit() } }
                        .buttonStyle(.glassProminent)
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
            .onChange(of: pickerItem) { _, item in Task { await load(item) } }
            .overlay { if isSubmitting { ProgressView() } }
        }
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        let type = item.supportedContentTypes.first
        media = PickedMedia(
            data: data,
            type: isVideo ? .video : .image,
            fileExtension: type?.preferredFilenameExtension ?? (isVideo ? "mov" : "jpg"),
            contentType: type?.preferredMIMEType ?? (isVideo ? "video/quicktime" : "image/jpeg")
        )
        previewImage = isVideo ? nil : UIImage(data: data).map(Image.init(uiImage:))
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await onSubmit(text.trimmingCharacters(in: .whitespacesAndNewlines), media)
            dismiss()
        } catch {
            errorMessage = "Couldn't submit: \(error.localizedDescription)"
        }
    }
}

/// F3: read a report — text, image or video, and when it was posted.
struct ReportDetailSheet: View {
    var report: Report

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(report.createdAt.formatted(.relative(presentation: .named)), systemImage: "clock")
                    if report.isDemo {
                        Text("Demo").font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 2)
                            .glassEffect(.regular.tint(.orange.opacity(0.3)), in: .capsule)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Text(report.description)
                    .font(.title3)

                if let url = report.mediaURL {
                    switch report.mediaType {
                    case .video:
                        VideoPlayer(player: AVPlayer(url: url))
                            .frame(height: 240)
                            .clipShape(.rect(cornerRadius: 16))
                    default:
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 160)
                        }
                        .clipShape(.rect(cornerRadius: 16))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .presentationDetents([.medium, .large])
    }
}

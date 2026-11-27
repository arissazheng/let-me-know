import AVKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

let emergencyPhone = URL(string: "tel://911")!

/// Large + button in the map's bottom corner. Press and hold to reveal Report, campus police, and 911,
/// then slide onto one and let go to choose it. A quick tap opens the same options to tap.
struct ActionFab: View {
    enum Action: CaseIterable {
        case report, campusPolice, emergency

        var symbol: String {
            switch self {
            case .report: "exclamationmark.bubble.fill"
            case .campusPolice: "shield.lefthalf.filled"
            case .emergency: "phone.fill"
            }
        }

        /// Where the option sits relative to the + button's center.
        var offset: CGSize {
            switch self {
            case .emergency: CGSize(width: 0, height: -90)
            case .campusPolice: CGSize(width: -80, height: -72)
            case .report: CGSize(width: -92, height: 4)
            }
        }
    }

    /// The campus police's short name (e.g. "UCPD"); without a known number that option is hidden.
    var policeName: String?
    var onAction: (Action) -> Void

    private var actions: [Action] { Action.allCases.filter { $0 != .campusPolice || policeName != nil } }

    private func label(_ action: Action) -> String {
        switch action {
        case .report: "Report"
        case .campusPolice: policeName ?? "Police"
        case .emergency: "911"
        }
    }

    @State private var isOpen = false
    @State private var hovered: Action?
    @State private var pressStart: Date?
    @State private var holdTask: Task<Void, Never>?
    private let size: CGFloat = 66

    var body: some View {
        ZStack {
            // Only drawn while open: glass ignores .opacity, so hidden options would show through.
            if isOpen {
                ForEach(actions, id: \.self) { action in
                    option(action)
                }
            }
            plusButton
        }
        .animation(.bouncy(duration: 0.3), value: isOpen)
        .animation(.snappy(duration: 0.15), value: hovered)
    }

    private func option(_ action: Action) -> some View {
        Button {
            choose(action)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: action.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(action == .emergency ? .white : action == .report ? .red : .blue)
                    .frame(width: 52, height: 52)
                    .glassEffect(action == .emergency ? .regular.tint(.red) : .regular.interactive(), in: .circle)
                    .scaleEffect(hovered == action ? 1.18 : 1)
                Text(label(action))
                    .font(.caption.bold())
                    .shadow(color: .white.opacity(0.9), radius: 2)
            }
        }
        .buttonStyle(.plain)
        .offset(action.offset)
        .transition(
            .scale(scale: 0.3)
                .combined(with: .opacity)
                .combined(with: .offset(x: -action.offset.width, y: -action.offset.height))
        )
    }

    private var plusButton: some View {
        Image(systemName: "plus")
            .font(.system(size: 28, weight: .semibold))
            .rotationEffect(.degrees(isOpen ? 45 : 0))
            .frame(width: size, height: size)
            .contentShape(.rect)
            // Plain (non-interactive) glass: interactive glass tracks touches itself and would
            // cancel the hold-and-slide drag.
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .gesture(holdAndSlide)
            .accessibilityLabel("Report or call for help")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { isOpen.toggle() }
    }

    /// Press: open after a short hold. Drag: highlight the option under the finger. Release: choose it.
    private var holdAndSlide: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if pressStart == nil {
                    pressStart = .now
                    holdTask = Task {
                        try? await Task.sleep(for: .milliseconds(250))
                        guard !Task.isCancelled else { return }
                        isOpen = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
                if isOpen { hovered = action(at: value.location) }
            }
            .onEnded { value in
                holdTask?.cancel()
                let wasHold = pressStart.map { Date.now.timeIntervalSince($0) >= 0.25 } ?? false
                pressStart = nil
                if wasHold {
                    if let action = action(at: value.location) { choose(action) } else { hovered = nil }
                } else {
                    isOpen.toggle()
                }
            }
    }

    /// The option within reach of a point in the + button's own coordinates.
    private func action(at point: CGPoint) -> Action? {
        let center = CGPoint(x: size / 2, y: size / 2)
        return actions.first { action in
            let target = CGPoint(x: center.x + action.offset.width, y: center.y + action.offset.height)
            return hypot(point.x - target.x, point.y - target.y) < 36
        }
    }

    private func choose(_ action: Action) {
        isOpen = false
        hovered = nil
        onAction(action)
    }
}

/// Liquid glass card over a faded map; tapping anywhere outside the card closes it.
struct GlassModal<Content: View>: View {
    var onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) { content }
                    .padding(20)
                    .padding(.top, 6)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 640)
            .fixedSize(horizontal: false, vertical: true)
            .glassEffect(.regular, in: .rect(cornerRadius: 32))
            .overlay(alignment: .topTrailing) {
                Button("Close", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .padding(12)
            }
            .padding(20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
}

/// F4: optional title, a description, and any number of photos/videos.
struct ReportFormView: View {
    var onSubmit: (_ title: String, _ description: String, _ media: [PickedMedia]) async throws -> Void
    var onClose: () -> Void

    @State private var title = ""
    @State private var text = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var media: [PickedMedia] = []
    @State private var previews: [UIImage?] = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        GlassModal(onClose: onClose) {
            TextField("Title", text: $title)
                .font(.title.bold())
                .padding(.trailing, 44)

            Text("Description \(Text("*").foregroundStyle(.red))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Description, required")
            TextField("What happened?", text: $text, axis: .vertical)
                .lineLimit(5...10)
                .padding(14)
                .background(.background.opacity(0.7), in: .rect(cornerRadius: 16))

            if !media.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 84, maximum: 84), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(media.indices, id: \.self) { i in
                        thumbnail(i)
                    }
                }
            }

            PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .any(of: [.images, .videos])) {
                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.tint)
                    Text(media.isEmpty ? "Upload" : "Add more")
                        .font(.subheadline.weight(.semibold))
                    Text(".JPG, .PNG, .MOV")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(.background.opacity(0.5), in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
                .contentShape(.rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(isSubmitting ? "Submitting…" : "Confirm") { Task { await submit() } }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
            }
        }
        .onChange(of: pickerItems) { _, items in Task { await load(items) } }
    }

    private func thumbnail(_ i: Int) -> some View {
        Color.clear
            .frame(width: 84, height: 84)
            .overlay {
                if let image = previews[i] {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "video.fill").font(.title2).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
                }
            }
            .clipShape(.rect(cornerRadius: 14))
            .overlay(alignment: .topTrailing) {
                Button("Remove", systemImage: "xmark.circle.fill") {
                    media.remove(at: i)
                    previews.remove(at: i)
                    pickerItems.removeAll()
                }
                .labelStyle(.iconOnly)
                .foregroundStyle(.white, .black.opacity(0.55))
                .padding(4)
            }
    }

    /// Adds newly picked photos/videos.
    private func load(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            let type = item.supportedContentTypes.first
            media.append(PickedMedia(
                data: data,
                type: isVideo ? .video : .image,
                fileExtension: type?.preferredFilenameExtension ?? (isVideo ? "mov" : "jpg"),
                contentType: type?.preferredMIMEType ?? (isVideo ? "video/quicktime" : "image/jpeg")
            ))
            previews.append(isVideo ? nil : UIImage(data: data))
        }
        if !items.isEmpty { pickerItems = [] }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await onSubmit(title.trimmingCharacters(in: .whitespaces), text.trimmingCharacters(in: .whitespacesAndNewlines), media)
            onClose()
        } catch {
            errorMessage = "Couldn't submit: \(error.localizedDescription)"
        }
    }
}

/// F3: a report's title, place, description, and a media library (large view + thumbnails).
struct ReportDetailView: View {
    var report: Report
    var onClose: () -> Void
    @State private var index = 0

    var body: some View {
        GlassModal(onClose: onClose) {
            Text(report.title ?? "Incident report")
                .font(.title.bold())
                .padding(.trailing, 44)

            VStack(alignment: .leading, spacing: 6) {
                if let place = report.placeName {
                    Label(place, systemImage: "mappin")
                }
                HStack(spacing: 12) {
                    Label(report.createdAt.formatted(.relative(presentation: .named)), systemImage: "clock")
                    if report.isDemo {
                        Text("Demo").font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 2)
                            .glassEffect(.regular.tint(.orange.opacity(0.3)), in: .capsule)
                    }
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            Text(report.description)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.background.opacity(0.7), in: .rect(cornerRadius: 16))

            let media = report.attachments
            if media.indices.contains(index) {
                HStack(alignment: .top, spacing: 8) {
                    mediaView(media[index], large: true)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(.black)
                        .clipShape(.rect(cornerRadius: 18))
                    if media.count > 1 {
                        ScrollView {
                            VStack(spacing: 6) {
                                ForEach(media.indices, id: \.self) { i in
                                    Button { index = i } label: {
                                        mediaView(media[i], large: false)
                                            .frame(width: 56, height: 56)
                                            .clipShape(.rect(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(i == index ? Color.accentColor : .clear, lineWidth: 2))
                                            .opacity(i == index ? 1 : 0.7)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(width: 56)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func mediaView(_ item: Report.MediaItem, large: Bool) -> some View {
        switch item.type {
        case .video:
            if large {
                VideoPlayer(player: AVPlayer(url: item.url)).id(item.url)
            } else {
                Image(systemName: "play.rectangle.fill").font(.title2).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(.black)
            }
        case .image:
            AsyncImage(url: item.url) { image in
                image.resizable().aspectRatio(contentMode: large ? .fit : .fill)
            } placeholder: {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

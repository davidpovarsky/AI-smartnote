import Foundation
import AVFoundation
import PDFKit
import PencilKit
import SwiftUI
import UIKit

/// A local-first model that mirrors the major Goodnotes/Notability workspaces.
/// Network sync and real AI execution can attach to these records later without
/// changing the iPad writing surface.
struct Notebook: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: NotebookKind = .notebook
    var title: String
    var subject: String
    var folder: LibraryFolder
    var cover: NotebookCover
    var modifiedAt: Date
    var isFavorite: Bool
    var isShared: Bool = false
    var pages: [NotebookPage]
    var recordings: [AudioRecording] = []
    var studySets: [StudySet] = []
    var collaborators: [Collaborator] = []
    var exportedDocuments: [ExportedDocument] = []

    var pageCountText: String {
        "\(pages.count) 页"
    }

    /// Library search should find real notebook contents, not only titles.
    var searchableText: String {
        let pageText = pages
            .map { page in
                [
                    page.title,
                    page.template.rawValue,
                    page.previewLines.joined(separator: " "),
                    page.outlineTitle ?? "",
                    page.elements.map { "\($0.title) \($0.detail)" }.joined(separator: " "),
                    page.assets.map { "\($0.title) \($0.kind.rawValue)" }.joined(separator: " "),
                    page.transcriptSummary ?? ""
                ].joined(separator: " ")
            }
            .joined(separator: " ")
        let recordingText = recordings.map(\.transcript).joined(separator: " ")
        let studyText = studySets
            .flatMap(\.cards)
            .map { "\($0.prompt) \($0.answer)" }
            .joined(separator: " ")
        return [title, subject, kind.rawValue, pageText, recordingText, studyText].joined(separator: " ")
    }
}

struct NotebookPage: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var template: PaperTemplate
    var previewLines: [String]
    var rotationDegrees: Int
    var drawingData: Data = Data()
    var elements: [PageElement] = []
    var assets: [ImportedAsset] = []
    var audioMarkers: [AudioMarker] = []
    var isBookmarked: Bool = false
    var outlineTitle: String?
    var transcriptSummary: String?

    var normalizedRotationDegrees: Int {
        Self.normalizedRotationDegrees(rotationDegrees)
    }

    var hasUserAnnotations: Bool {
        !drawingData.isEmpty || !elements.isEmpty || assets.contains { asset in
            !(asset.kind == .pdf && asset.storedFileName != nil && asset.sourcePageIndex != nil)
        }
    }

    init(
        id: UUID = UUID(),
        title: String,
        template: PaperTemplate,
        previewLines: [String],
        rotationDegrees: Int = 0,
        drawingData: Data = Data(),
        elements: [PageElement] = [],
        assets: [ImportedAsset] = [],
        audioMarkers: [AudioMarker] = [],
        isBookmarked: Bool = false,
        outlineTitle: String? = nil,
        transcriptSummary: String? = nil
    ) {
        self.id = id
        self.title = title
        self.template = template
        self.previewLines = previewLines
        self.rotationDegrees = Self.normalizedRotationDegrees(rotationDegrees)
        self.drawingData = drawingData
        self.elements = elements
        self.assets = assets
        self.audioMarkers = audioMarkers
        self.isBookmarked = isBookmarked
        self.outlineTitle = outlineTitle
        self.transcriptSummary = transcriptSummary
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case template
        case previewLines
        case rotationDegrees
        case drawingData
        case elements
        case assets
        case audioMarkers
        case isBookmarked
        case outlineTitle
        case transcriptSummary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "未命名页面"
        template = try container.decodeIfPresent(PaperTemplate.self, forKey: .template) ?? .ruled
        previewLines = try container.decodeIfPresent([String].self, forKey: .previewLines) ?? []
        rotationDegrees = Self.normalizedRotationDegrees(try container.decodeIfPresent(Int.self, forKey: .rotationDegrees) ?? 0)
        drawingData = try container.decodeIfPresent(Data.self, forKey: .drawingData) ?? Data()
        elements = try container.decodeIfPresent([PageElement].self, forKey: .elements) ?? []
        assets = try container.decodeIfPresent([ImportedAsset].self, forKey: .assets) ?? []
        audioMarkers = try container.decodeIfPresent([AudioMarker].self, forKey: .audioMarkers) ?? []
        isBookmarked = try container.decodeIfPresent(Bool.self, forKey: .isBookmarked) ?? false
        outlineTitle = try container.decodeIfPresent(String.self, forKey: .outlineTitle)
        transcriptSummary = try container.decodeIfPresent(String.self, forKey: .transcriptSummary)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(template, forKey: .template)
        try container.encode(previewLines, forKey: .previewLines)
        try container.encode(normalizedRotationDegrees, forKey: .rotationDegrees)
        try container.encode(drawingData, forKey: .drawingData)
        try container.encode(elements, forKey: .elements)
        try container.encode(assets, forKey: .assets)
        try container.encode(audioMarkers, forKey: .audioMarkers)
        try container.encode(isBookmarked, forKey: .isBookmarked)
        try container.encodeIfPresent(outlineTitle, forKey: .outlineTitle)
        try container.encodeIfPresent(transcriptSummary, forKey: .transcriptSummary)
    }

    static func normalizedRotationDegrees(_ degrees: Int) -> Int {
        let roundedToRightAngle = Int((Double(degrees) / 90.0).rounded()) * 90
        let remainder = roundedToRightAngle % 360
        return remainder < 0 ? remainder + 360 : remainder
    }
}

enum NotebookKind: String, CaseIterable, Codable, Identifiable {
    case notebook = "笔记本"
    case pdf = "PDF 批注"
    case whiteboard = "白板"
    case textDocument = "文本文件"
    case quickNote = "Quicknote"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .notebook: return "book.closed"
        case .pdf: return "doc.richtext"
        case .whiteboard: return "infinity"
        case .textDocument: return "doc.text"
        case .quickNote: return "bolt.square"
        }
    }
}

enum DocumentCreationPreset: String, CaseIterable, Identifiable {
    case notebook = "笔记本"
    case pdf = "PDF"
    case scan = "扫描"
    case whiteboard = "白板"
    case textDocument = "文本"
    case quickNote = "Quicknote"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .notebook: return "book.closed"
        case .pdf: return "doc.richtext"
        case .scan: return "doc.viewfinder"
        case .whiteboard: return "infinity"
        case .textDocument: return "doc.text"
        case .quickNote: return "bolt.square"
        }
    }

    var defaultTemplate: PaperTemplate {
        switch self {
        case .notebook: return .ruled
        case .pdf, .scan, .textDocument, .quickNote: return .blank
        case .whiteboard: return .dotted
        }
    }
}

enum LibraryFolder: String, CaseIterable, Codable, Identifiable {
    case documents = "文稿"
    case favorites = "收藏"
    case classes = "课堂"
    case work = "工作"
    case imports = "导入"
    case shared = "共享"
    case trash = "废纸篓"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .documents: return "doc.text"
        case .favorites: return "star"
        case .classes: return "graduationcap"
        case .work: return "briefcase"
        case .imports: return "square.and.arrow.down"
        case .shared: return "person.2"
        case .trash: return "trash"
        }
    }
}

enum PaperTemplate: String, CaseIterable, Codable, Identifiable {
    case blank = "空白"
    case ruled = "横线"
    case grid = "方格"
    case dotted = "点阵"
    case cornell = "康奈尔"
    case planner = "计划"
    case music = "五线谱"

    var id: String { rawValue }
}

enum NotebookCover: String, CaseIterable, Codable, Identifiable {
    case blue
    case green
    case coral
    case ink
    case violet

    var id: String { rawValue }

    var colors: [Color] {
        switch self {
        case .blue: return [Color(red: 0.25, green: 0.48, blue: 0.92), Color(red: 0.58, green: 0.78, blue: 1.0)]
        case .green: return [Color(red: 0.10, green: 0.55, blue: 0.42), Color(red: 0.63, green: 0.87, blue: 0.64)]
        case .coral: return [Color(red: 0.90, green: 0.34, blue: 0.31), Color(red: 0.98, green: 0.72, blue: 0.49)]
        case .ink: return [Color(red: 0.12, green: 0.17, blue: 0.26), Color(red: 0.37, green: 0.43, blue: 0.58)]
        case .violet: return [Color(red: 0.43, green: 0.31, blue: 0.77), Color(red: 0.76, green: 0.62, blue: 0.96)]
        }
    }
}

enum LibraryDisplayMode: String, CaseIterable, Codable, Identifiable {
    case grid = "网格"
    case list = "列表"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

enum WritingTool: String, CaseIterable, Codable, Identifiable {
    case pen = "钢笔"
    case pencil = "铅笔"
    case highlighter = "荧光笔"
    case eraser = "橡皮"
    case lasso = "套索"
    case shapes = "形状"
    case text = "文字"
    case tape = "遮挡"
    case ruler = "直尺"
    case laser = "激光笔"
    case zoom = "缩放"
    case image = "图片"
    case audio = "录音"
    case convert = "转换"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .pen: return "pencil.tip"
        case .pencil: return "pencil"
        case .highlighter: return "highlighter"
        case .eraser: return "eraser"
        case .lasso: return "lasso"
        case .shapes: return "square.on.circle"
        case .text: return "textformat"
        case .tape: return "rectangle.fill.on.rectangle.fill"
        case .ruler: return "ruler"
        case .laser: return "scope"
        case .zoom: return "plus.magnifyingglass"
        case .image: return "photo"
        case .audio: return "mic"
        case .convert: return "function"
        }
    }
}

enum EditorSidePanel: String, CaseIterable, Codable, Identifiable {
    case pages = "页面"
    case content = "内容"
    case audio = "录音"
    case study = "学习"
    case share = "共享"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .pages: return "rectangle.grid.2x2"
        case .content: return "square.stack.3d.up"
        case .audio: return "waveform"
        case .study: return "rectangle.on.rectangle.angled"
        case .share: return "person.2"
        }
    }

    var accessibilityID: String {
        switch self {
        case .pages: return "pages"
        case .content: return "content"
        case .audio: return "audio"
        case .study: return "study"
        case .share: return "share"
        }
    }
}

enum PageManagerFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case bookmarks = "书签"
    case annotated = "批注"
    case outline = "大纲"

    var id: String { rawValue }

    var accessibilityID: String {
        switch self {
        case .all: return "all"
        case .bookmarks: return "bookmarks"
        case .annotated: return "annotated"
        case .outline: return "outline"
        }
    }

    func includes(_ page: NotebookPage) -> Bool {
        switch self {
        case .all:
            return true
        case .bookmarks:
            return page.isBookmarked
        case .annotated:
            return page.hasUserAnnotations
        case .outline:
            return page.outlineTitle != nil
        }
    }
}

enum PageElementKind: String, CaseIterable, Codable, Identifiable {
    case handwriting = "手写"
    case textBox = "文本框"
    case shape = "形状"
    case sticker = "贴纸"
    case image = "图片"
    case tape = "遮挡"
    case math = "数学"
    case laserTrail = "激光轨迹"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .handwriting: return "pencil.tip"
        case .textBox: return "textformat"
        case .shape: return "square.on.circle"
        case .sticker: return "seal"
        case .image: return "photo"
        case .tape: return "rectangle.fill.on.rectangle.fill"
        case .math: return "function"
        case .laserTrail: return "scope"
        }
    }
}

struct PageElement: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: PageElementKind
    var title: String
    var detail: String
    var color: InkSwatch
    var frame: PageElementFrame
    var rotationDegrees: Double
    var scale: Double
    var isLocked: Bool

    init(
        id: UUID = UUID(),
        kind: PageElementKind,
        title: String,
        detail: String,
        color: InkSwatch = .black,
        frame: PageElementFrame = .defaultFrame,
        rotationDegrees: Double = 0,
        scale: Double = 1,
        isLocked: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.color = color
        self.frame = frame
        self.rotationDegrees = rotationDegrees
        self.scale = scale
        self.isLocked = isLocked
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case kind
        case title
        case detail
        case color
        case frame
        case rotationDegrees
        case scale
        case isLocked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decodeIfPresent(PageElementKind.self, forKey: .kind) ?? .handwriting
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? kind.rawValue
        detail = try container.decodeIfPresent(String.self, forKey: .detail) ?? ""
        color = try container.decodeIfPresent(InkSwatch.self, forKey: .color) ?? .black
        // Older local notebooks only stored list metadata. Geometry defaults make
        // those files editable without a migration pass.
        frame = try container.decodeIfPresent(PageElementFrame.self, forKey: .frame) ?? .defaultFrame
        rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? 0
        scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(detail, forKey: .detail)
        try container.encode(color, forKey: .color)
        try container.encode(frame, forKey: .frame)
        try container.encode(rotationDegrees, forKey: .rotationDegrees)
        try container.encode(scale, forKey: .scale)
        try container.encode(isLocked, forKey: .isLocked)
    }
}

struct PageElementFrame: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    static let defaultFrame = PageElementFrame(x: 96, y: 144, width: 240, height: 96)

    var detailText: String {
        "\(Int(x)), \(Int(y)) · \(Int(width))×\(Int(height))"
    }

    func offsetBy(x deltaX: Double, y deltaY: Double) -> PageElementFrame {
        PageElementFrame(x: x + deltaX, y: y + deltaY, width: width, height: height)
    }
}

enum ImportedAssetKind: String, CaseIterable, Codable, Identifiable {
    case pdf = "PDF"
    case powerpoint = "PPT"
    case image = "图片"
    case scan = "扫描"
    case webClip = "网页剪藏"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .pdf: return "doc.richtext"
        case .powerpoint: return "rectangle.on.rectangle"
        case .image: return "photo"
        case .scan: return "doc.viewfinder"
        case .webClip: return "link"
        }
    }
}

struct ImportedAsset: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: ImportedAssetKind
    var title: String
    var pageCount: Int
    var storedFileName: String?
    var byteCount: Int?
    var sourcePageIndex: Int?
    var importedAt: Date?

    var detailText: String {
        var parts = ["\(kind.rawValue) · \(pageCount) 页"]
        if let sourcePageIndex {
            parts.append("源文件第 \(sourcePageIndex + 1) 页")
        }
        if let byteCount {
            parts.append(Self.formattedByteCount(byteCount))
        }
        return parts.joined(separator: " · ")
    }

    init(
        id: UUID = UUID(),
        kind: ImportedAssetKind,
        title: String,
        pageCount: Int = 1,
        storedFileName: String? = nil,
        byteCount: Int? = nil,
        sourcePageIndex: Int? = nil,
        importedAt: Date? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.pageCount = pageCount
        self.storedFileName = storedFileName
        self.byteCount = byteCount
        self.sourcePageIndex = sourcePageIndex
        self.importedAt = importedAt
    }

    private static func formattedByteCount(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}

enum ExportedDocumentKind: String, Codable, Identifiable {
    case pdf = "PDF"

    var id: String { rawValue }
}

struct ExportedDocument: Identifiable, Codable, Hashable {
    let id: UUID
    var kind: ExportedDocumentKind
    var title: String
    var storedFileName: String
    var pageCount: Int
    var byteCount: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        kind: ExportedDocumentKind = .pdf,
        title: String,
        storedFileName: String,
        pageCount: Int,
        byteCount: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.storedFileName = storedFileName
        self.pageCount = pageCount
        self.byteCount = byteCount
        self.createdAt = createdAt
    }

    var detailText: String {
        "\(kind.rawValue) · \(pageCount) 页 · \(ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file))"
    }
}

struct AudioRecording: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var duration: TimeInterval
    var transcript: String
    var linkedPageID: NotebookPage.ID?
    var createdAt: Date
    var storedFileName: String?
    var byteCount: Int?
    var playbackRate: Double?
    var voiceBoostLevel: Double?

    init(
        id: UUID = UUID(),
        title: String,
        duration: TimeInterval,
        transcript: String,
        linkedPageID: NotebookPage.ID? = nil,
        createdAt: Date = Date(),
        storedFileName: String? = nil,
        byteCount: Int? = nil,
        playbackRate: Double? = nil,
        voiceBoostLevel: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.transcript = transcript
        self.linkedPageID = linkedPageID
        self.createdAt = createdAt
        self.storedFileName = storedFileName
        self.byteCount = byteCount
        self.playbackRate = playbackRate
        self.voiceBoostLevel = voiceBoostLevel
    }

    var detailText: String {
        var parts = [
            Self.formattedDuration(duration),
            transcript
        ]
        if let byteCount {
            parts.append(ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file))
        }
        if let playbackRate {
            parts.append("\(playbackRate.formatted(.number.precision(.fractionLength(1))))x")
        }
        return parts.joined(separator: " · ")
    }

    static func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(Int(duration.rounded()), 0)
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }
}

struct AudioMarker: Identifiable, Codable, Hashable {
    let id: UUID
    var recordingID: AudioRecording.ID
    var timestamp: TimeInterval
    var title: String
}

struct StudyCard: Identifiable, Codable, Hashable {
    let id: UUID
    var prompt: String
    var answer: String
    var isStarred: Bool

    init(id: UUID = UUID(), prompt: String, answer: String, isStarred: Bool = false) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
        self.isStarred = isStarred
    }
}

struct StudySet: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var cards: [StudyCard]
    var sourcePageID: NotebookPage.ID?

    init(id: UUID = UUID(), title: String, cards: [StudyCard], sourcePageID: NotebookPage.ID? = nil) {
        self.id = id
        self.title = title
        self.cards = cards
        self.sourcePageID = sourcePageID
    }
}

struct Collaborator: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var role: String
    var color: InkSwatch

    init(id: UUID = UUID(), name: String, role: String, color: InkSwatch) {
        self.id = id
        self.name = name
        self.role = role
        self.color = color
    }
}

struct TemplatePack: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var detail: String
    var templates: [PaperTemplate]
    var isInstalled: Bool

    init(id: UUID = UUID(), title: String, detail: String, templates: [PaperTemplate], isInstalled: Bool = false) {
        self.id = id
        self.title = title
        self.detail = detail
        self.templates = templates
        self.isInstalled = isInstalled
    }
}

enum InkSwatch: String, CaseIterable, Codable, Identifiable {
    case black
    case blue
    case red
    case green
    case orange
    case purple

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .black: return .black
        case .blue: return .blue
        case .red: return .red
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        }
    }
}

enum PlatformDesignGeneration: Equatable {
    case classic
    case liquidGlass26
    case refinedGlass27

    /// Keeps platform branching explicit while the app remains source-compatible.
    static func preferred(majorOSVersion: Int) -> PlatformDesignGeneration {
        if majorOSVersion >= 27 { return .refinedGlass27 }
        if majorOSVersion >= 26 { return .liquidGlass26 }
        return .classic
    }
}

enum WorkspacePane: String, Codable, Identifiable {
    case primary = "主笔记"
    case secondary = "副笔记"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .primary: return "rectangle.leadinghalf.inset.filled"
        case .secondary: return "rectangle.trailinghalf.inset.filled"
        }
    }
}

enum MultiNoteLayout: String, CaseIterable, Codable, Identifiable {
    case horizontal = "右侧打开"
    case vertical = "底部打开"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .horizontal: return "rectangle.split.2x1"
        case .vertical: return "rectangle.split.1x2"
        }
    }
}

@Observable
final class NotebookLibrary {
    private let autosaves: Bool
    private let storageURL: URL

    var selectedFolder: LibraryFolder = .documents
    var selectedNotebookID: Notebook.ID?
    var selectedPageID: NotebookPage.ID?
    var activePane: WorkspacePane = .primary
    var pageManagerRevision = 0
    var isMultiNoteEnabled = false
    var multiNoteLayout: MultiNoteLayout = .horizontal
    var secondaryNotebookID: Notebook.ID?
    var secondaryPageID: NotebookPage.ID?
    var selectedSidePanel: EditorSidePanel = .pages
    var pageManagerFilter: PageManagerFilter = .all
    var isSelectingPages = false
    var selectedPageIDs: Set<NotebookPage.ID> = []
    var selectedElementID: PageElement.ID?
    var copiedElement: PageElement?
    var searchText = ""
    var displayMode: LibraryDisplayMode = .grid
    var activeTool: WritingTool = .pen
    var selectedInk: InkSwatch = .black
    var isRecordingAudio = false
    var activeRecordingStartedAt: Date?
    var activeRecordingFileName: String?
    var activePlaybackRecordingID: AudioRecording.ID?
    var isPlayingAudio = false
    var audioPlaybackPosition: TimeInterval = 0
    var notebooks: [Notebook]
    var templatePacks: [TemplatePack] = TemplatePack.featured

    init(
        notebooks: [Notebook] = NotebookLibrary.samples,
        loadsFromDisk: Bool = false,
        autosaves: Bool = false,
        storageURL: URL = NotebookLibrary.defaultStorageURL
    ) {
        self.autosaves = autosaves
        self.storageURL = storageURL
        let loadedNotebooks = loadsFromDisk ? (try? Self.loadNotebooks(from: storageURL)) : nil
        self.notebooks = loadedNotebooks ?? notebooks
        selectedNotebookID = self.notebooks.first?.id
        selectedPageID = self.notebooks.first?.pages.first?.id
    }

    var visibleNotebooks: [Notebook] {
        notebooks
            .filter { notebook in
                switch selectedFolder {
                case .documents:
                    return notebook.folder != .trash
                case .favorites:
                    return notebook.isFavorite && notebook.folder != .trash
                case .shared:
                    return notebook.isShared && notebook.folder != .trash
                default:
                    return notebook.folder == selectedFolder
                }
            }
            .filter { notebook in
                searchText.isEmpty || notebook.searchableText.localizedStandardContains(searchText)
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    var primaryNotebook: Notebook? {
        guard let selectedNotebookID else { return visibleNotebooks.first ?? notebooks.first }
        return notebooks.first { $0.id == selectedNotebookID }
    }

    var primaryPage: NotebookPage? {
        guard let selectedNotebook = primaryNotebook else { return nil }
        if let selectedPageID, let page = selectedNotebook.pages.first(where: { $0.id == selectedPageID }) {
            return page
        }
        return selectedNotebook.pages.first
    }

    var secondaryNotebook: Notebook? {
        guard isMultiNoteEnabled, let secondaryNotebookID else { return nil }
        return notebooks.first { $0.id == secondaryNotebookID }
    }

    var secondaryPage: NotebookPage? {
        guard let secondaryNotebook else { return nil }
        if let secondaryPageID, let page = secondaryNotebook.pages.first(where: { $0.id == secondaryPageID }) {
            return page
        }
        return secondaryNotebook.pages.first
    }

    var selectedNotebook: Notebook? {
        if activePane == .secondary, let secondaryNotebook {
            return secondaryNotebook
        }
        return primaryNotebook
    }

    var selectedPage: NotebookPage? {
        if activePane == .secondary, let secondaryPage {
            return secondaryPage
        }
        return primaryPage
    }

    var selectedElement: PageElement? {
        guard let selectedElementID, let page = selectedPage else { return nil }
        return page.elements.first { $0.id == selectedElementID }
    }

    var hasCopiedElement: Bool {
        copiedElement != nil
    }

    var canTransferPagesToOtherPane: Bool {
        isMultiNoteEnabled && transferDestinationNotebookIndex != nil
    }

    var canMovePagesToOtherPane: Bool {
        guard canTransferPagesToOtherPane, let notebookIndex = currentNotebookIndex else { return false }
        let pageCount = notebooks[notebookIndex].pages.count
        let transferCount = pageTransferIndexes(in: notebookIndex).count
        return transferCount > 0 && pageCount > transferCount
    }

    var canTransferSelectedElementToOtherPane: Bool {
        isMultiNoteEnabled && selectedElement != nil && transferDestinationPageIndexes != nil
    }

    var canDeleteCurrentPage: Bool {
        (selectedNotebook?.pages.count ?? 0) > 1
    }

    var selectedPageCount: Int {
        selectedPageIDs.count
    }

    var hasSelectedPages: Bool {
        !selectedPageIDs.isEmpty
    }

    var canMoveCurrentPageUp: Bool {
        guard let pageIndex = currentPageIndex else { return false }
        return pageIndex > 0
    }

    var canMoveCurrentPageDown: Bool {
        guard let notebookIndex = currentNotebookIndex, let pageIndex = currentPageIndex else { return false }
        return pageIndex < notebooks[notebookIndex].pages.count - 1
    }

    var canDeleteSelectedPages: Bool {
        guard let notebook = selectedNotebook else { return false }
        return !selectedPageIDs.isEmpty && selectedPageIDs.count < notebook.pages.count
    }

    var activePlaybackRecording: AudioRecording? {
        guard let activePlaybackRecordingID else { return selectedNotebook?.recordings.first }
        return selectedNotebook?.recordings.first { $0.id == activePlaybackRecordingID }
    }

    func select(_ notebook: Notebook) {
        if activePane == .secondary, isMultiNoteEnabled {
            secondaryNotebookID = notebook.id
            secondaryPageID = notebook.pages.first?.id
        } else {
            selectedNotebookID = notebook.id
            selectedPageID = notebook.pages.first?.id
            activePane = .primary
        }
        selectedElementID = nil
        clearPageSelection()
    }

    func selectPage(_ pageID: NotebookPage.ID, in pane: WorkspacePane? = nil) {
        let resolvedPane = pane ?? activePane
        if resolvedPane == .secondary, isMultiNoteEnabled {
            guard secondaryNotebook?.pages.contains(where: { $0.id == pageID }) == true else { return }
            activePane = .secondary
            secondaryPageID = pageID
        } else {
            guard primaryNotebook?.pages.contains(where: { $0.id == pageID }) == true else { return }
            activePane = .primary
            selectedPageID = pageID
        }
        selectedElementID = nil
        clearPageSelection()
    }

    func activatePane(_ pane: WorkspacePane) {
        guard pane == .primary || secondaryNotebook != nil else { return }
        activePane = pane
        selectedElementID = nil
        clearPageSelection()
    }

    func openNextNotebookInMultiNote(layout: MultiNoteLayout = .horizontal) {
        let fallbackNotebook = primaryNotebook ?? notebooks.first
        let candidate = notebooks.first { notebook in
            notebook.id != selectedNotebookID && notebook.folder != .trash
        } ?? fallbackNotebook
        guard let candidate else { return }
        openNotebookInMultiNote(candidate, layout: layout)
    }

    func openNotebookInMultiNote(_ notebook: Notebook, layout: MultiNoteLayout = .horizontal) {
        if selectedNotebookID == nil {
            selectedNotebookID = notebook.id
            selectedPageID = notebook.pages.first?.id
        }
        secondaryNotebookID = notebook.id
        secondaryPageID = notebook.pages.first(where: { $0.id != selectedPageID })?.id ?? notebook.pages.first?.id
        isMultiNoteEnabled = true
        multiNoteLayout = layout
        activePane = .secondary
        selectedElementID = nil
        clearPageSelection()
    }

    func closeMultiNote() {
        isMultiNoteEnabled = false
        secondaryNotebookID = nil
        secondaryPageID = nil
        activePane = .primary
        selectedElementID = nil
        clearPageSelection()
    }

    func setMultiNoteLayout(_ layout: MultiNoteLayout) {
        guard isMultiNoteEnabled else {
            openNextNotebookInMultiNote(layout: layout)
            return
        }
        multiNoteLayout = layout
    }

    func createDocument(_ preset: DocumentCreationPreset, template: PaperTemplate? = nil) {
        let resolvedTemplate = template ?? preset.defaultTemplate

        switch preset {
        case .notebook:
            createNotebook(template: resolvedTemplate)
        case .pdf:
            importDocumentStub(kind: .pdf)
        case .scan:
            importDocumentStub(kind: .scan)
        case .whiteboard:
            createNotebook(kind: .whiteboard, title: "无限白板", subject: "白板", cover: .violet, template: resolvedTemplate)
        case .textDocument:
            createNotebook(kind: .textDocument, title: "文本文件", subject: "文稿", cover: .ink, template: resolvedTemplate)
        case .quickNote:
            createNotebook(kind: .quickNote, title: "Quicknote", subject: "速记", template: resolvedTemplate)
        }
    }

    func createNotebook(
        kind: NotebookKind = .notebook,
        title: String? = nil,
        subject: String = "新建",
        folder: LibraryFolder? = nil,
        cover: NotebookCover? = nil,
        template: PaperTemplate = .ruled
    ) {
        let resolvedTitle = title ?? Self.defaultTitle(for: kind)
        let page = NotebookPage(
            id: UUID(),
            title: kind == .whiteboard ? "无限画布" : "第一页",
            template: template,
            previewLines: Self.defaultPreviewLines(for: kind),
            elements: kind == .textDocument ? [
                PageElement(kind: .textBox, title: "正文", detail: "点击页面任意位置开始输入。")
            ] : []
        )
        let notebook = Notebook(
            id: UUID(),
            kind: kind,
            title: resolvedTitle,
            subject: subject,
            folder: folder ?? (selectedFolder == .trash || selectedFolder == .favorites || selectedFolder == .shared ? .documents : selectedFolder),
            cover: cover ?? NotebookCover.allCases.randomElement() ?? .blue,
            modifiedAt: Date(),
            isFavorite: false,
            pages: [page]
        )
        notebooks.insert(notebook, at: 0)
        select(notebook)
        persistIfNeeded()
    }

    func createQuickNote() {
        createNotebook(kind: .quickNote, title: "Quicknote", subject: "速记", template: .blank)
    }

    func createWhiteboard() {
        createNotebook(kind: .whiteboard, title: "无限白板", subject: "白板", cover: .violet, template: .dotted)
    }

    func createTextDocument() {
        createNotebook(kind: .textDocument, title: "文本文件", subject: "文稿", cover: .ink, template: .blank)
    }

    func importDocumentStub(kind: ImportedAssetKind = .pdf) {
        createNotebook(kind: .pdf, title: kind == .scan ? "扫描文稿" : "导入的 \(kind.rawValue)", subject: "导入", folder: .imports, cover: .ink, template: .blank)
        addAsset(kind: kind, title: kind == .scan ? "课堂扫描.pdf" : "课程资料.\(kind.rawValue.lowercased())", pageCount: kind == .pdf ? 12 : 3)
    }

    @discardableResult
    func importExternalFile(at url: URL) throws -> Notebook.ID {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        if Self.isAudioFile(url) {
            return try importAudioFile(data: data, originalFileName: url.lastPathComponent)
        }

        let storedFileName = try Self.storeImportedFile(data: data, originalFileName: url.lastPathComponent, beside: storageURL)
        let summary = Self.importSummary(for: url, data: data, storedFileName: storedFileName)

        switch summary.kind {
        case .pdf:
            return importPDF(summary)
        case .image, .scan:
            return importImage(summary)
        case .powerpoint, .webClip:
            createNotebook(kind: .pdf, title: summary.displayTitle, subject: "导入", folder: .imports, cover: .ink, template: .blank)
            addAsset(
                kind: summary.kind,
                title: summary.originalFileName,
                pageCount: summary.pageCount,
                storedFileName: summary.storedFileName,
                byteCount: summary.byteCount
            )
            return selectedNotebookID ?? notebooks[0].id
        }
    }

    @discardableResult
    func importExternalFiles(_ urls: [URL]) throws -> [Notebook.ID] {
        try urls.map { try importExternalFile(at: $0) }
    }

    private func importPDF(_ summary: ImportedFileSummary) -> Notebook.ID {
        let pdfDocument = PDFDocument(data: summary.data)
        let pageCount = max(pdfDocument?.pageCount ?? summary.pageCount, 1)
        let pages = (0..<pageCount).map { pageIndex in
            let pdfText = pdfDocument?.page(at: pageIndex)?.string.flatMap(Self.compactPreviewText)
            let previewLines = [
                "PDF · \(summary.originalFileName)",
                "第 \(pageIndex + 1) / \(pageCount) 页",
                pdfText ?? ""
            ].filter { !$0.isEmpty }
            let asset = ImportedAsset(
                kind: .pdf,
                title: summary.originalFileName,
                pageCount: pageCount,
                storedFileName: summary.storedFileName,
                byteCount: summary.byteCount,
                sourcePageIndex: pageIndex,
                importedAt: Date()
            )
            return NotebookPage(
                id: UUID(),
                title: pageIndex == 0 ? "PDF 首页" : "PDF 第 \(pageIndex + 1) 页",
                template: .blank,
                previewLines: previewLines,
                assets: [asset]
            )
        }
        let notebook = Notebook(
            id: UUID(),
            kind: .pdf,
            title: summary.displayTitle,
            subject: "导入",
            folder: .imports,
            cover: .ink,
            modifiedAt: Date(),
            isFavorite: false,
            pages: pages
        )
        notebooks.insert(notebook, at: 0)
        select(notebook)
        selectedFolder = .imports
        selectedSidePanel = .pages
        persistIfNeeded()
        return notebook.id
    }

    private func importImage(_ summary: ImportedFileSummary) -> Notebook.ID {
        if selectedNotebook == nil {
            createNotebook(title: summary.displayTitle, subject: "导入", folder: .imports, cover: .coral, template: .blank)
        }
        addAsset(
            kind: .image,
            title: summary.originalFileName,
            pageCount: 1,
            storedFileName: summary.storedFileName,
            byteCount: summary.byteCount
        )
        if let indexes = selectedIndexes {
            let element = PageElement(
                kind: .image,
                title: summary.displayTitle,
                detail: "已从文件导入，可移动、缩放并与墨迹分层。",
                color: selectedInk,
                frame: PageElementFrame(x: 120, y: 160, width: 300, height: 200)
            )
            notebooks[indexes.notebook].pages[indexes.page].elements.append(element)
            notebooks[indexes.notebook].modifiedAt = Date()
            selectedElementID = element.id
            selectedSidePanel = .content
            persistIfNeeded()
        }
        return selectedNotebook?.id ?? notebooks[0].id
    }

    func addPage(template: PaperTemplate = .ruled) {
        guard let notebookIndex = currentNotebookIndex else { return }
        let pageNumber = notebooks[notebookIndex].pages.count + 1
        let page = NotebookPage(id: UUID(), title: "第 \(pageNumber) 页", template: template, previewLines: [])
        notebooks[notebookIndex].pages.append(page)
        notebooks[notebookIndex].modifiedAt = Date()
        setCurrentPageID(page.id)
        selectedElementID = nil
        selectedSidePanel = .pages
        persistIfNeeded()
    }

    func changeCurrentPageTemplate(to template: PaperTemplate) {
        guard let indexes = selectedIndexes else { return }
        guard notebooks[indexes.notebook].pages[indexes.page].template != template else { return }
        notebooks[indexes.notebook].pages[indexes.page].template = template
        notebooks[indexes.notebook].modifiedAt = Date()
        selectedSidePanel = .pages
        persistIfNeeded()
    }

    func rotateCurrentOrSelectedPagesClockwise() {
        rotateCurrentOrSelectedPages(by: 90)
    }

    func rotateCurrentOrSelectedPagesCounterclockwise() {
        rotateCurrentOrSelectedPages(by: -90)
    }

    func rotateCurrentOrSelectedPages(by degrees: Int) {
        guard let notebookIndex = currentNotebookIndex else { return }
        let indexes = pageTransferIndexes(in: notebookIndex)
        guard !indexes.isEmpty else { return }

        for pageIndex in indexes {
            let currentRotation = notebooks[notebookIndex].pages[pageIndex].rotationDegrees
            notebooks[notebookIndex].pages[pageIndex].rotationDegrees = NotebookPage.normalizedRotationDegrees(currentRotation + degrees)
        }
        notebooks[notebookIndex].modifiedAt = Date()
        selectedSidePanel = .pages
        persistIfNeeded()
    }

    func duplicateCurrentPage() {
        guard let indexes = selectedIndexes else { return }
        let currentPage = notebooks[indexes.notebook].pages[indexes.page]
        let duplicatedPage = Self.duplicatedPage(from: currentPage)
        notebooks[indexes.notebook].pages.insert(duplicatedPage, at: indexes.page + 1)
        notebooks[indexes.notebook].modifiedAt = Date()
        setCurrentPageID(duplicatedPage.id)
        selectedElementID = nil
        selectedSidePanel = .pages
        persistIfNeeded()
    }

    func deleteCurrentPage() {
        guard let indexes = selectedIndexes, notebooks[indexes.notebook].pages.count > 1 else { return }
        notebooks[indexes.notebook].pages.remove(at: indexes.page)
        let nextPageIndex = min(indexes.page, notebooks[indexes.notebook].pages.count - 1)
        setCurrentPageID(notebooks[indexes.notebook].pages[nextPageIndex].id)
        selectedElementID = nil
        notebooks[indexes.notebook].modifiedAt = Date()
        selectedSidePanel = .pages
        persistIfNeeded()
    }

    func setPageSelectionMode(_ isSelecting: Bool) {
        isSelectingPages = isSelecting
        if isSelecting {
            selectedPageIDs = currentPageID.map { [$0] } ?? []
        } else {
            selectedPageIDs.removeAll()
        }
    }

    func togglePageSelection(_ pageID: NotebookPage.ID) {
        isSelectingPages = true
        if selectedPageIDs.contains(pageID) {
            selectedPageIDs.remove(pageID)
        } else {
            selectedPageIDs.insert(pageID)
        }
        setCurrentPageID(pageID)
    }

    func selectAllPages() {
        guard let notebookIndex = currentNotebookIndex else { return }
        selectPages(Set(notebooks[notebookIndex].pages.map(\.id)))
    }

    func selectPages(_ pageIDs: Set<NotebookPage.ID>) {
        guard let notebookIndex = currentNotebookIndex else { return }
        let orderedPageIDs = notebooks[notebookIndex].pages.map(\.id)
        let validPageIDs = Set(orderedPageIDs.filter { pageIDs.contains($0) })
        guard !validPageIDs.isEmpty else { return }

        isSelectingPages = true
        selectedPageIDs = validPageIDs
        if let firstVisibleSelection = orderedPageIDs.first(where: { validPageIDs.contains($0) }) {
            setCurrentPageID(firstVisibleSelection)
        }
        selectedSidePanel = .pages
    }

    func toggleCurrentPageOutline() {
        guard let notebookIndex = currentNotebookIndex,
              let pageIndex = currentPageIndex ?? notebooks[notebookIndex].pages.indices.first else {
            return
        }
        if notebooks[notebookIndex].pages[pageIndex].outlineTitle == nil {
            notebooks[notebookIndex].pages[pageIndex].outlineTitle = notebooks[notebookIndex].pages[pageIndex].title
        } else {
            notebooks[notebookIndex].pages[pageIndex].outlineTitle = nil
        }
        setCurrentPageID(notebooks[notebookIndex].pages[pageIndex].id)
        notebooks[notebookIndex].modifiedAt = Date()
        selectedSidePanel = .pages
        pageManagerFilter = .outline
        pageManagerRevision += 1
        persistIfNeeded()
    }

    func clearPageSelection() {
        isSelectingPages = false
        selectedPageIDs.removeAll()
    }

    func moveCurrentPageUp() {
        guard let indexes = selectedIndexes, indexes.page > 0 else { return }
        movePage(in: indexes.notebook, from: indexes.page, to: indexes.page - 1)
    }

    func moveCurrentPageDown() {
        guard let indexes = selectedIndexes, indexes.page < notebooks[indexes.notebook].pages.count - 1 else { return }
        movePage(in: indexes.notebook, from: indexes.page, to: indexes.page + 1)
    }

    func moveSelectedPagesUp() {
        moveSelectedPages(direction: -1)
    }

    func moveSelectedPagesDown() {
        moveSelectedPages(direction: 1)
    }

    func movePageOrSelectedPages(draggedPageID: NotebookPage.ID, before destinationPageID: NotebookPage.ID) {
        movePageGroup(draggedPageID: draggedPageID, destinationPageID: destinationPageID, placesAtEnd: false)
    }

    func movePageOrSelectedPagesToEnd(draggedPageID: NotebookPage.ID) {
        movePageGroup(draggedPageID: draggedPageID, destinationPageID: nil, placesAtEnd: true)
    }

    func duplicateSelectedPages() {
        guard let notebookIndex = currentNotebookIndex else { return }
        let indexes = selectedPageIndexes(in: notebookIndex)
        guard !indexes.isEmpty else {
            duplicateCurrentPage()
            return
        }

        let duplicatedPages = indexes.map { Self.duplicatedPage(from: notebooks[notebookIndex].pages[$0]) }
        let insertionIndex = (indexes.last ?? notebooks[notebookIndex].pages.endIndex - 1) + 1
        notebooks[notebookIndex].pages.insert(contentsOf: duplicatedPages, at: insertionIndex)
        notebooks[notebookIndex].modifiedAt = Date()
        if let firstDuplicatedID = duplicatedPages.first?.id {
            setCurrentPageID(firstDuplicatedID)
        }
        if isSelectingPages {
            selectedPageIDs = Set(duplicatedPages.map(\.id))
        }
        selectedSidePanel = .pages
        persistIfNeeded()
    }

    func copyPagesToOtherPane() {
        transferPagesToOtherPane(removesFromSource: false)
    }

    func movePagesToOtherPane() {
        transferPagesToOtherPane(removesFromSource: true)
    }

    func clearSelectedPagesContent() {
        guard let notebookIndex = currentNotebookIndex else { return }
        let indexes = selectedPageIndexes(in: notebookIndex)
        let targetIndexes = indexes.isEmpty ? currentPageIndex.map { [$0] } ?? [] : indexes
        guard !targetIndexes.isEmpty else { return }

        for pageIndex in targetIndexes {
            clearContent(of: &notebooks[notebookIndex].pages[pageIndex])
        }
        notebooks[notebookIndex].modifiedAt = Date()
        selectedElementID = nil
        selectedSidePanel = .pages
        persistIfNeeded()
    }

    func deleteSelectedPages() {
        guard let notebookIndex = currentNotebookIndex else { return }
        let indexes = selectedPageIndexes(in: notebookIndex)
        guard !indexes.isEmpty, indexes.count < notebooks[notebookIndex].pages.count else { return }

        let fallbackIndex = min(indexes.first ?? 0, notebooks[notebookIndex].pages.count - indexes.count - 1)
        let idsToDelete = Set(indexes.map { notebooks[notebookIndex].pages[$0].id })
        notebooks[notebookIndex].pages.removeAll { idsToDelete.contains($0.id) }
        setCurrentPageID(notebooks[notebookIndex].pages[fallbackIndex].id)
        selectedPageIDs.removeAll()
        selectedElementID = nil
        isSelectingPages = false
        notebooks[notebookIndex].modifiedAt = Date()
        selectedSidePanel = .pages
        persistIfNeeded()
    }

    func toggleFavorite(_ notebook: Notebook) {
        guard let index = notebooks.firstIndex(where: { $0.id == notebook.id }) else { return }
        notebooks[index].isFavorite.toggle()
        notebooks[index].modifiedAt = Date()
        persistIfNeeded()
    }

    func toggleCurrentPageBookmark() {
        guard let indexes = selectedIndexes else { return }
        notebooks[indexes.notebook].pages[indexes.page].isBookmarked.toggle()
        notebooks[indexes.notebook].modifiedAt = Date()
        persistIfNeeded()
    }

    func addElement(kind: PageElementKind, title: String? = nil) {
        guard let indexes = selectedIndexes else { return }
        let currentCount = notebooks[indexes.notebook].pages[indexes.page].elements.count
        let element = PageElement(
            kind: kind,
            title: title ?? kind.rawValue,
            detail: Self.defaultElementDetail(for: kind),
            color: selectedInk,
            frame: PageElementFrame(x: 96 + Double((currentCount % 3) * 28), y: 144 + Double((currentCount % 4) * 28), width: 240, height: 96)
        )
        notebooks[indexes.notebook].pages[indexes.page].elements.append(element)
        notebooks[indexes.notebook].modifiedAt = Date()
        selectedElementID = element.id
        selectedSidePanel = .content
        persistIfNeeded()
    }

    func selectElement(_ element: PageElement) {
        selectElement(id: element.id)
    }

    func selectElement(id: PageElement.ID) {
        guard selectedPage?.elements.contains(where: { $0.id == id }) == true else { return }
        selectedElementID = id
        activeTool = .lasso
        selectedSidePanel = .content
    }

    func clearElementSelection() {
        selectedElementID = nil
    }

    func moveSelectedElementBy(x deltaX: Double, y deltaY: Double) {
        mutateSelectedElement { element in
            element.frame = element.frame.offsetBy(x: deltaX, y: deltaY)
        }
    }

    func scaleSelectedElement(by factor: Double) {
        mutateSelectedElement { element in
            let nextScale = min(max(element.scale * factor, 0.25), 4)
            let appliedFactor = nextScale / max(element.scale, 0.01)
            element.scale = nextScale
            element.frame.width = min(max(element.frame.width * appliedFactor, 48), 900)
            element.frame.height = min(max(element.frame.height * appliedFactor, 32), 900)
        }
    }

    func rotateSelectedElement(by degrees: Double) {
        mutateSelectedElement { element in
            let nextRotation = (element.rotationDegrees + degrees).truncatingRemainder(dividingBy: 360)
            element.rotationDegrees = nextRotation < 0 ? nextRotation + 360 : nextRotation
        }
    }

    func toggleSelectedElementLock() {
        mutateSelectedElement(allowsLocked: true) { element in
            element.isLocked.toggle()
        }
    }

    func copySelectedElement() {
        guard let indexes = selectedElementIndexes else { return }
        copiedElement = notebooks[indexes.notebook].pages[indexes.page].elements[indexes.element]
        selectedSidePanel = .content
    }

    func duplicateSelectedElement() {
        guard let indexes = selectedElementIndexes else { return }
        let source = notebooks[indexes.notebook].pages[indexes.page].elements[indexes.element]
        let duplicate = Self.duplicatedElement(from: source, titleSuffix: "副本", offset: 24)
        notebooks[indexes.notebook].pages[indexes.page].elements.insert(duplicate, at: indexes.element + 1)
        notebooks[indexes.notebook].modifiedAt = Date()
        selectedElementID = duplicate.id
        selectedSidePanel = .content
        persistIfNeeded()
    }

    func cutSelectedElement() {
        guard let indexes = selectedElementIndexes else { return }
        let element = notebooks[indexes.notebook].pages[indexes.page].elements[indexes.element]
        guard !element.isLocked else { return }
        copiedElement = element
        notebooks[indexes.notebook].pages[indexes.page].elements.remove(at: indexes.element)
        notebooks[indexes.notebook].modifiedAt = Date()
        selectedElementID = nil
        selectedSidePanel = .content
        persistIfNeeded()
    }

    func pasteCopiedElement() {
        guard let indexes = selectedIndexes, let copiedElement else { return }
        let pasted = Self.duplicatedElement(from: copiedElement, titleSuffix: "粘贴", offset: 32)
        notebooks[indexes.notebook].pages[indexes.page].elements.append(pasted)
        notebooks[indexes.notebook].modifiedAt = Date()
        selectedElementID = pasted.id
        selectedSidePanel = .content
        persistIfNeeded()
    }

    func deleteSelectedElement() {
        guard let indexes = selectedElementIndexes else { return }
        guard !notebooks[indexes.notebook].pages[indexes.page].elements[indexes.element].isLocked else { return }
        notebooks[indexes.notebook].pages[indexes.page].elements.remove(at: indexes.element)
        notebooks[indexes.notebook].modifiedAt = Date()
        selectedElementID = nil
        selectedSidePanel = .content
        persistIfNeeded()
    }

    func copySelectedElementToOtherPane() {
        transferSelectedElementToOtherPane(removesFromSource: false)
    }

    func moveSelectedElementToOtherPane() {
        transferSelectedElementToOtherPane(removesFromSource: true)
    }

    func addAsset(
        kind: ImportedAssetKind,
        title: String,
        pageCount: Int,
        storedFileName: String? = nil,
        byteCount: Int? = nil,
        sourcePageIndex: Int? = nil
    ) {
        guard let indexes = selectedIndexes else { return }
        let asset = ImportedAsset(
            kind: kind,
            title: title,
            pageCount: pageCount,
            storedFileName: storedFileName,
            byteCount: byteCount,
            sourcePageIndex: sourcePageIndex,
            importedAt: Date()
        )
        notebooks[indexes.notebook].pages[indexes.page].assets.append(asset)
        notebooks[indexes.notebook].pages[indexes.page].previewLines.append("\(kind.rawValue) · \(title)")
        notebooks[indexes.notebook].modifiedAt = Date()
        selectedSidePanel = .content
        persistIfNeeded()
    }

    func toggleAudioRecording() {
        if isRecordingAudio {
            finishAudioRecording()
        } else {
            beginAudioRecording()
        }
    }

    func beginAudioRecording(storedFileName: String? = nil, startedAt: Date = Date()) {
        activeRecordingStartedAt = startedAt
        activeRecordingFileName = storedFileName
        isRecordingAudio = true
        activeTool = .audio
        selectedSidePanel = .audio
    }

    func finishAudioRecording(
        storedFileName: String? = nil,
        duration: TimeInterval? = nil,
        byteCount: Int? = nil,
        transcript: String = "这里会保存课堂或会议录音的实时转写，并与书写时间线对应。"
    ) {
        guard let notebookIndex = currentNotebookIndex else { return }
        let resolvedDuration = duration ?? activeRecordingStartedAt.map { max(Date().timeIntervalSince($0), 6) } ?? 42
        let recording = AudioRecording(
            title: "录音 \(notebooks[notebookIndex].recordings.count + 1)",
            duration: resolvedDuration,
            transcript: transcript,
            linkedPageID: currentPageID,
            storedFileName: storedFileName ?? activeRecordingFileName,
            byteCount: byteCount,
            playbackRate: 1.0,
            voiceBoostLevel: 0
        )
        notebooks[notebookIndex].recordings.append(recording)
        if let pageIndex = currentPageIndex {
            notebooks[notebookIndex].pages[pageIndex].audioMarkers.append(
                AudioMarker(id: UUID(), recordingID: recording.id, timestamp: resolvedDuration, title: "书写同步点")
            )
            notebooks[notebookIndex].pages[pageIndex].transcriptSummary = "录音已链接到本页，可回放并同步定位书写内容。"
        }
        notebooks[notebookIndex].modifiedAt = Date()
        isRecordingAudio = false
        activeRecordingStartedAt = nil
        activeRecordingFileName = nil
        selectedSidePanel = .audio
        persistIfNeeded()
    }

    func selectAudioRecording(_ recording: AudioRecording) {
        activePlaybackRecordingID = recording.id
        audioPlaybackPosition = min(audioPlaybackPosition, recording.duration)
        selectedSidePanel = .audio
    }

    func toggleAudioPlayback(for recording: AudioRecording? = nil) {
        if let recording {
            if activePlaybackRecordingID != recording.id {
                activePlaybackRecordingID = recording.id
                audioPlaybackPosition = 0
            }
        } else if activePlaybackRecordingID == nil {
            activePlaybackRecordingID = selectedNotebook?.recordings.first?.id
            audioPlaybackPosition = 0
        }

        guard activePlaybackRecording != nil else { return }
        isPlayingAudio.toggle()
        selectedSidePanel = .audio
    }

    func stopAudioPlayback() {
        isPlayingAudio = false
    }

    func seekAudio(to position: TimeInterval) {
        guard let recording = activePlaybackRecording else { return }
        audioPlaybackPosition = min(max(position, 0), recording.duration)
        if let pageID = nearestPageID(for: recording, at: audioPlaybackPosition) ?? currentPageID {
            setCurrentPageID(pageID)
        }
        selectedSidePanel = .audio
    }

    func skipAudio(by interval: TimeInterval) {
        seekAudio(to: audioPlaybackPosition + interval)
    }

    func setAudioPlaybackRate(_ rate: Double, for recordingID: AudioRecording.ID? = nil) {
        updateRecording(recordingID ?? activePlaybackRecordingID) { recording in
            recording.playbackRate = min(max(rate, 0.5), 2.0)
        }
    }

    func setVoiceBoostLevel(_ level: Double, for recordingID: AudioRecording.ID? = nil) {
        updateRecording(recordingID ?? activePlaybackRecordingID) { recording in
            recording.voiceBoostLevel = min(max(level, 0), 1)
        }
    }

    func createStudySetFromCurrentPage() {
        guard let notebookIndex = currentNotebookIndex else { return }
        let page = selectedPage
        let title = "学习卡 · \(page?.title ?? "当前页")"
        let cards = [
            StudyCard(prompt: "这页的核心概念是什么？", answer: page?.previewLines.first ?? "从页面内容提炼重点。", isStarred: true),
            StudyCard(prompt: "有哪些待复习问题？", answer: "从批注、录音和手写内容生成复习提示。")
        ]
        notebooks[notebookIndex].studySets.append(StudySet(title: title, cards: cards, sourcePageID: page?.id))
        notebooks[notebookIndex].modifiedAt = Date()
        selectedSidePanel = .study
        persistIfNeeded()
    }

    func convertSelectionToText() {
        addElement(kind: .textBox, title: "手写转文字")
    }

    func convertSelectionToMath() {
        addElement(kind: .math, title: "数学转换")
    }

    func shareCurrentNotebook() {
        guard let notebookIndex = currentNotebookIndex else { return }
        notebooks[notebookIndex].isShared = true
        if notebooks[notebookIndex].collaborators.isEmpty {
            notebooks[notebookIndex].collaborators = [
                Collaborator(name: "我", role: "所有者", color: .blue),
                Collaborator(name: "协作者", role: "可编辑", color: .green)
            ]
        }
        selectedSidePanel = .share
        notebooks[notebookIndex].modifiedAt = Date()
        persistIfNeeded()
    }

    func updateDrawingData(_ data: Data, for pageID: NotebookPage.ID) {
        guard let notebookIndex = notebooks.firstIndex(where: { notebook in
            notebook.pages.contains { $0.id == pageID }
        }), let pageIndex = notebooks[notebookIndex].pages.firstIndex(where: { $0.id == pageID }) else {
            return
        }

        guard notebooks[notebookIndex].pages[pageIndex].drawingData != data else { return }
        notebooks[notebookIndex].pages[pageIndex].drawingData = data
        notebooks[notebookIndex].modifiedAt = Date()
        persistIfNeeded()
    }

    func pdfBackgroundAsset(for page: NotebookPage?) -> ImportedAsset? {
        page?.assets.first { asset in
            asset.kind == .pdf && asset.storedFileName != nil && asset.sourcePageIndex != nil
        }
    }

    func fileURL(for asset: ImportedAsset) -> URL? {
        guard let storedFileName = asset.storedFileName else { return nil }
        return Self.importsDirectory(beside: storageURL).appendingPathComponent(storedFileName)
    }

    func fileURL(for exportedDocument: ExportedDocument) -> URL {
        Self.exportsDirectory(beside: storageURL).appendingPathComponent(exportedDocument.storedFileName)
    }

    func fileURL(for recording: AudioRecording) -> URL? {
        guard let storedFileName = recording.storedFileName else { return nil }
        return Self.recordingsDirectory(beside: storageURL).appendingPathComponent(storedFileName)
    }

    func createRecordingDestination(fileExtension: String = "m4a") throws -> (storedFileName: String, url: URL) {
        let directory = Self.recordingsDirectory(beside: storageURL)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storedFileName = "\(UUID().uuidString)-Recording.\(fileExtension)"
        return (storedFileName, directory.appendingPathComponent(storedFileName))
    }

    @discardableResult
    func exportCurrentNotebookToPDF() throws -> ExportedDocument {
        guard let notebookIndex = currentNotebookIndex else {
            throw NotebookLibraryError.noSelectedNotebook
        }

        let notebook = notebooks[notebookIndex]
        let pdfData = try renderPDFData(title: notebook.title, pages: notebook.pages)
        let exportedFileName = "\(UUID().uuidString)-\(Self.sanitizedFileName(notebook.title)).pdf"
        let exportURL = Self.exportsDirectory(beside: storageURL).appendingPathComponent(exportedFileName)
        try FileManager.default.createDirectory(at: exportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pdfData.write(to: exportURL, options: [.atomic])

        let exportedDocument = ExportedDocument(
            title: "\(notebook.title).pdf",
            storedFileName: exportedFileName,
            pageCount: notebook.pages.count,
            byteCount: pdfData.count
        )
        notebooks[notebookIndex].exportedDocuments.insert(exportedDocument, at: 0)
        notebooks[notebookIndex].modifiedAt = Date()
        selectedSidePanel = .share
        persistIfNeeded()
        return exportedDocument
    }

    @discardableResult
    func exportCurrentOrSelectedPagesToPDF() throws -> ExportedDocument {
        guard let notebookIndex = currentNotebookIndex else {
            throw NotebookLibraryError.noSelectedNotebook
        }

        let notebook = notebooks[notebookIndex]
        let indexes = pageTransferIndexes(in: notebookIndex)
        guard !indexes.isEmpty else {
            throw NotebookLibraryError.noSelectedNotebook
        }

        let pages = indexes.map { notebook.pages[$0] }
        let exportTitle = pageExportTitle(for: notebook, pages: pages)
        let pdfData = try renderPDFData(title: exportTitle, pages: pages)
        let exportedFileName = "\(UUID().uuidString)-\(Self.sanitizedFileName(exportTitle)).pdf"
        let exportURL = Self.exportsDirectory(beside: storageURL).appendingPathComponent(exportedFileName)
        try FileManager.default.createDirectory(at: exportURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pdfData.write(to: exportURL, options: [.atomic])

        let exportedDocument = ExportedDocument(
            title: "\(exportTitle).pdf",
            storedFileName: exportedFileName,
            pageCount: pages.count,
            byteCount: pdfData.count
        )
        notebooks[notebookIndex].exportedDocuments.insert(exportedDocument, at: 0)
        notebooks[notebookIndex].modifiedAt = Date()
        selectedSidePanel = .share
        persistIfNeeded()
        return exportedDocument
    }

    @discardableResult
    private func importAudioFile(data: Data, originalFileName: String) throws -> Notebook.ID {
        if selectedNotebook == nil {
            createNotebook(kind: .notebook, title: "音频笔记", subject: "导入", folder: .imports, cover: .green, template: .ruled)
        }

        let storedFileName = try Self.storeRecordingFile(data: data, originalFileName: originalFileName, beside: storageURL)
        let audioURL = Self.recordingsDirectory(beside: storageURL).appendingPathComponent(storedFileName)
        let duration = (try? AVAudioPlayer(contentsOf: audioURL))?.duration ?? 0
        guard let notebookIndex = currentNotebookIndex else { return notebooks[0].id }

        let recording = AudioRecording(
            title: audioURL.deletingPathExtension().lastPathComponent,
            duration: duration,
            transcript: "已导入外部音频，可与当前页书写内容建立同步点。",
            linkedPageID: currentPageID,
            storedFileName: storedFileName,
            byteCount: data.count,
            playbackRate: 1.0,
            voiceBoostLevel: 0
        )
        notebooks[notebookIndex].recordings.append(recording)
        if let pageIndex = currentPageIndex {
            notebooks[notebookIndex].pages[pageIndex].audioMarkers.append(
                AudioMarker(id: UUID(), recordingID: recording.id, timestamp: 0, title: "导入音频")
            )
            notebooks[notebookIndex].pages[pageIndex].transcriptSummary = "外部音频已链接到本页，可用于复听与定位。"
        }
        notebooks[notebookIndex].modifiedAt = Date()
        selectedSidePanel = .audio
        persistIfNeeded()
        return notebooks[notebookIndex].id
    }

    func saveNow() throws {
        try Self.save(notebooks, to: storageURL)
    }

    func reloadFromDisk() throws {
        notebooks = try Self.loadNotebooks(from: storageURL)
        selectedNotebookID = notebooks.first?.id
        selectedPageID = notebooks.first?.pages.first?.id
        closeMultiNote()
    }

    private struct ImportedFileSummary {
        var originalFileName: String
        var displayTitle: String
        var kind: ImportedAssetKind
        var pageCount: Int
        var storedFileName: String
        var byteCount: Int
        var data: Data
    }

    enum NotebookLibraryError: LocalizedError {
        case noSelectedNotebook

        var errorDescription: String? {
            switch self {
            case .noSelectedNotebook:
                return "没有可导出的笔记本。"
            }
        }
    }

    private static let exportPageSize = CGSize(width: 780, height: 1040)

    private var currentNotebookID: Notebook.ID? {
        if activePane == .secondary, isMultiNoteEnabled {
            return secondaryNotebookID ?? selectedNotebookID
        }
        return selectedNotebookID
    }

    private var currentPageID: NotebookPage.ID? {
        if activePane == .secondary, isMultiNoteEnabled {
            return secondaryPageID ?? selectedPageID
        }
        return selectedPageID
    }

    private var currentNotebookIndex: Int? {
        guard let currentNotebookID else { return notebooks.indices.first }
        return notebooks.firstIndex { $0.id == currentNotebookID }
    }

    private var currentPageIndex: Int? {
        guard let notebookIndex = currentNotebookIndex else { return nil }
        if let currentPageID, let pageIndex = notebooks[notebookIndex].pages.firstIndex(where: { $0.id == currentPageID }) {
            return pageIndex
        }
        return notebooks[notebookIndex].pages.indices.first
    }

    private func setCurrentPageID(_ pageID: NotebookPage.ID?) {
        if activePane == .secondary, isMultiNoteEnabled {
            secondaryPageID = pageID
        } else {
            selectedPageID = pageID
        }
    }

    private var selectedIndexes: (notebook: Int, page: Int)? {
        guard let notebookIndex = currentNotebookIndex, let pageIndex = currentPageIndex else { return nil }
        return (notebookIndex, pageIndex)
    }

    private var selectedElementIndexes: (notebook: Int, page: Int, element: Int)? {
        guard let selectedElementID, let indexes = selectedIndexes,
              let elementIndex = notebooks[indexes.notebook].pages[indexes.page].elements.firstIndex(where: { $0.id == selectedElementID }) else {
            return nil
        }
        return (indexes.notebook, indexes.page, elementIndex)
    }

    private var transferDestinationPane: WorkspacePane? {
        guard isMultiNoteEnabled else { return nil }
        return activePane == .primary ? .secondary : .primary
    }

    private var transferDestinationNotebookIndex: Int? {
        guard let pane = transferDestinationPane else { return nil }
        return notebookIndex(for: pane)
    }

    private var transferDestinationPageIndexes: (notebook: Int, page: Int)? {
        guard let pane = transferDestinationPane,
              let notebookIndex = notebookIndex(for: pane),
              let pageIndex = pageIndex(for: pane) else {
            return nil
        }
        return (notebookIndex, pageIndex)
    }

    private func notebookIndex(for pane: WorkspacePane) -> Int? {
        let notebookID = pane == .primary ? selectedNotebookID : secondaryNotebookID
        guard let notebookID else { return nil }
        return notebooks.firstIndex { $0.id == notebookID }
    }

    private func pageIndex(for pane: WorkspacePane) -> Int? {
        guard let notebookIndex = notebookIndex(for: pane) else { return nil }
        let pageID = pane == .primary ? selectedPageID : secondaryPageID
        if let pageID, let pageIndex = notebooks[notebookIndex].pages.firstIndex(where: { $0.id == pageID }) {
            return pageIndex
        }
        return notebooks[notebookIndex].pages.indices.first
    }

    private func setPageID(_ pageID: NotebookPage.ID?, for pane: WorkspacePane) {
        if pane == .primary {
            selectedPageID = pageID
        } else {
            secondaryPageID = pageID
        }
    }

    private func pageTransferIndexes(in notebookIndex: Int) -> [Int] {
        let selectedIndexes = selectedPageIndexes(in: notebookIndex)
        if !selectedIndexes.isEmpty {
            return selectedIndexes
        }
        return currentPageIndex.map { [$0] } ?? []
    }

    private func transferPagesToOtherPane(removesFromSource: Bool) {
        guard let destinationPane = transferDestinationPane,
              let sourceNotebookIndex = currentNotebookIndex,
              let destinationNotebookIndex = transferDestinationNotebookIndex else {
            return
        }

        let indexes = pageTransferIndexes(in: sourceNotebookIndex)
        guard !indexes.isEmpty else { return }
        if removesFromSource {
            guard sourceNotebookIndex != destinationNotebookIndex,
                  notebooks[sourceNotebookIndex].pages.count > indexes.count else {
                return
            }
        }

        let transferredPages = indexes.map { index in
            removesFromSource ? notebooks[sourceNotebookIndex].pages[index] : Self.duplicatedPage(from: notebooks[sourceNotebookIndex].pages[index])
        }
        notebooks[destinationNotebookIndex].pages.append(contentsOf: transferredPages)
        notebooks[destinationNotebookIndex].modifiedAt = Date()

        if removesFromSource {
            let idsToRemove = Set(indexes.map { notebooks[sourceNotebookIndex].pages[$0].id })
            notebooks[sourceNotebookIndex].pages.removeAll { idsToRemove.contains($0.id) }
            notebooks[sourceNotebookIndex].modifiedAt = Date()

            if currentNotebookIndex == sourceNotebookIndex, let fallbackPage = notebooks[sourceNotebookIndex].pages.first {
                setCurrentPageID(fallbackPage.id)
            }
        }

        if let firstTransferredID = transferredPages.first?.id {
            setPageID(firstTransferredID, for: destinationPane)
        }
        activePane = destinationPane
        selectedElementID = nil
        selectedPageIDs.removeAll()
        isSelectingPages = false
        selectedSidePanel = .pages
        persistIfNeeded()
    }

    private func transferSelectedElementToOtherPane(removesFromSource: Bool) {
        guard let source = selectedElementIndexes,
              let destination = transferDestinationPageIndexes else {
            return
        }

        let element = notebooks[source.notebook].pages[source.page].elements[source.element]
        guard !removesFromSource || !element.isLocked else { return }
        let transferredElement = Self.duplicatedElement(from: element, titleSuffix: removesFromSource ? "" : "副本", offset: 32)

        notebooks[destination.notebook].pages[destination.page].elements.append(transferredElement)
        notebooks[destination.notebook].modifiedAt = Date()

        if removesFromSource {
            notebooks[source.notebook].pages[source.page].elements.remove(at: source.element)
            notebooks[source.notebook].modifiedAt = Date()
        }

        if let destinationPane = transferDestinationPane {
            activePane = destinationPane
        }
        selectedElementID = transferredElement.id
        selectedSidePanel = .content
        persistIfNeeded()
    }

    private func mutateSelectedElement(allowsLocked: Bool = false, _ mutate: (inout PageElement) -> Void) {
        guard let indexes = selectedElementIndexes else { return }
        guard allowsLocked || !notebooks[indexes.notebook].pages[indexes.page].elements[indexes.element].isLocked else { return }

        mutate(&notebooks[indexes.notebook].pages[indexes.page].elements[indexes.element])
        notebooks[indexes.notebook].modifiedAt = Date()
        selectedSidePanel = .content
        persistIfNeeded()
    }

    private func movePage(in notebookIndex: Int, from sourceIndex: Int, to destinationIndex: Int) {
        guard notebooks[notebookIndex].pages.indices.contains(sourceIndex),
              notebooks[notebookIndex].pages.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else { return }

        let page = notebooks[notebookIndex].pages.remove(at: sourceIndex)
        notebooks[notebookIndex].pages.insert(page, at: destinationIndex)
        setCurrentPageID(page.id)
        notebooks[notebookIndex].modifiedAt = Date()
        selectedSidePanel = .pages
        persistIfNeeded()
    }

    private func movePageGroup(draggedPageID: NotebookPage.ID, destinationPageID: NotebookPage.ID?, placesAtEnd: Bool) {
        guard let notebookIndex = currentNotebookIndex else { return }
        let pages = notebooks[notebookIndex].pages
        guard pages.contains(where: { $0.id == draggedPageID }) else { return }

        // When a selected thumbnail is dragged, Goodnotes-style managers move
        // that selected block together instead of separating the page under the finger.
        let draggedSelectionIDs: Set<NotebookPage.ID>
        if isSelectingPages, selectedPageIDs.contains(draggedPageID) {
            draggedSelectionIDs = selectedPageIDs
        } else {
            draggedSelectionIDs = [draggedPageID]
        }

        let movingPages = pages.filter { draggedSelectionIDs.contains($0.id) }
        guard !movingPages.isEmpty else { return }
        var remainingPages = pages.filter { !draggedSelectionIDs.contains($0.id) }

        let destinationIndex: Int
        if placesAtEnd {
            destinationIndex = remainingPages.count
        } else if let destinationPageID,
                  !draggedSelectionIDs.contains(destinationPageID),
                  let foundIndex = remainingPages.firstIndex(where: { $0.id == destinationPageID }) {
            destinationIndex = foundIndex
        } else {
            return
        }

        remainingPages.insert(contentsOf: movingPages, at: destinationIndex)
        guard remainingPages.map(\.id) != pages.map(\.id) else { return }

        notebooks[notebookIndex].pages = remainingPages
        if let firstMovedPageID = movingPages.first?.id {
            setCurrentPageID(firstMovedPageID)
        }
        if isSelectingPages {
            selectedPageIDs = Set(movingPages.map(\.id))
        }
        notebooks[notebookIndex].modifiedAt = Date()
        selectedSidePanel = .pages
        persistIfNeeded()
    }

    private func moveSelectedPages(direction: Int) {
        guard let notebookIndex = currentNotebookIndex, direction != 0 else { return }
        let indexes = selectedPageIndexes(in: notebookIndex)
        guard !indexes.isEmpty else { return }

        let pages = notebooks[notebookIndex].pages
        if direction < 0, indexes.first == pages.indices.first { return }
        if direction > 0, indexes.last == pages.indices.last { return }

        let selectedIDs = Set(indexes.map { pages[$0].id })
        let selectedPages = indexes.map { pages[$0] }
        var remainingPages = pages.filter { !selectedIDs.contains($0.id) }
        let destinationIndex: Int
        if direction < 0 {
            destinationIndex = max((indexes.first ?? 0) - 1, 0)
        } else {
            destinationIndex = min((indexes.last ?? 0) + 2 - selectedPages.count, remainingPages.count)
        }

        remainingPages.insert(contentsOf: selectedPages, at: destinationIndex)
        notebooks[notebookIndex].pages = remainingPages
        if let firstSelectedID = selectedPages.first?.id {
            setCurrentPageID(firstSelectedID)
        }
        notebooks[notebookIndex].modifiedAt = Date()
        selectedSidePanel = .pages
        persistIfNeeded()
    }

    private func selectedPageIndexes(in notebookIndex: Int) -> [Int] {
        notebooks[notebookIndex].pages.indices.filter { index in
            selectedPageIDs.contains(notebooks[notebookIndex].pages[index].id)
        }
    }

    private func updateRecording(_ recordingID: AudioRecording.ID?, mutate: (inout AudioRecording) -> Void) {
        guard let recordingID, let notebookIndex = currentNotebookIndex,
              let recordingIndex = notebooks[notebookIndex].recordings.firstIndex(where: { $0.id == recordingID }) else {
            return
        }

        mutate(&notebooks[notebookIndex].recordings[recordingIndex])
        notebooks[notebookIndex].modifiedAt = Date()
        persistIfNeeded()
    }

    private func nearestPageID(for recording: AudioRecording, at position: TimeInterval) -> NotebookPage.ID? {
        guard let notebook = selectedNotebook else { return recording.linkedPageID }
        let markers = notebook.pages.flatMap { page in
            page.audioMarkers
                .filter { $0.recordingID == recording.id && $0.timestamp <= position }
                .map { (pageID: page.id, marker: $0) }
        }
        return markers.max { lhs, rhs in
            lhs.marker.timestamp < rhs.marker.timestamp
        }?.pageID ?? recording.linkedPageID
    }

    private func clearContent(of page: inout NotebookPage) {
        page.drawingData = Data()
        page.elements.removeAll()
        page.audioMarkers.removeAll()
        page.transcriptSummary = nil
        page.assets.removeAll { asset in
            !(asset.kind == .pdf && asset.storedFileName != nil && asset.sourcePageIndex != nil)
        }
        page.previewLines = page.previewLines.filter { line in
            line.hasPrefix("PDF ·") || line.hasPrefix("第 ")
        }
    }

    private func persistIfNeeded() {
        guard autosaves else { return }
        try? saveNow()
    }

    private func pageExportTitle(for notebook: Notebook, pages: [NotebookPage]) -> String {
        if pages.count == 1, let page = pages.first {
            return "\(notebook.title)-\(page.title)"
        }
        if pages.count == notebook.pages.count {
            return "\(notebook.title)-全部页面"
        }
        return "\(notebook.title)-所选 \(pages.count) 页"
    }

    private func renderPDFData(title: String, pages: [NotebookPage]) throws -> Data {
        let bounds = CGRect(origin: .zero, size: Self.exportPageSize)
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: title,
            kCGPDFContextCreator as String: "SmartNotes"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        return renderer.pdfData { rendererContext in
            for page in pages {
                rendererContext.beginPage()
                let cgContext = rendererContext.cgContext
                cgContext.saveGState()
                Self.applyRotation(page.normalizedRotationDegrees, in: bounds, context: cgContext)
                drawBackground(for: page, in: bounds, context: cgContext)
                drawDrawingIfNeeded(page.drawingData, in: bounds)
                drawExportOverlays(for: page, in: bounds)
                cgContext.restoreGState()
            }
        }
    }

    private static func applyRotation(_ degrees: Int, in bounds: CGRect, context: CGContext) {
        let normalizedDegrees = NotebookPage.normalizedRotationDegrees(degrees)
        guard normalizedDegrees != 0 else { return }

        context.translateBy(x: bounds.midX, y: bounds.midY)
        context.rotate(by: CGFloat(normalizedDegrees) * .pi / 180)
        if normalizedDegrees == 90 || normalizedDegrees == 270 {
            let scale = min(bounds.width / bounds.height, bounds.height / bounds.width)
            context.scaleBy(x: scale, y: scale)
        }
        context.translateBy(x: -bounds.midX, y: -bounds.midY)
    }

    private func drawBackground(for page: NotebookPage, in bounds: CGRect, context: CGContext) {
        if let asset = pdfBackgroundAsset(for: page),
           let fileURL = fileURL(for: asset),
           let pdfDocument = PDFDocument(url: fileURL),
           let pdfPage = pdfDocument.page(at: asset.sourcePageIndex ?? 0) {
            draw(pdfPage: pdfPage, in: bounds)
        } else {
            Self.drawTemplate(page.template, in: bounds, context: context)
        }
    }

    private func draw(pdfPage: PDFPage, in bounds: CGRect) {
        let thumbnail = pdfPage.thumbnail(of: bounds.size, for: .mediaBox)
        UIColor.white.setFill()
        UIRectFill(bounds)
        thumbnail.draw(in: Self.aspectFitRect(aspectRatio: thumbnail.size, inside: bounds))
    }

    private func drawDrawingIfNeeded(_ drawingData: Data, in bounds: CGRect) {
        guard !drawingData.isEmpty, let drawing = try? PKDrawing(data: drawingData) else { return }
        drawing.image(from: bounds, scale: 2).draw(in: bounds)
    }

    private func drawExportOverlays(for page: NotebookPage, in bounds: CGRect) {
        guard pdfBackgroundAsset(for: page) == nil else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .regular),
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraph
        ]
        let text = ([page.title] + page.previewLines).joined(separator: "\n")
        text.draw(in: bounds.insetBy(dx: 48, dy: 48), withAttributes: attributes)
    }

    private static func drawTemplate(_ template: PaperTemplate, in bounds: CGRect, context: CGContext) {
        UIColor.white.setFill()
        context.fill(bounds)

        switch template {
        case .blank:
            break
        case .ruled, .cornell:
            strokeHorizontalLines(in: bounds, spacing: 34, color: UIColor.systemBlue.withAlphaComponent(0.18), context: context)
            if template == .cornell {
                strokeLine(
                    from: CGPoint(x: bounds.width * 0.32, y: bounds.minY),
                    to: CGPoint(x: bounds.width * 0.32, y: bounds.maxY),
                    color: UIColor.systemRed.withAlphaComponent(0.22),
                    context: context
                )
            }
        case .grid:
            strokeHorizontalLines(in: bounds, spacing: 32, color: UIColor.systemBlue.withAlphaComponent(0.12), context: context)
            var x = bounds.minX
            while x < bounds.maxX {
                strokeLine(from: CGPoint(x: x, y: bounds.minY), to: CGPoint(x: x, y: bounds.maxY), color: UIColor.systemBlue.withAlphaComponent(0.12), context: context)
                x += 32
            }
        case .dotted:
            UIColor.systemGray.withAlphaComponent(0.32).setFill()
            var x = bounds.minX + 28
            while x < bounds.maxX {
                var y = bounds.minY + 28
                while y < bounds.maxY {
                    context.fillEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                    y += 28
                }
                x += 28
            }
        case .planner:
            strokeHorizontalLines(in: bounds, spacing: 58, color: UIColor.systemGreen.withAlphaComponent(0.14), context: context)
            strokeLine(from: CGPoint(x: bounds.width * 0.18, y: bounds.minY), to: CGPoint(x: bounds.width * 0.18, y: bounds.maxY), color: UIColor.systemGreen.withAlphaComponent(0.18), context: context)
            strokeLine(from: CGPoint(x: bounds.width * 0.68, y: bounds.minY), to: CGPoint(x: bounds.width * 0.68, y: bounds.maxY), color: UIColor.systemGreen.withAlphaComponent(0.18), context: context)
        case .music:
            var y = bounds.minY + 80
            while y < bounds.maxY - 80 {
                for offset in stride(from: CGFloat(0), through: 36, by: 9) {
                    strokeLine(
                        from: CGPoint(x: bounds.minX + 54, y: y + offset),
                        to: CGPoint(x: bounds.maxX - 54, y: y + offset),
                        color: UIColor.systemGray.withAlphaComponent(0.28),
                        context: context
                    )
                }
                y += 88
            }
        }
    }

    private static func strokeHorizontalLines(in bounds: CGRect, spacing: CGFloat, color: UIColor, context: CGContext) {
        var y = bounds.minY + spacing
        while y < bounds.maxY {
            strokeLine(from: CGPoint(x: bounds.minX, y: y), to: CGPoint(x: bounds.maxX, y: y), color: color, context: context)
            y += spacing
        }
    }

    private static func strokeLine(from start: CGPoint, to end: CGPoint, color: UIColor, context: CGContext) {
        context.saveGState()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(1)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        context.restoreGState()
    }

    private static func importSummary(for url: URL, data: Data, storedFileName: String) -> ImportedFileSummary {
        let kind = importedAssetKind(for: url)
        let pageCount: Int
        if kind == .pdf {
            pageCount = max(PDFDocument(data: data)?.pageCount ?? 1, 1)
        } else {
            pageCount = 1
        }

        return ImportedFileSummary(
            originalFileName: url.lastPathComponent,
            displayTitle: url.deletingPathExtension().lastPathComponent,
            kind: kind,
            pageCount: pageCount,
            storedFileName: storedFileName,
            byteCount: data.count,
            data: data
        )
    }

    private static func importedAssetKind(for url: URL) -> ImportedAssetKind {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return .pdf
        case "png", "jpg", "jpeg", "heic", "heif", "gif", "tiff", "tif", "webp":
            return .image
        case "ppt", "pptx", "key":
            return .powerpoint
        default:
            return .webClip
        }
    }

    private static func isAudioFile(_ url: URL) -> Bool {
        switch url.pathExtension.lowercased() {
        case "m4a", "mp3", "wav", "aac", "caf", "aiff", "aif", "mp4":
            return true
        default:
            return false
        }
    }

    private static func storeImportedFile(data: Data, originalFileName: String, beside storageURL: URL) throws -> String {
        let directory = importsDirectory(beside: storageURL)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let storedFileName = "\(UUID().uuidString)-\(sanitizedFileName(originalFileName))"
        let destinationURL = directory.appendingPathComponent(storedFileName)
        try data.write(to: destinationURL, options: [.atomic])
        return storedFileName
    }

    private static func storeRecordingFile(data: Data, originalFileName: String, beside storageURL: URL) throws -> String {
        let directory = recordingsDirectory(beside: storageURL)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let storedFileName = "\(UUID().uuidString)-\(sanitizedFileName(originalFileName))"
        let destinationURL = directory.appendingPathComponent(storedFileName)
        try data.write(to: destinationURL, options: [.atomic])
        return storedFileName
    }

    private static func importsDirectory(beside storageURL: URL) -> URL {
        storageURL.deletingLastPathComponent().appendingPathComponent("Imports", isDirectory: true)
    }

    private static func exportsDirectory(beside storageURL: URL) -> URL {
        storageURL.deletingLastPathComponent().appendingPathComponent("Exports", isDirectory: true)
    }

    private static func recordingsDirectory(beside storageURL: URL) -> URL {
        storageURL.deletingLastPathComponent().appendingPathComponent("Recordings", isDirectory: true)
    }

    private static func aspectFitRect(aspectRatio: CGSize, inside bounds: CGRect) -> CGRect {
        guard aspectRatio.width > 0, aspectRatio.height > 0, bounds.width > 0, bounds.height > 0 else {
            return bounds
        }
        let scale = min(bounds.width / aspectRatio.width, bounds.height / aspectRatio.height)
        let size = CGSize(width: aspectRatio.width * scale, height: aspectRatio.height * scale)
        return CGRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private static func duplicatedPage(from page: NotebookPage) -> NotebookPage {
        NotebookPage(
            id: UUID(),
            title: "\(page.title) 副本",
            template: page.template,
            previewLines: page.previewLines,
            rotationDegrees: page.rotationDegrees,
            drawingData: page.drawingData,
            elements: page.elements,
            assets: page.assets,
            audioMarkers: page.audioMarkers,
            isBookmarked: page.isBookmarked,
            outlineTitle: page.outlineTitle,
            transcriptSummary: page.transcriptSummary
        )
    }

    private static func duplicatedElement(from element: PageElement, titleSuffix: String, offset: Double) -> PageElement {
        let title = titleSuffix.isEmpty ? element.title : "\(element.title) \(titleSuffix)"
        return PageElement(
            kind: element.kind,
            title: title,
            detail: element.detail,
            color: element.color,
            frame: element.frame.offsetBy(x: offset, y: offset),
            rotationDegrees: element.rotationDegrees,
            scale: element.scale,
            isLocked: false
        )
    }

    private static func sanitizedFileName(_ fileName: String) -> String {
        let fallback = "ImportedFile"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let cleanedScalars = fileName.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let cleaned = String(cleanedScalars).trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
        return cleaned.isEmpty ? fallback : cleaned
    }

    nonisolated private static func compactPreviewText(_ text: String) -> String? {
        let compacted = text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !compacted.isEmpty else { return nil }
        return String(compacted.prefix(180))
    }

    private static var defaultStorageURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("SmartNotes", isDirectory: true)
            .appendingPathComponent("Library.json")
    }

    private static func loadNotebooks(from url: URL) throws -> [Notebook] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Notebook].self, from: data)
    }

    private static func save(_ notebooks: [Notebook], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(notebooks)
        try data.write(to: url, options: [.atomic])
    }

    private static func defaultTitle(for kind: NotebookKind) -> String {
        switch kind {
        case .notebook: return "未命名笔记本"
        case .pdf: return "PDF 批注"
        case .whiteboard: return "无限白板"
        case .textDocument: return "文本文件"
        case .quickNote: return "Quicknote"
        }
    }

    private static func defaultPreviewLines(for kind: NotebookKind) -> [String] {
        switch kind {
        case .notebook: return ["在这里开始书写。"]
        case .pdf: return ["导入 PDF 后可直接批注、搜索、导出。"]
        case .whiteboard: return ["无限画布", "适合头脑风暴和项目图。"]
        case .textDocument: return ["键盘输入、段落整理、与手写内容并存。"]
        case .quickNote: return ["快速捕捉想法，稍后整理进资料库。"]
        }
    }

    private static func defaultElementDetail(for kind: PageElementKind) -> String {
        switch kind {
        case .handwriting: return "Apple Pencil 书写层。"
        case .textBox: return "可移动文本框，适合键盘笔记。"
        case .shape: return "自动规整的直线、箭头和图形。"
        case .sticker: return "从贴纸库或选区保存的素材。"
        case .image: return "照片、截图或拖放图片。"
        case .tape: return "遮挡答案，用于背诵和主动回忆。"
        case .math: return "手写公式转换为可缩放数学内容。"
        case .laserTrail: return "演示时的临时激光标记。"
        }
    }
}

extension NotebookLibrary {
    static let samples: [Notebook] = [
        Notebook(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            title: "微积分课堂笔记",
            subject: "数学",
            folder: .classes,
            cover: .blue,
            modifiedAt: Date(timeIntervalSinceNow: -1_800),
            isFavorite: true,
            isShared: true,
            pages: [
                NotebookPage(
                    id: UUID(),
                    title: "极限与连续",
                    template: .ruled,
                    previewLines: ["lim x -> 0", "夹逼定理", "课后习题 1-8"],
                    elements: [
                        PageElement(kind: .handwriting, title: "课堂手写", detail: "两页推导和重点高亮。", color: .blue),
                        PageElement(kind: .tape, title: "遮挡练习", detail: "遮住定义，复习时点击揭晓。", color: .orange)
                    ],
                    isBookmarked: true
                ),
                NotebookPage(id: UUID(), title: "导数", template: .grid, previewLines: ["切线斜率", "链式法则"])
            ],
            recordings: [
                AudioRecording(title: "第 8 周课堂录音", duration: 1_482, transcript: "老师讲解了极限、连续和夹逼定理。")
            ],
            studySets: [
                StudySet(
                    title: "微积分复习卡",
                    cards: [
                        StudyCard(prompt: "夹逼定理的使用条件？", answer: "左右两侧函数同极限，目标函数被夹在中间。", isStarred: true),
                        StudyCard(prompt: "导数的几何意义？", answer: "曲线在一点处切线的斜率。")
                    ]
                )
            ],
            collaborators: [
                Collaborator(name: "我", role: "所有者", color: .blue),
                Collaborator(name: "同学 A", role: "可评论", color: .green)
            ]
        ),
        Notebook(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            kind: .whiteboard,
            title: "产品设计草图",
            subject: "工作",
            folder: .work,
            cover: .green,
            modifiedAt: Date(timeIntervalSinceNow: -8_400),
            isFavorite: false,
            pages: [
                NotebookPage(
                    id: UUID(),
                    title: "主页结构",
                    template: .dotted,
                    previewLines: ["侧栏", "文档网格", "编辑工具条"],
                    elements: [
                        PageElement(kind: .shape, title: "信息架构", detail: "白板上的结构图和连线。", color: .green)
                    ]
                )
            ]
        ),
        Notebook(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
            title: "读书摘录",
            subject: "个人",
            folder: .documents,
            cover: .coral,
            modifiedAt: Date(timeIntervalSinceNow: -16_000),
            isFavorite: true,
            pages: [
                NotebookPage(id: UUID(), title: "第一章", template: .cornell, previewLines: ["核心观点", "可引用句子", "待查资料"])
            ]
        ),
        Notebook(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000104")!,
            kind: .pdf,
            title: "导入的 PDF 批注",
            subject: "导入",
            folder: .imports,
            cover: .ink,
            modifiedAt: Date(timeIntervalSinceNow: -26_000),
            isFavorite: false,
            pages: [
                NotebookPage(
                    id: UUID(),
                    title: "论文第一页",
                    template: .blank,
                    previewLines: ["摘要高亮", "边栏问题"],
                    assets: [
                        ImportedAsset(kind: .pdf, title: "research-paper.pdf", pageCount: 18)
                    ],
                    isBookmarked: true
                )
            ]
        )
    ]
}

extension TemplatePack {
    static let featured: [TemplatePack] = [
        TemplatePack(title: "课堂套装", detail: "横线、康奈尔、方格，适合课程笔记。", templates: [.ruled, .cornell, .grid], isInstalled: true),
        TemplatePack(title: "计划与复盘", detail: "日计划、项目复盘和任务拆解页面。", templates: [.planner, .grid]),
        TemplatePack(title: "音乐与创作", detail: "五线谱、空白页和草图页。", templates: [.music, .blank, .dotted])
    ]
}

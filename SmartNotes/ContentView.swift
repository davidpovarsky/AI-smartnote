import Foundation
import AVFoundation
import PDFKit
import PencilKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var library = NotebookLibrary(
        loadsFromDisk: !Self.isRunningUITests,
        autosaves: !Self.isRunningUITests
    )
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var isShowingFileImporter = false
    @State private var importErrorMessage: String?
    @State private var audioCapture = AudioCaptureController()
    @State private var audioPlayback = AudioPlaybackController()

    private static var isRunningUITests: Bool {
        ProcessInfo.processInfo.environment["SMARTNOTES_UI_TEST"] == "1"
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            LibrarySidebar(library: library, importFiles: showFileImporter)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        } content: {
            NotebookBrowser(library: library, importFiles: showFileImporter)
                .navigationSplitViewColumnWidth(min: 360, ideal: 430, max: 520)
        } detail: {
            NotebookEditor(library: library, audioCapture: audioCapture, audioPlayback: audioPlayback)
        }
        .background(Color.smartCanvasBackground)
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.pdf, .image, .audio],
            allowsMultipleSelection: true,
            onCompletion: handleFileImport
        )
        .alert(
            "导入失败",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
        .accessibilityIdentifier("ipad-notes-shell")
    }

    private func showFileImporter() {
        isShowingFileImporter = true
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            try library.importExternalFiles(urls)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }
}

struct LibrarySidebar: View {
    @Bindable var library: NotebookLibrary
    let importFiles: () -> Void

    var body: some View {
        List {
            Section("资料库") {
                ForEach(LibraryFolder.allCases) { folder in
                    Button {
                        withAnimation(.snappy) {
                            library.selectedFolder = folder
                        }
                    } label: {
                        Label(folder.rawValue, systemImage: folder.symbolName)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(library.selectedFolder == folder ? Color.accentColor : Color.primary)
                    .listRowBackground(library.selectedFolder == folder ? Color.accentColor.opacity(0.12) : Color.clear)
                        .accessibilityIdentifier("sidebar-folder-\(folder.id)")
                }
            }

            Section("快速入口") {
                Button {
                    library.createDocument(.scan)
                } label: {
                    Label("扫描文稿", systemImage: "doc.viewfinder")
                }
                .buttonStyle(.plain)

                Button {
                    importFiles()
                } label: {
                    Label("导入文件", systemImage: "square.and.arrow.down.on.square")
                }
                .buttonStyle(.plain)

                Button {
                    library.createDocument(.quickNote)
                } label: {
                    Label("Quicknote", systemImage: "bolt.square")
                }
                .buttonStyle(.plain)
            }
        }
        .scrollContentBackground(.hidden)
        .background(.thinMaterial)
        .navigationTitle("SmartNotes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    library.createNotebook()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("新建笔记本")
                .accessibilityIdentifier("create-notebook-button")
            }
        }
    }
}

struct NotebookBrowser: View {
    @Bindable var library: NotebookLibrary
    let importFiles: () -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 168, maximum: 220), spacing: 18)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LibraryHeader(library: library, importFiles: importFiles)

                if library.visibleNotebooks.isEmpty {
                    EmptyLibraryView {
                        library.createNotebook()
                    }
                        .frame(maxWidth: .infinity, minHeight: 420)
                } else if library.displayMode == .grid {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                        ForEach(library.visibleNotebooks) { notebook in
                            NotebookCard(
                                notebook: notebook,
                                isSelected: library.selectedNotebookID == notebook.id,
                                select: { library.select(notebook) },
                                toggleFavorite: { library.toggleFavorite(notebook) },
                                openInMultiNote: { library.openNotebookInMultiNote(notebook, layout: .horizontal) }
                            )
                        }
                    }
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(library.visibleNotebooks) { notebook in
                            NotebookRow(
                                notebook: notebook,
                                isSelected: library.selectedNotebookID == notebook.id,
                                select: { library.select(notebook) },
                                toggleFavorite: { library.toggleFavorite(notebook) },
                                openInMultiNote: { library.openNotebookInMultiNote(notebook, layout: .horizontal) }
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color.smartGroupedBackground)
        .searchable(text: $library.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索标题、科目")
        .navigationTitle(library.selectedFolder.rawValue)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Picker("显示方式", selection: $library.displayMode) {
                    ForEach(LibraryDisplayMode.allCases) { mode in
                        Image(systemName: mode.symbolName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 108)
                .accessibilityIdentifier("library-display-picker")

                NewDocumentMenu(library: library, title: "新建", symbolName: "square.and.pencil", importFiles: importFiles)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("browser-create-notebook-button")
            }
        }
    }
}

struct LibraryHeader: View {
    @Bindable var library: NotebookLibrary
    let importFiles: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(library.selectedFolder.rawValue)
                        .font(.largeTitle.bold())
                    Text("\(library.visibleNotebooks.count) 个笔记本")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                NewDocumentMenu(library: library, title: "新建", symbolName: "plus.rectangle.on.rectangle", importFiles: importFiles)
                    .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 10) {
                QuickActionChip(title: "新建笔记本", symbolName: "plus.rectangle.on.rectangle") {
                    library.createDocument(.notebook)
                }
                .accessibilityIdentifier("library-quick-new-notebook")
                QuickActionChip(title: "导入 PDF", symbolName: "doc.richtext") {
                    importFiles()
                }
                .accessibilityIdentifier("library-quick-import-pdf")
                QuickActionChip(title: "扫描", symbolName: "camera.viewfinder") {
                    library.createDocument(.scan)
                }
                .accessibilityIdentifier("library-quick-scan")
                QuickActionChip(title: "白板", symbolName: "infinity") {
                    library.createDocument(.whiteboard)
                }
                .accessibilityIdentifier("library-quick-whiteboard")
                QuickActionChip(title: "文本", symbolName: "doc.text") {
                    library.createDocument(.textDocument)
                }
                .accessibilityIdentifier("library-quick-text")
            }
        }
    }
}

struct NotebookCard: View {
    let notebook: Notebook
    let isSelected: Bool
    let select: () -> Void
    let toggleFavorite: () -> Void
    let openInMultiNote: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 12) {
                NotebookCoverPreview(notebook: notebook)
                    .aspectRatio(0.78, contentMode: .fit)

                VStack(alignment: .leading, spacing: 4) {
                    Label(notebook.kind.rawValue, systemImage: notebook.kind.symbolName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(notebook.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(notebook.subject) · \(notebook.pageCountText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.black.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("右侧打开", action: openInMultiNote)
            Button(notebook.isFavorite ? "取消收藏" : "收藏", action: toggleFavorite)
            Button("重命名") {}
            Button(role: .destructive) {} label: {
                Label("移到废纸篓", systemImage: "trash")
            }
        }
        .accessibilityIdentifier("notebook-card-\(notebook.id.uuidString)")
    }
}

struct NotebookRow: View {
    let notebook: Notebook
    let isSelected: Bool
    let select: () -> Void
    let toggleFavorite: () -> Void
    let openInMultiNote: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 14) {
                NotebookCoverPreview(notebook: notebook)
                    .frame(width: 68, height: 88)

                VStack(alignment: .leading, spacing: 5) {
                    Label(notebook.kind.rawValue, systemImage: notebook.kind.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(notebook.title)
                        .font(.headline)
                    Text("\(notebook.subject) · \(notebook.pageCountText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: toggleFavorite) {
                    Image(systemName: notebook.isFavorite ? "star.fill" : "star")
                }
                .buttonStyle(.plain)
                .foregroundStyle(notebook.isFavorite ? .yellow : .secondary)
            }
            .padding(12)
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("右侧打开", action: openInMultiNote)
            Button(notebook.isFavorite ? "取消收藏" : "收藏", action: toggleFavorite)
        }
    }
}

struct NotebookCoverPreview: View {
    let notebook: Notebook

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: notebook.cover.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.78))
                    .frame(width: 42, height: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.58))
                    .frame(width: 72, height: 4)
                Spacer()
                Text(notebook.subject.uppercased())
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 8, x: 0, y: 5)
    }
}

struct NotebookEditor: View {
    @Bindable var library: NotebookLibrary
    @Bindable var audioCapture: AudioCaptureController
    @Bindable var audioPlayback: AudioPlaybackController
    @State private var showPageStrip = true
    @State private var showSidePanel = true
    @State private var zoom = 1.0

    var body: some View {
        VStack(spacing: 0) {
            DocumentTabBar(library: library, showSidePanel: $showSidePanel)
            WritingToolbar(library: library, audioCapture: audioCapture, showPageStrip: $showPageStrip, zoom: $zoom)

            GeometryReader { proxy in
                let sidePanelWidth = showSidePanel ? 292.0 : 0.0
                let pageStripWidth = showPageStrip ? 132.0 : 0.0
                let railWidth = 48.0
                let workspaceChromeWidth = sidePanelWidth + pageStripWidth + railWidth + 80.0
                let fitZoom = max(0.48, min(zoom, (proxy.size.width - workspaceChromeWidth) / 780.0))

                HStack(spacing: 0) {
                    if showPageStrip {
                        PageThumbnailRail(library: library)
                            .frame(width: pageStripWidth)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }

                    MultiNoteRailControls(library: library)
                        .frame(width: railWidth)

                    MultiNoteWorkspace(library: library, zoom: fitZoom)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(1)

                    if showSidePanel {
                        EditorSidePanelView(library: library, audioCapture: audioCapture, audioPlayback: audioPlayback)
                            .frame(width: sidePanelWidth)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }
        }
        .background(Color.smartCanvasBackground)
        .navigationTitle(library.selectedNotebook?.title ?? "笔记")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("note-editor-regular-workbench")
    }
}

struct MultiNoteRailControls: View {
    @Bindable var library: NotebookLibrary

    var body: some View {
        VStack(spacing: 8) {
            Button {
                library.openNextNotebookInMultiNote(layout: .horizontal)
            } label: {
                Image(systemName: "rectangle.split.2x1")
                    .frame(width: 32, height: 32)
            }
            .help("右侧打开")
            .accessibilityLabel("右侧打开")
            .accessibilityIdentifier("rail-open-multinote-right-button")

            Button {
                if library.multiNoteLayout == .horizontal {
                    library.setMultiNoteLayout(.vertical)
                } else {
                    library.setMultiNoteLayout(.horizontal)
                }
            } label: {
                Image(systemName: library.multiNoteLayout == .horizontal ? "rectangle.split.1x2" : "rectangle.split.2x1")
                    .frame(width: 32, height: 32)
            }
            .disabled(!library.isMultiNoteEnabled)
            .help("切换多笔记布局")
            .accessibilityLabel("切换多笔记布局")
            .accessibilityIdentifier("rail-toggle-multinote-layout-button")

            if library.isMultiNoteEnabled {
                Button {
                    library.closeMultiNote()
                } label: {
                    Image(systemName: "xmark.rectangle")
                        .frame(width: 32, height: 32)
                }
                .help("关闭副笔记")
                .accessibilityLabel("关闭副笔记")
                .accessibilityIdentifier("rail-close-multinote-button")
            }

            Spacer()
        }
        .buttonStyle(.bordered)
        .padding(.top, 14)
        .background(.thinMaterial)
    }
}

struct MultiNoteWorkspace: View {
    @Bindable var library: NotebookLibrary
    let zoom: Double

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            Group {
                if library.isMultiNoteEnabled, let secondaryNotebook = library.secondaryNotebook, let secondaryPage = library.secondaryPage {
                    if library.multiNoteLayout == .horizontal {
                        HStack(alignment: .top, spacing: 24) {
                            NotebookWorkspacePane(
                                library: library,
                                pane: .primary,
                                notebook: library.primaryNotebook,
                                page: library.primaryPage,
                                zoom: min(zoom, 0.86)
                            )
                            NotebookWorkspacePane(
                                library: library,
                                pane: .secondary,
                                notebook: secondaryNotebook,
                                page: secondaryPage,
                                zoom: min(zoom, 0.86)
                            )
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 24) {
                            NotebookWorkspacePane(
                                library: library,
                                pane: .primary,
                                notebook: library.primaryNotebook,
                                page: library.primaryPage,
                                zoom: min(zoom, 0.88)
                            )
                            NotebookWorkspacePane(
                                library: library,
                                pane: .secondary,
                                notebook: secondaryNotebook,
                                page: secondaryPage,
                                zoom: min(zoom, 0.88)
                            )
                        }
                    }
                } else {
                    NotebookWorkspacePane(
                        library: library,
                        pane: .primary,
                        notebook: library.primaryNotebook,
                        page: library.primaryPage,
                        zoom: zoom
                    )
                }
            }
            .padding(40)
        }
        .background(Color.smartCanvasBackground)
        .accessibilityIdentifier("multinote-workspace")
    }
}

struct NotebookWorkspacePane: View {
    @Bindable var library: NotebookLibrary
    let pane: WorkspacePane
    let notebook: Notebook?
    let page: NotebookPage?
    let zoom: Double

    private var isActive: Bool {
        library.activePane == pane || (!library.isMultiNoteEnabled && pane == .primary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Label(pane.rawValue, systemImage: pane.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                Text(notebook?.title ?? "未选择笔记")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }

            PaperCanvas(
                library: library,
                notebook: notebook,
                page: page,
                activeTool: library.activeTool,
                selectedInk: library.selectedInk,
                isActive: isActive
            )
            .frame(width: 780 * zoom, height: 1040 * zoom)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Color.accentColor.opacity(0.7) : Color.clear, lineWidth: 3)
            )
        }
        .onTapGesture {
            library.activatePane(pane)
        }
        .accessibilityIdentifier(pane == .primary ? "workspace-primary-pane" : "workspace-secondary-pane")
    }
}

struct DocumentTabBar: View {
    @Bindable var library: NotebookLibrary
    @Binding var showSidePanel: Bool

    var body: some View {
        HStack(spacing: 8) {
            WorkspaceTabButton(
                pane: .primary,
                notebook: library.primaryNotebook,
                isActive: library.activePane == .primary || !library.isMultiNoteEnabled
            ) {
                library.activatePane(.primary)
            }
            .accessibilityIdentifier("workspace-primary-tab")

            if library.isMultiNoteEnabled, let secondaryNotebook = library.secondaryNotebook {
                WorkspaceTabButton(
                    pane: .secondary,
                    notebook: secondaryNotebook,
                    isActive: library.activePane == .secondary
                ) {
                    library.activatePane(.secondary)
                }
                .accessibilityIdentifier("workspace-secondary-tab")
            }

            Spacer()

            Button {
                library.openNextNotebookInMultiNote(layout: .horizontal)
            } label: {
                Label("右侧打开", systemImage: "rectangle.split.2x1")
                    .labelStyle(.iconOnly)
            }
            .help("右侧打开")
            .accessibilityIdentifier("top-open-multinote-right-button")

            Button {
                if library.multiNoteLayout == .horizontal {
                    library.setMultiNoteLayout(.vertical)
                } else {
                    library.setMultiNoteLayout(.horizontal)
                }
            } label: {
                Label(library.multiNoteLayout == .horizontal ? "底部打开" : "右侧打开", systemImage: library.multiNoteLayout == .horizontal ? "rectangle.split.1x2" : "rectangle.split.2x1")
                    .labelStyle(.iconOnly)
            }
            .disabled(!library.isMultiNoteEnabled)
            .help(library.multiNoteLayout == .horizontal ? "切换到底部打开" : "切换到右侧打开")
            .accessibilityIdentifier("top-toggle-multinote-layout-button")

            if library.isMultiNoteEnabled {
                Button {
                    library.closeMultiNote()
                } label: {
                    Label("关闭副笔记", systemImage: "xmark.rectangle")
                        .labelStyle(.iconOnly)
                }
                .help("关闭副笔记")
                .accessibilityIdentifier("top-close-multinote-button")
            }

            Button {} label: { Image(systemName: "arrow.uturn.backward") }
            Button {} label: { Image(systemName: "arrow.uturn.forward") }
            Button {
                _ = try? library.exportCurrentNotebookToPDF()
            } label: {
                Label("导出 PDF", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("document-top-export-pdf-button")
            Button {
                withAnimation(.snappy) {
                    showSidePanel.toggle()
                }
            } label: {
                Image(systemName: showSidePanel ? "sidebar.right" : "sidebar.trailing")
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}

struct WorkspaceTabButton: View {
    let pane: WorkspacePane
    let notebook: Notebook?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: notebook?.kind.symbolName ?? pane.symbolName)
                VStack(alignment: .leading, spacing: 1) {
                    Text(notebook?.title ?? "未选择笔记")
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(pane.rawValue)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isActive ? Color.accentColor.opacity(0.14) : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? Color.accentColor.opacity(0.55) : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

struct WritingToolbar: View {
    @Bindable var library: NotebookLibrary
    @Bindable var audioCapture: AudioCaptureController
    @Binding var showPageStrip: Bool
    @Binding var zoom: Double

    var body: some View {
        HStack(spacing: 14) {
            Button {
                withAnimation(.snappy) { showPageStrip.toggle() }
            } label: {
                Image(systemName: showPageStrip ? "sidebar.left" : "sidebar.leading")
            }
            .accessibilityLabel("页面缩略图")

            Divider()

            Button {
                library.openNextNotebookInMultiNote(layout: .horizontal)
            } label: {
                Image(systemName: "rectangle.split.2x1")
                    .frame(width: 34, height: 32)
            }
            .help("右侧打开")
            .accessibilityLabel("右侧打开")
            .accessibilityIdentifier("toolbar-open-multinote-right-button")

            Button {
                if library.multiNoteLayout == .horizontal {
                    library.setMultiNoteLayout(.vertical)
                } else {
                    library.setMultiNoteLayout(.horizontal)
                }
            } label: {
                Image(systemName: library.multiNoteLayout == .horizontal ? "rectangle.split.1x2" : "rectangle.split.2x1")
                    .frame(width: 34, height: 32)
            }
            .disabled(!library.isMultiNoteEnabled)
            .help("切换多笔记布局")
            .accessibilityLabel("切换多笔记布局")
            .accessibilityIdentifier("toolbar-toggle-multinote-layout-button")

            if library.isMultiNoteEnabled {
                Button {
                    library.closeMultiNote()
                } label: {
                    Image(systemName: "xmark.rectangle")
                        .frame(width: 34, height: 32)
                }
                .help("关闭副笔记")
                .accessibilityLabel("关闭副笔记")
                .accessibilityIdentifier("toolbar-close-multinote-button")
            }

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(WritingTool.allCases) { tool in
                        Button {
                            library.activeTool = tool
                        } label: {
                            Image(systemName: tool.symbolName)
                                .frame(width: 36, height: 34)
                                .background(library.activeTool == tool ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .help(tool.rawValue)
                        .accessibilityIdentifier("ipad-drawing-tool-\(tool.rawValue)")
                    }
                }
            }
            .frame(maxWidth: 360)

            Divider()

            ForEach(InkSwatch.allCases) { ink in
                Button {
                    library.selectedInk = ink
                } label: {
                    Circle()
                        .fill(ink.color)
                        .frame(width: 22, height: 22)
                        .overlay(Circle().stroke(.primary.opacity(library.selectedInk == ink ? 0.8 : 0.12), lineWidth: 2))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Menu {
                ForEach(PageElementKind.allCases) { kind in
                    Button {
                        library.addElement(kind: kind)
                    } label: {
                        Label(kind.rawValue, systemImage: kind.symbolName)
                    }
                }

                Divider()

                Button {
                    library.addAsset(kind: .image, title: "插入图片.png", pageCount: 1)
                } label: {
                    Label("图片", systemImage: "photo")
                }
            } label: {
                Label("插入", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)

            Menu {
                Button {
                    library.convertSelectionToText()
                } label: {
                    Label("手写转文字", systemImage: "textformat")
                }
                Button {
                    library.convertSelectionToMath()
                } label: {
                    Label("数学转 LaTeX", systemImage: "function")
                }
                Button {
                    library.createStudySetFromCurrentPage()
                } label: {
                    Label("生成学习卡", systemImage: "rectangle.on.rectangle.angled")
                }
            } label: {
                Label("转换", systemImage: "wand.and.stars")
            }
            .buttonStyle(.bordered)

            Button {
                Task {
                    await audioCapture.toggleRecording(library: library)
                }
            } label: {
                Label(library.isRecordingAudio ? "停止" : "录音", systemImage: library.isRecordingAudio ? "stop.circle.fill" : "record.circle")
            }
            .buttonStyle(.borderedProminent)
            .tint(library.isRecordingAudio ? .red : .accentColor)

            Slider(value: $zoom, in: 0.72...1.35)
                .frame(width: 150)
            Text("\(Int(zoom * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Menu {
                ForEach(PaperTemplate.allCases) { template in
                    Button {
                        library.addPage(template: template)
                    } label: {
                        Label(template.rawValue, systemImage: "doc")
                    }
                }
            } label: {
                Label("添加页面", systemImage: "plus.square.on.square")
            }
            .buttonStyle(.bordered)

            Button("保存") {
                try? library.saveNow()
            }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("ipad-writing-save-button")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial)
        .accessibilityIdentifier("ipad-writing-toolbar")
    }
}

struct PageThumbnailRail: View {
    @Bindable var library: NotebookLibrary

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array((library.selectedNotebook?.pages ?? []).enumerated()), id: \.element.id) { index, page in
                    Button {
                        library.selectPage(page.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            PageThumbnailPreview(library: library, page: page)
                                .frame(height: 122)
                            HStack {
                                Text("\(index + 1). \(page.title)")
                                    .font(.caption.weight(.medium))
                                    .lineLimit(1)
                                Spacer(minLength: 4)
                                if page.isBookmarked {
                                    Image(systemName: "bookmark.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.yellow)
                                }
                            }
                        }
                        .padding(7)
                        .background(library.selectedPage?.id == page.id ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .draggable(page.id.uuidString)
                    .dropDestination(for: String.self) { items, _ in
                        return moveDroppedPages(items, before: page.id)
                    }
                    .accessibilityIdentifier("rail-page-thumbnail-\(index + 1)")
                }
            }
            .padding(12)
            .dropDestination(for: String.self) { items, _ in
                return moveDroppedPagesToEnd(items)
            }
        }
        .background(.thinMaterial)
        .accessibilityIdentifier("page-thumbnail-rail")
    }

    private func moveDroppedPages(_ items: [String], before destinationPageID: NotebookPage.ID) -> Bool {
        guard let draggedPageID = items.compactMap(UUID.init(uuidString:)).first else { return false }
        library.movePageOrSelectedPages(draggedPageID: draggedPageID, before: destinationPageID)
        return true
    }

    private func moveDroppedPagesToEnd(_ items: [String]) -> Bool {
        guard let draggedPageID = items.compactMap(UUID.init(uuidString:)).first else { return false }
        library.movePageOrSelectedPagesToEnd(draggedPageID: draggedPageID)
        return true
    }
}

struct PageThumbnailPreview: View {
    @Bindable var library: NotebookLibrary
    let page: NotebookPage

    var body: some View {
        let hasPDFBackground = library.pdfBackgroundAsset(for: page) != nil
        let rotationDegrees = Double(page.normalizedRotationDegrees)
        let rotationScale = page.rotationScaleForDisplay

        ZStack(alignment: .topLeading) {
            PageBackground(library: library, page: page)

            PageMiniContent(page: page, hasPDFBackground: hasPDFBackground)
                .padding(10)
                .rotationEffect(.degrees(rotationDegrees))
                .scaleEffect(rotationScale)
        }
        .aspectRatio(0.72, contentMode: .fit)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct PageMiniContent: View {
    let page: NotebookPage
    let hasPDFBackground: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if hasPDFBackground {
                Label(page.title, systemImage: "doc.richtext")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
            } else {
                Text(page.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                ForEach(page.previewLines.prefix(3), id: \.self) { line in
                    Text(line)
                        .font(.system(size: 7))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            if let outlineTitle = page.outlineTitle {
                Label(outlineTitle, systemImage: "list.bullet.rectangle")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.indigo)
                    .lineLimit(1)
            }

            if page.hasUserAnnotations {
                Label("批注", systemImage: "scribble")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.blue)
            }

            ForEach(page.elements.prefix(3)) { element in
                HStack(spacing: 4) {
                    Image(systemName: element.kind.symbolName)
                        .font(.system(size: 7, weight: .semibold))
                    Text(element.title)
                        .font(.system(size: 7))
                        .lineLimit(1)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .foregroundStyle(element.color.color)
                .background(element.color.color.opacity(0.12), in: Capsule())
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct PaperCanvas: View {
    @Bindable var library: NotebookLibrary
    let notebook: Notebook?
    let page: NotebookPage?
    let activeTool: WritingTool
    let selectedInk: InkSwatch
    var isActive = true

    var body: some View {
        let hasPDFBackground = library.pdfBackgroundAsset(for: page) != nil
        let rotationDegrees = Double(page?.normalizedRotationDegrees ?? 0)
        let rotationScale = page?.rotationScaleForDisplay ?? 1

        ZStack(alignment: .topLeading) {
            PageBackground(library: library, page: page)
            PencilCanvas(
                activeTool: activeTool,
                selectedInk: selectedInk,
                drawingData: page?.drawingData ?? Data()
            ) { data in
                guard let pageID = page?.id else { return }
                library.updateDrawingData(data, for: pageID)
            }
            .id(page?.id)
            .rotationEffect(.degrees(rotationDegrees))
            .scaleEffect(rotationScale)
                .accessibilityIdentifier("handwriting-canvas")

            VStack(alignment: .leading, spacing: 12) {
                if hasPDFBackground {
                    PDFPageBadge(page: page)
                } else {
                    Label(notebook?.kind.rawValue ?? "笔记页", systemImage: notebook?.kind.symbolName ?? "doc")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(page?.title ?? "空白页")
                        .font(.title2.bold())
                    ForEach(page?.previewLines ?? [], id: \.self) { line in
                        Text(line)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                if let summary = page?.transcriptSummary {
                    Label(summary, systemImage: "waveform")
                        .font(.callout)
                        .foregroundStyle(.blue)
                        .padding(.top, 4)
                }

                FeatureElementGrid(page: page, selectedElementID: isActive ? library.selectedElementID : nil, hidesBackgroundPDF: hasPDFBackground)
            }
            .padding(48)
            .rotationEffect(.degrees(rotationDegrees))
            .scaleEffect(rotationScale)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 20, x: 0, y: 12)
    }
}

struct PageBackground: View {
    @Bindable var library: NotebookLibrary
    let page: NotebookPage?

    var body: some View {
        Group {
            if let asset = library.pdfBackgroundAsset(for: page), let fileURL = library.fileURL(for: asset) {
                PDFPageBackground(fileURL: fileURL, pageIndex: asset.sourcePageIndex ?? 0)
            } else {
                PaperPattern(template: page?.template ?? .ruled)
            }
        }
        .rotationEffect(.degrees(Double(page?.normalizedRotationDegrees ?? 0)))
        .scaleEffect(page?.rotationScaleForDisplay ?? 1)
    }
}

private extension NotebookPage {
    var rotationScaleForDisplay: Double {
        normalizedRotationDegrees == 90 || normalizedRotationDegrees == 270 ? 0.75 : 1
    }
}

struct PDFPageBackground: UIViewRepresentable {
    let fileURL: URL
    let pageIndex: Int

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.backgroundColor = .white
        view.displayMode = .singlePage
        view.displayDirection = .vertical
        view.autoScales = true
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != fileURL {
            view.document = PDFDocument(url: fileURL)
        }
        if let page = view.document?.page(at: pageIndex) {
            view.go(to: page)
        }
        view.autoScales = true
    }
}

struct PDFPageBadge: View {
    let page: NotebookPage?

    var body: some View {
        Label(page?.title ?? "PDF 页面", systemImage: "doc.richtext")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.thinMaterial, in: Capsule())
    }
}

struct PaperPattern: View {
    let template: PaperTemplate

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))

            switch template {
            case .blank:
                break
            case .ruled, .cornell:
                drawHorizontalLines(in: &context, size: size, spacing: 34, color: Color.blue.opacity(0.18))
                if template == .cornell {
                    drawLine(in: &context, from: CGPoint(x: size.width * 0.32, y: 0), to: CGPoint(x: size.width * 0.32, y: size.height), color: Color.red.opacity(0.22))
                }
            case .grid:
                drawGrid(in: &context, size: size, spacing: 32)
            case .dotted:
                drawDots(in: &context, size: size, spacing: 28)
            case .planner:
                drawHorizontalLines(in: &context, size: size, spacing: 58, color: Color.green.opacity(0.14))
                drawLine(in: &context, from: CGPoint(x: size.width * 0.18, y: 0), to: CGPoint(x: size.width * 0.18, y: size.height), color: Color.green.opacity(0.18))
                drawLine(in: &context, from: CGPoint(x: size.width * 0.68, y: 0), to: CGPoint(x: size.width * 0.68, y: size.height), color: Color.green.opacity(0.18))
            case .music:
                var y: CGFloat = 80
                while y < size.height - 80 {
                    for offset in stride(from: CGFloat(0), through: 36, by: 9) {
                        drawLine(in: &context, from: CGPoint(x: 54, y: y + offset), to: CGPoint(x: size.width - 54, y: y + offset), color: Color.gray.opacity(0.28))
                    }
                    y += 88
                }
            }
        }
    }

    private func drawHorizontalLines(in context: inout GraphicsContext, size: CGSize, spacing: CGFloat, color: Color) {
        var y = spacing
        while y < size.height {
            drawLine(in: &context, from: CGPoint(x: 0, y: y), to: CGPoint(x: size.width, y: y), color: color)
            y += spacing
        }
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize, spacing: CGFloat) {
        var x: CGFloat = 0
        while x < size.width {
            drawLine(in: &context, from: CGPoint(x: x, y: 0), to: CGPoint(x: x, y: size.height), color: Color.blue.opacity(0.12))
            x += spacing
        }

        drawHorizontalLines(in: &context, size: size, spacing: spacing, color: Color.blue.opacity(0.12))
    }

    private func drawDots(in context: inout GraphicsContext, size: CGSize, spacing: CGFloat) {
        var x = spacing
        while x < size.width {
            var y = spacing
            while y < size.height {
                let dot = CGRect(x: x - 1, y: y - 1, width: 2, height: 2)
                context.fill(Path(ellipseIn: dot), with: .color(Color.gray.opacity(0.32)))
                y += spacing
            }
            x += spacing
        }
    }

    private func drawLine(in context: inout GraphicsContext, from start: CGPoint, to end: CGPoint, color: Color) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(path, with: .color(color), lineWidth: 1)
    }
}

struct PencilCanvas: UIViewRepresentable {
    let activeTool: WritingTool
    let selectedInk: InkSwatch
    let drawingData: Data
    let onDrawingChange: (Data) -> Void

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.tool = resolvedTool
        canvas.delegate = context.coordinator
        context.coordinator.apply(drawingData, to: canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvas.tool = resolvedTool
        context.coordinator.apply(drawingData, to: canvas)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private var resolvedTool: PKTool {
        switch activeTool {
        case .pen, .text, .lasso, .shapes, .tape, .ruler, .laser, .zoom, .image, .audio, .convert:
            return PKInkingTool(.pen, color: UIColor(selectedInk.color), width: 4)
        case .pencil:
            return PKInkingTool(.pencil, color: UIColor(selectedInk.color), width: 4)
        case .highlighter:
            return PKInkingTool(.marker, color: UIColor(selectedInk.color).withAlphaComponent(0.35), width: 16)
        case .eraser:
            return PKEraserTool(.bitmap)
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvas
        private var lastAppliedData = Data()

        init(parent: PencilCanvas) {
            self.parent = parent
        }

        func apply(_ data: Data, to canvas: PKCanvasView) {
            guard data != lastAppliedData else { return }
            if data.isEmpty {
                canvas.drawing = PKDrawing()
            } else if let drawing = try? PKDrawing(data: data) {
                canvas.drawing = drawing
            }
            lastAppliedData = data
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let data = canvasView.drawing.dataRepresentation()
            guard data != lastAppliedData else { return }
            lastAppliedData = data
            parent.onDrawingChange(data)
        }
    }
}

struct FeatureElementGrid: View {
    let page: NotebookPage?
    let selectedElementID: PageElement.ID?
    var hidesBackgroundPDF = false

    private let columns = [
        GridItem(.adaptive(minimum: 152, maximum: 220), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
            ForEach(page?.elements ?? []) { element in
                FeatureChip(
                    symbolName: element.isLocked ? "lock.fill" : element.kind.symbolName,
                    title: element.title,
                    detail: element.detail,
                    color: element.color.color.opacity(0.14),
                    isSelected: selectedElementID == element.id
                )
            }

            ForEach(filteredAssets) { asset in
                FeatureChip(symbolName: asset.kind.symbolName, title: asset.title, detail: asset.detailText, color: Color.blue.opacity(0.12))
            }
        }
        .padding(.top, 8)
    }

    private var filteredAssets: [ImportedAsset] {
        (page?.assets ?? []).filter { asset in
            !(hidesBackgroundPDF && asset.kind == .pdf && asset.sourcePageIndex != nil)
        }
    }
}

struct FeatureChip: View {
    let symbolName: String
    let title: String
    let detail: String
    let color: Color
    var isSelected = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .frame(width: 26, height: 26)
                .background(color, in: RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.12) : .white.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? Color.accentColor.opacity(0.65) : .black.opacity(0.06), lineWidth: isSelected ? 1.5 : 1))
    }
}

struct EditorSidePanelView: View {
    @Bindable var library: NotebookLibrary
    @Bindable var audioCapture: AudioCaptureController
    @Bindable var audioPlayback: AudioPlaybackController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                ForEach(EditorSidePanel.allCases) { panel in
                    Button {
                        library.selectedSidePanel = panel
                    } label: {
                        Image(systemName: panel.symbolName)
                            .frame(width: 34, height: 30)
                            .background(library.selectedSidePanel == panel ? Color.accentColor.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .help(panel.rawValue)
                    .accessibilityLabel(panel.rawValue)
                    .accessibilityIdentifier("editor-side-panel-\(panel.accessibilityID)")
                }
            }

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch library.selectedSidePanel {
                    case .pages:
                        PagesPanel(library: library)
                    case .content:
                        ContentPanel(library: library)
                    case .audio:
                        AudioPanel(library: library, audioCapture: audioCapture, audioPlayback: audioPlayback)
                    case .study:
                        StudyPanel(library: library)
                    case .share:
                        SharePanel(library: library)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .accessibilityIdentifier("editor-side-panel")
    }
}

struct PagesPanel: View {
    @Bindable var library: NotebookLibrary

    var body: some View {
        PanelHeader(title: "内容管理器", detail: "页面、书签、大纲")

        if library.isMultiNoteEnabled {
            WorkspaceMiniSwitcher(library: library)
        }

        PageManagerFilterBar(library: library)

        Button {
            library.toggleCurrentPageOutline()
        } label: {
            Label(library.selectedPage?.outlineTitle == nil ? "加入大纲" : "移出大纲", systemImage: "list.bullet.rectangle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("toggle-current-page-outline-button")

        HStack(spacing: 8) {
            Button {
                library.setPageSelectionMode(!library.isSelectingPages)
            } label: {
                Label(library.isSelectingPages ? "完成" : "选择", systemImage: library.isSelectingPages ? "checkmark.circle" : "checklist")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("page-selection-toggle-button")

            if library.isSelectingPages {
                Button {
                    library.selectPages(Set(visiblePageEntries.map { $0.page.id }))
                } label: {
                    Label("全选", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("select-all-pages-button")
            }
        }

        if library.isSelectingPages {
            Text("已选择 \(library.selectedPageCount) 页")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("selected-pages-count-label")
        }

        if library.pageManagerFilter == .outline {
            OutlineManagerSection(library: library, entries: visiblePageEntries)
        } else if visiblePageEntries.isEmpty {
            PageManagerEmptyState(filter: library.pageManagerFilter)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], spacing: 12) {
                ForEach(visiblePageEntries) { entry in
                    PageManagerThumbnail(library: library, page: entry.page, index: entry.index)
                        .draggable(entry.page.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            return moveDroppedPages(items, before: entry.page.id)
                        }
                }
            }
            .dropDestination(for: String.self) { items, _ in
                return moveDroppedPagesToEnd(items)
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            Menu {
                ForEach(PaperTemplate.allCases) { template in
                    Button {
                        library.addPage(template: template)
                    } label: {
                        Label(template.rawValue, systemImage: "plus.square.on.square")
                    }
                }
            } label: {
                Label("添加页面", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Menu {
                ForEach(PaperTemplate.allCases) { template in
                    Button {
                        library.changeCurrentPageTemplate(to: template)
                    } label: {
                        Label(template.rawValue, systemImage: template == library.selectedPage?.template ? "checkmark" : "doc")
                    }
                }
            } label: {
                Label(library.selectedPage?.template.rawValue ?? "纸张模板", systemImage: "doc.text.image")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            HStack {
                Button {
                    if library.isSelectingPages {
                        library.moveSelectedPagesUp()
                    } else {
                        library.moveCurrentPageUp()
                    }
                } label: {
                    Label("上移", systemImage: "arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!library.isSelectingPages && !library.canMoveCurrentPageUp)
                .accessibilityIdentifier("move-page-up-button")

                Button {
                    if library.isSelectingPages {
                        library.moveSelectedPagesDown()
                    } else {
                        library.moveCurrentPageDown()
                    }
                } label: {
                    Label("下移", systemImage: "arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!library.isSelectingPages && !library.canMoveCurrentPageDown)
                .accessibilityIdentifier("move-page-down-button")
            }
            .buttonStyle(.bordered)

            HStack {
                Button {
                    library.rotateCurrentOrSelectedPagesCounterclockwise()
                } label: {
                    Label("左转", systemImage: "rotate.left")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("rotate-pages-left-button")

                Button {
                    library.rotateCurrentOrSelectedPagesClockwise()
                } label: {
                    Label("右转", systemImage: "rotate.right")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("rotate-pages-right-button")
            }
            .buttonStyle(.bordered)

            HStack {
                Button {
                    if library.isSelectingPages {
                        library.duplicateSelectedPages()
                    } else {
                        library.duplicateCurrentPage()
                    }
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("duplicate-current-page-button")

                Button {
                    library.clearSelectedPagesContent()
                } label: {
                    Label("清空", systemImage: "eraser")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("clear-selected-pages-button")
            }
            .buttonStyle(.bordered)

            if library.canTransferPagesToOtherPane {
                HStack {
                    Button {
                        library.copyPagesToOtherPane()
                    } label: {
                        Label("复制到另一笔记", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("copy-pages-to-other-pane-button")

                    Button {
                        library.movePagesToOtherPane()
                    } label: {
                        Label("移到另一笔记", systemImage: "arrowshape.turn.up.right")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!library.canMovePagesToOtherPane)
                    .accessibilityIdentifier("move-pages-to-other-pane-button")
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Button {
                    _ = try? library.exportCurrentOrSelectedPagesToPDF()
                } label: {
                    Label(library.isSelectingPages ? "导出所选" : "导出当前页", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("document-export-pdf-button")

                Button(role: .destructive) {
                    if library.isSelectingPages {
                        library.deleteSelectedPages()
                    } else {
                        library.deleteCurrentPage()
                    }
                } label: {
                    Label("删除", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .disabled(library.isSelectingPages ? !library.canDeleteSelectedPages : !library.canDeleteCurrentPage)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("delete-current-page-button")
            }

            Button {
                library.toggleCurrentPageBookmark()
            } label: {
                Label("切换书签", systemImage: "bookmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            HStack {
                Button {
                    library.openNextNotebookInMultiNote(layout: .horizontal)
                } label: {
                    Label("右侧打开", systemImage: "rectangle.split.2x1")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("open-multinote-right-button")

                Button {
                    if library.multiNoteLayout == .horizontal {
                        library.setMultiNoteLayout(.vertical)
                    } else {
                        library.setMultiNoteLayout(.horizontal)
                    }
                } label: {
                    Label("切换布局", systemImage: library.multiNoteLayout == .horizontal ? "rectangle.split.1x2" : "rectangle.split.2x1")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!library.isMultiNoteEnabled)
                .accessibilityIdentifier("panel-toggle-multinote-layout-button")
            }
            .buttonStyle(.bordered)

            if library.isMultiNoteEnabled {
                Button {
                    library.closeMultiNote()
                } label: {
                    Label("关闭副笔记", systemImage: "xmark.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("panel-close-multinote-button")
            }

            if !((library.selectedPage?.elements.isEmpty ?? true) && (library.selectedPage?.assets.isEmpty ?? true)) {
                Button {
                    library.selectedSidePanel = .content
                } label: {
                    Label("对象图层", systemImage: "lasso")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("open-content-panel-button")
            }

            if !(library.selectedNotebook?.recordings.isEmpty ?? true) {
                Button {
                    library.selectedSidePanel = .audio
                } label: {
                    Label("录音回放", systemImage: "waveform")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("open-audio-panel-button")
            }
        }
    }

    private func moveDroppedPages(_ items: [String], before destinationPageID: NotebookPage.ID) -> Bool {
        guard let draggedPageID = items.compactMap(UUID.init(uuidString:)).first else { return false }
        library.movePageOrSelectedPages(draggedPageID: draggedPageID, before: destinationPageID)
        return true
    }

    private func moveDroppedPagesToEnd(_ items: [String]) -> Bool {
        guard let draggedPageID = items.compactMap(UUID.init(uuidString:)).first else { return false }
        library.movePageOrSelectedPagesToEnd(draggedPageID: draggedPageID)
        return true
    }

    private var visiblePageEntries: [PageManagerEntry] {
        _ = library.pageManagerRevision
        return (library.selectedNotebook?.pages ?? []).enumerated().compactMap { index, page in
            library.pageManagerFilter.includes(page) ? PageManagerEntry(index: index, page: page) : nil
        }
    }
}

struct PageManagerEntry: Identifiable {
    let index: Int
    let page: NotebookPage

    var id: NotebookPage.ID { page.id }
}

struct PageManagerFilterBar: View {
    @Bindable var library: NotebookLibrary
    private let rows: [[PageManagerFilter]] = [
        [.all, .bookmarks],
        [.annotated, .outline]
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(rows[rowIndex]) { filter in
                        Button {
                            library.pageManagerFilter = filter
                        } label: {
                            Text(filter.rawValue)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(library.pageManagerFilter == filter ? Color.accentColor : Color.secondary)
                        .background(library.pageManagerFilter == filter ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(library.pageManagerFilter == filter ? Color.accentColor.opacity(0.28) : Color.clear, lineWidth: 1)
                        )
                        .accessibilityLabel(filter.rawValue)
                        .accessibilityIdentifier("page-manager-filter-\(filter.accessibilityID)-button")
                    }
                }
            }
        }
    }
}

struct PageManagerEmptyState: View {
    let filter: PageManagerFilter

    var body: some View {
        Label(emptyText, systemImage: "tray")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier("page-manager-empty-state")
    }

    private var emptyText: String {
        switch filter {
        case .all: return "还没有页面"
        case .bookmarks: return "没有书签页面"
        case .annotated: return "没有已批注页面"
        case .outline: return "没有大纲条目"
        }
    }
}

struct OutlineManagerSection: View {
    @Bindable var library: NotebookLibrary
    let entries: [PageManagerEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                library.toggleCurrentPageOutline()
            } label: {
                Label(library.selectedPage?.outlineTitle == nil ? "加入大纲" : "移出大纲", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("outline-section-toggle-page-outline-button")

            Text("大纲条目")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("outline-manager-section")

            if entries.isEmpty {
                PageManagerEmptyState(filter: .outline)
            } else {
                ForEach(entries) { entry in
                    HStack(spacing: 8) {
                        Button {
                            library.selectPage(entry.page.id)
                        } label: {
                            HStack(spacing: 8) {
                                Text("\(entry.index + 1)")
                                    .font(.caption2.monospacedDigit().weight(.bold))
                                    .frame(width: 24, height: 22)
                                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.page.outlineTitle ?? entry.page.title)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                    Text(entry.page.title)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier(entry.page.id == library.selectedPage?.id ? "outline-current-page-row" : "outline-row-\(entry.index + 1)")

                        Button {
                            library.selectPage(entry.page.id)
                            library.toggleCurrentPageOutline()
                        } label: {
                            Image(systemName: "minus.circle")
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("remove-outline-row-\(entry.index + 1)-button")
                    }
                    .padding(8)
                    .background(library.selectedPage?.id == entry.page.id ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct PageManagerThumbnail: View {
    @Bindable var library: NotebookLibrary
    let page: NotebookPage
    let index: Int

    var body: some View {
        Button {
            if library.isSelectingPages {
                library.togglePageSelection(page.id)
            } else {
                library.selectPage(page.id)
            }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                ZStack(alignment: .topTrailing) {
                    PageThumbnailPreview(library: library, page: page)
                        .frame(height: 132)

                    if library.isSelectingPages {
                        Image(systemName: library.selectedPageIDs.contains(page.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(library.selectedPageIDs.contains(page.id) ? Color.accentColor : Color.secondary)
                            .symbolRenderingMode(.hierarchical)
                            .padding(7)
                            .background(.thinMaterial, in: Circle())
                            .padding(6)
                    }

                    if page.isBookmarked {
                        Image(systemName: "bookmark.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                            .padding(7)
                            .background(.thinMaterial, in: Circle())
                            .padding(6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }

                    if page.hasUserAnnotations {
                        Image(systemName: "pencil.tip.crop.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                            .padding(7)
                            .background(.thinMaterial, in: Circle())
                            .padding(6)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }

                HStack(spacing: 6) {
                    Text("\(index + 1)")
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .frame(width: 24, height: 22)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))

                    VStack(alignment: .leading, spacing: 1) {
                        Text(page.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(page.template.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(8)
            .background(isActive ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isActive ? Color.accentColor.opacity(0.45) : Color.black.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityIdentifier("page-row-\(index + 1)")
    }

    private var isActive: Bool {
        library.selectedPage?.id == page.id || library.selectedPageIDs.contains(page.id)
    }
}

struct WorkspaceMiniSwitcher: View {
    @Bindable var library: NotebookLibrary

    var body: some View {
        HStack(spacing: 8) {
            Button {
                library.activatePane(.primary)
            } label: {
                Label("主笔记", systemImage: WorkspacePane.primary.symbolName)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(library.activePane == .primary ? .accentColor : .secondary)
            .accessibilityIdentifier("workspace-primary-tab")

            Button {
                library.activatePane(.secondary)
            } label: {
                Label("副笔记", systemImage: WorkspacePane.secondary.symbolName)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(library.activePane == .secondary ? .accentColor : .secondary)
            .accessibilityIdentifier("workspace-secondary-tab")
        }
    }
}

struct ContentPanel: View {
    @Bindable var library: NotebookLibrary

    var body: some View {
        PanelHeader(title: "页面内容", detail: "图层、附件、贴纸和遮挡")

        if (library.selectedPage?.elements.isEmpty ?? true) && (library.selectedPage?.assets.isEmpty ?? true) {
            Text("当前页还没有插入对象。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }

        ForEach(Array((library.selectedPage?.elements ?? []).enumerated()), id: \.element.id) { index, element in
            Button {
                library.selectElement(element)
            } label: {
                PanelRow(
                    symbolName: element.isLocked ? "lock.fill" : element.kind.symbolName,
                    title: element.title,
                    detail: "\(element.detail) · \(element.frame.detailText)"
                )
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(library.selectedElementID == element.id ? Color.accentColor.opacity(0.11) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(index == 0 ? "content-panel-first-element-button" : "content-panel-element-\(element.id.uuidString)")
        }

        if let selectedElement = library.selectedElement {
            ObjectInspector(library: library, element: selectedElement)
        } else if library.hasCopiedElement {
            Button {
                library.pasteCopiedElement()
            } label: {
                Label("粘贴对象", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("paste-selected-object-button")
        }

        ForEach(library.selectedPage?.assets ?? []) { asset in
            PanelRow(symbolName: asset.kind.symbolName, title: asset.title, detail: asset.detailText)
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(PageElementKind.allCases) { kind in
                Button {
                    library.addElement(kind: kind)
                } label: {
                    Label(kind.rawValue, systemImage: kind.symbolName)
                        .labelStyle(.iconOnly)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help(kind.rawValue)
            }
        }
    }
}

struct ObjectInspector: View {
    @Bindable var library: NotebookLibrary
    let element: PageElement

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("对象菜单")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("object-inspector")
                    Text(element.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: element.isLocked ? "lock.fill" : element.kind.symbolName)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            }

            Text("位置 \(element.frame.detailText) · \(Int(element.rotationDegrees))° · \(String(format: "%.1fx", element.scale))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .accessibilityIdentifier("selected-object-summary")

            HStack(spacing: 8) {
                ObjectActionButton(title: "上移", symbolName: "arrow.up", accessibilityID: "move-selected-object-up-button", isDisabled: element.isLocked) {
                    library.moveSelectedElementBy(x: 0, y: -12)
                }
                ObjectActionButton(title: "左移", symbolName: "arrow.left", accessibilityID: "move-selected-object-left-button", isDisabled: element.isLocked) {
                    library.moveSelectedElementBy(x: -12, y: 0)
                }
                ObjectActionButton(title: "右移", symbolName: "arrow.right", accessibilityID: "move-selected-object-right-button", isDisabled: element.isLocked) {
                    library.moveSelectedElementBy(x: 12, y: 0)
                }
                ObjectActionButton(title: "下移", symbolName: "arrow.down", accessibilityID: "move-selected-object-down-button", isDisabled: element.isLocked) {
                    library.moveSelectedElementBy(x: 0, y: 12)
                }
            }

            HStack(spacing: 8) {
                ObjectActionButton(title: "缩小", symbolName: "minus.magnifyingglass", accessibilityID: "scale-selected-object-down-button", isDisabled: element.isLocked) {
                    library.scaleSelectedElement(by: 0.9)
                }
                ObjectActionButton(title: "放大", symbolName: "plus.magnifyingglass", accessibilityID: "scale-selected-object-up-button", isDisabled: element.isLocked) {
                    library.scaleSelectedElement(by: 1.1)
                }
                ObjectActionButton(title: "逆时针旋转", symbolName: "arrow.counterclockwise", accessibilityID: "rotate-selected-object-left-button", isDisabled: element.isLocked) {
                    library.rotateSelectedElement(by: -15)
                }
                ObjectActionButton(title: "顺时针旋转", symbolName: "arrow.clockwise", accessibilityID: "rotate-selected-object-right-button", isDisabled: element.isLocked) {
                    library.rotateSelectedElement(by: 15)
                }
            }

            HStack(spacing: 8) {
                ObjectActionButton(title: "复制", symbolName: "doc.on.doc", accessibilityID: "copy-selected-object-button") {
                    library.copySelectedElement()
                }
                ObjectActionButton(title: "副本", symbolName: "plus.square.on.square", accessibilityID: "duplicate-selected-object-button") {
                    library.duplicateSelectedElement()
                }
                ObjectActionButton(title: "粘贴", symbolName: "doc.on.clipboard", accessibilityID: "paste-selected-object-button", isDisabled: !library.hasCopiedElement) {
                    library.pasteCopiedElement()
                }
                ObjectActionButton(title: element.isLocked ? "解锁" : "锁定", symbolName: element.isLocked ? "lock.open" : "lock", accessibilityID: "lock-selected-object-button") {
                    library.toggleSelectedElementLock()
                }
            }

            if library.canTransferSelectedElementToOtherPane {
                HStack(spacing: 8) {
                    ObjectActionButton(title: "复制到另一笔记", symbolName: "doc.on.doc", accessibilityID: "copy-selected-object-to-other-pane-button") {
                        library.copySelectedElementToOtherPane()
                    }
                    ObjectActionButton(title: "移到另一笔记", symbolName: "arrowshape.turn.up.right", accessibilityID: "move-selected-object-to-other-pane-button", isDisabled: element.isLocked) {
                        library.moveSelectedElementToOtherPane()
                    }
                }
            }

            HStack(spacing: 8) {
                ObjectActionButton(title: "剪切", symbolName: "scissors", accessibilityID: "cut-selected-object-button", isDisabled: element.isLocked) {
                    library.cutSelectedElement()
                }
                ObjectActionButton(title: "删除", symbolName: "trash", role: .destructive, accessibilityID: "delete-selected-object-button", isDisabled: element.isLocked) {
                    library.deleteSelectedElement()
                }
            }
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct ObjectActionButton: View {
    let title: String
    let symbolName: String
    var role: ButtonRole?
    let accessibilityID: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: symbolName)
                .labelStyle(.iconOnly)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.bordered)
        .disabled(isDisabled)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityID)
    }
}

struct AudioPanel: View {
    @Bindable var library: NotebookLibrary
    @Bindable var audioCapture: AudioCaptureController
    @Bindable var audioPlayback: AudioPlaybackController

    var body: some View {
        PanelHeader(title: "录音与转写", detail: "Notability 式音频同步")

        Button {
            Task {
                await audioCapture.toggleRecording(library: library)
            }
        } label: {
            Label(library.isRecordingAudio ? "停止录音并链接页面" : "开始录音", systemImage: library.isRecordingAudio ? "stop.circle.fill" : "record.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)

        if let errorMessage = audioCapture.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
        }

        if let errorMessage = audioPlayback.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
        }

        if let recording = library.activePlaybackRecording {
            AudioPlaybackControls(library: library, audioPlayback: audioPlayback, recording: recording)
        }

        ForEach(library.selectedNotebook?.recordings ?? []) { recording in
            Button {
                Task {
                    await audioPlayback.togglePlayback(library: library, recording: recording)
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: library.activePlaybackRecordingID == recording.id && library.isPlayingAudio ? "pause.circle.fill" : "play.circle")
                        .frame(width: 28, height: 28)
                        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(recording.title)
                            .font(.subheadline.weight(.semibold))
                        Text(recording.detailText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    Spacer()
                }
                .padding(8)
                .background(library.activePlaybackRecordingID == recording.id ? Color.accentColor.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("audio-recording-row-\(recording.id.uuidString)")
        }

        if library.selectedNotebook?.recordings.isEmpty ?? true {
            Text("录音会保存转写，并与页面书写同步。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

struct AudioPlaybackControls: View {
    @Bindable var library: NotebookLibrary
    @Bindable var audioPlayback: AudioPlaybackController
    let recording: AudioRecording

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(AudioRecording.formattedDuration(library.audioPlaybackPosition))
                    .font(.caption.monospacedDigit())
                Slider(
                    value: Binding(
                        get: { library.audioPlaybackPosition },
                        set: { newValue in
                            audioPlayback.seek(library: library, to: newValue)
                        }
                    ),
                    in: 0...max(recording.duration, 1)
                )
                Text(AudioRecording.formattedDuration(recording.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    audioPlayback.skip(library: library, by: -10)
                } label: {
                    Label("后退 10 秒", systemImage: "gobackward.10")
                        .labelStyle(.iconOnly)
                }
                .accessibilityIdentifier("audio-skip-back-button")

                Button {
                    Task {
                        await audioPlayback.togglePlayback(library: library, recording: recording)
                    }
                } label: {
                    Label(library.isPlayingAudio ? "暂停" : "播放", systemImage: library.isPlayingAudio ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("audio-playback-toggle-button")

                Button {
                    audioPlayback.skip(library: library, by: 10)
                } label: {
                    Label("前进 10 秒", systemImage: "goforward.10")
                        .labelStyle(.iconOnly)
                }
                .accessibilityIdentifier("audio-skip-forward-button")
            }
            .buttonStyle(.bordered)

            HStack {
                Text("倍速")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("倍速", selection: Binding(
                    get: { recording.playbackRate ?? 1.0 },
                    set: { newValue in
                        audioPlayback.setRate(library: library, recording: recording, rate: newValue)
                    }
                )) {
                    Text("0.5x").tag(0.5)
                    Text("1x").tag(1.0)
                    Text("1.5x").tag(1.5)
                    Text("2x").tag(2.0)
                }
                .pickerStyle(.segmented)
            }

            HStack {
                Text("Voice Boost")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { recording.voiceBoostLevel ?? 0 },
                        set: { newValue in
                            audioPlayback.setVoiceBoost(library: library, recording: recording, level: newValue)
                        }
                    ),
                    in: 0...1
                )
            }
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("audio-playback-controls")
    }
}

struct StudyPanel: View {
    @Bindable var library: NotebookLibrary

    var body: some View {
        PanelHeader(title: "学习材料", detail: "摘要、测验、闪卡和主动回忆")

        Button {
            library.createStudySetFromCurrentPage()
        } label: {
            Label("从当前页生成学习卡", systemImage: "rectangle.on.rectangle.angled")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)

        ForEach(library.selectedNotebook?.studySets ?? []) { set in
            VStack(alignment: .leading, spacing: 8) {
                PanelRow(symbolName: "rectangle.on.rectangle.angled", title: set.title, detail: "\(set.cards.count) 张卡片")
                ForEach(set.cards.prefix(3)) { card in
                    Text(card.prompt)
                        .font(.caption)
                        .foregroundStyle(card.isStarred ? .yellow : .secondary)
                }
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SharePanel: View {
    @Bindable var library: NotebookLibrary
    @State private var exportErrorMessage: String?

    var body: some View {
        PanelHeader(title: "共享与协作", detail: "实时协作、导出和权限")

        HStack {
            Button {
                library.shareCurrentNotebook()
            } label: {
                Label("开启共享", systemImage: "person.2.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                do {
                    try library.exportCurrentNotebookToPDF()
                    exportErrorMessage = nil
                } catch {
                    exportErrorMessage = error.localizedDescription
                }
            } label: {
                Label("导出 PDF", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("export-current-notebook-pdf-button")
        }

        ForEach(library.selectedNotebook?.collaborators ?? []) { collaborator in
            PanelRow(symbolName: "person.crop.circle", title: collaborator.name, detail: collaborator.role)
        }

        if let exportErrorMessage {
            Label(exportErrorMessage, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
        }

        if let exports = library.selectedNotebook?.exportedDocuments, !exports.isEmpty {
            Divider()
            PanelHeader(title: "导出记录", detail: "可分享到课堂、云盘或其他应用")
            ForEach(exports) { export in
                PanelRow(symbolName: "doc.richtext", title: export.title, detail: export.detailText)
            }
        }

        Divider()

        PanelRow(symbolName: "square.and.arrow.up", title: "导出", detail: "PDF、图片、SmartNotes 包")
        PanelRow(symbolName: "lock.shield", title: "权限", detail: "只读、可评论、可编辑")
    }
}

struct PanelHeader: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct PanelRow: View {
    let symbolName: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
    }
}

struct QuickActionChip: View {
    let title: String
    let symbolName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbolName)
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}

struct NewDocumentMenu: View {
    @Bindable var library: NotebookLibrary
    let title: String
    let symbolName: String
    var importFiles: (() -> Void)?

    var body: some View {
        Menu {
            Section("文档类型") {
                if let importFiles {
                    Button {
                        importFiles()
                    } label: {
                        Label("从文件导入", systemImage: "folder")
                    }
                }

                ForEach(DocumentCreationPreset.allCases) { preset in
                    Button {
                        library.createDocument(preset)
                    } label: {
                        Label(preset.rawValue, systemImage: preset.symbolName)
                    }
                }
            }

            Section("笔记本纸张") {
                ForEach(PaperTemplate.allCases) { template in
                    Button {
                        library.createDocument(.notebook, template: template)
                    } label: {
                        Label(template.rawValue, systemImage: "doc")
                    }
                }
            }
        } label: {
            Label(title, systemImage: symbolName)
        }
    }
}

struct EmptyLibraryView: View {
    let createNotebook: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("没有笔记本", systemImage: "book.closed")
        } description: {
            Text("新建一个笔记本开始书写。")
        } actions: {
            Button("新建笔记本", action: createNotebook)
                .buttonStyle(.borderedProminent)
        }
    }
}

@MainActor
@Observable
final class AudioCaptureController {
    var errorMessage: String?

    private var recorder: AVAudioRecorder?
    private var activeFileName: String?
    private var activeFileURL: URL?

    func toggleRecording(library: NotebookLibrary) async {
        if library.isRecordingAudio {
            stopRecording(library: library)
        } else {
            await startRecording(library: library)
        }
    }

    private func startRecording(library: NotebookLibrary) async {
        do {
            let destination = try library.createRecordingDestination()
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            let recorder = try AVAudioRecorder(url: destination.url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            guard recorder.record() else {
                throw AudioCaptureError.cannotStart
            }

            self.recorder = recorder
            activeFileName = destination.storedFileName
            activeFileURL = destination.url
            errorMessage = nil
            library.beginAudioRecording(storedFileName: destination.storedFileName)
        } catch {
            errorMessage = error.localizedDescription
            library.isRecordingAudio = false
            library.activeRecordingStartedAt = nil
            library.activeRecordingFileName = nil
        }
    }

    private func stopRecording(library: NotebookLibrary) {
        let duration = recorder?.currentTime ?? 0
        recorder?.stop()
        recorder = nil

        let byteCount = activeFileURL.flatMap { url in
            try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int
        }
        library.finishAudioRecording(
            storedFileName: activeFileName,
            duration: max(duration, 0),
            byteCount: byteCount
        )
        activeFileName = nil
        activeFileURL = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    enum AudioCaptureError: LocalizedError {
        case cannotStart

        var errorDescription: String? {
            switch self {
            case .cannotStart:
                return "无法开始录音，请检查麦克风权限。"
            }
        }
    }
}

@MainActor
@Observable
final class AudioPlaybackController {
    var errorMessage: String?

    private var player: AVAudioPlayer?
    private var activeRecordingID: AudioRecording.ID?

    func togglePlayback(library: NotebookLibrary, recording: AudioRecording) async {
        do {
            if library.isPlayingAudio && activeRecordingID == recording.id {
                pause(library: library)
                return
            }

            try preparePlayerIfNeeded(library: library, recording: recording)
            player?.currentTime = library.audioPlaybackPosition
            player?.enableRate = true
            player?.rate = Float(recording.playbackRate ?? 1.0)
            player?.play()
            library.activePlaybackRecordingID = recording.id
            library.isPlayingAudio = true
            activeRecordingID = recording.id
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            library.toggleAudioPlayback(for: recording)
        }
    }

    func pause(library: NotebookLibrary) {
        library.audioPlaybackPosition = player?.currentTime ?? library.audioPlaybackPosition
        player?.pause()
        library.stopAudioPlayback()
    }

    func seek(library: NotebookLibrary, to position: TimeInterval) {
        library.seekAudio(to: position)
        player?.currentTime = library.audioPlaybackPosition
    }

    func skip(library: NotebookLibrary, by interval: TimeInterval) {
        library.skipAudio(by: interval)
        player?.currentTime = library.audioPlaybackPosition
    }

    func setRate(library: NotebookLibrary, recording: AudioRecording, rate: Double) {
        library.setAudioPlaybackRate(rate, for: recording.id)
        player?.enableRate = true
        player?.rate = Float(rate)
    }

    func setVoiceBoost(library: NotebookLibrary, recording: AudioRecording, level: Double) {
        library.setVoiceBoostLevel(level, for: recording.id)
    }

    private func preparePlayerIfNeeded(library: NotebookLibrary, recording: AudioRecording) throws {
        guard activeRecordingID != recording.id || player == nil else { return }
        guard let fileURL = library.fileURL(for: recording), FileManager.default.fileExists(atPath: fileURL.path) else {
            throw AudioPlaybackError.missingFile
        }
        let player = try AVAudioPlayer(contentsOf: fileURL)
        player.enableRate = true
        player.prepareToPlay()
        self.player = player
        activeRecordingID = recording.id
    }

    enum AudioPlaybackError: LocalizedError {
        case missingFile

        var errorDescription: String? {
            switch self {
            case .missingFile:
                return "找不到这段录音的本地文件。"
            }
        }
    }
}

private extension Color {
    static let smartGroupedBackground = Color(uiColor: .systemGroupedBackground)
    static let smartCanvasBackground = Color(red: 0.91, green: 0.92, blue: 0.94)
}

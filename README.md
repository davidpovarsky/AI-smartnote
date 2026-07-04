# SmartNotes

## English

SmartNotes is an iPad-only SwiftUI note-taking workspace inspired by document-first apps such as Goodnotes and Notability. It focuses on local-first notebooks, PDF annotation, page management, handwriting tools, audio notes, study cards, and multi-note workflows.

### Features

- Three-column iPad document workspace with library, notebook browser, and editor panes.
- Notebook library with folders for documents, favorites, classes, work, imports, shared items, and trash.
- Grid and list browsing, search across notebook metadata and page content, and favorite/shared filtering.
- Document creation presets for notebooks, PDFs, scans, whiteboards, text documents, and Quicknotes.
- Paper templates including blank, ruled, grid, dotted, Cornell, planner, and music pages.
- Writing surface powered by PencilKit with tools for pen, pencil, highlighter, eraser, lasso, shapes, text, tape, ruler, laser, zoom, images, audio, and conversion actions.
- Page management for adding, duplicating, deleting, rotating, selecting, reordering, bookmarking, outlining, and exporting pages.
- Multi-note mode with primary and secondary panes, horizontal or vertical layouts, and page/object transfer between panes.
- Import support for PDFs, images, and audio files, with imported assets stored beside the local library data.
- Audio recording and playback metadata, synchronized page markers, playback rate, and voice boost settings.
- Study set and sharing model support for future AI, sync, and collaboration features.
- PDF export for full notebooks or selected/current pages.

### Architecture

The app is intentionally small in file count and local-first in behavior:

- `SmartNotesApp.swift` launches directly into `ContentView`.
- `ContentView.swift` contains the SwiftUI shell, library UI, editor workspace, panels, canvas integration, and audio controllers.
- `Note.swift` contains the notebook data model, supporting enums, persistence, import/export logic, sample data, and the observable `NotebookLibrary` state container.
- `SmartNotesTests.swift` uses the Swift Testing framework for model, persistence, import/export, page management, audio, object editing, and multi-note behavior.
- `SmartNotesUITests.swift` uses XCTest UI automation to verify the iPad launch experience and key editor workflows.

Notebook data is encoded as JSON through `NotebookLibrary`. Imported files, recordings, and exports are stored in sibling directories next to the library storage file.

### Requirements

- Xcode with SwiftUI, Swift Testing, XCTest, PencilKit, PDFKit, AVFoundation, and UIKit support.
- An iPadOS run destination. The app target is configured as iPad-only.

### Running

1. Open the project in Xcode.
2. Select the `SmartNotes` scheme.
3. Choose an iPad simulator or device.
4. Build and run with `Cmd+R`.

### Testing

Run the test suite from Xcode with `Cmd+U`, or run the available unit and UI test targets from the Test navigator.

The UI tests set `SMARTNOTES_UI_TEST=1` so the app launches with deterministic in-memory sample data instead of loading or autosaving user data.

### Project Notes

- The app currently keeps most implementation in two large Swift files. That makes the prototype easy to inspect, but future work should consider extracting focused modules for the library, editor canvas, import/export services, audio, and test fixtures.
- `PlatformDesignGeneration` keeps iPadOS 26 and 27 design branching explicit while preserving compatibility with the current codebase.
- Network sync and real AI execution are not implemented yet, but the notebook model includes fields for collaborators, study sets, transcripts, and exported documents so those features can be attached later.

## 中文

SmartNotes 是一款仅面向 iPad 的 SwiftUI 笔记工作区，灵感来自 Goodnotes 和 Notability 这类以文档为中心的应用。它重点支持本地优先的笔记本、PDF 批注、页面管理、手写工具、录音笔记、学习卡片和多笔记工作流。

### 功能

- 三栏式 iPad 文档工作区，包含资料库、笔记本浏览器和编辑器。
- 笔记本资料库支持文稿、收藏、课堂、工作、导入、共享和废纸篓等分类。
- 支持网格和列表浏览，可搜索笔记本元数据和页面内容，并支持收藏与共享筛选。
- 支持创建笔记本、PDF、扫描件、白板、文本文件和 Quicknote。
- 支持空白、横线、方格、点阵、康奈尔、计划和五线谱等纸张模板。
- 基于 PencilKit 的书写区域，提供钢笔、铅笔、荧光笔、橡皮、套索、形状、文字、遮挡、直尺、激光笔、缩放、图片、录音和转换等工具。
- 页面管理支持新增、复制、删除、旋转、选择、重排、书签、大纲和导出。
- 多笔记模式支持主副窗格、横向或纵向布局，以及页面和对象在窗格之间移动或复制。
- 支持导入 PDF、图片和音频文件，导入资源会存储在本地资料库数据旁边。
- 支持录音与播放元数据、页面同步标记、播放速度和语音增强设置。
- 数据模型已预留学习集、共享、协作者和转录摘要能力，便于后续接入 AI、同步和协作功能。
- 支持导出整个笔记本、当前页面或所选页面为 PDF。

### 架构

这个项目目前刻意保持较少的文件数量，并采用本地优先的设计：

- `SmartNotesApp.swift` 直接启动到 `ContentView`。
- `ContentView.swift` 包含 SwiftUI 外壳、资料库界面、编辑工作区、侧边面板、画布集成和音频控制器。
- `Note.swift` 包含笔记本数据模型、相关枚举、持久化、导入导出逻辑、示例数据，以及可观察的 `NotebookLibrary` 状态容器。
- `SmartNotesTests.swift` 使用 Swift Testing 框架测试模型、持久化、导入导出、页面管理、音频、对象编辑和多笔记行为。
- `SmartNotesUITests.swift` 使用 XCTest UI 自动化验证 iPad 启动体验和关键编辑器流程。

笔记本数据通过 `NotebookLibrary` 编码为 JSON。导入文件、录音和导出文件会保存在资料库存储文件旁边的同级目录中。

### 环境要求

- 支持 SwiftUI、Swift Testing、XCTest、PencilKit、PDFKit、AVFoundation 和 UIKit 的 Xcode。
- iPadOS 运行目标。当前 App target 配置为仅支持 iPad。

### 运行

1. 在 Xcode 中打开项目。
2. 选择 `SmartNotes` scheme。
3. 选择 iPad 模拟器或真机。
4. 使用 `Cmd+R` 构建并运行。

### 测试

可以在 Xcode 中使用 `Cmd+U` 运行测试，也可以在 Test navigator 中运行单元测试和 UI 测试 target。

UI 测试会设置 `SMARTNOTES_UI_TEST=1`，使应用使用确定性的内存示例数据启动，而不是加载或自动保存用户数据。

### 项目说明

- 目前大部分实现集中在两个较大的 Swift 文件中。这便于原型阶段快速查看，但后续可以考虑拆分出资料库、编辑画布、导入导出服务、音频和测试夹具等更聚焦的模块。
- `PlatformDesignGeneration` 显式保留了 iPadOS 26 和 27 的设计分支，同时保持当前代码库的兼容性。
- 网络同步和真实 AI 执行尚未实现，但笔记本模型已经包含协作者、学习集、转录摘要和导出文档等字段，后续可以在此基础上接入相关能力。

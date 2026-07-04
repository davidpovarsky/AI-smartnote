import CoreGraphics
import PDFKit
import SwiftUI
import Testing
import UIKit
@testable import SmartNotes

struct SmartNotesTests {
    private func temporaryLibraryURL(_ name: String = UUID().uuidString) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartNotesTests-\(name)", isDirectory: true)
            .appendingPathComponent("Library.json")
    }

    private func temporaryImportURL(_ fileName: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SmartNotesTests-Imports", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(fileName)
    }

    private func makePDF(at url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 320, height: 420))
        try renderer.writePDF(to: url) { context in
            context.beginPage()
            "Alpha calculus limits".draw(
                at: CGPoint(x: 32, y: 48),
                withAttributes: [.font: UIFont.systemFont(ofSize: 18)]
            )
            context.beginPage()
            "Beta theorem review".draw(
                at: CGPoint(x: 32, y: 48),
                withAttributes: [.font: UIFont.systemFont(ofSize: 18)]
            )
        }
    }

    @MainActor
    @Test func platformGenerationTracksIPadOS26And27DesignBranches() {
        #expect(PlatformDesignGeneration.preferred(majorOSVersion: 25) == .classic)
        #expect(PlatformDesignGeneration.preferred(majorOSVersion: 26) == .liquidGlass26)
        #expect(PlatformDesignGeneration.preferred(majorOSVersion: 27) == .refinedGlass27)
    }

    @MainActor
    @Test func libraryFiltersFoldersFavoritesAndSharedWorkspaces() {
        let library = NotebookLibrary()

        library.selectedFolder = .favorites
        #expect(library.visibleNotebooks.allSatisfy { $0.isFavorite })

        library.selectedFolder = .work
        #expect(library.visibleNotebooks.map(\.subject) == ["工作"])

        library.selectedFolder = .shared
        #expect(library.visibleNotebooks.allSatisfy { $0.isShared })
    }

    @MainActor
    @Test func creatingNotebookSelectsItAndStartsWithOneWritablePage() throws {
        let library = NotebookLibrary(notebooks: [])

        library.createNotebook()
        let notebook = try #require(library.selectedNotebook)
        let page = try #require(library.selectedPage)

        #expect(library.notebooks.count == 1)
        #expect(notebook.title == "未命名笔记本")
        #expect(notebook.pages.count == 1)
        #expect(page.template == .ruled)
    }

    @MainActor
    @Test func creatingDocumentsFromPresetsUsesExpectedKindsAndTemplates() throws {
        let library = NotebookLibrary(notebooks: [])

        library.createDocument(.whiteboard)
        #expect(library.selectedNotebook?.kind == .whiteboard)
        #expect(library.selectedPage?.template == .dotted)

        library.createDocument(.notebook, template: .music)
        #expect(library.selectedNotebook?.kind == .notebook)
        #expect(library.selectedPage?.template == .music)

        library.createDocument(.textDocument)
        #expect(library.selectedNotebook?.kind == .textDocument)
        #expect(library.selectedPage?.elements.first?.kind == .textBox)

        library.createDocument(.scan)
        let scan = try #require(library.selectedNotebook)
        #expect(scan.kind == .pdf)
        #expect(scan.folder == .imports)
        #expect(scan.pages.first?.assets.first?.kind == .scan)
    }

    @MainActor
    @Test func addingPageUsesSelectedNotebookAndMovesSelection() throws {
        let library = NotebookLibrary()
        let originalCount = try #require(library.selectedNotebook?.pages.count)

        library.addPage(template: .grid)
        let notebook = try #require(library.selectedNotebook)
        let page = try #require(library.selectedPage)

        #expect(notebook.pages.count == originalCount + 1)
        #expect(page.template == .grid)
    }

    @MainActor
    @Test func pageManagementChangesTemplatesDuplicatesAndDeletesPages() throws {
        let library = NotebookLibrary(notebooks: [])

        library.createNotebook()
        let firstPageID = try #require(library.selectedPage?.id)
        library.changeCurrentPageTemplate(to: .grid)
        library.addElement(kind: .shape, title: "流程图")
        library.duplicateCurrentPage()

        let duplicatedPage = try #require(library.selectedPage)
        #expect(library.selectedNotebook?.pages.count == 2)
        #expect(duplicatedPage.id != firstPageID)
        #expect(duplicatedPage.title == "第一页 副本")
        #expect(duplicatedPage.template == .grid)
        #expect(duplicatedPage.elements.contains { $0.title == "流程图" })

        library.deleteCurrentPage()
        #expect(library.selectedNotebook?.pages.count == 1)
        #expect(library.selectedPage?.id == firstPageID)

        library.deleteCurrentPage()
        #expect(library.selectedNotebook?.pages.count == 1)
    }

    @MainActor
    @Test func pageOrganizerReordersCurrentPageAndSelectedGroups() throws {
        let library = NotebookLibrary(notebooks: [])

        library.createNotebook()
        let firstID = try #require(library.selectedPage?.id)
        library.addPage(template: .grid)
        let secondID = try #require(library.selectedPage?.id)
        library.addPage(template: .dotted)
        let thirdID = try #require(library.selectedPage?.id)

        library.selectedPageID = firstID
        library.moveCurrentPageDown()
        #expect(library.selectedNotebook?.pages.map(\.id) == [secondID, firstID, thirdID])

        library.setPageSelectionMode(true)
        library.togglePageSelection(thirdID)
        library.moveSelectedPagesUp()
        #expect(library.selectedNotebook?.pages.map(\.id) == [firstID, thirdID, secondID])
        #expect(library.selectedPageIDs == [firstID, thirdID])

        library.movePageOrSelectedPagesToEnd(draggedPageID: thirdID)
        #expect(library.selectedNotebook?.pages.map(\.id) == [secondID, firstID, thirdID])
        #expect(library.selectedPageIDs == [firstID, thirdID])

        library.movePageOrSelectedPages(draggedPageID: firstID, before: secondID)
        #expect(library.selectedNotebook?.pages.map(\.id) == [firstID, thirdID, secondID])
    }

    @MainActor
    @Test func pageOrganizerSupportsBulkDuplicateClearAndDelete() throws {
        let library = NotebookLibrary(notebooks: [])

        library.createNotebook()
        library.addPage(template: .grid)
        library.addPage(template: .dotted)
        let pages = try #require(library.selectedNotebook?.pages)
        let firstID = pages[0].id
        let secondID = pages[1].id

        library.selectedPageID = firstID
        library.addElement(kind: .shape, title: "待清空图形")
        #expect(library.selectedPage?.elements.isEmpty == false)

        library.setPageSelectionMode(true)
        library.clearSelectedPagesContent()
        #expect(library.selectedNotebook?.pages.first?.elements.isEmpty == true)

        library.selectedPageIDs = [firstID, secondID]
        library.duplicateSelectedPages()
        #expect(library.selectedNotebook?.pages.count == 5)
        #expect(library.selectedPageCount == 2)

        library.deleteSelectedPages()
        #expect(library.selectedNotebook?.pages.count == 3)

        library.selectAllPages()
        library.deleteSelectedPages()
        #expect(library.selectedNotebook?.pages.count == 3)
    }

    @MainActor
    @Test func pageOrganizerRotatesCurrentAndSelectedPages() throws {
        let library = NotebookLibrary(notebooks: [])

        library.createNotebook()
        let firstID = try #require(library.selectedPage?.id)
        library.addPage(template: .grid)
        let secondID = try #require(library.selectedPage?.id)
        library.addPage(template: .dotted)
        let thirdID = try #require(library.selectedPage?.id)

        library.rotateCurrentOrSelectedPagesClockwise()
        #expect(library.selectedPage?.id == thirdID)
        #expect(library.selectedPage?.rotationDegrees == 90)

        library.selectedPageID = firstID
        library.setPageSelectionMode(true)
        library.togglePageSelection(secondID)
        library.rotateCurrentOrSelectedPagesCounterclockwise()

        let pages = try #require(library.selectedNotebook?.pages)
        #expect(pages.first { $0.id == firstID }?.rotationDegrees == 270)
        #expect(pages.first { $0.id == secondID }?.rotationDegrees == 270)
        #expect(pages.first { $0.id == thirdID }?.rotationDegrees == 90)
    }

    @MainActor
    @Test func pageManagerFiltersBookmarksAnnotationsAndOutlines() throws {
        let library = NotebookLibrary(notebooks: [])

        library.createNotebook()
        let outlinedID = try #require(library.selectedPage?.id)
        library.toggleCurrentPageOutline()

        library.addPage(template: .grid)
        let annotatedID = try #require(library.selectedPage?.id)
        library.addElement(kind: .shape, title: "批注对象")

        library.addPage(template: .dotted)
        let bookmarkedID = try #require(library.selectedPage?.id)
        library.toggleCurrentPageBookmark()

        let pages = try #require(library.selectedNotebook?.pages)
        #expect(pages.filter { PageManagerFilter.outline.includes($0) }.map(\.id) == [outlinedID])
        #expect(pages.filter { PageManagerFilter.annotated.includes($0) }.map(\.id) == [annotatedID])
        #expect(pages.filter { PageManagerFilter.bookmarks.includes($0) }.map(\.id) == [bookmarkedID])

        library.selectPages(Set(pages.filter { PageManagerFilter.annotated.includes($0) }.map(\.id)))
        #expect(library.selectedPageIDs == [annotatedID])
        #expect(library.selectedPage?.id == annotatedID)

        library.toggleCurrentPageOutline()
        #expect(library.selectedPage?.outlineTitle == "第 2 页")
    }

    @MainActor
    @Test func multiNoteWorkspaceOpensSecondaryNotebookAndRoutesEditsToActivePane() throws {
        let library = NotebookLibrary()
        let primaryID = try #require(library.primaryNotebook?.id)
        let primaryPageCount = try #require(library.primaryNotebook?.pages.count)

        library.openNextNotebookInMultiNote(layout: .horizontal)

        let secondaryID = try #require(library.secondaryNotebook?.id)
        let secondaryPageCount = try #require(library.secondaryNotebook?.pages.count)
        #expect(library.isMultiNoteEnabled)
        #expect(library.activePane == .secondary)
        #expect(library.selectedNotebook?.id == secondaryID)
        #expect(secondaryID != primaryID)

        library.addPage(template: .grid)
        #expect(library.secondaryNotebook?.pages.count == secondaryPageCount + 1)
        #expect(library.primaryNotebook?.pages.count == primaryPageCount)
        #expect(library.selectedPage?.template == .grid)

        library.setMultiNoteLayout(.vertical)
        #expect(library.multiNoteLayout == .vertical)

        library.activatePane(.primary)
        #expect(library.selectedNotebook?.id == primaryID)
        #expect(library.selectedPage?.id == library.primaryPage?.id)

        library.closeMultiNote()
        #expect(library.isMultiNoteEnabled == false)
        #expect(library.secondaryNotebook == nil)
        #expect(library.activePane == .primary)
    }

    @MainActor
    @Test func multiNoteTransfersPagesAndObjectsBetweenPanes() throws {
        let library = NotebookLibrary()

        library.openNextNotebookInMultiNote(layout: .horizontal)
        let originalPrimaryCount = try #require(library.primaryNotebook?.pages.count)
        let originalSecondaryCount = try #require(library.secondaryNotebook?.pages.count)

        library.activatePane(.primary)
        let copiedSourcePageID = try #require(library.selectedPage?.id)
        library.copyPagesToOtherPane()

        #expect(library.activePane == .secondary)
        #expect(library.primaryNotebook?.pages.count == originalPrimaryCount)
        #expect(library.secondaryNotebook?.pages.count == originalSecondaryCount + 1)
        #expect(library.selectedPage?.id != copiedSourcePageID)
        #expect(library.selectedPage?.title.hasSuffix("副本") == true)

        library.activatePane(.primary)
        library.movePagesToOtherPane()

        #expect(library.activePane == .secondary)
        #expect(library.primaryNotebook?.pages.count == originalPrimaryCount - 1)
        #expect(library.secondaryNotebook?.pages.count == originalSecondaryCount + 2)

        library.activatePane(.primary)
        library.addElement(kind: .sticker, title: "跨窗格贴纸")
        let originalElementID = try #require(library.selectedElement?.id)
        let primaryElementCount = try #require(library.selectedPage?.elements.count)
        let secondaryElementCount = try #require(library.secondaryPage?.elements.count)

        library.copySelectedElementToOtherPane()

        #expect(library.activePane == .secondary)
        #expect(library.selectedElement?.title == "跨窗格贴纸 副本")
        #expect(library.secondaryPage?.elements.count == secondaryElementCount + 1)

        library.activatePane(.primary)
        library.selectElement(id: originalElementID)
        library.moveSelectedElementToOtherPane()

        #expect(library.activePane == .secondary)
        #expect(library.primaryPage?.elements.count == primaryElementCount - 1)
        #expect(library.secondaryPage?.elements.contains { $0.title == "跨窗格贴纸" } == true)
    }

    @MainActor
    @Test func importScanAudioStudyAndShareWorkflowsMutateCurrentDocument() throws {
        let library = NotebookLibrary(notebooks: [])

        library.importDocumentStub(kind: .scan)
        let imported = try #require(library.selectedNotebook)
        let importedPage = try #require(library.selectedPage)

        #expect(imported.kind == .pdf)
        #expect(imported.folder == .imports)
        #expect(importedPage.assets.first?.kind == .scan)

        library.toggleAudioRecording()
        #expect(library.isRecordingAudio)
        library.finishAudioRecording()
        #expect(library.selectedNotebook?.recordings.count == 1)
        #expect(library.selectedPage?.audioMarkers.count == 1)

        library.createStudySetFromCurrentPage()
        #expect(library.selectedNotebook?.studySets.count == 1)
        #expect(library.selectedNotebook?.studySets.first?.cards.count == 2)

        library.shareCurrentNotebook()
        #expect(library.selectedNotebook?.isShared == true)
        #expect(library.selectedNotebook?.collaborators.isEmpty == false)
    }

    @MainActor
    @Test func audioRecordingStoresFileMetadataMarkersAndPersists() throws {
        let storageURL = temporaryLibraryURL()
        let library = NotebookLibrary(notebooks: [], autosaves: true, storageURL: storageURL)

        library.createNotebook()
        let destination = try library.createRecordingDestination()
        try Data([1, 3, 5, 7, 9]).write(to: destination.url)
        library.beginAudioRecording(storedFileName: destination.storedFileName)
        library.finishAudioRecording(
            storedFileName: destination.storedFileName,
            duration: 125,
            byteCount: 5,
            transcript: "老师讲到傅里叶级数。"
        )

        let recording = try #require(library.selectedNotebook?.recordings.first)
        let page = try #require(library.selectedPage)
        #expect(recording.storedFileName == destination.storedFileName)
        #expect(recording.duration == 125)
        #expect(recording.byteCount == 5)
        #expect(recording.detailText.contains("2:05"))
        #expect(page.audioMarkers.first?.recordingID == recording.id)
        #expect(library.fileURL(for: recording).map { FileManager.default.fileExists(atPath: $0.path) } == true)

        let restored = NotebookLibrary(notebooks: [], loadsFromDisk: true, storageURL: storageURL)
        #expect(restored.selectedNotebook?.recordings.first?.storedFileName == destination.storedFileName)
    }

    @MainActor
    @Test func audioPlaybackControlsSeekAcrossSynchronizedPageMarkers() throws {
        let library = NotebookLibrary(notebooks: [])

        library.createNotebook()
        let firstPageID = try #require(library.selectedPage?.id)
        library.addPage(template: .grid)
        let secondPageID = try #require(library.selectedPage?.id)
        library.selectedPageID = firstPageID
        library.finishAudioRecording(duration: 120, transcript: "同步回放测试")
        let recording = try #require(library.selectedNotebook?.recordings.first)
        let recordingID = recording.id
        let notebookIndex = try #require(library.notebooks.firstIndex(where: { $0.id == library.selectedNotebookID }))
        let secondPageIndex = try #require(library.notebooks[notebookIndex].pages.firstIndex(where: { $0.id == secondPageID }))
        library.notebooks[notebookIndex].pages[secondPageIndex].audioMarkers.append(
            AudioMarker(id: UUID(), recordingID: recordingID, timestamp: 45, title: "第二页重点")
        )

        library.toggleAudioPlayback(for: recording)
        #expect(library.isPlayingAudio)

        library.seekAudio(to: 50)
        #expect(library.audioPlaybackPosition == 50)
        #expect(library.selectedPageID == secondPageID)

        library.skipAudio(by: -10)
        #expect(library.audioPlaybackPosition == 40)
        #expect(library.selectedPageID == firstPageID)

        library.setAudioPlaybackRate(1.5, for: recordingID)
        library.setVoiceBoostLevel(0.75, for: recordingID)
        let updatedRecording = try #require(library.selectedNotebook?.recordings.first)
        #expect(updatedRecording.playbackRate == 1.5)
        #expect(updatedRecording.voiceBoostLevel == 0.75)
    }

    @MainActor
    @Test func externalAudioImportCreatesRecordingOnCurrentNotebook() throws {
        let audioURL = temporaryImportURL("lecture.m4a")
        try FileManager.default.createDirectory(at: audioURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([0, 1, 2, 3, 4, 5]).write(to: audioURL)
        let library = NotebookLibrary(notebooks: [])

        library.createNotebook()
        let notebookID = try #require(library.selectedNotebook?.id)
        try library.importExternalFile(at: audioURL)

        let notebook = try #require(library.selectedNotebook)
        let recording = try #require(notebook.recordings.first)
        #expect(notebook.id == notebookID)
        #expect(recording.title.hasSuffix("lecture"))
        #expect(recording.storedFileName?.hasSuffix("lecture.m4a") == true)
        #expect(recording.byteCount == 6)
        #expect(library.selectedSidePanel == .audio)
    }

    @MainActor
    @Test func externalPDFImportCreatesPagedSearchableNotebookAndPersistsAssets() throws {
        let storageURL = temporaryLibraryURL()
        let pdfURL = temporaryImportURL("Lecture Pack.pdf")
        try makePDF(at: pdfURL)
        let library = NotebookLibrary(notebooks: [], autosaves: true, storageURL: storageURL)

        try library.importExternalFile(at: pdfURL)

        let notebook = try #require(library.selectedNotebook)
        let firstAsset = try #require(notebook.pages.first?.assets.first)
        let firstPage = try #require(notebook.pages.first)
        #expect(notebook.kind == .pdf)
        #expect(notebook.folder == .imports)
        #expect(notebook.title == "Lecture Pack")
        #expect(notebook.pages.count == 2)
        #expect(firstAsset.kind == .pdf)
        #expect(firstAsset.pageCount == 2)
        #expect(firstAsset.sourcePageIndex == 0)
        #expect(firstAsset.storedFileName?.hasSuffix("Lecture-Pack.pdf") == true)
        #expect((firstAsset.byteCount ?? 0) > 0)
        #expect(library.pdfBackgroundAsset(for: firstPage)?.id == firstAsset.id)
        #expect(library.fileURL(for: firstAsset).map { FileManager.default.fileExists(atPath: $0.path) } == true)

        library.searchText = "Lecture Pack"
        #expect(library.visibleNotebooks.map(\.id).contains(notebook.id))

        let restored = NotebookLibrary(notebooks: [], loadsFromDisk: true, storageURL: storageURL)
        #expect(restored.selectedNotebook?.pages.first?.assets.first?.storedFileName == firstAsset.storedFileName)
    }

    @MainActor
    @Test func exportingImportedPDFCreatesShareablePDFAndExportHistory() throws {
        let storageURL = temporaryLibraryURL()
        let pdfURL = temporaryImportURL("Worksheet.pdf")
        try makePDF(at: pdfURL)
        let library = NotebookLibrary(notebooks: [], autosaves: true, storageURL: storageURL)

        try library.importExternalFile(at: pdfURL)
        let exported = try library.exportCurrentNotebookToPDF()
        let exportURL = library.fileURL(for: exported)
        let exportedPDF = try #require(PDFDocument(url: exportURL))

        #expect(FileManager.default.fileExists(atPath: exportURL.path))
        #expect(exportedPDF.pageCount == 2)
        #expect(exported.pageCount == 2)
        #expect(exported.byteCount > 0)
        #expect(library.selectedNotebook?.exportedDocuments.first?.id == exported.id)

        let restored = NotebookLibrary(notebooks: [], loadsFromDisk: true, storageURL: storageURL)
        #expect(restored.selectedNotebook?.exportedDocuments.first?.storedFileName == exported.storedFileName)
    }

    @MainActor
    @Test func exportingCurrentOrSelectedPagesCreatesPageScopedPDF() throws {
        let storageURL = temporaryLibraryURL()
        let library = NotebookLibrary(notebooks: [], autosaves: true, storageURL: storageURL)

        library.createNotebook(title: "页面管理测试")
        let firstID = try #require(library.selectedPage?.id)
        library.addPage(template: .grid)
        let secondID = try #require(library.selectedPage?.id)
        library.addPage(template: .dotted)

        library.selectedPageID = firstID
        library.setPageSelectionMode(true)
        library.togglePageSelection(secondID)

        let exported = try library.exportCurrentOrSelectedPagesToPDF()
        let exportedPDF = try #require(PDFDocument(url: library.fileURL(for: exported)))

        #expect(exportedPDF.pageCount == 2)
        #expect(exported.pageCount == 2)
        #expect(exported.title == "页面管理测试-所选 2 页.pdf")
        #expect(library.selectedNotebook?.exportedDocuments.first?.id == exported.id)
    }

    @MainActor
    @Test func externalImageImportAddsLayeredAssetToCurrentPage() throws {
        let imageURL = temporaryImportURL("diagram.png")
        try FileManager.default.createDirectory(at: imageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data([137, 80, 78, 71, 13, 10, 26, 10]).write(to: imageURL)
        let library = NotebookLibrary(notebooks: [])

        library.createNotebook()
        let notebookID = try #require(library.selectedNotebook?.id)
        try library.importExternalFile(at: imageURL)

        let notebook = try #require(library.selectedNotebook)
        let page = try #require(library.selectedPage)
        let asset = try #require(page.assets.first)

        #expect(notebook.id == notebookID)
        #expect(asset.kind == .image)
        #expect(asset.title == "diagram.png")
        #expect(asset.storedFileName?.hasSuffix("diagram.png") == true)
        #expect(page.elements.contains { $0.kind == .image && $0.title == "diagram" })
        #expect(library.selectedSidePanel == .content)
    }

    @MainActor
    @Test func legacyPageElementsDecodeWithEditableGeometryDefaults() throws {
        let json = """
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "kind": "形状",
          "title": "旧图形",
          "detail": "来自旧版本的列表对象。",
          "color": "green"
        }
        """.data(using: .utf8)!

        let element = try JSONDecoder().decode(PageElement.self, from: json)

        #expect(element.frame == .defaultFrame)
        #expect(element.rotationDegrees == 0)
        #expect(element.scale == 1)
        #expect(element.isLocked == false)
    }

    @MainActor
    @Test func legacyNotebookPagesDecodeWithRotationDefault() throws {
        let json = """
        {
          "id": "22222222-2222-2222-2222-222222222222",
          "title": "旧页面",
          "template": "横线",
          "previewLines": ["旧版本没有页面旋转字段"]
        }
        """.data(using: .utf8)!

        let page = try JSONDecoder().decode(NotebookPage.self, from: json)

        #expect(page.rotationDegrees == 0)
        #expect(page.normalizedRotationDegrees == 0)
        #expect(page.outlineTitle == nil)
        #expect(page.hasUserAnnotations == false)
    }

    @MainActor
    @Test func lassoObjectEditingMovesTransformsCopiesPastesAndDeletesElements() throws {
        let library = NotebookLibrary(notebooks: [])

        library.createNotebook()
        library.addElement(kind: .shape, title: "流程图")
        let original = try #require(library.selectedElement)
        let originalID = original.id

        library.moveSelectedElementBy(x: 24, y: -12)
        var selected = try #require(library.selectedElement)
        #expect(selected.frame.x == original.frame.x + 24)
        #expect(selected.frame.y == original.frame.y - 12)

        library.scaleSelectedElement(by: 1.5)
        library.rotateSelectedElement(by: 45)
        selected = try #require(library.selectedElement)
        #expect(abs(selected.scale - 1.5) < 0.001)
        #expect(selected.rotationDegrees == 45)

        library.duplicateSelectedElement()
        let duplicate = try #require(library.selectedElement)
        #expect(duplicate.id != originalID)
        #expect(duplicate.title == "流程图 副本")
        #expect(library.selectedPage?.elements.count == 2)

        library.deleteSelectedElement()
        #expect(library.selectedPage?.elements.count == 1)
        library.selectElement(id: originalID)

        library.copySelectedElement()
        #expect(library.hasCopiedElement)
        library.pasteCopiedElement()
        let pasted = try #require(library.selectedElement)
        #expect(pasted.id != originalID)
        #expect(pasted.title == "流程图 粘贴")
        #expect(library.selectedPage?.elements.count == 2)

        library.toggleSelectedElementLock()
        let lockedX = try #require(library.selectedElement?.frame.x)
        library.moveSelectedElementBy(x: 100, y: 0)
        library.deleteSelectedElement()
        #expect(library.selectedElement?.frame.x == lockedX)
        #expect(library.selectedPage?.elements.count == 2)

        library.toggleSelectedElementLock()
        library.cutSelectedElement()
        #expect(library.selectedPage?.elements.count == 1)
        #expect(library.selectedElement == nil)

        library.pasteCopiedElement()
        #expect(library.selectedPage?.elements.count == 2)
        library.deleteSelectedElement()
        #expect(library.selectedPage?.elements.count == 1)
    }

    @MainActor
    @Test func insertingAndConvertingPageElementsTracksContentPanelState() throws {
        let library = NotebookLibrary()

        library.addElement(kind: .tape)
        library.convertSelectionToMath()

        let page = try #require(library.selectedPage)
        #expect(page.elements.map(\.kind).contains(.tape))
        #expect(page.elements.map(\.kind).contains(.math))
        #expect(library.selectedElement?.kind == .math)
        #expect(library.selectedSidePanel == .content)
    }

    @MainActor
    @Test func localPersistenceRestoresLibraryDocumentsAndFeatureState() throws {
        let url = temporaryLibraryURL()
        let library = NotebookLibrary(notebooks: [], autosaves: true, storageURL: url)

        library.createWhiteboard()
        library.addElement(kind: .shape, title: "流程图")
        library.toggleCurrentPageBookmark()
        library.toggleAudioRecording()
        library.finishAudioRecording()
        library.createStudySetFromCurrentPage()
        library.shareCurrentNotebook()
        try library.saveNow()

        let restored = NotebookLibrary(notebooks: [], loadsFromDisk: true, storageURL: url)
        let notebook = try #require(restored.selectedNotebook)
        let page = try #require(restored.selectedPage)

        #expect(notebook.kind == .whiteboard)
        #expect(notebook.isShared)
        #expect(notebook.recordings.count == 1)
        #expect(notebook.studySets.count == 1)
        #expect(page.isBookmarked)
        #expect(page.elements.contains { $0.title == "流程图" })
    }

    @MainActor
    @Test func drawingDataIsStoredOnTheSelectedPageAndAutosaved() throws {
        let url = temporaryLibraryURL()
        let library = NotebookLibrary(notebooks: [], autosaves: true, storageURL: url)

        library.createNotebook()
        let pageID = try #require(library.selectedPage?.id)
        let drawingData = Data([0, 1, 2, 3, 5, 8])

        library.updateDrawingData(drawingData, for: pageID)

        #expect(library.selectedPage?.drawingData == drawingData)

        let restored = NotebookLibrary(notebooks: [], loadsFromDisk: true, storageURL: url)
        #expect(restored.selectedPage?.drawingData == drawingData)
    }
}

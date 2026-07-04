import UIKit
import XCTest

final class SmartNotesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchEnvironment["SMARTNOTES_UI_TEST"] = "1"
    }

    @MainActor
    func testIPadLaunchesIntoDocumentLibraryAndEditor() throws {
        app.launch()

        XCTAssertEqual(UIDevice.current.userInterfaceIdiom, .pad)
        XCTAssertTrue(element(id: "ipad-notes-shell").waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["SmartNotes"].exists)
        XCTAssertTrue(element(id: "note-editor-regular-workbench").exists)
    }

    @MainActor
    func testNewNotebookAppearsFromSidebarCreateButton() throws {
        app.launch()
        XCTAssertTrue(element(id: "create-notebook-button").waitForExistence(timeout: 8))

        app.buttons["create-notebook-button"].tap()

        XCTAssertTrue(app.staticTexts["未命名笔记本"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(id: "note-editor-regular-workbench").exists)
    }

    @MainActor
    func testQuickWhiteboardActionCreatesWhiteboardDocument() throws {
        app.launch()
        XCTAssertTrue(element(id: "library-quick-whiteboard").waitForExistence(timeout: 8))

        app.buttons["library-quick-whiteboard"].tap()

        XCTAssertTrue(app.staticTexts["无限白板"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(id: "note-editor-regular-workbench").exists)
    }

    @MainActor
    func testPagePanelCanDuplicateTheCurrentPage() throws {
        app.launch()
        XCTAssertTrue(element(id: "duplicate-current-page-button").waitForExistence(timeout: 8))

        app.buttons["duplicate-current-page-button"].tap()

        XCTAssertTrue(app.staticTexts["极限与连续 副本"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testPagePanelSelectionModeCanSelectAllPages() throws {
        app.launch()
        XCTAssertTrue(element(id: "page-selection-toggle-button").waitForExistence(timeout: 8))

        app.buttons["page-selection-toggle-button"].tap()
        XCTAssertTrue(app.staticTexts["已选择 1 页"].waitForExistence(timeout: 5))

        app.buttons["select-all-pages-button"].tap()
        XCTAssertTrue(app.staticTexts["已选择 2 页"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(id: "rotate-pages-right-button").exists)
        app.buttons["rotate-pages-right-button"].tap()
    }

    @MainActor
    func testPageManagerCanAddCurrentPageToOutline() throws {
        app.launch()
        XCTAssertTrue(element(id: "page-manager-filter-outline-button").waitForExistence(timeout: 8))

        app.buttons["page-manager-filter-outline-button"].tap()
        XCTAssertTrue(element(id: "toggle-current-page-outline-button").waitForExistence(timeout: 5))

        app.buttons["toggle-current-page-outline-button"].tap()
        XCTAssertTrue(element(id: "outline-manager-section").exists)
        XCTAssertTrue(element(id: "outline-current-page-row").waitForExistence(timeout: 5))
    }

    @MainActor
    func testPagePanelCanExportCurrentPageAsPDF() throws {
        app.launch()
        XCTAssertTrue(element(id: "document-export-pdf-button").waitForExistence(timeout: 8))

        app.buttons["document-export-pdf-button"].tap()

        XCTAssertTrue(app.staticTexts["微积分课堂笔记-极限与连续.pdf"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testAudioPanelShowsPlaybackControlsForExistingRecording() throws {
        app.launch()
        XCTAssertTrue(element(id: "open-audio-panel-button").waitForExistence(timeout: 8))

        app.buttons["open-audio-panel-button"].tap()

        XCTAssertTrue(element(id: "audio-playback-controls").waitForExistence(timeout: 5))
    }

    @MainActor
    func testContentPanelObjectMenuCanMoveSelectedObject() throws {
        app.launch()
        XCTAssertTrue(element(id: "open-content-panel-button").waitForExistence(timeout: 8))

        app.buttons["open-content-panel-button"].tap()
        XCTAssertTrue(element(id: "content-panel-first-element-button").waitForExistence(timeout: 5))

        app.buttons["content-panel-first-element-button"].tap()
        XCTAssertTrue(element(id: "object-inspector").waitForExistence(timeout: 5))

        app.buttons["move-selected-object-right-button"].tap()
        XCTAssertTrue(element(id: "selected-object-summary").exists)
    }

    @MainActor
    func testMultiNoteWorkspaceCanOpenSecondaryPane() throws {
        app.launch()
        XCTAssertTrue(element(id: "open-multinote-right-button").waitForExistence(timeout: 8))

        app.buttons["open-multinote-right-button"].tap()
        XCTAssertTrue(element(id: "workspace-secondary-pane").waitForExistence(timeout: 5))
        XCTAssertTrue(element(id: "workspace-secondary-tab").exists)
        XCTAssertTrue(element(id: "copy-pages-to-other-pane-button").exists)
    }

    private func element(id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }
}

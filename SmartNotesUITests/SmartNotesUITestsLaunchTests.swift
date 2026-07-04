import XCTest

final class SmartNotesUITestsLaunchTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "SmartNotes iPad Library Launch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

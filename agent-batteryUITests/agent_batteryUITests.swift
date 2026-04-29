import XCTest

final class AgentBatteryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchesMenuBarApp() throws {
        let app = XCUIApplication()
        app.launch()

        let isRunning = app.wait(for: .runningForeground, timeout: 3)
            || app.wait(for: .runningBackground, timeout: 1)
        XCTAssertTrue(isRunning)
    }
}

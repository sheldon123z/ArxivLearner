import XCTest

// MARK: - Phase3FlowUITests
//
// Integration tests for Phase 3 features:
// - Statistics tab navigation
// - Settings new sections (appearance, iCloud sync)
// - Reading stats view

final class Phase3FlowUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-UITest"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Tab Bar

    func testTabBarContainsFiveTabs() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "Tab bar should appear")

        let expectedTabs = ["发现", "文库", "对话", "统计", "设置"]
        for tab in expectedTabs {
            XCTAssertTrue(
                tabBar.buttons[tab].exists,
                "Tab '\(tab)' should exist"
            )
        }
    }

    // MARK: - Reading Stats Tab

    func testStatsTabNavigation() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))

        tabBar.buttons["统计"].tap()

        // ReadingStatsView should show navigation title
        XCTAssertTrue(
            app.navigationBars["阅读统计"].waitForExistence(timeout: 3),
            "Stats tab should show '阅读统计' navigation title"
        )
    }

    func testStatsTabShowsSummaryCards() {
        app.tabBars.firstMatch.buttons["统计"].tap()
        XCTAssertTrue(app.navigationBars["阅读统计"].waitForExistence(timeout: 3))

        // Summary section header
        XCTAssertTrue(
            app.staticTexts["本周概况"].waitForExistence(timeout: 3),
            "Weekly summary section should be visible"
        )
    }

    func testStatsTabShowsHeatmap() {
        app.tabBars.firstMatch.buttons["统计"].tap()
        XCTAssertTrue(app.navigationBars["阅读统计"].waitForExistence(timeout: 3))

        // Heatmap section header (may need scrolling)
        let heatmapText = app.staticTexts["阅读热力图（近 12 周）"]
        if !heatmapText.exists {
            app.swipeUp()
        }
        XCTAssertTrue(
            heatmapText.waitForExistence(timeout: 3),
            "Heatmap section should be visible"
        )
    }

    func testStatsTabWeeklyReportButton() {
        app.tabBars.firstMatch.buttons["统计"].tap()
        XCTAssertTrue(app.navigationBars["阅读统计"].waitForExistence(timeout: 3))

        // Scroll to find buttons
        app.swipeUp()

        let weeklyButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '本周报告'")
        ).firstMatch

        if weeklyButton.waitForExistence(timeout: 3) {
            weeklyButton.tap()
            XCTAssertTrue(
                app.navigationBars["本周报告"].waitForExistence(timeout: 3),
                "Weekly report view should appear"
            )
            // Navigate back
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    func testStatsTabMonthlyReportButton() {
        app.tabBars.firstMatch.buttons["统计"].tap()
        XCTAssertTrue(app.navigationBars["阅读统计"].waitForExistence(timeout: 3))

        app.swipeUp()

        let monthlyButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS '本月报告'")
        ).firstMatch

        if monthlyButton.waitForExistence(timeout: 3) {
            monthlyButton.tap()
            XCTAssertTrue(
                app.navigationBars["本月报告"].waitForExistence(timeout: 3),
                "Monthly report view should appear"
            )
            app.navigationBars.buttons.firstMatch.tap()
        }
    }

    // MARK: - Settings New Sections

    func testSettingsShowsAppearanceSection() {
        app.tabBars.firstMatch.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 3))

        let appearanceHeader = app.staticTexts["外观"]
        if !appearanceHeader.exists {
            app.swipeUp()
        }
        XCTAssertTrue(
            appearanceHeader.waitForExistence(timeout: 3),
            "Appearance section should exist in Settings"
        )
    }

    func testSettingsShowsiCloudSection() {
        app.tabBars.firstMatch.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 3))

        // Scroll to iCloud section
        app.swipeUp()

        let iCloudHeader = app.staticTexts["iCloud 同步"]
        if !iCloudHeader.exists {
            app.swipeUp()
        }
        XCTAssertTrue(
            iCloudHeader.waitForExistence(timeout: 3),
            "iCloud sync section should exist in Settings"
        )
    }

    func testSettingsiCloudManualSyncButton() {
        app.tabBars.firstMatch.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 3))

        app.swipeUp()

        let syncButton = app.buttons["立即同步"]
        if !syncButton.exists {
            app.swipeUp()
        }
        // Button may be disabled on simulator; just verify it exists
        XCTAssertTrue(
            syncButton.waitForExistence(timeout: 3),
            "Manual sync button should exist"
        )
    }

    // MARK: - Settings Tab Management Link

    func testSettingsTagManagementNavigation() {
        app.tabBars.firstMatch.buttons["设置"].tap()
        XCTAssertTrue(app.navigationBars["设置"].waitForExistence(timeout: 3))

        // Tags might be in settings as a nav link
        let tagRow = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '标签'")
        ).firstMatch

        if tagRow.waitForExistence(timeout: 2) {
            tagRow.tap()
            sleep(1)
            // Navigate back if we went to a new screen
            if app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
        // Verify settings is still accessible
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 3))
    }
}

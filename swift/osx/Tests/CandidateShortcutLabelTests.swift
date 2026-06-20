import XCTest
@testable import KhiinPJH

final class CandidateShortcutLabelTests: XCTestCase {
    func testPageLocalIndexesUseOneBasedShortcutLabels() {
        let labels = (0...8).map { candidateShortcutLabel(for: $0) }

        XCTAssertEqual(labels, ["1.", "2.", "3.", "4.", "5.", "6.", "7.", "8.", "9."])
    }
}

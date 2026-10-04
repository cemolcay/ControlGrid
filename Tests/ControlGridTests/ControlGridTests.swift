import XCTest
import UIKit
@testable import ControlGrid

final class ControlGridTests: XCTestCase {
    func testFractionUsesTheCompleteAvailableAxis() {
        let fixed = UIView()
        let flexible = UIView()
        let fractional = UIView()
        let grid = makeGrid(size: CGSize(width: 320, height: 400), rowSpacing: 10)

        grid.setRows([
            row(fixed, height: .fixed(40)),
            row(flexible, height: .flexible(min: nil, max: nil)),
            row(fractional, height: .fraction(0.25)),
        ])
        grid.layoutIfNeeded()

        XCTAssertEqual(fixed.superview!.frame.height, 40, accuracy: 0.001)
        XCTAssertEqual(fractional.superview!.frame.height, 100, accuracy: 0.001)
        XCTAssertEqual(flexible.superview!.frame.height, 240, accuracy: 0.001)
    }

    func testWeightedCellsShareRemainingWidthProportionally() {
        let lane = UIView()
        let scene = UIView()
        let controls = UIView()
        let grid = makeGrid(size: CGSize(width: 332, height: 100), cellSpacing: 8)

        grid.setRows([
            ControlGridRow(cells: [
                ControlGridCell(view: lane, spec: CellSpec(width: .fixed(46))),
                ControlGridCell(view: scene, spec: CellSpec(width: .weighted(1.7))),
                ControlGridCell(view: controls, spec: CellSpec(width: .weighted(1))),
            ])
        ])
        grid.layoutIfNeeded()

        XCTAssertEqual(lane.superview!.frame.width, 46, accuracy: 0.001)
        XCTAssertEqual(scene.superview!.frame.width, 170, accuracy: 0.001)
        XCTAssertEqual(controls.superview!.frame.width, 100, accuracy: 0.001)
    }

    func testWeightedMaximumRedistributesRemainingSpace() {
        let first = UIView()
        let second = UIView()
        let grid = makeGrid(size: CGSize(width: 400, height: 100), cellSpacing: 16)

        grid.setRows([
            ControlGridRow(cells: [
                ControlGridCell(
                    view: first,
                    spec: CellSpec(width: .weighted(3, max: 100))),
                ControlGridCell(view: second, spec: CellSpec(width: .weighted(1))),
            ])
        ])
        grid.layoutIfNeeded()

        XCTAssertEqual(first.superview!.frame.width, 100, accuracy: 0.001)
        XCTAssertEqual(second.superview!.frame.width, 284, accuracy: 0.001)
    }

    /// Clamping one row to its maximum must not push a later row down to its minimum: every share
    /// in a pass comes from the same space and weight.
    func testWeightedMaximumsDoNotForceOtherRowsToTheirMinimums() {
        let button = UIView()
        let knobs = UIView()
        let wide = UIView()
        let common = UIView()
        let grid = makeGrid(size: CGSize(width: 320, height: 290), rowSpacing: 8)

        grid.setRows([
            row(button, height: .fixed(40)),
            row(knobs, height: .weighted(2, min: 56, max: 88)),
            row(wide, height: .weighted(1, min: 28)),
            row(common, height: .weighted(2, min: 56, max: 88)),
        ])
        grid.layoutIfNeeded()

        XCTAssertEqual(knobs.superview!.frame.height, 88, accuracy: 0.001)
        XCTAssertEqual(common.superview!.frame.height, 88, accuracy: 0.001)
        XCTAssertEqual(wide.superview!.frame.height, 50, accuracy: 0.001)
    }

    func testWeightedMinimumTakesSpaceFromTheOthers() {
        let first = UIView()
        let second = UIView()
        let third = UIView()
        let grid = makeGrid(size: CGSize(width: 300, height: 100))

        grid.setRows([
            ControlGridRow(cells: [
                ControlGridCell(view: first, spec: CellSpec(width: .weighted(1, min: 150))),
                ControlGridCell(view: second, spec: CellSpec(width: .weighted(1))),
                ControlGridCell(view: third, spec: CellSpec(width: .weighted(1))),
            ])
        ])
        grid.layoutIfNeeded()

        XCTAssertEqual(first.superview!.frame.width, 150, accuracy: 0.001)
        XCTAssertEqual(second.superview!.frame.width, 75, accuracy: 0.001)
        XCTAssertEqual(third.superview!.frame.width, 75, accuracy: 0.001)
    }

    func testLegacyFlexibleCellsStillReceiveEqualShares() {
        let first = UIView()
        let second = UIView()
        let grid = makeGrid(size: CGSize(width: 210, height: 100), cellSpacing: 10)

        grid.setRows([
            ControlGridRow(cells: [
                ControlGridCell(view: first),
                ControlGridCell(view: second),
            ])
        ])
        grid.layoutIfNeeded()

        XCTAssertEqual(first.superview!.frame.width, 100, accuracy: 0.001)
        XCTAssertEqual(second.superview!.frame.width, 100, accuracy: 0.001)
    }

    func testSetRowsRetainsContainerForAnUnchangedView() {
        let view = UIView()
        let grid = makeGrid(size: CGSize(width: 200, height: 200))
        grid.setRows([row(view, height: .fixed(40))])
        grid.layoutIfNeeded()
        let originalContainer = view.superview

        grid.setRows([row(view, height: .fraction(0.5))])
        grid.layoutIfNeeded()

        XCTAssertTrue(view.superview === originalContainer)
        XCTAssertEqual(view.superview!.frame.height, 100, accuracy: 0.001)
    }

    func testHiddenRowCollapsesWithoutRemovingItsContainerOrLeavingSpacing() {
        let content = UIView()
        let keyboard = UIView()
        let grid = makeGrid(size: CGSize(width: 200, height: 300), rowSpacing: 10)
        grid.setRows([
            row(content, height: .flexible(min: nil, max: nil)),
            ControlGridRow(
                cells: [ControlGridCell(view: keyboard)],
                spec: RowSpec(height: .fraction(0.25)),
                isHidden: true),
        ])
        grid.layoutIfNeeded()
        let keyboardContainer = keyboard.superview

        XCTAssertEqual(content.superview!.frame.height, 300, accuracy: 0.001)
        XCTAssertEqual(keyboardContainer!.frame.minY, 300, accuracy: 0.001)
        XCTAssertEqual(keyboardContainer!.frame.height, 0, accuracy: 0.001)
        XCTAssertTrue(keyboardContainer!.isHidden)

        grid.setRows([
            row(content, height: .flexible(min: nil, max: nil)),
            ControlGridRow(
                cells: [ControlGridCell(view: keyboard)],
                spec: RowSpec(height: .fraction(0.25))),
        ])
        grid.layoutIfNeeded()

        XCTAssertTrue(keyboard.superview === keyboardContainer)
        XCTAssertEqual(content.superview!.frame.height, 215, accuracy: 0.001)
        XCTAssertEqual(keyboardContainer!.frame.minY, 225, accuracy: 0.001)
        XCTAssertEqual(keyboardContainer!.frame.height, 75, accuracy: 0.001)
        XCTAssertFalse(keyboardContainer!.isHidden)
    }

    func testHiddenCellCollapsesWithoutRemovingItsContainerOrLeavingSpacing() {
        let first = UIView()
        let alternate = UIView()
        let last = UIView()
        let grid = makeGrid(size: CGSize(width: 210, height: 100), cellSpacing: 10)
        grid.setRows([
            ControlGridRow(cells: [
                ControlGridCell(view: first),
                ControlGridCell(view: alternate, isHidden: true),
                ControlGridCell(view: last),
            ])
        ])
        grid.layoutIfNeeded()
        let alternateContainer = alternate.superview

        XCTAssertEqual(first.superview!.frame.width, 100, accuracy: 0.001)
        XCTAssertEqual(alternateContainer!.frame.width, 0, accuracy: 0.001)
        XCTAssertEqual(last.superview!.frame.width, 100, accuracy: 0.001)
        XCTAssertTrue(alternateContainer!.isHidden)

        XCTAssertTrue(grid.setCellHidden(false, containing: alternate))
        XCTAssertTrue(grid.setCellHidden(true, containing: first))
        XCTAssertFalse(grid.setCellHidden(true, containing: UIView()))
        grid.layoutIfNeeded()

        XCTAssertTrue(alternate.superview === alternateContainer)
        XCTAssertEqual(alternateContainer!.frame.width, 100, accuracy: 0.001)
        XCTAssertEqual(last.superview!.frame.width, 100, accuracy: 0.001)
        XCTAssertFalse(alternateContainer!.isHidden)
        XCTAssertEqual(grid.contentViews, [first, alternate, last])
    }

    func testHorizontalMinimumsCompressToViewport() {
        let first = UIView()
        let second = UIView()
        let grid = makeGrid(size: CGSize(width: 150, height: 80), cellSpacing: 10)
        grid.setRows([ControlGridRow(cells: [
            ControlGridCell(view: first, spec: CellSpec(width: .weighted(1, min: 100))),
            ControlGridCell(view: second, spec: CellSpec(width: .weighted(1, min: 100))),
        ])])
        grid.layoutIfNeeded()

        XCTAssertEqual(first.superview!.frame.width, 75, accuracy: 0.001)
        XCTAssertEqual(second.superview!.frame.width, 75, accuracy: 0.001)
        XCTAssertEqual(second.superview!.frame.maxX, 150, accuracy: 0.001)
        XCTAssertFalse(grid.isScrollEnabled)
    }

    func testSpacingCannotPushCellsBeyondNarrowViewport() {
        let cells = (0..<3).map { _ in UIView() }
        let grid = makeGrid(size: CGSize(width: 10, height: 80), cellSpacing: 8)
        grid.setRows([ControlGridRow(cells: cells.map { ControlGridCell(view: $0) })])
        grid.layoutIfNeeded()

        XCTAssertEqual(cells.last!.superview!.frame.maxX, 10, accuracy: 0.001)
    }

    func testFittingRowScrollsWhenItsContentCannotFit() {
        let fixed = UIView()
        let content = FittingView(size: CGSize(width: 40, height: 80))
        let grid = makeGrid(size: CGSize(width: 200, height: 100), rowSpacing: 10)
        grid.setRows([
            row(fixed, height: .fixed(40)),
            row(content, height: .fitting()),
        ])
        grid.layoutIfNeeded()

        XCTAssertEqual(content.superview!.frame.height, 80, accuracy: 0.001)
        XCTAssertEqual(grid.contentSize.height, 130, accuracy: 0.001)
        XCTAssertTrue(grid.isScrollEnabled)
    }

    func testFittingRowUsesAutoLayoutSizeWhenSizeThatFitsIsEmpty() {
        let content = UIView()
        content.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let grid = makeGrid(size: CGSize(width: 200, height: 100))
        grid.setRows([row(content, height: .fitting())])
        grid.layoutIfNeeded()

        XCTAssertEqual(content.superview!.frame.height, 64, accuracy: 0.001)
    }

    func testFittingRowTracksChangedAutoLayoutHeight() {
        let content = UIView()
        let height = content.heightAnchor.constraint(equalToConstant: 64)
        height.isActive = true
        let grid = makeGrid(size: CGSize(width: 200, height: 200))
        grid.setRows([row(content, height: .fitting())])
        grid.layoutIfNeeded()

        height.constant = 80
        grid.setNeedsLayout()
        grid.layoutIfNeeded()

        XCTAssertEqual(content.superview!.frame.height, 80, accuracy: 0.001)
    }

    func testFittingParentCanMeasureNestedGrid() {
        let child = makeGrid(size: .zero)
        child.setRows([row(UIView(), height: .fixed(70))])
        let parent = makeGrid(size: CGSize(width: 200, height: 100))
        parent.setRows([row(child, height: .fitting())])
        parent.layoutIfNeeded()

        XCTAssertEqual(child.superview!.frame.height, 70, accuracy: 0.001)
    }

    func testFittingCellUsesContentWidthAndInsets() {
        let content = FittingView(size: CGSize(width: 46, height: 20))
        let grid = makeGrid(size: CGSize(width: 200, height: 60))
        grid.setRows([ControlGridRow(cells: [
            ControlGridCell(view: content, spec: CellSpec(
                width: .fitting(),
                insets: UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4))),
        ], spec: RowSpec(horizontalAlignment: .trailing))])
        grid.layoutIfNeeded()

        XCTAssertEqual(content.superview!.frame.width, 54, accuracy: 0.001)
        XCTAssertEqual(content.superview!.frame.minX, 146, accuracy: 0.001)
    }

    func testMutableSpacingAndInsetsUpdateExistingCells() {
        let first = UIView()
        let second = UIView()
        let grid = makeGrid(size: CGSize(width: 200, height: 100), cellSpacing: 0)
        grid.setRows([ControlGridRow(cells: [.init(view: first), .init(view: second)])])
        grid.layoutIfNeeded()
        XCTAssertEqual(second.superview!.frame.minX, 100, accuracy: 0.001)

        grid.defaultCellSpacing = 20
        grid.defaultCellInsets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        grid.layoutIfNeeded()
        first.superview!.layoutIfNeeded()

        XCTAssertEqual(second.superview!.frame.minX, 110, accuracy: 0.001)
        XCTAssertEqual(first.frame.minX, 5, accuracy: 0.001)
    }

    func testMutableRowSpacingAndContentAlignmentRelayout() {
        let first = UIView()
        let second = UIView()
        let grid = makeGrid(size: CGSize(width: 100, height: 200))
        grid.setRows([row(first, height: .fixed(40)), row(second, height: .fixed(40))])
        grid.layoutIfNeeded()

        grid.rowSpacing = 20
        grid.contentAlignment = .bottom
        grid.layoutIfNeeded()

        XCTAssertEqual(first.superview!.frame.minY, 100, accuracy: 0.001)
        XCTAssertEqual(second.superview!.frame.minY, 160, accuracy: 0.001)
    }

    func testLeadingFollowsRightToLeftDirection() {
        let content = UIView()
        let grid = makeGrid(size: CGSize(width: 200, height: 80))
        grid.semanticContentAttribute = .forceRightToLeft
        grid.setRows([ControlGridRow(cells: [
            ControlGridCell(view: content, spec: CellSpec(width: .fixed(40))),
        ], spec: RowSpec(horizontalAlignment: .leading))])
        grid.layoutIfNeeded()

        XCTAssertEqual(content.superview!.frame.minX, 160, accuracy: 0.001)
    }

    func testRemovingAllRowsResetsScrolling() {
        let grid = makeGrid(size: CGSize(width: 100, height: 100))
        grid.setRows([row(UIView(), height: .fixed(200))])
        grid.layoutIfNeeded()
        XCTAssertTrue(grid.isScrollEnabled)

        grid.setRows([])
        grid.layoutIfNeeded()
        XCTAssertFalse(grid.isScrollEnabled)
        XCTAssertFalse(grid.alwaysBounceVertical)
        XCTAssertEqual(grid.contentSize, .zero)
    }

    private final class FittingView: UIView {
        let fittingSize: CGSize
        init(size: CGSize) {
            fittingSize = size
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { nil }
        override func sizeThatFits(_ size: CGSize) -> CGSize { fittingSize }
    }

    private func makeGrid(
        size: CGSize,
        rowSpacing: CGFloat = 0,
        cellSpacing: CGFloat = 0
    ) -> ControlGrid {
        let grid = ControlGrid(rowSpacing: rowSpacing, defaultCellSpacing: cellSpacing)
        grid.frame = CGRect(origin: .zero, size: size)
        return grid
    }

    private func row(_ view: UIView, height: GridDimension) -> ControlGridRow {
        ControlGridRow(
            cells: [ControlGridCell(view: view)],
            spec: RowSpec(height: height))
    }
}

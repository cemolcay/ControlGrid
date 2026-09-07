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

        grid.setCellHidden(false, atRow: 0, column: 1)
        grid.setCellHidden(true, atRow: 0, column: 0)
        grid.layoutIfNeeded()

        XCTAssertTrue(alternate.superview === alternateContainer)
        XCTAssertEqual(alternateContainer!.frame.width, 100, accuracy: 0.001)
        XCTAssertEqual(last.superview!.frame.width, 100, accuracy: 0.001)
        XCTAssertFalse(alternateContainer!.isHidden)
        XCTAssertEqual(grid.contentViews, [first, alternate, last])
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

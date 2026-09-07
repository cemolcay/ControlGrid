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

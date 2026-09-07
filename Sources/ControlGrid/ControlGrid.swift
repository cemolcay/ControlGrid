/*
 ControlGrid
 ===========

 A generic 2D grid layout component built on UIScrollView with fully manual
 frame layout. Rows and cells are configured declaratively via specs, giving
 you symmetric, composable control over both axes.

 QUICK START — 4-column equally-fitted grid:

     let grid = ControlGrid()
     grid.setRows([
         ControlGridRow(cells: [a, b, c, d].map { ControlGridCell(view: $0) }),
         ControlGridRow(cells: [e, f, g, h].map { ControlGridCell(view: $0) }),
     ])

 MIXED ROW HEIGHTS — first row fixed, rest flexible:

     let grid = ControlGrid(
         defaultRowSpec: RowSpec(height: .flexible(min: 40, max: 80)),
         contentAlignment: .center
     )
     grid.setRows([
         ControlGridRow(
             cells: [header].map { ControlGridCell(view: $0) },
             spec: RowSpec(height: .fixed(44))
         ),
         ControlGridRow(cells: [a, b, c, d].map { ControlGridCell(view: $0) }),
     ])

 FIXED-WIDTH CELLS WITH SPACERS — two 60pt buttons with a flexible gap between them:

     ControlGridRow(cells: [
         ControlGridCell(view: leftBtn, spec: CellSpec(width: .fixed(60))),
         ControlGridCell(view: nil),                                          // spacer
         ControlGridCell(view: rightBtn, spec: CellSpec(width: .fixed(60))),
     ])

 CENTERING PATTERN — center a 200pt item using spacer cells:

     ControlGridRow(cells: [
         ControlGridCell(view: nil),
         ControlGridCell(view: title, spec: CellSpec(width: .fixed(200))),
         ControlGridCell(view: nil),
     ])

 OVERFLOW BEHAVIOR:
 - Vertical (rows):    If total row heights exceed grid height, the grid scrolls.
                       Rows always keep their declared/minimum heights.
 - Horizontal (cells): Fixed cells shrink proportionally when their total
                       exceeds row width — no horizontal scrolling, no clipping.
                       e.g. two .fixed(100) cells in 150pt → each gets 75pt.

 WEIGHTED + FRACTIONAL SIZING — fixed selector, 1.7:1 content split, 22.5% keyboard:

     ControlGridRow(cells: [
         ControlGridCell(view: selector, spec: CellSpec(width: .fixed(46))),
         ControlGridCell(view: scene, spec: CellSpec(width: .weighted(1.7))),
         ControlGridCell(view: controls, spec: CellSpec(width: .weighted(1))),
     ])

     ControlGridRow(
         cells: [ControlGridCell(view: keyboard)],
         spec: RowSpec(height: .fraction(0.225)))
 */

import UIKit

// MARK: - GridDimension

/// Describes how a row's height or a cell's width is sized during layout.
///
/// Both the vertical (row height) and horizontal (cell width) axes use this
/// same type, giving the grid symmetric configuration on both dimensions.
public enum GridDimension {
    /// An exact size in points. Proportionally shrinks when total fixed sizes
    /// exceed available space (horizontal axis only; vertical scrolls instead).
    case fixed(CGFloat)

    /// A flexible size that shares available space with other flexible items
    /// after fixed items are allocated. Clamped to `[min, max]` when provided.
    ///
    /// - `min: nil` means no minimum (can shrink to 0).
    /// - `max: nil` means no maximum (takes as much space as available share).
    /// - `.flexible(min: nil, max: nil)` means "equal share, no constraints".
    case flexible(min: CGFloat?, max: CGFloat?)

    /// A flexible size that receives a weighted share of the space remaining after fixed and
    /// fractional items are allocated. A regular `flexible` item has an implicit weight of 1.
    /// Non-positive weights receive no unconstrained share, though `min` is still respected.
    case weighted(CGFloat, min: CGFloat? = nil, max: CGFloat? = nil)

    /// A size expressed as a fraction of the grid's complete available axis before spacing is
    /// removed. For example, `.fraction(0.25)` is one quarter of the grid's height for a row or
    /// width for a cell. Negative fractions are treated as zero.
    case fraction(CGFloat)
}

// MARK: - ContentAlignment

/// How rows are positioned vertically when total content height is less than
/// the grid's bounds height (i.e., no scrolling needed).
public enum ContentAlignment {
    /// Rows pinned to the top edge.
    case top
    /// Rows centered vertically.
    case center
    /// Rows pinned to the bottom edge.
    case bottom
}

// MARK: - HorizontalAlignment

/// How cells are positioned horizontally within a row when total cell width
/// is less than the row width.
public enum HorizontalAlignment {
    /// Cells pinned to the leading edge.
    case leading
    /// Cells centered horizontally.
    case center
    /// Cells pinned to the trailing edge.
    case trailing
}

// MARK: - CellSpec

/// Per-cell layout configuration. All properties are optional; `nil` falls
/// through to the row-level spec, then the grid-level defaults.
public struct CellSpec {
    /// Width dimension for this cell. Nil uses `RowSpec.defaultCellWidth`.
    public var width: GridDimension?
    /// Insets applied between the cell container boundary and content view.
    /// Nil uses `RowSpec.cellInsets` → `ControlGrid.defaultCellInsets`.
    public var insets: UIEdgeInsets?

    public init(width: GridDimension? = nil, insets: UIEdgeInsets? = nil) {
        self.width = width
        self.insets = insets
    }
}

// MARK: - RowSpec

/// Per-row layout configuration. All optional properties fall through to
/// `ControlGrid`'s grid-level defaults when nil.
public struct RowSpec {
    /// Height dimension for this row.
    public var height: GridDimension
    /// How cells are aligned horizontally when their total width < row width.
    public var horizontalAlignment: HorizontalAlignment
    /// Default cell width used for cells whose `CellSpec.width` is nil.
    public var defaultCellWidth: GridDimension
    /// Horizontal spacing between cells. Nil uses `ControlGrid.defaultCellSpacing`.
    public var cellSpacing: CGFloat?
    /// Default cell insets for cells in this row whose `CellSpec.insets` is nil.
    /// Nil falls through to `ControlGrid.defaultCellInsets`.
    public var cellInsets: UIEdgeInsets?

    public init(
        height: GridDimension = .flexible(min: nil, max: nil),
        horizontalAlignment: HorizontalAlignment = .center,
        defaultCellWidth: GridDimension = .flexible(min: nil, max: nil),
        cellSpacing: CGFloat? = nil,
        cellInsets: UIEdgeInsets? = nil
    ) {
        self.height = height
        self.horizontalAlignment = horizontalAlignment
        self.defaultCellWidth = defaultCellWidth
        self.cellSpacing = cellSpacing
        self.cellInsets = cellInsets
    }
}

// MARK: - ControlGridCell

/// A single cell in a `ControlGridRow`.
public struct ControlGridCell {
    /// The content view for this cell. Pass `nil` to create a spacer cell
    /// that takes up space but renders nothing.
    public var view: UIView?
    /// Per-cell layout overrides. Nil uses the parent row/grid defaults.
    public var spec: CellSpec?
    /// When true, the cell consumes no width or adjacent cell spacing, while its container stays
    /// attached so showing it again can animate from its collapsed position.
    public var isHidden: Bool

    public init(view: UIView? = nil, spec: CellSpec? = nil, isHidden: Bool = false) {
        self.view = view
        self.spec = spec
        self.isHidden = isHidden
    }
}

// MARK: - ControlGridRow

/// A single row in a `ControlGrid`.
public struct ControlGridRow {
    /// The cells to display in this row. Cell count implicitly defines the
    /// column count for this row (each row can have a different number of cells).
    public var cells: [ControlGridCell]
    /// Row-level layout overrides. Nil uses the grid's `defaultRowSpec`.
    public var spec: RowSpec?
    /// When true, the row consumes no height or adjacent row spacing, while its cell containers
    /// remain attached so showing it again can animate from its collapsed position.
    public var isHidden: Bool

    public init(cells: [ControlGridCell], spec: RowSpec? = nil, isHidden: Bool = false) {
        self.cells = cells
        self.spec = spec
        self.isHidden = isHidden
    }
}

// MARK: - CellContainer

/// A private container view that wraps a content view and pins it via
/// Auto Layout. The container itself is positioned by manual frame layout.
private class CellContainer: UIView {
    private(set) var contentView: UIView?
    private var contentConstraints: [NSLayoutConstraint] = []

    /// Replaces the current content view with `view`, pinned inside the
    /// container using the given `insets`.
    func setContent(_ view: UIView?, insets: UIEdgeInsets) {
        if contentView === view {
            guard contentConstraints.count == 4 else { return }
            contentConstraints[0].constant = insets.left
            contentConstraints[1].constant = -insets.right
            contentConstraints[2].constant = insets.top
            contentConstraints[3].constant = -insets.bottom
            return
        }

        contentView?.removeFromSuperview()
        NSLayoutConstraint.deactivate(contentConstraints)
        contentView = view
        contentConstraints = []
        guard let view else { return }
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        contentConstraints = [
            view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: insets.left),
            view.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -insets.right),
            view.topAnchor.constraint(equalTo: topAnchor, constant: insets.top),
            view.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -insets.bottom),
        ]
        NSLayoutConstraint.activate(contentConstraints)
    }
}

// MARK: - ControlGrid

/// A 2D grid layout component backed by `UIScrollView`.
///
/// Rows are laid out vertically; cells within each row are laid out horizontally.
/// Both axes use `GridDimension` for fixed or flexible sizing with optional
/// min/max clamping and proportional overflow handling.
///
/// Row positioning (vertical) is controlled by `ContentAlignment`.
/// Cell positioning within a row (horizontal) is controlled by `HorizontalAlignment`.
///
/// The grid scrolls vertically when total content height exceeds bounds.
/// Horizontal overflow is handled by proportional shrinking of fixed cells.
public class ControlGrid: UIScrollView {

    // MARK: Configuration

    /// Grid-level fallback spec applied to any row whose `spec` is `nil`.
    public var defaultRowSpec: RowSpec

    /// Vertical spacing between rows in points.
    public var rowSpacing: CGFloat

    /// How rows are vertically positioned when total content height < bounds.
    public var contentAlignment: ContentAlignment

    /// Horizontal spacing between cells, used when `RowSpec.cellSpacing` is nil.
    public var defaultCellSpacing: CGFloat

    /// Cell insets used when neither `CellSpec.insets` nor `RowSpec.cellInsets`
    /// is set.
    public var defaultCellInsets: UIEdgeInsets

    // MARK: Private State

    private var rows: [ControlGridRow] = []
    private var cellContainers: [[CellContainer]] = []

    // MARK: Init

    /// Creates a ControlGrid with the given configuration defaults.
    ///
    /// - Parameters:
    ///   - defaultRowSpec: Row spec applied to rows that don't provide their own.
    ///   - rowSpacing: Vertical gap between rows.
    ///   - contentAlignment: Vertical positioning of rows when content fits.
    ///   - defaultCellSpacing: Horizontal gap between cells (row-level fallback).
    ///   - defaultCellInsets: Content insets within each cell (last fallback).
    public init(
        defaultRowSpec: RowSpec = RowSpec(),
        rowSpacing: CGFloat = 8,
        contentAlignment: ContentAlignment = .center,
        defaultCellSpacing: CGFloat = 8,
        defaultCellInsets: UIEdgeInsets = .zero
    ) {
        self.defaultRowSpec = defaultRowSpec
        self.rowSpacing = rowSpacing
        self.contentAlignment = contentAlignment
        self.defaultCellSpacing = defaultCellSpacing
        self.defaultCellInsets = defaultCellInsets
        super.init(frame: .zero)
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
    }

    public required init?(coder: NSCoder) {
        self.defaultRowSpec = RowSpec()
        self.rowSpacing = 8
        self.contentAlignment = .center
        self.defaultCellSpacing = 8
        self.defaultCellInsets = .zero
        super.init(coder: coder)
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
    }

    // MARK: Public API

    /// Replaces all current content with the given rows.
    ///
    /// Retains cell containers whose content-view identity is unchanged, removes obsolete
    /// containers, builds any new ones, then triggers a layout pass. Retaining containers keeps
    /// live controls and scenes attached while their row or cell dimensions change.
    ///
    /// - Parameter rows: The rows to display. Each row defines its own cells
    ///   and may override the grid's `defaultRowSpec`.
    public func setRows(_ rows: [ControlGridRow]) {
        var reusableContainers: [ObjectIdentifier: CellContainer] = [:]
        for container in cellContainers.flatMap({ $0 }) {
            if let view = container.contentView {
                reusableContainers[ObjectIdentifier(view)] = container
            }
        }
        var retainedContainers = Set<ObjectIdentifier>()
        var newContainers: [[CellContainer]] = []
        self.rows = rows

        for row in rows {
            let rowSpec = row.spec ?? defaultRowSpec
            var rowCells: [CellContainer] = []
            for cell in row.cells {
                let container = cell.view.flatMap {
                    reusableContainers[ObjectIdentifier($0)]
                } ?? CellContainer()
                let insets = cell.spec?.insets ?? rowSpec.cellInsets ?? defaultCellInsets
                container.setContent(cell.view, insets: insets)
                if container.superview == nil {
                    addSubview(container)
                }
                retainedContainers.insert(ObjectIdentifier(container))
                rowCells.append(container)
            }
            newContainers.append(rowCells)
        }
        cellContainers.flatMap { $0 }
            .filter { !retainedContainers.contains(ObjectIdentifier($0)) }
            .forEach { $0.removeFromSuperview() }
        cellContainers = newContainers
        setNeedsLayout()
    }

    /// Content views in row-major order. Hidden rows and cells remain present.
    public var contentViews: [UIView] {
        rows.flatMap(\.cells).compactMap(\.view)
    }

    /// Collapses or reveals one existing row without rebuilding its cell containers.
    public func setRowHidden(_ isHidden: Bool, at index: Int) {
        guard rows.indices.contains(index), rows[index].isHidden != isHidden else { return }
        rows[index].isHidden = isHidden
        setNeedsLayout()
    }

    /// Collapses or reveals one existing cell without rebuilding its container.
    public func setCellHidden(_ isHidden: Bool, atRow rowIndex: Int, column: Int) {
        guard rows.indices.contains(rowIndex),
              rows[rowIndex].cells.indices.contains(column),
              rows[rowIndex].cells[column].isHidden != isHidden else { return }
        rows[rowIndex].cells[column].isHidden = isHidden
        setNeedsLayout()
    }

    // MARK: Layout

    override public func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }
        guard !rows.isEmpty else {
            contentSize = .zero
            return
        }
        performLayout()
    }

    /// Computes and applies all row and cell frames.
    ///
    /// Two-pass layout:
    /// 1. **Vertical pass** — resolves each row's height using `distributeSizes`.
    ///    Determines whether vertical scrolling is needed.
    /// 2. **Horizontal pass** — for each row, resolves cell widths independently
    ///    using `distributeSizes`. Applies horizontal alignment offset.
    private func performLayout() {
        let availableWidth = bounds.width
        let availableHeight = bounds.height
        let rowCount = rows.count

        // --- Vertical pass ---
        let rowSpecs = rows.map { $0.spec ?? defaultRowSpec }
        let visibleRowIndices = rows.indices.filter { !rows[$0].isHidden }
        let visibleRowDimensions = visibleRowIndices.map { rowSpecs[$0].height }
        let (visibleRowHeights, needsScrolling) = distributeSizes(
            availableSpace: availableHeight,
            dimensions: visibleRowDimensions,
            spacing: rowSpacing,
            proportionalShrink: false
        )
        var rowHeights = [CGFloat](repeating: 0, count: rowCount)
        for (visibleIndex, rowIndex) in visibleRowIndices.enumerated() {
            rowHeights[rowIndex] = visibleRowHeights[visibleIndex]
        }

        let totalRowSpacing = CGFloat(max(0, visibleRowIndices.count - 1)) * rowSpacing
        let totalContentHeight = rowHeights.reduce(0, +) + totalRowSpacing

        isScrollEnabled = needsScrolling
        alwaysBounceVertical = needsScrolling
        contentSize = CGSize(width: availableWidth, height: max(totalContentHeight, availableHeight))

        var yOffset: CGFloat = 0
        if !needsScrolling {
            switch contentAlignment {
            case .top:    yOffset = 0
            case .center: yOffset = max(0, (availableHeight - totalContentHeight) / 2)
            case .bottom: yOffset = max(0, availableHeight - totalContentHeight)
            }
        }

        // --- Horizontal pass + frame assignment ---
        var currentY = yOffset
        for (rowIndex, row) in rows.enumerated() {
            let rowIsHidden = row.isHidden
            let rowSpec = row.spec ?? defaultRowSpec
            let rowH = rowHeights[rowIndex]
            let cellSpacing = rowSpec.cellSpacing ?? defaultCellSpacing
            let visibleCellIndices = row.cells.indices.filter { !row.cells[$0].isHidden }
            let visibleCellDimensions = visibleCellIndices.map { index -> GridDimension in
                let cell = row.cells[index]
                return cell.spec?.width ?? rowSpec.defaultCellWidth
            }

            let (visibleCellWidths, _) = distributeSizes(
                availableSpace: availableWidth,
                dimensions: visibleCellDimensions,
                spacing: cellSpacing,
                proportionalShrink: true
            )
            var cellWidths = [CGFloat](repeating: 0, count: row.cells.count)
            for (visibleIndex, cellIndex) in visibleCellIndices.enumerated() {
                cellWidths[cellIndex] = visibleCellWidths[visibleIndex]
            }

            let totalCellSpacing = CGFloat(max(0, visibleCellIndices.count - 1)) * cellSpacing
            let totalCellWidth = cellWidths.reduce(0, +) + totalCellSpacing

            var xOffset: CGFloat = 0
            if totalCellWidth < availableWidth {
                switch rowSpec.horizontalAlignment {
                case .leading:  xOffset = 0
                case .center:   xOffset = (availableWidth - totalCellWidth) / 2
                case .trailing: xOffset = availableWidth - totalCellWidth
                }
            }

            var currentX = xOffset
            for (colIndex, container) in (cellContainers[rowIndex]).enumerated() {
                let cellIsHidden = row.cells[colIndex].isHidden
                let w = cellWidths[colIndex]
                container.isHidden = rowIsHidden || cellIsHidden
                container.frame = CGRect(x: currentX, y: currentY, width: w, height: rowH)
                guard !cellIsHidden else { continue }
                currentX += w
                if colIndex != visibleCellIndices.last {
                    currentX += cellSpacing
                }
            }

            guard !rowIsHidden else { continue }
            currentY += rowH
            if rowIndex != visibleRowIndices.last {
                currentY += rowSpacing
            }
        }
    }

    /// Distributes `availableSpace` across items described by `dimensions`,
    /// separated by `spacing`.
    ///
    /// Fixed items take their declared size first. Remaining space is shared
    /// equally among flexible items, with iterative clamping to respect
    /// `min`/`max` bounds. Freed space from clamped items is redistributed
    /// to unclamped flexible items until stable.
    ///
    /// Overflow handling:
    /// - `proportionalShrink: false` (rows): sets `needsScrolling = true`
    ///   when fixed minimums exceed available space.
    /// - `proportionalShrink: true` (cells): shrinks all fixed items by the
    ///   same ratio so they fit without horizontal scrolling or clipping.
    ///
    /// - Parameters:
    ///   - availableSpace: Total space to distribute (height or width).
    ///   - dimensions: Array of `GridDimension` values, one per item.
    ///   - spacing: Gap between items.
    ///   - proportionalShrink: When `true`, fixed items shrink proportionally
    ///     on overflow rather than triggering scrolling.
    /// - Returns: Array of resolved sizes (same count as `dimensions`) and a
    ///   `needsScrolling` flag (always `false` when `proportionalShrink` is `true`).
    private func distributeSizes(
        availableSpace: CGFloat,
        dimensions: [GridDimension],
        spacing: CGFloat,
        proportionalShrink: Bool
    ) -> (sizes: [CGFloat], needsScrolling: Bool) {
        let count = dimensions.count
        guard count > 0 else { return ([], false) }

        let totalSpacing = CGFloat(max(0, count - 1)) * spacing
        let spaceForItems = availableSpace - totalSpacing

        var sizes = [CGFloat](repeating: 0, count: count)
        var fixedTotal: CGFloat = 0
        var flexibleIndices: [Int] = []
        var flexibleWeights = [CGFloat](repeating: 0, count: count)
        var flexibleMinimums = [CGFloat?](repeating: nil, count: count)
        var flexibleMaximums = [CGFloat?](repeating: nil, count: count)

        for (i, dim) in dimensions.enumerated() {
            switch dim {
            case .fixed(let h):
                sizes[i] = max(0, h)
                fixedTotal += sizes[i]
            case .fraction(let fraction):
                sizes[i] = availableSpace * max(0, fraction)
                fixedTotal += sizes[i]
            case .flexible(let min, let max):
                flexibleIndices.append(i)
                flexibleWeights[i] = 1
                flexibleMinimums[i] = min
                flexibleMaximums[i] = max
            case .weighted(let weight, let min, let max):
                flexibleIndices.append(i)
                flexibleWeights[i] = Swift.max(0, weight)
                flexibleMinimums[i] = min
                flexibleMaximums[i] = max
            }
        }

        // Handle proportional shrink for horizontal axis
        if proportionalShrink && fixedTotal > spaceForItems {
            let ratio = fixedTotal > 0 ? max(0, spaceForItems) / fixedTotal : 0
            for i in 0..<count {
                switch dimensions[i] {
                case .fixed, .fraction:
                    sizes[i] *= ratio
                case .flexible, .weighted:
                    break
                }
            }
            // Flexible items get 0 (no space left after fixed items shrunk to fill)
            return (sizes, false)
        }

        // Minimum check for vertical scrolling trigger
        var minTotal: CGFloat = fixedTotal
        for i in flexibleIndices {
            minTotal += max(0, flexibleMinimums[i] ?? 0)
        }

        if minTotal > spaceForItems {
            // Content doesn't fit even at minimum sizes
            var remaining = spaceForItems - fixedTotal
            for i in flexibleIndices {
                let allocated = max(0, flexibleMinimums[i] ?? 0)
                sizes[i] = allocated
                remaining -= allocated
            }
            return (sizes, !proportionalShrink)
        }

        guard !flexibleIndices.isEmpty else {
            return (sizes, fixedTotal > spaceForItems)
        }

        // Iterative clamping: distribute remaining space to flexible items
        var unclamped = Set(flexibleIndices)
        var spaceForFlexible = spaceForItems - fixedTotal
        var changed = true

        while changed {
            changed = false
            guard !unclamped.isEmpty else { break }
            let totalWeight = unclamped.reduce(CGFloat.zero) {
                $0 + flexibleWeights[$1]
            }

            for i in unclamped {
                let share = totalWeight > 0
                    ? spaceForFlexible * flexibleWeights[i] / totalWeight
                    : 0
                if let maxH = flexibleMaximums[i], share > maxH {
                    sizes[i] = max(0, maxH)
                    spaceForFlexible -= sizes[i]
                    unclamped.remove(i)
                    changed = true
                } else if let minH = flexibleMinimums[i], share < minH {
                    sizes[i] = max(0, minH)
                    spaceForFlexible -= sizes[i]
                    unclamped.remove(i)
                    changed = true
                }
            }
        }

        // Assign final weighted shares to unclamped flexible items.
        if !unclamped.isEmpty {
            let totalWeight = unclamped.reduce(CGFloat.zero) {
                $0 + flexibleWeights[$1]
            }
            for i in unclamped {
                sizes[i] = totalWeight > 0
                    ? max(0, spaceForFlexible * flexibleWeights[i] / totalWeight)
                    : 0
            }
        }

        return (sizes, false)
    }
}

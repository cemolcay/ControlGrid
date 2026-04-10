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
 */

import UIKit

// MARK: - GridDimension

/// Describes how a row's height or a cell's width is sized during layout.
///
/// Both the vertical (row height) and horizontal (cell width) axes use this
/// same type, giving the grid symmetric configuration on both dimensions.
enum GridDimension {
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
}

// MARK: - ContentAlignment

/// How rows are positioned vertically when total content height is less than
/// the grid's bounds height (i.e., no scrolling needed).
enum ContentAlignment {
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
enum HorizontalAlignment {
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
struct CellSpec {
    /// Width dimension for this cell. Nil uses `RowSpec.defaultCellWidth`.
    var width: GridDimension?
    /// Insets applied between the cell container boundary and content view.
    /// Nil uses `RowSpec.cellInsets` → `ControlGrid.defaultCellInsets`.
    var insets: UIEdgeInsets?

    init(width: GridDimension? = nil, insets: UIEdgeInsets? = nil) {
        self.width = width
        self.insets = insets
    }
}

// MARK: - RowSpec

/// Per-row layout configuration. All optional properties fall through to
/// `ControlGrid`'s grid-level defaults when nil.
struct RowSpec {
    /// Height dimension for this row.
    var height: GridDimension
    /// How cells are aligned horizontally when their total width < row width.
    var horizontalAlignment: HorizontalAlignment
    /// Default cell width used for cells whose `CellSpec.width` is nil.
    var defaultCellWidth: GridDimension
    /// Horizontal spacing between cells. Nil uses `ControlGrid.defaultCellSpacing`.
    var cellSpacing: CGFloat?
    /// Default cell insets for cells in this row whose `CellSpec.insets` is nil.
    /// Nil falls through to `ControlGrid.defaultCellInsets`.
    var cellInsets: UIEdgeInsets?

    init(
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
struct ControlGridCell {
    /// The content view for this cell. Pass `nil` to create a spacer cell
    /// that takes up space but renders nothing.
    var view: UIView?
    /// Per-cell layout overrides. Nil uses the parent row/grid defaults.
    var spec: CellSpec?

    init(view: UIView? = nil, spec: CellSpec? = nil) {
        self.view = view
        self.spec = spec
    }
}

// MARK: - ControlGridRow

/// A single row in a `ControlGrid`.
struct ControlGridRow {
    /// The cells to display in this row. Cell count implicitly defines the
    /// column count for this row (each row can have a different number of cells).
    var cells: [ControlGridCell]
    /// Row-level layout overrides. Nil uses the grid's `defaultRowSpec`.
    var spec: RowSpec?

    init(cells: [ControlGridCell], spec: RowSpec? = nil) {
        self.cells = cells
        self.spec = spec
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
    func setContent(_ view: UIView, insets: UIEdgeInsets) {
        contentView?.removeFromSuperview()
        NSLayoutConstraint.deactivate(contentConstraints)
        contentView = view
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
class ControlGrid: UIScrollView {

    // MARK: Configuration

    /// Grid-level fallback spec applied to any row whose `spec` is `nil`.
    var defaultRowSpec: RowSpec

    /// Vertical spacing between rows in points.
    var rowSpacing: CGFloat

    /// How rows are vertically positioned when total content height < bounds.
    var contentAlignment: ContentAlignment

    /// Horizontal spacing between cells, used when `RowSpec.cellSpacing` is nil.
    var defaultCellSpacing: CGFloat

    /// Cell insets used when neither `CellSpec.insets` nor `RowSpec.cellInsets`
    /// is set.
    var defaultCellInsets: UIEdgeInsets

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
    init(
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

    required init?(coder: NSCoder) {
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
    /// Removes existing cell containers from the view hierarchy, builds new
    /// ones from the provided rows, then triggers a layout pass.
    ///
    /// - Parameter rows: The rows to display. Each row defines its own cells
    ///   and may override the grid's `defaultRowSpec`.
    func setRows(_ rows: [ControlGridRow]) {
        cellContainers.flatMap { $0 }.forEach { $0.removeFromSuperview() }
        cellContainers = []
        self.rows = rows

        for row in rows {
            let rowSpec = row.spec ?? defaultRowSpec
            var rowCells: [CellContainer] = []
            for cell in row.cells {
                let container = CellContainer()
                let insets = cell.spec?.insets ?? rowSpec.cellInsets ?? defaultCellInsets
                if let view = cell.view {
                    container.setContent(view, insets: insets)
                }
                addSubview(container)
                rowCells.append(container)
            }
            cellContainers.append(rowCells)
        }
        setNeedsLayout()
    }

    // MARK: Layout

    override func layoutSubviews() {
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
        let rowDimensions = rowSpecs.map { $0.height }
        let (rowHeights, needsScrolling) = distributeSizes(
            availableSpace: availableHeight,
            dimensions: rowDimensions,
            spacing: rowSpacing,
            proportionalShrink: false
        )

        let totalRowSpacing = CGFloat(max(0, rowCount - 1)) * rowSpacing
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
            let rowSpec = row.spec ?? defaultRowSpec
            let rowH = rowHeights[rowIndex]
            let cellSpacing = rowSpec.cellSpacing ?? defaultCellSpacing
            let cellCount = row.cells.count

            let cellDimensions = row.cells.map { cell -> GridDimension in
                cell.spec?.width ?? rowSpec.defaultCellWidth
            }

            let (cellWidths, _) = distributeSizes(
                availableSpace: availableWidth,
                dimensions: cellDimensions,
                spacing: cellSpacing,
                proportionalShrink: true
            )

            let totalCellSpacing = CGFloat(max(0, cellCount - 1)) * cellSpacing
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
                let w = cellWidths[colIndex]
                container.frame = CGRect(x: currentX, y: currentY, width: w, height: rowH)
                currentX += w + cellSpacing
            }

            currentY += rowH + rowSpacing
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

        for (i, dim) in dimensions.enumerated() {
            switch dim {
            case .fixed(let h):
                sizes[i] = h
                fixedTotal += h
            case .flexible:
                flexibleIndices.append(i)
            }
        }

        // Handle proportional shrink for horizontal axis
        if proportionalShrink && fixedTotal > spaceForItems && spaceForItems > 0 {
            let ratio = spaceForItems / fixedTotal
            for i in 0..<count {
                if case .fixed = dimensions[i] {
                    sizes[i] *= ratio
                }
            }
            // Flexible items get 0 (no space left after fixed items shrunk to fill)
            return (sizes, false)
        }

        // Minimum check for vertical scrolling trigger
        var minTotal: CGFloat = fixedTotal
        for i in flexibleIndices {
            if case .flexible(let min, _) = dimensions[i] {
                minTotal += (min ?? 0)
            }
        }

        if minTotal > spaceForItems {
            // Content doesn't fit even at minimum sizes
            var remaining = spaceForItems - fixedTotal
            for i in flexibleIndices {
                if case .flexible(let min, _) = dimensions[i] {
                    let allocated = min ?? 0
                    sizes[i] = allocated
                    remaining -= allocated
                }
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
            let sharePerItem = spaceForFlexible / CGFloat(unclamped.count)

            for i in unclamped {
                if case .flexible(let minH, let maxH) = dimensions[i] {
                    if let maxH, sharePerItem > maxH {
                        sizes[i] = maxH
                        spaceForFlexible -= maxH
                        unclamped.remove(i)
                        changed = true
                    } else if let minH, sharePerItem < minH {
                        sizes[i] = minH
                        spaceForFlexible -= minH
                        unclamped.remove(i)
                        changed = true
                    }
                }
            }
        }

        // Assign final share to unclamped flexible items
        if !unclamped.isEmpty {
            let finalShare = max(0, spaceForFlexible / CGFloat(unclamped.count))
            for i in unclamped {
                sizes[i] = finalShare
            }
        }

        return (sizes, false)
    }
}

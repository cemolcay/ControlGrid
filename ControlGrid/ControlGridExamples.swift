import UIKit

// MARK: - ControlGridDemo

/// A named demo configuration for ControlGrid.
struct ControlGridDemo {
    /// Short title shown in the navigation bar.
    let name: String
    /// One-line description shown below the title.
    let subtitle: String
    /// Returns a freshly configured ControlGrid for this demo.
    let makeGrid: () -> ControlGrid
}

// MARK: - ControlGridDemoContainer

/// Hosts a demo ControlGrid with a title and subtitle label above it.
class ControlGridDemoContainer: UIView {

    // MARK: Subviews

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = .label
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let gridContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.systemBackground
        v.layer.cornerRadius = 12
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.separator.cgColor
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var currentGrid: ControlGrid?

    // MARK: Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        addSubview(nameLabel)
        addSubview(subtitleLabel)
        addSubview(gridContainer)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            gridContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            gridContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            gridContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            gridContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }

    // MARK: API

    /// Loads a demo, replacing the current grid.
    func load(_ demo: ControlGridDemo) {
        nameLabel.text = demo.name
        subtitleLabel.text = demo.subtitle

        currentGrid?.removeFromSuperview()
        let grid = demo.makeGrid()
        grid.translatesAutoresizingMaskIntoConstraints = false
        gridContainer.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: gridContainer.topAnchor),
            grid.leadingAnchor.constraint(equalTo: gridContainer.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: gridContainer.trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: gridContainer.bottomAnchor),
        ])
        currentGrid = grid
    }
}

// MARK: - ControlGridExamplesViewController

/// A view controller that pages through ControlGrid demo configurations.
///
/// The root layout is itself a ControlGrid with two rows:
/// - Row 0 (flexible): the demo container
/// - Row 1 (fixed 64pt): previous / counter / next navigation
class ControlGridExamplesViewController: UIViewController {

    // MARK: Subviews

    private let rootGrid = ControlGrid(
        defaultRowSpec: RowSpec(height: .flexible(min: nil, max: nil)),
        rowSpacing: 0,
        contentAlignment: .top,
        defaultCellSpacing: 0
    )

    private let demoContainer = ControlGridDemoContainer()

    private let prevButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("← Prev", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        return b
    }()

    private let nextButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Next →", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        return b
    }()

    private let counterLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        return l
    }()

    // MARK: State

    private var currentIndex = 0

    private lazy var demos: [ControlGridDemo] = makeAllDemos()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "ControlGrid Examples"

        prevButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)

        // Root layout: demo container fills top, nav row fixed at bottom
        rootGrid.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootGrid)
        NSLayoutConstraint.activate([
            rootGrid.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            rootGrid.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rootGrid.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rootGrid.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        rootGrid.setRows([
            // Demo area — takes all remaining vertical space
            ControlGridRow(cells: [ControlGridCell(view: demoContainer)]),

            // Navigation row — fixed height, prev|counter|next
            ControlGridRow(
                cells: [
                    ControlGridCell(view: prevButton,    spec: CellSpec(width: .fixed(90))),
                    ControlGridCell(view: counterLabel),
                    ControlGridCell(view: nextButton,    spec: CellSpec(width: .fixed(90))),
                ],
                spec: RowSpec(
                    height: .fixed(64),
                    horizontalAlignment: .center,
                    cellSpacing: 8,
                    cellInsets: UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
                )
            ),
        ])

        showDemo(at: 0)
    }

    // MARK: Navigation

    @objc private func prevTapped() {
        showDemo(at: (currentIndex - 1 + demos.count) % demos.count)
    }

    @objc private func nextTapped() {
        showDemo(at: (currentIndex + 1) % demos.count)
    }

    private func showDemo(at index: Int) {
        currentIndex = index
        let demo = demos[index]
        demoContainer.load(demo)
        counterLabel.text = "\(index + 1) / \(demos.count)"
        prevButton.isEnabled = true
        nextButton.isEnabled = true
    }
}

// MARK: - Demo Catalogue

private func makeAllDemos() -> [ControlGridDemo] {
    [
        demoEqualGrid(),
        demoMixedRowHeights(),
        demoVariableColumnCounts(),
        demoFixedCellsWithSpacer(),
        demoCenteringPattern(),
        demoHorizontalAlignments(),
        demoSpacerRows(),
        demoScrollingOverflow(),
        demoCellInsets(),
        demoNestedGrid(),
    ]
}

// MARK: Demo 1 — Equal Grid

private func demoEqualGrid() -> ControlGridDemo {
    ControlGridDemo(
        name: "Equal Grid",
        subtitle: "3 rows × 4 cols, all cells and rows share space equally"
    ) {
        let grid = ControlGrid(
            defaultRowSpec: RowSpec(height: .flexible(min: nil, max: nil)),
            rowSpacing: 8,
            contentAlignment: .center,
            defaultCellSpacing: 8
        )
        grid.backgroundColor = .clear

        let labels = ["A", "B", "C", "D",
                      "E", "F", "G", "H",
                      "I", "J", "K", "L"]

        grid.setRows([
            ControlGridRow(cells: labels[0..<4].enumerated().map { i, t in ControlGridCell(view: demoCell(t, i)) }),
            ControlGridRow(cells: labels[4..<8].enumerated().map { i, t in ControlGridCell(view: demoCell(t, i + 4)) }),
            ControlGridRow(cells: labels[8..<12].enumerated().map { i, t in ControlGridCell(view: demoCell(t, i + 8)) }),
        ])
        return grid
    }
}

// MARK: Demo 2 — Mixed Row Heights

private func demoMixedRowHeights() -> ControlGridDemo {
    ControlGridDemo(
        name: "Mixed Row Heights",
        subtitle: "Fixed header (44pt), flexible content rows (min:40 max:90), fixed footer (40pt)"
    ) {
        let grid = ControlGrid(
            defaultRowSpec: RowSpec(height: .flexible(min: 40, max: 90)),
            rowSpacing: 8,
            contentAlignment: .center
        )

        let header = demoCell("Header", 5)
        let footer = demoCell("Footer", 6)

        grid.setRows([
            ControlGridRow(
                cells: [ControlGridCell(view: header)],
                spec: RowSpec(height: .fixed(44))
            ),
            ControlGridRow(cells: [0, 1, 2, 3].map { i in ControlGridCell(view: demoCell("\(i+1)", i)) }),
            ControlGridRow(cells: [4, 5, 6, 7].map { i in ControlGridCell(view: demoCell("\(i+1)", i)) }),
            ControlGridRow(
                cells: [ControlGridCell(view: footer)],
                spec: RowSpec(height: .fixed(40))
            ),
        ])
        return grid
    }
}

// MARK: Demo 3 — Variable Column Counts

private func demoVariableColumnCounts() -> ControlGridDemo {
    ControlGridDemo(
        name: "Variable Column Counts",
        subtitle: "Each row has a different number of cells — 1, 2, 3, then 4 columns"
    ) {
        let grid = ControlGrid(
            defaultRowSpec: RowSpec(height: .flexible(min: nil, max: nil)),
            rowSpacing: 8,
            contentAlignment: .center
        )

        grid.setRows([
            ControlGridRow(cells: [ControlGridCell(view: demoCell("1 col", 0))]),
            ControlGridRow(cells: (0..<2).map { i in ControlGridCell(view: demoCell("2–\(i+1)", 1)) }),
            ControlGridRow(cells: (0..<3).map { i in ControlGridCell(view: demoCell("3–\(i+1)", 2)) }),
            ControlGridRow(cells: (0..<4).map { i in ControlGridCell(view: demoCell("4–\(i+1)", i + 3)) }),
        ])
        return grid
    }
}

// MARK: Demo 4 — Fixed Cells + Spacer

private func demoFixedCellsWithSpacer() -> ControlGridDemo {
    ControlGridDemo(
        name: "Fixed Cells + Spacer",
        subtitle: "Two fixed-width buttons separated by a flexible spacer cell (view: nil)"
    ) {
        let grid = ControlGrid(
            defaultRowSpec: RowSpec(height: .flexible(min: nil, max: nil)),
            rowSpacing: 8,
            contentAlignment: .center
        )

        // Each row: [fixed button] [spacer] [fixed button]
        // Spacer width grows/shrinks with available space
        func navRow(_ left: String, _ right: String, _ colorIndex: Int) -> ControlGridRow {
            ControlGridRow(cells: [
                ControlGridCell(view: demoCell(left, colorIndex),   spec: CellSpec(width: .fixed(80))),
                ControlGridCell(view: nil),  // flexible spacer
                ControlGridCell(view: demoCell(right, colorIndex + 1), spec: CellSpec(width: .fixed(80))),
            ])
        }

        grid.setRows([
            navRow("Back", "Next", 0),
            navRow("Cancel", "Save", 2),
            navRow("−", "+", 4),
        ])
        return grid
    }
}

// MARK: Demo 5 — Centering with Spacers

private func demoCenteringPattern() -> ControlGridDemo {
    ControlGridDemo(
        name: "Centering with Spacers",
        subtitle: "nil spacers on both sides center a fixed-width cell in each row"
    ) {
        let grid = ControlGrid(
            defaultRowSpec: RowSpec(height: .flexible(min: nil, max: nil)),
            rowSpacing: 8,
            contentAlignment: .center
        )

        // [spacer] [fixed content] [spacer] — spacers share remaining width equally
        func centeredRow(_ label: String, width: CGFloat, colorIndex: Int) -> ControlGridRow {
            ControlGridRow(cells: [
                ControlGridCell(view: nil),
                ControlGridCell(view: demoCell(label, colorIndex), spec: CellSpec(width: .fixed(width))),
                ControlGridCell(view: nil),
            ])
        }

        grid.setRows([
            centeredRow("Wide (200pt)",   width: 200, colorIndex: 0),
            centeredRow("Medium (140pt)", width: 140, colorIndex: 2),
            centeredRow("Narrow (80pt)",  width: 80,  colorIndex: 4),
            centeredRow("Tiny (50pt)",    width: 50,  colorIndex: 6),
        ])
        return grid
    }
}

// MARK: Demo 6 — Horizontal Alignments

private func demoHorizontalAlignments() -> ControlGridDemo {
    ControlGridDemo(
        name: "Horizontal Alignment",
        subtitle: "Three rows using .leading, .center, and .trailing alignment"
    ) {
        let grid = ControlGrid(
            defaultRowSpec: RowSpec(height: .flexible(min: nil, max: nil)),
            rowSpacing: 8,
            contentAlignment: .center
        )

        // Each row has 2 fixed-width cells, pushed to different edges
        func alignedRow(_ alignment: HorizontalAlignment, _ label: String, _ colorIndex: Int) -> ControlGridRow {
            ControlGridRow(
                cells: [
                    ControlGridCell(view: demoCell(label, colorIndex),     spec: CellSpec(width: .fixed(80))),
                    ControlGridCell(view: demoCell(label, colorIndex + 1), spec: CellSpec(width: .fixed(80))),
                ],
                spec: RowSpec(
                    height: .flexible(min: nil, max: nil),
                    horizontalAlignment: alignment,
                    defaultCellWidth: .flexible(min: nil, max: nil),
                    cellSpacing: 8
                )
            )
        }

        grid.setRows([
            alignedRow(.leading,  "Leading",  0),
            alignedRow(.center,   "Center",   2),
            alignedRow(.trailing, "Trailing", 4),
        ])
        return grid
    }
}

// MARK: Demo 7 — Spacer Rows

private func demoSpacerRows() -> ControlGridDemo {
    ControlGridDemo(
        name: "Spacer Rows",
        subtitle: "Empty rows with fixed height act as visual dividers between content"
    ) {
        let grid = ControlGrid(
            defaultRowSpec: RowSpec(height: .flexible(min: nil, max: nil)),
            rowSpacing: 0,  // row spacing is zero — spacing is done via spacer rows
            contentAlignment: .center
        )

        let spacer8  = ControlGridRow(cells: [], spec: RowSpec(height: .fixed(8)))
        let spacer24 = ControlGridRow(cells: [], spec: RowSpec(height: .fixed(24)))

        grid.setRows([
            ControlGridRow(cells: (0..<3).map { i in ControlGridCell(view: demoCell("Top \(i+1)", i)) }),
            spacer24,
            ControlGridRow(cells: (0..<3).map { i in ControlGridCell(view: demoCell("Mid \(i+1)", i + 3)) }),
            spacer8,
            ControlGridRow(cells: (0..<3).map { i in ControlGridCell(view: demoCell("Mid \(i+1)", i + 3)) }),
            spacer24,
            ControlGridRow(cells: (0..<3).map { i in ControlGridCell(view: demoCell("Bot \(i+1)", i + 5)) }),
        ])
        return grid
    }
}

// MARK: Demo 8 — Scrolling Overflow

private func demoScrollingOverflow() -> ControlGridDemo {
    ControlGridDemo(
        name: "Scrolling Overflow",
        subtitle: "8 rows with min:50pt — scrolls when rows can't fit in the available height"
    ) {
        let grid = ControlGrid(
            defaultRowSpec: RowSpec(height: .flexible(min: 50, max: 70)),
            rowSpacing: 8,
            contentAlignment: .top
        )

        let rows = (0..<8).map { rowIndex in
            ControlGridRow(cells: (0..<3).map { colIndex in
                ControlGridCell(view: demoCell("R\(rowIndex+1)C\(colIndex+1)", rowIndex * 3 + colIndex))
            })
        }
        grid.setRows(rows)
        return grid
    }
}

// MARK: Demo 9 — Cell Insets

private func demoCellInsets() -> ControlGridDemo {
    ControlGridDemo(
        name: "Cell Insets",
        subtitle: "Same 2×4 grid — each row overrides cell insets to show padding differences"
    ) {
        let grid = ControlGrid(
            defaultRowSpec: RowSpec(height: .flexible(min: nil, max: nil)),
            rowSpacing: 8,
            contentAlignment: .center,
            defaultCellInsets: .zero
        )

        func row(_ label: String, insets: UIEdgeInsets, colorIndex: Int) -> ControlGridRow {
            ControlGridRow(
                cells: (0..<4).map { i in ControlGridCell(view: demoCell(label, colorIndex + i)) },
                spec: RowSpec(
                    height: .flexible(min: nil, max: nil),
                    cellInsets: insets
                )
            )
        }

        grid.setRows([
            row("0pt",  insets: .zero,                                              colorIndex: 0),
            row("4pt",  insets: UIEdgeInsets(top: 4,  left: 4,  bottom: 4,  right: 4),  colorIndex: 2),
            row("8pt",  insets: UIEdgeInsets(top: 8,  left: 8,  bottom: 8,  right: 8),  colorIndex: 4),
            row("16pt", insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16), colorIndex: 6),
        ])
        return grid
    }
}

// MARK: Demo 10 — Nested Grid

private func demoNestedGrid() -> ControlGridDemo {
    ControlGridDemo(
        name: "Nested Grid",
        subtitle: "A 2×2 outer grid where one cell contains an inner ControlGrid"
    ) {
        // Inner grid: 2×3 equal cells
        let innerGrid = ControlGrid(
            defaultRowSpec: RowSpec(height: .flexible(min: nil, max: nil)),
            rowSpacing: 4,
            contentAlignment: .center,
            defaultCellSpacing: 4
        )
        innerGrid.backgroundColor = UIColor.systemFill
        innerGrid.layer.cornerRadius = 8
        innerGrid.clipsToBounds = true
        innerGrid.setRows([
            ControlGridRow(cells: (0..<3).map { i in ControlGridCell(view: demoCell("i\(i+1)", i + 2), spec: CellSpec(insets: UIEdgeInsets(top: 3, left: 3, bottom: 3, right: 3))) }),
            ControlGridRow(cells: (0..<3).map { i in ControlGridCell(view: demoCell("i\(i+4)", i + 5), spec: CellSpec(insets: UIEdgeInsets(top: 3, left: 3, bottom: 3, right: 3))) }),
        ])

        // Outer grid: 2×2, one cell replaced by innerGrid
        let outerGrid = ControlGrid(
            defaultRowSpec: RowSpec(height: .flexible(min: nil, max: nil)),
            rowSpacing: 8,
            contentAlignment: .center
        )
        outerGrid.setRows([
            ControlGridRow(cells: [
                ControlGridCell(view: demoCell("A", 0)),
                ControlGridCell(view: demoCell("B", 1)),
            ]),
            ControlGridRow(cells: [
                ControlGridCell(view: demoCell("C", 6)),
                ControlGridCell(view: innerGrid),  // nested ControlGrid as a cell
            ]),
        ])
        return outerGrid
    }
}

// MARK: - Helpers

private let demoPalette: [UIColor] = [
    UIColor(red: 0.27, green: 0.45, blue: 0.87, alpha: 1),  // indigo
    UIColor(red: 0.87, green: 0.38, blue: 0.31, alpha: 1),  // coral
    UIColor(red: 0.25, green: 0.72, blue: 0.52, alpha: 1),  // mint
    UIColor(red: 0.87, green: 0.71, blue: 0.27, alpha: 1),  // amber
    UIColor(red: 0.60, green: 0.31, blue: 0.87, alpha: 1),  // violet
    UIColor(red: 0.27, green: 0.71, blue: 0.87, alpha: 1),  // sky
    UIColor(red: 0.87, green: 0.53, blue: 0.27, alpha: 1),  // orange
    UIColor(red: 0.50, green: 0.75, blue: 0.27, alpha: 1),  // lime
]

/// Creates a colored cell view with a centered label.
private func demoCell(_ text: String, _ colorIndex: Int) -> UIView {
    let container = UIView()
    container.backgroundColor = demoPalette[abs(colorIndex) % demoPalette.count]
    container.layer.cornerRadius = 6
    container.clipsToBounds = true

    let label = UILabel()
    label.text = text
    label.textAlignment = .center
    label.font = .systemFont(ofSize: 12, weight: .semibold)
    label.textColor = .white
    label.adjustsFontSizeToFitWidth = true
    label.minimumScaleFactor = 0.6
    label.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(label)

    NSLayoutConstraint.activate([
        label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 4),
        label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -4),
    ])
    return container
}

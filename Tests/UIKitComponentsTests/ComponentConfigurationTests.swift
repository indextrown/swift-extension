#if canImport(UIKit) && !os(watchOS) && !os(tvOS)
import Testing
import UIKit
@testable import UIKitComponents

/// 컴포넌트를 셀에 넣은 컬렉션뷰를 창에 띄워 배치까지 돌리는 도우미예요.
@MainActor
private final class CollectionFixture {
    let window: UIWindow
    let collectionView: UICollectionView
    let makeCounter = Counter()
    var texts: [String]
    private var dataSource: UICollectionViewDiffableDataSource<Int, Int>!

    init(texts: [String]) {
        self.texts = texts
        self.collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 240, height: 800),
            collectionViewLayout: UICollectionViewCompositionalLayout.list(using: .init(appearance: .plain))
        )
        self.window = UIWindow(frame: self.collectionView.frame)
        self.window.addSubview(self.collectionView)
        self.window.makeKeyAndVisible()

        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { [unowned self] cell, _, index in
            cell.contentConfiguration = LabelComponent(self.texts[index], makeCounter: self.makeCounter).contentConfiguration()
        }
        self.dataSource = UICollectionViewDiffableDataSource(collectionView: self.collectionView) { collectionView, indexPath, index in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: index)
        }

        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(Array(texts.indices))
        self.dataSource.apply(snapshot, animatingDifferences: false)
        runLayout(self.window)
    }

    func cell(at item: Int) -> UICollectionViewCell? {
        return self.collectionView.cellForItem(at: IndexPath(item: item, section: 0))
    }

    func contentView(at item: Int) -> ComponentContentView<LabelComponent>? {
        return self.cell(at: item)?.contentView as? ComponentContentView<LabelComponent>
    }

    func reconfigureAll(with texts: [String]) {
        self.texts = texts
        var snapshot = self.dataSource.snapshot()
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        self.dataSource.apply(snapshot, animatingDifferences: false)
        runLayout(self.window)
    }

    func scrollToEnd() {
        for offset in stride(from: 0, through: self.collectionView.contentSize.height, by: 200) {
            self.collectionView.contentOffset.y = offset
            runLayout(self.window)
        }
    }
}

private func alternatingTexts(count: Int, flipped: Bool = false) -> [String] {
    return (0..<count).map { ($0.isMultiple(of: 2) != flipped) ? longText : shortText }
}

@MainActor
@Test func collectionViewCellsSizeToComponentContent() throws {
    let fixture = CollectionFixture(texts: alternatingTexts(count: 10))

    let longCell = try #require(fixture.cell(at: 0))
    let shortCell = try #require(fixture.cell(at: 1))

    #expect(abs(longCell.frame.height - expectedHeight(longText, width: 240)) < 1)
    #expect(abs(shortCell.frame.height - expectedHeight(shortText, width: 240)) < 1)
}

@MainActor
@Test func collectionViewReusesComponentViewsWhileScrolling() {
    let fixture = CollectionFixture(texts: alternatingTexts(count: 40))

    fixture.scrollToEnd()

    #expect(fixture.makeCounter.value < 40)
}

@MainActor
@Test func reconfiguringCellKeepsViewAndResizes() throws {
    let fixture = CollectionFixture(texts: alternatingTexts(count: 10))
    let before = try #require(fixture.contentView(at: 0))

    fixture.reconfigureAll(with: alternatingTexts(count: 10, flipped: true))

    let after = try #require(fixture.contentView(at: 0))
    let cell = try #require(fixture.cell(at: 0))
    #expect(before === after)
    #expect(after.hostedView.label.text == shortText)
    #expect(abs(cell.frame.height - expectedHeight(shortText, width: 240)) < 1)
}

@MainActor
@Test func cellResizesAfterInvalidateLayout() throws {
    guard #available(iOS 16.0, *) else { return }

    let contextBox = ContextBox()
    let collectionView = UICollectionView(
        frame: CGRect(x: 0, y: 0, width: 240, height: 800),
        collectionViewLayout: UICollectionViewCompositionalLayout.list(using: .init(appearance: .plain))
    )
    let window = UIWindow(frame: collectionView.frame)
    window.addSubview(collectionView)
    window.makeKeyAndVisible()
    let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Int> { cell, _, _ in
        cell.contentConfiguration = LabelComponent(shortText, contextBox: contextBox).contentConfiguration()
    }
    let dataSource = UICollectionViewDiffableDataSource<Int, Int>(collectionView: collectionView) { collectionView, indexPath, item in
        collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
    }
    var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
    snapshot.appendSections([0])
    snapshot.appendItems([0])
    dataSource.apply(snapshot, animatingDifferences: false)
    runLayout(window)
    let cell = try #require(collectionView.cellForItem(at: IndexPath(item: 0, section: 0)))
    let contentView = try #require(cell.contentView as? ComponentContentView<LabelComponent>)

    /// 이미지를 받아 넣은 것처럼 데이터 소스를 건드리지 않고 뷰의 크기만 바꿔요.
    contentView.hostedView.label.text = longText
    contextBox.context?.invalidateLayout()
    runLayout(window)

    #expect(abs(cell.frame.height - expectedHeight(longText, width: 240)) < 1)
}

@MainActor
@Test func tableViewCellsSizeToComponentContentAndReuse() throws {
    let texts = alternatingTexts(count: 40)
    let makeCounter = Counter()
    let dataSource = TableDataSource(texts: texts, makeCounter: makeCounter)
    let tableView = UITableView(frame: CGRect(x: 0, y: 0, width: 240, height: 800), style: .plain)
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: TableDataSource.reuseIdentifier)
    tableView.dataSource = dataSource
    let window = UIWindow(frame: tableView.frame)
    window.addSubview(tableView)
    window.makeKeyAndVisible()
    tableView.reloadData()
    runLayout(window)

    let longCell = try #require(tableView.cellForRow(at: IndexPath(row: 0, section: 0)))
    let shortCell = try #require(tableView.cellForRow(at: IndexPath(row: 1, section: 0)))
    /// 테이블뷰 셀은 구분선 높이만큼 더 커질 수 있어요.
    #expect(abs(longCell.frame.height - expectedHeight(longText, width: 240)) < 2)
    #expect(abs(shortCell.frame.height - expectedHeight(shortText, width: 240)) < 2)

    for offset in stride(from: 0, through: tableView.contentSize.height, by: 200) {
        tableView.contentOffset.y = offset
        runLayout(window)
    }
    #expect(makeCounter.value < texts.count)
}

@MainActor
@Test func newConfigurationCancelsPreviousWork() {
    let cancellations = Counter()
    let contentView = CancellationComponent(cancellations: cancellations).contentConfiguration().makeContentView()

    contentView.configuration = CancellationComponent(cancellations: cancellations).contentConfiguration()

    #expect(cancellations.value == 1)
}

@MainActor
@Test func cellStateChangeDoesNotUpdateNonEquatableComponent() {
    var updates = 0
    let configuration = ClosureComponent(text: shortText) { updates += 1 }.contentConfiguration()
    let contentView = configuration.makeContentView()
    #expect(updates == 1)

    /// 셀의 강조·선택 상태가 바뀌면 UIKit은 `updated(for:)`로 만든 같은 설정을 다시 넣어요.
    contentView.configuration = configuration.updated(for: UICellConfigurationState(traitCollection: UITraitCollection()))
    #expect(updates == 1)

    /// 새로 만든 설정은 값이 같아도 갱신해요. 클로저를 담은 컴포넌트는 비교할 수 없기 때문이에요.
    contentView.configuration = ClosureComponent(text: shortText) { updates += 1 }.contentConfiguration()
    #expect(updates == 2)
}

@MainActor
@Test func changingConfigurationComponentUpdatesAgain() {
    var updates = 0
    var configuration = ClosureComponent(text: shortText) { updates += 1 }.contentConfiguration()
    let contentView = configuration.makeContentView()

    configuration.component = ClosureComponent(text: longText) { updates += 1 }
    contentView.configuration = configuration

    #expect(updates == 2)
}

@MainActor
@Test func highlightingListCellDoesNotUpdateComponent() {
    var updates = 0
    let cell = UICollectionViewListCell(frame: CGRect(x: 0, y: 0, width: 240, height: 80))
    cell.contentConfiguration = ClosureComponent(text: shortText) { updates += 1 }.contentConfiguration()
    cell.layoutIfNeeded()
    let updatesAfterSetup = updates

    cell.isHighlighted = true
    cell.layoutIfNeeded()
    cell.isSelected = true
    cell.layoutIfNeeded()
    cell.isHighlighted = false
    cell.layoutIfNeeded()

    #expect(updatesAfterSetup == 1)
    #expect(updates == updatesAfterSetup)
}

@MainActor
@Test func releasedContentViewCancelsWork() {
    let cancellations = Counter()

    autoreleasepool {
        let contentView = CancellationComponent(cancellations: cancellations).contentConfiguration().makeContentView()
        #expect(contentView.configuration is ComponentConfiguration<CancellationComponent>)
    }

    #expect(cancellations.value == 1)
}

@MainActor
@Test func contentViewSupportsOnlySameComponentType() {
    guard #available(iOS 16.0, *) else { return }

    let contentView = LabelComponent("a").contentConfiguration().makeContentView()

    #expect(contentView.supports(LabelComponent("b").contentConfiguration()))
    #expect(!contentView.supports(UIListContentConfiguration.cell()))
}

private final class TableDataSource: NSObject, UITableViewDataSource {
    static let reuseIdentifier = "cell"

    let texts: [String]
    let makeCounter: Counter

    init(texts: [String], makeCounter: Counter) {
        self.texts = texts
        self.makeCounter = makeCounter
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.texts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.reuseIdentifier, for: indexPath)
        cell.contentConfiguration = LabelComponent(self.texts[indexPath.row], makeCounter: self.makeCounter).contentConfiguration()
        return cell
    }
}
#endif

// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// The children a registered view draws itself, handed to it alike on every host: whole, in order, the same child the
/// same object, and only when the children changed.
final class DrawnChildrenTests: XCTestCase {
    /// A child the parent's view draws has no view of its own; another child, or the same type elsewhere, does.
    @MainActor
    func testAChildTheParentDrawsHasNoViewOfItsOwn() {
        let (runtime, _) = Self.runtime()
        runtime.tree.apply(Self.shelf(["a", "b"], extra: true), complete: true)

        let children = runtime.tree.root?.children ?? []
        XCTAssertEqual(children.map { $0.isDrawnByParent(in: Self.registry) }, [true, true, false])
        XCTAssertEqual(children.map { $0.native.presentsView }, [false, false, true])
    }

    /// The view is handed every child it draws, in order, when the element is made and whenever its children change -
    /// one taken away, one given another value - and not when only its own values change; a child stays the same
    /// object for as long as it lives.
    @MainActor
    func testTheViewIsHandedItsChildrenWheneverTheyChange() throws {
        let (runtime, shelf) = Self.runtime()
        runtime.tree.apply(Self.shelf(["a", "b"]), complete: true)
        let first = try XCTUnwrap(shelf.handed.last)

        var own = HostPatch(id: .manual("shelf"), type: ShelfContract.nodeType)
        own.properties[ShelfContract.caption.token] = .string("Books")
        runtime.tree.apply(own, complete: false)
        XCTAssertEqual(shelf.handed.count, 1, "its own value changed, its children did not")

        var renamed = HostPatch(id: .manual("shelf"), type: ShelfContract.nodeType)
        var book = HostPatch(id: .manual("b"), type: BookContract.nodeType)
        book.properties[BookContract.title.token] = .string("b, again")
        renamed.children = .changed([book])
        runtime.tree.apply(renamed, complete: false)
        runtime.tree.apply(Self.shelf(["b"]), complete: false)

        XCTAssertEqual(shelf.handed.map { $0.map(\.title) }, [["a", "b"], ["a", "b, again"], ["b"]])
        XCTAssertEqual(shelf.handed[2][0].child, first[1].child, "the same child is the same object")
    }

    // MARK: - Support

    /// The shelf's registry: its view draws the books among its children.
    @MainActor
    static let registry: Registry<ShelfView> = {
        let registry = Registry<ShelfView>()
        registry.add(ShelfContract.self, create: { _ in ShelfView() }) { shelf in
            shelf.children(BookContract.self, members: [BookContract.title]) { view, books in
                view.handed.append(books.map { (child: $0, title: $0.value(BookContract.title) ?? "") })
            }
        }
        return registry
    }()

    /// A runtime whose shelf has the view the registry makes, handed its drawn children as a host's native half
    /// hands them; every other element has none.
    @MainActor
    private static func runtime() -> (HostRuntime, ShelfView) {
        let shelf = ShelfView()
        var made: HostRuntime?
        let runtime = HostRuntime(clock: StillClock(), reducesMotion: { false }, makeNative: { element in
            Drawing(element, view: element.type == ShelfContract.nodeType ? shelf : nil) { made }
        }, log: { _ in })
        made = runtime
        return (runtime, shelf)
    }

    /// A shelf holding a book for each title, and a label after them where `extra` says.
    private static func shelf(_ titles: [String], extra: Bool = false) -> HostPatch {
        var shelf = HostPatch(id: .manual("shelf"), type: ShelfContract.nodeType)
        var children = titles.map { title in
            var book = HostPatch(id: .manual(title), type: BookContract.nodeType)
            book.properties[BookContract.title.token] = .string(title)
            return book
        }
        if extra { children.append(HostPatch(id: .manual("label"), type: .text)) }
        shelf.children = .arranged(children)
        return shelf
    }
}

/// The shelf's view: every list of books it was handed, each book with its title.
@MainActor
final class ShelfView {
    var handed: [[(child: ChildElement<BookContract>, title: String)]] = []
}

/// A native half handing its view the children it draws, as every host's does.
@MainActor
private final class Drawing: NativeElement {
    unowned let element: MountedElement
    let view: ShelfView?
    let runtime: () -> HostRuntime?

    init(_ element: MountedElement, view: ShelfView?, runtime: @escaping () -> HostRuntime?) {
        self.element = element
        self.view = view
        self.runtime = runtime
    }

    var presentsView: Bool { !element.isDrawnByParent(in: DrawnChildrenTests.registry) }
    func standingValue(_ property: Prop) -> HostValue? { nil }
    func animates(_ property: Prop) -> Bool { false }
    func applied(changed: Set<Prop>, wasDescribed: Bool) {
        guard let view, let runtime = runtime() else { return }
        element.applyDrawnChildren(to: view, through: DrawnChildrenTests.registry, in: runtime)
    }
    func presentFrame(_ changed: Set<Prop>) {}
    func arrangeChildren() {}
    func leave() {}
}

/// A view drawing its books itself.
enum ShelfContract: ElementContract {
    static let nodeType: NodeType = "Test.Shelf"
    static let tiers: [any Contract.Type] = [ViewContract.self]
    static let caption = ElementProperty<Self, String>("caption")
    static let members: [any ContractMember] = [caption]
}

/// A book on a shelf, wearing no tier.
enum BookContract: ElementContract {
    static let nodeType: NodeType = "Test.Book"
    static let title = ElementProperty<Self, String>("title")
    static let members: [any ContractMember] = [title]
}

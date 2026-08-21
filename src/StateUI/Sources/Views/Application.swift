// How an application opens, mirroring MAUI's own three types.
//
//     Application  ──createWindow()──▶  Window  ──▶  Page  ──▶  the view tree
//
// The same three types MAUI has, in the same order, doing the same things: an
// Application makes a Window, a Window shows a Page, a Page has content. And all
// three are DECLARED rather than constructed - an application is a type, a
// window is a type, a page is a type:
//
//     struct GalleryApp: Application {
//         func createWindow() -> Window { MainWindow() }
//     }
//
//     struct MainWindow: Window {
//         var title: String? { "StateUI" }
//         var content: Page { MainPage() }
//     }
//
//     struct MainPage: ContentPage {
//         var content: Element {
//             VStack { … }
//         }
//     }
//
// The page and window properties are not decoration: they reach the real MAUI
// Page and Window the host is sitting in.

/// The application. MAUI: Application.
///
/// Handed to `stateUIUseApp` once, at startup - the Swift half of MAUI's
/// `builder.UseMauiApp<App>()`.
public protocol Application {
    /// The application's window. MAUI: Application.CreateWindow.
    ///
    /// Called again on every render, like everything else that describes the
    /// interface, so the window and its page see state changes without anything
    /// being invalidated by hand.
    ///
    /// The FIRST window where there are several - see `windows`, which is what
    /// an application with more than one writes, and which calls this one.
    func createWindow() -> Window

    /// Every window the application has open. MAUI: Application.Windows.
    ///
    /// The one `createWindow()` makes is what an application says by leaving
    /// this alone. An application that can show SEVERAL writes them here, as
    /// ordinary Swift over its own state:
    ///
    ///     @State private var inspectors: [Inspector] = []
    ///
    ///     var windows: [Window] {
    ///         [createWindow()]
    ///             + inspectors.map { InspectorWindow(inspector: $0, open: $inspectors) }
    ///     }
    ///
    ///     struct InspectorWindow: Window {
    ///         let inspector: Inspector
    ///         let open: Binding<[Inspector]>
    ///
    ///         var id: AnyHashable? { inspector }
    ///         var title: String? { inspector.name }
    ///         var onDestroying: EventHandler? {
    ///             { open.wrappedValue.removeAll { $0 == inspector } }
    ///         }
    ///
    ///         var content: Page { InspectorPage(inspector) }
    ///     }
    ///
    /// Opening a window is `inspectors.append(…)` and closing one is `remove`:
    /// there is no act to call and nothing to await, exactly as with a
    /// navigation stack or a modal stack. The host opens and closes the
    /// platform's windows to match what this says.
    ///
    /// A window is a TYPE, so a list of them need not be all of one kind: a
    /// `DocumentWindow` and an `InspectorWindow` are two declarations, and
    /// which of them this list holds is ordinary Swift.
    ///
    /// **Two things are the author's, and both are in the example.** A window
    /// built from a value carries an `id`, or the differ identifies it by
    /// POSITION and closing the middle window of three moves the last one's
    /// content into it. And a window the USER closed is reported through
    /// `onDestroying` - the library cannot fold that back into state it does
    /// not own - so the handler is what keeps the list honest; write it as a
    /// removal BY VALUE, which stays right when this side closed the window
    /// itself and the platform reports it a moment later.
    ///
    /// **iPad, Mac Catalyst and Windows.** A second window needs a platform
    /// with somewhere to put it, and a phone has none. On iOS and Mac Catalyst
    /// the app has to be set up for SCENES as well, and every piece of that
    /// fails silently: `UIApplicationSupportsMultipleScenes` and the full scene
    /// manifest in Info.plist, the app's own registered
    /// `SceneDelegate : MauiUISceneDelegate`, and all four iPad orientations.
    /// Miss one and the first window opens BLANK or the second is refused, with
    /// nothing said either way. Describing more windows than a platform can
    /// open is not an error - the extra ones simply do not appear.
    var windows: [Window] { get }

    /// The reader asked the PLATFORM for a window - and this is where the
    /// application answers by describing one.
    ///
    /// A Mac offers it as *File ▸ New Window*, an iPad as its window controls.
    /// What it usually means is a NEW DOCUMENT - a second copy of the same
    /// thing, with its own state - so the answer is an `append` to whatever
    /// `windows` is built from, exactly as if a button in the interface had
    /// been pressed:
    ///
    ///     @State private var documents: [Int] = []
    ///
    ///     var onCreatingWindow: EventHandler? {
    ///         { documents.append((documents.max() ?? 0) + 1) }
    ///     }
    ///
    ///     var windows: [Window] {
    ///         [createWindow()] + documents.map { DocumentWindow(number: $0, open: $documents) }
    ///     }
    ///
    /// The window the platform made is held OPEN while this runs and is the
    /// very one the new node gets, so the reader sees the window they asked
    /// for rather than a second one opening beside it.
    ///
    /// **An application that leaves this alone shows the windows it lists, and
    /// the platform's window is closed again** - which is the honest answer to
    /// "I do not describe you", and better than the blank window it would
    /// otherwise be. The same happens if the handler runs and describes
    /// nothing new: the tree is what decides, here as everywhere.
    ///
    /// MAUI has no event for this. What the platform does is call
    /// `Application.CreateWindow`, and this is that call reaching the tree -
    /// the mirror of `Window.onDestroying`, which is the platform taking one
    /// away.
    ///
    /// **WINDOWS NEVER ASKS, so an application only for Windows can leave this
    /// alone.** MAUI's WinUI backend calls `Application.CreateWindow` once, from
    /// `OnLaunched`, and a launch that reaches a process already running returns
    /// without making anything - so the taskbar's second window is a second
    /// PROCESS, with a tree of its own. Measured. A Windows app that wants one
    /// launch to reach another instance does its own single-instancing and then
    /// APPENDS to `windows`, which needs nothing from here.
    var onCreatingWindow: EventHandler? { get }

    /// The styles every control in the application can be given.
    /// MAUI: Application.Resources.
    ///
    ///     var styles: StyleSheet? {
    ///         StyleSheet {
    ///             Style<Label>().fontSize(14)
    ///         }
    ///     }
    ///
    /// Read on every render like the window, and never sent: a style is
    /// resolved on this side, into the controls it applies to. See
    /// Views/Style.swift.
    var styles: StyleSheet? { get }

    /// Every piece of state the application KEEPS between launches.
    ///
    ///     var persistentKeys: [PersistentKey] { [.lastGroup, .appearance] }
    ///
    /// The host reads exactly these out of the store before the first view is
    /// built, so a `@State(.lastGroup)` already holds what the reader left
    /// behind the first time anything looks at it.
    ///
    /// **A key left off this list is never read.** State declared with it
    /// still SAVES - the write knows its own key - so the value appears on the
    /// launch after next and the symptom is a setting that lags one run
    /// behind. The list is the one thing that cannot be worked out from the
    /// views, because a store is read key by key and the views that would name
    /// the keys do not exist yet. See Core/Persistence.swift.
    var persistentKeys: [PersistentKey] { get }

    /// WHERE that state is kept. MAUI: Preferences, by default.
    ///
    /// The platform's own settings store unless the application names one it
    /// registered on the host side with `StateUIStores.Add` - which is what an
    /// application writes when its settings belong in a file of its own rather
    /// than beside the platform's.
    var persistentStorage: PersistentStorage { get }
}

extension Application {
    /// No styles of its own, which is what an application says by not writing
    /// this.
    public var styles: StyleSheet? { nil }

    /// Nothing kept between launches, which is what an application says by not
    /// writing this.
    public var persistentKeys: [PersistentKey] { [] }

    /// The platform's own settings store.
    public var persistentStorage: PersistentStorage { .preferences }

    /// One window, the one `createWindow()` makes.
    public var windows: [Window] { [createWindow()] }

    /// No answer, which closes the window the platform opened: an application
    /// shows the windows it describes, and it describes none for this one.
    public var onCreatingWindow: EventHandler? { nil }
}

/// A window onto a page. MAUI: Window.
///
///     struct MainWindow: Window {
///         var title: String? { "My Application" }
///         var width: Double? { 1200 }
///         var height: Double? { 800 }
///         var minimumWidth: Double? { 600 }
///         var minimumHeight: Double? { 400 }
///
///         var content: Page { MainPage() }
///     }
///
/// which is MAUI's own
///
///     new Window(new MainPage()) { Title = …, Width = 1200, … }
///
/// written the way a PAGE is written here: a type you DECLARE and configure,
/// never a value you chain onto. `content` is the only requirement - everything
/// else has an answer for a window that says nothing about it.
///
/// That is what makes a window a place to put things. An application with
/// several kinds says each kind once
///
///     struct DocumentWindow: Window { … }
///     struct InspectorWindow: Window { … }
///
/// and `windows` on the Application is a list of them, mixed freely. The
/// ARRANGEMENT belongs here too: a window's `content` is where a
/// `NavigationPage` over a path, a `TabbedPage` over a selection or a
/// `FlyoutPage` over a menu is written, so which windows an application has
/// open and how each of them moves are one declaration apiece.
///
/// **Where a window has a size at all.** Measured against MAUI 10:
///
/// |                | width, height        | x, y      | minimum, maximum |
/// |----------------|----------------------|-----------|------------------|
/// | Windows        | yes                  | yes       | yes              |
/// | Mac Catalyst   | yes, through the host | **no**   | yes              |
/// | iOS, Android   | no                   | no        | no               |
///
/// A phone has no window to size, so nothing there is a surprise. The Mac is:
/// MAUI does not implement `Window.Width` on Catalyst - assigning it changes
/// nothing, in plain C# as much as here - so the host opens the window at that
/// size through the size restriction Catalyst DOES honour, and gives the
/// restriction back on the next turn of the run loop. The window opens where it
/// was told and the user can still resize it. See `SwiftWindowSize` on the C#
/// side for the measurements behind that.
///
/// `x` and `y` have no such route and stay a Windows property: macOS places its
/// own windows.
///
/// One more Catalyst fact, also measured: a Catalyst window is UIKit content
/// drawn at 77%, so a width of 1100 measures 847 macOS points - the same scale
/// MAUI's own `MaximumWidth` already works in. The number is in MAUI's units,
/// not the screen's.
public protocol Window: Element {
    /// What the window shows - a `NavigationPage` for an app that pushes and
    /// pops, a `TabbedPage` for tabs, a `FlyoutPage` for a menu beside the page,
    /// a `ContentPage` for one screen. MAUI: Window.Page.
    ///
    /// Named `content` rather than `page`, the one place a window's property is
    /// not MAUI's own word: it is what a `ContentPage` and a `ContentView` call
    /// the same thing, and all three are read the same way.
    ///
    /// The only thing a window must say, and read again on every render like
    /// every other part of the tree.
    var content: Page { get }

    /// WHICH window this is - the value it stands for.
    ///
    ///     var id: AnyHashable? { inspector }
    ///
    /// The identity `ForEach` gives a row, for the same reason: a window built
    /// from a value is matched by that value, so closing the middle window of
    /// three closes THAT one instead of moving the last one's page into it.
    /// A window without an id is identified by its position, which is right for
    /// a window that is always there and wrong for one made from data.
    ///
    /// Anything `Hashable` - the author's own type, the way `ForEach` does -
    /// and it never crosses the boundary as a property.
    var id: AnyHashable? { get }

    /// What the window is called - the desktop title bar, the task switcher.
    /// MAUI: Window.Title. Ignored where a platform has no window title.
    var title: String? { get }

    // MARK: - Where it is

    /// How far from the left of the screen the window opens.
    /// MAUI: Window.X. Windows only - Mac Catalyst places its own windows.
    var x: Double? { get }

    /// How far from the top. MAUI: Window.Y. Windows only.
    var y: Double? { get }

    // MARK: - How big it is

    /// How wide the window OPENS. MAUI: Window.Width. Desktop only.
    ///
    /// A starting size, not a fixed one: the user can still resize the window,
    /// within whatever minimum and maximum it was given. For a size that cannot
    /// be changed, say so - a maximum equal to the minimum.
    var width: Double? { get }

    /// How tall it opens. MAUI: Window.Height. Desktop only.
    var height: Double? { get }

    /// The width below which the window cannot be dragged.
    /// MAUI: Window.MinimumWidth. Desktop only.
    var minimumWidth: Double? { get }

    /// The height below which it cannot be dragged.
    /// MAUI: Window.MinimumHeight. Desktop only.
    var minimumHeight: Double? { get }

    /// The width beyond which the window cannot be dragged.
    /// MAUI: Window.MaximumWidth. Desktop only.
    ///
    ///     var minimumWidth: Double? { 1100 }
    ///     var maximumWidth: Double? { 1100 }
    ///
    /// is how a window is stopped from being resized at all.
    var maximumWidth: Double? { get }

    /// The height beyond which it cannot be dragged.
    /// MAUI: Window.MaximumHeight. Desktop only.
    var maximumHeight: Double? { get }

    // MARK: - What hangs off it

    /// The window's own strip of chrome, in place of the system title bar.
    /// MAUI: Window.TitleBar. Desktop only - `WindowHandler.MapTitleBar` has a
    /// body on Mac Catalyst and Windows and nowhere else, measured, so a phone
    /// ignores it.
    ///
    ///     var titleBar: TitleBar? {
    ///         device.idiom == .desktop
    ///             ? TitleBar("StateUI Gallery").subtitle("Home")
    ///             : nil
    ///     }
    ///
    /// `@Environment var device: DeviceInfo` on the application is how one is
    /// written only where it can draw - see the doc on `TitleBar`.
    var titleBar: TitleBar? { get }

    /// The pages presented OVER the window, the last of them on top.
    /// MAUI: INavigation.ModalStack.
    ///
    ///     @State private var sheets: [Sheet] = []
    ///
    ///     var modalStack: ModalStack? {
    ///         ModalStack($sheets) { sheet in
    ///             switch sheet {
    ///             case .settings: SettingsPage(sheets: $sheets)
    ///             case .about: AboutPage()
    ///             }
    ///         }
    ///     }
    ///
    /// A second arranged list beside the content, drawn over the bars and
    /// everything else. Presenting a page is `sheets.append(.settings)` and
    /// dismissing one is a `remove`; a sheet the reader drags away truncates
    /// the array itself.
    ///
    /// It belongs to the window rather than to any page, which is MAUI's own
    /// model - see `ModalStack`.
    var modalStack: ModalStack? { get }

    /// The objects this window offers to everything in it, resolved by TYPE -
    /// the same `.environment` a view offers, one level further out.
    ///
    /// This is where a DOCUMENT's context belongs when an application has one
    /// window per document: named once on the window, read by every page under
    /// it without being threaded through their initializers.
    ///
    ///     struct EditorWindow: Window {
    ///         let project: Project
    ///
    ///         var environment: [AnyObject] { [project.context] }
    ///         var content: Page { EditorPage() }
    ///     }
    ///
    ///     struct EditorPage: ContentPage {
    ///         @Environment private var context: ProjectContext
    ///
    ///         var content: Element { Label(context.documentName) }
    ///     }
    ///
    /// A nearer `.environment()` of the same type overrides for its own branch,
    /// so a view inside may still replace what the window offered. Nothing about
    /// it crosses the boundary; see Core/Environment.swift.
    ///
    /// Each object answers for ITS OWN class, the one it was made as. A reader
    /// asking for a base class is answered by `.environment()` written inside
    /// the page instead, that one keying on the type it was WRITTEN as.
    var environment: [AnyObject] { get }

    // MARK: - Its lifetime
    //
    // For an application with one window - which is most of them - the window's
    // lifetime IS the application's: MAUI's own Application.OnStart, OnSleep and
    // OnResume are the same three moments - created, stopped, resumed - said on
    // the Application class, where they are protected virtuals on the app's own
    // App subclass and nothing outside it can hear them. The window's public
    // events are the same lifecycle told where a subscription can listen, which
    // is why MAUI's documentation points at them too. Where there are SEVERAL
    // windows each one says its own, and `onDestroying` is how the one the user
    // closed reaches the state that opened it - see `windows` on Application.
    //
    // These reach a `StateUIWindow`. A `StateUIHost` borrows a window the C#
    // application owns, and that application already has these events in C# - so
    // there they say nothing.

    /// Runs when the platform window has been created - once, before anything is
    /// shown. MAUI: Window.Created, and the application's `OnStart` moment.
    var onCreated: EventHandler? { get }

    /// Runs when the window comes to the front - at launch after `onCreated`,
    /// and again when the app returns after `onDeactivated`.
    /// MAUI: Window.Activated.
    ///
    /// WHEN the pair fires is the platform's, measured: Android says
    /// deactivated then activated around every trip through the home screen,
    /// while Mac Catalyst raises them only around HIDING and SHOWING the app - a
    /// mere switch of focus to another app says nothing there.
    var onActivated: EventHandler? { get }

    /// Runs when the window leaves the front - on the way to the background,
    /// before `onStopped`. MAUI: Window.Deactivated. See `onActivated` for which
    /// moments each platform counts.
    var onDeactivated: EventHandler? { get }

    /// Runs when the window is no longer visible - the application's `OnSleep`
    /// moment, and the place to save: nothing promises the process comes back.
    /// MAUI: Window.Stopped.
    var onStopped: EventHandler? { get }

    /// Runs when the window returns after `onStopped` - the application's
    /// `OnResume` moment. Not at launch: a window that was never stopped resumes
    /// nothing, and `onCreated` and `onActivated` say that.
    /// MAUI: Window.Resumed.
    var onResumed: EventHandler? { get }

    /// Runs as the window is being destroyed - the last word before the process
    /// may end. MAUI: Window.Destroying.
    ///
    /// Also the REPORT that a window has gone, whoever took it away: the
    /// platform's close button, or this side no longer describing it. An
    /// application with several windows folds it back into the state that opened
    /// them - `inspectors.removeAll { $0 == inspector }` - which is right either
    /// way round, because a removal by value is idempotent. See `windows` on
    /// Application.
    var onDestroying: EventHandler? { get }
}

// What a window says by saying nothing. Every one of these leaves the property
// out of the message entirely, so MAUI's own default stands and a window writes
// only what it wants to be different.

extension Window {
    /// Identified by its POSITION in the application's list, which is right for
    /// a window that is always there.
    public var id: AnyHashable? { nil }

    /// No title, so the platform names the window itself.
    public var title: String? { nil }

    /// Placed by the platform.
    public var x: Double? { nil }

    /// Placed by the platform.
    public var y: Double? { nil }

    /// Opened at whatever width the platform opens a window at.
    public var width: Double? { nil }

    /// Opened at whatever height the platform opens a window at.
    public var height: Double? { nil }

    /// Draggable as small as the platform allows.
    public var minimumWidth: Double? { nil }

    /// Draggable as small as the platform allows.
    public var minimumHeight: Double? { nil }

    /// Draggable as large as the platform allows.
    public var maximumWidth: Double? { nil }

    /// Draggable as large as the platform allows.
    public var maximumHeight: Double? { nil }

    /// The system's own title bar, which is what a desktop draws unasked.
    public var titleBar: TitleBar? { nil }

    /// Nothing presented over the window.
    public var modalStack: ModalStack? { nil }

    /// Nothing of its own to offer, so a page under it reads what the standard
    /// providers answer.
    public var environment: [AnyObject] { [] }

    /// Nothing to do when the window is created.
    public var onCreated: EventHandler? { nil }

    /// Nothing to do when it comes to the front.
    public var onActivated: EventHandler? { nil }

    /// Nothing to do when it leaves the front.
    public var onDeactivated: EventHandler? { nil }

    /// Nothing to do when it stops being visible.
    public var onStopped: EventHandler? { nil }

    /// Nothing to do when it comes back.
    public var onResumed: EventHandler? { nil }

    /// Nothing to do when it goes away - which an application with SEVERAL
    /// windows has to write, there being no binding to fold the closure back
    /// through. See `windows` on Application.
    public var onDestroying: EventHandler? { nil }

    /// The window as a node: its own properties, its page, and whatever hangs
    /// off it beside.
    ///
    /// A placeholder, exactly like a page's, so that a window declared as a type
    /// may hold `@State` of its own and be rebuilt on its own when that state
    /// changes - the arrangement being written here, a window is as much a place
    /// to keep things as a page is. See Core/Stateful.swift.
    ///
    /// The `id` goes on the PLACEHOLDER, which is the node the application's
    /// arranged list matches; expanding carries it through to the window.
    public var body: Node {
        var placeholder = Node.composed(self, type: String(reflecting: Self.self)) {
            var node = Node(
                type: .window, props: windowProps, children: [content.body] + windowSlots)

            node.environments = environment.map {
                (key: ObjectIdentifier(type(of: $0)), object: $0)
            }

            // Written out one by one rather than walked over a collection: the
            // wire is deterministic, and a Dictionary or a Set iterated into a
            // message differs between two instances inside one run. See
            // Core/Wire.swift.
            if let handler = onCreated { node.addHandler(.created, handler) }
            if let handler = onActivated { node.addHandler(.activated, handler) }
            if let handler = onDeactivated { node.addHandler(.deactivated, handler) }
            if let handler = onStopped { node.addHandler(.stopped, handler) }
            if let handler = onResumed { node.addHandler(.resumed, handler) }
            if let handler = onDestroying { node.addHandler(.destroying, handler) }

            // The report that a modal has GONE, which is the window's because
            // the stack is - see ModalStack.swift.
            if let stack = modalStack { node.addHandler(.modalPopped, stack.popped) }

            return node
        }

        placeholder.id = id.map { String(describing: $0) }
        return placeholder
    }

    /// The window's own properties, as the host reads them.
    ///
    /// Shared by every window so that a new kind cannot quietly support a
    /// different set - the same reason a page's are in one place.
    var windowProps: [Prop: PropValue] {
        var props: [Prop: PropValue] = [:]

        props[.title] = title.map { .string($0) }
        props[.x] = x.map { .number($0) }
        props[.y] = y.map { .number($0) }
        props[.width] = width.map { .number($0) }
        props[.height] = height.map { .number($0) }
        props[.minimumWidth] = minimumWidth.map { .number($0) }
        props[.minimumHeight] = minimumHeight.map { .number($0) }
        props[.maximumWidth] = maximumWidth.map { .number($0) }
        props[.maximumHeight] = maximumHeight.map { .number($0) }

        return props
    }

    /// What hangs off the window besides its page: the chrome and the modal
    /// stack, each as the node the host knows it by.
    ///
    /// After the content and in a fixed order, which is what makes the window's
    /// children the same list in every run - the host reads them by TYPE and
    /// never by position, so the order is this side's to settle.
    var windowSlots: [Node] {
        var slots: [Node] = []

        if let bar = titleBar { slots.append(bar.body) }
        if let stack = modalStack { slots.append(stack.node) }

        return slots
    }
}

/// A screenful of interface. MAUI: Page.
///
/// What a window shows, what a navigation stack holds, what a tab is - and it
/// asks nothing else, which is the whole of this protocol.
///
/// There are TWO KINDS, and the difference is who writes the type. A page an
/// author WRITES conforms to `ContentPage` and answers properties. A page an
/// author CONSTRUCTS is a value this library declares - `NavigationPage($path)
/// { … }`, `TabbedPage(tabs) { … }`, `FlyoutPage($open) { … }` - and a
/// constructor's result has no properties to override, so what it is told is
/// told by MODIFIER: `.title("Stack")`, from `PageElement`.
///
/// Which is why nothing is declared here. A property declared on `Page` is one
/// every CONSTRUCTED page wears without being able to answer it - a
/// `NavigationPage` carrying a `var title` that is always nil, beside the
/// `.title(_:)` that works. The sixteen a written page answers belong to
/// `ContentPage`, which can answer them.
public protocol Page: Element {}

/// A page showing a single view. MAUI: ContentPage.
///
/// The properties are requirements with defaults rather than modifiers, because
/// that is how a MAUI page is written: a page is a type you declare and
/// configure, not a value you chain onto. Every one of them is read on every
/// render, like the content itself and like every other part of the tree.
///
///     struct MainPage: ContentPage {
///         var title: String? { "Home" }
///         var content: Element { … }
///     }
///
/// A page also carries what it asks of the CONTAINER showing it, which in MAUI
/// is a set of attached properties written on the page itself:
///
///     struct DetailsPage: ContentPage {
///         var navigationPageHasNavigationBar: Bool? { false }
///         var navigationPageHasBackButton: Bool? { false }
///     }
///
/// The `navigationPage` prefix is the attached property's declaring type, the
/// same way `Grid.Row` is written `.gridRow` on a view. What the BAR looks like
/// is not here at all: it belongs to the arrangement drawing it - see
/// `barBackgroundColor` on `NavigationPage` and `TabbedPage`.
///
/// THREE of these - `title`, `iconImageSource` and `modalPresentationStyle` -
/// are what a CONSTRUCTED page needs as well, and are exactly the three
/// `PageElement` spells as modifiers: a tab reads its caption and its icon off
/// the page inside it, and that page is often a whole navigation stack. The
/// host applies those three to any page it makes and the other thirteen to a
/// content page alone, which is the same division read from the other side.
public protocol ContentPage: Page {
    /// What the page shows. One view - put a layout here for more than one.
    var content: Element { get }

    /// What the page is called. MAUI: Page.Title.
    ///
    /// The navigation bar's text while this page is on top, and the caption of
    /// the tab holding it - the same meaning `.title(_:)` carries on a page the
    /// library constructs; see `PageElement`.
    var title: String? { get }

    /// The picture that stands for the page. MAUI: Page.IconImageSource.
    ///
    ///     var iconImageSource: ImageSource? { "house.png" }
    ///
    /// A tab's icon, in practice - a `TabbedPage` draws it above or beside the
    /// caption. A page that is not shown as an item of something else has
    /// nowhere to draw it, and platforms ignore it there.
    var iconImageSource: ImageSource? { get }

    /// The space kept between the page's edge and its content.
    /// MAUI: Page.Padding.
    ///
    ///     var padding: Thickness? { Thickness(16) }
    ///
    /// A page has no margin to go with it: nothing is outside a page.
    var padding: Thickness? { get }

    /// What is drawn behind the page. MAUI: VisualElement.BackgroundColor.
    ///
    /// The PAGE's own - the bar above it is the arrangement's, and takes
    /// `barBackgroundColor` there.
    var backgroundColor: Color? { get }

    /// Whether a tap outside a focused input closes the keyboard.
    /// MAUI: ContentPage.HideSoftInputOnTapped.
    ///
    ///     var hideSoftInputOnTapped: Bool? { true }
    ///
    /// The platform's own answer to a keyboard with no way out, and the reason
    /// this library adds no tap-catching view of its own: MAUI recognizes the
    /// tap ALONGSIDE whatever else is listening, so a scroll, a button and a
    /// gesture on the page all go on working - a view laid over the content to
    /// catch touches could not promise that.
    ///
    /// It takes a TAP on the page to fire, and unfocuses whichever view the
    /// page has focused. A keyboard that has to be closed by something else -
    /// a Done button over a form of six fields - is `SoftInput.hide()`, which
    /// asks the page who holds the focus; see Core/Focus.swift.
    var hideSoftInputOnTapped: Bool? { get }

    /// Whether this page keeps its content out of the bars - the status bar,
    /// the notch, the home indicator, and on Mac Catalyst the window's title
    /// bar. MAUI: the `Page.UseSafeArea` iOS platform-specific.
    ///
    ///     struct MenuPage: ContentPage {
    ///         var useSafeArea: Bool? { false }   // a header that runs to the top
    ///     }
    ///
    /// True is the platform's own answer and what a page gets by saying
    /// nothing. FALSE is for a page whose top is a picture rather than text -
    /// a flyout's banner, a hero image - which has to reach the edge or the
    /// page's own colour shows above it in a strip.
    ///
    /// **iOS and Mac Catalyst only**, being a UIKit platform-specific; Android
    /// and Windows ignore it. It is the PAGE's inset, which is what makes it
    /// different from `.safeAreaEdges()` on a layout: measured on Catalyst, a
    /// layout saying `.none` still began below the title bar, because the page
    /// under it had already taken the inset out of the room it was given.
    var useSafeArea: Bool? { get }

    /// How the page covers the screen when it is PRESENTED over the window -
    /// a sheet, a card, the whole screen.
    /// MAUI: the `Page.ModalPresentationStyle` platform-specific.
    ///
    ///     struct SettingsPage: ContentPage {
    ///         var modalPresentationStyle: UIModalPresentationStyle? { .pageSheet }
    ///     }
    ///
    /// **iOS and Mac Catalyst only.** UIKit is the only platform with a choice
    /// here; Android and Windows present every modal page over the whole
    /// window. See `Window.modalStack`, which is what presents one, and
    /// `UIModalPresentationStyle` for what each style draws.
    ///
    /// It says nothing about a page reached any other way: a page pushed onto a
    /// navigation stack or shown as a tab is not presented, and ignores it.
    var modalPresentationStyle: UIModalPresentationStyle? { get }

    // What this page asks of the NAVIGATION STACK it is on. Attached
    // properties, so each carries the class that declares it -
    // `NavigationPage.HasNavigationBar` is `navigationPageHasNavigationBar`.
    // The colours of the BAR belong to the NavigationPage rather than to a
    // page on it - see `barBackgroundColor` in Views/NavigationPage.swift.

    /// Whether the navigation bar is shown while this page is on top.
    /// MAUI: NavigationPage.HasNavigationBar.
    ///
    ///     struct SplashPage: ContentPage {
    ///         var navigationPageHasNavigationBar: Bool? { false }
    ///     }
    var navigationPageHasNavigationBar: Bool? { get }

    /// Whether the way back is offered while this page is on top - false for a
    /// page the reader must finish rather than leave.
    /// MAUI: NavigationPage.HasBackButton.
    ///
    /// It hides the BUTTON, and iOS's swipe-back with it. Android's system
    /// back is the platform's and goes on working, so a page that must not be
    /// left cannot be built out of this alone.
    var navigationPageHasBackButton: Bool? { get }

    /// What the back button reads while the page ABOVE this one is on top.
    /// MAUI: NavigationPage.BackButtonTitle.
    ///
    /// Written on the page the reader would go BACK TO, never on the one they
    /// are looking at: iOS draws the title of the page underneath on the back
    /// button, and this is how that page says something shorter. Android and
    /// Windows draw an arrow with nowhere to put words, and ignore it.
    var navigationPageBackButtonTitle: String? { get }

    /// A small picture beside the title on the bar.
    /// MAUI: NavigationPage.TitleIconImageSource.
    var navigationPageTitleIconImageSource: ImageSource? { get }

    /// The colour of the back arrow on the bar.
    /// MAUI: NavigationPage.IconColor - `barTextColor` on the NavigationPage
    /// paints the title and the arrow together, and this overrides the arrow.
    var navigationPageIconColor: Color? { get }

    /// A view on the bar, in place of the title.
    /// MAUI: NavigationPage.TitleView.
    ///
    /// A view rather than a handler: whatever is written here is an ordinary
    /// part of the tree, reading the same state the content reads. The bar is
    /// simply where it is placed.
    var navigationPageTitleView: Element? { get }

    /// The buttons in the page's navigation bar. MAUI: Page.ToolbarItems.
    ///
    ///     var toolbarItems: [ToolbarItem] {
    ///         [
    ///             ToolbarItem("Add").onClicked { items.append(Item()) },
    ///             ToolbarItem("Sort").order(.secondary),
    ///         ]
    ///     }
    ///
    /// Read on every render like everything else, so what the bar offers can
    /// depend on the page's state.
    var toolbarItems: [ToolbarItem] { get }

    /// The menus on the desktop menu bar while this page is showing.
    /// MAUI: Page.MenuBarItems - which a phone has nowhere to put and shows
    /// none of, in MAUI as here.
    ///
    ///     var menuBarItems: [MenuBarItem] {
    ///         [
    ///             MenuBarItem("File") {
    ///                 MenuFlyoutItem("New").onClicked { documents.append(Document()) }
    ///             }
    ///         ]
    ///     }
    var menuBarItems: [MenuBarItem] { get }

    // The page's own two events. A window has six of these and they are
    // written the same way - a defaulted property answering a handler, added
    // to the node where the window's are.

    /// The page is about to be shown. MAUI: Page.Appearing.
    ///
    ///     struct FeedPage: ContentPage {
    ///         @State private var items: [Item] = []
    ///
    ///         var onAppearing: EventHandler? {
    ///             { items = try await load() }
    ///         }
    ///     }
    ///
    /// It runs on every arrival, not only the first: coming back from a pushed
    /// page raises it again, which is what makes it the place to refresh
    /// something that may have changed while the page was covered. A page that
    /// wants the FIRST time only keeps a `@State` flag of its own.
    ///
    /// It does not fire for the page a message is describing for the very first
    /// time - the platform raises that one while the message is still being
    /// applied, and a report from inside an apply is dropped, the rule every
    /// report here follows. The page's `content` is built at that moment
    /// anyway, so anything that must happen before the first draw belongs in
    /// the state that content reads.
    var onAppearing: EventHandler? { get }

    /// The page has been covered or left. MAUI: Page.Disappearing.
    ///
    /// The mirror of `onAppearing`, and it runs whether the reader went
    /// forward, went back, or switched to another tab.
    var onDisappearing: EventHandler? { get }

    /// A move has ARRIVED at this page. MAUI: Page.NavigatedTo.
    ///
    /// The difference from `onAppearing` is what raises it: this one is about
    /// NAVIGATION and nothing else, while appearing also answers the page
    /// coming back on screen for a reason that was never a move - the
    /// application waking, a tab bar rebuilding. A page that means "the reader
    /// came here" wants this one.
    var onNavigatedTo: EventHandler? { get }

    /// A move is ABOUT to leave this page. MAUI: Page.NavigatingFrom.
    ///
    /// The page is still the one on screen, which is what makes it the place to
    /// put away what the move must not carry: a running clock, a half-typed
    /// draft worth keeping.
    var onNavigatingFrom: EventHandler? { get }

    /// A move HAS left this page. MAUI: Page.NavigatedFrom.
    ///
    /// The other side of `onNavigatingFrom`: by now the destination is on
    /// screen, so this is where anything that had to wait for the move to
    /// finish belongs.
    var onNavigatedFrom: EventHandler? { get }
}

// What a page says by saying nothing. Every one of these is nil, which means the
// property is not sent at all - so MAUI's own default stands, and a page writes
// only what it wants to be different.

extension ContentPage {
    /// No title, so a bar shows nothing and a tab falls back to its own.
    public var title: String? { nil }

    /// No picture, so a tab shows its caption alone.
    public var iconImageSource: ImageSource? { nil }

    /// No padding, so the content runs to the page's edges.
    public var padding: Thickness? { nil }

    /// No background of its own, so the platform's page colour stands.
    public var backgroundColor: Color? { nil }

    /// Taps as the platform has them, which on both is a keyboard that stays up
    /// until something takes the focus away.
    public var hideSoftInputOnTapped: Bool? { nil }

    /// Nothing to run when the page arrives.
    public var onAppearing: EventHandler? { nil }

    /// Nothing to run when it leaves.
    public var onDisappearing: EventHandler? { nil }

    /// Nothing to run when a move arrives here.
    public var onNavigatedTo: EventHandler? { nil }

    /// Nothing to run as a move begins to leave.
    public var onNavigatingFrom: EventHandler? { nil }

    /// Nothing to run once a move has left.
    public var onNavigatedFrom: EventHandler? { nil }

    /// The platform's own answer, which is to inset.
    public var useSafeArea: Bool? { nil }

    /// Presented the way the platform presents a page, which everywhere is over
    /// the whole window.
    public var modalPresentationStyle: UIModalPresentationStyle? { nil }

    /// The navigation bar as the stack has it, which is shown.
    public var navigationPageHasNavigationBar: Bool? { nil }

    /// The way back as the stack has it, which is offered.
    public var navigationPageHasBackButton: Bool? { nil }

    /// The back button reads what iOS would put there by itself.
    public var navigationPageBackButtonTitle: String? { nil }

    /// No picture beside the title.
    public var navigationPageTitleIconImageSource: ImageSource? { nil }

    /// The back arrow as `barTextColor` painted it.
    public var navigationPageIconColor: Color? { nil }

    /// No view on the bar, so it shows the title.
    public var navigationPageTitleView: Element? { nil }

    /// Nothing in the navigation bar but the title.
    public var toolbarItems: [ToolbarItem] { [] }

    /// No menus of its own.
    public var menuBarItems: [MenuBarItem] { [] }

    /// The page's own properties, as the host reads them.
    ///
    /// Shared by every kind of page so that a new one - a ContentPage today,
    /// something else later - cannot quietly support a different set.
    var pageProps: [Prop: PropValue] {
        var props: [Prop: PropValue] = [:]

        props[.title] = title.map { .string($0) }
        props[.iconImageSource] = iconImageSource?.propValue
        props[.padding] = padding?.propValue
        props[.backgroundColor] = backgroundColor?.propValue
        props[.hideSoftInputOnTapped] = hideSoftInputOnTapped.map { .bool($0) }
        props[.useSafeArea] = useSafeArea.map { .bool($0) }
        props[.modalPresentationStyle] = modalPresentationStyle?.propValue


        props[.navigationPageHasNavigationBar] = navigationPageHasNavigationBar.map { .bool($0) }
        props[.navigationPageHasBackButton] = navigationPageHasBackButton.map { .bool($0) }
        props[.navigationPageBackButtonTitle] = navigationPageBackButtonTitle.map { .string($0) }
        props[.navigationPageTitleIconImageSource] = navigationPageTitleIconImageSource?.propValue
        props[.navigationPageIconColor] = navigationPageIconColor?.propValue

        return props
    }

    /// What hangs off the page besides its content: the title view, the
    /// toolbar items and the menu bar items, each as the node the host knows
    /// it by.
    var pageSlots: [Node] {
        var slots: [Node] = []

        if let titleView = navigationPageTitleView {
            slots.append(Node(type: .navigationPageTitleView, children: [titleView.body]))
        }

        // Collections rather than one node each, for the reason a SwipeView's
        // items are: the host has a list to keep in step, and a list needs
        // somewhere of its own to be matched against.
        if !toolbarItems.isEmpty {
            slots.append(Node(type: .toolbarItems, children: toolbarItems.map { $0.body }))
        }

        if !menuBarItems.isEmpty {
            slots.append(Node(type: .menuBarItems, children: menuBarItems.map { $0.body }))
        }

        return slots
    }

    /// The page as a node: its properties, its content, and whatever hangs off
    /// it besides.
    ///
    /// A placeholder, like ContentView's, and for one reason more: a page's
    /// title view and toolbar items hang BESIDE its content and read the same
    /// state, so they too have to be built after the differ has decided whose
    /// state that is. See Core/Stateful.swift.
    public var body: Node {
        Node.composed(self, type: String(reflecting: Self.self)) {
            // The content first, so a page that gained a title view does not
            // look to the differ as though its content moved.
            var node = Node(
                type: .contentPage, props: pageProps, children: [content.body] + pageSlots)

            // One by one rather than over a collection, the window's rule: the
            // wire is deterministic and nothing may iterate a Dictionary into a
            // message.
            if let handler = onAppearing { node.addHandler(.appearing, handler) }
            if let handler = onDisappearing { node.addHandler(.disappearing, handler) }
            if let handler = onNavigatedTo { node.addHandler(.navigatedTo, handler) }
            if let handler = onNavigatingFrom { node.addHandler(.navigatingFrom, handler) }
            if let handler = onNavigatedFrom { node.addHandler(.navigatedFrom, handler) }

            return node
        }
    }
}

/// Names the application to the host. MAUI: `builder.UseMauiApp<App>()`.
///
/// The one line an app writes outside its own interface, and it goes in the
/// function the host calls by name at startup:
///
///     @_cdecl("stateui_app_register")
///     public func stateui_app_register() {
///         stateUIUseApp(HelloWorldApp())
///     }
///
/// That function lives in the APP's module and cannot move into this library:
/// on Android and Windows the app is a separate native library, and nothing in
/// it runs until something calls into it by name.
///
/// - Parameter application: the application, kept for as long as the process
///   lives - so `@State` declared on it is the state that outlives every
///   window.
public func stateUIUseApp(_ application: Application) {
    Renderer.shared.setApplication(application)
}

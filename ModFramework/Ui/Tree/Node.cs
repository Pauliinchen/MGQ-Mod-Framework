//----------------------------------------------------------------
//  Node.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Added whether a part keeps the sides it measured in proportion, its height following its width
//                            - Added the part of a part's padding that gives way at its largest size, and what gave way of it
//                            - Added the named column a root stacks in, and whether a root that hides there keeps its place
//                            - Added the room kept around a part, outside its size
//                            - Added a column in the middle of its room at its most width, and the widths it picks from
//                            - Kept the part a root first opened on as its home
//                            - Took how many tabs a row of tabs shows
//      Paulinchen  2026-11-07: Told whether the scripts show a part, whatever form its root's step picks
//                            - Added the items dragged between drop zones, the zones and the container they share
//                            - Added a child that lies over its parent's top right corner, such as a badge
//                            - Added the columns of a grid a child spans
//                            - Added the slider, a number picked between its bounds by LEFT and RIGHT or the pointer, with its
//                              track and the cells of a rating
//                            - Removed the rows that line their columns up, which no script sends
//                            - Added the copies of a part that its root picks the step of its compact forms for
//                            - Added the compact forms of a part and the step of its root that picks them
//                            - Used the bridge and the runtime under the framework's namespace
//                            - Added the component that handed the focus to a list
//                            - Kept the component the focus came from on every component, not only on a list
//      Paulinchen  2026-11-06: Took out the right click as cancel of a root of today's UI, which no root asks for any more
//                            - Removed the number field set digit by digit, which a numeric field replaces
//                            - Added the lists whose paging scrolls the box beside them
//                            - Typed a number field as a numeric field types, and took out its calculator start
//                            - Took out the row of tabs as one key stop, which no screen uses any more
//                            - Added a root joined to a game window, which takes the focus only when that window hands it over
//      Paulinchen  2026-11-05: Added the lists that show a page of their rows at a time
//                            - Added a part the keys reach only by an arrow with the jump key, such as a table's column title
//                            - Added the numeric field, a number typed as a text field types or stepped within its bounds
//                            - Added the group of each row of a list that the move hotkeys keep a row within, and whether
//                              a list takes the move hotkeys
//                            - Added a part that waits for the key the player presses to bind a hotkey, with the keys other
//                              hotkeys have
//      Paulinchen  2026-11-04: Added the zone a root stacks in or lies alone at, the edge it docks along, the part it
//                              lies beside, its mod's load order, whether it gives room in a full zone and whether it
//                              hides for want of room, and how a root beside a part lines up with it
//                            - Let a text field rest without typing while it keeps the focus
//                            - Added the parts that take the submit of a list inside them
//                            - Added the parts with a context menu, and the roots that take a right click as cancel
//                            - Added the game's extra buttons a part takes, and those a root opened under
//                            - Let the scripts leave unset whether a list's cursor follows the pointer and goes round
//                            - Added the component the focus came from into a page or a text field
//                            - Added roots of the new UI layer and the roots that hold the game's buttons, which take the focus
//                              and Tab as they open, the parts that take the window's page step, the hotkey a part
//                              declares, none for an empty name, and the roots whose pad shoulders only step tabs
//                            - Let the scripts leave unset whether tabs step by Tab and the pad's shoulders
//                            - Worked out whether a component takes the focus and the keys from what it is, unless the
//                              scripts set it: whether it has an action, repeats a key or is set aside for the pointer
//                            - Added the component the focus starts on as its root opens
//                            - Noted the roots whose components changed since their last layout, and where each root was
//                              placed and laid out last
//                            - Took the good properties of a set and told the refused ones apart
//      Paulinchen  2026-11-01: Added tabs that are one key stop above their pages, and the pages of tabs
//                            - Added boxes that keep the focus at their ends
//                            - Added where the box of each of a list's rows ends, which a click picks the row by
//                            - Added whether digits typed into a number field shift in until a digit is picked
//                            - Added lists a click on any row picks at once
//                            - Added text fields told that a cancel key left them
//      Paulinchen  2026-10-31: Added the characters a text field types of the keys bound to the game's buttons
//                            - Added the tick a root opened in and the game's buttons held as it opened
//                            - Added roots that close on a click outside them and roots whose buttons are quiet under
//                              another root that holds the game's buttons, and components that take a click
//                            - Added roots docked at a corner of the screen and roots the pointer passes through but for
//                              their parts
//                            - Added labels that keep at most a number of lines, or as many as their room holds
//                            - Added the toggles of a list's rows and lists whose cursor goes round at their ends
//                            - Added containers clicked as one part, containers the keys stop on as a whole first,
//                              columns that keep their newest parts, grids that fit their columns and tabs the arrows
//                              step
//                            - Added keys a text field claims only with Alt held, and text fields typed into only once
//                              confirmed
//                            - Added the number field, a number set digit by digit
//                            - Added components that take the mouse wheel themselves
//      Paulinchen  2026-10-30: Added the rows of a list that have a value
//                            - Added lists of columns and text fields that hand the focus on past their sides, and the
//                              text field that steers a list
//                            - Added roots told an arrow that found nothing to move the focus to
//                            - Added lists that hand LEFT and RIGHT to the scripts
//                            - Added the heading rows of a list
//                            - Added lists that hand the focus on past their first and last line
//                            - Added lists whose rows the player moves
//      Paulinchen  2026-10-29: Added components that keep the height of their tallest content and take at most a share
//                              of their column
//                            - Added lists that show their rows in columns
//                            - Added lists of whole rows, columns whose rows line up, the component cancel moves the
//                              focus to, a slides that cancel moves back and the key a focus is kept by
//                            - Added the game window a mod puts components on
//                            - Added slides, drawn shifts, inert components, shrinking children, tabs stepped by
//                              the shoulder buttons and roots that ask before cancel closes them
//                            - Added a list whose cursor stays put under the pointer and a component whose click plays no sound
//                            - Added a list the shoulder buttons do not page
//                            - Let the scripts scroll a box
//                            - Added components the keys never reach, one key stop that steps through its places
//                              and tabs that Tab and a gamepad's shoulder buttons step
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Ui.Layout;

namespace MGQParadox.ModFramework.Ui.Tree;

/// <summary>
/// What a component is, as the scripts name it in the tree's "add"; it sets the defaults of the
/// properties that decide its input.
/// </summary>
internal enum NodeKind
{
    /// <summary>A root with the game's window frame, which takes Tab and closes on cancel.</summary>
    Window,

    /// <summary>A modal window above the others.</summary>
    Dialog,

    /// <summary>A panel, floating when it is a root.</summary>
    Box,

    /// <summary>A field typed into, floating when it is a root.</summary>
    TextField,

    /// <summary>The text shown when the pointer rests, which never takes the pointer.</summary>
    Tooltip,

    /// <summary>A plain container in a column or a row.</summary>
    Stack,

    /// <summary>A plain container in a grid.</summary>
    Grid,

    /// <summary>A row of tabs over their pages.</summary>
    Tabs,

    /// <summary>A text.</summary>
    Label,

    /// <summary>An icon.</summary>
    Icon,

    /// <summary>An image.</summary>
    Picture,

    /// <summary>A text button.</summary>
    Button,

    /// <summary>An icon alone as a button.</summary>
    IconButton,

    /// <summary>A box with a label, or a switch.</summary>
    Checkbox,

    /// <summary>A value picked from a few.</summary>
    Select,

    /// <summary>Rows with a cursor.</summary>
    List,

    /// <summary>A bar.</summary>
    Gauge,

    /// <summary>A line.</summary>
    Divider,

    /// <summary>Name and value rows.</summary>
    Stats,

    /// <summary>A strip of equal pages, a few of them in view.</summary>
    Slides,

    /// <summary>A modder's own component.</summary>
    Custom,

    /// <summary>A number typed as a text field types, or stepped within its bounds, as MudBlazor's numeric field.</summary>
    NumericField,

    /// <summary>
    /// A number picked between its bounds by LEFT and RIGHT or the pointer, as MudBlazor's slider, or
    /// with cells as MudBlazor's rating.
    /// </summary>
    Slider,

    /// <summary>
    /// A game window a mod puts components on, as a root that takes the pointer only where they lie
    /// and the keys only in its text fields, since the game window under it reads them.
    /// </summary>
    Adopted,
}

/// <summary>
/// How a container places its children.
/// </summary>
internal enum FlowLayout
{
    /// <summary>One under the other.</summary>
    Column,

    /// <summary>Side by side.</summary>
    Row,

    /// <summary>In columns, filled row by row.</summary>
    Grid,

    /// <summary>Each at its own place.</summary>
    Absolute,
}

/// <summary>
/// Where a stack puts its children along itself when they leave room over.
/// </summary>
internal enum FlowJustify
{
    /// <summary>At its start.</summary>
    Start,

    /// <summary>In its middle.</summary>
    Center,

    /// <summary>At its end.</summary>
    End,

    /// <summary>The room shared out between them.</summary>
    Between,
}

/// <summary>
/// Where a child sits across its parent's stack.
/// </summary>
internal enum FlowAlign
{
    /// <summary>At the start.</summary>
    Start,

    /// <summary>In the middle.</summary>
    Center,

    /// <summary>At the end.</summary>
    End,

    /// <summary>Over the whole breadth.</summary>
    Stretch,
}

/// <summary>
/// The room kept inside a component's edges.
/// </summary>
/// <param name="Top">Above.</param>
/// <param name="Right">At the right.</param>
/// <param name="Bottom">Below.</param>
/// <param name="Left">At the left.</param>
internal readonly record struct Insets(int Top, int Right, int Bottom, int Left)
{
    /// <summary>Gets the room at the left and the right together.</summary>
    public int Horizontal => Left + Right;

    /// <summary>Gets the room above and below together.</summary>
    public int Vertical => Top + Bottom;

    /// <summary>
    /// Takes the room off a place.
    /// </summary>
    /// <param name="rect">The place.</param>
    /// <returns>What is left inside, never less than nothing.</returns>
    public LayoutRect Inside(LayoutRect rect) =>
        new(rect.X + Left, rect.Y + Top, System.Math.Max(rect.Width - Horizontal, 0), System.Math.Max(rect.Height - Vertical, 0));
}

/// <summary>
/// A component of the scripts as the tree knows it: what lays it out and what decides its input,
/// never what it draws, with the place the layout gave it and its input's state.
/// </summary>
internal sealed class Node
{
    /// <summary>
    /// The line or row height of a component that names none, the game's line height.
    /// </summary>
    public const int DefaultRowHeight = 24;

    /// <summary>
    /// Where its scrolling starts, see <see cref="ScrollTop"/>.
    /// </summary>
    private int _scrollTop;

    /// <summary>
    /// Whether its kind takes the focus, as long as it has an action and repeats no key.
    /// </summary>
    private readonly bool _kindTakesFocus;

    /// <summary>
    /// Whether it takes the focus as the scripts set it, null to work it out, see <see cref="Focusable"/>.
    /// </summary>
    private bool? _focusable;

    /// <summary>
    /// Whether the keys never reach it as the scripts set it, null to work it out, see <see cref="PointerOnly"/>.
    /// </summary>
    private bool? _pointerOnly;

    /// <summary>
    /// Whether the scripts show it, see <see cref="Visible"/>.
    /// </summary>
    private bool _visible = true;

    /// <summary>
    /// Creates a node with its kind's defaults.
    /// </summary>
    /// <param name="id">The component's id.</param>
    /// <param name="kind">What it is.</param>
    public Node(int id, NodeKind kind)
    {
        Id = id;
        Kind = kind;
        _kindTakesFocus = kind is NodeKind.Button or NodeKind.IconButton or NodeKind.Checkbox or NodeKind.Select or NodeKind.List or NodeKind.TextField or NodeKind.NumericField or NodeKind.Slider;
        Closable = kind is NodeKind.Window or NodeKind.Dialog;
        Modal = kind == NodeKind.Dialog;
        Mouse = kind != NodeKind.Tooltip;
        Z = kind switch
        {
            NodeKind.Window => 200,
            NodeKind.Dialog => 1040,
            NodeKind.Tooltip => 1100,
            _ => 1000,
        };
    }

    /// <summary>Gets the component's id.</summary>
    public int Id { get; }

    /// <summary>Gets what it is.</summary>
    public NodeKind Kind { get; }

    /// <summary>Gets or sets its parent, null for a root.</summary>
    public Node? Parent { get; set; }

    /// <summary>Gets its children in their order.</summary>
    public List<Node> Children { get; } = [];

    /// <summary>Gets whether it is a root.</summary>
    public bool IsRoot => Parent is null;

    /// <summary>Gets whether Tab moves the focus inside it, as a root.</summary>
    public bool TakesTab => Kind is NodeKind.Window or NodeKind.Dialog || (Layer && Captures);

    /// <summary>Gets whether it gives the focus to its first focusable component when it opens.</summary>
    public bool FocusesOnOpen => !Joined && (Kind is NodeKind.Window or NodeKind.Dialog || (Layer && Captures));

    /// <summary>
    /// Gets whether a root shares one cursor with a game window beside it, which hands it the focus;
    /// it never takes the focus by itself as it opens or as another root closes.
    /// </summary>
    public bool Joined { get; private set; }

    /// <summary>
    /// Gets whether a root is drawn through the UI layer, whose keys follow the rules the tree
    /// works out from what it holds wherever the engine sets nothing else.
    /// </summary>
    public bool Layer { get; private set; }

    /// <summary>Gets whether a root holds the game's buttons while it is open.</summary>
    public bool Captures { get; private set; }

    /// <summary>Gets whether it takes the window's page step, as a part with on_page.</summary>
    public bool Pages { get; private set; }

    /// <summary>
    /// Gets the hotkey it declares, a hotkey's name: a root closes by it, any other part is pressed;
    /// null for none.
    /// </summary>
    public string? Hotkey { get; private set; }

    /// <summary>
    /// Gets the game's extra buttons a part takes, as an on_button: of the UI layer; a press of one
    /// goes to the nearest part from the focus upward that takes it.
    /// </summary>
    public IReadOnlySet<UiExtraButton> ExtraButtons { get; private set; } = new HashSet<UiExtraButton>();

    /// <summary>
    /// Gets whether a part takes the submit of a list: false sends a list's submit up to the nearest
    /// part around it that takes it, null while the scripts leave it to the list itself.
    /// </summary>
    public bool? TakesSubmit { get; private set; }

    /// <summary>
    /// Gets whether a part has a context menu, which a right click, the Menu key or a held confirm on
    /// a gamepad opens.
    /// </summary>
    public bool ContextMenu { get; private set; }

    /// <summary>Gets whether a root's pad shoulders only step tabs, never its page or a list.</summary>
    public bool ShouldersStepTabsOnly { get; private set; }

    /// <summary>Gets how it places its children.</summary>
    public FlowLayout Layout { get; private set; }

    /// <summary>Gets the pixels between its children.</summary>
    public int Gap { get; private set; }

    /// <summary>Gets the room inside its edges.</summary>
    public Insets Padding { get; private set; }

    /// <summary>
    /// Gets the part of each side of its padding that gives way, before what it holds narrows, once
    /// it reaches its most size or the room it gets.
    /// </summary>
    public Insets PaddingGives { get; private set; }

    /// <summary>Gets or sets how much of each side of its padding gave way at its place after the last layout.</summary>
    public Insets PaddingCut { get; set; }

    /// <summary>Gets the room inside its edges at its place: its padding less what gave way of it.</summary>
    public Insets Room => new(Padding.Top - PaddingCut.Top, Padding.Right - PaddingCut.Right, Padding.Bottom - PaddingCut.Bottom, Padding.Left - PaddingCut.Left);

    /// <summary>Gets the room kept around it, outside its size, where nothing of it draws or takes a click.</summary>
    public Insets Margin { get; private set; }

    /// <summary>
    /// Gets whether it takes a column's width up to its most width and stands in the middle of what
    /// is left, as a container does.
    /// </summary>
    public bool Centered { get; private set; }

    /// <summary>
    /// Gets the widths a centered part picks from, from the narrowest: the largest that fits its room,
    /// and as its own width the narrowest that holds what it holds; null for none.
    /// </summary>
    public int[]? Widths { get; private set; }

    /// <summary>Gets where its children go along it when they leave room over.</summary>
    public FlowJustify Justify { get; private set; }

    /// <summary>Gets whether its text wraps, or its row starts a new line when it runs out of room.</summary>
    public bool Wrap { get; private set; }

    /// <summary>Gets its grid's column widths, null for one that shares the room left.</summary>
    public int?[] Columns { get; private set; } = [null];

    /// <summary>Gets where it sits across its parent's stack.</summary>
    public FlowAlign Align { get; private set; } = FlowAlign.Stretch;

    /// <summary>Gets its share of the room its parent's stack leaves over.</summary>
    public int Grow { get; private set; }

    /// <summary>Gets how many of its parent grid's columns it spans, at least one.</summary>
    public int Span { get; private set; } = 1;

    /// <summary>
    /// Gets whether it lies over its parent's top right corner, taking no room of its parent's
    /// layout, such as a badge over a button.
    /// </summary>
    public bool Corner { get; private set; }

    /// <summary>Gets its fixed width, null to fit what it holds.</summary>
    public int? FixedWidth { get; private set; }

    /// <summary>Gets its fixed height, null to fit what it holds.</summary>
    public int? FixedHeight { get; private set; }

    /// <summary>Gets its least width.</summary>
    public int MinWidth { get; private set; }

    /// <summary>Gets its least height.</summary>
    public int MinHeight { get; private set; }

    /// <summary>Gets its most width, null for no bound but the screen's.</summary>
    public int? MaxWidth { get; private set; }

    /// <summary>Gets its most height, null for no bound but the screen's.</summary>
    public int? MaxHeight { get; private set; }

    /// <summary>Gets its place: on the screen for a root, in its parent's content when the parent places children absolutely.</summary>
    public (int X, int Y)? At { get; private set; }

    /// <summary>Gets whether a root sits in the middle of the screen.</summary>
    public bool Center { get; private set; }

    /// <summary>
    /// Gets whether it is shown: the scripts show it, it is the form its root's step picks, and as a
    /// part's forms it holds a form shown.
    /// </summary>
    /// <remarks>A part whose picked form is hidden takes no gap in its stack, as a hidden part takes none.</remarks>
    public bool Visible => _visible && FormShown && ((FormSteps is null && !Measures) || Children.Exists(child => child.Visible));

    /// <summary>Gets whether the scripts show it, whatever form its root's step picks.</summary>
    public bool ShownByScripts => _visible;

    /// <summary>
    /// Gets whether it holds a part and copies of it that the scripts hide, which its root picks the
    /// step of its compact forms for as for the tallest of them.
    /// </summary>
    public bool Measures { get; private set; }

    /// <summary>Gets or sets the child that stands for a part with copies as its root measures it, 0 for the part itself.</summary>
    public int CopyMeasured { get; set; }

    /// <summary>
    /// Gets the step from which each child shows as a part's forms: the first 0 for the part itself,
    /// then its compact forms; null for no forms.
    /// </summary>
    public int[]? FormSteps { get; private set; }

    /// <summary>Gets or sets whether it is the form its root's step picks, true for no form.</summary>
    public bool FormShown { get; set; } = true;

    /// <summary>Gets or sets the step a root picked the compact forms by, kept while its size stays the same.</summary>
    public int FoldStep { get; set; }

    /// <summary>Gets or sets the size a root picked its step at, null before it.</summary>
    public (int Width, int Height)? FoldSize { get; set; }

    /// <summary>Gets whether it takes input.</summary>
    public bool Enabled { get; private set; } = true;

    /// <summary>
    /// Gets whether it is drawn but takes neither the pointer nor the focus, with what it holds, as a
    /// page sliding out of view.
    /// </summary>
    public bool Inert { get; private set; }

    /// <summary>
    /// Gets how far it is drawn from its place, with what it holds; the pointer hits it where it is drawn.
    /// </summary>
    public (int X, int Y) Offset { get; private set; }

    /// <summary>Gets whether it gives room back when its row or column runs out, though it does not grow.</summary>
    public bool Shrinks { get; private set; }

    /// <summary>Gets how many pages a slides shows side by side.</summary>
    public int PagesShown { get; private set; } = 1;

    /// <summary>Gets whether LEFT and RIGHT that find nothing to focus inside a slides move it a page.</summary>
    public bool SlideKeys { get; private set; }

    /// <summary>Gets whether a row of tabs steps by the game's L and R while the focus is in its root.</summary>
    public bool Shoulder { get; private set; }

    /// <summary>
    /// Gets whether a row of tabs steps by Tab and Shift+Tab while the focus is in its root, null
    /// while the scripts leave it to the root's rules.
    /// </summary>
    public bool? TabKey { get; private set; }

    /// <summary>
    /// Gets whether a row of tabs steps by a gamepad's R and L, not the keyboard's keys of the game's
    /// L and R, while the focus is in its root, null while the scripts leave it to the root's rules.
    /// </summary>
    public bool? PadShoulders { get; private set; }

    /// <summary>
    /// Gets how many tabs a row of tabs shows, null while the scripts do not tell.
    /// </summary>
    public int? TabsShown { get; private set; }

    /// <summary>
    /// Gets whether it is the page of a tab, apart from the other parts its tabs hold.
    /// </summary>
    public bool TabPage { get; private set; }

    /// <summary>
    /// Gets whether the keys never reach it or what it holds, while the pointer still does: as the
    /// scripts set it, else while it is set aside for the pointer.
    /// </summary>
    public bool PointerOnly => _pointerOnly ?? Aside;

    /// <summary>
    /// Gets whether it is set aside for the pointer, as the summary beside a list that only the
    /// mouse uses.
    /// </summary>
    public bool Aside { get; private set; }

    /// <summary>
    /// Gets whether it has an action or a bind; a component the scripts tell nothing of counts as
    /// having one.
    /// </summary>
    public bool Acts { get; private set; } = true;

    /// <summary>
    /// Gets whether its press only repeats a key, as a button that closes its root or slides back,
    /// so the keys pass over it.
    /// </summary>
    public bool Repeats { get; private set; }

    /// <summary>Gets whether the focus starts on it as its root opens.</summary>
    public bool Autofocus { get; private set; }

    /// <summary>
    /// Gets whether the keys reach it only by an arrow with the jump key held, or from a part like it,
    /// such as a table's column title: the focus never starts on it and a plain arrow passes over it.
    /// </summary>
    public bool JumpOnly { get; private set; }

    /// <summary>
    /// Gets whether it is one key stop whose LEFT and RIGHT move its cursor through its rows, such as
    /// a row of slots.
    /// </summary>
    public bool Steps { get; private set; }

    /// <summary>Gets whether a root asks the scripts before cancel closes it, instead of closing.</summary>
    public bool GuardsCancel { get; private set; }

    /// <summary>Gets whether a root is told an arrow that found no component of it to move the focus to.</summary>
    public bool TellsLeave { get; private set; }

    /// <summary>
    /// Gets whether it keeps, in a column, the height of the tallest content it held since the
    /// scripts last set it steady, so what lies beside it never moves as its content changes.
    /// </summary>
    public bool Steady { get; private set; }

    /// <summary>Gets or sets the height of the tallest content a steady component held, 0 for none yet.</summary>
    public int SteadyHeight { get; set; }

    /// <summary>
    /// Gets the most percent of its column's height it takes, null for no such limit; what it holds
    /// then shrinks into that room.
    /// </summary>
    public int? MaxShare { get; private set; }

    /// <summary>Gets whether a list shows only whole rows, as many as its place holds.</summary>
    public bool WholeRows { get; private set; }

    /// <summary>
    /// Gets the component cancel moves the focus to while it or anything it holds has the focus,
    /// null for none.
    /// </summary>
    public int? CancelTo { get; private set; }

    /// <summary>Gets whether cancel moves a slides back a page while the focus is inside it.</summary>
    public bool SlideBack { get; private set; }

    /// <summary>
    /// Gets the key the focus is kept by, so a component made anew with the same key gets the focus
    /// its root kept for the one it replaced; null for none.
    /// </summary>
    public string? FocusKey { get; private set; }

    /// <summary>
    /// Gets whether a root closes on a left click outside it, as cancel closes it.
    /// </summary>
    public bool CloseOutside { get; private set; }

    /// <summary>
    /// Gets whether a root lies under another that holds the game's buttons, so a click on its
    /// buttons buzzes.
    /// </summary>
    public bool HeldUnder { get; private set; }

    /// <summary>
    /// Gets whether the scripts wait for a click on it, such as a label with a click block.
    /// </summary>
    public bool Clicks { get; private set; }

    /// <summary>
    /// Gets the zone a root stacks in at its default place, one of <see cref="Docks.Names"/>; null
    /// for none.
    /// </summary>
    public string? Dock { get; private set; }

    /// <summary>
    /// Gets the order of a docked root among those of its zone, lower nearer the zone's edge.
    /// </summary>
    public int DockOrder { get; private set; }

    /// <summary>
    /// Gets the zone a root lies alone at, without stacking with the others there, one of
    /// <see cref="Docks.Names"/>; null for none.
    /// </summary>
    public string? Anchor { get; private set; }

    /// <summary>
    /// Gets the edge a root docks along, taking its whole length, one of <see cref="Docks.Edges"/>;
    /// null for none.
    /// </summary>
    public string? Edge { get; private set; }

    /// <summary>
    /// Gets the place of a root's mod in the load order, which orders the roots of a zone with the
    /// same order.
    /// </summary>
    public int LoadOrder { get; private set; }

    /// <summary>
    /// Gets whether a docked root shrinks to its least height before a root of its zone hides for
    /// want of room.
    /// </summary>
    public bool GivesRoom { get; private set; }

    /// <summary>
    /// Gets the component a root lies beside, null for none or for a place the scripts give.
    /// </summary>
    public int? BesideNode { get; private set; }

    /// <summary>
    /// Gets the place a root lies beside, such as a game window's, which the scripts give; null for
    /// none.
    /// </summary>
    public LayoutRect? BesideRect { get; private set; }

    /// <summary>
    /// Gets the side of what it lies beside a root lies on, one of <see cref="Docks.Sides"/>.
    /// </summary>
    public string BesideSide { get; private set; } = "right";

    /// <summary>
    /// Gets whether a root beside a part takes the other side where its own has no room.
    /// </summary>
    public bool Flip { get; private set; } = true;

    /// <summary>
    /// Gets whether a root beside a part lines up with its left or top instead of its middle.
    /// </summary>
    public bool LinesUpAtStart { get; private set; }

    /// <summary>
    /// Gets the named column a root stacks in, which places it; null for none.
    /// </summary>
    public ColumnPlace? Column { get; private set; }

    /// <summary>
    /// Gets whether a root of a column that does not show keeps its place there, as while the
    /// scripts fade it out.
    /// </summary>
    public bool ColumnHold { get; private set; }

    /// <summary>
    /// Gets or sets whether a docked root hides because its zone has no room left for it.
    /// </summary>
    public bool Crowded { get; set; }

    /// <summary>
    /// Gets whether a root takes the pointer only on its parts that take clicks or show a tooltip,
    /// letting it through everywhere else.
    /// </summary>
    public bool MouseParts { get; private set; }

    /// <summary>
    /// Gets the most lines a wrapped text keeps, 0 for all of them and -1 for as many as its room
    /// holds, which then measures as one line and takes the room its parent gives it.
    /// </summary>
    public int MostLines { get; private set; }

    /// <summary>
    /// Gets how many toggles each row of a list has at its right end, by the row; rows without
    /// toggles are not named.
    /// </summary>
    public Dictionary<int, int> ToggleRows { get; private set; } = [];

    /// <summary>
    /// Gets where the box of each row of a list ends, in pixels from the left of its cell, by the
    /// row; rows without a box are not named.
    /// </summary>
    public Dictionary<int, int> BoxEnds { get; private set; } = [];

    /// <summary>
    /// Gets or sets the toggle of the cursor's row the cursor stands on, -1 for the row's text.
    /// </summary>
    public int ToggleCursor { get; set; } = -1;

    /// <summary>
    /// Gets whether a list's cursor goes round on every press: UP on its first row picks the last, DOWN
    /// on its last the first; null while the scripts leave it to the root's rules.
    /// </summary>
    public bool? Round { get; private set; }

    /// <summary>
    /// Gets whether a click on any row of a list picks it at once, not only on the cursor's row.
    /// </summary>
    public bool ClickPicks { get; private set; }

    /// <summary>
    /// Gets whether a text field is told that a cancel key left it, before the focus moves on.
    /// </summary>
    public bool TellsCancelled { get; private set; }

    /// <summary>
    /// Gets whether a container is clicked as one part: one key stop, what it holds taking neither
    /// the pointer nor the keys.
    /// </summary>
    public bool Clickable { get; private set; }

    /// <summary>
    /// Gets whether the keys stop on a container as a whole while the focus is outside it, confirm
    /// moving the focus inside.
    /// </summary>
    public bool Enter { get; private set; }

    /// <summary>
    /// Gets or sets the component inside a container that held the focus last, which confirm on a
    /// container the keys enter and a sideways move into it go back to.
    /// </summary>
    public Node? LastInner { get; set; }

    /// <summary>
    /// Gets whether a column lays its parts out from its bottom, leaving out from the top what its
    /// height does not hold.
    /// </summary>
    public bool Tail { get; private set; }

    /// <summary>
    /// Gets the most columns of a grid that takes as many equal columns as its widest child fits
    /// whole, 0 for a grid of the columns it names.
    /// </summary>
    public int FitColumns { get; private set; }

    /// <summary>
    /// Gets whether LEFT and RIGHT step tabs whenever the focused component has no use for them.
    /// </summary>
    public bool Arrows { get; private set; }

    /// <summary>
    /// Gives a grid that fits its columns a count of equal columns.
    /// </summary>
    /// <param name="count">The columns, at least one.</param>
    public void FitTo(int count) => Columns = new int?[System.Math.Max(count, 1)];

    /// <summary>
    /// Gets whether a text field takes the focus without typing until confirm or a click starts it.
    /// </summary>
    public bool ConfirmToType { get; private set; }

    /// <summary>
    /// Gets whether a text field typed into only once confirmed types now.
    /// </summary>
    public bool Typing { get; private set; }

    /// <summary>
    /// Gets whether a text field rests with the focus but without typing, since its first cancel in
    /// a root of the UI layer, until it types again or the focus leaves it.
    /// </summary>
    public bool Resting { get; private set; }

    /// <summary>
    /// Gets whether it is a text field that types now: one that types whenever it has the focus,
    /// unless it rests, or one that types only once confirmed or woken while it does.
    /// </summary>
    public bool TypesNow => TypesText && (!(ConfirmToType || Resting) || Typing);

    /// <summary>
    /// Gets whether it types as a text field does: a text field, or a numeric or number field, which
    /// types only once confirmed or, a number field, once a digit went down.
    /// </summary>
    public bool TypesText => Kind is NodeKind.TextField or NodeKind.NumericField;

    /// <summary>
    /// Gets whether it types a whole number, as a numeric field and a number field do.
    /// </summary>
    public bool TypesNumber => Kind is NodeKind.NumericField;

    /// <summary>
    /// Has a text field rest: it keeps the focus but no longer types.
    /// </summary>
    public void Rest() => (Resting, Typing) = (true, false);

    /// <summary>
    /// Ends a text field's rest as the focus leaves it, so it types again once it gets the focus back.
    /// </summary>
    public void EndRest() => Resting = false;

    /// <summary>
    /// Gets or sets the number a numeric field or a slider shows.
    /// </summary>
    public int Number { get; set; }

    /// <summary>
    /// Gets the least number of a numeric field or a slider, null for none.
    /// </summary>
    public int? NumberMin { get; private set; }

    /// <summary>
    /// Gets the largest number of a numeric field or a slider, null for none.
    /// </summary>
    public int? NumberMax { get; private set; }

    /// <summary>
    /// Gets what a step adds to or takes from the number of a numeric field or a slider.
    /// </summary>
    public int NumberStep { get; private set; } = 1;

    /// <summary>
    /// Gets the width of the room at either end of a numeric field where a click steps it, 0 while it
    /// shows no arrows.
    /// </summary>
    public int NumberArrows { get; private set; }

    /// <summary>
    /// Gets the room inside a slider left and right of its track, across which the pointer picks its
    /// number.
    /// </summary>
    public (int Left, int Right) Track { get; private set; }

    /// <summary>
    /// Gets the width of each cell of a slider shown as a rating, a star with the room after it, from
    /// the left end of its track; 0 for a slider without cells.
    /// </summary>
    public int Cells { get; private set; }

    /// <summary>
    /// Gets whether a component takes the mouse wheel itself, told as wheel, such as a log that
    /// scrolls its wrapped rows.
    /// </summary>
    public bool WheelTold { get; private set; }

    /// <summary>Gets whether it takes the pointer; false lets the pointer through it and what it holds.</summary>
    public bool Mouse { get; private set; }

    /// <summary>Gets a root's depth among the roots.</summary>
    public int Z { get; private set; }

    /// <summary>Gets whether a root blocks the input of every root below it.</summary>
    public bool Modal { get; private set; }

    /// <summary>Gets whether cancel closes it, as a root.</summary>
    public bool Closable { get; private set; }

    /// <summary>Gets whether the player moves it, as a root kept by the layout.</summary>
    public bool Movable { get; private set; }

    /// <summary>Gets how the player resizes it, as a root kept by the layout.</summary>
    public LayoutResize Resizable { get; private set; } = LayoutResize.None;

    /// <summary>
    /// Gets whether it takes the focus: as the scripts set it, else when its kind takes the focus,
    /// it has an action and it repeats no key.
    /// </summary>
    public bool Focusable => _focusable ?? (_kindTakesFocus && Acts && !Repeats);

    /// <summary>Gets whether a box scrolls what it holds.</summary>
    public bool Scroll { get; private set; }

    /// <summary>Gets a list's rows, or a text field's lines.</summary>
    public int Rows { get; private set; }

    /// <summary>Gets how many rows of a list lie side by side on one line, 1 for a plain list.</summary>
    public int RowCells { get; private set; } = 1;

    /// <summary>Gets how many lines a list's rows take, its cells filling each line from the left.</summary>
    public int RowLines => (Rows + RowCells - 1) / RowCells;

    /// <summary>Gets the height of one line or row.</summary>
    public int RowHeight { get; private set; } = DefaultRowHeight;

    /// <summary>Gets the text it measures by, null for none.</summary>
    public string? Text { get; private set; }

    /// <summary>Gets the key of the font its text is measured in, null for none.</summary>
    public int? Font { get; private set; }

    /// <summary>Gets whether its text carries the game's escape codes.</summary>
    public bool Escapes { get; private set; }

    /// <summary>Gets the width the scripts measured for what it shows, null for none.</summary>
    public int? MeasuredWidth { get; private set; }

    /// <summary>Gets the height the scripts measured, null for none.</summary>
    public int? MeasuredHeight { get; private set; }

    /// <summary>Gets whether it keeps the sides it measured in proportion, its height following the width it gets and its width a fixed height.</summary>
    public bool KeepsAspect { get; private set; }

    /// <summary>Gets the id the layout keeps a root's place under, null for a root the player does not arrange.</summary>
    public string? LayoutId { get; private set; }

    /// <summary>
    /// The bit of a claimed key code that claims the key only while the left Alt is held, and the
    /// key alone only while it is not.
    /// </summary>
    public const int AltFlag = 0x100;

    /// <summary>Gets the key codes a text field claims, which it is told of instead of acting on them, those with <see cref="AltFlag"/> only while the left Alt is held.</summary>
    public IReadOnlyCollection<int> Keys { get; private set; } = [];

    /// <summary>Gets a list's rows that take no submit.</summary>
    public IReadOnlySet<int> DisabledRows { get; private set; } = new HashSet<int>();

    /// <summary>Gets a list's heading rows, which the cursor, the keys and the pointer pass over.</summary>
    public IReadOnlySet<int> HeadingRows { get; private set; } = new HashSet<int>();

    /// <summary>Gets whether a list hands LEFT and RIGHT to the scripts as a step of its cursor's row, as a list of values does.</summary>
    public bool Sides { get; private set; }

    /// <summary>Gets a list's rows that have a value, the only rows a list with <see cref="Sides"/> hands LEFT and RIGHT to the scripts on.</summary>
    public IReadOnlySet<int> ValueRows { get; private set; } = new HashSet<int>();

    /// <summary>Gets whether it shows a tooltip when the pointer rests on it.</summary>
    public bool Tooltip { get; private set; }

    /// <summary>
    /// Gets whether a list's cursor follows the pointer over its rows, null while the scripts leave it
    /// to the root's rules.
    /// </summary>
    public bool? FollowPointer { get; private set; }

    /// <summary>Gets whether a list hands the focus on by UP on its first line and DOWN on its last.</summary>
    public bool LeaveEnds { get; private set; }

    /// <summary>Gets whether a box keeps the focus by UP at its top and DOWN at its end.</summary>
    public bool KeepEnds { get; private set; }

    /// <summary>
    /// Gets whether a list of columns hands the focus on by RIGHT on the last row of a line and LEFT
    /// on the first, and a text field of one line by RIGHT with the caret at the end of its text and
    /// LEFT at its start.
    /// </summary>
    public bool LeaveSides { get; private set; }

    /// <summary>
    /// Gets the characters a text field types of the keys the game's buttons are bound to: the
    /// letters in lower case, the space and "0"; null for every one of them.
    /// </summary>
    public string? Takes { get; private set; }

    /// <summary>
    /// Gets or sets the tree's tick a root opened or showed again in, whose keys and presses are
    /// older than it.
    /// </summary>
    public long OpenedAt { get; set; } = -1;

    /// <summary>
    /// Gets or sets the bits of the game's buttons held since before a root opened, each until it is
    /// let go.
    /// </summary>
    public int HeldAtOpen { get; set; }

    /// <summary>
    /// Gets or sets the bits of the game's extra buttons held since before a root opened, each until
    /// it is let go.
    /// </summary>
    public int HeldExtraAtOpen { get; set; }

    /// <summary>Gets the text field that steers a list, which UP on the list's first line moves the focus to when the list hands it on; null for none.</summary>
    public int? UpTo { get; private set; }

    /// <summary>Gets whether a text field's caret stands at the start of its text and at its end, as its script tells.</summary>
    public (bool Start, bool End) CaretEnds { get; private set; }

    /// <summary>Gets whether the game's L and R page a list.</summary>
    public bool ShoulderPages { get; private set; } = true;

    /// <summary>Gets whether Page Up, Page Down and the paging the shoulders fall back to scroll the box that scrolls beside a list instead of the list, such as the reading pane beside a page view's list.</summary>
    public bool PagesBeside { get; private set; }

    /// <summary>Gets whether a list shows a page of its rows at a time, so paging it tells its script page_step instead of moving its cursor.</summary>
    public bool OwnPages { get; private set; }

    /// <summary>Gets whether a click on it, or a pick of a list's row, plays no sound, as on a button no block answers.</summary>
    public bool Quiet { get; private set; }

    /// <summary>Gets or sets a list's cursor row, -1 for none.</summary>
    public int Cursor { get; set; } = -1;

    /// <summary>Gets whether a list lets the pointer drag its rows to another place.</summary>
    public bool Reorder { get; private set; }

    /// <summary>Gets whether a list whose rows move takes the framework's Move Up and Move Down hotkeys, as the framework's own mod list does.</summary>
    public bool MoveHotkeys { get; private set; }

    /// <summary>Gets or sets whether a list carries its cursor's row, which its cursor moves to another place.</summary>
    public bool Moving { get; set; }

    /// <summary>Gets whether it is an item of a drop zone that the player picks up and puts into a drop zone.</summary>
    public bool Drag { get; private set; }

    /// <summary>Gets whether it is a drop zone, whose items are its children that are dragged.</summary>
    public bool DropZone { get; private set; }

    /// <summary>Gets whether it holds drop zones between which its items are dragged.</summary>
    public bool DropContainer { get; private set; }

    /// <summary>Gets the first and the last row the row a list carries may move to, the rows of its group; null for every row.</summary>
    public (int First, int Last)? MoveSpan { get; private set; }

    /// <summary>
    /// Gets or sets the keys other hotkeys have, each with that hotkey's name, while the part waits
    /// for the key the player presses to bind a hotkey; null while it does not wait.
    /// </summary>
    public Dictionary<int, string>? CaptureTaken { get; set; }

    /// <summary>Gets the group of each row of a list that lets its rows move, in the rows' order; empty while the rows form one group.</summary>
    public List<int> RowGroups { get; private set; } = [];

    /// <summary>Gets or sets where its scrolling starts: a list's first line shown, a box's first pixel.</summary>
    public int ScrollTop
    {
        get => _scrollTop;
        set
        {
            if (_scrollTop != value)
            {
                _scrollTop = value;
                MarkDirty();
            }
        }
    }

    /// <summary>Gets or sets whether a root holds a component changed since its last layout.</summary>
    public bool LayoutDirty { get; set; }

    /// <summary>Gets or sets where a root was placed at its last layout, before the docks moved it; null before it.</summary>
    public LayoutRect? Placed { get; set; }

    /// <summary>Gets or sets where the player had put a root at its last layout, null for nowhere.</summary>
    public LayoutRect? ArrangedAt { get; set; }

    /// <summary>Gets or sets the place a root was laid out in last, null before it.</summary>
    public LayoutRect? LaidOutAt { get; set; }

    /// <summary>Gets or sets how much of it shows: a list's lines, a box's pixels.</summary>
    public int ScrollShown { get; set; }

    /// <summary>Gets or sets how much there is: a list's lines, a box's content pixels.</summary>
    public int ScrollTotal { get; set; }

    /// <summary>Gets or sets its place after the last layout, null before it or while it is hidden.</summary>
    public LayoutRect? Rect { get; set; }

    /// <summary>Gets or sets a root's place among the roots of the same depth, higher on top.</summary>
    public long Raise { get; set; }

    /// <summary>Gets or sets the component inside a root that had the focus last, null for none.</summary>
    public Node? LastFocus { get; set; }

    /// <summary>
    /// Gets or sets the component the focus came from as it entered this page of a root of the new
    /// UI layer, where cancel walks back to; null for none.
    /// </summary>
    public Node? CameFrom { get; set; }

    /// <summary>
    /// Gets or sets the component beside it the focus came from into it in a root of the new UI
    /// layer, by an arrow, a click or the scripts, where cancel in a list walks back to; null for
    /// none.
    /// </summary>
    public Node? HandedFrom { get; set; }

    /// <summary>
    /// Gets or sets the component a root gave the focus to as it first opened, where cancel walks no
    /// way back in a root of the new UI layer; null for none.
    /// </summary>
    public Node? Home { get; set; }

    /// <summary>Gets whether it scrolls: a list, or a box that scrolls what it holds.</summary>
    public bool Scrolls => Kind == NodeKind.List || Scroll;

    /// <summary>Gets whether its content outgrows it, so it shows a scrollbar.</summary>
    public bool Overflows => Scrolls && ScrollTotal > ScrollShown;

    /// <summary>
    /// Takes the properties the scripts sent, each optional; one unknown or out of range is left as
    /// it was and the others are still taken.
    /// </summary>
    /// <param name="props">The properties by name, see <see cref="ComponentTree"/>.</param>
    /// <returns>Why each property left out was refused, empty when every one was taken.</returns>
    public List<string> Apply(RubyHash props)
    {
        var refused = new List<string>();
        foreach ((RubyValue key, RubyValue value) in props)
        {
            try
            {
                Take(key.AsText(), value);
            }
            catch (Exception error) when (error is BridgeRequestException or RubyValueException)
            {
                refused.Add(error.Message);
            }
        }

        MarkDirty();
        return refused;
    }

    /// <summary>
    /// Notes that the root it lies in must be laid out again.
    /// </summary>
    public void MarkDirty()
    {
        Node top = this;
        while (top.Parent is { } above)
        {
            top = above;
        }

        top.LayoutDirty = true;
    }

    /// <summary>
    /// Reads a kind's name.
    /// </summary>
    /// <param name="name">The name, such as "text_field".</param>
    /// <returns>The kind.</returns>
    /// <exception cref="BridgeRequestException">No kind has the name.</exception>
    public static NodeKind KindOf(string name) => name switch
    {
        "window" => NodeKind.Window,
        "dialog" => NodeKind.Dialog,
        "box" => NodeKind.Box,
        "text_field" => NodeKind.TextField,
        "tooltip" => NodeKind.Tooltip,
        "stack" => NodeKind.Stack,
        "grid" => NodeKind.Grid,
        "tabs" => NodeKind.Tabs,
        "label" => NodeKind.Label,
        "icon" => NodeKind.Icon,
        "picture" => NodeKind.Picture,
        "button" => NodeKind.Button,
        "icon_button" => NodeKind.IconButton,
        "checkbox" => NodeKind.Checkbox,
        "select" => NodeKind.Select,
        "list" => NodeKind.List,
        "gauge" => NodeKind.Gauge,
        "divider" => NodeKind.Divider,
        "stats" => NodeKind.Stats,
        "slides" => NodeKind.Slides,
        "custom" => NodeKind.Custom,
        "numeric_field" => NodeKind.NumericField,
        "slider" => NodeKind.Slider,
        "adopted" => NodeKind.Adopted,
        _ => throw new BridgeRequestException($"No component kind is named {name}."),
    };

    /// <summary>
    /// Takes one property.
    /// </summary>
    /// <param name="name">Its name.</param>
    /// <param name="value">Its value.</param>
    /// <exception cref="BridgeRequestException">The property is unknown or out of range.</exception>
    private void Take(string name, RubyValue value)
    {
        switch (name)
        {
            case "layout": Layout = LayoutOf(value.AsText()); break;
            case "gap": Gap = Whole(name, value); break;
            case "padding": TakePadding(value); break;
            case "margin": Margin = InsetsOf(name, value); break;
            case "centered": Centered = value.AsBool(); break;
            case "widths": Widths = value.IsNil ? null : SortedWidths(value); break;
            case "justify": Justify = JustifyOf(value.AsText()); break;
            case "wrap": Wrap = value.AsBool(); break;
            case "columns": Columns = ColumnsOf(value); break;
            case "align": Align = AlignOf(value.AsText()); break;
            case "grow": Grow = Whole(name, value); break;
            case "span": Span = System.Math.Max(Whole(name, value), 1); break;
            case "corner": Corner = value.AsBool(); break;
            case "size": (FixedWidth, FixedHeight) = Pair(name, value); break;
            case "width": FixedWidth = Side(name, value); break;
            case "height": FixedHeight = Side(name, value); break;
            case "min": (int? width, int? height) = Pair(name, value); (MinWidth, MinHeight) = (width ?? 0, height ?? 0); break;
            case "max": (MaxWidth, MaxHeight) = Pair(name, value); break;
            case "at": At = value.IsNil ? null : (value.AsArray()[0].AsInt(), value.AsArray()[1].AsInt()); break;
            case "center": Center = value.AsBool(); break;
            case "visible": _visible = value.AsBool(); break;
            case "forms": FormSteps = value.IsNil ? null : [.. Numbers(value)]; break;
            case "measures": Measures = value.AsBool(); break;
            case "enabled": Enabled = value.AsBool(); break;
            case "mouse": Mouse = value.AsBool(); break;
            case "z": Z = value.AsInt(); break;
            case "modal": Modal = value.AsBool(); break;
            case "closable": Closable = value.AsBool(); break;
            case "movable": Movable = value.AsBool(); break;
            case "resizable": Resizable = ResizeOf(value); break;
            case "focusable": _focusable = value.AsBool(); break;
            case "acts": Acts = value.AsBool(); break;
            case "repeats": Repeats = value.AsBool(); break;
            case "autofocus": Autofocus = value.AsBool(); break;
            case "jump_only": JumpOnly = value.AsBool(); break;
            case "scroll": Scroll = value.AsBool(); break;
            case "rows": Rows = Whole(name, value); break;
            case "row_cells": RowCells = System.Math.Max(Whole(name, value), 1); break;
            case "row_height": RowHeight = System.Math.Max(Whole(name, value), 1); break;
            case "text": Text = value.IsNil ? null : value.AsText(); break;
            case "font": Font = value.IsNil ? null : value.AsInt(); break;
            case "escapes": Escapes = value.AsBool(); break;
            case "measured": (MeasuredWidth, MeasuredHeight) = Pair(name, value); break;
            case "aspect": KeepsAspect = value.AsBool(); break;
            case "layout_id": LayoutId = value.IsNil ? null : value.AsText(); break;
            case "keys": Keys = KeyCodes(value); break;
            case "index": Cursor = value.IsNil ? -1 : value.AsInt(); break;
            case "disabled_rows": DisabledRows = new HashSet<int>(Numbers(value)); break;
            case "heading_rows": HeadingRows = new HashSet<int>(Numbers(value)); break;
            case "sides": Sides = value.AsBool(); break;
            case "value_rows": ValueRows = new HashSet<int>(Numbers(value)); break;
            case "tooltip": Tooltip = value.AsBool(); break;
            case "follow_pointer": FollowPointer = value.IsNil ? null : value.AsBool(); break;
            case "reorder": Reorder = value.AsBool(); break;
            case "move_hotkeys": MoveHotkeys = value.AsBool(); break;
            case "row_groups": RowGroups = Numbers(value); break;
            case "capture": CaptureTaken = CaptureOf(value); break;
            case "moving": Moving = value.AsBool(); break;
            case "move_span": MoveSpan = value.IsNil ? null : (value.AsArray()[0].AsInt(), value.AsArray()[1].AsInt()); break;
            case "shoulder_pages": ShoulderPages = value.AsBool(); break;
            case "pages_beside": PagesBeside = value.AsBool(); break;
            case "own_pages": OwnPages = value.AsBool(); break;
            case "leave_ends": LeaveEnds = value.AsBool(); break;
            case "keep_ends": KeepEnds = value.AsBool(); break;
            case "leave_sides": LeaveSides = value.AsBool(); break;
            case "takes": Takes = value.IsNil ? null : value.AsText(); break;
            case "up_to": UpTo = value.IsNil ? null : value.AsInt(); break;
            case "caret_ends": CaretEnds = value.IsNil ? (false, false) : (value.AsArray()[0].AsBool(), value.AsArray()[1].AsBool()); break;
            case "quiet": Quiet = value.AsBool(); break;
            case "scroll_top": ScrollTop = Whole(name, value); break;
            case "inert": Inert = value.AsBool(); break;
            case "offset": Offset = value.IsNil ? (0, 0) : (value.AsArray()[0].AsInt(), value.AsArray()[1].AsInt()); break;
            case "shrink": Shrinks = value.AsBool(); break;
            case "shown": PagesShown = System.Math.Max(Whole(name, value), 1); break;
            case "slide_keys": SlideKeys = value.AsBool(); break;
            case "shoulder": Shoulder = value.AsBool(); break;
            case "pointer_only": _pointerOnly = value.AsBool(); break;
            case "aside": Aside = value.AsBool(); break;
            case "steps": Steps = value.AsBool(); break;
            case "tab_key": TabKey = value.IsNil ? null : value.AsBool(); break;
            case "pad_shoulders": PadShoulders = value.IsNil ? null : value.AsBool(); break;
            case "tabs_shown": TabsShown = value.IsNil ? null : value.AsInt(); break;
            case "layer": Layer = value.AsBool(); break;
            case "captures": Captures = value.AsBool(); break;
            case "joined": Joined = value.AsBool(); break;
            case "pages": Pages = value.AsBool(); break;
            case "hotkey": Hotkey = value.IsNil || value.AsText().Length == 0 ? null : value.AsText(); break;
            case "submits": TakesSubmit = value.IsNil ? null : value.AsBool(); break;
            case "context_menu": ContextMenu = value.AsBool(); break;
            case "extra_buttons": ExtraButtons = ExtraButtonsOf(value); break;
            case "shoulders": ShouldersStepTabsOnly = !value.IsNil && value.AsText() == "tabs"; break;
            case "tab_page": TabPage = value.AsBool(); break;
            case "cancel_guard": GuardsCancel = value.AsBool(); break;
            case "leave_told": TellsLeave = value.AsBool(); break;
            case "whole_rows": WholeRows = value.AsBool(); break;
            case "steady": (Steady, SteadyHeight) = (value.AsBool(), 0); break;
            case "max_share": MaxShare = value.IsNil ? null : System.Math.Min(Whole(name, value), 100); break;
            case "cancel_to": CancelTo = value.IsNil ? null : value.AsInt(); break;
            case "slide_back": SlideBack = value.AsBool(); break;
            case "focus_key": FocusKey = value.IsNil ? null : value.AsText(); break;
            case "close_outside": CloseOutside = value.AsBool(); break;
            case "held_under": HeldUnder = value.AsBool(); break;
            case "clicks": Clicks = value.AsBool(); break;
            case "dock": Dock = DockOf(value); break;
            case "dock_order": DockOrder = value.AsInt(); break;
            case "anchor": Anchor = NameOf(name, value, Docks.Names); break;
            case "edge": Edge = NameOf(name, value, Docks.Edges); break;
            case "load_order": LoadOrder = value.AsInt(); break;
            case "gives_room": GivesRoom = value.AsBool(); break;
            case "beside": (BesideNode, BesideRect) = BesideOf(value); break;
            case "side": BesideSide = NameOf(name, value, Docks.Sides) ?? "right"; break;
            case "flip": Flip = value.AsBool(); break;
            case "line_up": LinesUpAtStart = NameOf(name, value, Docks.LineUps) == "start"; break;
            case "column": Column = ColumnOf(value); break;
            case "column_hold": ColumnHold = value.AsBool(); break;
            case "mouse_parts": MouseParts = value.AsBool(); break;
            case "most_lines": MostLines = value.AsInt(); break;
            case "toggle_rows": ToggleRows = ByRow(value); break;
            case "box_ends": BoxEnds = ByRow(value); break;
            case "round": Round = value.IsNil ? null : value.AsBool(); break;
            case "click_picks": ClickPicks = value.AsBool(); break;
            case "tells_cancelled": TellsCancelled = value.AsBool(); break;
            case "clickable": Clickable = value.AsBool(); break;
            case "drag": Drag = value.AsBool(); break;
            case "drop_zone": DropZone = value.AsBool(); break;
            case "drop_container": DropContainer = value.AsBool(); break;
            case "enter": Enter = value.AsBool(); break;
            case "tail": Tail = value.AsBool(); break;
            case "fit_columns": FitColumns = Whole(name, value); break;
            case "arrows": Arrows = value.AsBool(); break;
            case "confirm_to_type": ConfirmToType = value.AsBool(); break;
            case "typing": Typing = value.AsBool(); Resting &= !Typing; break;
            case "number": Number = Kind is NodeKind.NumericField or NodeKind.Slider ? value.AsInt() : Whole(name, value); break;
            case "number_min": NumberMin = value.IsNil ? null : value.AsInt(); break;
            case "number_max": NumberMax = value.IsNil ? null : value.AsInt(); break;
            case "number_step": NumberStep = System.Math.Max(value.AsInt(), 1); break;
            case "number_arrows": NumberArrows = System.Math.Max(value.AsInt(), 0); break;
            case "track": (int? left, int? right) = Pair(name, value); Track = (left ?? 0, right ?? 0); break;
            case "cells": Cells = Whole(name, value); break;
            case "wheel_told": WheelTold = value.AsBool(); break;
            default: throw new BridgeRequestException($"No component property is named {name}.");
        }
    }

    /// <summary>
    /// Reads the keys other hotkeys have while a part waits for a key.
    /// </summary>
    /// <param name="value">{key code => the hotkey's name}, nil while it does not wait.</param>
    /// <returns>The keys with their hotkeys' names, null while it does not wait.</returns>
    private static Dictionary<int, string>? CaptureOf(RubyValue value)
    {
        if (value.IsNil)
        {
            return null;
        }

        var taken = new Dictionary<int, string>();
        foreach ((RubyValue code, RubyValue name) in value.AsHash())
        {
            taken[code.AsInt()] = name.AsText();
        }

        return taken;
    }

    /// <summary>
    /// Reads a number of each row of a list, such as how many toggles it has.
    /// </summary>
    /// <param name="value">Each row's number in the rows' order, 0 for none, nil for no row.</param>
    /// <returns>The numbers above 0, by the row.</returns>
    private static Dictionary<int, int> ByRow(RubyValue value)
    {
        var byRow = new Dictionary<int, int>();
        List<int> numbers = Numbers(value);
        for (int row = 0; row < numbers.Count; row++)
        {
            if (numbers[row] > 0)
            {
                byRow[row] = numbers[row];
            }
        }

        return byRow;
    }

    /// <summary>
    /// Reads the game's extra buttons a part takes.
    /// </summary>
    /// <param name="value">The buttons' names, such as ["Z", "Y"], nil for none.</param>
    /// <returns>The buttons.</returns>
    /// <exception cref="BridgeRequestException">A name is no extra button.</exception>
    private static HashSet<UiExtraButton> ExtraButtonsOf(RubyValue value)
    {
        var buttons = new HashSet<UiExtraButton>();
        foreach (RubyValue name in value.IsNil ? [] : value.AsArray())
        {
            buttons.Add(name.AsText() switch
            {
                "A" => UiExtraButton.A,
                "X" => UiExtraButton.X,
                "Y" => UiExtraButton.Y,
                "Z" => UiExtraButton.Z,
                string other => throw new BridgeRequestException($"No extra button of the game is named {other}."),
            });
        }

        return buttons;
    }

    /// <summary>
    /// Reads a root's dock.
    /// </summary>
    /// <param name="value">The zone's name, nil for none.</param>
    /// <returns>The zone, null for none.</returns>
    /// <exception cref="BridgeRequestException">No zone has the name.</exception>
    private static string? DockOf(RubyValue value) => NameOf("dock", value, Docks.Names);

    /// <summary>
    /// Reads a root's column.
    /// </summary>
    /// <param name="value">[name, x, y, gap, align], nil for none.</param>
    /// <returns>The column, null for none.</returns>
    /// <exception cref="BridgeRequestException">Its gap is below 0 or no align has its name.</exception>
    private static ColumnPlace? ColumnOf(RubyValue value)
    {
        if (value.IsNil)
        {
            return null;
        }

        RubyArray column = value.AsArray();
        return new ColumnPlace(column[0].AsText(), column[1].AsInt(), column[2].AsInt(), Whole("column gap", column[3]), NameOf("column align", column[4], Docks.ColumnAligns) ?? "left");
    }

    /// <summary>
    /// Reads a name that must be one of a few.
    /// </summary>
    /// <param name="property">The property, for the message.</param>
    /// <param name="value">The name, nil for none.</param>
    /// <param name="names">The names it may be.</param>
    /// <returns>The name, null for none.</returns>
    /// <exception cref="BridgeRequestException">It is none of them.</exception>
    private static string? NameOf(string property, RubyValue value, string[] names)
    {
        if (value.IsNil)
        {
            return null;
        }

        string name = value.AsText();
        return System.Array.IndexOf(names, name) >= 0 ? name : throw new BridgeRequestException($"No {property} is named {name}.");
    }

    /// <summary>
    /// Reads what a root lies beside: a component's id, or a place as [x, y, width, height].
    /// </summary>
    /// <param name="value">The id, the place, or nil for nothing.</param>
    /// <returns>The component or the place, both null for nothing.</returns>
    private static (int? Node, LayoutRect? Rect) BesideOf(RubyValue value)
    {
        if (value.IsNil)
        {
            return (null, null);
        }

        if (value is not RubyArray place)
        {
            return (value.AsInt(), null);
        }

        return place.Count == 4 ? (null, new LayoutRect(place[0].AsInt(), place[1].AsInt(), place[2].AsInt(), place[3].AsInt()))
                                : throw new BridgeRequestException("A place to lie beside takes [x, y, width, height].");
    }

    /// <summary>
    /// Reads a number that cannot be negative.
    /// </summary>
    /// <param name="name">The property's name.</param>
    /// <param name="value">The value.</param>
    /// <returns>The number.</returns>
    /// <exception cref="BridgeRequestException">It is negative.</exception>
    private static int Whole(string name, RubyValue value)
    {
        int number = value.AsInt();
        return number >= 0 ? number : throw new BridgeRequestException($"The {name} of a component cannot be {number}.");
    }

    /// <summary>
    /// Reads one side of a size.
    /// </summary>
    /// <param name="name">The property's name.</param>
    /// <param name="value">The side, nil for none.</param>
    /// <returns>The side, null for none.</returns>
    private static int? Side(string name, RubyValue value) => value.IsNil ? null : Whole(name, value);

    /// <summary>
    /// Reads a width and a height.
    /// </summary>
    /// <param name="name">The property's name.</param>
    /// <param name="value">[width, height], either side nil for none, or nil for neither.</param>
    /// <returns>Both sides.</returns>
    private static (int? Width, int? Height) Pair(string name, RubyValue value)
    {
        if (value.IsNil)
        {
            return (null, null);
        }

        RubyArray pair = value.AsArray();
        return pair.Count == 2 ? (Side(name, pair[0]), Side(name, pair[1])) : throw new BridgeRequestException($"The {name} of a component cannot be {value}.");
    }

    /// <summary>
    /// Reads a list of numbers.
    /// </summary>
    /// <param name="value">The list, nil for none.</param>
    /// <returns>The numbers.</returns>
    private static List<int> Numbers(RubyValue value)
    {
        var numbers = new List<int>();
        if (!value.IsNil)
        {
            foreach (RubyValue item in value.AsArray())
            {
                numbers.Add(item.AsInt());
            }
        }

        return numbers;
    }

    /// <summary>
    /// Reads the key codes a text field claims.
    /// </summary>
    /// <param name="value">The codes, nil for none.</param>
    /// <returns>The codes.</returns>
    /// <exception cref="BridgeRequestException">A code is out of range.</exception>
    private static List<int> KeyCodes(RubyValue value)
    {
        List<int> codes = Numbers(value);
        foreach (int code in codes)
        {
            if ((code & ~AltFlag) is < 0x01 or > 0xFE)
            {
                throw new BridgeRequestException($"There is no key code {code}.");
            }
        }

        return codes;
    }

    /// <summary>
    /// Reads the room inside the edges or around them.
    /// </summary>
    /// <param name="name">The property it is, for the refusal.</param>
    /// <param name="value">One number for every side, or [top, right, bottom, left].</param>
    /// <returns>The room.</returns>
    private static Insets InsetsOf(string name, RubyValue value)
    {
        if (value is RubyInteger)
        {
            int all = Whole(name, value);
            return new Insets(all, all, all, all);
        }

        RubyArray sides = value.AsArray();
        return sides.Count == 4 ? SidesAt(name, sides, 0) : throw new BridgeRequestException($"The {name} of a component cannot be {value}.");
    }

    /// <summary>
    /// Reads the padding, and the part of each side that gives way where four more numbers follow,
    /// each at most its side.
    /// </summary>
    /// <param name="value">One number for every side, [top, right, bottom, left], or those and the pixels of each that give way.</param>
    private void TakePadding(RubyValue value)
    {
        if (value is not RubyArray { Count: 8 } sides)
        {
            (Padding, PaddingGives) = (InsetsOf("padding", value), default);
            return;
        }

        Padding = SidesAt("padding", sides, 0);
        Insets gives = SidesAt("padding", sides, 4);
        PaddingGives = new Insets(System.Math.Min(gives.Top, Padding.Top), System.Math.Min(gives.Right, Padding.Right),
                                  System.Math.Min(gives.Bottom, Padding.Bottom), System.Math.Min(gives.Left, Padding.Left));
    }

    /// <summary>
    /// Reads four sides from a list of numbers.
    /// </summary>
    /// <param name="name">The property it is, for the refusal.</param>
    /// <param name="sides">The numbers.</param>
    /// <param name="start">Where the top side is.</param>
    /// <returns>The sides.</returns>
    private static Insets SidesAt(string name, RubyArray sides, int start) =>
        new(Whole(name, sides[start]), Whole(name, sides[start + 1]), Whole(name, sides[start + 2]), Whole(name, sides[start + 3]));

    /// <summary>
    /// Reads the widths a centered part picks from.
    /// </summary>
    /// <param name="value">The widths in pixels.</param>
    /// <returns>The widths, from the narrowest.</returns>
    private static int[] SortedWidths(RubyValue value)
    {
        int[] widths = [.. Numbers(value)];
        System.Array.Sort(widths);
        return widths;
    }

    /// <summary>
    /// Reads a grid's columns.
    /// </summary>
    /// <param name="value">A count of equal columns, or each column's width with nil for one that shares the room left.</param>
    /// <returns>The widths.</returns>
    private static int?[] ColumnsOf(RubyValue value)
    {
        if (value is RubyInteger)
        {
            int count = value.AsInt();
            return count > 0 ? new int?[count] : throw new BridgeRequestException($"A grid cannot have {count} columns.");
        }

        RubyArray widths = value.AsArray();
        var columns = new int?[widths.Count];
        for (int index = 0; index < columns.Length; index++)
        {
            columns[index] = Side("columns", widths[index]);
        }

        return columns.Length > 0 ? columns : throw new BridgeRequestException("A grid cannot have no columns.");
    }

    /// <summary>
    /// Reads how a root resizes.
    /// </summary>
    /// <param name="value">false, true, "width" or "height".</param>
    /// <returns>The way.</returns>
    private static LayoutResize ResizeOf(RubyValue value) => value switch
    {
        RubyBool { Flag: true } => LayoutResize.Both,
        RubyBool { Flag: false } or RubyNil => LayoutResize.None,
        _ => value.AsText() switch
        {
            "width" => LayoutResize.Width,
            "height" => LayoutResize.Height,
            string other => throw new BridgeRequestException($"A component cannot resize by {other}."),
        },
    };

    /// <summary>
    /// Reads how a container places its children.
    /// </summary>
    /// <param name="name">"column", "row", "grid" or "absolute".</param>
    /// <returns>The layout.</returns>
    private static FlowLayout LayoutOf(string name) => name switch
    {
        "column" => FlowLayout.Column,
        "row" => FlowLayout.Row,
        "grid" => FlowLayout.Grid,
        "absolute" => FlowLayout.Absolute,
        _ => throw new BridgeRequestException($"No layout is named {name}."),
    };

    /// <summary>
    /// Reads where a stack puts its children.
    /// </summary>
    /// <param name="name">"start", "center", "end" or "between".</param>
    /// <returns>The way.</returns>
    private static FlowJustify JustifyOf(string name) => name switch
    {
        "start" => FlowJustify.Start,
        "center" => FlowJustify.Center,
        "end" => FlowJustify.End,
        "between" => FlowJustify.Between,
        _ => throw new BridgeRequestException($"No justify is named {name}."),
    };

    /// <summary>
    /// Reads where a child sits across its parent's stack.
    /// </summary>
    /// <param name="name">"start", "center", "end" or "stretch".</param>
    /// <returns>The way.</returns>
    private static FlowAlign AlignOf(string name) => name switch
    {
        "start" => FlowAlign.Start,
        "center" => FlowAlign.Center,
        "end" => FlowAlign.End,
        "stretch" => FlowAlign.Stretch,
        _ => throw new BridgeRequestException($"No align is named {name}."),
    };
}

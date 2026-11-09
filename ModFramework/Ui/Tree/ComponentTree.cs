//----------------------------------------------------------------
//  ComponentTree.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Told the scripts how much of a part's padding gave way at its place
//                            - Kept the view of a scrolled box inside what is left of its padding
//                            - Stacked the roots of each named column, a hidden one too while it keeps its place there
//                            - Noted the part a root first opens on as its home
//                            - Counted a docked root's margin into the least height it shrinks to in a full zone
//      Paulinchen  2026-11-07: Picked an item of a drop zone up by confirm and put the item carried down by it
//                            - Put the carried item back once the focus leaves its container or a root above opens
//                            - Named a child over its parent's corner among the properties
//                            - Named the columns of a grid a child spans among the properties
//                            - Fitted the number the scripts give a slider to its bounds and steps, and kept the slider dragged
//                            - Moved the key handling into ComponentTreeKeys.cs and the pointer handling into ComponentTreeMouse.cs
//                            - Picked the step of a root's compact forms before its layout
//                            - Used the bridge and the runtime under the framework's namespace
//                            - Walked cancel in a list back to the component that handed it the focus
//                            - Counted an arrow or a click into a list as the way back for cancel
//                            - Asked KeyNames which cancel keys leave a text field
//                            - Took out the focus and the keys kept from the tree while a box outside it typed
//      Paulinchen  2026-11-06: Gave the focus back to a root that never held it where its focus starts, its part marked autofocus
//                              first, as a question opens while the box under it closes
//                            - Stepped the tabs the arrows step past a part the keys reach only by the jump key
//                            - Removed the number field set digit by digit, which a numeric field replaces
//                            - Started typing a number field by a digit of the number row, from where it types as a
//                              numeric field, and took out its calculator start
//                            - Picked the box below or above a box picked as a whole by where it lies, not by tree order
//                            - Left the rows of a list to read, which has neither an action nor a bind, unframed and unpicked
//                              by the pointer
//                            - Gave the focus back after a root closed to the key stop nearest the component that had it,
//                              when that one turned off meanwhile
//                            - Took out the row of tabs as one key stop, which no screen uses any more
//                            - Left L, R, Page Up and Page Down unused in a root joined to a game window, as on the title's
//                              commands
//                            - Gave the focus back to no root joined to a game window, which waits for that window to hand it over
//      Paulinchen  2026-11-05: Scrolled a list whose columns changed so its cursor stays in sight
//                            - Told a list that shows a page of its rows at a time to turn it by the shoulders that page it
//                            - Told a root that guards its cancel whether a gamepad cancelled, so the game's letters
//                              take a letter away
//                            - Stepped a numeric field within its bounds by the arrows, the wheel and a click on an arrow
//                              while it does not type, typed into it as into a text field, and stepped what it types by Up
//                              and Down
//                            - Confirmed a text field by a key bound to confirm that types nothing into it
//                            - Held every key and the pointer for a part that waits for the key the player presses to bind a hotkey
//                            - Told a box the keys enter when the focus went inside it and when it came out
//                            - Gave a disabled part no hover light, no wheel and no toggle, and a disabled row no frame and no drag
//      Paulinchen  2026-11-04: Placed the roots in the nine zones and along the edges of the screen, and beside a part or a
//                              place, and hid the roots a full zone has no room for
//                            - Closed a root above the focus that takes the keys but holds nothing for them, such as a
//                              popover of text, on cancel before the root the focus lies in
//                            - Told the layout where the part lies that a root lies beside, and asked it for the places the
//                              player left on the screen of now
//                            - Kept the focus on a text field of a root of the new UI layer whose typing its first cancel stopped
//                            - Told the hotkeys whose key a screen uses as one of the game's extra buttons
//                            - Sent the submit of a list that does not take it up to the nearest part that does
//                            - Opened a part's context menu by a right click, the Menu key or a gamepad's confirm held, and
//                              took a right click elsewhere in a root of the new UI layer and in the context menu as cancel
//                            - Moved the focus out of a list or a row of a root of the new UI layer by an arrow with the jump
//                              key or the game's A held
//                            - Told the nearest part from the focus upward that takes one of the game's extra buttons
//                              that it went down
//                            - Wrapped a list of a root of the new UI layer on a fresh press at its end, and kept the focus
//                              in a row that uses LEFT and RIGHT itself at its ends there
//                            - Lit no part under the pointer in a window of the new UI layer, whose lists frame the row there
//                            - Walked cancel in a root of the new UI layer back the way the focus came into a page, and
//                              stopped a typing text field there on its first cancel
//                            - Split the game's L and R by device in a root of the new UI layer, stepped its tabs by Tab and
//                              the pad's shoulders without being told to, took Tab into its first text field and back,
//                              and pressed the parts whose declared hotkey went down unless it is quiet
//                            - Closed a root by its declared hotkey and told the reason
//                            - Started the focus of a root that opens on its component marked for it, and moved the focus
//                              from a component of a root of the new UI layer that hides or turns off to the key stop
//                              nearest it
//                            - Laid out only the roots whose components changed, and kept the roots in one list ordered
//                              from the bottom to the top
//                            - Took the good changes of a batch and told each refused one, and asked the scripts to send
//                              the whole tree again after a batch it could not read
//      Paulinchen  2026-11-01: Let tabs be one key stop above their pages: LEFT and RIGHT step them, DOWN and confirm enter
//                              the page shown, and the focus a script puts into a container goes onto the part it held
//                              last
//                            - Picked a list's row at once by a click on its box, also while the cursor stood elsewhere
//                            - Kept the focus in a box asked to at its ends
//                            - Noted the part every container held the focus on last, which LEFT and RIGHT move back onto
//                            - Picked a row of a list at once by a click on it when the list asks for it, the second
//                              click of that double click pressing nothing the pick showed under the pointer
//                            - Told a text field a cancel key left it
//                            - Shifted the digits typed into a number field in from the right until a digit is picked
//                            - Took no keys while a box outside the tree holds the game's buttons, such as another
//                              mod's chat box
//                            - Stepped a root's tabs by a gamepad's L and R while a text field in it types, and handed a
//                              gamepad's UP and DOWN to a field that claims the arrow keys
//      Paulinchen  2026-10-31: Took the game's cancel keys from the key settings of F1, typed a bound letter in a text field
//                              and the numpad's 0 into one that takes only digits
//                            - Took the confirm, L and R keys from the key settings of F1 too, left a text field by a
//                              cancel key it types nothing of, and had a key that left one type nothing
//                            - Kept a root from the presses that went down before it opened or in the tick it opened
//                            - Placed the roots docked at a corner of the screen and told the room each dock takes
//                            - Told a list a pick of a row that takes none
//                            - Told a component that takes the mouse wheel itself the wheel's notches
//                            - Set a number field digit by digit: the arrows pick and turn a digit, the number row's
//                              digits set one, a click picks one and the wheel turns the one under the pointer
//                            - Told a text field the keys it claims with Alt held apart from those without, and kept a
//                              field typed into only once confirmed as a plain key stop until then, its cancel putting
//                              back its text
//                            - Clicked a container as one part, moved the focus into a container the keys stop on as a
//                              whole by confirm and back out by cancel, gave the focus to the first part inside a
//                              component, and stepped tabs by LEFT and RIGHT where the focused part had no use for them
//                            - Moved a list's cursor onto the toggles of its row and back by LEFT and RIGHT, told a toggle
//                              confirmed or clicked, and went round at a list's ends
//                            - Closed a root on a left click outside it, the click going no further, and buzzed a
//                              click on a button of a root under another that holds the game's buttons
//      Paulinchen  2026-10-30: Handed LEFT and RIGHT to the scripts only on the rows of a list that have a value
//                            - Moved the focus from a list of columns at its side with nothing beside it into the page
//                              beside in a slides, or slid it
//                            - Moved the focus on from a list of columns and a text field that hand it on past their
//                              sides, and up from a list to the text field that steers it
//                            - Told a root that asks for it an arrow that found no component to move the focus to
//                            - Handed LEFT and RIGHT on a list of values to the scripts and kept the pick of a quiet
//                              list silent
//                            - Passed the heading rows of a list over by the keys and the pointer
//                            - Moved the focus on from a list that hands it on past its first and last line
//                            - Let a list carry a row to another place by the keys or a drag of the pointer
//      Paulinchen  2026-10-29: Moved the cursor of a list that shows its rows in columns along its lines and between
//                              its columns, and hit its rows by both sides of the pointer
//                            - Handed the game's L and R that the focused component did not use to its root
//                            - Moved the focus where a component sends cancel, slid a slides back on cancel and gave
//                              the focus to a component made anew with the key of the one it replaced
//                            - Left the late cancel of the numpad's 0 to the game when it cancelled nothing
//                            - Hit and scrolled components shifted from their places where they are drawn
//                            - Let LEFT and RIGHT move a slides, L and R step its root's tabs and the arrows scroll
//                              a focused box
//                            - Asked a root that guards its cancel instead of closing it
//                            - Showed the tooltip of a component focused by a key at once
//                            - Let a list keep its cursor under the pointer and frame the row there
//                            - Let LEFT and RIGHT move the focus out of a list
//                            - Kept a click on a quiet component silent
//                            - Left L and R to a list that the shoulder buttons do not page
//                            - Kept a press on a component only the pointer reaches from taking the focus, let a
//                              press on a place of a key stop focus the stop, and stepped a key stop by LEFT and
//                              RIGHT
//                            - Let Tab and a gamepad's shoulder buttons step tabs
//                            - Kept the tooltip a key's focus showed while another window is in front
//                            - Let a gamepad's UP and DOWN leave a field of one line
//      Paulinchen  2026-10-28: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;
using MGQParadox.ModFramework.Input;
using MGQParadox.ModFramework.Options;
using MGQParadox.ModFramework.Ui.Layout;
using MGQParadox.ModFramework.Ui.Text;

namespace MGQParadox.ModFramework.Ui.Tree;

/// <summary>
/// The components of the mods as a tree (the scripts' Component nodes): it lays them out, finds
/// what the pointer is on, keeps the hover, the press, the focus and the scrolling, and turns the
/// pointer, the game's buttons and the keys into the components' events.
/// </summary>
/// <remarks>
/// The scripts put the tree after the input model and the layout in each tick, so it reads the
/// tick's own pointer, keys and dragged places. Outside a focused text field it takes confirm,
/// cancel and the arrows only from the game's buttons, so one Enter press is one press; inside one
/// it takes them from the keys, so typing an x or a z never cancels or confirms.
/// </remarks>
internal sealed partial class ComponentTree : IUiModel
{
    /// <summary>
    /// The model's name in the tick, whose input is {"add" => [[id, parent id or nil, kind, index or
    /// nil, props]], "set" => [[id, props]], "remove" => [ids], "screen" => [width, height],
    /// "focus" => id, "focus_in" => id (the part inside it that held the focus last, else its first,
    /// takes the focus; a list without a row is passed over, and a part that holds no others takes
    /// it itself), "blur" => id, "hotkeys" => {name => [key code, why it is off its scenes or nil]}},
    /// each optional. The props are the layout and input properties: layout gap padding justify wrap
    /// columns span corner align grow size width height min max at column column_hold center visible enabled mouse z modal closable
    /// movable resizable focusable acts repeats aside autofocus scroll rows row_height text font escapes measured layout_id keys
    /// row_cells index layer captures pages hotkey extra_buttons context_menu submits shoulders disabled_rows heading_rows sides value_rows leave_ends keep_ends leave_sides up_to caret_ends takes close_outside held_under clicks dock dock_order mouse_parts most_lines toggle_rows box_ends round clickable enter tail fit_columns arrows confirm_to_type typing digits number digit_cell wheel_told tooltip follow_pointer shoulder_pages quiet scroll_top inert offset
    /// shrink shown slide_keys shoulder tab_page cancel_guard leave_told whole_rows cancel_to slide_back focus_key
    /// jump_only pages_beside drag drop_zone drop_container tabs_shown.
    /// </summary>
    public const string ModelName = "tree";

    /// <summary>
    /// The tree's event, with only what changed since the last: {"rects" => {id => [x, y, width,
    /// height]}, "states" => {id => bits of <see cref="Hovered"/>, <see cref="Pressed"/> and
    /// <see cref="Focused"/>}, "scroll" => {id => [top, shown, total]}, "padding_cut" => {id => [top,
    /// right, bottom, left] of its padding that gave way}, "events" => [[id, name,
    /// value]], "cues", "taken" => [key codes the tree acted on], "refused" => [[id, why, whether the
    /// component was left out of the tree]], "quiet" => [[hotkey, why it did nothing, whether that is a clash with a game
    /// button, logged once]], "clashes" => {hotkey => why a screen uses its key as a game button}, "resync" => why the tree could not read a batch and was
    /// emptied, so the scripts send every root again, "late" => bits of the game's
    /// buttons that came a tick after the key the tree took them from, "order" => [root ids from the
    /// bottom to the top], "over" => the root under the pointer or nil, "tooltip" => [id, x, y] at
    /// the pointer, [id, x, y, true] under a component a key focused, or nil, "docks" => {dock =>
    /// the pixels its shown roots at their default places take from its edge}}. The events are click,
    /// change (row), submit (row, or none for a text field's confirm from a gamepad; row and the list
    /// to a part that takes the submit of a list inside it that does not), close ("outside"
    /// for a click outside a root that closes on one, "hotkey" for its declared hotkey, else none), focus,
    /// blur, hover (inside), toggle (row and toggle: confirm on a toggle of a list's row),
    /// context (x and y: where its context menu opens, by a right click, the Menu key or a gamepad's
    /// confirm held), toggle_cursor (row and toggle, -1 for the row's text: the cursor moved onto a toggle or off it),
    /// refuse (row: a pick of a list's row that takes none), wheel (notches, to a component that takes the wheel itself), number (a number field's number changed), pick (a number field's digit picked, 0 the leftmost), type (digit: a digit of the number row that starts typing a number field),
    /// cancelled (a cancel key left a text field that types and asks for it, before the focus moves on),
    /// row_click (row and whether it held the cursor: a click on a row that has toggles), hover_row (the row under the pointer of a list whose cursor does not
    /// follow it, -1 for none), side (row and -1 or 1, LEFT or RIGHT on a list of values), key (code), step (-1 or 1, a select's value or a row of tabs'
    /// tab), slide (-1 or 1, a slides' page), back (a slides cancel moves back a page), cancel (a
    /// root that guards its cancel; "outside" for a click outside it, "pad" for a gamepad's cancel), page (-1 or 1 and whether a gamepad pressed it, to a root:
    /// the game's L or R that the focused component did not use; in a root of the UI layer to the
    /// nearest part from the focus upward that takes the page step), button (A, X, Y or Z: one of the
    /// game's extra buttons went down, to the nearest part from the focus upward that takes it, in a
    /// root of the UI layer) and leave (left, right, up or down,
    /// to a root that asks for it: an arrow that found no component of it to move the focus to).
    /// </summary>
    /// <remarks>
    /// The scripts draw the roots in "order" within each depth, since a press or a show raises a
    /// root above the others of its depth; and they keep the "late" buttons from the scene for the
    /// tick, as the root their key closed no longer holds them.
    /// </remarks>
    public const string EventTopic = "ui.tree";

    /// <summary>
    /// Takes the changes queued after the tick, as the tick's input without the frame's input, and
    /// answers what changed, as the event says it.
    /// </summary>
    public const string LayoutTopic = "ui.tree.layout";

    /// <summary>
    /// Forgets every component, for F12.
    /// </summary>
    public const string ResetTopic = "ui.tree.reset";

    /// <summary>
    /// Ticks the pointer rests on a component before its tooltip shows.
    /// </summary>
    public const int TooltipFrames = 30;

    /// <summary>
    /// The state bit of the component under the pointer.
    /// </summary>
    public const int Hovered = 1;

    /// <summary>
    /// The state bit of the component the left button went down on, while the pointer stays on it.
    /// </summary>
    public const int Pressed = 2;

    /// <summary>
    /// The state bit of the component holding the focus.
    /// </summary>
    public const int Focused = 4;

    /// <summary>Windows' code of Tab.</summary>
    public const int TabKey = 0x09;

    /// <summary>Windows' code of Shift.</summary>
    public const int ShiftKey = 0x10;

    /// <summary>Windows' code of Enter.</summary>
    public const int EnterKey = 0x0D;

    /// <summary>Windows' code of Escape.</summary>
    public const int EscapeKey = 0x1B;

    /// <summary>Windows' code of the space bar.</summary>
    public const int SpaceKey = 0x20;

    /// <summary>Windows' code of Insert, the numpad's 0 with Num Lock off.</summary>
    public const int InsertKey = 0x2D;

    /// <summary>Windows' code of Page Up.</summary>
    public const int PageUpKey = 0x21;

    /// <summary>Windows' code of Page Down.</summary>
    public const int PageDownKey = 0x22;

    /// <summary>Windows' code of Q, one of the game's L keys.</summary>
    public const int QKey = 0x51;

    /// <summary>Windows' code of W, one of the game's R keys.</summary>
    public const int WKey = 0x57;

    /// <summary>Windows' code of the up arrow.</summary>
    public const int UpKey = 0x26;

    /// <summary>Windows' code of the down arrow.</summary>
    public const int DownKey = 0x28;

    /// <summary>Windows' code of X, one of the game's cancel keys.</summary>
    public const int XKey = 0x58;

    /// <summary>Windows' code of Z, one of the game's confirm keys.</summary>
    public const int ZKey = 0x5A;

    /// <summary>Windows' code of the numpad's 0 with Num Lock on.</summary>
    public const int NumpadZero = 0x60;

    /// <summary>Windows' code of the Menu key, which opens a context menu.</summary>
    public const int MenuKey = 0x5D;

    /// <summary>
    /// The host the tree posts on.
    /// </summary>
    private readonly UiHost _host;

    /// <summary>
    /// The input model of the same host.
    /// </summary>
    private readonly InputModel _input;

    /// <summary>
    /// The layout that keeps where the player put a root, null for none.
    /// </summary>
    private readonly LayoutModel? _layout;

    /// <summary>
    /// The layout of the components.
    /// </summary>
    private readonly Flow _flow;

    /// <summary>
    /// The text box being typed into, which a key that left a text field types nothing into; null
    /// for none.
    /// </summary>
    private readonly EditModel? _edit;

    /// <summary>
    /// The keys of the game's buttons read for the key settings of F1 they were read from.
    /// </summary>
    private (ButtonAssignment Binding, int[] Confirm, int[] Cancel, int[] Shoulder, int[] CancelBound)? _keys;

    /// <summary>
    /// Every component by its id.
    /// </summary>
    private readonly Dictionary<int, Node> _nodes = [];

    /// <summary>
    /// The roots in the order they opened.
    /// </summary>
    private readonly List<Node> _roots = [];

    /// <summary>
    /// The roots laid out or scrolled since the last report, whose components' places and
    /// scrolling the report compares.
    /// </summary>
    private readonly HashSet<Node> _moved = [];

    /// <summary>
    /// The fonts texts are measured in, null to measure no text.
    /// </summary>
    private readonly UiText? _text;

    /// <summary>
    /// Whether the roots' order changed since the last report.
    /// </summary>
    private bool _orderChanged;

    /// <summary>
    /// The screen's size at the last layout, null before it.
    /// </summary>
    private (int Width, int Height)? _settledScreen;

    /// <summary>
    /// How many character widths the fonts had learned at the last layout.
    /// </summary>
    private long _settledLearned = -1;

    /// <summary>
    /// The lists whose cursor, rows or columns the scripts set, scrolled to show the cursor after the layout.
    /// </summary>
    private readonly HashSet<Node> _cursorsSet = [];

    /// <summary>
    /// The places the scripts were told last, by id.
    /// </summary>
    private readonly Dictionary<int, LayoutRect> _postedRects = [];

    /// <summary>
    /// The scrolling the scripts were told last, by id.
    /// </summary>
    private readonly Dictionary<int, (int Top, int Shown, int Total)> _postedScroll = [];

    /// <summary>
    /// What of its padding gave way, as the scripts were told it last, by id.
    /// </summary>
    private readonly Dictionary<int, Insets> _postedCuts = [];

    /// <summary>
    /// The states the scripts were told last, by id, none for a component with no state.
    /// </summary>
    private Dictionary<int, int> _postedStates = [];

    /// <summary>
    /// The events since the last report.
    /// </summary>
    private RubyArray _events = [];

    /// <summary>
    /// The sounds since the last report.
    /// </summary>
    private RubyArray _cues = [];

    /// <summary>
    /// The key codes acted on since the last report.
    /// </summary>
    private RubyArray _taken = [];

    /// <summary>
    /// The roots from the bottom to the top as the scripts were told it.
    /// </summary>
    private List<int> _postedOrder = [];

    /// <summary>
    /// The room each dock takes, as last laid out.
    /// </summary>
    private Dictionary<string, int> _dockRooms = [];

    /// <summary>
    /// Whether the room of a dock changed since the last report.
    /// </summary>
    private bool _docksChanged;

    /// <summary>
    /// Whether a root hid or showed again for want of room since the last report.
    /// </summary>
    private bool _crowdedChanged;

    /// <summary>
    /// The bits of the game's buttons that came late since the last report.
    /// </summary>
    private int _late;

    /// <summary>
    /// The screen size the scripts named, null to take the input model's.
    /// </summary>
    private (int Width, int Height)? _screen;

    /// <summary>
    /// The count roots are raised by, which orders roots of the same depth.
    /// </summary>
    private long _raise;

    /// <summary>
    /// Whether the cancel taken now came from a gamepad: the game's cancel without a key of it down.
    /// </summary>
    private bool _padCancel;

    /// <summary>
    /// The component holding the focus, null for none.
    /// </summary>
    private Node? _focus;

    /// <summary>
    /// The component under the pointer, null for none.
    /// </summary>
    private Node? _hover;

    /// <summary>
    /// The component the left button went down on and is still held over, null for none.
    /// </summary>
    private Node? _pressed;

    /// <summary>
    /// The row of a list the left button went down on, -1 for none.
    /// </summary>
    private int _pressedRow = -1;

    /// <summary>
    /// Whether that row held the cursor already, so letting go on it submits it.
    /// </summary>
    private bool _pressedOnCursor;

    /// <summary>
    /// Whether the press was the second of a double click.
    /// </summary>
    private bool _pressedTwice;

    /// <summary>
    /// The list and row a click last submitted, which the second click of a double click does not
    /// submit again.
    /// </summary>
    private (Node List, int Row)? _lastSubmit;

    /// <summary>
    /// Whether the last click let go submitted a list's row.
    /// </summary>
    /// <remarks>
    /// A row a click submits may open a page whose buttons come up under the pointer, which the
    /// second click of a double click would press.
    /// </remarks>
    private bool _clickSubmitted;

    /// <summary>
    /// The scrollbar thumb being dragged and where on it the pointer took it, null for none.
    /// </summary>
    private (Node Node, int Grab)? _thumb;

    /// <summary>
    /// The slider whose knob the pointer drags, null for none.
    /// </summary>
    private Node? _slid;

    /// <summary>
    /// The rating under the pointer and the cell under it as the scripts were told them, nulls for
    /// none.
    /// </summary>
    private (Node? Node, int? Cell) _preview;

    /// <summary>
    /// Where the pointer was at the last tick.
    /// </summary>
    private (int X, int Y)? _lastPointer;

    /// <summary>
    /// The root under the pointer as the scripts were told it.
    /// </summary>
    private int? _over;

    /// <summary>
    /// Whether the root under the pointer changed since the last report.
    /// </summary>
    private bool _overChanged;

    /// <summary>
    /// The component whose tooltip the pointer rests on, null for none.
    /// </summary>
    private Node? _tipNode;

    /// <summary>
    /// Ticks the pointer rested on it, -1 after a press until the pointer moves.
    /// </summary>
    private int _rest;

    /// <summary>
    /// The tooltip shown and whether a key's focus showed it, null for none.
    /// </summary>
    private (int Id, int X, int Y, bool ByFocus)? _tip;

    /// <summary>
    /// The list whose cursor does not follow the pointer and its row the pointer is on, null for none.
    /// </summary>
    private (Node List, int Row)? _hoverRow;

    /// <summary>
    /// Whether the tooltip changed since the last report.
    /// </summary>
    private bool _tipChanged;

    /// <summary>
    /// The changes refused since the last report, each [id, why, whether the component was left out].
    /// </summary>
    private RubyArray _refused = [];

    /// <summary>
    /// Why the tree could not read the scripts' last changes and forgot every component, null while it read them all.
    /// </summary>
    private string? _resync;

    /// <summary>
    /// Whether a box scrolled, so what it holds moved and the tree lays out again.
    /// </summary>
    private bool _relayout;

    /// <summary>
    /// Whether the tree took a key of the game's cancel at the last tick while the game's cancel
    /// did not go down.
    /// </summary>
    private bool _cancelKeyFirst;

    /// <summary>
    /// Whether the tree took a key of the game's confirm at the last tick while the game's confirm
    /// did not go down.
    /// </summary>
    private bool _confirmKeyFirst;

    /// <summary>
    /// The part a gamepad's confirm is held on, which a context menu opens on once it is held long
    /// enough, with the ticks it is held; null for none.
    /// </summary>
    private (Node Focus, int Ticks)? _heldConfirm;

    /// <summary>
    /// The ticks counted, which tell a root opened in this tick.
    /// </summary>
    private long _ticks;

    /// <summary>
    /// Creates the tree, registers its topics and has the input model watch the keys it reads.
    /// </summary>
    /// <param name="host">The host of the interface's models.</param>
    /// <param name="input">The input model of the same host.</param>
    /// <param name="layout">The layout that keeps where the player put a root, null for none.</param>
    /// <param name="text">The fonts texts are measured in, null to measure no text.</param>
    /// <param name="edit">The text box being typed into, null for none.</param>
    public ComponentTree(UiHost host, InputModel input, LayoutModel? layout, UiText? text, EditModel? edit = null)
    {
        ArgumentNullException.ThrowIfNull(host);
        ArgumentNullException.ThrowIfNull(input);
        _host = host;
        _input = input;
        _layout = layout;
        _edit = edit;
        _text = text;
        _flow = new Flow(text);
        foreach (int code in new[] { TabKey, EnterKey, EscapeKey, SpaceKey, InsertKey, PageUpKey, PageDownKey, UpKey, DownKey, XKey, ZKey, NumpadZero, QKey, WKey, MenuKey,
                                     0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39 })
        {
            input.Watch(code);
        }

        BridgeContext context = host.Context;
        context.Register(LayoutTopic, (_, request) =>
        {
            TryChange(request);
            Settle();
            return Report();
        });
        context.Register(ResetTopic, (_, _) =>
        {
            Reset();
            return null;
        });
    }

    /// <inheritdoc />
    public string Name => ModelName;

    /// <summary>
    /// Takes the scripts' changes, lays the tree out, follows the pointer, the game's buttons and
    /// the keys of the tick, and posts what changed as <see cref="EventTopic"/>.
    /// </summary>
    /// <param name="input">The changes, see <see cref="ModelName"/>.</param>
    public void Tick(RubyValue input)
    {
        _ticks++;
        TryChange(input);
        Settle();
        FindCapture();
        if (_capture is not null)
        {
            FollowCapture(_host.Buttons);
        }
        else if (_input.Front)
        {
            FollowPointer();
        }
        else
        {
            Away();
        }

        if (_capture is not null || _captureHeld != 0)
        {
            _cancelKeyFirst = _confirmKeyFirst = false;
        }
        else
        {
            FollowKeys(_host.Buttons);
        }

        if (_capture is null && _captureHeld == 0)
        {
            FollowHotkeys();
        }

        _captureHeld = _capture is null ? 0 : _captureHeld;
        if (_relayout)
        {
            _relayout = false;
            Settle();
        }

        RubyHash report = Report();
        if (report.Count > 0)
        {
            _host.Post(EventTopic, report);
        }
    }

    /// <summary>
    /// Tells whether one root lies above another.
    /// </summary>
    /// <param name="one">One root.</param>
    /// <param name="other">The other.</param>
    /// <returns>Whether the first does: a higher depth, or the same depth raised later.</returns>
    private static bool Above(Node one, Node other) => one.Z != other.Z ? one.Z > other.Z : one.Raise > other.Raise;

    /// <summary>
    /// Tells whether a component lies in another or is it.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="other">The other.</param>
    /// <returns>Whether it does.</returns>
    private static bool Inside(Node node, Node other)
    {
        for (Node? step = node; step is not null; step = step.Parent)
        {
            if (step == other)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Tells whether a component plays the confirm sound when it is clicked.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>Whether it does.</returns>
    private static bool Pressable(Node node) => node.Clickable || node.Kind is NodeKind.Button or NodeKind.IconButton or NodeKind.Checkbox or NodeKind.Select;

    /// <summary>
    /// Tells whether a root opened in this tick, whose keys and presses of this tick are older than it.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <returns>Whether it did.</returns>
    private bool Fresh(Node root) => root.OpenedAt == _ticks;

    /// <summary>
    /// Lists the roots shown, topmost first.
    /// </summary>
    /// <returns>The roots.</returns>
    private List<Node> TopFirst()
    {
        var shown = new List<Node>(_roots.Count);
        for (int index = _roots.Count - 1; index >= 0; index--)
        {
            if (_roots[index].Visible && !_roots[index].Crowded)
            {
                shown.Add(_roots[index]);
            }
        }

        return shown;
    }

    /// <summary>
    /// Lists every root's id, shown or not, from the bottom to the top.
    /// </summary>
    /// <returns>The ids.</returns>
    private List<int> BottomFirst() => _roots.ConvertAll(root => root.Id);

    /// <summary>
    /// Puts a root at its place in the roots, which stay ordered from the bottom to the top.
    /// </summary>
    /// <param name="root">The root, new or raised.</param>
    private void Rank(Node root)
    {
        _roots.Remove(root);
        int index = _roots.FindIndex(other => Above(other, root));
        _roots.Insert(index < 0 ? _roots.Count : index, root);
        _orderChanged = true;
    }

    /// <summary>
    /// Lists the roots shown that take input, topmost first: those down to the topmost modal one.
    /// </summary>
    /// <returns>The roots.</returns>
    private List<Node> Unblocked()
    {
        var open = new List<Node>();
        foreach (Node root in TopFirst())
        {
            open.Add(root);
            if (root.Modal)
            {
                break;
            }
        }

        return open;
    }

    /// <summary>
    /// Tells whether a modal root shown lies above a root.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <returns>Whether one does.</returns>
    private bool Blocked(Node root)
    {
        for (int index = _roots.Count - 1; index >= 0 && _roots[index] != root; index--)
        {
            if (_roots[index].Visible && _roots[index].Modal)
            {
                return true;
            }
        }

        return false;
    }

    /// <summary>
    /// Takes the scripts' changes, or forgets every component when they cannot be read, so the
    /// scripts send the whole tree again instead of the two trees drifting apart.
    /// </summary>
    /// <param name="input">The changes, see <see cref="ModelName"/>.</param>
    private void TryChange(RubyValue input)
    {
        try
        {
            Change(input.AsHash());
        }
        catch (Exception error) when (error is BridgeRequestException or RubyValueException or ArgumentException)
        {
            Reset();
            _resync = error.Message;
        }
    }

    /// <summary>
    /// Takes the scripts' changes: the screen, new components, changed properties, removed
    /// components, then the focus of roots that opened or showed and the focus the scripts asked
    /// for. A component or a property that is refused is told in the report, and the rest is
    /// still taken.
    /// </summary>
    /// <param name="changes">The changes, see <see cref="ModelName"/>.</param>
    /// <exception cref="RubyValueException">The changes are not shaped as <see cref="ModelName"/> says.</exception>
    private void Change(RubyHash changes)
    {
        (int Width, int Height)? screen = null;
        if (changes.TryGetValue("screen", out RubyValue? size) && !size.IsNil)
        {
            RubyArray pair = size.AsArray();
            screen = (Math.Max(pair[0].AsInt(), 1), Math.Max(pair[1].AsInt(), 1));
        }

        List<(Node Node, int? Parent, int? Index)> adds = Adds(changes["add"]);
        List<(Node Node, RubyHash Props)> sets = Sets(changes["set"], adds);
        var removes = new List<int>();
        foreach (RubyValue id in changes["remove"].IsNil ? [] : changes["remove"].AsArray())
        {
            removes.Add(id.AsInt());
        }

        int? focus = changes["focus"].IsNil ? null : changes["focus"].AsInt();
        int? blur = changes["blur"].IsNil ? null : changes["blur"].AsInt();
        int? focusIn = changes["focus_in"].IsNil ? null : changes["focus_in"].AsInt();
        TakeHotkeys(changes["hotkeys"]);

        _screen = screen ?? _screen;
        var opened = new List<Node>();
        foreach ((Node node, int? parent, int? index) in adds)
        {
            Insert(node, parent, index, opened);
        }

        foreach ((Node node, RubyHash props) in sets)
        {
            bool hidden = !node.Visible;
            int z = node.Z;
            Refuse(node.Id, node.Apply(props), false);
            if (props.ContainsKey("index") || props.ContainsKey("rows") || props.ContainsKey("row_cells"))
            {
                _cursorsSet.Add(node);
            }

            if (node.IsRoot && hidden && node.Visible)
            {
                node.Raise = ++_raise;
                opened.Add(node);
            }

            if (node.IsRoot && (node.Z != z || opened.Contains(node)) && _roots.Contains(node))
            {
                Rank(node);
            }
        }

        foreach (Node slider in adds.Select(add => add.Node).Concat(sets.Select(set => set.Node)).Where(node => node.Kind == NodeKind.Slider))
        {
            SlideTo(slider, Fit(slider, slider.Number));
        }

        foreach (int id in removes)
        {
            if (_nodes.TryGetValue(id, out Node? node))
            {
                Remove(node);
            }
        }

        foreach (Node root in opened)
        {
            root.OpenedAt = _ticks;
            root.HeldAtOpen = _host.Buttons.Bits >> (2 * UiButtons.Count);
            root.HeldExtraAtOpen = _host.ExtraButtons.Bits >> (2 * UiExtraButtons.Count);
            Opened(root);
        }

        if (focus is int wanted && _nodes.TryGetValue(wanted, out Node? asked))
        {
            TryFocus(asked);
        }

        if (blur is int left && _focus?.Id == left)
        {
            Blur(forget: true);
        }

        if (focusIn is int scope && _nodes.TryGetValue(scope, out Node? holder) &&
            Focus.Into(holder) is { } inside)
        {
            TryFocus(inside);
        }
    }

    /// <summary>
    /// Reads the components to add and makes them, not yet in the tree. One with a taken id or an
    /// unknown kind is left out with what it holds, and a property refused leaves the component
    /// without it; each is told in the report.
    /// </summary>
    /// <param name="value">Each [id, parent id or nil, kind, index or nil, props or nil], nil for none; one whose parent no component has is left out, with what it holds.</param>
    /// <returns>Each component with its parent and its index among the parent's children.</returns>
    /// <exception cref="RubyValueException">An entry is not shaped as the tick's "add" says.</exception>
    private List<(Node Node, int? Parent, int? Index)> Adds(RubyValue value)
    {
        var adds = new List<(Node, int?, int?)>();
        var ids = new HashSet<int>();
        foreach (RubyValue entry in value.IsNil ? [] : value.AsArray())
        {
            RubyArray add = entry.AsArray();
            int id = add[0].AsInt();
            int? parent = add[1].IsNil ? null : add[1].AsInt();

            // The tree closes roots by itself, and the scripts may add to one before they hear of it.
            if (parent is int owner && !_nodes.ContainsKey(owner) && !ids.Contains(owner))
            {
                continue;
            }

            if (_nodes.ContainsKey(id) || !ids.Add(id))
            {
                Refuse(id, [$"A component with the id {id} was added already."], true);
                continue;
            }

            Node node;
            try
            {
                node = new Node(id, Node.KindOf(add[2].AsText()));
            }
            catch (BridgeRequestException error)
            {
                ids.Remove(id);
                Refuse(id, [error.Message], true);
                continue;
            }

            if (add.Count > 4 && !add[4].IsNil)
            {
                Refuse(id, node.Apply(add[4].AsHash()), false);
            }

            adds.Add((node, parent, add[3].IsNil ? null : add[3].AsInt()));
        }

        return adds;
    }

    /// <summary>
    /// Reads the properties to set.
    /// </summary>
    /// <param name="value">Each [id, props], nil for none; an id no component has is left out.</param>
    /// <param name="adds">The components added in the same change, which may be set too.</param>
    /// <returns>Each component with its properties.</returns>
    /// <exception cref="RubyValueException">An entry is not shaped as the tick's "set" says.</exception>
    private List<(Node Node, RubyHash Props)> Sets(RubyValue value, List<(Node Node, int? Parent, int? Index)> adds)
    {
        var sets = new List<(Node, RubyHash)>();
        foreach (RubyValue entry in value.IsNil ? [] : value.AsArray())
        {
            RubyArray pair = entry.AsArray();
            int id = pair[0].AsInt();
            Node? node = _nodes.GetValueOrDefault(id) ?? adds.Find(add => add.Node.Id == id).Node;
            if (node is not null)
            {
                sets.Add((node, pair[1].AsHash()));
            }
        }

        return sets;
    }

    /// <summary>
    /// Tells the scripts each change of a component the tree refused.
    /// </summary>
    /// <param name="id">The component.</param>
    /// <param name="why">Why each change was refused.</param>
    /// <param name="left">Whether the component was left out of the tree.</param>
    private void Refuse(int id, List<string> why, bool left)
    {
        foreach (string reason in why)
        {
            _refused.Add(new RubyArray { id, reason, left });
        }
    }

    /// <summary>
    /// Puts a new component into the tree: a root on top of its depth, a child at its index.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="parent">Its parent's id, null for a root.</param>
    /// <param name="index">Its index among the parent's children, null for the end.</param>
    /// <param name="opened">Where a new root goes.</param>
    private void Insert(Node node, int? parent, int? index, List<Node> opened)
    {
        if (parent is int owner)
        {
            Node above = _nodes[owner];
            above.Children.Insert(Math.Min(Math.Max(index ?? above.Children.Count, 0), above.Children.Count), node);
            node.Parent = above;
            node.MarkDirty();
        }
        else
        {
            node.Raise = ++_raise;
            Rank(node);
            opened.Add(node);
        }

        _nodes[node.Id] = node;
        if (node.Cursor >= 0)
        {
            _cursorsSet.Add(node);
        }
    }

    /// <summary>
    /// Gives a window or a dialog that opened or showed again the focus: on the component that had
    /// it, else where its focus starts, or keeps that component for later while a modal root lies
    /// above it. The component it first opens on is its home. An item carried below a root that
    /// opens above it goes back where it came from.
    /// </summary>
    /// <param name="root">The root.</param>
    private void Opened(Node root)
    {
        EndCarryUnder();
        Node? last = root.LastFocus is { } kept && _nodes.ContainsKey(kept.Id) && Focus.CanHold(kept) ? kept : null;
        if (!_nodes.ContainsKey(root.Id) || !root.FocusesOnOpen || !root.Visible || (last ?? Focus.Start(root)) is not { } first)
        {
            return;
        }

        if (root.Home is null || !_nodes.ContainsKey(root.Home.Id))
        {
            root.Home = first;
        }

        if (Blocked(root))
        {
            KeepRootFocus(root, first);
        }
        else
        {
            TryFocus(first);
        }
    }

    /// <summary>
    /// Removes a component with everything it holds. The focus inside it, and the focus its root
    /// kept, go to a component of the root with the same focus key, else the focus goes to the
    /// root's first component when that root focuses on opening; a root removed with no focus left
    /// gives it back below.
    /// </summary>
    /// <param name="node">The component.</param>
    private void Remove(Node node)
    {
        bool hadFocus = _focus is not null && Inside(_focus, node);
        string? focusKey = hadFocus ? _focus!.FocusKey : null;
        Node root = Focus.RootOf(node);
        if (node.Parent is { } parent)
        {
            parent.Children.Remove(node);
            parent.MarkDirty();
        }
        else
        {
            _roots.Remove(node);
            _moved.Remove(node);
            _orderChanged = true;
        }

        Forget(node);
        if (root == node && root.LastFocus is { } closing)
        {
            TellBoxes(closing, null);
        }
        else if (root != node && root.LastFocus is { } last && Inside(last, node))
        {
            KeepRootFocus(root, last.FocusKey is string key ? Keyed(root, key) : null);
        }

        if (hadFocus)
        {
            _focus = null;
        }

        if (root == node && _focus is null)
        {
            Restore(null);
        }
        else if (hadFocus && !TryFocusKey(root, focusKey) && root.FocusesOnOpen && Focus.First(root) is { } first)
        {
            TryFocus(first);
        }
    }

    /// <summary>
    /// Gives the focus to the component of a focus key inside a root, as one made anew in place of
    /// the focused one.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <param name="key">The key, null for none.</param>
    /// <returns>Whether that component has the focus now.</returns>
    private bool TryFocusKey(Node root, string? key) => key is not null && Keyed(root, key) is { } keyed && TryFocus(keyed);

    /// <summary>
    /// Finds the component of a focus key inside a component.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="key">The key.</param>
    /// <returns>The component, itself or one it holds, null for none.</returns>
    private static Node? Keyed(Node node, string key)
    {
        if (node.FocusKey == key)
        {
            return node;
        }

        foreach (Node child in node.Children)
        {
            if (Keyed(child, key) is { } found)
            {
                return found;
            }
        }

        return null;
    }

    /// <summary>
    /// Forgets a component and everything it holds.
    /// </summary>
    /// <param name="node">The component.</param>
    private void Forget(Node node)
    {
        foreach (Node child in node.Children)
        {
            Forget(child);
        }

        _nodes.Remove(node.Id);
        _postedRects.Remove(node.Id);
        _postedScroll.Remove(node.Id);
        _postedCuts.Remove(node.Id);
        _cursorsSet.Remove(node);
        _hover = _hover == node ? null : _hover;
        _pressed = _pressed == node ? null : _pressed;
        _thumb = _thumb?.Node == node ? null : _thumb;
        _slid = _slid == node ? null : _slid;
        _dragFrom = _dragFrom?.Item == node ? null : _dragFrom;
        _preview = _preview.Node == node ? (null, null) : _preview;
        _lastSubmit = _lastSubmit?.List == node ? null : _lastSubmit;
        _hoverRow = _hoverRow?.List == node ? null : _hoverRow;
        if (_tipNode == node)
        {
            _tipNode = null;
            HideTip();
        }
        else if (_tip?.Id == node.Id)
        {
            HideTip();
        }
    }

    /// <summary>
    /// Forgets every component, as F12 starts the game's scenes again.
    /// </summary>
    private void Reset()
    {
        _nodes.Clear();
        _roots.Clear();
        _moved.Clear();
        _orderChanged = false;
        _settledScreen = null;
        _cursorsSet.Clear();
        _postedRects.Clear();
        _postedScroll.Clear();
        _postedCuts.Clear();
        _postedStates = [];
        _postedOrder = [];
        _late = 0;
        _events = [];
        _cues = [];
        _taken = [];
        _refused = [];
        _resync = null;
        (_focus, _hover, _pressed, _thumb, _lastSubmit, _tipNode, _tip, _hoverRow) = (null, null, null, null, null, null, null, null);
        (_over, _overChanged, _tipChanged, _relayout) = (null, false, false, false);
        _crowdedChanged = false;
    }

    /// <summary>
    /// Lays the tree out, keeps the lists' cursors within their rows and in sight, and moves the
    /// focus off a component that can no longer hold it.
    /// </summary>
    private void Settle()
    {
        (int width, int height) = _screen ?? _input.ScreenSize;
        long learned = _text?.WidthsLearned ?? 0;
        bool everything = _settledScreen != (width, height) || _settledLearned != learned;
        (_settledScreen, _settledLearned) = ((width, height), learned);
        _flow.Begin();
        var placed = new List<(Node Root, LayoutRect Rect, bool Dirty)>();
        var docked = new List<Docked>();
        var dockedAt = new List<int>();
        var besides = new List<Node>();
        var stacked = new List<Stacked>();
        var stackedAt = new List<int>();
        foreach (Node open in _roots)
        {
            if (!open.Visible && !(open.Column is not null && open.ColumnHold))
            {
                continue;
            }

            if (open.BesideNode is not null || open.BesideRect is not null)
            {
                besides.Add(open);
                continue;
            }

            LayoutRect? arranged = Arranges(open) ? _layout?.Arranged(open.LayoutId!, width, height) : null;
            bool dirty = everything || open.LayoutDirty || open.Placed is null || open.ArrangedAt != arranged;
            LayoutRect rect = dirty ? _flow.PlaceRoot(open, width, height, arranged) : open.Placed!.Value;
            (open.Placed, open.ArrangedAt) = (rect, arranged);
            if (open.Column is { } column)
            {
                stackedAt.Add(placed.Count);
                stacked.Add(new Stacked(column, open.Id, rect));
            }
            else if ((open.Dock is not null || open.Edge is not null) && !(arranged is not null && open.Movable))
            {
                dockedAt.Add(placed.Count);
                docked.Add(new Docked(open.Dock ?? Docks.Top, open.Edge, open.DockOrder, open.LoadOrder, open.Id, rect, open.GivesRoom, open.MinHeight + open.Margin.Vertical));
            }

            placed.Add((open, rect, dirty));
        }

        (LayoutRect[] places, bool[] crowded, Dictionary<string, int> rooms) = Docks.Place(docked, width, height);
        var crowdedNow = new HashSet<Node>();
        for (int index = 0; index < dockedAt.Count; index++)
        {
            (Node dockedRoot, _, bool dockedDirty) = placed[dockedAt[index]];
            placed[dockedAt[index]] = (dockedRoot, places[index], dockedDirty);
            if (crowded[index])
            {
                crowdedNow.Add(dockedRoot);
            }
        }

        LayoutRect[] columnPlaces = Docks.Stack(stacked);
        for (int index = 0; index < stackedAt.Count; index++)
        {
            (Node stackedRoot, _, bool stackedDirty) = placed[stackedAt[index]];
            placed[stackedAt[index]] = (stackedRoot, columnPlaces[index], stackedDirty);
        }

        foreach (Node root in _roots.Where(root => root.Crowded != crowdedNow.Contains(root)))
        {
            root.Crowded = !root.Crowded;
            _crowdedChanged = true;
        }

        foreach ((Node placedRoot, LayoutRect placedRect, bool dirty) in placed)
        {
            ArrangeRoot(placedRoot, placedRect, dirty);
        }

        foreach (Node open in besides)
        {
            PlaceBeside(open, width, height, everything);
        }

        if (!rooms.OrderBy(pair => pair.Key, StringComparer.Ordinal).SequenceEqual(_dockRooms.OrderBy(pair => pair.Key, StringComparer.Ordinal)))
        {
            _dockRooms = rooms;
            _docksChanged = true;
        }

        foreach (Node list in _cursorsSet)
        {
            if (list.Cursor >= list.Rows)
            {
                MoveCursor(list, list.Rows - 1, false);
            }

            Scroll.ShowCursor(list);
        }

        _cursorsSet.Clear();
        if (_focus is { } focus)
        {
            KeepFocus(focus);
        }
    }

    /// <summary>
    /// Tells whether the player arranges a root: it has a place id and moves or resizes.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <returns>Whether they do.</returns>
    private static bool Arranges(Node root) => root.LayoutId is not null && (root.Movable || root.Resizable != LayoutResize.None);

    /// <summary>
    /// Lays a root out at its place, with the compact forms its room needs, when it changed or the
    /// root holds a changed component.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <param name="rect">Its place.</param>
    /// <param name="dirty">Whether it holds a changed component.</param>
    private void ArrangeRoot(Node root, LayoutRect rect, bool dirty)
    {
        if (dirty || root.LaidOutAt != rect)
        {
            _flow.Fold(root, rect);
            _flow.Arrange(root, rect);
            root.LaidOutAt = rect;
            _moved.Add(root);
        }

        root.LayoutDirty = false;
    }

    /// <summary>
    /// Places a root beside the part or the place it names, after every other root, so a part of
    /// another root has its place of this layout. While what it names does not show, it stays where
    /// it was; the player's drag counts from what it names.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <param name="width">The screen's width.</param>
    /// <param name="height">The screen's height.</param>
    /// <param name="everything">Whether every root is laid out anew.</param>
    private void PlaceBeside(Node root, int width, int height, bool everything)
    {
        LayoutRect? target = root.BesideRect ?? (root.BesideNode is int id && _nodes.TryGetValue(id, out Node? part) ? ShownRect(part) : null);
        LayoutRect? arranged = null;
        if (Arranges(root) && _layout is { } layout)
        {
            layout.Anchor(root.LayoutId!, target);
            arranged = layout.Arranged(root.LayoutId!, width, height);
        }

        bool dirty = everything || root.LayoutDirty || root.Placed is null || root.ArrangedAt != arranged;
        LayoutRect size = dirty ? _flow.PlaceRoot(root, width, height, arranged) : root.Placed!.Value;
        (root.Placed, root.ArrangedAt) = (size, arranged);
        LayoutRect rect = arranged is not null && root.Movable ? size
                        : target is { } at ? Docks.Beside(at, size.Width, size.Height, root.BesideSide, root.Flip, root.LinesUpAtStart, width, height)
                        : root.LaidOutAt ?? size;
        ArrangeRoot(root, rect, dirty);
    }

    /// <summary>
    /// Tells where a component shows: its place while it, everything it lies in and its root show.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <returns>Its place, null while it does not show or was never laid out.</returns>
    private static LayoutRect? ShownRect(Node node)
    {
        for (Node? each = node; each is not null; each = each.Parent)
        {
            if (!each.Visible || each.Crowded)
            {
                return null;
            }
        }

        return node.Rect;
    }

    /// <summary>
    /// Moves the focus off a component that can no longer hold it, and keeps the focus of a root
    /// hidden or covered by a modal one for when it shows again.
    /// </summary>
    /// <remarks>
    /// Only roots of the UI layer use the nearest key stop, so the engine's own roots keep
    /// a turned-off focus and go back to their first key stop.
    /// </remarks>
    /// <param name="focus">The component holding the focus.</param>
    private void KeepFocus(Node focus)
    {
        Node root = Focus.RootOf(focus);
        bool rootAway = !root.Visible || Blocked(root);
        if (Focus.CanHold(focus) && !rootAway)
        {
            if (root.Layer && !Focus.Enabled(focus) && Focus.Nearest(root, focus) is { } other)
            {
                TryFocus(other);
            }

            return;
        }

        Node? next = rootAway || !root.FocusesOnOpen ? null : NextFocus(root, focus);
        Blur(forget: !rootAway);
        if (rootAway)
        {
            Restore(root);
        }
        else if (next is not null)
        {
            TryFocus(next);
        }
    }

    /// <summary>
    /// Finds where the focus goes from a component of a shown root that hid: in a root of the new UI
    /// layer into the page shown when its tab page hid, else to the key stop nearest it, and in any
    /// other root to its first key stop.
    /// </summary>
    /// <param name="root">The root it lies in.</param>
    /// <param name="focus">The component holding the focus.</param>
    /// <returns>The component, null when the root has none to give.</returns>
    private Node? NextFocus(Node root, Node focus) =>
        root.Layer ? IntoPageShown(focus) ?? Focus.Nearest(root, focus) : Focus.First(root);

    /// <summary>
    /// Finds where the focus goes when the tab page that holds it hid: into the page its tabs show
    /// now, onto the part it held there last.
    /// </summary>
    /// <param name="focus">The component holding the focus.</param>
    /// <returns>The component, null when no tab page of it hid or its tabs show no page yet.</returns>
    private Node? IntoPageShown(Node focus)
    {
        Node? hidden = focus;
        while (hidden is not null && hidden.Visible)
        {
            hidden = hidden.Parent;
        }

        return hidden is { TabPage: true, Parent: { Kind: NodeKind.Tabs } tabs } && Focus.PageShown(tabs) is { } page ? Focus.Into(page) : null;
    }

    /// <summary>
    /// Gives the focus back after a root closed or was left: to the topmost root taking input that
    /// still has the component that held its focus, in a root of the UI layer the key stop
    /// nearest it when it turned off meanwhile, or that focuses on opening, where its focus starts;
    /// a joined root waits for its game window to hand it the focus.
    /// </summary>
    /// <param name="left">A root just left, which does not get it back, null for none.</param>
    private void Restore(Node? left)
    {
        foreach (Node root in Unblocked())
        {
            if (root == left || root.Joined)
            {
                continue;
            }

            if (root.LastFocus is { } last && _nodes.ContainsKey(last.Id)
                && (TryFocus(last) || (root.Layer && Focus.CanHold(last) && !Focus.Enabled(last) && Focus.Nearest(root, last) is { } nearest && TryFocus(nearest))))
            {
                return;
            }

            if (root.FocusesOnOpen && Focus.Start(root) is { } first && TryFocus(first))
            {
                return;
            }
        }
    }

    /// <summary>
    /// Moves the focus to a component that may take it now: focusable, shown, taking input, in a
    /// root no modal root lies above.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="cancelled">Whether cancel moves it there, which notes no way back.</param>
    /// <returns>Whether it has the focus now.</returns>
    private bool TryFocus(Node node, bool cancelled = false)
    {
        if (!Focus.CanHold(node) || !Focus.Enabled(node) || Blocked(Focus.RootOf(node)))
        {
            return false;
        }

        SetFocus(node, cancelled);
        return true;
    }

    /// <summary>
    /// Moves the focus to a component, telling the one that had it and the one that gets it; the item
    /// carried goes back where it came from once the focus leaves its drop container.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="cancelled">Whether cancel moves it there, which notes no way back.</param>
    private void SetFocus(Node node, bool cancelled)
    {
        if (_focus == node)
        {
            return;
        }

        if (_focus is { } old)
        {
            DropOnBlur(old);
            old.EndRest();
            Event(old.Id, "blur");
        }

        HideFocusTip();
        EndCarryOutside(node);
        NoteWayIn(_focus, node);
        NoteHandOver(_focus, node, cancelled);
        _focus = node;
        KeepRootFocus(Focus.RootOf(node), node);
        for (Node? step = node.Parent; step is not null; step = step.Parent)
        {
            step.LastInner = node;
        }
        Event(node.Id, "focus");
        foreach (int code in node.Keys)
        {
            _input.Watch(code & ~Node.AltFlag);
        }
    }

    /// <summary>
    /// Takes the focus off the component holding it.
    /// </summary>
    /// <param name="forget">Whether its root forgets it, so the focus does not come back to it.</param>
    private void Blur(bool forget)
    {
        if (_focus is not { } focus)
        {
            return;
        }

        DropOnBlur(focus);
        focus.EndRest();
        Event(focus.Id, "blur");
        HideFocusTip();
        if (forget)
        {
            KeepRootFocus(Focus.RootOf(focus), null);
        }

        _focus = null;
    }

    /// <summary>
    /// Moves the focus a root keeps for itself, telling the boxes the keys enter in that root that it
    /// comes out of or goes inside.
    /// </summary>
    /// <remarks>
    /// A popup or a dialog above that takes the focus leaves the focus its root keeps as it is, so a
    /// box is never told it was left because one of its own parts opened something.
    /// </remarks>
    /// <param name="root">The root.</param>
    /// <param name="node">The part it keeps the focus on, null for none.</param>
    private void KeepRootFocus(Node root, Node? node)
    {
        Node? before = root.LastFocus;
        root.LastFocus = node;
        if (before != node)
        {
            TellBoxes(before, node);
        }
    }

    /// <summary>
    /// Tells each box the keys enter that the focus comes out of, "came_out", and each it goes inside,
    /// "went_in": inside means on a part in the box, not on the box picked as a whole.
    /// </summary>
    /// <param name="from">The component that held the focus, null for none.</param>
    /// <param name="to">The component that gets it, null for none.</param>
    private void TellBoxes(Node? from, Node? to)
    {
        for (Node? box = from?.Parent; box is not null; box = box.Parent)
        {
            if (box.Enter && (to is null || to == box || !Inside(to, box)))
            {
                Event(box.Id, "came_out");
            }
        }

        for (Node? box = to?.Parent; box is not null; box = box.Parent)
        {
            if (box.Enter && (from is null || from == box || !Inside(from, box)))
            {
                Event(box.Id, "went_in");
            }
        }
    }

    /// <summary>
    /// Has a list that loses the focus while it carries a row drop it where it is.
    /// </summary>
    /// <param name="node">The component losing the focus.</param>
    private void DropOnBlur(Node node)
    {
        if (node.Moving)
        {
            Drop(node, cue: false);
        }
    }

    /// <summary>
    /// Scrolls a list or box a page.
    /// </summary>
    /// <param name="node">The list or box.</param>
    /// <param name="direction">-1 up, 1 down.</param>
    private void Page(Node node, int direction) => Scrolled(node, Scroll.To(node, node.ScrollTop + direction * Math.Max(node.ScrollShown, 1)));

    /// <summary>
    /// Follows a scroll: a list's cursor stays in sight, and what a box holds is laid out again.
    /// </summary>
    /// <param name="node">The list or box.</param>
    /// <param name="moved">Whether it scrolled.</param>
    private void Scrolled(Node node, bool moved)
    {
        if (!moved)
        {
            return;
        }

        if (node.Kind != NodeKind.List)
        {
            _relayout = true;
        }
        else if (Scroll.CursorInSight(node) is int row)
        {
            MoveCursor(node, row, false);
        }
    }

    /// <summary>
    /// Follows the tooltip: the pointer resting <see cref="TooltipFrames"/> ticks on a component
    /// with one shows it, and moving or pressing hides it.
    /// </summary>
    /// <param name="target">What lies under the pointer and takes input, null for none.</param>
    /// <param name="point">Where the pointer is.</param>
    /// <param name="moved">Whether the pointer moved since the last tick.</param>
    private void FollowTip(Hit? target, (int X, int Y)? point, bool moved)
    {
        Node? tipped = target?.Node;
        while (tipped is not null && !tipped.Tooltip)
        {
            tipped = tipped.Parent;
        }

        if (tipped != _tipNode || moved)
        {
            _tipNode = tipped;
            _rest = 0;
            HideTip();
            return;
        }

        if (tipped is null || _rest < 0 || point is not { } spot)
        {
            return;
        }

        _rest++;
        if (_rest == TooltipFrames)
        {
            _tip = (tipped.Id, spot.X, spot.Y, false);
            _tipChanged = true;
        }
    }

    /// <summary>
    /// Shows the tooltip of a component a key gave the focus to at once, under it.
    /// </summary>
    /// <param name="node">The component.</param>
    private void ShowFocusTip(Node node)
    {
        if (node.Tooltip && node.Rect is { } rect)
        {
            (int dx, int dy) = HitTest.ShiftOf(node);
            _tip = (node.Id, rect.X + dx, rect.Y + rect.Height + dy, true);
            _tipChanged = true;
        }
    }

    /// <summary>
    /// Hides the tooltip a key's focus showed, as the focus moves on.
    /// </summary>
    private void HideFocusTip()
    {
        if (_tip is { ByFocus: true })
        {
            HideTip();
        }
    }

    /// <summary>
    /// Hides the tooltip shown.
    /// </summary>
    private void HideTip()
    {
        if (_tip is not null)
        {
            _tip = null;
            _tipChanged = true;
        }
    }

    /// <summary>
    /// Keeps the root under the pointer.
    /// </summary>
    /// <param name="id">The root, null for none.</param>
    private void SetOver(int? id)
    {
        if (id != _over)
        {
            _over = id;
            _overChanged = true;
        }
    }

    /// <summary>
    /// Keeps the component under the pointer and tells it and the one before.
    /// </summary>
    /// <param name="node">The component, null for none.</param>
    private void SetHover(Node? node)
    {
        if (node == _hover)
        {
            return;
        }

        if (_hover is { } old)
        {
            Event(old.Id, "hover", false);
        }

        _hover = node;
        if (node is not null)
        {
            Event(node.Id, "hover", true);
        }
    }

    /// <summary>
    /// Keeps the row of a list whose cursor does not follow the pointer that the pointer is on, and
    /// tells the list, and the list before when the pointer left it.
    /// </summary>
    /// <param name="framed">The list and its row, null for none.</param>
    private void SetHoverRow((Node List, int Row)? framed)
    {
        if (framed == _hoverRow)
        {
            return;
        }

        if (_hoverRow is { } old && old.List != framed?.List)
        {
            Event(old.List.Id, "hover_row", -1);
        }

        _hoverRow = framed;
        if (framed is { } now)
        {
            Event(now.List.Id, "hover_row", now.Row);
        }
    }

    /// <summary>
    /// Closes a root: tells it, plays the cancel sound for a cancel and removes it, so the focus goes
    /// back below. A root that guards its cancel is only told of a cancel, and the scripts close it
    /// unless a block keeps it.
    /// </summary>
    /// <param name="root">The root.</param>
    /// <param name="why">Why it closes, told with the close; null for cancel.</param>
    private void Close(Node root, string? why = null)
    {
        if (root.GuardsCancel && why is null)
        {
            if (_padCancel)
            {
                Event(root.Id, "cancel", "pad");
            }
            else
            {
                Event(root.Id, "cancel");
            }

            return;
        }

        if (why is null)
        {
            Event(root.Id, "close");
            Cue(UiCue.Cancel);
        }
        else
        {
            Event(root.Id, "close", why);
        }

        Remove(root);
    }

    /// <summary>
    /// Takes confirm on the focused component: a list submits its cursor row, any other is clicked,
    /// a disabled one buzzes.
    /// </summary>
    /// <param name="focus">The focused component.</param>
    private void Confirm(Node focus)
    {
        if (ConfirmDrag(focus))
        {
        }
        else if (!Focus.Enabled(focus))
        {
            Cue(UiCue.Buzzer);
        }
        else if (focus.Enter)
        {
            Node? inner = focus.LastInner is { } last && _nodes.ContainsKey(last.Id) && Inside(last, focus) && Focus.CanHold(last) && Focus.Enabled(last)
                ? last
                : Focus.FirstInside(focus);
            if (inner is null)
            {
                Cue(UiCue.Buzzer);
            }
            else
            {
                MoveFocus(inner);
            }
        }
        else if (focus.Kind == NodeKind.List && focus.Cursor >= 0 && focus.ToggleCursor >= 0 && !focus.DisabledRows.Contains(focus.Cursor))
        {
            Event(focus.Id, "toggle", focus.Cursor);
            _events[^1].AsArray().Add(focus.ToggleCursor);
            if (!focus.Quiet)
            {
                Cue(UiCue.Ok);
            }
        }

        else if (focus.Kind != NodeKind.List)
        {
            Click(focus);
        }
        else if (focus.Cursor >= 0)
        {
            Submit(focus, focus.Cursor);
        }
    }

    /// <summary>
    /// Clicks a component, with the confirm sound unless it is quiet.
    /// </summary>
    /// <param name="node">The component.</param>
    private void Click(Node node)
    {
        Event(node.Id, "click");
        if (Pressable(node) && !node.Quiet)
        {
            Cue(UiCue.Ok);
        }
    }

    /// <summary>
    /// Submits a list's row with the confirm sound unless the list is quiet, or buzzes for a disabled
    /// one; a list that carries a row drops it instead, a disabled one too. A list that does not take
    /// its submit tells it to the nearest part around it that does, with the list.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="row">The row.</param>
    private void Submit(Node list, int row)
    {
        if (list.Moving)
        {
            Drop(list, cue: true);
            return;
        }

        if (list.DisabledRows.Contains(row))
        {
            Event(list.Id, "refuse", row);
            Cue(UiCue.Buzzer);
            return;
        }

        Node taker = SubmitTaker(list);
        if (taker == list)
        {
            Event(list.Id, "submit", row);
        }
        else
        {
            _events.Add(new RubyArray { taker.Id, "submit", row, list.Id });
        }

        if (!list.Quiet)
        {
            Cue(UiCue.Ok);
        }

        _lastSubmit = (list, row);
    }

    /// <summary>
    /// Has a list carry the row the pointer took from its place, as the pointer drags it.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="row">The row.</param>
    private void Carry(Node list, int row)
    {
        list.Moving = true;
        Event(list.Id, "carry", row);
    }

    /// <summary>
    /// Has a list drop the row it carries where its cursor is.
    /// </summary>
    /// <param name="list">The list.</param>
    /// <param name="cue">Whether the confirm sound plays.</param>
    private void Drop(Node list, bool cue)
    {
        list.Moving = false;
        Event(list.Id, "drop", list.Cursor);
        if (cue)
        {
            Cue(UiCue.Ok);
        }
    }

    /// <summary>
    /// Scrolls every box a component lies in that scrolls what it holds, so the component shows.
    /// </summary>
    /// <param name="node">The component.</param>
    private void Reveal(Node node)
    {
        if (node.Rect is not { } rect)
        {
            return;
        }

        for (Node? box = node.Parent; box is not null; box = box.Parent)
        {
            if (!box.Scroll || box.Rect is not { } place)
            {
                continue;
            }

            LayoutRect view = box.Room.Inside(place);
            int above = view.Y - rect.Y;
            int below = rect.Y + rect.Height - (view.Y + view.Height);
            int step = above > 0 ? -above : Math.Max(below, 0);
            Scrolled(box, step != 0 && Scroll.To(box, box.ScrollTop + step));
        }
    }

    /// <summary>
    /// Adds an event for the scripts.
    /// </summary>
    /// <param name="id">The component.</param>
    /// <param name="name">The event's name.</param>
    /// <param name="value">Its value, null for none.</param>
    private void Event(int id, string name, RubyValue? value = null)
    {
        var entry = new RubyArray { id, name };
        if (value is not null)
        {
            entry.Add(value);
        }

        _events.Add(entry);
    }

    /// <summary>
    /// Adds a sound for the scripts to play.
    /// </summary>
    /// <param name="cue">The sound, see <see cref="UiCue"/>.</param>
    private void Cue(string cue) => _cues.Add(cue);

    /// <summary>
    /// Builds what changed since the last report, and keeps it as told.
    /// </summary>
    /// <returns>The changes, see <see cref="EventTopic"/>; empty when nothing changed.</returns>
    private RubyHash Report()
    {
        var report = new RubyHash();
        var rects = new RubyHash();
        var scroll = new RubyHash();
        var cuts = new RubyHash();
        foreach (Node root in _roots)
        {
            if (_moved.Contains(root) || (root.LayoutDirty && root.Visible))
            {
                Compare(root, rects, scroll, cuts);
            }
        }

        _moved.Clear();

        RubyHash states = States();
        Put(report, "rects", rects, rects.Count);
        Put(report, "states", states, states.Count);
        Put(report, "scroll", scroll, scroll.Count);
        Put(report, "padding_cut", cuts, cuts.Count);
        Put(report, "events", _events, _events.Count);
        Put(report, "cues", _cues, _cues.Count);
        Put(report, "taken", _taken, _taken.Count);
        Put(report, "refused", _refused, _refused.Count);
        Put(report, "quiet", _quiet, _quiet.Count);
        Put(report, "clashes", _clashes, _clashes.Count);
        (_events, _cues, _taken, _refused, _quiet, _clashes) = ([], [], [], [], [], new());
        if (_resync is not null)
        {
            report["resync"] = _resync;
            _resync = null;
        }

        if (_late != 0)
        {
            report["late"] = _late;
            _late = 0;
        }

        List<int> order = _orderChanged ? BottomFirst() : _postedOrder;
        _orderChanged = false;
        if (!order.SequenceEqual(_postedOrder))
        {
            _postedOrder = order;
            report["order"] = new RubyArray(order.Select(id => (RubyValue)id));
        }

        if (_overChanged)
        {
            report["over"] = _over is int over ? over : RubyNil.Value;
            _overChanged = false;
        }

        if (_docksChanged)
        {
            var docks = new RubyHash();
            foreach ((string dock, int room) in _dockRooms)
            {
                docks[dock] = room;
            }

            report["docks"] = docks;
            _docksChanged = false;
        }

        if (_crowdedChanged)
        {
            report["crowded"] = new RubyArray(_roots.Where(root => root.Crowded).Select(root => (RubyValue)root.Id));
            _crowdedChanged = false;
        }

        if (_tipChanged)
        {
            report["tooltip"] = _tip is not { } tip ? RubyNil.Value : tip.ByFocus ? new RubyArray { tip.Id, tip.X, tip.Y, true } : new RubyArray { tip.Id, tip.X, tip.Y };
            _tipChanged = false;
        }

        return report;
    }

    /// <summary>
    /// Adds the places, the scrolling and what gave way of the padding of a component and of
    /// everything it holds that changed since they were last reported.
    /// </summary>
    /// <param name="node">The component.</param>
    /// <param name="rects">Where the changed places go.</param>
    /// <param name="scroll">Where the changed scrolling goes.</param>
    /// <param name="cuts">Where what changed of what gave way of a padding goes.</param>
    private void Compare(Node node, RubyHash rects, RubyHash scroll, RubyHash cuts)
    {
        if (node.Rect is { } rect && (!_postedRects.TryGetValue(node.Id, out LayoutRect told) || told != rect))
        {
            _postedRects[node.Id] = rect;
            rects.Add(node.Id, rect.ToValue());
        }

        var scrolled = (node.ScrollTop, node.ScrollShown, node.ScrollTotal);
        if (node.Scrolls && node.Rect is not null && (!_postedScroll.TryGetValue(node.Id, out var toldScroll) || toldScroll != scrolled))
        {
            _postedScroll[node.Id] = scrolled;
            scroll.Add(node.Id, new RubyArray { scrolled.ScrollTop, scrolled.ScrollShown, scrolled.ScrollTotal });
        }

        Insets cut = node.PaddingCut;
        if (node.Rect is not null && _postedCuts.GetValueOrDefault(node.Id) != cut)
        {
            _postedCuts[node.Id] = cut;
            cuts.Add(node.Id, new RubyArray { cut.Top, cut.Right, cut.Bottom, cut.Left });
        }

        foreach (Node child in node.Children)
        {
            Compare(child, rects, scroll, cuts);
        }
    }

    /// <summary>
    /// Builds the states that changed since the last report: hover, a press the pointer stays on,
    /// and the focus.
    /// </summary>
    /// <returns>Each changed component's bits, 0 for one that lost its state.</returns>
    private RubyHash States()
    {
        var now = new Dictionary<int, int>();
        void Mark(Node? node, int bit)
        {
            if (node is not null && _nodes.ContainsKey(node.Id))
            {
                now[node.Id] = now.GetValueOrDefault(node.Id) | bit;
            }
        }

        Mark(_hover is { } hovered && !InLayerWindow(hovered) && Focus.Enabled(hovered) ? hovered : null, Hovered);
        Mark(_pressed == _hover ? _pressed : null, Pressed);
        Mark(_focus, Focused);
        var states = new RubyHash();
        foreach ((int id, int bits) in now)
        {
            if (_postedStates.GetValueOrDefault(id) != bits)
            {
                states.Add(id, bits);
            }
        }

        foreach (int id in _postedStates.Keys)
        {
            if (!now.ContainsKey(id) && _nodes.ContainsKey(id))
            {
                states.Add(id, 0);
            }
        }

        _postedStates = now;
        return states;
    }

    /// <summary>
    /// Puts a part into a report when it holds anything.
    /// </summary>
    /// <param name="report">The report.</param>
    /// <param name="key">The part's name.</param>
    /// <param name="value">The part.</param>
    /// <param name="count">How much it holds.</param>
    private static void Put(RubyHash report, string key, RubyValue value, int count)
    {
        if (count > 0)
        {
            report[key] = value;
        }
    }
}


module ImGui;

import core.stdc.stdarg : va_list, va_start, va_end;
import Game.Core.Math : Vec2, Vec4;

@nogc nothrow:

// Version
enum IMGUI_VERSION = "1.67";
enum IMGUI_VERSION_NUM = 16603;
// #define IMGUI_CHECKVERSION()        ImGui::DebugCheckVersionAndDataLayout(IMGUI_VERSION, sizeof(ImGuiIO), sizeof(ImGuiStyle), sizeof(ImVec2), sizeof(ImVec4), sizeof(ImDrawVert))

// Forward declarations
// struct ImDrawChannel;               // Temporary storage for outputting drawing commands out of order, used by ImDrawList::ChannelsSplit()
// struct ImDrawCmd;                   // A single draw command within a parent ImDrawList (generally maps to 1 GPU draw call)
// struct ImDrawData;                  // All draw command lists required to render the frame
// struct ImDrawList;                  // A single draw command list (generally one per window)
struct ImDrawListSharedData;        // Data shared among multiple draw lists (typically owned by parent ImGui context, but you may create one yourself)
// struct ImDrawVert;                  // A single vertex (20 bytes by default, override layout with IMGUI_OVERRIDE_DRAWVERT_STRUCT_LAYOUT)
// struct ImFont;                      // Runtime data for a single font within a parent ImFontAtlas
// struct ImFontAtlas;                 // Runtime data for multiple fonts, bake multiple fonts into a single texture, TTF/OTF font loader
// struct ImFontConfig;                // Configuration data when adding a font or merging fonts
// struct ImColor;                     // Helper functions to create a color that can be converted to either u32 or float4 (*obsolete* please avoid using)
// struct ImGuiIO;                     // Main configuration and I/O between your application and ImGui
// struct ImGuiOnceUponAFrame;         // Simple helper for running a block of code not more than once a frame, used by IMGUI_ONCE_UPON_A_FRAME macro
// struct ImGuiStorage;                // Simple custom key value storage
// struct ImGuiTextFilter;             // Parse and apply text filters. In format "aaaaa[,bbbb][,ccccc]"
// struct ImGuiTextBuffer;             // Text buffer for logging/accumulating text
// struct ImGuiTextEditCallbackData;   // Shared state of ImGui::InputText() when using custom ImGuiTextEditCallback (rare/advanced use)
// struct ImGuiSizeCallbackData;       // Structure used to constraint window size in custom ways when using custom ImGuiSizeCallback (rare/advanced use)
// struct ImGuiListClipper;            // Helper to manually clip large list of items
// struct ImGuiPayload;                // User data payload for drag and drop operations
struct ImGuiContext;                // ImGui context (opaque)
alias ImTextureID = void*;                 // User data to identify a texture (this is whatever to you want it to be! read the FAQ about ImTextureID in imgui.cpp)

// Typedefs and Enumerations (declared as int for compatibility with old C++ and to not pollute the top of this file)
alias ImGuiID = uint;       // Unique ID used by widgets (typically hashed from a stack of string)
alias ImWchar = ushort;     // Character for keyboard input/display
alias int ImGuiCol;               // -> enum ImGuiCol_             // Enum: A color identifier for styling
alias int ImGuiCond;              // -> enum ImGuiCond_            // Enum: A condition for Set*()
alias int ImGuiDataType;          // -> enum ImGuiDataType_        // Enum: A primary data type
alias int ImGuiDir;               // -> enum ImGuiDir_             // Enum: A cardinal direction
alias int ImGuiKey;               // -> enum ImGuiKey_             // Enum: A key identifier (ImGui-side enum)
alias int ImGuiNavInput;          // -> enum ImGuiNavInput_        // Enum: An input identifier for navigation
alias int ImGuiMouseCursor;       // -> enum ImGuiMouseCursor_     // Enum: A mouse cursor identifier
alias int ImGuiStyleVar;          // -> enum ImGuiStyleVar_        // Enum: A variable identifier for styling
alias int ImDrawCornerFlags;      // -> enum ImDrawCornerFlags_    // Flags: for ImDrawList::AddRect*() etc.
alias int ImDrawListFlags;        // -> enum ImDrawListFlags_      // Flags: for ImDrawList
alias int ImFontAtlasFlags;       // -> enum ImFontAtlasFlags_     // Flags: for ImFontAtlas
alias int ImGuiBackendFlags;      // -> enum ImGuiBackendFlags_    // Flags: for io.BackendFlags
alias int ImGuiColorEditFlags;    // -> enum ImGuiColorEditFlags_  // Flags: for ColorEdit*(), ColorPicker*()
alias int ImGuiColumnsFlags;      // -> enum ImGuiColumnsFlags_    // Flags: for Columns(), BeginColumns()
alias int ImGuiConfigFlags;       // -> enum ImGuiConfigFlags_     // Flags: for io.ConfigFlags
alias int ImGuiComboFlags;        // -> enum ImGuiComboFlags_      // Flags: for BeginCombo()
alias int ImGuiDragDropFlags;     // -> enum ImGuiDragDropFlags_   // Flags: for *DragDrop*()
alias int ImGuiFocusedFlags;      // -> enum ImGuiFocusedFlags_    // Flags: for IsWindowFocused()
alias int ImGuiHoveredFlags;      // -> enum ImGuiHoveredFlags_    // Flags: for IsItemHovered(), IsWindowHovered() etc.
alias int ImGuiInputTextFlags;    // -> enum ImGuiInputTextFlags_  // Flags: for InputText*()
alias int ImGuiSelectableFlags;   // -> enum ImGuiSelectableFlags_ // Flags: for Selectable()
alias int ImGuiTabBarFlags;       // -> enum ImGuiTabBarFlags_     // Flags: for BeginTabBar()
alias int ImGuiTabItemFlags;      // -> enum ImGuiTabItemFlags_    // Flags: for BeginTabItem()
alias int ImGuiTreeNodeFlags;     // -> enum ImGuiTreeNodeFlags_   // Flags: for TreeNode*(),CollapsingHeader()
alias int ImGuiWindowFlags;       // -> enum ImGuiWindowFlags_     // Flags: for Begin*()

extern(C++)
{
    alias ImGuiInputTextCallback = int function(ImGuiInputTextCallbackData *data);
    alias ImGuiSizeCallback      = void function(ImGuiSizeCallbackData* data);
}

// Scalar data types
alias ImS32 = int;  // 32-bit signed integer == int
alias ImU32 = uint;  // 32-bit unsigned integer (often used to store packed colors)
alias ImS64 = long;
alias ImU64 = ulong;

alias ImVec2 = Vec2;
alias ImVec4 = Vec4;

extern(C++, ImGui)
{
@nogc nothrow:

// Context creation and access
// All contexts share a same ImFontAtlas by default. If you want different font atlas, you can new() them and overwrite the GetIO().Fonts variable of an ImGui context.
// All those functions are not reliant on the current context.
ImGuiContext* CreateContext(ImFontAtlas* shared_font_atlas = null);
void          DestroyContext(ImGuiContext* ctx = null);   // null = destroy current context
ImGuiContext* GetCurrentContext();
void          SetCurrentContext(ImGuiContext* ctx);
bool          DebugCheckVersionAndDataLayout(const(char)* version_str, size_t sz_io, size_t sz_style, size_t sz_vec2, size_t sz_vec4, size_t sz_drawvert);

// Main
ref ImGuiIO    GetIO();                                    // access the IO structure (mouse/keyboard/gamepad inputs, time, various configuration options/flags)
ref ImGuiStyle GetStyle();                                 // access the Style structure (colors, sizes). Always use PushStyleCol(), PushStyleVar() to modify style mid-frame.
void           NewFrame();                                 // start a new ImGui frame, you can submit any command from this point until Render()/EndFrame().
void           EndFrame();                                 // ends the ImGui frame. automatically called by Render(), so most likely don't need to ever call that yourself directly. If you don't need to render you may call EndFrame() but you'll have wasted CPU already. If you don't need to render, better to not create any imgui windows instead!
void           Render();                                   // ends the ImGui frame, finalize the draw data. (Obsolete: optionally call io.RenderDrawListsFn if set. Nowadays, prefer calling your render function yourself.)
ImDrawData*    GetDrawData();                              // valid after Render() and until the next call to NewFrame(). this is what you have to render. (Obsolete: this used to be passed to your io.RenderDrawListsFn() function.)

// Demo, Debug, Information
void          ShowDemoWindow(bool* p_open = null);        // create demo/test window (previously called ShowTestWindow). demonstrate most ImGui features. call this to learn about the library! try to make it always available in your application!
void          ShowAboutWindow(bool* p_open = null);       // create about window. display Dear ImGui version, credits and build/system information.
void          ShowMetricsWindow(bool* p_open = null);     // create metrics window. display ImGui internals: draw commands (with individual draw calls and vertices), window list, basic internal state, etc.
void          ShowStyleEditor(ImGuiStyle* ref_ = null);    // add style editor block (not a window). you can pass in a reference ImGuiStyle structure to compare to, revert to and save to (else it uses the default style)
bool          ShowStyleSelector(const(char)* label);       // add style selector block (not a window), essentially a combo listing the default styles.
void          ShowFontSelector(const(char)* label);        // add font selector block (not a window), essentially a combo listing the loaded fonts.
void          ShowUserGuide();                            // add basic help/info block (not a window): how to manipulate ImGui as a end-user (mouse/keyboard controls).
const(char)*  GetVersion();                               // get a version string e.g. "1.23"

// Styles
void          StyleColorsDark(ImGuiStyle* dst = null);    // new, recommended style (default)
void          StyleColorsClassic(ImGuiStyle* dst = null); // classic imgui style
void          StyleColorsLight(ImGuiStyle* dst = null);   // best used with borders and a custom, thicker font

// Windows
// (Begin = push window to the stack and start appending to it. End = pop window from the stack. You may append multiple times to the same window during the same frame)
// Begin()/BeginChild() return false to indicate the window being collapsed or fully clipped, so you may early out and omit submitting anything to the window.
// You need to always call a matching End()/EndChild() for a Begin()/BeginChild() call, regardless of its return value (this is due to legacy reason and is inconsistent with BeginMenu/EndMenu, BeginPopup/EndPopup and other functions where the End call should only be called if the corresponding Begin function returned true.)
// Passing 'bool* p_open != null' shows a close widget in the upper-right corner of the window, which when clicking will set the boolean to false.
// Use child windows to introduce independent scrolling/clipping regions within a host window. Child windows can embed their own child.
bool          Begin(const(char)* name, bool* p_open = null, ImGuiWindowFlags flags = 0);
void          End();

// Child Windows
// - Use child windows to begin into a self-contained independent scrolling/clipping regions within a host window. Child windows can embed their own child.
// - For each independent axis of 'size': ==0.0f: use remaining host window size / >0.0f: fixed size / <0.0f: use remaining window size minus abs(size) / Each axis can use a different mode, e.g. ImVec2(0,400).
// - BeginChild() returns false to indicate the window is collapsed or fully clipped, so you may early out and omit submitting anything to the window.
//   Always call a matching EndChild() for each BeginChild() call, regardless of its return value [this is due to legacy reason and is inconsistent with most other functions such as BeginMenu/EndMenu, BeginPopup/EndPopup, etc. where the EndXXX call should only be called if the corresponding BeginXXX function returned true.]
bool          BeginChild(const(char)* str_id, ref const ImVec2 size, bool border = false, ImGuiWindowFlags flags = 0); // Begin a scrolling region. size==0.0f: use remaining window size, size<0.0f: use remaining window size minus abs(size). size>0.0f: fixed size. each axis can use a different mode, e.g. ImVec2(0,400).
bool          BeginChild(ImGuiID id, ref const ImVec2 size, bool border = false, ImGuiWindowFlags flags = 0);
void          EndChild();

// Windows Utilities
bool          IsWindowAppearing();
bool          IsWindowCollapsed();
bool          IsWindowFocused(ImGuiFocusedFlags flags=0); // is current window focused? or its root/child, depending on flags. see flags for options.
bool          IsWindowHovered(ImGuiHoveredFlags flags=0); // is current window hovered (and typically: not blocked by a popup/modal)? see flags for options. NB: If you are trying to check whether your mouse should be dispatched to imgui or to your app, you should use the 'io.WantCaptureMouse' boolean for that! Please read the FAQ!
ImDrawList*   GetWindowDrawList();                        // get draw list associated to the window, to append your own drawing primitives
ImVec2        GetWindowPos();                             // get current window position in screen space (useful if you want to do your own drawing via the DrawList API)
ImVec2        GetWindowSize();                            // get current window size
float         GetWindowWidth();                           // get current window width (shortcut for GetWindowSize().x)
float         GetWindowHeight();                          // get current window height (shortcut for GetWindowSize().y)
ImVec2        GetContentRegionMax();                      // current content boundaries (typically window boundaries including scrolling, or current column boundaries), in windows coordinates
ImVec2        GetContentRegionAvail();                    // == GetContentRegionMax() - GetCursorPos()
float         GetContentRegionAvailWidth();               //
ImVec2        GetWindowContentRegionMin();                // content boundaries min (roughly (0,0)-Scroll), in window coordinates
ImVec2        GetWindowContentRegionMax();                // content boundaries max (roughly (0,0)+Size-Scroll) where Size can be override with SetNextWindowContentSize(), in window coordinates
float         GetWindowContentRegionWidth();              //

void          SetNextWindowPos(ref const ImVec2 pos, ImGuiCond cond, ref const ImVec2 pivot); // set next window position. call before Begin(). use pivot=(0.5f,0.5f) to center on given point, etc.
void          SetNextWindowSize(ref const ImVec2 size, ImGuiCond cond = 0);                  // set next window size. set axis to 0.0f to force an auto-fit on this axis. call before Begin()
void          SetNextWindowSizeConstraints(ref const ImVec2 size_min, ref const ImVec2 size_max, ImGuiSizeCallback custom_callback = null, void* custom_callback_data = null); // set next window size limits. use -1,-1 on either X/Y axis to preserve the current size. Use callback to apply non-trivial programmatic constraints.
void          SetNextWindowContentSize(ref const ImVec2 size);                               // set next window content size (~ enforce the range of scrollbars). not including window decorations (title bar, menu bar, etc.). set an axis to 0.0f to leave it automatic. call before Begin()
void          SetNextWindowCollapsed(bool collapsed, ImGuiCond cond = 0);                 // set next window collapsed state. call before Begin()
void          SetNextWindowFocus();                                                       // set next window to be focused / front-most. call before Begin()
void          SetNextWindowBgAlpha(float alpha);                                          // set next window background color alpha. helper to easily modify ImGuiCol_WindowBg/ChildBg/PopupBg.
void          SetWindowPos(ref const ImVec2 pos, ImGuiCond cond = 0);                        // (not recommended) set current window position - call within Begin()/End(). prefer using SetNextWindowPos(), as this may incur tearing and side-effects.
void          SetWindowSize(ref const ImVec2 size, ImGuiCond cond = 0);                      // (not recommended) set current window size - call within Begin()/End(). set to ImVec2(0,0) to force an auto-fit. prefer using SetNextWindowSize(), as this may incur tearing and minor side-effects.
void          SetWindowCollapsed(bool collapsed, ImGuiCond cond = 0);                     // (not recommended) set current window collapsed state. prefer using SetNextWindowCollapsed().
void          SetWindowFocus();                                                           // (not recommended) set current window to be focused / front-most. prefer using SetNextWindowFocus().
void          SetWindowFontScale(float scale);                                            // set font scale. Adjust IO.FontGlobalScale if you want to scale all windows
void          SetWindowPos(const(char)* name, ref const ImVec2 pos, ImGuiCond cond = 0);      // set named window position.
void          SetWindowSize(const(char)* name, ref const ImVec2 size, ImGuiCond cond = 0);    // set named window size. set axis to 0.0f to force an auto-fit on this axis.
void          SetWindowCollapsed(const(char)* name, bool collapsed, ImGuiCond cond = 0);   // set named window collapsed state
void          SetWindowFocus(const(char)* name);                                           // set named window to be focused / front-most. use null to remove focus.

// Windows Scrolling
float         GetScrollX();                                                   // get scrolling amount [0..GetScrollMaxX()]
float         GetScrollY();                                                   // get scrolling amount [0..GetScrollMaxY()]
float         GetScrollMaxX();                                                // get maximum scrolling amount ~~ ContentSize.X - WindowSize.X
float         GetScrollMaxY();                                                // get maximum scrolling amount ~~ ContentSize.Y - WindowSize.Y
void          SetScrollX(float scroll_x);                                     // set scrolling amount [0..GetScrollMaxX()]
void          SetScrollY(float scroll_y);                                     // set scrolling amount [0..GetScrollMaxY()]
void          SetScrollHereY(float center_y_ratio = 0.5f);                    // adjust scrolling amount to make current cursor position visible. center_y_ratio=0.0: top, 0.5: center, 1.0: bottom. When using to make a "default/current item" visible, consider using SetItemDefaultFocus() instead.
void          SetScrollFromPosY(float pos_y, float center_y_ratio = 0.5f);    // adjust scrolling amount to make given position valid. use GetCursorPos() or GetCursorStartPos()+offset to get valid positions.

// Parameters stacks (shared)
void          PushFont(ImFont* font);                                         // use null as a shortcut to push default font
void          PopFont();
void          PushStyleColor(ImGuiCol idx, ImU32 col);
void          PushStyleColor(ImGuiCol idx, const ref ImVec4 col);
void          PopStyleColor(int count = 1);
void          PushStyleVar(ImGuiStyleVar idx, float val);
void          PushStyleVar(ImGuiStyleVar idx, ref const ImVec2 val);
void          PopStyleVar(int count = 1);
ref const(ImVec4) GetStyleColorVec4(ImGuiCol idx);                                // retrieve style color as stored in ImGuiStyle structure. use to feed back into PushStyleColor(), otherwise use GetColorU32() to get style color with style alpha baked in.
ImFont*       GetFont();                                                      // get current font
float         GetFontSize();                                                  // get current font size (= height in pixels) of current font with current scale applied
ImVec2        GetFontTexUvWhitePixel();                                       // get UV coordinate for a while pixel, useful to draw custom shapes via the ImDrawList API
ImU32         GetColorU32(ImGuiCol idx, float alpha_mul = 1.0f);              // retrieve given style color with style alpha applied and optional extra alpha multiplier
ImU32         GetColorU32(ref const ImVec4 col);                                 // retrieve given color with style alpha applied
ImU32         GetColorU32(ImU32 col);                                         // retrieve given color with style alpha applied

// Parameters stacks (current window)
void          PushItemWidth(float item_width);                                // width of items for the common item+label case, pixels. 0.0f = default to ~2/3 of windows width, >0.0f: width in pixels, <0.0f align xx pixels to the right of window (so -1.0f always align width to the right side)
void          PopItemWidth();
float         CalcItemWidth();                                                // width of item given pushed settings and current cursor position
void          PushTextWrapPos(float wrap_pos_x = 0.0f);                       // word-wrapping for Text*() commands. < 0.0f: no wrapping; 0.0f: wrap to end of window (or column); > 0.0f: wrap at 'wrap_pos_x' position in window local space
void          PopTextWrapPos();
void          PushAllowKeyboardFocus(bool allow_keyboard_focus);              // allow focusing using TAB/Shift-TAB, enabled by default but you can disable it for certain widgets
void          PopAllowKeyboardFocus();
void          PushButtonRepeat(bool repeat);                                  // in 'repeat' mode, Button*() functions return repeated true in a typematic manner (using io.KeyRepeatDelay/io.KeyRepeatRate setting). Note that you can call IsItemActive() after any Button() to tell if the button is held in the current frame.
void          PopButtonRepeat();

// Cursor / Layout
void          Separator();                                                    // separator, generally horizontal. inside a menu bar or in horizontal layout mode, this becomes a vertical separator.
void          SameLine(float pos_x = 0.0f, float spacing_w = -1.0f);          // call between widgets or groups to layout them horizontally
void          NewLine();                                                      // undo a SameLine()
void          Spacing();                                                      // add vertical spacing
void          Dummy(ref const ImVec2 size);                                      // add a dummy item of given size
void          Indent(float indent_w = 0.0f);                                  // move content position toward the right, by style.IndentSpacing or indent_w if != 0
void          Unindent(float indent_w = 0.0f);                                // move content position back to the left, by style.IndentSpacing or indent_w if != 0
void          BeginGroup();                                                   // lock horizontal starting position + capture group bounding box into one "item" (so you can use IsItemHovered() or layout primitives such as SameLine() on whole group, etc.)
void          EndGroup();
ImVec2        GetCursorPos();                                                 // cursor position is relative to window position
float         GetCursorPosX();                                                // "
float         GetCursorPosY();                                                // "
void          SetCursorPos(ref const ImVec2 local_pos);                          // "
void          SetCursorPosX(float x);                                         // "
void          SetCursorPosY(float y);                                         // "
ImVec2        GetCursorStartPos();                                            // initial cursor position
ImVec2        GetCursorScreenPos();                                           // cursor position in absolute screen coordinates [0..io.DisplaySize] (useful to work with ImDrawList API)
void          SetCursorScreenPos(ref const ImVec2 screen_pos);                   // cursor position in absolute screen coordinates [0..io.DisplaySize]
void          AlignTextToFramePadding();                                      // vertically align upcoming text baseline to FramePadding.y so that it will align properly to regularly framed items (call if you have text on a line before a framed item)
float         GetTextLineHeight();                                            // ~ FontSize
float         GetTextLineHeightWithSpacing();                                 // ~ FontSize + style.ItemSpacing.y (distance in pixels between 2 consecutive lines of text)
float         GetFrameHeight();                                               // ~ FontSize + style.FramePadding.y * 2
float         GetFrameHeightWithSpacing();                                    // ~ FontSize + style.FramePadding.y * 2 + style.ItemSpacing.y (distance in pixels between 2 consecutive lines of framed widgets)

// ID stack/scopes
// Read the FAQ for more details about how ID are handled in dear imgui. If you are creating widgets in a loop you most
// likely want to push a unique identifier (e.g. object pointer, loop index) to uniquely differentiate them.
// You can also use the "##foobar" syntax within widget label to distinguish them from each others.
// In this header file we use the "label"/"name" terminology to denote a string that will be displayed and used as an ID,
// whereas "str_id" denote a string that is only used as an ID and not aimed to be displayed.
void          PushID(const(char)* str_id);                                     // push identifier into the ID stack. IDs are hash of the entire stack!
void          PushID(const(char)* str_id_begin, const(char)* str_id_end);
void          PushID(const(void)* ptr_id);
void          PushID(int int_id);
void          PopID();
ImGuiID       GetID(const(char)* str_id);                                      // calculate unique ID (hash of whole ID stack + given parameter). e.g. if you want to query into ImGuiStorage yourself
ImGuiID       GetID(const(char)* str_id_begin, const(char)* str_id_end);
ImGuiID       GetID(const(void)* ptr_id);

// Widgets: Text
void          TextUnformatted(const(char)* text, const(char)* text_end = null);                // raw text without formatting. Roughly equivalent to Text("%s", text) but: A) doesn't require null terminated string if 'text_end' is specified, B) it's faster, no memory copy is done, no buffer size limits, recommended for long chunks of text.
void          Text(const(char)* fmt, ...); // simple formatted text
void          TextColored(ref const ImVec4 col, const(char)* fmt, ...); // shortcut for PushStyleColor(ImGuiCol_Text, col); Text(fmt, ...); PopStyleColor();
void          TextDisabled(const(char)* fmt, ...); // shortcut for PushStyleColor(ImGuiCol_Text, style.Colors[ImGuiCol_TextDisabled]); Text(fmt, ...); PopStyleColor();
void          TextWrapped(const(char)* fmt, ...); // shortcut for PushTextWrapPos(0.0f); Text(fmt, ...); PopTextWrapPos();. Note that this won't work on an auto-resizing window if there's no other widgets to extend the window width, yoy may need to set a size using SetNextWindowSize().
void          LabelText(const(char)* label, const(char)* fmt, ...); // display text+label aligned the same way as value+label widgets
void          BulletText(const(char)* fmt, ...); // shortcut for Bullet()+Text()
void          TextV(const(char)* fmt, va_list args);
void          TextColoredV(const ref ImVec4 col, const(char)* fmt, va_list args);
void          TextDisabledV(const(char)* fmt, va_list args);
void          TextWrappedV(const(char)* fmt, va_list args);
void          LabelTextV(const(char)* label, const(char)* fmt, va_list args);
void          BulletTextV(const(char)* fmt, va_list args);

alias ImPlotDataGetterCallback = float function(void* data, int idx);

// Widgets: Main
bool          Button(const(char)* label, ref const ImVec2 size);    // button
bool          SmallButton(const(char)* label);                                 // button with FramePadding=(0,0) to easily embed within text
bool          ArrowButton(const(char)* str_id, ImGuiDir dir);
bool          InvisibleButton(const(char)* str_id, ref const ImVec2 size);        // button behavior without the visuals, useful to build custom behaviors using the public api (along with IsItemActive, IsItemHovered, etc.)
void          Image(ImTextureID user_texture_id, ref const ImVec2 size, ref const ImVec2 uv0, ref const ImVec2 uv1, ref const ImVec4 tint_col, ref const ImVec4 border_col);
bool          ImageButton(ImTextureID user_texture_id, ref const ImVec2 size, ref const ImVec2 uv0,  ref const ImVec2 uv1, int frame_padding, ref const ImVec4 bg_col, ref const ImVec4 tint_col);    // <0 frame_padding uses default frame padding settings. 0 for no padding
bool          Checkbox(const(char)* label, bool* v);
bool          CheckboxFlags(const(char)* label, uint* flags, uint flags_value);
bool          RadioButton(const(char)* label, bool active);
bool          RadioButton(const(char)* label, int* v, int v_button);
void          PlotLines(const(char)* label, const(float)* values, int values_count, int values_offset = 0, const(char)* overlay_text = null, float scale_min = float.max, float scale_max = float.max, ImVec2 graph_size = ImVec2(0,0), int stride = float.sizeof);
void          PlotLines(const(char)* label, ImPlotDataGetterCallback values_getter, void* data, int values_count, int values_offset = 0, const(char)* overlay_text = null, float scale_min = float.max, float scale_max = float.max, ImVec2 graph_size = ImVec2(0,0));
void          PlotHistogram(const(char)* label, const(float)* values, int values_count, int values_offset = 0, const(char)* overlay_text = null, float scale_min = float.max, float scale_max = float.max, ImVec2 graph_size = ImVec2(0,0), int stride = float.sizeof);
void          PlotHistogram(const(char)* label, ImPlotDataGetterCallback values_getter, void* data, int values_count, int values_offset = 0, const(char)* overlay_text = null, float scale_min = float.max, float scale_max = float.max, ImVec2 graph_size = ImVec2(0,0));
void          ProgressBar(float fraction, ref const ImVec2 size_arg, const(char)* overlay = null);
void          Bullet();                                                       // draw a small circle and keep the cursor on the same line. advance cursor x position by GetTreeNodeToLabelSpacing(), same distance that TreeNode() uses

alias ImComboGetterCallback = bool function(void* data, int idx, const(char)** out_text);

// Widgets: Combo Box
// The new BeginCombo()/EndCombo() api allows you to manage your contents and selection state however you want it.
// The old Combo() api are helpers over BeginCombo()/EndCombo() which are kept available for convenience purpose.
bool          BeginCombo(const(char)* label, const(char)* preview_value, ImGuiComboFlags flags = 0);
void          EndCombo(); // only call EndCombo() if BeginCombo() returns true!
bool          Combo(const(char)* label, int* current_item, const(char)** items, int items_count, int popup_max_height_in_items = -1);
bool          Combo(const(char)* label, int* current_item, const(char)* items_separated_by_zeros, int popup_max_height_in_items = -1);      // Separate items with \0 within a string, end item-list with \0\0. e.g. "One\0Two\0Three\0"
bool          Combo(const(char)* label, int* current_item, ImComboGetterCallback items_getter, void* data, int items_count, int popup_max_height_in_items = -1);

// Widgets: Drags (tip: ctrl+click on a drag box to input with keyboard. manually input values aren't clamped, can go off-bounds)
// For all the Float2/Float3/Float4/Int2/Int3/Int4 versions of every functions, note that a 'float v[X]' function argument is the same as 'float* v', the array syntax is just a way to document the number of elements that are expected to be accessible. You can pass address of your first element out of a contiguous set, e.g. &myvector.x
// Adjust format string to decorate the value with a prefix, a suffix, or adapt the editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs; "Biscuit: %.0f" -> Biscuit: 1; etc.
// Speed are per-pixel of mouse movement (v_speed=0.2f: mouse needs to move by 5 pixels to increase value by 1). For gamepad/keyboard navigation, minimum speed is Max(v_speed, minimum_step_at_given_precision).
bool          DragFloat (const(char)* label, float* v, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* format = "%.3f", float power = 1.0f);     // If v_min >= v_max we have no bound
bool          DragFloat2(const(char)* label, float* v, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* format = "%.3f", float power = 1.0f);
bool          DragFloat3(const(char)* label, float* v, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* format = "%.3f", float power = 1.0f);
bool          DragFloat4(const(char)* label, float* v, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* format = "%.3f", float power = 1.0f);
bool          DragFloatRange2(const(char)* label, float* v_current_min, float* v_current_max, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* format = "%.3f", const(char)* format_max = null, float power = 1.0f);
bool          DragInt (const(char)* label, int* v, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* format = "%d");                                       // If v_min >= v_max we have no bound
bool          DragInt2(const(char)* label, int* v, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* format = "%d");
bool          DragInt3(const(char)* label, int* v, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* format = "%d");
bool          DragInt4(const(char)* label, int* v, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* format = "%d");
bool          DragIntRange2(const(char)* label, int* v_current_min, int* v_current_max, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* format = "%d", const(char)* format_max = null);
bool          DragScalar(const(char)* label, ImGuiDataType data_type, void* v, float v_speed, const(void)* v_min = null, const(void)* v_max = null, const(char)* format = null, float power = 1.0f);
bool          DragScalarN(const(char)* label, ImGuiDataType data_type, void* v, int components, float v_speed, const(void)* v_min = null, const(void)* v_max = null, const(char)* format = null, float power = 1.0f);

// Widgets: Input with Keyboard
bool          InputText(const(char)* label, char* buf, size_t buf_size, ImGuiInputTextFlags flags = 0, ImGuiInputTextCallback callback = null, void* user_data = null);
bool          InputTextMultiline(const(char)* label, char* buf, size_t buf_size, ref const ImVec2 size, ImGuiInputTextFlags flags = 0, ImGuiInputTextCallback callback = null, void* user_data = null);
bool          InputFloat (const(char)* label, float* v, float step = 0.0f, float step_fast = 0.0f, const(char)* format = "%.3f", ImGuiInputTextFlags extra_flags = 0);
bool          InputFloat2(const(char)* label, float* v, const(char)* format = "%.3f", ImGuiInputTextFlags extra_flags = 0);
bool          InputFloat3(const(char)* label, float* v, const(char)* format = "%.3f", ImGuiInputTextFlags extra_flags = 0);
bool          InputFloat4(const(char)* label, float* v, const(char)* format = "%.3f", ImGuiInputTextFlags extra_flags = 0);
bool          InputInt (const(char)* label, int* v, int step = 1, int step_fast = 100, ImGuiInputTextFlags extra_flags = 0);
bool          InputInt2(const(char)* label, int* v, ImGuiInputTextFlags extra_flags = 0);
bool          InputInt3(const(char)* label, int* v, ImGuiInputTextFlags extra_flags = 0);
bool          InputInt4(const(char)* label, int* v, ImGuiInputTextFlags extra_flags = 0);
bool          InputDouble(const(char)* label, double* v, double step = 0.0f, double step_fast = 0.0f, const(char)* format = "%.6f", ImGuiInputTextFlags extra_flags = 0);
bool          InputScalar(const(char)* label, ImGuiDataType data_type, void* v, const(void)* step = null, const(void)* step_fast = null, const(char)* format = null, ImGuiInputTextFlags extra_flags = 0);
bool          InputScalarN(const(char)* label, ImGuiDataType data_type, void* v, int components, const(void)* step = null, const(void)* step_fast = null, const(char)* format = null, ImGuiInputTextFlags extra_flags = 0);

// Widgets: Sliders (tip: ctrl+click on a slider to input with keyboard. manually input values aren't clamped, can go off-bounds)
// Adjust format string to decorate the value with a prefix, a suffix, or adapt the editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs; "Biscuit: %.0f" -> Biscuit: 1; etc.
bool          SliderFloat(const(char)* label, float* v, float v_min, float v_max, const(char)* format = "%.3f", float power = 1.0f);     // adjust format to decorate the value with a prefix or a suffix for in-slider labels or unit display. Use power!=1.0 for power curve sliders
bool          SliderFloat2(const(char)* label, float* v, float v_min, float v_max, const(char)* format = "%.3f", float power = 1.0f);
bool          SliderFloat3(const(char)* label, float* v, float v_min, float v_max, const(char)* format = "%.3f", float power = 1.0f);
bool          SliderFloat4(const(char)* label, float* v, float v_min, float v_max, const(char)* format = "%.3f", float power = 1.0f);
bool          SliderAngle(const(char)* label, float* v_rad, float v_degrees_min = -360.0f, float v_degrees_max = +360.0f, const(char)* format = "%.0f deg");
bool          SliderInt(const(char)* label, int* v, int v_min, int v_max, const(char)* format = "%d");
bool          SliderInt2(const(char)* label, int* v, int v_min, int v_max, const(char)* format = "%d");
bool          SliderInt3(const(char)* label, int* v, int v_min, int v_max, const(char)* format = "%d");
bool          SliderInt4(const(char)* label, int* v, int v_min, int v_max, const(char)* format = "%d");
bool          SliderScalar(const(char)* label, ImGuiDataType data_type, void* v, const(void)* v_min, const(void)* v_max, const(char)* format = null, float power = 1.0f);
bool          SliderScalarN(const(char)* label, ImGuiDataType data_type, void* v, int components, const(void)* v_min, const(void)* v_max, const(char)* format = null, float power = 1.0f);
bool          VSliderFloat(const(char)* label, ref const ImVec2 size, float* v, float v_min, float v_max, const(char)* format = "%.3f", float power = 1.0f);
bool          VSliderInt(const(char)* label, ref const ImVec2 size, int* v, int v_min, int v_max, const(char)* format = "%d");
bool          VSliderScalar(const(char)* label, ref const ImVec2 size, ImGuiDataType data_type, void* v, const(void)* v_min, const(void)* v_max, const(char)* format = null, float power = 1.0f);

// Widgets: Color Editor/Picker (tip: the ColorEdit* functions have a little colored preview square that can be left-clicked to open a picker, and right-clicked to open an option menu.)
// Note that a 'float v[X]' function argument is the same as 'float* v', the array syntax is just a way to document the number of elements that are expected to be accessible. You can the pass the address of a first float element out of a contiguous structure, e.g. &myvector.x
bool          ColorEdit3(const(char)* label, float* col, ImGuiColorEditFlags flags = 0);
bool          ColorEdit4(const(char)* label, float* col, ImGuiColorEditFlags flags = 0);
bool          ColorPicker3(const(char)* label, float* col, ImGuiColorEditFlags flags = 0);
bool          ColorPicker4(const(char)* label, float* col, ImGuiColorEditFlags flags = 0, const(float)* ref_col = null);
bool          ColorButton(const(char)* desc_id, ref const ImVec4 col, ImGuiColorEditFlags flags = 0, ImVec2 size = ImVec2(0,0));  // display a colored square/button, hover for details, return true when pressed.
void          SetColorEditOptions(ImGuiColorEditFlags flags);                     // initialize current options (generally on application startup) if you want to select a default format, picker type, etc. User will be able to change many settings, unless you pass the _NoOptions flag to your calls.

// Widgets: Trees
bool          TreeNode(const(char)* label);                                        // if returning 'true' the node is open and the tree id is pushed into the id stack. user is responsible for calling TreePop().
bool          TreeNode(const(char)* str_id, const(char)* fmt, ...);   // read the FAQ about why and how to use ID. to align arbitrary text at the same level as a TreeNode() you can use Bullet().
bool          TreeNode(const(void)* ptr_id, const(char)* fmt, ...);   // "
bool          TreeNodeEx(const(char)* label, ImGuiTreeNodeFlags flags = 0);
bool          TreeNodeEx(const(char)* str_id, ImGuiTreeNodeFlags flags, const(char)* fmt, ...);
bool          TreeNodeEx(const(void)* ptr_id, ImGuiTreeNodeFlags flags, const(char)* fmt, ...);
bool          TreeNodeV(const(char)* str_id, const(char)* fmt, va_list args);
bool          TreeNodeV(const(void)* ptr_id, const(char)* fmt, va_list args);
bool          TreeNodeExV(const(char)* str_id, ImGuiTreeNodeFlags flags, const(char)* fmt, va_list args);
bool          TreeNodeExV(const(void)* ptr_id, ImGuiTreeNodeFlags flags, const(char)* fmt, va_list args);
void          TreePush(const(char)* str_id);                                       // ~ Indent()+PushId(). Already called by TreeNode() when returning true, but you can call Push/Pop yourself for layout purpose
void          TreePush(const(void)* ptr_id = null);                                // "
void          TreePop();                                                          // ~ Unindent()+PopId()
void          TreeAdvanceToLabelPos();                                            // advance cursor x position by GetTreeNodeToLabelSpacing()
float         GetTreeNodeToLabelSpacing();                                        // horizontal distance preceding label when using TreeNode*() or Bullet() == (g.FontSize + style.FramePadding.x*2) for a regular unframed TreeNode
void          SetNextTreeNodeOpen(bool is_open, ImGuiCond cond = 0);              // set next TreeNode/CollapsingHeader open state.
bool          CollapsingHeader(const(char)* label, ImGuiTreeNodeFlags flags = 0);  // if returning 'true' the header is open. doesn't indent nor push on ID stack. user doesn't have to call TreePop().
bool          CollapsingHeader(const(char)* label, bool* p_open, ImGuiTreeNodeFlags flags = 0); // when 'p_open' isn't null, display an additional small close button on upper right of the header

alias ImListBoxGetterCallback = bool function(void* data, int idx, const(char)** out_text);

// Widgets: Selectable / Lists
bool          Selectable(const(char)* label, bool selected, ImGuiSelectableFlags flags, ref const ImVec2 size);  // "bool selected" carry the selection state (read-only). Selectable() is clicked is returns true so you can modify your selection state. size.x==0.0: use remaining width, size.x>0.0: specify width. size.y==0.0: use label height, size.y>0.0: specify height
bool          Selectable(const(char)* label, bool* p_selected, ImGuiSelectableFlags flags, ref const ImVec2 size);       // "bool* p_selected" point to the selection state (read-write), as a convenient helper.
bool          ListBox(const(char)* label, int* current_item, const(char)** items, int items_count, int height_in_items = -1);
bool          ListBox(const(char)* label, int* current_item, ImListBoxGetterCallback items_getter, void* data, int items_count, int height_in_items = -1);
bool          ListBoxHeader(const(char)* label, ref const ImVec2 size); // use if you want to reimplement ListBox() will custom data or interactions. if the function return true, you can output elements then call ListBoxFooter() afterwards.
bool          ListBoxHeader(const(char)* label, int items_count, int height_in_items = -1); // "
void          ListBoxFooter();                                                    // terminate the scrolling region. only call ListBoxFooter() if ListBoxHeader() returned true!

// Widgets: Value() Helpers. Output single value in "name: value" format (tip: freely declare more in your code to handle your types. you can add functions to the ImGui namespace)
void          Value(const(char)* prefix, bool b);
void          Value(const(char)* prefix, int v);
void          Value(const(char)* prefix, uint v);
void          Value(const(char)* prefix, float v, const(char)* float_format = null);

// Tooltips
void          SetTooltip(const(char)* fmt, ...);                     // set text tooltip under mouse-cursor, typically use with ImGui::IsItemHovered(). overidde any previous call to SetTooltip().
void          SetTooltipV(const(char)* fmt, va_list args);
void          BeginTooltip();                                                     // begin/append a tooltip window. to create full-featured tooltip (with any kind of contents).
void          EndTooltip();

// Menus
bool          BeginMainMenuBar();                                                 // create and append to a full screen menu-bar.
void          EndMainMenuBar();                                                   // only call EndMainMenuBar() if BeginMainMenuBar() returns true!
bool          BeginMenuBar();                                                     // append to menu-bar of current window (requires ImGuiWindowFlags_MenuBar flag set on parent window).
void          EndMenuBar();                                                       // only call EndMenuBar() if BeginMenuBar() returns true!
bool          BeginMenu(const(char)* label, bool enabled = true);                  // create a sub-menu entry. only call EndMenu() if this returns true!
void          EndMenu();                                                          // only call EndMenu() if BeginMenu() returns true!
bool          MenuItem(const(char)* label, const(char)* shortcut = null, bool selected = false, bool enabled = true);  // return true when activated. shortcuts are displayed for convenience but not processed by ImGui at the moment
bool          MenuItem(const(char)* label, const(char)* shortcut, bool* p_selected, bool enabled = true);              // return true when activated + toggle (*p_selected) if p_selected != null

// Popups
void          OpenPopup(const(char)* str_id);                                      // call to mark popup as open (don't call every frame!). popups are closed when user click outside, or if CloseCurrentPopup() is called within a BeginPopup()/EndPopup() block. By default, Selectable()/MenuItem() are calling CloseCurrentPopup(). Popup identifiers are relative to the current ID-stack (so OpenPopup and BeginPopup needs to be at the same level).
bool          BeginPopup(const(char)* str_id, ImGuiWindowFlags flags = 0);                                             // return true if the popup is open, and you can start outputting to it. only call EndPopup() if BeginPopup() returns true!
bool          BeginPopupContextItem(const(char)* str_id = null, int mouse_button = 1);                                 // helper to open and begin popup when clicked on last item. if you can pass a null str_id only if the previous item had an id. If you want to use that on a non-interactive item such as Text() you need to pass in an explicit ID here. read comments in .cpp!
bool          BeginPopupContextWindow(const(char)* str_id = null, int mouse_button = 1, bool also_over_items = true);  // helper to open and begin popup when clicked on current window.
bool          BeginPopupContextVoid(const(char)* str_id = null, int mouse_button = 1);                                 // helper to open and begin popup when clicked in void (where there are no imgui windows).
bool          BeginPopupModal(const(char)* name, bool* p_open = null, ImGuiWindowFlags flags = 0);                     // modal dialog (regular window with title bar, block interactions behind the modal window, can't close the modal window by clicking outside)
void          EndPopup();                                                                                             // only call EndPopup() if BeginPopupXXX() returns true!
bool          OpenPopupOnItemClick(const(char)* str_id = null, int mouse_button = 1);                                  // helper to open popup when clicked on last item. return true when just opened.
bool          IsPopupOpen(const(char)* str_id);                                    // return true if the popup is open
void          CloseCurrentPopup();                                                // close the popup we have begin-ed into. clicking on a MenuItem or Selectable automatically close the current popup.

// Columns
// You can also use SameLine(pos_x) for simplified columns. The columns API is still work-in-progress and rather lacking.
void          Columns(int count = 1, const(char)* id = null, bool border = true);
void          NextColumn();                                                       // next column, defaults to current row or next row if the current row is finished
int           GetColumnIndex();                                                   // get current column index
float         GetColumnWidth(int column_index = -1);                              // get column width (in pixels). pass -1 to use current column
void          SetColumnWidth(int column_index, float width);                      // set column width (in pixels). pass -1 to use current column
float         GetColumnOffset(int column_index = -1);                             // get position of column line (in pixels, from the left side of the contents region). pass -1 to use current column, otherwise 0..GetColumnsCount() inclusive. column 0 is typically 0.0f
void          SetColumnOffset(int column_index, float offset_x);                  // set position of column line (in pixels, from the left side of the contents region). pass -1 to use current column
int           GetColumnsCount();

// Tab Bars, Tabs
// [BETA API] API may evolve!
bool          BeginTabBar(const(char)* str_id, ImGuiTabBarFlags flags = 0);        // create and append into a TabBar
void          EndTabBar();                                                        // only call EndTabBar() if BeginTabBar() returns true!
bool          BeginTabItem(const(char)* label, bool* p_open = null, ImGuiTabItemFlags flags = 0);// create a Tab. Returns true if the Tab is selected.
void          EndTabItem();                                                       // only call EndTabItem() if BeginTabItem() returns true!
void          SetTabItemClosed(const(char)* tab_or_docked_window_label);           // notify TabBar or Docking system of a closed tab/window ahead (useful to reduce visual flicker on reorderable tab bars). For tab-bar: call after BeginTabBar() and before Tab submissions. Otherwise call with a window name.


// Logging/Capture: all text output from interface is captured to tty/file/clipboard. By default, tree nodes are automatically opened during logging.
void          LogToTTY(int max_depth = -1);                                       // start logging to tty
void          LogToFile(int max_depth = -1, const(char)* filename = null);         // start logging to file
void          LogToClipboard(int max_depth = -1);                                 // start logging to OS clipboard
void          LogFinish();                                                        // stop logging (close file, etc.)
void          LogButtons();                                                       // helper to display buttons for logging to tty/file/clipboard
void          LogText(const(char)* fmt, ...);                        // pass text data straight to log (without being displayed)

// Drag and Drop
// [BETA API] Missing Demo code. API may evolve.
bool          BeginDragDropSource(ImGuiDragDropFlags flags = 0);                                      // call when the current item is active. If this return true, you can call SetDragDropPayload() + EndDragDropSource()
bool          SetDragDropPayload(const(char)* type, const(void)* data, size_t size, ImGuiCond cond = 0);// type is a user defined string of maximum 32 characters. Strings starting with '_' are reserved for dear imgui internal types. Data is copied and held by imgui.
void          EndDragDropSource();                                                                    // only call EndDragDropSource() if BeginDragDropSource() returns true!
bool          BeginDragDropTarget();                                                                  // call after submitting an item that may receive an item. If this returns true, you can call AcceptDragDropPayload() + EndDragDropTarget()
const(ImGuiPayload)* AcceptDragDropPayload(const(char)* type, ImGuiDragDropFlags flags = 0);            // accept contents of a given type. If ImGuiDragDropFlags_AcceptBeforeDelivery is set you can peek into the payload before the mouse button is released.
void          EndDragDropTarget();                                                                    // only call EndDragDropTarget() if BeginDragDropTarget() returns true!

// Clipping
void          PushClipRect(ref const ImVec2 clip_rect_min, ref const ImVec2 clip_rect_max, bool intersect_with_current_clip_rect);
void          PopClipRect();

// Focus, Activation
// (Prefer using "SetItemDefaultFocus()" over "if (IsWindowAppearing()) SetScrollHere()" when applicable, to make your code more forward compatible when navigation branch is merged)
void          SetItemDefaultFocus();                                              // make last item the default focused item of a window. Please use instead of "if (IsWindowAppearing()) SetScrollHere()" to signify "default item".
void          SetKeyboardFocusHere(int offset = 0);                               // focus keyboard on the next widget. Use positive 'offset' to access sub components of a multiple component widget. Use -1 to access previous widget.

// Utilities
bool          IsItemHovered(ImGuiHoveredFlags flags = 0);                         // is the last item hovered? (and usable, aka not blocked by a popup, etc.). See ImGuiHoveredFlags for more options.
bool          IsItemActive();                                                     // is the last item active? (e.g. button being held, text field being edited- items that don't interact will always return false)
bool          IsItemFocused();                                                    // is the last item focused for keyboard/gamepad navigation?
bool          IsItemClicked(int mouse_button = 0);                                // is the last item clicked? (e.g. button/node just clicked on)
bool          IsItemVisible();                                                    // is the last item visible? (aka not out of sight due to clipping/scrolling.)
bool          IsItemEdited();                                                     // did the last item modify its underlying value this frame? or was pressed? This is generally the same as the "bool" return value of many widgets.
bool          IsItemDeactivated();                                                // was the last item just made inactive (item was previously active). Useful for Undo/Redo patterns with widgets that requires continuous editing.
bool          IsItemDeactivatedAfterEdit();                                       // was the last item just made inactive and made a value change when it was active? (e.g. Slider/Drag moved). Useful for Undo/Redo patterns with widgets that requires continuous editing. Note that you may get false positives (some widgets such as Combo()/ListBox()/Selectable() will return true even when clicking an already selected item).
bool          IsAnyItemHovered();
bool          IsAnyItemActive();
bool          IsAnyItemFocused();
ImVec2        GetItemRectMin();                                                   // get bounding rectangle of last item, in screen space
ImVec2        GetItemRectMax();                                                   // "
ImVec2        GetItemRectSize();                                                  // get size of last item, in screen space
void          SetItemAllowOverlap();                                              // allow last item to be overlapped by a subsequent item. sometimes useful with invisible buttons, selectables, etc. to catch unused area.
bool          IsRectVisible(ref const ImVec2 size);                                  // test if rectangle (of given size, starting from cursor position) is visible / not clipped.
bool          IsRectVisible(ref const ImVec2 rect_min, ref const ImVec2 rect_max);      // test if rectangle (in screen space) is visible / not clipped. to perform coarse clipping on user's side.
double        GetTime();
int           GetFrameCount();
ImDrawList*   GetOverlayDrawList();                                               // this draw list will be the last rendered one, useful to quickly draw overlays shapes/text
ImDrawListSharedData* GetDrawListSharedData();                                    // you may use this when creating your own ImDrawList instances
const(char)*   GetStyleColorName(ImGuiCol idx);
void          SetStateStorage(ImGuiStorage* storage);                             // replace current window storage with our own (if you want to manipulate it yourself, typically clear subsection of it)
ImGuiStorage* GetStateStorage();
ImVec2        CalcTextSize(const(char)* text, const(char)* text_end = null, bool hide_text_after_double_hash = false, float wrap_width = -1.0f);
void          CalcListClipping(int items_count, float items_height, int* out_items_display_start, int* out_items_display_end);    // calculate coarse clipping for large list of evenly sized items. Prefer using the ImGuiListClipper higher-level helper if you can.

bool          BeginChildFrame(ImGuiID id, ref const ImVec2 size, ImGuiWindowFlags flags = 0); // helper to create a child window / scrolling region that looks like a normal widget frame
void          EndChildFrame();                                                    // always call EndChildFrame() regardless of BeginChildFrame() return values (which indicates a collapsed/clipped window)

ImVec4        ColorConvertU32ToFloat4(ImU32 in_);
ImU32         ColorConvertFloat4ToU32(ref const ImVec4 in_);
void          ColorConvertRGBtoHSV(float r, float g, float b, ref float out_h, ref float out_s, ref float out_v);
void          ColorConvertHSVtoRGB(float h, float s, float v, ref float out_r, ref float out_g, ref float out_b);

// Inputs
int           GetKeyIndex(ImGuiKey imgui_key);                                    // map ImGuiKey_* values into user's key index. == io.KeyMap[key]
bool          IsKeyDown(int user_key_index);                                      // is key being held. == io.KeysDown[user_key_index]. note that imgui doesn't know the semantic of each entry of io.KeysDown[]. Use your own indices/enums according to how your backend/engine stored them into io.KeysDown[]!
bool          IsKeyPressed(int user_key_index, bool repeat = true);               // was key pressed (went from !Down to Down). if repeat=true, uses io.KeyRepeatDelay / KeyRepeatRate
bool          IsKeyReleased(int user_key_index);                                  // was key released (went from Down to !Down)..
int           GetKeyPressedAmount(int key_index, float repeat_delay, float rate); // uses provided repeat rate/delay. return a count, most often 0 or 1 but might be >1 if RepeatRate is small enough that DeltaTime > RepeatRate
bool          IsMouseDown(int button);                                            // is mouse button held
bool          IsAnyMouseDown();                                                   // is any mouse button held
bool          IsMouseClicked(int button, bool repeat = false);                    // did mouse button clicked (went from !Down to Down)
bool          IsMouseDoubleClicked(int button);                                   // did mouse button double-clicked. a double-click returns false in IsMouseClicked(). uses io.MouseDoubleClickTime.
bool          IsMouseReleased(int button);                                        // did mouse button released (went from Down to !Down)
bool          IsMouseDragging(int button = 0, float lock_threshold = -1.0f);      // is mouse dragging. if lock_threshold < -1.0f uses io.MouseDraggingThreshold
bool          IsMouseHoveringRect(ref const ImVec2 r_min, ref const ImVec2 r_max, bool clip = true);  // is mouse hovering given bounding rect (in screen space). clipped by current clipping settings. disregarding of consideration of focus/window ordering/blocked by a popup.
bool          IsMousePosValid(const(ImVec2)* mouse_pos = null);                    //
ImVec2        GetMousePos();                                                      // shortcut to ImGui::GetIO().MousePos provided by user, to be consistent with other calls
ImVec2        GetMousePosOnOpeningCurrentPopup();                                 // retrieve backup of mouse position at the time of opening popup we have BeginPopup() into
ImVec2        GetMouseDragDelta(int button = 0, float lock_threshold = -1.0f);    // dragging amount since clicking. if lock_threshold < -1.0f uses io.MouseDraggingThreshold
void          ResetMouseDragDelta(int button = 0);                                //
ImGuiMouseCursor GetMouseCursor();                                                // get desired cursor type, reset in ImGui::NewFrame(), this is updated during the frame. valid before Render(). If you use software rendering by setting io.MouseDrawCursor ImGui will render those for you
void          SetMouseCursor(ImGuiMouseCursor type);                              // set desired cursor type
void          CaptureKeyboardFromApp(bool capture = true);                        // manually override io.WantCaptureKeyboard flag next frame (said flag is entirely left for your application to handle). e.g. force capture keyboard when your widget is being hovered.
void          CaptureMouseFromApp(bool capture = true);                           // manually override io.WantCaptureMouse flag next frame (said flag is entirely left for your application to handle).

// Clipboard Utilities (also see the LogToClipboard() function to capture or output text data to the clipboard)
const(char)*   GetClipboardText();
void          SetClipboardText(const(char)* text);

// Settings/.Ini Utilities
// The disk functions are automatically called if io.IniFilename != null (default is "imgui.ini").
// Set io.IniFilename to null to load/save manually. Read io.WantSaveIniSettings description about handling .ini saving manually.
void          LoadIniSettingsFromDisk(const(char)* ini_filename);                  // call after CreateContext() and before the first call to NewFrame(). NewFrame() automatically calls LoadIniSettingsFromDisk(io.IniFilename).
void          LoadIniSettingsFromMemory(const(char)* ini_data, size_t ini_size=0); // call after CreateContext() and before the first call to NewFrame() to provide .ini data from your own data source.
void          SaveIniSettingsToDisk(const(char)* ini_filename);
const(char)*   SaveIniSettingsToMemory(size_t* out_ini_size = null);               // return a zero-terminated string with the .ini data which you can save by your own mean. call when io.WantSaveIniSettings is set, then save data by your own mean and clear io.WantSaveIniSettings.

alias ImAllocCallback = void* function(size_t sz, void* user_data);
alias ImFreeCallback = void function(void* ptr, void* user_data);

// Memory Utilities
// All those functions are not reliant on the current context.
// If you reload the contents of imgui.cpp at runtime, you may need to call SetCurrentContext() + SetAllocatorFunctions() again.
void          SetAllocatorFunctions(ImAllocCallback alloc_func, ImFreeCallback free_func, void* user_data = null);
void*         MemAlloc(size_t size);
void          MemFree(void* ptr);

}

// Flags for ImGui::Begin()
enum
{
    ImGuiWindowFlags_None                   = 0,
    ImGuiWindowFlags_NoTitleBar             = 1 << 0,   // Disable title-bar
    ImGuiWindowFlags_NoResize               = 1 << 1,   // Disable user resizing with the lower-right grip
    ImGuiWindowFlags_NoMove                 = 1 << 2,   // Disable user moving the window
    ImGuiWindowFlags_NoScrollbar            = 1 << 3,   // Disable scrollbars (window can still scroll with mouse or programatically)
    ImGuiWindowFlags_NoScrollWithMouse      = 1 << 4,   // Disable user vertically scrolling with mouse wheel. On child window, mouse wheel will be forwarded to the parent unless NoScrollbar is also set.
    ImGuiWindowFlags_NoCollapse             = 1 << 5,   // Disable user collapsing window by double-clicking on it
    ImGuiWindowFlags_AlwaysAutoResize       = 1 << 6,   // Resize every window to its content every frame
    ImGuiWindowFlags_NoBackground           = 1 << 7,   // Disable drawing background color (WindowBg, etc.) and outside border. Similar as using SetNextWindowBgAlpha(0.0f).
    ImGuiWindowFlags_NoSavedSettings        = 1 << 8,   // Never load/save settings in .ini file
    ImGuiWindowFlags_NoMouseInputs          = 1 << 9,   // Disable catching mouse, hovering test with pass through.
    ImGuiWindowFlags_MenuBar                = 1 << 10,  // Has a menu-bar
    ImGuiWindowFlags_HorizontalScrollbar    = 1 << 11,  // Allow horizontal scrollbar to appear (off by default). You may use SetNextWindowContentSize(ImVec2(width,0.0f)); prior to calling Begin() to specify width. Read code in imgui_demo in the "Horizontal Scrolling" section.
    ImGuiWindowFlags_NoFocusOnAppearing     = 1 << 12,  // Disable taking focus when transitioning from hidden to visible state
    ImGuiWindowFlags_NoBringToFrontOnFocus  = 1 << 13,  // Disable bringing window to front when taking focus (e.g. clicking on it or programatically giving it focus)
    ImGuiWindowFlags_AlwaysVerticalScrollbar= 1 << 14,  // Always show vertical scrollbar (even if ContentSize.y < Size.y)
    ImGuiWindowFlags_AlwaysHorizontalScrollbar=1<< 15,  // Always show horizontal scrollbar (even if ContentSize.x < Size.x)
    ImGuiWindowFlags_AlwaysUseWindowPadding = 1 << 16,  // Ensure child windows without border uses style.WindowPadding (ignored by default for non-bordered child windows, because more convenient)
    ImGuiWindowFlags_NoNavInputs            = 1 << 18,  // No gamepad/keyboard navigation within the window
    ImGuiWindowFlags_NoNavFocus             = 1 << 19,  // No focusing toward this window with gamepad/keyboard navigation (e.g. skipped by CTRL+TAB)
    ImGuiWindowFlags_UnsavedDocument        = 1 << 20,  // Append '*' to title without affecting the ID, as a convenience to avoid using the ### operator. When used in a tab/docking context, tab is selected on closure and closure is deferred by one frame to allow code to cancel the closure (with a confirmation popup, etc.) without flicker.
    ImGuiWindowFlags_NoNav                  = ImGuiWindowFlags_NoNavInputs | ImGuiWindowFlags_NoNavFocus,
    ImGuiWindowFlags_NoDecoration           = ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_NoCollapse,
    ImGuiWindowFlags_NoInputs               = ImGuiWindowFlags_NoMouseInputs | ImGuiWindowFlags_NoNavInputs | ImGuiWindowFlags_NoNavFocus,

    // [Internal]
    ImGuiWindowFlags_NavFlattened           = 1 << 23,  // [BETA] Allow gamepad/keyboard navigation to cross over parent border to this child (only use on child that have no scrolling!)
    ImGuiWindowFlags_ChildWindow            = 1 << 24,  // Don't use! For internal use by BeginChild()
    ImGuiWindowFlags_Tooltip                = 1 << 25,  // Don't use! For internal use by BeginTooltip()
    ImGuiWindowFlags_Popup                  = 1 << 26,  // Don't use! For internal use by BeginPopup()
    ImGuiWindowFlags_Modal                  = 1 << 27,  // Don't use! For internal use by BeginPopupModal()
    ImGuiWindowFlags_ChildMenu              = 1 << 28   // Don't use! For internal use by BeginMenu()
}

// Flags for ImGui::InputText()
enum
{
    ImGuiInputTextFlags_None                = 0,
    ImGuiInputTextFlags_CharsDecimal        = 1 << 0,   // Allow 0123456789.+-*/
    ImGuiInputTextFlags_CharsHexadecimal    = 1 << 1,   // Allow 0123456789ABCDEFabcdef
    ImGuiInputTextFlags_CharsUppercase      = 1 << 2,   // Turn a..z into A..Z
    ImGuiInputTextFlags_CharsNoBlank        = 1 << 3,   // Filter out spaces, tabs
    ImGuiInputTextFlags_AutoSelectAll       = 1 << 4,   // Select entire text when first taking mouse focus
    ImGuiInputTextFlags_EnterReturnsTrue    = 1 << 5,   // Return 'true' when Enter is pressed (as opposed to when the value was modified)
    ImGuiInputTextFlags_CallbackCompletion  = 1 << 6,   // Callback on pressing TAB (for completion handling)
    ImGuiInputTextFlags_CallbackHistory     = 1 << 7,   // Callback on pressing Up/Down arrows (for history handling)
    ImGuiInputTextFlags_CallbackAlways      = 1 << 8,   // Callback on each iteration. User code may query cursor position, modify text buffer.
    ImGuiInputTextFlags_CallbackCharFilter  = 1 << 9,   // Callback on character inputs to replace or discard them. Modify 'EventChar' to replace or discard, or return 1 in callback to discard.
    ImGuiInputTextFlags_AllowTabInput       = 1 << 10,  // Pressing TAB input a '\t' character into the text field
    ImGuiInputTextFlags_CtrlEnterForNewLine = 1 << 11,  // In multi-line mode, unfocus with Enter, add new line with Ctrl+Enter (default is opposite: unfocus with Ctrl+Enter, add line with Enter).
    ImGuiInputTextFlags_NoHorizontalScroll  = 1 << 12,  // Disable following the cursor horizontally
    ImGuiInputTextFlags_AlwaysInsertMode    = 1 << 13,  // Insert mode
    ImGuiInputTextFlags_ReadOnly            = 1 << 14,  // Read-only mode
    ImGuiInputTextFlags_Password            = 1 << 15,  // Password mode, display all characters as '*'
    ImGuiInputTextFlags_NoUndoRedo          = 1 << 16,  // Disable undo/redo. Note that input text owns the text data while active, if you want to provide your own undo/redo stack you need e.g. to call ClearActiveID().
    ImGuiInputTextFlags_CharsScientific     = 1 << 17,  // Allow 0123456789.+-*/eE (Scientific notation input)
    ImGuiInputTextFlags_CallbackResize      = 1 << 18,  // Callback on buffer capacity changes request (beyond 'buf_size' parameter value), allowing the string to grow. Notify when the string wants to be resized (for string types which hold a cache of their Size). You will be provided a new BufSize in the callback and NEED to honor it. (see misc/cpp/imgui_stdlib.h for an example of using this)
    // [Internal]
    ImGuiInputTextFlags_Multiline           = 1 << 20   // For internal use by InputTextMultiline()
}

// Flags for ImGui::TreeNodeEx(), ImGui::CollapsingHeader*()
enum
{
    ImGuiTreeNodeFlags_None                 = 0,
    ImGuiTreeNodeFlags_Selected             = 1 << 0,   // Draw as selected
    ImGuiTreeNodeFlags_Framed               = 1 << 1,   // Full colored frame (e.g. for CollapsingHeader)
    ImGuiTreeNodeFlags_AllowItemOverlap     = 1 << 2,   // Hit testing to allow subsequent widgets to overlap this one
    ImGuiTreeNodeFlags_NoTreePushOnOpen     = 1 << 3,   // Don't do a TreePush() when open (e.g. for CollapsingHeader) = no extra indent nor pushing on ID stack
    ImGuiTreeNodeFlags_NoAutoOpenOnLog      = 1 << 4,   // Don't automatically and temporarily open node when Logging is active (by default logging will automatically open tree nodes)
    ImGuiTreeNodeFlags_DefaultOpen          = 1 << 5,   // Default node to be open
    ImGuiTreeNodeFlags_OpenOnDoubleClick    = 1 << 6,   // Need double-click to open node
    ImGuiTreeNodeFlags_OpenOnArrow          = 1 << 7,   // Only open when clicking on the arrow part. If ImGuiTreeNodeFlags_OpenOnDoubleClick is also set, single-click arrow or double-click all box to open.
    ImGuiTreeNodeFlags_Leaf                 = 1 << 8,   // No collapsing, no arrow (use as a convenience for leaf nodes).
    ImGuiTreeNodeFlags_Bullet               = 1 << 9,   // Display a bullet instead of arrow
    ImGuiTreeNodeFlags_FramePadding         = 1 << 10,  // Use FramePadding (even for an unframed text node) to vertically align text baseline to regular widget height. Equivalent to calling AlignTextToFramePadding().
    //ImGuITreeNodeFlags_SpanAllAvailWidth  = 1 << 11,  // FIXME: TODO: Extend hit box horizontally even if not framed
    //ImGuiTreeNodeFlags_NoScrollOnOpen     = 1 << 12,  // FIXME: TODO: Disable automatic scroll on TreePop() if node got just open and contents is not visible
    ImGuiTreeNodeFlags_NavLeftJumpsBackHere = 1 << 13,  // (WIP) Nav: left direction may move to this TreeNode() from any of its child (items submitted between TreeNode and TreePop)
    ImGuiTreeNodeFlags_CollapsingHeader     = ImGuiTreeNodeFlags_Framed | ImGuiTreeNodeFlags_NoTreePushOnOpen | ImGuiTreeNodeFlags_NoAutoOpenOnLog

}

// Flags for ImGui::Selectable()
enum
{
    ImGuiSelectableFlags_None               = 0,
    ImGuiSelectableFlags_DontClosePopups    = 1 << 0,   // Clicking this don't close parent popup window
    ImGuiSelectableFlags_SpanAllColumns     = 1 << 1,   // Selectable frame can span all columns (text will still fit in current column)
    ImGuiSelectableFlags_AllowDoubleClick   = 1 << 2,   // Generate press events on double clicks too
    ImGuiSelectableFlags_Disabled           = 1 << 3    // Cannot be selected, display greyed out text

}

// Flags for ImGui::BeginCombo()
enum
{
    ImGuiComboFlags_None                    = 0,
    ImGuiComboFlags_PopupAlignLeft          = 1 << 0,   // Align the popup toward the left by default
    ImGuiComboFlags_HeightSmall             = 1 << 1,   // Max ~4 items visible. Tip: If you want your combo popup to be a specific size you can use SetNextWindowSizeConstraints() prior to calling BeginCombo()
    ImGuiComboFlags_HeightRegular           = 1 << 2,   // Max ~8 items visible (default)
    ImGuiComboFlags_HeightLarge             = 1 << 3,   // Max ~20 items visible
    ImGuiComboFlags_HeightLargest           = 1 << 4,   // As many fitting items as possible
    ImGuiComboFlags_NoArrowButton           = 1 << 5,   // Display on the preview box without the square arrow button
    ImGuiComboFlags_NoPreview               = 1 << 6,   // Display only a square arrow button
    ImGuiComboFlags_HeightMask_             = ImGuiComboFlags_HeightSmall | ImGuiComboFlags_HeightRegular | ImGuiComboFlags_HeightLarge | ImGuiComboFlags_HeightLargest
}

// Flags for ImGui::BeginTabBar()
enum
{
    ImGuiTabBarFlags_None                           = 0,
    ImGuiTabBarFlags_Reorderable                    = 1 << 0,   // Allow manually dragging tabs to re-order them + New tabs are appended at the end of list
    ImGuiTabBarFlags_AutoSelectNewTabs              = 1 << 1,   // Automatically select new tabs when they appear
    ImGuiTabBarFlags_NoCloseWithMiddleMouseButton   = 1 << 2,   // Disable behavior of closing tabs (that are submitted with p_open != NULL) with middle mouse button. You can still repro this behavior on user's side with if (IsItemHovered() && IsMouseClicked(2)) *p_open = false.
    ImGuiTabBarFlags_NoTabListPopupButton           = 1 << 3,
    ImGuiTabBarFlags_NoTabListScrollingButtons      = 1 << 4,
    ImGuiTabBarFlags_NoTooltip                      = 1 << 5,   // Disable tooltips when hovering a tab
    ImGuiTabBarFlags_FittingPolicyResizeDown        = 1 << 6,   // Resize tabs when they don't fit
    ImGuiTabBarFlags_FittingPolicyScroll            = 1 << 7,   // Add scroll buttons when tabs don't fit
    ImGuiTabBarFlags_FittingPolicyMask_             = ImGuiTabBarFlags_FittingPolicyResizeDown | ImGuiTabBarFlags_FittingPolicyScroll,
    ImGuiTabBarFlags_FittingPolicyDefault_          = ImGuiTabBarFlags_FittingPolicyResizeDown
}

// Flags for ImGui::BeginTabItem()
enum
{
    ImGuiTabItemFlags_None                          = 0,
    ImGuiTabItemFlags_UnsavedDocument               = 1 << 0,   // Append '*' to title without affecting the ID, as a convenience to avoid using the ### operator. Also: tab is selected on closure and closure is deferred by one frame to allow code to undo it without flicker.
    ImGuiTabItemFlags_SetSelected                   = 1 << 1,   // Trigger flag to programatically make the tab selected when calling BeginTabItem()
    ImGuiTabItemFlags_NoCloseWithMiddleMouseButton  = 1 << 2,   // Disable behavior of closing tabs (that are submitted with p_open != NULL) with middle mouse button. You can still repro this behavior on user's side with if (IsItemHovered() && IsMouseClicked(2)) *p_open = false.
    ImGuiTabItemFlags_NoPushId                      = 1 << 3    // Don't call PushID(tab->ID)/PopID() on BeginTabItem()/EndTabItem()
}

// Flags for ImGui::IsWindowFocused()
enum
{
    ImGuiFocusedFlags_None                          = 0,
    ImGuiFocusedFlags_ChildWindows                  = 1 << 0,   // IsWindowFocused(): Return true if any children of the window is focused
    ImGuiFocusedFlags_RootWindow                    = 1 << 1,   // IsWindowFocused(): Test from root window (top most parent of the current hierarchy)
    ImGuiFocusedFlags_AnyWindow                     = 1 << 2,   // IsWindowFocused(): Return true if any window is focused. Important: If you are trying to tell how to dispatch your low-level inputs, do NOT use this. Use ImGui::GetIO().WantCaptureMouse instead.
    ImGuiFocusedFlags_RootAndChildWindows           = ImGuiFocusedFlags_RootWindow | ImGuiFocusedFlags_ChildWindows
}

// Flags for ImGui::IsItemHovered(), ImGui::IsWindowHovered()
// Note: If you are trying to check whether your mouse should be dispatched to imgui or to your app, you should use the 'io.WantCaptureMouse' boolean for that. Please read the FAQ!
enum
{
    ImGuiHoveredFlags_None                          = 0,        // Return true if directly over the item/window, not obstructed by another window, not obstructed by an active popup or modal blocking inputs under them.
    ImGuiHoveredFlags_ChildWindows                  = 1 << 0,   // IsWindowHovered() only: Return true if any children of the window is hovered
    ImGuiHoveredFlags_RootWindow                    = 1 << 1,   // IsWindowHovered() only: Test from root window (top most parent of the current hierarchy)
    ImGuiHoveredFlags_AnyWindow                     = 1 << 2,   // IsWindowHovered() only: Return true if any window is hovered
    ImGuiHoveredFlags_AllowWhenBlockedByPopup       = 1 << 3,   // Return true even if a popup window is normally blocking access to this item/window
    //ImGuiHoveredFlags_AllowWhenBlockedByModal     = 1 << 4,   // Return true even if a modal popup window is normally blocking access to this item/window. FIXME-TODO: Unavailable yet.
    ImGuiHoveredFlags_AllowWhenBlockedByActiveItem  = 1 << 5,   // Return true even if an active item is blocking access to this item/window. Useful for Drag and Drop patterns.
    ImGuiHoveredFlags_AllowWhenOverlapped           = 1 << 6,   // Return true even if the position is overlapped by another window
    ImGuiHoveredFlags_AllowWhenDisabled             = 1 << 7,   // Return true even if the item is disabled
    ImGuiHoveredFlags_RectOnly                      = ImGuiHoveredFlags_AllowWhenBlockedByPopup | ImGuiHoveredFlags_AllowWhenBlockedByActiveItem | ImGuiHoveredFlags_AllowWhenOverlapped,
    ImGuiHoveredFlags_RootAndChildWindows           = ImGuiHoveredFlags_RootWindow | ImGuiHoveredFlags_ChildWindows
}

// Flags for ImGui::BeginDragDropSource(), ImGui::AcceptDragDropPayload()
enum
{
    ImGuiDragDropFlags_None                         = 0,
    // BeginDragDropSource() flags
    ImGuiDragDropFlags_SourceNoPreviewTooltip       = 1 << 0,   // By default, a successful call to BeginDragDropSource opens a tooltip so you can display a preview or description of the source contents. This flag disable this behavior.
    ImGuiDragDropFlags_SourceNoDisableHover         = 1 << 1,   // By default, when dragging we clear data so that IsItemHovered() will return false, to avoid subsequent user code submitting tooltips. This flag disable this behavior so you can still call IsItemHovered() on the source item.
    ImGuiDragDropFlags_SourceNoHoldToOpenOthers     = 1 << 2,   // Disable the behavior that allows to open tree nodes and collapsing header by holding over them while dragging a source item.
    ImGuiDragDropFlags_SourceAllowNullID            = 1 << 3,   // Allow items such as Text(), Image() that have no unique identifier to be used as drag source, by manufacturing a temporary identifier based on their window-relative position. This is extremely unusual within the dear imgui ecosystem and so we made it explicit.
    ImGuiDragDropFlags_SourceExtern                 = 1 << 4,   // External source (from outside of imgui), won't attempt to read current item/window info. Will always return true. Only one Extern source can be active simultaneously.
    ImGuiDragDropFlags_SourceAutoExpirePayload      = 1 << 5,   // Automatically expire the payload if the source cease to be submitted (otherwise payloads are persisting while being dragged)
    // AcceptDragDropPayload() flags
    ImGuiDragDropFlags_AcceptBeforeDelivery         = 1 << 10,  // AcceptDragDropPayload() will returns true even before the mouse button is released. You can then call IsDelivery() to test if the payload needs to be delivered.
    ImGuiDragDropFlags_AcceptNoDrawDefaultRect      = 1 << 11,  // Do not draw the default highlight rectangle when hovering over target.
    ImGuiDragDropFlags_AcceptNoPreviewTooltip       = 1 << 12,  // Request hiding the BeginDragDropSource tooltip from the BeginDragDropTarget site.
    ImGuiDragDropFlags_AcceptPeekOnly               = ImGuiDragDropFlags_AcceptBeforeDelivery | ImGuiDragDropFlags_AcceptNoDrawDefaultRect  // For peeking ahead and inspecting the payload before delivery.
}

// A primary data type
enum
{
    ImGuiDataType_S32,      // int
    ImGuiDataType_U32,      // unsigned int
    ImGuiDataType_S64,      // long long, __int64
    ImGuiDataType_U64,      // unsigned long long, unsigned __int64
    ImGuiDataType_Float,    // float
    ImGuiDataType_Double,   // double
    ImGuiDataType_COUNT
}

// A cardinal direction
enum
{
    ImGuiDir_None    = -1,
    ImGuiDir_Left    = 0,
    ImGuiDir_Right   = 1,
    ImGuiDir_Up      = 2,
    ImGuiDir_Down    = 3,
    ImGuiDir_COUNT
}

// User fill ImGuiIO.KeyMap[] array with indices into the ImGuiIO.KeysDown[512] array
enum
{
    ImGuiKey_Tab,
    ImGuiKey_LeftArrow,
    ImGuiKey_RightArrow,
    ImGuiKey_UpArrow,
    ImGuiKey_DownArrow,
    ImGuiKey_PageUp,
    ImGuiKey_PageDown,
    ImGuiKey_Home,
    ImGuiKey_End,
    ImGuiKey_Insert,
    ImGuiKey_Delete,
    ImGuiKey_Backspace,
    ImGuiKey_Space,
    ImGuiKey_Enter,
    ImGuiKey_Escape,
    ImGuiKey_A,         // for text edit CTRL+A: select all
    ImGuiKey_C,         // for text edit CTRL+C: copy
    ImGuiKey_V,         // for text edit CTRL+V: paste
    ImGuiKey_X,         // for text edit CTRL+X: cut
    ImGuiKey_Y,         // for text edit CTRL+Y: redo
    ImGuiKey_Z,         // for text edit CTRL+Z: undo
    ImGuiKey_COUNT
}

// [BETA] Gamepad/Keyboard directional navigation
// Keyboard: Set io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard to enable. NewFrame() will automatically fill io.NavInputs[] based on your io.KeysDown[] + io.KeyMap[] arrays.
// Gamepad:  Set io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad to enable. Back-end: set ImGuiBackendFlags_HasGamepad and fill the io.NavInputs[] fields before calling NewFrame(). Note that io.NavInputs[] is cleared by EndFrame().
// Read instructions in imgui.cpp for more details. Download PNG/PSD at goo.gl/9LgVZW.
enum
{
    // Gamepad Mapping
    ImGuiNavInput_Activate,      // activate / open / toggle / tweak value       // e.g. Cross  (PS4), A (Xbox), A (Switch), Space (Keyboard)
    ImGuiNavInput_Cancel,        // cancel / close / exit                        // e.g. Circle (PS4), B (Xbox), B (Switch), Escape (Keyboard)
    ImGuiNavInput_Input,         // text input / on-screen keyboard              // e.g. Triang.(PS4), Y (Xbox), X (Switch), Return (Keyboard)
    ImGuiNavInput_Menu,          // tap: toggle menu / hold: focus, move, resize // e.g. Square (PS4), X (Xbox), Y (Switch), Alt (Keyboard)
    ImGuiNavInput_DpadLeft,      // move / tweak / resize window (w/ PadMenu)    // e.g. D-pad Left/Right/Up/Down (Gamepads), Arrow keys (Keyboard)
    ImGuiNavInput_DpadRight,     //
    ImGuiNavInput_DpadUp,        //
    ImGuiNavInput_DpadDown,      //
    ImGuiNavInput_LStickLeft,    // scroll / move window (w/ PadMenu)            // e.g. Left Analog Stick Left/Right/Up/Down
    ImGuiNavInput_LStickRight,   //
    ImGuiNavInput_LStickUp,      //
    ImGuiNavInput_LStickDown,    //
    ImGuiNavInput_FocusPrev,     // next window (w/ PadMenu)                     // e.g. L1 or L2 (PS4), LB or LT (Xbox), L or ZL (Switch)
    ImGuiNavInput_FocusNext,     // prev window (w/ PadMenu)                     // e.g. R1 or R2 (PS4), RB or RT (Xbox), R or ZL (Switch)
    ImGuiNavInput_TweakSlow,     // slower tweaks                                // e.g. L1 or L2 (PS4), LB or LT (Xbox), L or ZL (Switch)
    ImGuiNavInput_TweakFast,     // faster tweaks                                // e.g. R1 or R2 (PS4), RB or RT (Xbox), R or ZL (Switch)

    // [Internal] Don't use directly! This is used internally to differentiate keyboard from gamepad inputs for behaviors that require to differentiate them.
    // Keyboard behavior that have no corresponding gamepad mapping (e.g. CTRL+TAB) will be directly reading from io.KeysDown[] instead of io.NavInputs[].
    ImGuiNavInput_KeyMenu_,      // toggle menu                                  // = io.KeyAlt
    ImGuiNavInput_KeyLeft_,      // move left                                    // = Arrow keys
    ImGuiNavInput_KeyRight_,     // move right
    ImGuiNavInput_KeyUp_,        // move up
    ImGuiNavInput_KeyDown_,      // move down
    ImGuiNavInput_COUNT,
    ImGuiNavInput_InternalStart_ = ImGuiNavInput_KeyMenu_
}

// Configuration flags stored in io.ConfigFlags. Set by user/application.
enum
{
    ImGuiConfigFlags_NavEnableKeyboard      = 1 << 0,   // Master keyboard navigation enable flag. NewFrame() will automatically fill io.NavInputs[] based on io.KeysDown[].
    ImGuiConfigFlags_NavEnableGamepad       = 1 << 1,   // Master gamepad navigation enable flag. This is mostly to instruct your imgui back-end to fill io.NavInputs[]. Back-end also needs to set ImGuiBackendFlags_HasGamepad.
    ImGuiConfigFlags_NavEnableSetMousePos   = 1 << 2,   // Instruct navigation to move the mouse cursor. May be useful on TV/console systems where moving a virtual mouse is awkward. Will update io.MousePos and set io.WantSetMousePos=true. If enabled you MUST honor io.WantSetMousePos requests in your binding, otherwise ImGui will react as if the mouse is jumping around back and forth.
    ImGuiConfigFlags_NavNoCaptureKeyboard   = 1 << 3,   // Instruct navigation to not set the io.WantCaptureKeyboard flag with io.NavActive is set.
    ImGuiConfigFlags_NoMouse                = 1 << 4,   // Instruct imgui to clear mouse position/buttons in NewFrame(). This allows ignoring the mouse information back-end
    ImGuiConfigFlags_NoMouseCursorChange    = 1 << 5,   // Instruct back-end to not alter mouse cursor shape and visibility.

    // User storage (to allow your back-end/engine to communicate to code that may be shared between multiple projects. Those flags are not used by core ImGui)
    ImGuiConfigFlags_IsSRGB                 = 1 << 20,  // Application is SRGB-aware.
    ImGuiConfigFlags_IsTouchScreen          = 1 << 21   // Application is using a touch screen instead of a mouse.
}

// Back-end capabilities flags stored in io.BackendFlags. Set by imgui_impl_xxx or custom back-end.
enum
{
    ImGuiBackendFlags_None                  = 0,
    ImGuiBackendFlags_HasGamepad            = 1 << 0,   // Back-end supports and has a connected gamepad.
    ImGuiBackendFlags_HasMouseCursors       = 1 << 1,   // Back-end supports reading GetMouseCursor() to change the OS cursor shape.
    ImGuiBackendFlags_HasSetMousePos        = 1 << 2    // Back-end supports io.WantSetMousePos requests to reposition the OS mouse position (only used if ImGuiConfigFlags_NavEnableSetMousePos is set).
}

// Enumeration for PushStyleColor() / PopStyleColor()
enum
{
    ImGuiCol_Text,
    ImGuiCol_TextDisabled,
    ImGuiCol_WindowBg,              // Background of normal windows
    ImGuiCol_ChildBg,               // Background of child windows
    ImGuiCol_PopupBg,               // Background of popups, menus, tooltips windows
    ImGuiCol_Border,
    ImGuiCol_BorderShadow,
    ImGuiCol_FrameBg,               // Background of checkbox, radio button, plot, slider, text input
    ImGuiCol_FrameBgHovered,
    ImGuiCol_FrameBgActive,
    ImGuiCol_TitleBg,
    ImGuiCol_TitleBgActive,
    ImGuiCol_TitleBgCollapsed,
    ImGuiCol_MenuBarBg,
    ImGuiCol_ScrollbarBg,
    ImGuiCol_ScrollbarGrab,
    ImGuiCol_ScrollbarGrabHovered,
    ImGuiCol_ScrollbarGrabActive,
    ImGuiCol_CheckMark,
    ImGuiCol_SliderGrab,
    ImGuiCol_SliderGrabActive,
    ImGuiCol_Button,
    ImGuiCol_ButtonHovered,
    ImGuiCol_ButtonActive,
    ImGuiCol_Header,
    ImGuiCol_HeaderHovered,
    ImGuiCol_HeaderActive,
    ImGuiCol_Separator,
    ImGuiCol_SeparatorHovered,
    ImGuiCol_SeparatorActive,
    ImGuiCol_ResizeGrip,
    ImGuiCol_ResizeGripHovered,
    ImGuiCol_ResizeGripActive,
    ImGuiCol_Tab,
    ImGuiCol_TabHovered,
    ImGuiCol_TabActive,
    ImGuiCol_TabUnfocused,
    ImGuiCol_TabUnfocusedActive,
    ImGuiCol_PlotLines,
    ImGuiCol_PlotLinesHovered,
    ImGuiCol_PlotHistogram,
    ImGuiCol_PlotHistogramHovered,
    ImGuiCol_TextSelectedBg,
    ImGuiCol_DragDropTarget,
    ImGuiCol_NavHighlight,          // Gamepad/keyboard: current highlighted item
    ImGuiCol_NavWindowingHighlight, // Highlight window when using CTRL+TAB
    ImGuiCol_NavWindowingDimBg,     // Darken/colorize entire screen behind the CTRL+TAB window list, when active
    ImGuiCol_ModalWindowDimBg,      // Darken/colorize entire screen behind a modal window, when one is active
    ImGuiCol_COUNT
}

// Enumeration for PushStyleVar() / PopStyleVar() to temporarily modify the ImGuiStyle structure.
// NB: the enum only refers to fields of ImGuiStyle which makes sense to be pushed/popped inside UI code. During initialization, feel free to just poke into ImGuiStyle directly.
// NB: if changing this enum, you need to update the associated internal table GStyleVarInfo[] accordingly. This is where we link enum values to members offset/type.
enum
{
    // Enum name ......................// Member in ImGuiStyle structure (see ImGuiStyle for descriptions)
    ImGuiStyleVar_Alpha,               // float     Alpha
    ImGuiStyleVar_WindowPadding,       // ImVec2    WindowPadding
    ImGuiStyleVar_WindowRounding,      // float     WindowRounding
    ImGuiStyleVar_WindowBorderSize,    // float     WindowBorderSize
    ImGuiStyleVar_WindowMinSize,       // ImVec2    WindowMinSize
    ImGuiStyleVar_WindowTitleAlign,    // ImVec2    WindowTitleAlign
    ImGuiStyleVar_ChildRounding,       // float     ChildRounding
    ImGuiStyleVar_ChildBorderSize,     // float     ChildBorderSize
    ImGuiStyleVar_PopupRounding,       // float     PopupRounding
    ImGuiStyleVar_PopupBorderSize,     // float     PopupBorderSize
    ImGuiStyleVar_FramePadding,        // ImVec2    FramePadding
    ImGuiStyleVar_FrameRounding,       // float     FrameRounding
    ImGuiStyleVar_FrameBorderSize,     // float     FrameBorderSize
    ImGuiStyleVar_ItemSpacing,         // ImVec2    ItemSpacing
    ImGuiStyleVar_ItemInnerSpacing,    // ImVec2    ItemInnerSpacing
    ImGuiStyleVar_IndentSpacing,       // float     IndentSpacing
    ImGuiStyleVar_ScrollbarSize,       // float     ScrollbarSize
    ImGuiStyleVar_ScrollbarRounding,   // float     ScrollbarRounding
    ImGuiStyleVar_GrabMinSize,         // float     GrabMinSize
    ImGuiStyleVar_GrabRounding,        // float     GrabRounding
    ImGuiStyleVar_TabRounding,         // float     TabRounding
    ImGuiStyleVar_ButtonTextAlign,     // ImVec2    ButtonTextAlign
    ImGuiStyleVar_COUNT
};

// Enumeration for ColorEdit3() / ColorEdit4() / ColorPicker3() / ColorPicker4() / ColorButton()
enum
{
    ImGuiColorEditFlags_None            = 0,
    ImGuiColorEditFlags_NoAlpha         = 1 << 1,   //              // ColorEdit, ColorPicker, ColorButton: ignore Alpha component (read 3 components from the input pointer).
    ImGuiColorEditFlags_NoPicker        = 1 << 2,   //              // ColorEdit: disable picker when clicking on colored square.
    ImGuiColorEditFlags_NoOptions       = 1 << 3,   //              // ColorEdit: disable toggling options menu when right-clicking on inputs/small preview.
    ImGuiColorEditFlags_NoSmallPreview  = 1 << 4,   //              // ColorEdit, ColorPicker: disable colored square preview next to the inputs. (e.g. to show only the inputs)
    ImGuiColorEditFlags_NoInputs        = 1 << 5,   //              // ColorEdit, ColorPicker: disable inputs sliders/text widgets (e.g. to show only the small preview colored square).
    ImGuiColorEditFlags_NoTooltip       = 1 << 6,   //              // ColorEdit, ColorPicker, ColorButton: disable tooltip when hovering the preview.
    ImGuiColorEditFlags_NoLabel         = 1 << 7,   //              // ColorEdit, ColorPicker: disable display of inline text label (the label is still forwarded to the tooltip and picker).
    ImGuiColorEditFlags_NoSidePreview   = 1 << 8,   //              // ColorPicker: disable bigger color preview on right side of the picker, use small colored square preview instead.
    ImGuiColorEditFlags_NoDragDrop      = 1 << 9,   //              // ColorEdit: disable drag and drop target. ColorButton: disable drag and drop source.

    // User Options (right-click on widget to change some of them). You can set application defaults using SetColorEditOptions(). The idea is that you probably don't want to override them in most of your calls, let the user choose and/or call SetColorEditOptions() during startup.
    ImGuiColorEditFlags_AlphaBar        = 1 << 16,  //              // ColorEdit, ColorPicker: show vertical alpha bar/gradient in picker.
    ImGuiColorEditFlags_AlphaPreview    = 1 << 17,  //              // ColorEdit, ColorPicker, ColorButton: display preview as a transparent color over a checkerboard, instead of opaque.
    ImGuiColorEditFlags_AlphaPreviewHalf= 1 << 18,  //              // ColorEdit, ColorPicker, ColorButton: display half opaque / half checkerboard, instead of opaque.
    ImGuiColorEditFlags_HDR             = 1 << 19,  //              // (WIP) ColorEdit: Currently only disable 0.0f..1.0f limits in RGBA edition (note: you probably want to use ImGuiColorEditFlags_Float flag as well).
    ImGuiColorEditFlags_RGB             = 1 << 20,  // [Inputs]     // ColorEdit: choose one among RGB/HSV/HEX. ColorPicker: choose any combination using RGB/HSV/HEX.
    ImGuiColorEditFlags_HSV             = 1 << 21,  // [Inputs]     // "
    ImGuiColorEditFlags_HEX             = 1 << 22,  // [Inputs]     // "
    ImGuiColorEditFlags_Uint8           = 1 << 23,  // [DataType]   // ColorEdit, ColorPicker, ColorButton: _display_ values formatted as 0..255.
    ImGuiColorEditFlags_Float           = 1 << 24,  // [DataType]   // ColorEdit, ColorPicker, ColorButton: _display_ values formatted as 0.0f..1.0f floats instead of 0..255 integers. No round-trip of value via integers.
    ImGuiColorEditFlags_PickerHueBar    = 1 << 25,  // [PickerMode] // ColorPicker: bar for Hue, rectangle for Sat/Value.
    ImGuiColorEditFlags_PickerHueWheel  = 1 << 26,  // [PickerMode] // ColorPicker: wheel for Hue, triangle for Sat/Value.

    // [Internal] Masks
    ImGuiColorEditFlags__InputsMask     = ImGuiColorEditFlags_RGB|ImGuiColorEditFlags_HSV|ImGuiColorEditFlags_HEX,
    ImGuiColorEditFlags__DataTypeMask   = ImGuiColorEditFlags_Uint8|ImGuiColorEditFlags_Float,
    ImGuiColorEditFlags__PickerMask     = ImGuiColorEditFlags_PickerHueWheel|ImGuiColorEditFlags_PickerHueBar,
    ImGuiColorEditFlags__OptionsDefault = ImGuiColorEditFlags_Uint8|ImGuiColorEditFlags_RGB|ImGuiColorEditFlags_PickerHueBar    // Change application default using SetColorEditOptions()
}

// Enumeration for GetMouseCursor()
// User code may request binding to display given cursor by calling SetMouseCursor(), which is why we have some cursors that are marked unused here
enum
{
    ImGuiMouseCursor_None = -1,
    ImGuiMouseCursor_Arrow = 0,
    ImGuiMouseCursor_TextInput,         // When hovering over InputText, etc.
    ImGuiMouseCursor_ResizeAll,         // (Unused by imgui functions)
    ImGuiMouseCursor_ResizeNS,          // When hovering over an horizontal border
    ImGuiMouseCursor_ResizeEW,          // When hovering over a vertical border or a column
    ImGuiMouseCursor_ResizeNESW,        // When hovering over the bottom-left corner of a window
    ImGuiMouseCursor_ResizeNWSE,        // When hovering over the bottom-right corner of a window
    ImGuiMouseCursor_Hand,              // (Unused by imgui functions. Use for e.g. hyperlinks)
    ImGuiMouseCursor_COUNT
}

// Condition for ImGui::SetWindow***(), SetNextWindow***(), SetNextTreeNode***() functions
// Important: Treat as a regular enum! Do NOT combine multiple values using binary operators! All the functions above treat 0 as a shortcut to ImGuiCond_Always.
enum
{
    ImGuiCond_Always        = 1 << 0,   // Set the variable
    ImGuiCond_Once          = 1 << 1,   // Set the variable once per runtime session (only the first call with succeed)
    ImGuiCond_FirstUseEver  = 1 << 2,   // Set the variable if the object/window has no persistently saved data (no entry in .ini file)
    ImGuiCond_Appearing     = 1 << 3    // Set the variable if the object/window is appearing after being hidden/inactive (or the first time)
}

// You may modify the ImGui::GetStyle() main instance during initialization and before NewFrame().
// During the frame, use ImGui::PushStyleVar(ImGuiStyleVar_XXXX)/PopStyleVar() to alter the main style values, and ImGui::PushStyleColor(ImGuiCol_XXX)/PopStyleColor() for colors.
extern(C++) struct ImGuiStyle
{
    float       Alpha;                      // Global alpha applies to everything in ImGui.
    ImVec2      WindowPadding;              // Padding within a window.
    float       WindowRounding;             // Radius of window corners rounding. Set to 0.0f to have rectangular windows.
    float       WindowBorderSize;           // Thickness of border around windows. Generally set to 0.0f or 1.0f. (Other values are not well tested and more CPU/GPU costly).
    ImVec2      WindowMinSize;              // Minimum window size. This is a global setting. If you want to constraint individual windows, use SetNextWindowSizeConstraints().
    ImVec2      WindowTitleAlign;           // Alignment for title bar text. Defaults to (0.0f,0.5f) for left-aligned,vertically centered.
    float       ChildRounding;              // Radius of child window corners rounding. Set to 0.0f to have rectangular windows.
    float       ChildBorderSize;            // Thickness of border around child windows. Generally set to 0.0f or 1.0f. (Other values are not well tested and more CPU/GPU costly).
    float       PopupRounding;              // Radius of popup window corners rounding. (Note that tooltip windows use WindowRounding)
    float       PopupBorderSize;            // Thickness of border around popup/tooltip windows. Generally set to 0.0f or 1.0f. (Other values are not well tested and more CPU/GPU costly).
    ImVec2      FramePadding;               // Padding within a framed rectangle (used by most widgets).
    float       FrameRounding;              // Radius of frame corners rounding. Set to 0.0f to have rectangular frame (used by most widgets).
    float       FrameBorderSize;            // Thickness of border around frames. Generally set to 0.0f or 1.0f. (Other values are not well tested and more CPU/GPU costly).
    ImVec2      ItemSpacing;                // Horizontal and vertical spacing between widgets/lines.
    ImVec2      ItemInnerSpacing;           // Horizontal and vertical spacing between within elements of a composed widget (e.g. a slider and its label).
    ImVec2      TouchExtraPadding;          // Expand reactive bounding box for touch-based system where touch position is not accurate enough. Unfortunately we don't sort widgets so priority on overlap will always be given to the first widget. So don't grow this too much!
    float       IndentSpacing;              // Horizontal indentation when e.g. entering a tree node. Generally == (FontSize + FramePadding.x*2).
    float       ColumnsMinSpacing;          // Minimum horizontal spacing between two columns.
    float       ScrollbarSize;              // Width of the vertical scrollbar, Height of the horizontal scrollbar.
    float       ScrollbarRounding;          // Radius of grab corners for scrollbar.
    float       GrabMinSize;                // Minimum width/height of a grab box for slider/scrollbar.
    float       GrabRounding;               // Radius of grabs corners rounding. Set to 0.0f to have rectangular slider grabs.
    float       TabRounding;                // Radius of upper corners of a tab. Set to 0.0f to have rectangular tabs.
    float       TabBorderSize;              // Thickness of border around tabs.
    ImVec2      ButtonTextAlign;            // Alignment of button text when button is larger than text. Defaults to (0.5f,0.5f) for horizontally+vertically centered.
    ImVec2      DisplayWindowPadding;       // Window position are clamped to be visible within the display area by at least this amount. Only applies to regular windows.
    ImVec2      DisplaySafeAreaPadding;     // If you cannot see the edges of your screen (e.g. on a TV) increase the safe area padding. Apply to popups/tooltips as well regular windows. NB: Prefer configuring your TV sets correctly!
    float       MouseCursorScale;           // Scale software rendered mouse cursor (when io.MouseDrawCursor is enabled). May be removed later.
    bool        AntiAliasedLines;           // Enable anti-aliasing on lines/borders. Disable if you are really tight on CPU/GPU.
    bool        AntiAliasedFill;            // Enable anti-aliasing on filled shapes (rounded rectangles, circles, etc.)
    float       CurveTessellationTol;       // Tessellation tolerance when using PathBezierCurveTo() without a specific number of segments. Decrease for highly tessellated curves (higher quality, more polygons), increase to reduce quality.
    ImVec4[ImGuiCol_COUNT]      Colors;

    void ScaleAllSizes(float scale_factor);
}

// This is where your app communicate with ImGui. Access via ImGui::GetIO().
// Read 'Programmer guide' section in .cpp file for general usage.
extern(C++) struct ImGuiIO
{
    //------------------------------------------------------------------
    // Configuration (fill once)                // Default value
    //------------------------------------------------------------------

    ImGuiConfigFlags   ConfigFlags;             // = 0              // See ImGuiConfigFlags_ enum. Set by user/application. Gamepad/keyboard navigation options, etc.
    ImGuiBackendFlags  BackendFlags;            // = 0              // See ImGuiBackendFlags_ enum. Set by back-end (imgui_impl_xxx files or custom back-end) to communicate features supported by the back-end.
    ImVec2             DisplaySize;             // <unset>          // Main display size, in pixels. For clamping windows positions.
    float              DeltaTime;               // = 1.0f/60.0f     // Time elapsed since last frame, in seconds.
    float              IniSavingRate;           // = 5.0f           // Minimum time between saving positions/sizes to .ini file, in seconds.
    const(char)*       IniFilename;             // = "imgui.ini"    // Path to .ini file. Set NULL to disable automatic .ini loading/saving, if e.g. you want to manually load/save from memory.
    const(char)*       LogFilename;             // = "imgui_log.txt"// Path to .log file (default parameter to ImGui::LogToFile when no file is specified).
    float              MouseDoubleClickTime;    // = 0.30f          // Time for a double-click, in seconds.
    float              MouseDoubleClickMaxDist; // = 6.0f           // Distance threshold to stay in to validate a double-click, in pixels.
    float              MouseDragThreshold;      // = 6.0f           // Distance threshold before considering we are dragging.
    int[ImGuiKey_COUNT] KeyMap;                 // <unset>          // Map of indices into the KeysDown[512] entries array which represent your "native" keyboard state.
    float              KeyRepeatDelay;          // = 0.250f         // When holding a key/button, time before it starts repeating, in seconds (for buttons in Repeat mode, etc.).
    float              KeyRepeatRate;           // = 0.050f         // When holding a key/button, rate at which it repeats, in seconds.
    void*              UserData;                // = NULL           // Store your own data for retrieval by callbacks.

    ImFontAtlas*Fonts;                          // <auto>           // Load, rasterize and pack one or more fonts into a single texture.
    float       FontGlobalScale;                // = 1.0f           // Global scale all fonts
    bool        FontAllowUserScaling;           // = false          // Allow user scaling text of individual window with CTRL+Wheel.
    ImFont*     FontDefault;                    // = NULL           // Font to use on NewFrame(). Use NULL to uses Fonts->Fonts[0].
    ImVec2      DisplayFramebufferScale;        // = (1.0f,1.0f)    // For retina display or other situations where window coordinates are different from framebuffer coordinates. User storage only, presently not used by ImGui.
    ImVec2      DisplayVisibleMin;              // <unset>          // [OBSOLETE] If you use DisplaySize as a virtual space larger than your screen, set DisplayVisibleMin/Max to the visible area.
    ImVec2      DisplayVisibleMax;              // <unset>          // [OBSOLETE] Just use io.DisplaySize! If the values are the same, we defaults to Min=(0.0f) and Max=DisplaySize

    // Miscellaneous configuration options
    bool        MouseDrawCursor;                // = false          // Request ImGui to draw a mouse cursor for you (if you are on a platform without a mouse cursor). Cannot be easily renamed to 'io.ConfigXXX' because this is frequently used by back-end implementations.
    bool        ConfigMacOSXBehaviors;          // = defined(__APPLE__) // OS X style: Text editing cursor movement using Alt instead of Ctrl, Shortcuts using Cmd/Super instead of Ctrl, Line/Text Start and End using Cmd+Arrows instead of Home/End, Double click selects by word instead of selecting whole text, Multi-selection in lists uses Cmd/Super instead of Ctrl (was called io.OptMacOSXBehaviors prior to 1.63)
    bool        ConfigInputTextCursorBlink;     // = true           // Set to false to disable blinking cursor, for users who consider it distracting. (was called: io.OptCursorBlink prior to 1.63)
    bool        ConfigWindowsResizeFromEdges;   // = true           // Enable resizing of windows from their edges and from the lower-left corner. This requires (io.BackendFlags & ImGuiBackendFlags_HasMouseCursors) because it needs mouse cursor feedback. (This used to be the a per-window ImGuiWindowFlags_ResizeFromAnySide flag)
    bool        ConfigWindowsMoveFromTitleBarOnly;// = false        // [BETA] Set to true to only allow moving windows when clicked+dragged from the title bar. Windows without a title bar are not affected.

    //------------------------------------------------------------------
    // Platform Functions
    // (the imgui_impl_xxxx back-end files are setting those up for you)
    //------------------------------------------------------------------

    // Optional: Platform/Renderer back-end name (informational only! will be displayed in About Window) + User data for back-end/wrappers to store their own stuff.
    const char* BackendPlatformName;            // = NULL
    const char* BackendRendererName;            // = NULL
    void*       BackendPlatformUserData;        // = NULL
    void*       BackendRendererUserData;        // = NULL
    void*       BackendLanguageUserData;        // = NULL
    //------------------------------------------------------------------
    // Settings (User Functions)
    //------------------------------------------------------------------

    // Optional: access OS clipboard
    // (default to use native Win32 clipboard on Windows, otherwise uses a private clipboard. Override to access OS clipboard on other architectures)
    const(char)* function(void* user_data) GetClipboardTextFn;
    void        function(void* user_data, const(char)* text) SetClipboardTextFn;
    void*       ClipboardUserData;

    // Optional: notify OS Input Method Editor of the screen position of your cursor for text input position (e.g. when using Japanese/Chinese IME in Windows)
    // (default to use native imm32 api on Windows)
    void function(int x, int y) ImeSetInputScreenPosFn;
    void*                       ImeWindowHandle;            // (Windows) Set this to your HWND to get automatic IME cursor positioning.

    // This is only here to keep ImGuiIO the same size, so that IMGUI_DISABLE_OBSOLETE_FUNCTIONS can exceptionally be used outside of imconfig.h.
    void*       RenderDrawListsFnDummy;

    //------------------------------------------------------------------
    // Input - Fill before calling NewFrame()
    //------------------------------------------------------------------

    ImVec2      MousePos;                    // Mouse position, in pixels. Set to ImVec2(-float.max,-float.max) if mouse is unavailable (on another screen, etc.)
    bool[5]     MouseDown;                   // Mouse buttons: left, right, middle + extras. ImGui itself mostly only uses left button (BeginPopupContext** are using right button). Others buttons allows us to track if the mouse is being used by your application + available to user as a convenience via IsMouse** API.
    float       MouseWheel;                  // Mouse wheel Vertical: 1 unit scrolls about 5 lines text.
    float       MouseWheelH;                 // Mouse wheel Horizontal. Most users don't have a mouse with an horizontal wheel, may not be filled by all back-ends.
    bool        KeyCtrl;                     // Keyboard modifier pressed: Control
    bool        KeyShift;                    // Keyboard modifier pressed: Shift
    bool        KeyAlt;                      // Keyboard modifier pressed: Alt
    bool        KeySuper;                    // Keyboard modifier pressed: Cmd/Super/Windows
    bool[512]   KeysDown;                    // Keyboard keys that are pressed (ideally left in the "native" order your engine has access to keyboard keys, so you can use your own defines/enums for keys).
    float[ImGuiNavInput_COUNT] NavInputs;    // Gamepad inputs (keyboard keys will be auto-mapped and be written here by ImGui::NewFrame, all values will be cleared back to zero in ImGui::EndFrame)

    // Functions
    void AddInputCharacter(ImWchar c);                        // Add new character into InputCharacters[]
    void AddInputCharactersUTF8(const(char)* utf8_chars);     // Add new characters into InputCharacters[] from an UTF-8 string
    void ClearInputCharacters();                              // Clear the text input buffer manually

    //------------------------------------------------------------------
    // Output - Retrieve after calling NewFrame()
    //------------------------------------------------------------------

    bool        WantCaptureMouse;               // When io.WantCaptureMouse is true, imgui will use the mouse inputs, do not dispatch them to your main game/application (in both cases, always pass on mouse inputs to imgui). (e.g. unclicked mouse is hovering over an imgui window, widget is active, mouse was clicked over an imgui window, etc.).
    bool        WantCaptureKeyboard;            // When io.WantCaptureKeyboard is true, imgui will use the keyboard inputs, do not dispatch them to your main game/application (in both cases, always pass keyboard inputs to imgui). (e.g. InputText active, or an imgui window is focused and navigation is enabled, etc.).
    bool        WantTextInput;                  // Mobile/console: when io.WantTextInput is true, you may display an on-screen keyboard. This is set by ImGui when it wants textual keyboard input to happen (e.g. when a InputText widget is active).
    bool        WantSetMousePos;                // MousePos has been altered, back-end should reposition mouse on next frame. Set only when ImGuiConfigFlags_NavEnableSetMousePos flag is enabled.
    bool        WantSaveIniSettings;            // When manual .ini load/save is active (io.IniFilename == NULL), this will be set to notify your application that you can call SaveIniSettingsToMemory() and save yourself. IMPORTANT: You need to clear io.WantSaveIniSettings yourself.
    bool        NavActive;                      // Directional navigation is currently allowed (will handle ImGuiKey_NavXXX events) = a window is focused and it doesn't use the ImGuiWindowFlags_NoNavInputs flag.
    bool        NavVisible;                     // Directional navigation is visible and allowed (will handle ImGuiKey_NavXXX events).
    float       Framerate;                      // Application framerate estimation, in frame per second. Solely for convenience. Rolling average estimation based on IO.DeltaTime over 120 frames
    int         MetricsRenderVertices;          // Vertices output during last call to Render()
    int         MetricsRenderIndices;           // Indices output during last call to Render() = number of triangles * 3
    int         MetricsRenderWindows;           // Number of visible windows
    int         MetricsActiveWindows;           // Number of active windows
    int         MetricsActiveAllocations;       // Number of active allocations, updated by MemAlloc/MemFree based on current context. May be off if you have multiple imgui contexts.
    ImVec2      MouseDelta;                     // Mouse delta. Note that this is zero if either current or previous position are invalid (-FLT_MAX,-FLT_MAX), so a disappearing/reappearing mouse won't have a huge delta.

    //------------------------------------------------------------------
    // [Internal] ImGui will maintain those fields. Forward compatibility not guaranteed!
    //------------------------------------------------------------------

    ImVec2                     MousePosPrev;                // Previous mouse position (note that MouseDelta is not necessary == MousePos-MousePosPrev, in case either position is invalid)
    ImVec2[5]                  MouseClickedPos;             // Position at time of clicking
    double[5]                  MouseClickedTime;            // Time of last click (used to figure out double-click)
    bool[5]                    MouseClicked;                // Mouse button went from !Down to Down
    bool[5]                    MouseDoubleClicked;          // Has mouse button been double-clicked?
    bool[5]                    MouseReleased;               // Mouse button went from Down to !Down
    bool[5]                    MouseDownOwned;              // Track if button was clicked inside a window. We don't request mouse capture from the application if click started outside ImGui bounds.
    float[5]                   MouseDownDuration;           // Duration the mouse button has been down (0.0f == just clicked)
    float[5]                   MouseDownDurationPrev;       // Previous time the mouse button has been down
    ImVec2[5]                  MouseDragMaxDistanceAbs;     // Maximum distance, absolute, on each axis, of how much mouse has traveled from the clicking point
    float[5]                   MouseDragMaxDistanceSqr;     // Squared maximum distance of how much mouse has traveled from the clicking point
    float[512]                 KeysDownDuration;            // Duration the keyboard key has been down (0.0f == just pressed)
    float[512]                 KeysDownDurationPrev;        // Previous duration the key has been down
    float[ImGuiNavInput_COUNT] NavInputsDownDuration;
    float[ImGuiNavInput_COUNT] NavInputsDownDurationPrev;
    ImVector!ImWchar           InputQueueCharacters;     // Queue of _characters_ input (obtained by platform back-end). Fill using AddInputCharacter() helper.
}

//-----------------------------------------------------------------------------
// Helpers
//-----------------------------------------------------------------------------

// Helper: Lightweight std::vector<> like class to avoid dragging dependencies (also: Windows implementation of STL with debug enabled is absurdly slow, so let's bypass it so our code runs fast in debug).
// *Important* Our implementation does NOT call C++ constructors/destructors. This is intentional, we do not require it but you have to be mindful of that. Do not use this class as a straight std::vector replacement in your code!
struct ImVector(T)
{
    int                         Size;
    int                         Capacity;
    T*                          Data;

    ref inout(T) opIndex(size_t i) inout { return Data[i]; }
    int   opDollar() const  { return Size; }
    T[]   opSlice()         { return Data[0 .. Size]; }

    // typedef T                   value_type;
    // typedef value_type*         iterator;
    // typedef const value_type*   const_iterator;

    // inline ImVector()           { Size = Capacity = 0; Data = null; }
    // inline ~ImVector()          { if (Data) ImGui::MemFree(Data); }
    // inline ImVector(const ImVector<T>& src)                     { Size = Capacity = 0; Data = null; operator=(src); }
    // inline ImVector& operator=(const ImVector<T>& src)          { clear(); resize(src.Size); memcpy(Data, src.Data, (size_t)Size * sizeof(value_type)); return *this; }

    // inline bool                 empty() const                   { return Size == 0; }
    // inline int                  size() const                    { return Size; }
    // inline int                  capacity() const                { return Capacity; }
    // inline value_type&          operator[](int i)               { IM_ASSERT(i < Size); return Data[i]; }
    // inline const value_type&    operator[](int i) const         { IM_ASSERT(i < Size); return Data[i]; }

    // inline void                 clear()                         { if (Data) { Size = Capacity = 0; ImGui::MemFree(Data); Data = null; } }
    // inline iterator             begin()                         { return Data; }
    // inline const_iterator       begin() const                   { return Data; }
    // inline iterator             end()                           { return Data + Size; }
    // inline const_iterator       end() const                     { return Data + Size; }
    // inline value_type&          front()                         { IM_ASSERT(Size > 0); return Data[0]; }
    // inline const value_type&    front() const                   { IM_ASSERT(Size > 0); return Data[0]; }
    // inline value_type&          back()                          { IM_ASSERT(Size > 0); return Data[Size - 1]; }
    // inline const value_type&    back() const                    { IM_ASSERT(Size > 0); return Data[Size - 1]; }
    // inline void                 swap(ImVector<value_type>& rhs) { int rhs_size = rhs.Size; rhs.Size = Size; Size = rhs_size; int rhs_cap = rhs.Capacity; rhs.Capacity = Capacity; Capacity = rhs_cap; value_type* rhs_data = rhs.Data; rhs.Data = Data; Data = rhs_data; }

    // inline int          _grow_capacity(int sz) const            { int new_capacity = Capacity ? (Capacity + Capacity/2) : 8; return new_capacity > sz ? new_capacity : sz; }
    // inline void         resize(int new_size)                    { if (new_size > Capacity) reserve(_grow_capacity(new_size)); Size = new_size; }
    // inline void         resize(int new_size,const value_type& v){ if (new_size > Capacity) reserve(_grow_capacity(new_size)); if (new_size > Size) for (int n = Size; n < new_size; n++) memcpy(&Data[n], &v, sizeof(v)); Size = new_size; }
    // inline void         reserve(int new_capacity)
    // {
    //     if (new_capacity <= Capacity)
    //         return;
    //     value_type* new_data = (value_type*)ImGui::MemAlloc((size_t)new_capacity * sizeof(value_type));
    //     if (Data)
    //         memcpy(new_data, Data, (size_t)Size * sizeof(value_type));
    //     ImGui::MemFree(Data);
    //     Data = new_data;
    //     Capacity = new_capacity;
    // }

    // // NB: &v cannot be pointing inside the ImVector Data itself! e.g. v.push_back(v[10]) is forbidden.
    // inline void         push_back(const value_type& v)                  { if (Size == Capacity) reserve(_grow_capacity(Size + 1)); memcpy(&Data[Size], &v, sizeof(v)); Size++; }
    // inline void         pop_back()                                      { IM_ASSERT(Size > 0); Size--; }
    // inline void         push_front(const value_type& v)                 { if (Size == 0) push_back(v); else insert(Data, v); }
    // inline iterator     erase(const_iterator it)                        { IM_ASSERT(it >= Data && it < Data+Size); const ptrdiff_t off = it - Data; memmove(Data + off, Data + off + 1, ((size_t)Size - (size_t)off - 1) * sizeof(value_type)); Size--; return Data + off; }
    // inline iterator     insert(const_iterator it, const value_type& v)  { IM_ASSERT(it >= Data && it <= Data+Size); const ptrdiff_t off = it - Data; if (Size == Capacity) reserve(_grow_capacity(Size + 1)); if (off < (int)Size) memmove(Data + off + 1, Data + off, ((size_t)Size - (size_t)off) * sizeof(value_type)); memcpy(&Data[off], &v, sizeof(v)); Size++; return Data + off; }
    // inline bool         contains(const value_type& v) const             { const T* data = Data;  const T* data_end = Data + Size; while (data < data_end) if (*data++ == v) return true; return false; }
}

// Helper: IM_NEW(), IM_PLACEMENT_NEW(), IM_DELETE() macros to call MemAlloc + Placement New, Placement Delete + MemFree
// We call C++ constructor on own allocated memory via the placement "new(ptr) Type()" syntax.
// Defining a custom placement new() with a dummy parameter allows us to bypass including <new> which on some platforms complains when user has disabled exceptions.
// struct ImNewDummy {}
// inline void* operator new(size_t, ImNewDummy, void* ptr) { return ptr; }
// inline void  operator delete(void*, ImNewDummy, void*)   {} // This is only required so we can use the symetrical new()
// #define IM_PLACEMENT_NEW(_PTR)              new(ImNewDummy(), _PTR)
// #define IM_NEW(_TYPE)                       new(ImNewDummy(), ImGui::MemAlloc(sizeof(_TYPE))) _TYPE
// template<typename T> void IM_DELETE(T* p)   { if (p) { p->~T(); ImGui::MemFree(p); } }

// Helper: Parse and apply text filters. In format "aaaaa[,bbbb][,ccccc]"
extern(C++) struct ImGuiTextFilter
{
    extern(C++) struct TextRange
    {
        const(char)* b;
        const(char)* e;

        // TextRange() { b = e = null; }
        // TextRange(const(char)* _b, const(char)* _e) { b = _b; e = _e; }
        // const(char)* begin() const { return b; }
        // const(char)* end() const { return e; }
        // bool empty() const { return b == e; }
        // char front() const { return *b; }
        // static bool is_blank(char c) { return c == ' ' || c == '\t'; }
        // void trim_blanks() { while (b < e && is_blank(*b)) b++; while (e > b && is_blank(*(e-1))) e--; }
        // void split(char separator, ImVector<TextRange>& out);
    }

    char[256]           InputBuf;
    ImVector!TextRange Filters;
    int                 CountGrep;

    //           ImGuiTextFilter(const(char)* default_filter = "");
    // bool      Draw(const(char)* label = "Filter (inc,-exc)", float width = 0.0f);    // Helper calling InputText+Build
    // bool      PassFilter(const(char)* text, const(char)* text_end = null) const;
    // void      Build();
    // void                Clear() { InputBuf[0] = 0; Build(); }
    // bool                IsActive() const { return !Filters.empty(); }
}

// Helper: Text buffer for logging/accumulating text
extern(C++) struct ImGuiTextBuffer
{
    ImVector!char      Buf;

    // ImGuiTextBuffer()   { Buf.push_back(0); }
    // inline char         operator[](int i) { return Buf.Data[i]; }
    // const(char)*         begin() const { return &Buf.front(); }
    // const(char)*         end() const { return &Buf.back(); }      // Buf is zero-terminated, so end() will point on the zero-terminator
    // int                 size() const { return Buf.Size - 1; }
    // bool                empty() { return Buf.Size <= 1; }
    // void                clear() { Buf.clear(); Buf.push_back(0); }
    // void                reserve(int capacity) { Buf.reserve(capacity); }
    // const(char)*         c_str() const { return Buf.Data; }
    // void      appendf(const(char)* fmt, ...) IM_FMTARGS(2);
    // void      appendfv(const(char)* fmt, va_list args) IM_FMTLIST(2);
}

// Helper: Simple Key->value storage
// Typically you don't have to worry about this since a storage is held within each Window.
// We use it to e.g. store collapse state for a tree (Int 0/1)
// This is optimized for efficient lookup (dichotomy into a contiguous buffer) and rare insertion (typically tied to user interactions aka max once a frame)
// You can use it as custom user storage for temporary values. Declare your own storage if, for example:
// - You want to manipulate the open/close state of a particular sub-tree in your interface (tree node uses Int 0/1 to store their state).
// - You want to store custom debug data easily without adding or editing structures in your code (probably not efficient, but convenient)
// Types are NOT stored, so it is up to you to make sure your Key don't collide with different types.
extern(C++) struct ImGuiStorage
{
    struct Pair
    {
        ImGuiID key;
        // union { int val_i; float val_f; void* val_p; }
        // Pair(ImGuiID _key, int _val_i)   { key = _key; val_i = _val_i; }
        // Pair(ImGuiID _key, float _val_f) { key = _key; val_f = _val_f; }
        // Pair(ImGuiID _key, void* _val_p) { key = _key; val_p = _val_p; }
    }
    ImVector!Pair      Data;

    // - Get***() functions find pair, never add/allocate. Pairs are sorted so a query is O(log N)
    // - Set***() functions find pair, insertion on demand if missing.
    // - Sorted insertion is costly, paid once. A typical frame shouldn't need to insert any new pair.
    // void                Clear() { Data.clear(); }
    int       GetInt(ImGuiID key, int default_val = 0) const;
    void      SetInt(ImGuiID key, int val);
    bool      GetBool(ImGuiID key, bool default_val = false) const;
    void      SetBool(ImGuiID key, bool val);
    float     GetFloat(ImGuiID key, float default_val = 0.0f) const;
    void      SetFloat(ImGuiID key, float val);
    void*     GetVoidPtr(ImGuiID key) const; // default_val is null
    void      SetVoidPtr(ImGuiID key, void* val);

    // - Get***Ref() functions finds pair, insert on demand if missing, return pointer. Useful if you intend to do Get+Set.
    // - References are only valid until a new value is added to the storage. Calling a Set***() function or a Get***Ref() function invalidates the pointer.
    // - A typical use case where this is convenient for quick hacking (e.g. add storage during a live Edit&Continue session if you can't modify existing struct)
    //      float* pvar = ImGui::GetFloatRef(key); ImGui::SliderFloat("var", pvar, 0, 100.0f); some_var += *pvar;
    int*      GetIntRef(ImGuiID key, int default_val = 0);
    bool*     GetBoolRef(ImGuiID key, bool default_val = false);
    float*    GetFloatRef(ImGuiID key, float default_val = 0.0f);
    void**    GetVoidPtrRef(ImGuiID key, void* default_val = null);

    // Use on your own storage if you know only integer are being stored (open/close all tree nodes)
    void      SetAllInt(int val);

    // For quicker full rebuild of a storage (instead of an incremental one), you may add all your contents and then sort once.
    void      BuildSortByKey();
}

//-----------------------------------------------------------------------------
// Misc data structures
//-----------------------------------------------------------------------------

// Shared state of InputText(), passed as an argument to your callback when a ImGuiInputTextFlags_Callback* flag is used.
// The callback function should return 0 by default.
// Callbacks (follow a flag name and see comments in ImGuiInputTextFlags_ declarations for more details)
// - ImGuiInputTextFlags_CallbackCompletion:  Callback on pressing TAB
// - ImGuiInputTextFlags_CallbackHistory:     Callback on pressing Up/Down arrows
// - ImGuiInputTextFlags_CallbackAlways:      Callback on each iteration
// - ImGuiInputTextFlags_CallbackCharFilter:  Callback on character inputs to replace or discard them. Modify 'EventChar' to replace or discard, or return 1 in callback to discard.
// - ImGuiInputTextFlags_CallbackResize:      Callback on buffer capacity changes request (beyond 'buf_size' parameter value), allowing the string to grow.
extern(C++) struct ImGuiInputTextCallbackData
{
    ImGuiInputTextFlags EventFlag;      // One ImGuiInputTextFlags_Callback*    // Read-only
    ImGuiInputTextFlags Flags;          // What user passed to InputText()      // Read-only
    void*               UserData;       // What user passed to InputText()      // Read-only

    // Arguments for the different callback events
    // - To modify the text buffer in a callback, prefer using the InsertChars() / DeleteChars() function. InsertChars() will take care of calling the resize callback if necessary.
    // - If you know your edits are not going to resize the underlying buffer allocation, you may modify the contents of 'Buf[]' directly. You need to update 'BufTextLen' accordingly (0 <= BufTextLen < BufSize) and set 'BufDirty'' to true so InputText can update its internal state.
    ImWchar             EventChar;      // Character input                      // Read-write   // [CharFilter] Replace character with another one, or set to zero to drop. return 1 is equivalent to setting EventChar=0;
    ImGuiKey            EventKey;       // Key pressed (Up/Down/TAB)            // Read-only    // [Completion,History]
    char*               Buf;            // Text buffer                          // Read-write   // [Resize] Can replace pointer / [Completion,History,Always] Only write to pointed data, don't replace the actual pointer!
    int                 BufTextLen;     // Text length (in bytes)               // Read-write   // [Resize,Completion,History,Always] Exclude zero-terminator storage. In C land: == strlen(some_text), in C++ land: string.length()
    int                 BufSize;        // Buffer size (in bytes) = capacity+1  // Read-only    // [Resize,Completion,History,Always] Include zero-terminator storage. In C land == ARRAYSIZE(my_char_array), in C++ land: string.capacity()+1
    bool                BufDirty;       // Set if you modify Buf/BufTextLen!    // Write        // [Completion,History,Always]
    int                 CursorPos;      //                                      // Read-write   // [Completion,History,Always]
    int                 SelectionStart; //                                      // Read-write   // [Completion,History,Always] == to SelectionEnd when no selection)
    int                 SelectionEnd;   //                                      // Read-write   // [Completion,History,Always]

    // Helper functions for text manipulation.
    // Use those function to benefit from the CallbackResize behaviors. Calling those function reset the selection.
    // ImGuiInputTextCallbackData();
    void      DeleteChars(int pos, int bytes_count);
    void      InsertChars(int pos, const(char)* text, const(char)* text_end = null);
    bool      HasSelection() const { return SelectionStart != SelectionEnd; }
}

// Resizing callback data to apply custom constraint. As enabled by SetNextWindowSizeConstraints(). Callback is called during the next Begin().
// NB: For basic min/max size constraint on each axis you don't need to use the callback! The SetNextWindowSizeConstraints() parameters are enough.
extern(C++) struct ImGuiSizeCallbackData
{
    void*   UserData;       // Read-only.   What user passed to SetNextWindowSizeConstraints()
    ImVec2  Pos;            // Read-only.   Window position, for reference.
    ImVec2  CurrentSize;    // Read-only.   Current window size.
    ImVec2  DesiredSize;    // Read-write.  Desired size, based on user's mouse position. Write to this field to restrain resizing.
}

// Data payload for Drag and Drop operations
extern(C++) struct ImGuiPayload
{
    // Members
    void*           Data;               // Data (copied and owned by dear imgui)
    int             DataSize;           // Data size

    // [Internal]
    ImGuiID         SourceId;           // Source item id
    ImGuiID         SourceParentId;     // Source parent id (if available)
    int             DataFrameCount;     // Data timestamp
    char[32+1]      DataType;     // Data type tag (short user-supplied string, 32 characters max)
    bool            Preview;            // Set when AcceptDragDropPayload() was called and mouse has been hovering the target item (nb: handle overlapping drag targets)
    bool            Delivery;           // Set when AcceptDragDropPayload() was called and mouse button is released over the target item.

    // void Clear()    { SourceId = SourceParentId = 0; Data = null; DataSize = 0; memset(DataType, 0, sizeof(DataType)); DataFrameCount = -1; Preview = Delivery = false; }
    // bool IsDataType(const(char)* type) const { return DataFrameCount != -1 && strcmp(type, DataType) == 0; }
    bool IsPreview() const                  { return Preview; }
    bool IsDelivery() const                 { return Delivery; }
}

// Helper: ImColor() implicity converts colors to either ImU32 (packed 4x1 byte) or ImVec4 (4x1 float)
// Prefer using IM_COL32() macros if you want a guaranteed compile-time ImU32 for usage with ImDrawList API.
// **Avoid storing ImColor! Store either u32 of ImVec4. This is not a full-featured color class. MAY OBSOLETE.
// **None of the ImGui API are using ImColor directly but you can use it as a convenience to pass colors in either ImU32 or ImVec4 formats. Explicitly cast to ImU32 or ImVec4 if needed.
struct ImColor
{
    ImVec4              Value;

    // ImColor()                                                       { Value.x = Value.y = Value.z = Value.w = 0.0f; }
    // ImColor(int r, int g, int b, int a = 255)                       { float sc = 1.0f/255.0f; Value.x = (float)r * sc; Value.y = (float)g * sc; Value.z = (float)b * sc; Value.w = (float)a * sc; }
    // ImColor(ImU32 rgba)                                             { float sc = 1.0f/255.0f; Value.x = (float)((rgba>>IM_COL32_R_SHIFT)&0xFF) * sc; Value.y = (float)((rgba>>IM_COL32_G_SHIFT)&0xFF) * sc; Value.z = (float)((rgba>>IM_COL32_B_SHIFT)&0xFF) * sc; Value.w = (float)((rgba>>IM_COL32_A_SHIFT)&0xFF) * sc; }
    // ImColor(float r, float g, float b, float a = 1.0f)              { Value.x = r; Value.y = g; Value.z = b; Value.w = a; }
    // ImColor(ref const ImVec4 col)                                      { Value = col; }
    // inline operator ImU32() const                                   { return ImGui::ColorConvertFloat4ToU32(Value); }
    // inline operator ImVec4() const                                  { return Value; }

    // // FIXME-OBSOLETE: May need to obsolete/cleanup those helpers.
    // inline void    SetHSV(float h, float s, float v, float a = 1.0f){ ImGui::ColorConvertHSVtoRGB(h, s, v, Value.x, Value.y, Value.z); Value.w = a; }
    // static ImColor HSV(float h, float s, float v, float a = 1.0f)   { float r,g,b; ImGui::ColorConvertHSVtoRGB(h, s, v, r, g, b); return ImColor(r,g,b,a); }
}

// Helper: Manually clip large list of items.
// If you are submitting lots of evenly spaced items and you have a random access to the list, you can perform coarse clipping based on visibility to save yourself from processing those items at all.
// The clipper calculates the range of visible items and advance the cursor to compensate for the non-visible items we have skipped.
// ImGui already clip items based on their bounds but it needs to measure text size to do so. Coarse clipping before submission makes this cost and your own data fetching/submission cost null.
// Usage:
//     ImGuiListClipper clipper(1000);  // we have 1000 elements, evenly spaced.
//     while (clipper.Step())
//         for (int i = clipper.DisplayStart; i < clipper.DisplayEnd; i++)
//             ImGui::Text("line number %d", i);
// - Step 0: the clipper let you process the first element, regardless of it being visible or not, so we can measure the element height (step skipped if we passed a known height as second arg to constructor).
// - Step 1: the clipper infer height from first element, calculate the actual range of elements to display, and position the cursor before the first element.
// - (Step 2: dummy step only required if an explicit items_height was passed to constructor or Begin() and user call Step(). Does nothing and switch to Step 3.)
// - Step 3: the clipper validate that we have reached the expected Y position (corresponding to element DisplayEnd), advance the cursor to the end of the list and then returns 'false' to end the loop.
extern(C++) struct ImGuiListClipper
{
    float   StartPosY;
    float   ItemsHeight;
    int     ItemsCount, StepNo, DisplayStart, DisplayEnd;

    // items_count:  Use -1 to ignore (you can call Begin later). Use INT_MAX if you don't know how many items you have (in which case the cursor won't be advanced in the final step).
    // items_height: Use -1.0f to be calculated automatically on first step. Otherwise pass in the distance between your items, typically GetTextLineHeightWithSpacing() or GetFrameHeightWithSpacing().
    // If you don't specify an items_height, you NEED to call Step(). If you specify items_height you may call the old Begin()/End() api directly, but prefer calling Step().
    // ImGuiListClipper(int items_count = -1, float items_height = -1.0f)  { Begin(items_count, items_height); } // NB: Begin() initialize every fields (as we allow user to call Begin/End multiple times on a same instance if they want).
    // ~ImGuiListClipper()                                                 { IM_ASSERT(ItemsCount == -1); }      // Assert if user forgot to call End() or Step() until false.

    // bool Step();                                              // Call until it returns false. The DisplayStart/DisplayEnd fields will be set and you can process/draw those items.
    // void Begin(int items_count, float items_height = -1.0f);  // Automatically called by constructor if you passed 'items_count' or by Step() in Step 1.
    // void End();                                               // Automatically called on the last call of Step() that returns false.
}

//-----------------------------------------------------------------------------
// Draw List
// Hold a series of drawing commands. The user provides a renderer for ImDrawData which essentially contains an array of ImDrawList.
//-----------------------------------------------------------------------------

// Draw callbacks for advanced uses.
// NB- You most likely do NOT need to use draw callbacks just to create your own widget or customized UI rendering (you can poke into the draw list for that)
// Draw callback may be useful for example, A) Change your GPU render state, B) render a complex 3D scene inside a UI element (without an intermediate texture/render target), etc.
// The expected behavior from your rendering function is 'if (cmd.UserCallback != null) cmd.UserCallback(parent_list, cmd); else RenderTriangles()'
alias ImDrawCallback = void function(const ImDrawList* parent_list, const ImDrawCmd* cmd);

// Typically, 1 command = 1 GPU draw call (unless command is a callback)
struct ImDrawCmd
{
    uint    ElemCount;              // Number of indices (multiple of 3) to be rendered as triangles. Vertices are stored in the callee ImDrawList's vtx_buffer[] array, indices in idx_buffer[].
    ImVec4          ClipRect;               // Clipping rectangle (x1, y1, x2, y2)
    ImTextureID     TextureId;              // User-provided texture ID. Set by user in ImfontAtlas::SetTexID() for fonts or passed to Image*() functions. Ignore if never using images or multiple fonts atlas.
    ImDrawCallback  UserCallback;           // If != null, call the function instead of rendering the vertices. clip_rect and texture_id will be set normally.
    void*           UserCallbackData;       // The draw callback code can access this.

    // ImDrawCmd() { ElemCount = 0; ClipRect.x = ClipRect.y = ClipRect.z = ClipRect.w = 0.0f; TextureId = null; UserCallback = null; UserCallbackData = null; }
}

alias ImDrawIdx =  ushort;

struct ImDrawVert
{
    ImVec2  pos;
    ImVec2  uv;
    ImU32   col;
}

// Draw channels are used by the Columns API to "split" the render list into different channels while building, so items of each column can be batched together.
// You can also use them to simulate drawing layers and submit primitives in a different order than how they will be rendered.
struct ImDrawChannel
{
    ImVector!ImDrawCmd     CmdBuffer;
    ImVector!ImDrawIdx     IdxBuffer;
}

enum
{
    ImDrawCornerFlags_TopLeft   = 1 << 0, // 0x1
    ImDrawCornerFlags_TopRight  = 1 << 1, // 0x2
    ImDrawCornerFlags_BotLeft   = 1 << 2, // 0x4
    ImDrawCornerFlags_BotRight  = 1 << 3, // 0x8
    ImDrawCornerFlags_Top       = ImDrawCornerFlags_TopLeft | ImDrawCornerFlags_TopRight,   // 0x3
    ImDrawCornerFlags_Bot       = ImDrawCornerFlags_BotLeft | ImDrawCornerFlags_BotRight,   // 0xC
    ImDrawCornerFlags_Left      = ImDrawCornerFlags_TopLeft | ImDrawCornerFlags_BotLeft,    // 0x5
    ImDrawCornerFlags_Right     = ImDrawCornerFlags_TopRight | ImDrawCornerFlags_BotRight,  // 0xA
    ImDrawCornerFlags_All       = 0xF     // In your function calls you may use ~0 (= all bits sets) instead of ImDrawCornerFlags_All, as a convenience
}

enum
{
    ImDrawListFlags_None             = 0,
    ImDrawListFlags_AntiAliasedLines = 1 << 0,  // Lines are anti-aliased (*2 the number of triangles for 1.0f wide line, otherwise *3 the number of triangles)
    ImDrawListFlags_AntiAliasedFill  = 1 << 1   // Filled shapes have anti-aliased edges (*2 the number of vertices)
}

// Draw command list
// This is the low-level list of polygons that ImGui functions are filling. At the end of the frame, all command lists are passed to your ImGuiIO::RenderDrawListFn function for rendering.
// Each ImGui window contains its own ImDrawList. You can use ImGui::GetWindowDrawList() to access the current window draw list and draw custom primitives.
// You can interleave normal ImGui:: calls and adding primitives to the current draw list.
// All positions are generally in pixel coordinates (top-left at (0,0), bottom-right at io.DisplaySize), but you are totally free to apply whatever transformation matrix to want to the data (if you apply such transformation you'll want to apply it to ClipRect as well)
// Important: Primitives are always added to the list and not culled (culling is done at higher-level by ImGui:: functions), if you use this API a lot consider coarse culling your drawn objects.
extern(C++) struct ImDrawList
{
    // This is what you have to render
    ImVector!ImDrawCmd      CmdBuffer;          // Draw commands. Typically 1 command = 1 GPU draw call, unless the command is a callback.
    ImVector!ImDrawIdx      IdxBuffer;          // Index buffer. Each command consume ImDrawCmd::ElemCount of those
    ImVector!ImDrawVert     VtxBuffer;          // Vertex buffer.
    ImDrawListFlags         Flags;              // Flags, you may poke into these to adjust anti-aliasing settings per-primitive.

    // [Internal, used while building lists]
    const ImDrawListSharedData* _Data;          // Pointer to shared draw data (you can use ImGui::GetDrawListSharedData() to get the one from current ImGui context)
    const(char)*             _OwnerName;         // Pointer to owner window's name for debugging
    uint                    _VtxCurrentIdx;     // [Internal] == VtxBuffer.Size
    ImDrawVert*             _VtxWritePtr;       // [Internal] point within VtxBuffer.Data after each add command (to avoid using the ImVector<> operators too much)
    ImDrawIdx*              _IdxWritePtr;       // [Internal] point within IdxBuffer.Data after each add command (to avoid using the ImVector<> operators too much)
    ImVector!ImVec4         _ClipRectStack;     // [Internal]
    ImVector!ImTextureID    _TextureIdStack;    // [Internal]
    ImVector!ImVec2         _Path;              // [Internal] current path building
    int                     _ChannelsCurrent;   // [Internal] current channel number (0)
    int                     _ChannelsCount;     // [Internal] number of active channels (1+)
    ImVector!ImDrawChannel  _Channels;          // [Internal] draw channels for columns API (not resized down so _ChannelsCount may be smaller than _Channels.Size)

    // If you want to create ImDrawList instances, pass them ImGui::GetDrawListSharedData() or create and use your own ImDrawListSharedData (so you can use ImDrawList without ImGui)
    // ImDrawList(const ImDrawListSharedData* shared_data) { _Data = shared_data; _OwnerName = null; Clear(); }
    // ~ImDrawList() { ClearFreeMemory(); }
    // void  PushClipRect(ImVec2 clip_rect_min, ImVec2 clip_rect_max, bool intersect_with_current_clip_rect = false);  // Render-level scissoring. This is passed down to your render function but not used for CPU-side coarse clipping. Prefer using higher-level ImGui::PushClipRect() to affect logic (hit-testing and widget culling)
    // void  PushClipRectFullScreen();
    // void  PopClipRect();
    // void  PushTextureID(ImTextureID texture_id);
    // void  PopTextureID();
    // inline ImVec2   GetClipRectMin() const { ref const ImVec4 cr = _ClipRectStack.back(); return ImVec2(cr.x, cr.y); }
    // inline ImVec2   GetClipRectMax() const { ref const ImVec4 cr = _ClipRectStack.back(); return ImVec2(cr.z, cr.w); }

    // // Primitives
    void  AddLine(ref const ImVec2 a, ref const ImVec2 b, ImU32 col, float thickness = 1.0f);
    void  AddRect(ref const ImVec2 a, ref const ImVec2 b, ImU32 col, float rounding = 0.0f, int rounding_corners_flags = ImDrawCornerFlags_All, float thickness = 1.0f);   // a: upper-left, b: lower-right, rounding_corners_flags: 4-bits corresponding to which corner to round
    void  AddRectFilled(ref const ImVec2 a, ref const ImVec2 b, ImU32 col, float rounding = 0.0f, int rounding_corners_flags = ImDrawCornerFlags_All);                     // a: upper-left, b: lower-right
    void  AddRectFilledMultiColor(ref const ImVec2 a, ref const ImVec2 b, ImU32 col_upr_left, ImU32 col_upr_right, ImU32 col_bot_right, ImU32 col_bot_left);
    void  AddQuad(ref const ImVec2 a, ref const ImVec2 b, ref const ImVec2 c, ref const ImVec2 d, ImU32 col, float thickness = 1.0f);
    void  AddQuadFilled(ref const ImVec2 a, ref const ImVec2 b, ref const ImVec2 c, ref const ImVec2 d, ImU32 col);
    void  AddTriangle(ref const ImVec2 a, ref const ImVec2 b, ref const ImVec2 c, ImU32 col, float thickness = 1.0f);
    void  AddTriangleFilled(ref const ImVec2 a, ref const ImVec2 b, ref const ImVec2 c, ImU32 col);
    void  AddCircle(ref const ImVec2 centre, float radius, ImU32 col, int num_segments = 12, float thickness = 1.0f);
    void  AddCircleFilled(ref const ImVec2 centre, float radius, ImU32 col, int num_segments = 12);
    void  AddText(ref const ImVec2 pos, ImU32 col, const(char)* text_begin, const(char)* text_end = null);
    void  AddText(const(ImFont)* font, float font_size, ref const ImVec2 pos, ImU32 col, const(char)* text_begin, const(char)* text_end = null, float wrap_width = 0.0f, const(ImVec4)* cpu_fine_clip_rect = null);
    // void  AddImage(ImTextureID user_texture_id, ref const ImVec2 a, ref const ImVec2 b, ref const ImVec2 uv_a = ImVec2(0,0), ref const ImVec2 uv_b = ImVec2(1,1), ImU32 col = 0xFFFFFFFF);
    // void  AddImageQuad(ImTextureID user_texture_id, ref const ImVec2 a, ref const ImVec2 b, ref const ImVec2 c, ref const ImVec2 d, ref const ImVec2 uv_a = ImVec2(0,0), ref const ImVec2 uv_b = ImVec2(1,0), ref const ImVec2 uv_c = ImVec2(1,1), ref const ImVec2 uv_d = ImVec2(0,1), ImU32 col = 0xFFFFFFFF);
    // void  AddImageRounded(ImTextureID user_texture_id, ref const ImVec2 a, ref const ImVec2 b, ref const ImVec2 uv_a, ref const ImVec2 uv_b, ImU32 col, float rounding, int rounding_corners = ImDrawCornerFlags.All);
    // void  AddPolyline(const ImVec2* points, const int num_points, ImU32 col, bool closed, float thickness);
    // void  AddConvexPolyFilled(const ImVec2* points, const int num_points, ImU32 col); // Note: Anti-aliased filling requires points to be in clockwise order.
    // void  AddBezierCurve(ref const ImVec2 pos0, ref const ImVec2 cp0, ref const ImVec2 cp1, ref const ImVec2 pos1, ImU32 col, float thickness, int num_segments = 0);

    void  AddLine(const ImVec2 a, const ImVec2 b, ImU32 col, float thickness = 1.0f)                                                                { AddLine(a, b, col, thickness); }
    void  AddRect(const ImVec2 a, const ImVec2 b, ImU32 col, float rounding = 0.0f, int rounding_corners_flags = ImDrawCornerFlags_All, float thickness = 1.0f) { AddRect(a, b, col, rounding, rounding_corners_flags, thickness); }
    void  AddRectFilled(const ImVec2 a, const ImVec2 b, ImU32 col, float rounding = 0.0f, int rounding_corners_flags = ImDrawCornerFlags_All)       { AddRectFilled(a, b, col, rounding, rounding_corners_flags); }
    void  AddRectFilledMultiColor(const ImVec2 a, const ImVec2 b, ImU32 col_upr_left, ImU32 col_upr_right, ImU32 col_bot_right, ImU32 col_bot_left) { AddRectFilledMultiColor(a, b, col_upr_left, col_upr_right, col_bot_right, col_bot_left); }
    void  AddQuad(const ImVec2 a, const ImVec2 b, const ImVec2 c, const ImVec2 d, ImU32 col, float thickness = 1.0f)                                { AddQuad(a, b, c, d, col, thickness); }
    void  AddQuadFilled(const ImVec2 a, const ImVec2 b, const ImVec2 c, const ImVec2 d, ImU32 col)                                                  { AddQuadFilled(a, b, c, d, col); }
    void  AddTriangle(const ImVec2 a, const ImVec2 b, const ImVec2 c, ImU32 col, float thickness = 1.0f)                                            { AddTriangle(a, b, c, col, thickness); }
    void  AddTriangleFilled(const ImVec2 a, const ImVec2 b, const ImVec2 c, ImU32 col)                                                              { AddTriangleFilled(a, b, c, col); }
    void  AddCircle(const ImVec2 centre, float radius, ImU32 col, int num_segments = 12, float thickness = 1.0f)                                    { AddCircle(centre, radius, col, num_segments, thickness); }
    void  AddCircleFilled(const ImVec2 centre, float radius, ImU32 col, int num_segments = 12)                                                      { AddCircleFilled(centre, radius, col, num_segments); }
    void  AddText(const ImVec2 pos, ImU32 col, const(char)* text_begin, const(char)* text_end = null)                                               { AddText(pos, col, text_begin, text_end); }
    void  AddText(const(ImFont)* font, float font_size, const ImVec2 pos, ImU32 col, const(char)* text_begin, const(char)* text_end = null, float wrap_width = 0.0f, const(ImVec4)* cpu_fine_clip_rect = null) { AddText(font, font_size, pos, col, text_begin, text_end, wrap_width, cpu_fine_clip_rect); }

    // // Stateful path API, add points then finish with PathFillConvex() or PathStroke()
    // inline    void  PathClear()                                                 { _Path.resize(0); }
    // inline    void  PathLineTo(ref const ImVec2 pos)                               { _Path.push_back(pos); }
    // inline    void  PathLineToMergeDuplicate(ref const ImVec2 pos)                 { if (_Path.Size == 0 || memcmp(&_Path[_Path.Size-1], &pos, 8) != 0) _Path.push_back(pos); }
    // inline    void  PathFillConvex(ImU32 col)                                   { AddConvexPolyFilled(_Path.Data, _Path.Size, col); PathClear(); }  // Note: Anti-aliased filling requires points to be in clockwise order.
    // inline    void  PathStroke(ImU32 col, bool closed, float thickness = 1.0f)  { AddPolyline(_Path.Data, _Path.Size, col, closed, thickness); PathClear(); }
    // void  PathArcTo(ref const ImVec2 centre, float radius, float a_min, float a_max, int num_segments = 10);
    // void  PathArcToFast(ref const ImVec2 centre, float radius, int a_min_of_12, int a_max_of_12);                                            // Use precomputed angles for a 12 steps circle
    // void  PathBezierCurveTo(ref const ImVec2 p1, ref const ImVec2 p2, ref const ImVec2 p3, int num_segments = 0);
    // void  PathRect(ref const ImVec2 rect_min, ref const ImVec2 rect_max, float rounding = 0.0f, int rounding_corners_flags = ImDrawCornerFlags.All);

    // // Channels
    // // - Use to simulate layers. By switching channels to can render out-of-order (e.g. submit foreground primitives before background primitives)
    // // - Use to minimize draw calls (e.g. if going back-and-forth between multiple non-overlapping clipping rectangles, prefer to append into separate channels then merge at the end)
    // void  ChannelsSplit(int channels_count);
    // void  ChannelsMerge();
    // void  ChannelsSetCurrent(int channel_index);

    // // Advanced
    // void  AddCallback(ImDrawCallback callback, void* callback_data);  // Your rendering function must check for 'UserCallback' in ImDrawCmd and call the function instead of rendering triangles.
    // void  AddDrawCmd();                                               // This is useful if you need to forcefully create a new draw call (to allow for dependent rendering / blending). Otherwise primitives are merged into the same draw-call as much as possible
    // ImDrawList* CloneOutput() const;                                  // Create a clone of the CmdBuffer/IdxBuffer/VtxBuffer.

    // // Internal helpers
    // // NB: all primitives needs to be reserved via PrimReserve() beforehand!
    // void  Clear();
    // void  ClearFreeMemory();
    // void  PrimReserve(int idx_count, int vtx_count);
    // void  PrimRect(ref const ImVec2 a, ref const ImVec2 b, ImU32 col);      // Axis aligned rectangle (composed of two triangles)
    // void  PrimRectUV(ref const ImVec2 a, ref const ImVec2 b, ref const ImVec2 uv_a, ref const ImVec2 uv_b, ImU32 col);
    // void  PrimQuadUV(ref const ImVec2 a, ref const ImVec2 b, ref const ImVec2 c, ref const ImVec2 d, ref const ImVec2 uv_a, ref const ImVec2 uv_b, ref const ImVec2 uv_c, ref const ImVec2 uv_d, ImU32 col);
    // inline    void  PrimWriteVtx(ref const ImVec2 pos, ref const ImVec2 uv, ImU32 col){ _VtxWritePtr->pos = pos; _VtxWritePtr->uv = uv; _VtxWritePtr->col = col; _VtxWritePtr++; _VtxCurrentIdx++; }
    // inline    void  PrimWriteIdx(ImDrawIdx idx)                                 { *_IdxWritePtr = idx; _IdxWritePtr++; }
    // inline    void  PrimVtx(ref const ImVec2 pos, ref const ImVec2 uv, ImU32 col)     { PrimWriteIdx((ImDrawIdx)_VtxCurrentIdx); PrimWriteVtx(pos, uv, col); }
    // void  UpdateClipRect();
    // void  UpdateTextureID();
}

// All draw data to render an ImGui frame
// (NB: the style and the naming convention here is a little inconsistent but we preserve them for backward compatibility purpose)
extern(C++) struct ImDrawData
{
    bool            Valid;                  // Only valid after Render() is called and before the next NewFrame() is called.
    ImDrawList**    CmdLists;               // Array of ImDrawList* to render. The ImDrawList are owned by ImGuiContext and only pointed to from here.
    int             CmdListsCount;          // Number of ImDrawList* to render
    int             TotalIdxCount;          // For convenience, sum of all ImDrawList's IdxBuffer.Size
    int             TotalVtxCount;          // For convenience, sum of all ImDrawList's VtxBuffer.Size
    ImVec2          DisplayPos;             // Upper-left position of the viewport to render (== upper-left of the orthogonal projection matrix to use)
    ImVec2          DisplaySize;            // Size of the viewport to render (== io.DisplaySize for the main viewport) (DisplayPos + DisplaySize == lower-right of the orthogonal projection matrix to use)

    // Functions
    // ImDrawData()    { Valid = false; Clear(); }
    // ~ImDrawData()   { Clear(); }
    // void Clear()    { Valid = false; CmdLists = null; CmdListsCount = TotalVtxCount = TotalIdxCount = 0; } // The ImDrawList are owned by ImGuiContext!
    // void  DeIndexAllBuffers();                // Helper to convert all buffers from indexed to non-indexed, in case you cannot render indexed. Note: this is slow and most likely a waste of resources. Always prefer indexed rendering!
    // void  ScaleClipRects(ref const ImVec2 sc);   // Helper to scale the ClipRect field of each ImDrawCmd. Use if your final output buffer is at a different scale than ImGui expects, or if there is a difference between your window resolution and framebuffer resolution.
}

//-----------------------------------------------------------------------------
// Font API (ImFontConfig, ImFontGlyph, ImFontAtlasFlags, ImFontAtlas, ImFontGlyphRangesBuilder, ImFont)
//-----------------------------------------------------------------------------

extern(C++) struct ImFontConfig
{
    void*           FontData;               //          // TTF/OTF data
    int             FontDataSize;           //          // TTF/OTF data size
    bool            FontDataOwnedByAtlas;   // true     // TTF/OTF data ownership taken by the container ImFontAtlas (will delete memory itself).
    int             FontNo;                 // 0        // Index of font within TTF/OTF file
    float           SizePixels;             //          // Size in pixels for rasterizer.
    int             OversampleH;            // 3        // Rasterize at higher quality for sub-pixel positioning. We don't use sub-pixel positions on the Y axis.
    int             OversampleV;            // 1        // Rasterize at higher quality for sub-pixel positioning. We don't use sub-pixel positions on the Y axis.
    bool            PixelSnapH;             // false    // Align every glyph to pixel boundary. Useful e.g. if you are merging a non-pixel aligned font with the default font. If enabled, you can set OversampleH/V to 1.
    ImVec2          GlyphExtraSpacing;      // 0, 0     // Extra spacing (in pixels) between glyphs. Only X axis is supported for now.
    ImVec2          GlyphOffset;            // 0, 0     // Offset all glyphs from this font input.
    const(ImWchar)* GlyphRanges;            // null     // Pointer to a user-provided list of Unicode range (2 value per range, values are inclusive, zero-terminated list). THE ARRAY DATA NEEDS TO PERSIST AS LONG AS THE FONT IS ALIVE.
    float           GlyphMinAdvanceX;       // 0        // Minimum AdvanceX for glyphs, set Min to align font icons, set both Min/Max to enforce mono-space font
    float           GlyphMaxAdvanceX;       // FLT_MAX  // Maximum AdvanceX for glyphs
    bool            MergeMode;              // false    // Merge into previous ImFont, so you can combine multiple inputs font into one ImFont (e.g. ASCII font + icons + Japanese glyphs). You may want to use GlyphOffset.y when merge font of different heights.
    uint    RasterizerFlags;        // 0x00     // Settings for custom font rasterizer (e.g. ImGuiFreeType). Leave as zero if you aren't using one.
    float           RasterizerMultiply;     // 1.0f     // Brighten (>1.0f) or darken (<1.0f) font output. Brightening small fonts may be a good workaround to make them more readable.

    // [Internal]
    char[40]        Name;               // Name (strictly to ease debugging)
    ImFont*         DstFont;

}

struct ImFontGlyph
{
    ImWchar         Codepoint;          // 0x0000..0xFFFF
    float           AdvanceX;           // Distance to next character (= data from font + ImFontConfig::GlyphExtraSpacing.x baked in)
    float           X0, Y0, X1, Y1;     // Glyph corners
    float           U0, V0, U1, V1;     // Texture coordinates
}

// Helper to build glyph ranges from text/string data. Feed your application strings/characters to it then call BuildRanges().
// This is essentially a tightly packed of vector of 64k booleans = 8KB storage.
struct ImFontGlyphRangesBuilder
{
    ImVector!int UsedChars;            // Store 1-bit per Unicode code point (0=unused, 1=used)

    // ImFontGlyphRangesBuilder()          { UsedChars.resize(0x10000 / 32); memset(UsedChars.Data, 0, 0x10000 / 32); }
    bool           GetBit(int n) const  { int off = (n >> 5); int mask = 1 << (n & 31); return (UsedChars[off] & mask) != 0; } // Get bit n in the array
    void           SetBit(int n)        { int off = (n >> 5); int mask = 1 << (n & 31); UsedChars[off] |= mask; }              // Set bit n in the array
    void           AddChar(ImWchar c)   { SetBit(c); }                          // Add character
    void AddText(const(char)* text, const(char)* text_end = null);      // Add string (each character of the UTF-8 string are added)
    void AddRanges(const(ImWchar)* ranges);                            // Add ranges, e.g. builder.AddRanges(ImFontAtlas::GetGlyphRangesDefault()) to force add all of ASCII/Latin+Ext
    void BuildRanges(ImVector!ImWchar* out_ranges);                  // Output new ranges
}

enum
{
    ImFontAtlasFlags_None               = 0,
    ImFontAtlasFlags_NoPowerOfTwoHeight = 1 << 0,   // Don't round the height to next power of two
    ImFontAtlasFlags_NoMouseCursors     = 1 << 1    // Don't build software mouse cursors into the atlas
}

// Load and rasterize multiple TTF/OTF fonts into a same texture.
// Sharing a texture for multiple fonts allows us to reduce the number of draw calls during rendering.
// We also add custom graphic data into the texture that serves for ImGui.
//  1. (Optional) Call AddFont*** functions. If you don't call any, the default font will be loaded for you.
//  2. Call GetTexDataAsAlpha8() or GetTexDataAsRGBA32() to build and retrieve pixels data.
//  3. Upload the pixels data into a texture within your graphics system.
//  4. Call SetTexID(my_tex_id); and pass the pointer/identifier to your texture. This value will be passed back to you during rendering to identify the texture.
// IMPORTANT: If you pass a 'glyph_ranges' array to AddFont*** functions, you need to make sure that your array persist up until the ImFont is build (when calling GetTexData*** or Build()). We only copy the pointer, not the data.
extern(C++) struct ImFontAtlas
{
    ~this();
    ImFont*           AddFont(const ImFontConfig* font_cfg);
    ImFont*           AddFontDefault(const ImFontConfig* font_cfg = null);
    ImFont*           AddFontFromFileTTF(const(char)* filename, float size_pixels, const ImFontConfig* font_cfg = null, const ImWchar* glyph_ranges = null);
    ImFont*           AddFontFromMemoryTTF(void* font_data, int font_size, float size_pixels, const ImFontConfig* font_cfg = null, const ImWchar* glyph_ranges = null); // Note: Transfer ownership of 'ttf_data' to ImFontAtlas! Will be deleted after Build(). Set font_cfg->FontDataOwnedByAtlas to false to keep ownership.
    ImFont*           AddFontFromMemoryCompressedTTF(const(void)* compressed_font_data, int compressed_font_size, float size_pixels, const ImFontConfig* font_cfg = null, const ImWchar* glyph_ranges = null); // 'compressed_font_data' still owned by caller. Compress with binary_to_compressed_c.cpp.
    ImFont*           AddFontFromMemoryCompressedBase85TTF(const(char)* compressed_font_data_base85, float size_pixels, const ImFontConfig* font_cfg = null, const ImWchar* glyph_ranges = null);              // 'compressed_font_data_base85' still owned by caller. Compress with binary_to_compressed_c.cpp with -base85 parameter.
    void              ClearInputData();           // Clear input data (all ImFontConfig structures including sizes, TTF data, glyph ranges, etc.) = all the data used to build the texture and fonts.
    void              ClearTexData();             // Clear output texture data (CPU side). Saves RAM once the texture has been copied to graphics memory.
    void              ClearFonts();               // Clear output font data (glyphs storage, UV coordinates).
    void              Clear();                    // Clear all input and output.

    // Build atlas, retrieve pixel data.
    // User is in charge of copying the pixels into graphics memory (e.g. create a texture with your engine). Then store your texture handle with SetTexID().
    // RGBA32 format is provided for convenience and compatibility, but note that unless you use CustomRect to draw color data, the RGB pixels emitted from Fonts will all be white (~75% of waste).
    // Pitch = Width * BytesPerPixels
    bool              Build();                    // Build pixels data. This is called automatically for you by the GetTexData*** functions.
    void              GetTexDataAsAlpha8(ubyte** out_pixels, int* out_width, int* out_height, int* out_bytes_per_pixel = null);  // 1 byte per-pixel
    void              GetTexDataAsRGBA32(ubyte** out_pixels, int* out_width, int* out_height, int* out_bytes_per_pixel = null);  // 4 bytes-per-pixel
    bool              IsBuilt()                   { return Fonts.Size > 0 && (TexPixelsAlpha8 != null || TexPixelsRGBA32 != null); }
    void              SetTexID(ImTextureID id)    { TexID = id; }

    //-------------------------------------------
    // Glyph Ranges
    //-------------------------------------------

    // Helpers to retrieve list of common Unicode ranges (2 value per range, values are inclusive, zero-terminated list)
    // NB: Make sure that your string are UTF-8 and NOT in your local code page. In C++11, you can create UTF-8 string literal using the u8"Hello world" syntax. See FAQ for details.
    const(ImWchar)*    GetGlyphRangesDefault();                // Basic Latin, Extended Latin
    const(ImWchar)*    GetGlyphRangesKorean();                 // Default + Korean characters
    const(ImWchar)*    GetGlyphRangesJapanese();               // Default + Hiragana, Katakana, Half-Width, Selection of 1946 Ideographs
    const(ImWchar)*    GetGlyphRangesChineseFull();            // Default + Half-Width + Japanese Hiragana/Katakana + full set of about 21000 CJK Unified Ideographs
    const(ImWchar)*    GetGlyphRangesChineseSimplifiedCommon();// Default + Half-Width + Japanese Hiragana/Katakana + set of 2500 CJK Unified Ideographs for common simplified Chinese
    const(ImWchar)*    GetGlyphRangesCyrillic();               // Default + about 400 Cyrillic characters
    const(ImWchar)*    GetGlyphRangesThai();                   // Default + Thai characters

    //-------------------------------------------
    // Custom Rectangles/Glyphs API
    //-------------------------------------------

    // You can request arbitrary rectangles to be packed into the atlas, for your own purposes. After calling Build(), you can query the rectangle position and render your pixels.
    // You can also request your rectangles to be mapped as font glyph (given a font + Unicode point), so you can render e.g. custom colorful icons and use them as regular glyphs.
    extern(C++) struct CustomRect
    {
        uint    ID;             // Input    // User ID. Use <0x10000 to map into a font glyph, >=0x10000 for other/internal/custom texture data.
        ushort  Width, Height;  // Input    // Desired rectangle dimension
        ushort  X, Y;           // Output   // Packed position in Atlas
        float           GlyphAdvanceX;  // Input    // For custom font glyphs only (ID<0x10000): glyph xadvance
        ImVec2          GlyphOffset;    // Input    // For custom font glyphs only (ID<0x10000): glyph display offset
        ImFont*         Font;           // Input    // For custom font glyphs only (ID<0x10000): target font
        // CustomRect()            { ID = 0xFFFFFFFF; Width = Height = 0; X = Y = 0xFFFF; GlyphAdvanceX = 0.0f; GlyphOffset = ImVec2(0,0); Font = null; }
        bool IsPacked() const   { return X != 0xFFFF; }
    }

    // int       AddCustomRectRegular(uint id, int width, int height);                                                                   // Id needs to be >= 0x10000. Id >= 0x80000000 are reserved for ImGui and ImDrawList
    // int       AddCustomRectFontGlyph(ImFont* font, ImWchar id, int width, int height, float advance_x, ref const ImVec2 offset = ImVec2(0,0));   // Id needs to be < 0x10000 to register a rectangle to map into a specific font.
    // const CustomRect*   GetCustomRectByIndex(int index) const { if (index < 0) return null; return &CustomRects[index]; }

    // [Internal]
    // void      CalcCustomRectUV(const CustomRect* rect, ImVec2* out_uv_min, ImVec2* out_uv_max);
    // bool      GetMouseCursorTexData(ImGuiMouseCursor cursor, ImVec2* out_offset, ImVec2* out_size, ImVec2 out_uv_border[2], ImVec2 out_uv_fill[2]);

    //-------------------------------------------
    // Members
    //-------------------------------------------

    bool                        Locked;             // Marked as Locked by ImGui::NewFrame() so attempt to modify the atlas will assert.
    ImFontAtlasFlags            Flags;              // Build flags (see ImFontAtlasFlags_)
    ImTextureID                 TexID;              // User data to refer to the texture once it has been uploaded to user's graphic systems. It is passed back to you during rendering via the ImDrawCmd structure.
    int                         TexDesiredWidth;    // Texture width desired by user before Build(). Must be a power-of-two. If have many glyphs your graphics API have texture size restrictions you may want to increase texture width to decrease height.
    int                         TexGlyphPadding;    // Padding between glyphs within texture in pixels. Defaults to 1.

    // [Internal]
    // NB: Access texture data via GetTexData*() calls! Which will setup a default font for you.
    ubyte*              TexPixelsAlpha8;    // 1 component per pixel, each component is unsigned 8-bit. Total size = TexWidth * TexHeight
    uint*               TexPixelsRGBA32;    // 4 component per pixel, each component is unsigned 8-bit. Total size = TexWidth * TexHeight * 4
    int                         TexWidth;           // Texture width calculated during Build().
    int                         TexHeight;          // Texture height calculated during Build().
    ImVec2                      TexUvScale;         // = (1.0f/TexWidth, 1.0f/TexHeight)
    ImVec2                      TexUvWhitePixel;    // Texture coordinates to a white pixel
    ImVector!(ImFont*)          Fonts;              // Hold all the fonts returned by AddFont*. Fonts[0] is the default font upon calling ImGui::NewFrame(), use ImGui::PushFont()/PopFont() to change the current font.
    ImVector!CustomRect         CustomRects;        // Rectangles for packing custom texture data into the atlas.
    ImVector!ImFontConfig       ConfigData;         // Internal data
    int[1]                      CustomRectIds;   // Identifiers of custom texture rectangle used by ImFontAtlas/ImDrawList
}

// Font runtime data and rendering
// ImFontAtlas automatically loads a default embedded font for you when you call GetTexDataAsAlpha8() or GetTexDataAsRGBA32().
extern(C++) struct ImFont
{
    // Members: Hot ~62/78 bytes
    float                       FontSize;           // <user set>   // Height of characters, set during loading (don't change after loading)
    float                       Scale;              // = 1.f        // Base font scale, multiplied by the per-window font scale which you can adjust with SetFontScale()
    ImVec2                      DisplayOffset;      // = (0.f,0.f)  // Offset font rendering by xx pixels
    ImVector!ImFontGlyph        Glyphs;             //              // All glyphs.
    ImVector!float              IndexAdvanceX;      //              // Sparse. Glyphs->AdvanceX in a directly indexable way (more cache-friendly, for CalcTextSize functions which are often bottleneck in large UI).
    ImVector!ImWchar            IndexLookup;        //              // Sparse. Index glyphs by Unicode code-point.
    const(ImFontGlyph)*         FallbackGlyph;      // == FindGlyph(FontFallbackChar)
    float                       FallbackAdvanceX;   // == FallbackGlyph->AdvanceX
    ImWchar                     FallbackChar;       // = '?'        // Replacement glyph if one isn't found. Only set via SetFallbackChar()

    // Members: Cold ~18/26 bytes
    short                       ConfigDataCount;    // ~ 1          // Number of ImFontConfig involved in creating this font. Bigger than 1 when merging multiple font sources into one ImFont.
    ImFontConfig*               ConfigData;         //              // Pointer within ContainerAtlas->ConfigData
    ImFontAtlas*                ContainerAtlas;     //              // What we has been loaded into
    float                       Ascent, Descent;    //              // Ascent: distance from top to bottom of e.g. 'A' [0..FontSize]
    bool                        DirtyLookupTables;
    int                         MetricsTotalSurface;//              // Total surface in pixels to get an idea of the font rasterization/texture cost (not exact, we approximate the cost of padding between glyphs)

    // Methods
    // ImFont();
    // ~ImFont();
    // void              ClearOutputData();
    // void              BuildLookupTable();
    // const ImFontGlyph*FindGlyph(ImWchar c) const;
    // const ImFontGlyph*FindGlyphNoFallback(ImWchar c) const;
    // void              SetFallbackChar(ImWchar c);
    // float                       GetCharAdvance(ImWchar c) const     { return ((int)c < IndexAdvanceX.Size) ? IndexAdvanceX[(int)c] : FallbackAdvanceX; }
    // bool                        IsLoaded() const                    { return ContainerAtlas != null; }
    // const(char)*                 GetDebugName() const                { return ConfigData ? ConfigData->Name : "<unknown>"; }

    // // 'max_width' stops rendering after a certain width (could be turned into a 2d size). float.max to disable.
    // // 'wrap_width' enable automatic word-wrapping across multiple lines to fit into given width. 0.0f to disable.
    // ImVec2            CalcTextSizeA(float size, float max_width, float wrap_width, const(char)* text_begin, const(char)* text_end = null, const(char)** remaining = null) const; // utf8
    // const(char)*       CalcWordWrapPositionA(float scale, const(char)* text, const(char)* text_end, float wrap_width) const;
    // void              RenderChar(ImDrawList* draw_list, float size, ImVec2 pos, ImU32 col, ImWchar c) const;
    // void              RenderText(ImDrawList* draw_list, float size, ImVec2 pos, ImU32 col, ref const ImVec4 clip_rect, const(char)* text_begin, const(char)* text_end, float wrap_width = 0.0f, bool cpu_fine_clip = false) const;

    // // [Internal]
    // void              GrowIndex(int new_size);
    // void              AddGlyph(ImWchar c, float x0, float y0, float x1, float y1, float u0, float v0, float u1, float v1, float advance_x);
    // void              AddRemapChar(ImWchar dst, ImWchar src, bool overwrite_dst = true); // Makes 'dst' character/glyph points to 'src' character/glyph. Currently needs to be called AFTER fonts have been built.
}


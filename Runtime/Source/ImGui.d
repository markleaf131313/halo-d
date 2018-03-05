
module ImGui;

import core.stdc.stdarg : va_list;

import Game.Core.Math : Vec2, Vec4;

// Enumerations (declared as int for compatibility and to not pollute the top of this file)
alias ImU32                = uint;
alias ImWchar              = ushort;     // character for keyboard input/display
alias ImTextureID          = void*;      // user data to identify a texture (this is whatever to you want it to be! read the FAQ about ImTextureID in imgui.cpp)
alias ImGuiID              = ImU32;      // unique ID used by widgets (typically hashed from a stack of string)
alias ImGuiTextEditCallback       = int  function(ImGuiTextEditCallbackData *data);
alias ImGuiSizeConstraintCallback = void function(ImGuiSizeConstraintCallbackData* data);
struct ImGuiContext {}

alias ImVec2 = Vec2;
alias ImVec4 = Vec4;

// struct ImVec2
// {
//     float x = 0.0f;
//     float y = 0.0f;
// }

// struct ImVec4
// {
//     float x = 0.0f;
//     float y = 0.0f;
//     float z = 0.0f;
//     float w = 0.0f;
// }

struct ImRect
{
    ImVec2 Min;
    ImVec2 Max;
}

@nogc nothrow
{
    ImVec2 igGetCursorScreenPos()
    {
        ImVec2 result;
        igGetCursorScreenPos(result);
        return result;
    }

    bool igInputShort(const(char)* label, short* v, short step = 1, short step_fast = 100, ImGuiInputTextFlags extra_flags = ImGuiInputTextFlags.Default)
    {
        int value = *v;
        bool result = igInputInt(label, &value, step, step_fast, extra_flags);

        *v = cast(short)value;
        return result;
    }

    bool igDragShortRange2(const(char)* label, short* v_current_min, short* v_current_max, float v_speed = 1.0f,
        short v_min = 0, short v_max = 0, const(char)* display_format = "%.0f", const(char)* display_format_max = null)
    {
        int value_min = *v_current_min;
        int value_max = *v_current_max;
        bool result = igDragIntRange2(label, &value_min, &value_max, v_speed, v_min, v_max, display_format, display_format_max);

        *v_current_min = cast(short)value_min;
        *v_current_max = cast(short)value_max;
        return result;
    }
}

extern(C) @nogc nothrow
{
    // Main
    ImGuiIO*       igGetIO();
    ImGuiStyle*    igGetStyle();
    ImDrawData*    igGetDrawData();                              // same value as passed to your io.RenderDrawListsFn() function. valid after Render() and until the next call to NewFrame()
    void           igNewFrame();                                 // start a new ImGui frame, you can submit any command from this point until NewFrame()/Render().
    void           igRender();                                   // ends the ImGui frame, finalize rendering data, then call your io.RenderDrawListsFn() function if set.
    void           igShutdown();
    void           igShowUserGuide();                            // help block
    void           igShowStyleEditor(ImGuiStyle* r = null);      // style editor block. you can pass in a reference ImGuiStyle structure to compare to, revert to and save to (else it uses the default style)
    void           igShowTestWindow(bool* p_open = null);        // test window demonstrating ImGui features
    void           igShowMetricsWindow(bool* p_open = null);     // metrics window for debugging ImGui

    // Window
                               bool          igBegin(const(char)* name, bool* p_open = null, ImGuiWindowFlags flags = ImGuiWindowFlags.Default);                                             // push window to the stack and start appending to it. see .cpp for details. return false when window is collapsed, so you can early out in your code. 'bool* p_open' creates a widget on the upper-right to close the window (which sets your bool to false).
    pragma(mangle, "igBegin2") bool          igBegin(const(char)* name, bool* p_open, ImVec2 size_on_first_use, float bg_alpha = -1.0f, ImGuiWindowFlags flags = ImGuiWindowFlags.Default);   // OBSOLETE. this is the older/longer API. the extra parameters aren't very relevant. call SetNextWindowSize() instead if you want to set a window size. For regular windows, 'size_on_first_use' only applies to the first time EVER the window is created and probably not what you want! might obsolete this API eventually.
    void          igEnd();                                                                                                                                         // finish appending to current window, pop it off the window stack.
                                     bool          igBeginChild(const(char)* str_id, ImVec2 size = ImVec2(0,0), bool border = false, ImGuiWindowFlags extra_flags = ImGuiWindowFlags.Default);      // begin a scrolling region. size==0.0f: use remaining window size, size<0.0f: use remaining window size minus abs(size). size>0.0f: fixed size. each axis can use a different mode, e.g. ImVec2(0,400).
    pragma(mangle, "igBeginChildEx") bool          igBeginChild(ImGuiID id, ImVec2 size = ImVec2(0,0), bool border = false, ImGuiWindowFlags extra_flags = ImGuiWindowFlags.Default);               // "
    void          igEndChild();
    ImVec2        igGetContentRegionMax();                                              // current content boundaries (typically window boundaries including scrolling, or current column boundaries), in windows coordinates
    ImVec2        igGetContentRegionAvail();                                            // == GetContentRegionMax() - GetCursorPos()
    float         igGetContentRegionAvailWidth();                                       //
    ImVec2        igGetWindowContentRegionMin();                                        // content boundaries min (roughly (0,0)-Scroll), in window coordinates
    ImVec2        igGetWindowContentRegionMax();                                        // content boundaries max (roughly (0,0)+Size-Scroll) where Size can be override with SetNextWindowContentSize(), in window coordinates
    float         igGetWindowContentRegionWidth();                                      //
    ImDrawList*   igGetWindowDrawList();                                                // get rendering command-list if you want to append your own draw primitives
    ImVec2        igGetWindowPos();                                                     // get current window position in screen space (useful if you want to do your own drawing via the DrawList api)
    ImVec2        igGetWindowSize();                                                    // get current window size
    float         igGetWindowWidth();
    float         igGetWindowHeight();
    bool          igIsWindowCollapsed();
    void          igSetWindowFontScale(float scale);                                    // per-window font scale. Adjust IO.FontGlobalScale if you want to scale all windows

    void          igSetNextWindowPos(ImVec2 pos, ImGuiSetCond cond = ImGuiSetCond.Default);                            // set next window position. call before Begin()
    void          igSetNextWindowPosCenter(ImGuiSetCond cond = ImGuiSetCond.Default);                                  // set next window position to be centered on screen. call before Begin()
    void          igSetNextWindowSize(ImVec2 size, ImGuiSetCond cond = ImGuiSetCond.Default);                          // set next window size. set axis to 0.0f to force an auto-fit on this axis. call before Begin()
    void          igSetNextWindowSizeConstraints(ImVec2 size_min, ImVec2 size_max, ImGuiSizeConstraintCallback custom_callback = null, void* custom_callback_data = null); // set next window size limits. use -1,-1 on either X/Y axis to preserve the current size. Use callback to apply non-trivial programmatic constraints.
    void          igSetNextWindowContentSize(ImVec2 size);                                          // set next window content size (enforce the range of scrollbars). set axis to 0.0f to leave it automatic. call before Begin()
    void          igSetNextWindowContentWidth(float width);                                         // set next window content width (enforce the range of horizontal scrollbar). call before Begin()
    void          igSetNextWindowCollapsed(bool collapsed, ImGuiSetCond cond = ImGuiSetCond.Default);                  // set next window collapsed state. call before Begin()
    void          igSetNextWindowFocus();                                                           // set next window to be focused / front-most. call before Begin()
    void          igSetWindowPos(ImVec2 pos, ImGuiSetCond cond = ImGuiSetCond.Default);                                // (not recommended) set current window position - call within Begin()/End(). prefer using SetNextWindowPos(), as this may incur tearing and side-effects.
    void          igSetWindowSize(ImVec2 size, ImGuiSetCond cond = ImGuiSetCond.Default);                              // (not recommended) set current window size - call within Begin()/End(). set to ImVec2(0,0) to force an auto-fit. prefer using SetNextWindowSize(), as this may incur tearing and minor side-effects.
    void          igSetWindowCollapsed(bool collapsed, ImGuiSetCond cond = ImGuiSetCond.Default);                      // (not recommended) set current window collapsed state. prefer using SetNextWindowCollapsed().
    void          igSetWindowFocus();                                                                                  // (not recommended) set current window to be focused / front-most. prefer using SetNextWindowFocus().
    pragma(mangle, "igSetWindowPos2")       void igSetWindowPos(const(char)* name, ImVec2 pos, ImGuiSetCond cond = ImGuiSetCond.Default);             // set named window position.
    pragma(mangle, "igSetWindowSize2")      void igSetWindowSize(const(char)* name, ImVec2 size, ImGuiSetCond cond = ImGuiSetCond.Default);           // set named window size. set axis to 0.0f to force an auto-fit on this axis.
    pragma(mangle, "igSetWindowCollapsed2") void igSetWindowCollapsed(const(char)* name, bool collapsed, ImGuiSetCond cond = ImGuiSetCond.Default);   // set named window collapsed state
    pragma(mangle, "igSetWindowFocus2")     void igSetWindowFocus(const(char)* name);                                                                 // set named window to be focused / front-most. use NULL to remove focus.

    float         igGetScrollX();                                                       // get scrolling amount [0..GetScrollMaxX()]
    float         igGetScrollY();                                                       // get scrolling amount [0..GetScrollMaxY()]
    float         igGetScrollMaxX();                                                    // get maximum scrolling amount ~~ ContentSize.X - WindowSize.X
    float         igGetScrollMaxY();                                                    // get maximum scrolling amount ~~ ContentSize.Y - WindowSize.Y
    void          igSetScrollX(float scroll_x);                                         // set scrolling amount [0..GetScrollMaxX()]
    void          igSetScrollY(float scroll_y);                                         // set scrolling amount [0..GetScrollMaxY()]
    void          igSetScrollHere(float center_y_ratio = 0.5f);                         // adjust scrolling amount to make current cursor position visible. center_y_ratio=0.0: top, 0.5: center, 1.0: bottom.
    void          igSetScrollFromPosY(float pos_y, float center_y_ratio = 0.5f);        // adjust scrolling amount to make given position valid. use GetCursorPos() or GetCursorStartPos()+offset to get valid positions.
    void          igSetKeyboardFocusHere(int offset = 0);                               // focus keyboard on the next widget. Use positive 'offset' to access sub components of a multiple component widget. Use negative 'offset' to access previous widgets.
    void          igSetStateStorage(ImGuiStorage* tree);                                // replace tree state storage with our own (if you want to manipulate it yourself, typically clear subsection of it)
    ImGuiStorage* igGetStateStorage();

    // Parameters stacks (shared)
    void          igPushFont(ImFont* font);                                             // use NULL as a shortcut to push default font
    void          igPopFont();
    void          igPushStyleColor(ImGuiCol idx, ref const ImVec4 col);
    void          igPopStyleColor(int count = 1);
    void          igPushStyleVar(ImGuiStyleVar idx, float val);
    pragma(mangle, "igPushStyleVarVec")
    void          igPushStyleVar(ImGuiStyleVar idx, ImVec2 val);
    void          igPopStyleVar(int count = 1);
    ImFont*       igGetFont();                                                          // get current font
    float         igGetFontSize();                                                      // get current font size (= height in pixels) of current font with current scale applied
    ImVec2        igGetFontTexUvWhitePixel();                                           // get UV coordinate for a while pixel, useful to draw custom shapes via the ImDrawList API
                                       ImU32         igGetColorU32(ImGuiCol idx, float alpha_mul = 1.0f);                  // retrieve given style color with style alpha applied and optional extra alpha multiplier
    pragma(mangle, "igGetColorU32Vec") ImU32         igGetColorU32(ref const ImVec4 col);                                  // retrieve given color with style alpha applied


    // Parameters stacks (current window)
    void          igPushItemWidth(float item_width);                                    // width of items for the common item+label case, pixels. 0.0f = default to ~2/3 of windows width, >0.0f: width in pixels, <0.0f align xx pixels to the right of window (so -1.0f always align width to the right side)
    void          igPopItemWidth();
    float         igCalcItemWidth();                                                    // width of item given pushed settings and current cursor position
    void          igPushTextWrapPos(float wrap_pos_x = 0.0f);                           // word-wrapping for Text*() commands. < 0.0f: no wrapping; 0.0f: wrap to end of window (or column); > 0.0f: wrap at 'wrap_pos_x' position in window local space
    void          igPopTextWrapPos();
    void          igPushAllowKeyboardFocus(bool v);                                     // allow focusing using TAB/Shift-TAB, enabled by default but you can disable it for certain widgets
    void          igPopAllowKeyboardFocus();
    void          igPushButtonRepeat(bool repeat);                                      // in 'repeat' mode, Button*() functions return repeated true in a typematic manner (uses io.KeyRepeatDelay/io.KeyRepeatRate for now). Note that you can call IsItemActive() after any Button() to tell if the button is held in the current frame.
    void          igPopButtonRepeat();

    // Cursor / Layout
    void          igSeparator();                                                        // horizontal line
    void          igSameLine(float pos_x = 0.0f, float spacing_w = -1.0f);              // call between widgets or groups to layout them horizontally
    void          igNewLine();                                                          // undo a SameLine()
    void          igSpacing();                                                          // add vertical spacing
    void          igDummy(ref const ImVec2 size);                                       // add a dummy item of given size
    void          igIndent(float indent_w = 0.0f);                                      // move content position toward the right, by style.IndentSpacing or indent_w if >0
    void          igUnindent(float indent_w = 0.0f);                                    // move content position back to the left, by style.IndentSpacing or indent_w if >0
    void          igBeginGroup();                                                       // lock horizontal starting position + capture group bounding box into one "item" (so you can use IsItemHovered() or layout primitives such as SameLine() on whole group, etc.)
    void          igEndGroup();
    void          igGetCursorPos(ref ImVec2);                                           // cursor position is relative to window position
    float         igGetCursorPosX();                                                    // "
    float         igGetCursorPosY();                                                    // "
    void          igSetCursorPos(ImVec2 local_pos);                                     // "
    void          igSetCursorPosX(float x);                                             // "
    void          igSetCursorPosY(float y);                                             // "
    void          igGetCursorStartPos(ref ImVec2);                                      // initial cursor position
    void          igGetCursorScreenPos(ref ImVec2);                                     // cursor position in absolute screen coordinates [0..io.DisplaySize] (useful to work with ImDrawList API)
    void          igSetCursorScreenPos(ImVec2 pos);                                     // cursor position in absolute screen coordinates [0..io.DisplaySize]
    void          igAlignFirstTextHeightToWidgets();                                    // call once if the first item on the line is a Text() item and you want to vertically lower it to match subsequent (bigger) widgets
    float         igGetTextLineHeight();                                                // height of font == GetWindowFontSize()
    float         igGetTextLineHeightWithSpacing();                                     // distance (in pixels) between 2 consecutive lines of text == GetWindowFontSize() + GetStyle().ItemSpacing.y
    float         igGetItemsLineHeightWithSpacing();                                    // distance (in pixels) between 2 consecutive lines of standard height widgets == GetWindowFontSize() + GetStyle().FramePadding.y*2 + GetStyle().ItemSpacing.y

    // Columns
    // You can also use SameLine(pos_x) for simplified columning. The columns API is still work-in-progress and rather lacking.
    void          igColumns(int count = 1, const(char)* id = null, bool border = true); // setup number of columns. use an identifier to distinguish multiple column sets. close with Columns(1).
    void          igNextColumn();                                                       // next column
    int           igGetColumnIndex();                                                   // get current column index
    float         igGetColumnOffset(int column_index = -1);                             // get position of column line (in pixels, from the left side of the contents region). pass -1 to use current column, otherwise 0..GetcolumnsCount() inclusive. column 0 is usually 0.0f and not resizable unless you call this
    void          igSetColumnOffset(int column_index, float offset_x);                  // set position of column line (in pixels, from the left side of the contents region). pass -1 to use current column
    float         igGetColumnWidth(int column_index = -1);                              // column width (== GetColumnOffset(GetColumnIndex()+1) - GetColumnOffset(GetColumnOffset())
    int           igGetColumnsCount();                                                  // number of columns (what was passed to Columns())

    // ID scopes
    // If you are creating widgets in a loop you most likely want to push a unique identifier so ImGui can differentiate them.
    // You can also use the "##foobar" syntax within widget label to distinguish them from each others. Read "A primer on the use of labels/IDs" in the FAQ for more details.
    pragma(mangle, "igPushIdStr")      void          igPushID(const(char)* str_id);                                        // push identifier into the ID stack. IDs are hash of the *entire* stack!
    pragma(mangle, "igPushIdStrRange") void          igPushID(const(char)* str_id_begin, const(char)* str_id_end);
    pragma(mangle, "igPushIdPtr")      void          igPushID(const(void)* ptr_id);
    pragma(mangle, "igPushIdInt")      void          igPushID(int int_id);
    pragma(mangle, "igPopId")          void          igPopID();
    pragma(mangle, "igGetIdStr")       ImGuiID       igGetID(const(char)* str_id);                                         // calculate unique ID (hash of whole ID stack + given parameter). useful if you want to query into ImGuiStorage yourself. otherwise rarely needed
    pragma(mangle, "igGetIdStrRange")  ImGuiID       igGetID(const(char)* str_id_begin, const(char)* str_id_end);
    pragma(mangle, "igGetIdPtr")       ImGuiID       igGetID(const(void)* ptr_id);

    // Widgets
    void          igText(const(char)* fmt, ...);
    void          igTextV(const(char)* fmt, va_list args);
    void          igTextColored(ref const ImVec4 col, const(char)* fmt, ...);                  // shortcut for PushStyleColor(ImGuiCol_Text, col); Text(fmt, ...); PopStyleColor();
    void          igTextColoredV(ref const ImVec4 col, const(char)* fmt, va_list args);
    void          igTextDisabled(const(char)* fmt, ...);                                       // shortcut for PushStyleColor(ImGuiCol_Text, style.Colors[ImGuiCol_TextDisabled]); Text(fmt, ...); PopStyleColor();
    void          igTextDisabledV(const(char)* fmt, va_list args);
    void          igTextWrapped(const(char)* fmt, ...);                                        // shortcut for PushTextWrapPos(0.0f); Text(fmt, ...); PopTextWrapPos();. Note that this won't work on an auto-resizing window if there's no other widgets to extend the window width, yoy may need to set a size using SetNextWindowSize().
    void          igTextWrappedV(const(char)* fmt, va_list args);
    void          igTextUnformatted(const(char)* text, const(char)* text_end = null);          // doesn't require null terminated string if 'text_end' is specified. no copy done to any bounded stack buffer, recommended for long chunks of text
    void          igLabelText(const(char)* label, const(char)* fmt, ...);                      // display text+label aligned the same way as value+label widgets
    void          igLabelTextV(const(char)* label, const(char)* fmt, va_list args);
    void          igBullet();                                                                  // draw a small circle and keep the cursor on the same line. advance cursor x position by GetTreeNodeToLabelSpacing(), same distance that TreeNode() uses
    void          igBulletText(const(char)* fmt, ...);                                         // shortcut for Bullet()+Text()
    void          igBulletTextV(const(char)* fmt, va_list args);
    bool          igButton(const(char)* label, ImVec2 size = ImVec2(0,0));                     // button
    bool          igSmallButton(const(char)* label);                                           // button with FramePadding=(0,0)
    bool          igInvisibleButton(const(char)* str_id, ImVec2 size);
    void          igImage(ImTextureID user_texture_id, ImVec2 size, ImVec2 uv0 = ImVec2(0,0), ImVec2 uv1 = ImVec2(1,1), ImVec4 tint_col = ImVec4(1,1,1,1), ImVec4 border_col = ImVec4(0,0,0,0));
    bool          igImageButton(ImTextureID user_texture_id, ImVec2 size, ImVec2 uv0 = ImVec2(0,0), ImVec2 uv1 = ImVec2(1,1), int frame_padding = -1, ImVec4 bg_col = ImVec4(0,0,0,0), ImVec4 tint_col = ImVec4(1,1,1,1));    // <0 frame_padding uses default frame padding settings. 0 for no padding
    bool          igCheckbox(const(char)* label, bool* v);
    bool          igCheckboxFlags(const(char)* label, uint* flags, uint flags_value);
    pragma(mangle, "igRadioButtonBool")
    bool          igRadioButton(const(char)* label, bool active);
    bool          igRadioButton(const(char)* label, int* v, int v_button);
    bool          igCombo(const(char)* label, int* current_item, const(char*)* items, int items_count, int height_in_items = -1);
    pragma(mangle, "igCombo2") bool          igCombo(const(char)* label, int* current_item, const(char)* items_separated_by_zeros, int height_in_items = -1);      // separate items with \0, end item-list with \0\0
    pragma(mangle, "igCombo3") bool          igCombo(const(char)* label, int* current_item, bool function(void* data, int idx, const(char)** out_text) items_getter, void* data, int items_count, int height_in_items = -1);
    bool          igColorButton(ref const ImVec4 col, bool small_height = false, bool outline_border = true);
    bool          igColorEdit3(const(char)* label, ref float[3] col);                              // Hint: 'float col[3]' function argument is same as 'float* col'. You can pass address of first element out of a contiguous set, e.g. &myvector.x
    bool          igColorEdit4(const(char)* label, ref float[4] col, bool show_alpha = true);      // "
    void          igColorEditMode(ImGuiColorEditMode mode);                                        // FIXME-OBSOLETE: This is inconsistent with most of the API and will be obsoleted/replaced.
                                   void          igPlotLines(const(char)* label, const(float)* values, int values_count, int values_offset = 0, const(char)* overlay_text = null, float scale_min = float.max, float scale_max = float.max, ImVec2 graph_size = ImVec2(0,0), int stride = float.sizeof);
    pragma(mangle, "igPlotLines2") void          igPlotLines(const(char)* label, float function(void* data, int idx) values_getter, void* data, int values_count, int values_offset = 0, const(char)* overlay_text = null, float scale_min = float.max, float scale_max = float.max, ImVec2 graph_size = ImVec2(0,0));
                                       void          igPlotHistogram(const(char)* label, const(float)* values, int values_count, int values_offset = 0, const(char)* overlay_text = null, float scale_min = float.max, float scale_max = float.max, ImVec2 graph_size = ImVec2(0,0), int stride = float.sizeof);
    pragma(mangle, "igPlotHistogram2") void          igPlotHistogram(const(char)* label, float function(void* data, int idx) values_getter, void* data, int values_count, int values_offset = 0, const(char)* overlay_text = null, float scale_min = float.max, float scale_max = float.max, ImVec2 graph_size = ImVec2(0,0));
    void          igProgressBar(float fraction, ImVec2 size_arg = ImVec2(-1,0), const(char)* overlay = null);

    // Widgets: Drags (tip: ctrl+click on a drag box to input with keyboard. manually input values aren't clamped, can go off-bounds)
    // For all the Float2/Float3/Float4/Int2/Int3/Int4 versions of every functions, remember than a 'float v[3]' function argument is the same as 'float* v'. You can pass address of your first element out of a contiguous set, e.g. &myvector.x
    bool          igDragFloat(const(char)* label, float* v, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* display_format = "%.3f", float power = 1.0f);     // If v_min >= v_max we have no bound
    bool          igDragFloat2(const(char)* label, ref float[2] v, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* display_format = "%.3f", float power = 1.0f);
    bool          igDragFloat3(const(char)* label, ref float[3] v, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* display_format = "%.3f", float power = 1.0f);
    bool          igDragFloat4(const(char)* label, ref float[4] v, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* display_format = "%.3f", float power = 1.0f);
    bool          igDragFloatRange2(const(char)* label, float* v_current_min, float* v_current_max, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* display_format = "%.3f", const(char)* display_format_max = null, float power = 1.0f);
    bool          igDragInt(const(char)* label, int* v, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* display_format = "%.0f");                                       // If v_min >= v_max we have no bound
    bool          igDragInt2(const(char)* label, ref int[2] v, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* display_format = "%.0f");
    bool          igDragInt3(const(char)* label, ref int[3] v, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* display_format = "%.0f");
    bool          igDragInt4(const(char)* label, ref int[4] v, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* display_format = "%.0f");
    bool          igDragIntRange2(const(char)* label, int* v_current_min, int* v_current_max, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* display_format = "%.0f", const(char)* display_format_max = null);

    // Widgets: Input with Keyboard
    bool          igInputText(const(char)* label, char* buf, size_t buf_size, ImGuiInputTextFlags flags = ImGuiInputTextFlags.Default, ImGuiTextEditCallback callback = null, void* user_data = null);
    bool          igInputTextMultiline(const(char)* label, char* buf, size_t buf_size, ImVec2 size = ImVec2(0,0), ImGuiInputTextFlags flags = ImGuiInputTextFlags.Default, ImGuiTextEditCallback callback = null, void* user_data = null);
    bool          igInputFloat(const(char)* label, float* v, float step = 0.0f, float step_fast = 0.0f, int decimal_precision = -1, ImGuiInputTextFlags extra_flags = ImGuiInputTextFlags.Default);
    bool          igInputFloat2(const(char)* label, ref float[2] v, int decimal_precision = -1, ImGuiInputTextFlags extra_flags = ImGuiInputTextFlags.Default);
    bool          igInputFloat3(const(char)* label, ref float[3] v, int decimal_precision = -1, ImGuiInputTextFlags extra_flags = ImGuiInputTextFlags.Default);
    bool          igInputFloat4(const(char)* label, ref float[4] v, int decimal_precision = -1, ImGuiInputTextFlags extra_flags = ImGuiInputTextFlags.Default);
    bool          igInputInt(const(char)* label, int* v, int step = 1, int step_fast = 100, ImGuiInputTextFlags extra_flags = ImGuiInputTextFlags.Default);
    bool          igInputInt2(const(char)* label, ref int[2] v, ImGuiInputTextFlags extra_flags = ImGuiInputTextFlags.Default);
    bool          igInputInt3(const(char)* label, ref int[3] v, ImGuiInputTextFlags extra_flags = ImGuiInputTextFlags.Default);
    bool          igInputInt4(const(char)* label, ref int[4] v, ImGuiInputTextFlags extra_flags = ImGuiInputTextFlags.Default);

    // Widgets: Sliders (tip: ctrl+click on a slider to input with keyboard. manually input values aren't clamped, can go off-bounds)
    bool          igSliderFloat(const(char)* label, float* v, float v_min, float v_max, const(char)* display_format = "%.3f", float power = 1.0f);     // adjust display_format to decorate the value with a prefix or a suffix. Use power!=1.0 for logarithmic sliders
    bool          igSliderFloat2(const(char)* label, ref float[2] v, float v_min, float v_max, const(char)* display_format = "%.3f", float power = 1.0f);
    bool          igSliderFloat3(const(char)* label, ref float[3] v, float v_min, float v_max, const(char)* display_format = "%.3f", float power = 1.0f);
    bool          igSliderFloat4(const(char)* label, ref float[4] v, float v_min, float v_max, const(char)* display_format = "%.3f", float power = 1.0f);
    bool          igSliderAngle(const(char)* label, float* v_rad, float v_degrees_min = -360.0f, float v_degrees_max = +360.0f);
    bool          igSliderInt(const(char)* label, int* v, int v_min, int v_max, const(char)* display_format = "%.0f");
    bool          igSliderInt2(const(char)* label, ref int[2] v, int v_min, int v_max, const(char)* display_format = "%.0f");
    bool          igSliderInt3(const(char)* label, ref int[3] v, int v_min, int v_max, const(char)* display_format = "%.0f");
    bool          igSliderInt4(const(char)* label, ref int[4] v, int v_min, int v_max, const(char)* display_format = "%.0f");
    bool          igVSliderFloat(const(char)* label, ImVec2 size, float* v, float v_min, float v_max, const(char)* display_format = "%.3f", float power = 1.0f);
    bool          igVSliderInt(const(char)* label, ImVec2 size, int* v, int v_min, int v_max, const(char)* display_format = "%.0f");

    // Widgets: Trees
                                       bool          igTreeNode(const(char)* label);                                           // if returning 'true' the node is open and the tree id is pushed into the id stack. user is responsible for calling TreePop().
    pragma(mangle, "igTreeNodeStr")    bool          igTreeNode(const(char)* str_id, const(char)* fmt, ...);                   // read the FAQ about why and how to use ID. to align arbitrary text at the same level as a TreeNode() you can use Bullet().
    pragma(mangle, "igTreeNodePtr")    bool          igTreeNode(const(void)* ptr_id, const(char)* fmt, ...);                   // "
    pragma(mangle, "igTreeNodeStrV")   bool          igTreeNodeV(const(char)* str_id, const(char)* fmt, va_list args);         // "
    pragma(mangle, "igTreeNodePtrV")   bool          igTreeNodeV(const(void)* ptr_id, const(char)* fmt, va_list args);         // "
                                       bool          igTreeNodeEx(const(char)* label, ImGuiTreeNodeFlags flags = ImGuiTreeNodeFlags.Default);
    pragma(mangle, "igTreeNodeExStr")  bool          igTreeNodeEx(const(char)* str_id, ImGuiTreeNodeFlags flags, const(char)* fmt, ...);
    pragma(mangle, "igTreeNodeExPtr")  bool          igTreeNodeEx(const(void)* ptr_id, ImGuiTreeNodeFlags flags, const(char)* fmt, ...);
                                       bool          igTreeNodeExV(const(char)* str_id, ImGuiTreeNodeFlags flags, const(char)* fmt, va_list args);
    pragma(mangle, "igTreeNodeExVPtr") bool          igTreeNodeExV(const(void)* ptr_id, ImGuiTreeNodeFlags flags, const(char)* fmt, va_list args);
    pragma(mangle, "igTreePushStr")    void          igTreePush(const(char)* str_id = null);          // ~ Indent()+PushId(). Already called by TreeNode() when returning true, but you can call Push/Pop yourself for layout purpose
    pragma(mangle, "igTreePushPtr")    void          igTreePush(const(void)* ptr_id = null);          // "
    void          igTreePop();                                                                        // ~ Unindent()+PopId()
    void          igTreeAdvanceToLabelPos();                                                          // advance cursor x position by GetTreeNodeToLabelSpacing()
    float         igGetTreeNodeToLabelSpacing();                                                      // horizontal distance preceeding label when using TreeNode*() or Bullet() == (g.FontSize + style.FramePadding.x*2) for a regular unframed TreeNode
    void          igSetNextTreeNodeOpen(bool is_open, ImGuiSetCond cond = ImGuiSetCond.Default);      // set next TreeNode/CollapsingHeader open state.
    bool          igCollapsingHeader(const(char)* label, ImGuiTreeNodeFlags flags = ImGuiTreeNodeFlags.Default);               // if returning 'true' the header is open. doesn't indent nor push on ID stack. user doesn't have to call TreePop().
    pragma(mangle, "igCollapsingHeader2")
    bool          igCollapsingHeader(const(char)* label, bool* p_open, ImGuiTreeNodeFlags flags = ImGuiTreeNodeFlags.Default); // when 'p_open' isn't NULL, display an additional small close button on upper right of the header

    // Widgets: Selectable / Lists
                                       bool          igSelectable(const(char)* label, bool selected = false, ImGuiSelectableFlags flags = ImGuiSelectableFlags.Default, ImVec2 size = ImVec2(0,0));  // size.x==0.0: use remaining width, size.x>0.0: specify width. size.y==0.0: use label height, size.y>0.0: specify height
    pragma(mangle, "igSelectableEx")   bool          igSelectable(const(char)* label, bool* p_selected, ImGuiSelectableFlags flags = ImGuiSelectableFlags.Default, ImVec2 size = ImVec2(0,0));
                                       bool          igListBox(const(char)* label, int* current_item, const(char)** items, int items_count, int height_in_items = -1);
    pragma(mangle, "igListBox2")       bool          igListBox(const(char)* label, int* current_item, bool function(void* data, int idx, const(char)** out_text) items_getter, void* data, int items_count, int height_in_items = -1);
                                       bool          igListBoxHeader(const(char)* label, ImVec2 size = ImVec2(0,0));                 // use if you want to reimplement ListBox() will custom data or interactions. make sure to call ListBoxFooter() afterwards.
    pragma(mangle, "igListBoxHeader2") bool          igListBoxHeader(const(char)* label, int items_count, int height_in_items = -1); // "
                                       void          igListBoxFooter();                                                              // terminate the scrolling region

    // Widgets: Value() Helpers. Output single value in "name: value" format (tip: freely declare more in your code to handle your types. you can add functions to the ImGui namespace)
    pragma(mangle, "igValueBool")   void          igValue(const(char)* prefix, bool b);
    pragma(mangle, "igValueInt")    void          igValue(const(char)* prefix, int v);
    pragma(mangle, "igValueUInt")   void          igValue(const(char)* prefix, uint v);
    pragma(mangle, "igValueFloat")  void          igValue(const(char)* prefix, float v, const(char)* float_format = null);
                                    void          igValueColor(const(char)* prefix, ref const ImVec4 v);
    pragma(mangle, "igValueColor2") void          igValueColor(const(char)* prefix, uint v);

    // Tooltips
    void          igSetTooltip(const(char)* fmt, ...);                                  // set tooltip under mouse-cursor, typically use with ImGui::IsHovered(). last call wins
    void          igSetTooltipV(const(char)* fmt, va_list args);
    void          igBeginTooltip();                                                     // use to create full-featured tooltip windows that aren't just text
    void          igEndTooltip();

    // Menus
    bool          igBeginMainMenuBar();                                                 // create and append to a full screen menu-bar. only call EndMainMenuBar() if this returns true!
    void          igEndMainMenuBar();
    bool          igBeginMenuBar();                                                     // append to menu-bar of current window (requires ImGuiWindowFlags_MenuBar flag set). only call EndMenuBar() if this returns true!
    void          igEndMenuBar();
    bool          igBeginMenu(const(char)* label, bool enabled = true);                 // create a sub-menu entry. only call EndMenu() if this returns true!
    void          igEndMenu();
    bool          igMenuItem(const(char)* label, const(char)* shortcut = null, bool selected = false, bool enabled = true);  // return true when activated. shortcuts are displayed for convenience but not processed by ImGui at the moment
    pragma(mangle, "igMenuItemPtr") bool igMenuItem(const(char)* label, const(char)* shortcut, bool* p_selected, bool enabled = true);              // return true when activated + toggle (*p_selected) if p_selected != NULL

    // Popups
    void          igOpenPopup(const(char)* str_id);                                      // mark popup as open. popups are closed when user click outside, or activate a pressable item, or CloseCurrentPopup() is called within a BeginPopup()/EndPopup() block. popup identifiers are relative to the current ID-stack (so OpenPopup and BeginPopup needs to be at the same level).
    bool          igBeginPopup(const(char)* str_id);                                     // return true if the popup is open, and you can start outputting to it. only call EndPopup() if BeginPopup() returned true!
    bool          igBeginPopupModal(const(char)* name, bool* p_open = null, ImGuiWindowFlags extra_flags = ImGuiWindowFlags.Default);               // modal dialog (can't close them by clicking outside)
    bool          igBeginPopupContextItem(const(char)* str_id, int mouse_button = 1);                                        // helper to open and begin popup when clicked on last item. read comments in .cpp!
    bool          igBeginPopupContextWindow(bool also_over_items = true, const(char)* str_id = null, int mouse_button = 1);  // helper to open and begin popup when clicked on current window.
    bool          igBeginPopupContextVoid(const(char)* str_id = null, int mouse_button = 1);                                 // helper to open and begin popup when clicked in void (no window).
    void          igEndPopup();
    void          igCloseCurrentPopup();                                                // close the popup we have begin-ed into. clicking on a MenuItem or Selectable automatically close the current popup.

    // Logging: all text output from interface is redirected to tty/file/clipboard. By default, tree nodes are automatically opened during logging.
    void          igLogToTTY(int max_depth = -1);                                       // start logging to tty
    void          igLogToFile(int max_depth = -1, const(char)* filename = null);        // start logging to file
    void          igLogToClipboard(int max_depth = -1);                                 // start logging to OS clipboard
    void          igLogFinish();                                                        // stop logging (close file, etc.)
    void          igLogButtons();                                                       // helper to display buttons for logging to tty/file/clipboard
    void          igLogText(const(char)* fmt, ...);                                     // pass text data straight to log (without being displayed)

    // Clipping
    void          igPushClipRect(ImVec2 clip_rect_min, ImVec2 clip_rect_max, bool intersect_with_current_clip_rect);
    void          igPopClipRect();

    // Utilities
    bool          igIsItemHovered();                                                    // was the last item hovered by mouse?
    bool          igIsItemHoveredRect();                                                // was the last item hovered by mouse? even if another item is active or window is blocked by popup while we are hovering this
    bool          igIsItemActive();                                                     // was the last item active? (e.g. button being held, text field being edited- items that don't interact will always return false)
    bool          igIsItemClicked(int mouse_button = 0);                                // was the last item clicked? (e.g. button/node just clicked on)
    bool          igIsItemVisible();                                                    // was the last item visible? (aka not out of sight due to clipping/scrolling.)
    bool          igIsAnyItemHovered();
    bool          igIsAnyItemActive();
    void          igGetItemRectMin(ref ImVec2);                                         // get bounding rect of last item in screen space
    void          igGetItemRectMax(ref ImVec2);                                         // "
    void          igGetItemRectSize(ref ImVec2);                                        // "
    void          igSetItemAllowOverlap();                                              // allow last item to be overlapped by a subsequent item. sometimes useful with invisible buttons, selectables, etc. to catch unused area.
    bool          igIsWindowHovered();                                                  // is current window hovered and hoverable (not blocked by a popup) (differentiate child windows from each others)
    bool          igIsWindowFocused();                                                  // is current window focused
    bool          igIsRootWindowFocused();                                              // is current root window focused (root = top-most parent of a child, otherwise self)
    bool          igIsRootWindowOrAnyChildFocused();                                    // is current root window or any of its child (including current window) focused
    bool          igIsRootWindowOrAnyChildHovered();                                    // is current root window or any of its child (including current window) hovered and hoverable (not blocked by a popup)
    bool          igIsRectVisible(ImVec2 size);                                         // test if rectangle of given size starting from cursor pos is visible (not clipped). to perform coarse clipping on user's side (as an optimization)
    bool          igIsPosHoveringAnyWindow(ImVec2 pos);                                 // is given position hovering any active imgui window
    float         igGetTime();
    int           igGetFrameCount();
    const(char)*  igGetStyleColName(ImGuiCol idx);
    void          igCalcItemRectClosestPoint(ref ImVec2, ImVec2 pos, bool on_edge = false, float outward = +0.0f);   // utility to find the closest point the last item bounding rectangle edge. useful to visually link items
    void          igCalcTextSize(ref ImVec2, const(char)* text, const(char)* text_end = null, bool hide_text_after_double_hash = false, float wrap_width = -1.0f);
    void          igCalcListClipping(int items_count, float items_height, int* out_items_display_start, int* out_items_display_end);    // calculate coarse clipping for large list of evenly sized items. Prefer using the ImGuiListClipper higher-level helper if you can.

    bool          igBeginChildFrame(ImGuiID id, ImVec2 size, ImGuiWindowFlags extra_flags = ImGuiWindowFlags.Default);      // helper to create a child window / scrolling region that looks like a normal widget frame
    void          igEndChildFrame();

    void          igColorConvertU32ToFloat4(ref ImVec4, ImU32 input);
    ImU32         igColorConvertFloat4ToU32(ref const ImVec4 input);
    void          igColorConvertRGBtoHSV(float r, float g, float b, ref float out_h, ref float out_s, ref float out_v);
    void          igColorConvertHSVtoRGB(float h, float s, float v, ref float out_r, ref float out_g, ref float out_b);

    // Inputs
    int           igGetKeyIndex(ImGuiKey key);                                          // map ImGuiKey_* values into user's key index. == io.KeyMap[key]
    bool          igIsKeyDown(int key_index);                                           // key_index into the keys_down[] array, imgui doesn't know the semantic of each entry, uses your own indices!
    bool          igIsKeyPressed(int key_index, bool repeat = true);                    // uses user's key indices as stored in the keys_down[] array. if repeat=true. uses io.KeyRepeatDelay / KeyRepeatRate
    bool          igIsKeyReleased(int key_index);                                       // "
    bool          igIsMouseDown(int button);                                            // is mouse button held
    bool          igIsMouseClicked(int button, bool repeat = false);                    // did mouse button clicked (went from !Down to Down)
    bool          igIsMouseDoubleClicked(int button);                                   // did mouse button double-clicked. a double-click returns false in IsMouseClicked(). uses io.MouseDoubleClickTime.
    bool          igIsMouseReleased(int button);                                        // did mouse button released (went from Down to !Down)
    bool          igIsMouseHoveringWindow();                                            // is mouse hovering current window ("window" in API names always refer to current window). disregarding of any consideration of being blocked by a popup. (unlike IsWindowHovered() this will return true even if the window is blocked because of a popup)
    bool          igIsMouseHoveringAnyWindow();                                         // is mouse hovering any visible window
    bool          igIsMouseHoveringRect(ImVec2 r_min, ImVec2 r_max, bool clip = true);  // is mouse hovering given bounding rect (in screen space). clipped by current clipping settings. disregarding of consideration of focus/window ordering/blocked by a popup.
    bool          igIsMouseDragging(int button = 0, float lock_threshold = -1.0f);      // is mouse dragging. if lock_threshold < -1.0f uses io.MouseDraggingThreshold
    ImVec2        igGetMousePos();                                                      // shortcut to ImGui::GetIO().MousePos provided by user, to be consistent with other calls
    ImVec2        igGetMousePosOnOpeningCurrentPopup();                                 // retrieve backup of mouse positioning at the time of opening popup we have BeginPopup() into
    ImVec2        igGetMouseDragDelta(int button = 0, float lock_threshold = -1.0f);    // dragging amount since clicking. if lock_threshold < -1.0f uses io.MouseDraggingThreshold
    void          igResetMouseDragDelta(int button = 0);                                //
    ImGuiMouseCursor igGetMouseCursor();                                                // get desired cursor type, reset in ImGui::NewFrame(), this updated during the frame. valid before Render(). If you use software rendering by setting io.MouseDrawCursor ImGui will render those for you
    void          igSetMouseCursor(ImGuiMouseCursor type);                              // set desired cursor type
    void          igCaptureKeyboardFromApp(bool capture = true);                        // manually override io.WantCaptureKeyboard flag next frame (said flag is entirely left for your application handle). e.g. force capture keyboard when your widget is being hovered.
    void          igCaptureMouseFromApp(bool capture = true);                           // manually override io.WantCaptureMouse flag next frame (said flag is entirely left for your application handle).

    void*         igMemAlloc(size_t sz);
    void          igMemFree(void* ptr);
    const(char)*  igGetClipboardText();
    void          igSetClipboardText(const(char)* text);

    // Internal context access - if you want to use multiple context, share context between modules (e.g. DLL). There is a default context created and active by default.
    // All contexts share a same ImFontAtlas by default. If you want different font atlas, you can new() them and overwrite the GetIO().Fonts variable of an ImGui context.
    const(char)*  igGetVersion();
    ImGuiContext* igCreateContext(void* function(size_t) malloc_fn = null, void function(void*) free_fn = null);
    void          igDestroyContext(ImGuiContext* ctx);
    ImGuiContext* igGetCurrentContext();
    void          igSetCurrentContext(ImGuiContext* ctx);

// TODO make the following private:

    void             ImFontConfig_DefaultConstructor(ImFontConfig* config);

    void             ImFontAtlas_GetTexDataAsRGBA32(ImFontAtlas* atlas, ubyte** out_pixels, int* out_width, int* out_height, int* out_bytes_per_pixel);
    void             ImFontAtlas_GetTexDataAsAlpha8(ImFontAtlas* atlas, ubyte** out_pixels, int* out_width, int* out_height, int* out_bytes_per_pixel);
    void             ImFontAtlas_SetTexID(ImFontAtlas* atlas, void* tex);
    ImFont*          ImFontAtlas_AddFont(ImFontAtlas* atlas, const(ImFontConfig)* font_cfg);
    ImFont*          ImFontAtlas_AddFontDefault(ImFontAtlas* atlas, const(ImFontConfig)* font_cfg);
    ImFont*          ImFontAtlas_AddFontFromFileTTF(ImFontAtlas* atlas, const(char)* filename, float size_pixels, const(ImFontConfig)* font_cfg, const(ImWchar)* glyph_ranges);
    ImFont*          ImFontAtlas_AddFontFromMemoryTTF(ImFontAtlas* atlas, void* ttf_data, int ttf_size, float size_pixels, const(ImFontConfig)* font_cfg, const(ImWchar)* glyph_ranges);
    ImFont*          ImFontAtlas_AddFontFromMemoryCompressedTTF(ImFontAtlas* atlas, const(void)* compressed_ttf_data, int compressed_ttf_size, float size_pixels, const(ImFontConfig)* font_cfg, const(ImWchar)* glyph_ranges);
    ImFont*          ImFontAtlas_AddFontFromMemoryCompressedBase85TTF(ImFontAtlas* atlas, const(char)* compressed_ttf_data_base85, float size_pixels, const(ImFontConfig)* font_cfg, const(ImWchar)* glyph_ranges);
    void             ImFontAtlas_ClearTexData(ImFontAtlas* atlas);
    void             ImFontAtlas_Clear(ImFontAtlas* atlas);

    void             ImGuiIO_AddInputCharacter(ushort c);
    void             ImGuiIO_AddInputCharactersUTF8(const(char)* utf8_chars);
    void             ImGuiIO_ClearInputCharacters();

    //ImDrawData


    //ImDrawList
    int                  ImDrawList_GetVertexBufferSize(ImDrawList* list);
    ImDrawVert*          ImDrawList_GetVertexPtr(ImDrawList* list, int n);
    int                  ImDrawList_GetIndexBufferSize(ImDrawList* list);
    ImDrawIdx*           ImDrawList_GetIndexPtr(ImDrawList* list, int n);
    int                  ImDrawList_GetCmdSize(ImDrawList* list);
    ImDrawCmd*           ImDrawList_GetCmdPtr(ImDrawList* list, int n);

    void             ImDrawList_Clear(ImDrawList* list);
    void             ImDrawList_ClearFreeMemory(ImDrawList* list);
    void             ImDrawList_PushClipRect(ImDrawList* list, ImVec2 clip_rect_min, ImVec2 clip_rect_max, bool intersect_with_current_clip_rect);
    void             ImDrawList_PushClipRectFullScreen(ImDrawList* list);
    void             ImDrawList_PopClipRect(ImDrawList* list);
    void             ImDrawList_PushTextureID(ImDrawList* list, ImTextureID texture_id);
    void             ImDrawList_PopTextureID(ImDrawList* list);

    // Primitives
    void             ImDrawList_AddLine(ImDrawList* list, ImVec2 a, ImVec2 b, ImU32 col, float thickness);
    void             ImDrawList_AddRect(ImDrawList* list, ImVec2 a, ImVec2 b, ImU32 col, float rounding, int rounding_corners, float thickness);
    void             ImDrawList_AddRectFilled(ImDrawList* list, ImVec2 a, ImVec2 b, ImU32 col, float rounding, int rounding_corners);
    void             ImDrawList_AddRectFilledMultiColor(ImDrawList* list, ImVec2 a, ImVec2 b, ImU32 col_upr_left, ImU32 col_upr_right, ImU32 col_bot_right, ImU32 col_bot_left);
    void             ImDrawList_AddQuad(ImDrawList* list, ImVec2 a, ImVec2 b, ImVec2 c, ImVec2 d, ImU32 col, float thickness);
    void             ImDrawList_AddQuadFilled(ImDrawList* list, ImVec2 a, ImVec2 b, ImVec2 c, ImVec2 d, ImU32 col);
    void             ImDrawList_AddTriangle(ImDrawList* list, ImVec2 a, ImVec2 b, ImVec2 c, ImU32 col, float thickness);
    void             ImDrawList_AddTriangleFilled(ImDrawList* list, ImVec2 a, ImVec2 b, ImVec2 c, ImU32 col);
    void             ImDrawList_AddCircle(ImDrawList* list, ImVec2 centre, float radius, ImU32 col, int num_segments, float thickness);
    void             ImDrawList_AddCircleFilled(ImDrawList* list, ImVec2 centre, float radius, ImU32 col, int num_segments);
    void             ImDrawList_AddText(ImDrawList* list, ImVec2 pos, ImU32 col, const(char)* text_begin, const(char)* text_end);
    void             ImDrawList_AddTextExt(ImDrawList* list, const(ImFont)* font, float font_size, ImVec2 pos, ImU32 col, const(char)* text_begin, const(char)* text_end, float wrap_width, const(ImVec4)* cpu_fine_clip_rect);
    void             ImDrawList_AddImage(ImDrawList* list, ImTextureID user_texture_id, ImVec2 a, ImVec2 b, ImVec2 uv0, ImVec2 uv1, ImU32 col);
    void             ImDrawList_AddPolyline(ImDrawList* list, const(ImVec2)* points, const int num_points, ImU32 col, bool closed, float thickness, bool anti_aliased);
    void             ImDrawList_AddConvexPolyFilled(ImDrawList* list, const(ImVec2)* points, const int num_points, ImU32 col, bool anti_aliased);
    void             ImDrawList_AddBezierCurve(ImDrawList* list, ImVec2 pos0, ImVec2 cp0, ImVec2 cp1, ImVec2 pos1, ImU32 col, float thickness, int num_segments);

    // Stateful path API, add points then finish with PathFill() or PathStroke()
    void             ImDrawList_PathClear(ImDrawList* list);
    void             ImDrawList_PathLineTo(ImDrawList* list, ImVec2 pos);
    void             ImDrawList_PathLineToMergeDuplicate(ImDrawList* list, ImVec2 pos);
    void             ImDrawList_PathFill(ImDrawList* list, ImU32 col);
    void             ImDrawList_PathStroke(ImDrawList* list, ImU32 col, bool closed, float thickness);
    void             ImDrawList_PathArcTo(ImDrawList* list, ImVec2 centre, float radius, float a_min, float a_max, int num_segments);
    void             ImDrawList_PathArcToFast(ImDrawList* list, ImVec2 centre, float radius, int a_min_of_12, int a_max_of_12); // Use precomputed angles for a 12 steps circle
    void             ImDrawList_PathBezierCurveTo(ImDrawList* list, ImVec2 p1, ImVec2 p2, ImVec2 p3, int num_segments);
    void             ImDrawList_PathRect(ImDrawList* list, ImVec2 rect_min, ImVec2 rect_max, float rounding, int rounding_corners);

    // Channels
    void             ImDrawList_ChannelsSplit(ImDrawList* list, int channels_count);
    void             ImDrawList_ChannelsMerge(ImDrawList* list);
    void             ImDrawList_ChannelsSetCurrent(ImDrawList* list, int channel_index);

    // Advanced
    void             ImDrawList_AddCallback(ImDrawList* list, ImDrawCallback callback, void* callback_data); // Your rendering function must check for 'UserCallback' in ImDrawCmd and call the function instead of rendering triangles.
    void             ImDrawList_AddDrawCmd(ImDrawList* list); // This is useful if you need to forcefully create a new draw call (to allow for dependent rendering / blending). Otherwise primitives are merged into the same draw-call as much as possible

    // Internal helpers
    void             ImDrawList_PrimReserve(ImDrawList* list, int idx_count, int vtx_count);
    void             ImDrawList_PrimRect(ImDrawList* list, ImVec2 a, ImVec2 b, ImU32 col);
    void             ImDrawList_PrimRectUV(ImDrawList* list, ImVec2 a, ImVec2 b, ImVec2 uv_a, ImVec2 uv_b, ImU32 col);
    void             ImDrawList_PrimQuadUV(ImDrawList* list,ImVec2 a, ImVec2 b, ImVec2 c, ImVec2 d, ImVec2 uv_a, ImVec2 uv_b, ImVec2 uv_c, ImVec2 uv_d, ImU32 col);
    void             ImDrawList_PrimWriteVtx(ImDrawList* list, ImVec2 pos, ImVec2 uv, ImU32 col);
    void             ImDrawList_PrimWriteIdx(ImDrawList* list, ImDrawIdx idx);
    void             ImDrawList_PrimVtx(ImDrawList* list, ImVec2 pos, ImVec2 uv, ImU32 col);
    void             ImDrawList_UpdateClipRect(ImDrawList* list);
    void             ImDrawList_UpdateTextureID(ImDrawList* list);

    // Internal Functions

    ImGuiWindow* igGetCurrentWindowRead();
    ImGuiWindow* igGetCurrentWindow();
    ImGuiWindow* igGetParentWindow();

                                  void igItemSize(ImVec2, float text_offset_y = 0.0f);
    pragma(mangle, "igItemSize2") void igItemSize(ImRect, float text_offset_y = 0.0f);

    bool igAddItem(ImRect, ImGuiID*);
}

enum ImGuiWindowFlags
{
    Default                = 0,
    NoTitleBar             = 1 << 0,   // Disable title-bar
    NoResize               = 1 << 1,   // Disable user resizing with the lower-right grip
    NoMove                 = 1 << 2,   // Disable user moving the window
    NoScrollbar            = 1 << 3,   // Disable scrollbars (window can still scroll with mouse or programatically)
    NoScrollWithMouse      = 1 << 4,   // Disable user vertically scrolling with mouse wheel
    NoCollapse             = 1 << 5,   // Disable user collapsing window by double-clicking on it
    AlwaysAutoResize       = 1 << 6,   // Resize every window to its content every frame
    ShowBorders            = 1 << 7,   // Show borders around windows and items
    NoSavedSettings        = 1 << 8,   // Never load/save settings in .ini file
    NoInputs               = 1 << 9,   // Disable catching mouse or keyboard inputs
    MenuBar                = 1 << 10,  // Has a menu-bar
    HorizontalScrollbar    = 1 << 11,  // Allow horizontal scrollbar to appear (off by default). You may use SetNextWindowContentSize(ImVec2(width,0.0f)); prior to calling Begin() to specify width. Read code in imgui_demo in the "Horizontal Scrolling" section.
    NoFocusOnAppearing     = 1 << 12,  // Disable taking focus when transitioning from hidden to visible state
    NoBringToFrontOnFocus  = 1 << 13,  // Disable bringing window to front when taking focus (e.g. clicking on it or programatically giving it focus)
    AlwaysVerticalScrollbar= 1 << 14,  // Always show vertical scrollbar (even if ContentSize.y < Size.y)
    AlwaysHorizontalScrollbar=1<< 15,  // Always show horizontal scrollbar (even if ContentSize.x < Size.x)
    AlwaysUseWindowPadding = 1 << 16,  // Ensure child windows without border uses style.WindowPadding (ignored by default for non-bordered child windows, because more convenient)
    // [Internal]
    ChildWindow            = 1 << 20,  // Don't use! For internal use by BeginChild()
    ChildWindowAutoFitX    = 1 << 21,  // Don't use! For internal use by BeginChild()
    ChildWindowAutoFitY    = 1 << 22,  // Don't use! For internal use by BeginChild()
    ComboBox               = 1 << 23,  // Don't use! For internal use by ComboBox()
    Tooltip                = 1 << 24,  // Don't use! For internal use by BeginTooltip()
    Popup                  = 1 << 25,  // Don't use! For internal use by BeginPopup()
    Modal                  = 1 << 26,  // Don't use! For internal use by BeginPopupModal()
    ChildMenu              = 1 << 27   // Don't use! For internal use by BeginMenu()
}

// Flags for ImGui::InputText()
enum ImGuiInputTextFlags
{
    Default             = 0,        // Default: 0
    CharsDecimal        = 1 << 0,   // Allow 0123456789.+-*/
    CharsHexadecimal    = 1 << 1,   // Allow 0123456789ABCDEFabcdef
    CharsUppercase      = 1 << 2,   // Turn a..z into A..Z
    CharsNoBlank        = 1 << 3,   // Filter out spaces, tabs
    AutoSelectAll       = 1 << 4,   // Select entire text when first taking mouse focus
    EnterReturnsTrue    = 1 << 5,   // Return 'true' when Enter is pressed (as opposed to when the value was modified)
    CallbackCompletion  = 1 << 6,   // Call user function on pressing TAB (for completion handling)
    CallbackHistory     = 1 << 7,   // Call user function on pressing Up/Down arrows (for history handling)
    CallbackAlways      = 1 << 8,   // Call user function every time. User code may query cursor position, modify text buffer.
    CallbackCharFilter  = 1 << 9,   // Call user function to filter character. Modify data->EventChar to replace/filter input, or return 1 to discard character.
    AllowTabInput       = 1 << 10,  // Pressing TAB input a '\t' character into the text field
    CtrlEnterForNewLine = 1 << 11,  // In multi-line mode, allow exiting edition by pressing Enter. Ctrl+Enter to add new line (by default adds new lines with Enter).
    NoHorizontalScroll  = 1 << 12,  // Disable following the cursor horizontally
    AlwaysInsertMode    = 1 << 13,  // Insert mode
    ReadOnly            = 1 << 14,  // Read-only mode
    Password            = 1 << 15,  // Password mode, display all characters as '*'
    // [Internal]
    Multiline           = 1 << 20   // For internal use by InputTextMultiline()
}

// Flags for ImGui::TreeNodeEx(), ImGui::CollapsingHeader*()
enum ImGuiTreeNodeFlags
{
    Default              = 0,
    Selected             = 1 << 0,   // Draw as selected
    Framed               = 1 << 1,   // Full colored frame (e.g. for CollapsingHeader)
    AllowOverlapMode     = 1 << 2,   // Hit testing to allow subsequent widgets to overlap this one
    NoTreePushOnOpen     = 1 << 3,   // Don't do a TreePush() when open (e.g. for CollapsingHeader) = no extra indent nor pushing on ID stack
    NoAutoOpenOnLog      = 1 << 4,   // Don't automatically and temporarily open node when Logging is active (by default logging will automatically open tree nodes)
    DefaultOpen          = 1 << 5,   // Default node to be open
    OpenOnDoubleClick    = 1 << 6,   // Need double-click to open node
    OpenOnArrow          = 1 << 7,   // Only open when clicking on the arrow part. If ImGuiTreeNodeFlags_OpenOnDoubleClick is also set, single-click arrow or double-click all box to open.
    Leaf                 = 1 << 8,   // No collapsing, no arrow (use as a convenience for leaf nodes).
    Bullet               = 1 << 9,   // Display a bullet instead of arrow
    //ImGuITreeNodeFlags_SpanAllAvailWidth  = 1 << 10,  // FIXME: TODO: Extend hit box horizontally even if not framed
    //ImGuiTreeNodeFlags_NoScrollOnOpen     = 1 << 11,  // FIXME: TODO: Disable automatic scroll on TreePop() if node got just open and contents is not visible
    CollapsingHeader     = Framed | NoAutoOpenOnLog
}

// Flags for ImGui::Selectable()
enum ImGuiSelectableFlags
{
    Default            = 0,
    DontClosePopups    = 1 << 0,   // Clicking this don't close parent popup window
    SpanAllColumns     = 1 << 1,   // Selectable frame can span all columns (text will still fit in current column)
    AllowDoubleClick   = 1 << 2    // Generate press events on double clicks too
}

// User fill ImGuiIO.KeyMap[] array with indices into the ImGuiIO.KeysDown[512] array
enum ImGuiKey
{
    Tab,       // for tabbing through fields
    LeftArrow, // for text edit
    RightArrow,// for text edit
    UpArrow,   // for text edit
    DownArrow, // for text edit
    PageUp,
    PageDown,
    Home,      // for text edit
    End,       // for text edit
    Delete,    // for text edit
    Backspace, // for text edit
    Enter,     // for text edit
    Escape,    // for text edit
    A,         // for text edit CTRL+A: select all
    C,         // for text edit CTRL+C: copy
    V,         // for text edit CTRL+V: paste
    X,         // for text edit CTRL+X: cut
    Y,         // for text edit CTRL+Y: redo
    Z,         // for text edit CTRL+Z: undo
    Count
}

// Enumeration for PushStyleColor() / PopStyleColor()
enum ImGuiCol
{
    Text,
    TextDisabled,
    WindowBg,              // Background of normal windows
    ChildWindowBg,         // Background of child windows
    PopupBg,               // Background of popups, menus, tooltips windows
    Border,
    BorderShadow,
    FrameBg,               // Background of checkbox, radio button, plot, slider, text input
    FrameBgHovered,
    FrameBgActive,
    TitleBg,
    TitleBgCollapsed,
    TitleBgActive,
    MenuBarBg,
    ScrollbarBg,
    ScrollbarGrab,
    ScrollbarGrabHovered,
    ScrollbarGrabActive,
    ComboBg,
    CheckMark,
    SliderGrab,
    SliderGrabActive,
    Button,
    ButtonHovered,
    ButtonActive,
    Header,
    HeaderHovered,
    HeaderActive,
    Column,
    ColumnHovered,
    ColumnActive,
    ResizeGrip,
    ResizeGripHovered,
    ResizeGripActive,
    CloseButton,
    CloseButtonHovered,
    CloseButtonActive,
    PlotLines,
    PlotLinesHovered,
    PlotHistogram,
    PlotHistogramHovered,
    TextSelectedBg,
    ModalWindowDarkening,  // darken entire screen when a modal window is active
    Count
}

// Enumeration for PushStyleVar() / PopStyleVar()
// NB: the enum only refers to fields of ImGuiStyle() which makes sense to be pushed/poped in UI code. Feel free to add others.
enum ImGuiStyleVar
{
    Alpha,               // float
    WindowPadding,       // ImVec2
    WindowRounding,      // float
    WindowMinSize,       // ImVec2
    ChildWindowRounding, // float
    FramePadding,        // ImVec2
    FrameRounding,       // float
    ItemSpacing,         // ImVec2
    ItemInnerSpacing,    // ImVec2
    IndentSpacing,       // float
    GrabMinSize          // float
}

enum ImGuiAlign
{
    Left     = 1 << 0,
    Center   = 1 << 1,
    Right    = 1 << 2,
    Top      = 1 << 3,
    VCenter  = 1 << 4,
    Default  = Left | Top
}

// Enumeration for ColorEditMode()
// FIXME-OBSOLETE: Will be replaced by future color/picker api
enum ImGuiColorEditMode
{
    UserSelect = -2,
    UserSelectShowButton = -1,
    RGB = 0,
    HSV = 1,
    HEX = 2
}

// Enumeration for GetMouseCursor()
enum ImGuiMouseCursor
{
    Arrow = 0,
    TextInput,         // When hovering over InputText, etc.
    Move,              // Unused
    ResizeNS,          // Unused
    ResizeEW,          // When hovering over a column
    ResizeNESW,        // Unused
    ResizeNWSE,        // When hovering over the bottom-right corner of a window
    Count_
}

// Condition flags for ImGui::SetWindow***(), SetNextWindow***(), SetNextTreeNode***() functions
// All those functions treat 0 as a shortcut to ImGuiSetCond_Always
enum ImGuiSetCond
{
    Default       = 0,
    Always        = 1 << 0, // Set the variable
    Once          = 1 << 1, // Only set the variable on the first call per runtime session
    FirstUseEver  = 1 << 2, // Only set the variable if the window doesn't exist in the .ini file
    Appearing     = 1 << 3  // Only set the variable if the window is appearing after being inactive (or the first time)
}

struct ImGuiStyle
{
    float       Alpha;                      // Global alpha applies to everything in ImGui
    ImVec2      WindowPadding;              // Padding within a window
    ImVec2      WindowMinSize;              // Minimum window size
    float       WindowRounding;             // Radius of window corners rounding. Set to 0.0f to have rectangular windows
    ImGuiAlign  WindowTitleAlign;           // Alignment for title bar text
    float       ChildWindowRounding;        // Radius of child window corners rounding. Set to 0.0f to have rectangular windows
    ImVec2      FramePadding;               // Padding within a framed rectangle (used by most widgets)
    float       FrameRounding;              // Radius of frame corners rounding. Set to 0.0f to have rectangular frame (used by most widgets).
    ImVec2      ItemSpacing;                // Horizontal and vertical spacing between widgets/lines
    ImVec2      ItemInnerSpacing;           // Horizontal and vertical spacing between within elements of a composed widget (e.g. a slider and its label)
    ImVec2      TouchExtraPadding;          // Expand reactive bounding box for touch-based system where touch position is not accurate enough. Unfortunately we don't sort widgets so priority on overlap will always be given to the first widget. So don't grow this too much!
    float       IndentSpacing;              // Horizontal indentation when e.g. entering a tree node. Generally == (FontSize + FramePadding.x*2).
    float       ColumnsMinSpacing;          // Minimum horizontal spacing between two columns
    float       ScrollbarSize;              // Width of the vertical scrollbar, Height of the horizontal scrollbar
    float       ScrollbarRounding;          // Radius of grab corners for scrollbar
    float       GrabMinSize;                // Minimum width/height of a grab box for slider/scrollbar
    float       GrabRounding;               // Radius of grabs corners rounding. Set to 0.0f to have rectangular slider grabs.
    ImVec2      DisplayWindowPadding;       // Window positions are clamped to be visible within the display area by at least this amount. Only covers regular windows.
    ImVec2      DisplaySafeAreaPadding;     // If you cannot see the edge of your screen (e.g. on a TV) increase the safe area padding. Covers popups/tooltips as well regular windows.
    bool        AntiAliasedLines;           // Enable anti-aliasing on lines/borders. Disable if you are really tight on CPU/GPU.
    bool        AntiAliasedShapes;          // Enable anti-aliasing on filled shapes (rounded rectangles, circles, etc.)
    float       CurveTessellationTol;       // Tessellation tolerance. Decrease for highly tessellated curves (higher quality, more polygons), increase to reduce quality.
    ImVec4[ImGuiCol.Count] Colors;
}

// This is where your app communicate with ImGui. Access via ImGui::GetIO().
// Read 'Programmer guide' section in .cpp file for general usage.
extern(C)
struct ImGuiIO
{
    static      if((void*).sizeof == 4) static assert(this.sizeof == 5044);
    else static if((void*).sizeof == 8) static assert(this.sizeof == 5096);

    //------------------------------------------------------------------
    // Settings (fill once)                 // Default value:
    //------------------------------------------------------------------

    ImVec2              DisplaySize;              // <unset>              // Display size, in pixels. For clamping windows positions.
    float               DeltaTime;                // = 1.0f/60.0f         // Time elapsed since last frame, in seconds.
    float               IniSavingRate;            // = 5.0f               // Maximum time between saving positions/sizes to .ini file, in seconds.
    const(char)*        IniFilename;              // = "imgui.ini"        // Path to .ini file. NULL to disable .ini saving.
    const(char)*        LogFilename;              // = "imgui_log.txt"    // Path to .log file (default parameter to ImGui::LogToFile when no file is specified).
    float               MouseDoubleClickTime;     // = 0.30f              // Time for a double-click, in seconds.
    float               MouseDoubleClickMaxDist;  // = 6.0f               // Distance threshold to stay in to validate a double-click, in pixels.
    float               MouseDragThreshold;       // = 6.0f               // Distance threshold before considering we are dragging
    int[ImGuiKey.Count] KeyMap;                   // <unset>              // Map of indices into the KeysDown[512] entries array
    float               KeyRepeatDelay;           // = 0.250f             // When holding a key/button, time before it starts repeating, in seconds (for buttons in Repeat mode, etc.).
    float               KeyRepeatRate;            // = 0.020f             // When holding a key/button, rate at which it repeats, in seconds.
    void*               UserData;                 // = NULL               // Store your own data for retrieval by callbacks.

    ImFontAtlas*  Fonts;                    // <auto>               // Load and assemble one or more fonts into a single tightly packed texture. Output to Fonts array.
    float         FontGlobalScale;          // = 1.0f               // Global scale all fonts
    bool          FontAllowUserScaling;     // = false              // Allow user scaling text of individual window with CTRL+Wheel.
    ImVec2        DisplayFramebufferScale;  // = (1.0f,1.0f)        // For retina display or other situations where window coordinates are different from framebuffer coordinates. User storage only, presently not used by ImGui.
    ImVec2        DisplayVisibleMin;        // <unset> (0.0f,0.0f)  // If you use DisplaySize as a virtual space larger than your screen, set DisplayVisibleMin/Max to the visible area.
    ImVec2        DisplayVisibleMax;        // <unset> (0.0f,0.0f)  // If the values are the same, we defaults to Min=(0.0f) and Max=DisplaySize

    // Advanced/subtle behaviors
    bool          WordMovementUsesAltKey;   // = defined(__APPLE__) // OS X style: Text editing cursor movement using Alt instead of Ctrl
    bool          ShortcutsUseSuperKey;     // = defined(__APPLE__) // OS X style: Shortcuts using Cmd/Super instead of Ctrl
    bool          DoubleClickSelectsWord;   // = defined(__APPLE__) // OS X style: Double click selects by word instead of selecting whole text
    bool          MultiSelectUsesSuperKey;  // = defined(__APPLE__) // OS X style: Multi-selection in lists uses Cmd/Super instead of Ctrl [unused yet]

    //------------------------------------------------------------------
    // User Functions
    //------------------------------------------------------------------

    // Rendering function, will be called in Render().
    // Alternatively you can keep this to NULL and call GetDrawData() after Render() to get the same pointer.
    // See example applications if you are unsure of how to implement this.
    void function(ImDrawData* data) RenderDrawListsFn;

    // Optional: access OS clipboard
    // (default to use native Win32 clipboard on Windows, otherwise uses a private clipboard. Override to access OS clipboard on other architectures)
    const(char)* function()                  @nogc nothrow GetClipboardTextFn;
    void         function(const(char)* text) @nogc nothrow SetClipboardTextFn;

    // Optional: override memory allocations. MemFreeFn() may be called with a NULL pointer.
    // (default to posix malloc/free)
    void* function(size_t sz) MemAllocFn;
    void  function(void* ptr) MemFreeFn;

    // Optional: notify OS Input Method Editor of the screen position of your cursor for text input position (e.g. when using Japanese/Chinese IME in Windows)
    // (default to use native imm32 api on Windows)
    void function(int x, int y) ImeSetInputScreenPosFn;
    void*                       ImeWindowHandle;            // (Windows) Set this to your HWND to get automatic IME cursor positioning.

    //------------------------------------------------------------------
    // Input - Fill before calling NewFrame()
    //------------------------------------------------------------------

    ImVec2      MousePos;                   // Mouse position, in pixels (set to -1,-1 if no mouse / on another screen, etc.)
    bool[5]     MouseDown;                  // Mouse buttons: left, right, middle + extras. ImGui itself mostly only uses left button (BeginPopupContext** are using right button). Others buttons allows us to track if the mouse is being used by your application + available to user as a convenience via IsMouse** API.
    float       MouseWheel;                 // Mouse wheel: 1 unit scrolls about 5 lines text.
    bool        MouseDrawCursor;            // Request ImGui to draw a mouse cursor for you (if you are on a platform without a mouse cursor).
    bool        KeyCtrl;                    // Keyboard modifier pressed: Control
    bool        KeyShift;                   // Keyboard modifier pressed: Shift
    bool        KeyAlt;                     // Keyboard modifier pressed: Alt
    bool        KeySuper;                   // Keyboard modifier pressed: Cmd/Super/Windows
    bool[512]   KeysDown;                   // Keyboard keys that are pressed (in whatever storage order you naturally have access to keyboard data)
    ImWchar[17] InputCharacters;            // List of characters input (translated by user from keypress+keyboard state). Fill using AddInputCharacter() helper.

    // Functions
    void AddInputCharacter(ImWchar c)                    { ImGuiIO_AddInputCharacter(c); }                // Helper to add a new character into InputCharacters[]
    void AddInputCharactersUTF8(const(char)* utf8_chars) { ImGuiIO_AddInputCharactersUTF8(utf8_chars); }  // Helper to add new characters into InputCharacters[] from an UTF-8 string
    void ClearInputCharacters()                          { ImGuiIO_ClearInputCharacters(); }              // Helper to clear the text input buffer

    //------------------------------------------------------------------
    // Output - Retrieve after calling NewFrame(), you can use them to discard inputs or hide them from the rest of your application
    //------------------------------------------------------------------

    bool        WantCaptureMouse;           // Mouse is hovering a window or widget is active (= ImGui will use your mouse input)
    bool        WantCaptureKeyboard;        // Widget is active (= ImGui will use your keyboard input)
    bool        WantTextInput;              // Some text input widget is active, which will read input characters from the InputCharacters array.
    float       Framerate;                  // Framerate estimation, in frame per second. Rolling average estimation based on IO.DeltaTime over 120 frames
    int         MetricsAllocs;              // Number of active memory allocations
    int         MetricsRenderVertices;      // Vertices output during last call to Render()
    int         MetricsRenderIndices;       // Indices output during last call to Render() = number of triangles * 3
    int         MetricsActiveWindows;       // Number of visible windows (exclude child windows)

    //------------------------------------------------------------------
    // [Internal] ImGui will maintain those fields for you
    //------------------------------------------------------------------

    ImVec2      MousePosPrev;               // Previous mouse position
    ImVec2      MouseDelta;                 // Mouse delta. Note that this is zero if either current or previous position are negative to allow mouse enabling/disabling.
    bool[5]     MouseClicked;               // Mouse button went from !Down to Down
    ImVec2[5]   MouseClickedPos;            // Position at time of clicking
    float[5]    MouseClickedTime;           // Time of last click (used to figure out double-click)
    bool[5]     MouseDoubleClicked;         // Has mouse button been double-clicked?
    bool[5]     MouseReleased;              // Mouse button went from Down to !Down
    bool[5]     MouseDownOwned;             // Track if button was clicked inside a window. We don't request mouse capture from the application if click started outside ImGui bounds.
    float[5]    MouseDownDuration;          // Duration the mouse button has been down (0.0f == just clicked)
    float[5]    MouseDownDurationPrev;      // Previous time the mouse button has been down
    float[5]    MouseDragMaxDistanceSqr;    // Squared maximum distance of how much mouse has traveled from the click point
    float[512]  KeysDownDuration;           // Duration the keyboard key has been down (0.0f == just pressed)
    float[512]  KeysDownDurationPrev;       // Previous duration the key has been down
}

//-----------------------------------------------------------------------------
// Helpers
//-----------------------------------------------------------------------------

// Lightweight std::vector<> like class to avoid dragging dependencies (also: windows implementation of STL with debug enabled is absurdly slow, so let's bypass it so our code runs fast in debug).
// Our implementation does NOT call c++ constructors because we don't use them in ImGui. Don't use this class as a straight std::vector replacement in your code!
struct ImVector(T)
{
    int                         Size;
    int                         Capacity;
    T*                          Data;

    ref T opIndex(size_t i) { return Data[i]; }
    int   opDollar() const  { return Size; }
    T[]   opSlice()         { return Data[0 .. Size]; }

version(none)
{
    alias value_type     = T;
    alias iterator       = value_type*;
    alias const_iterator = const(value_type)*;

    bool                 empty() const                   { return Size == 0; }
    int                  size() const                    { return Size; }
    int                  capacity() const                { return Capacity; }

    ref inout(value_type) opIndex(int i) inout           { assert(i < Size); return Data[i]; }

    void                 clear()                         { if (Data) { Size = Capacity = 0; ImGui.MemFree(Data); Data = null; } }
    iterator             begin()                         { return Data; }
    const_iterator       begin() const                   { return Data; }
    iterator             end()                           { return Data + Size; }
    const_iterator       end() const                     { return Data + Size; }
    ref inout(value_type) front() inout                  { assert(Size > 0); return Data[0]; }
    ref inout(value_type) back() inout                   { assert(Size > 0); return Data[Size-1]; }
    void                 swap(ref ImVector!T rhs)        { int rhs_size = rhs.Size; rhs.Size = Size; Size = rhs_size; int rhs_cap = rhs.Capacity; rhs.Capacity = Capacity; Capacity = rhs_cap; value_type* rhs_data = rhs.Data; rhs.Data = Data; Data = rhs_data; }

    int                  _grow_capacity(int new_size)    { int new_capacity = Capacity ? (Capacity + Capacity/2) : 8; return new_capacity > new_size ? new_capacity : new_size; }

    void                 resize(int new_size)            { if (new_size > Capacity) reserve(_grow_capacity(new_size)); Size = new_size; }
    void                 reserve(int new_capacity)
    {
        if (new_capacity <= Capacity) return;
        T* new_data = cast(value_type*)igMemAlloc(cast(size_t)new_capacity * value_type.sizeof);
        memcpy(new_data, Data, cast(size_t)Size * value_type.sizeof);
        igMemFree(Data);
        Data = new_data;
        Capacity = new_capacity;
    }

    void                 push_back()(auto ref const value_type v) { if (Size == Capacity) reserve(_grow_capacity(Size+1)); Data[Size++] = v; }
    void                 pop_back()                               { assert(Size > 0); Size--; }

    iterator erase(const_iterator it)
    {
        assert(it >= Data && it < Data+Size);
        const ptrdiff_t off = it - Data;
        memmove(Data + off, Data + off + 1, (cast(size_t)Size - cast(size_t)off - 1) * value_type.sizeof);
        Size--;
        return Data + off;
    }

    iterator insert()(const_iterator it, auto ref const value_type v)
    {
        assert(it >= Data && it <= Data+Size);
        const ptrdiff_t off = it - Data;
        if (Size == Capacity) reserve(Capacity ? Capacity * 2 : 4);
        if (off < Size) memmove(Data + off + 1, Data + off, (cast(size_t)Size - cast(size_t)off) * value_type.sizeof);
        Data[off] = v; Size++;
        return Data + off;
    }
}
}

// Helper: Parse and apply text filters. In format "aaaaa[,bbbb][,ccccc]"
struct ImGuiTextFilter
{
    struct TextRange
    {
        const(char)* b;
        const(char)* e;

        const(char)* begin() const   { return b; }
        const(char)* end() const     { return e; }
        bool empty() const           { return b == e; }
        char front() const           { return *b; }
        static bool is_blank(char c) { return c == ' ' || c == '\t'; }
        void trim_blanks()           { while (b < e && is_blank(*b)) b++; while (e > b && is_blank(*(e-1))) e--; }
        void split(char separator, ref ImVector!TextRange output);
    }

    char[256]           InputBuf;
    ImVector!TextRange  Filters;
    int                 CountGrep;

version(none)
{
    void Clear() { InputBuf[0] = 0; Build(); }
    bool Draw(const(char)* label = "Filter (inc,-exc)", float width = 0.0f);    // Helper calling InputText+Build
    bool PassFilter(const(char)* text, const(char)* text_end = null) const;
    bool IsActive() const { return !Filters.empty(); }
    void Build();
}
}

// Helper: Text buffer for logging/accumulating text
struct ImGuiTextBuffer
{
    ImVector!char       Buf;

version(none)
{
    char                opIndex(int i) { return Buf.Data[i]; }
    const(char)*        begin() const { return &Buf.front(); }
    const(char)*        end() const { return &Buf.back(); }      // Buf is zero-terminated, so end() will point on the zero-terminator
    int                 size() const { return Buf.Size - 1; }
    bool                empty() { return Buf.Size <= 1; }
    void                clear() { Buf.clear(); Buf.push_back(0); }
    const(char)*        c_str() const { return Buf.Data; }
    void                append(const(char)* fmt, ...);
    void                appendv(const(char)* fmt, va_list args);
}
}


// Helper: Simple Key->value storage
// - Store collapse state for a tree (Int 0/1)
// - Store color edit options (Int using values in ImGuiColorEditMode enum).
// - Custom user storage for temporary values.
// Typically you don't have to worry about this since a storage is held within each Window.
// Declare your own storage if:
// - You want to manipulate the open/close state of a particular sub-tree in your interface (tree node uses Int 0/1 to store their state).
// - You want to store custom debug data easily without adding or editing structures in your code.
// Types are NOT stored, so it is up to you to make sure your Key don't collide with different types.
struct ImGuiStorage
{
    struct Pair
    {
        ImGuiID key;
        union { int val_i; float val_f; void* val_p; };

        this(ImGuiID _key, int _val_i) { key = _key; val_i = _val_i; }
        this(ImGuiID _key, float _val_f) { key = _key; val_f = _val_f; }
        this(ImGuiID _key, void* _val_p) { key = _key; val_p = _val_p; }
    }

    ImVector!Pair       Data;


version(none)
{
    // - Get***() functions find pair, never add/allocate. Pairs are sorted so a query is O(log N)
    // - Set***() functions find pair, insertion on demand if missing.
    // - Sorted insertion is costly, paid once. A typical frame shouldn't need to insert any new pair.
    void      Clear();
    int       GetInt(ImGuiID key, int default_val = 0) const;
    void      SetInt(ImGuiID key, int val);
    bool      GetBool(ImGuiID key, bool default_val = false) const;
    void      SetBool(ImGuiID key, bool val);
    float     GetFloat(ImGuiID key, float default_val = 0.0f) const;
    void      SetFloat(ImGuiID key, float val);
    void*     GetVoidPtr(ImGuiID key) const; // default_val is NULL
    void      SetVoidPtr(ImGuiID key, void* val);

    // - Get***Ref() functions finds pair, insert on demand if missing, return pointer. Useful if you intend to do Get+Set.
    // - References are only valid until a new value is added to the storage. Calling a Set***() function or a Get***Ref() function invalidates the pointer.
    // - A typical use case where this is convenient:
    //      float* pvar = ImGui::GetFloatRef(key); ImGui::SliderFloat("var", pvar, 0, 100.0f); some_var += *pvar;
    // - You can also use this to quickly create temporary editable values during a session of using Edit&Continue, without restarting your application.
    int*      GetIntRef(ImGuiID key, int default_val = 0);
    bool*     GetBoolRef(ImGuiID key, bool default_val = false);
    float*    GetFloatRef(ImGuiID key, float default_val = 0.0f);
    void**    GetVoidPtrRef(ImGuiID key, void* default_val = null);

    // Use on your own storage if you know only integer are being stored (open/close all tree nodes)
    void      SetAllInt(int val);
}
}


// Shared state of InputText(), passed to callback when a ImGuiInputTextFlags_Callback* flag is used and the corresponding callback is triggered.
struct ImGuiTextEditCallbackData
{
    ImGuiInputTextFlags EventFlag;      // One of ImGuiInputTextFlags_Callback* // Read-only
    ImGuiInputTextFlags Flags;          // What user passed to InputText()      // Read-only
    void*               UserData;       // What user passed to InputText()      // Read-only
    bool                ReadOnly;       // Read-only mode                       // Read-only

    // CharFilter event:
    ImWchar             EventChar;      // Character input                      // Read-write (replace character or set to zero)

    // Completion,History,Always events:
    // If you modify the buffer contents make sure you update 'BufTextLen' and set 'BufDirty' to true.
    ImGuiKey            EventKey;       // Key pressed (Up/Down/TAB)            // Read-only
    char*               Buf;            // Current text buffer                  // Read-write (pointed data only, can't replace the actual pointer)
    int                 BufTextLen;     // Current text length in bytes         // Read-write
    int                 BufSize;        // Maximum text length in bytes         // Read-only
    bool                BufDirty;       // Set if you modify Buf/BufTextLen!!   // Write
    int                 CursorPos;      //                                      // Read-write
    int                 SelectionStart; //                                      // Read-write (== to SelectionEnd when no selection)
    int                 SelectionEnd;   //                                      // Read-write

version(none)
{
    // NB: Helper functions for text manipulation. Calling those function loses selection.
    void    DeleteChars(int pos, int bytes_count);
    void    InsertChars(int pos, const(char)* text, const(char)* text_end = null);
    bool    HasSelection() const { return SelectionStart != SelectionEnd; }
}
}

// Resizing callback data to apply custom constraint. As enabled by SetNextWindowSizeConstraints(). Callback is called during the next Begin().
// NB: For basic min/max size constraint on each axis you don't need to use the callback! The SetNextWindowSizeConstraints() parameters are enough.
struct ImGuiSizeConstraintCallbackData
{
    void*   UserData;       // Read-only.   What user passed to SetNextWindowSizeConstraints()
    ImVec2  Pos;            // Read-only.	Window position, for reference.
    ImVec2  CurrentSize;    // Read-only.	Current window size.
    ImVec2  DesiredSize;    // Read-write.  Desired size, based on user's mouse position. Write to this field to restrain resizing.
}

// ImColor() helper to implicity converts colors to either ImU32 (packed 4x1 byte) or ImVec4 (4x1 float)
// Prefer using IM_COL32() macros if you want a guaranteed compile-time ImU32 for usage with ImDrawList API.
// Avoid storing ImColor! Store either u32 of ImVec4. This is not a full-featured color class.
// None of the ImGui API are using ImColor directly but you can use it as a convenience to pass colors in either ImU32 or ImVec4 formats.
struct ImColor
{
    ImVec4              Value;

version(none)
{
    this(int r, int g, int b, int a = 255)                       { float sc = 1.0f/255.0f; Value.x = cast(float)r * sc; Value.y = cast(float)g * sc; Value.z = cast(float)b * sc; Value.w = cast(float)a * sc; }
    this(ImU32 rgba)                                             { float sc = 1.0f/255.0f; Value.x = cast(float)(rgba&0xFF) * sc; Value.y = cast(float)((rgba>>8)&0xFF) * sc; Value.z = cast(float)((rgba>>16)&0xFF) * sc; Value.w = cast(float)(rgba >> 24) * sc; }
    this(float r, float g, float b, float a = 1.0f)              { Value.x = r; Value.y = g; Value.z = b; Value.w = a; }
    this(ref const ImVec4 col)                                   { Value = col; }
    auto opCast(ImU32)() const                                   { return ImGui.ColorConvertFloat4ToU32(Value); }
    auto opCast(ImVec4)() const                                  { return Value; }

    void    SetHSV(float h, float s, float v, float a = 1.0f){ ImGui.ColorConvertHSVtoRGB(h, s, v, Value.x, Value.y, Value.z); Value.w = a; }

    static ImColor HSV(float h, float s, float v, float a = 1.0f)   { float r,g,b; ImGui.ColorConvertHSVtoRGB(h, s, v, r, g, b); return ImColor(r,g,b,a); }
}
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
struct ImGuiListClipper
{
    float   StartPosY;
    float   ItemsHeight;
    int     ItemsCount, StepNo, DisplayStart, DisplayEnd;

    // items_count:  Use -1 to ignore (you can call Begin later). Use INT_MAX if you don't know how many items you have (in which case the cursor won't be advanced in the final step).
    // items_height: Use -1.0f to be calculated automatically on first step. Otherwise pass in the distance between your items, typically GetTextLineHeightWithSpacing() or GetItemsLineHeightWithSpacing().
    // If you don't specify an items_height, you NEED to call Step(). If you specify items_height you may call the old Begin()/End() api directly, but prefer calling Step().

version(none)
{
    //this(int items_count, float items_height = -1.0f) { Begin(items_count, items_height); } // NB: Begin() initialize every fields (as we allow user to call Begin/End multiple times on a same instance if they want).
    //~this();                                           // Assert if user forgot to call End() or Step() until false.

    bool Step();                                              // Call until it returns false. The DisplayStart/DisplayEnd fields will be set and you can process/draw those items.
    void Begin(int items_count, float items_height = -1.0f);  // Automatically called by constructor if you passed 'items_count' or by Step() in Step 1.
    void End();                                               // Automatically called on the last call of Step() that returns false.
}
}

// Draw callbacks for advanced uses.
// NB- You most likely do NOT need to use draw callbacks just to create your own widget or customized UI rendering (you can poke into the draw list for that)
// Draw callback may be useful for example, A) Change your GPU render state, B) render a complex 3D scene inside a UI element (without an intermediate texture/render target), etc.
// The expected behavior from your rendering function is 'if (cmd.UserCallback != NULL) cmd.UserCallback(parent_list, cmd); else RenderTriangles()'
alias ImDrawCallback = void function(const(ImDrawList)* parent_list, const(ImDrawCmd)* cmd);

// Typically, 1 command = 1 gpu draw call (unless command is a callback)
struct ImDrawCmd
{
    uint            ElemCount;              // Number of indices (multiple of 3) to be rendered as triangles. Vertices are stored in the callee ImDrawList's vtx_buffer[] array, indices in idx_buffer[].
    ImVec4          ClipRect = ImVec4(-8192.0f, -8192.0f, +8192.0f, +8192.0f); // Clipping rectangle (x1, y1, x2, y2)
    ImTextureID     TextureId;              // User-provided texture ID. Set by user in ImfontAtlas::SetTexID() for fonts or passed to Image*() functions. Ignore if never using images or multiple fonts atlas.
    ImDrawCallback  UserCallback;           // If != NULL, call the function instead of rendering the vertices. clip_rect and texture_id will be set normally.
    void*           UserCallbackData;       // The draw callback code can access this.
}

// Vertex index
alias ImDrawIdx = ushort;

// vertex layout
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

// Draw command list
// This is the low-level list of polygons that ImGui functions are filling. At the end of the frame, all command lists are passed to your ImGuiIO::RenderDrawListFn function for rendering.
// At the moment, each ImGui window contains its own ImDrawList but they could potentially be merged in the future.
// If you want to add custom rendering within a window, you can use ImGui::GetWindowDrawList() to access the current draw list and add your own primitives.
// You can interleave normal ImGui:: calls and adding primitives to the current draw list.
// All positions are in screen coordinates (0,0=top-left, 1 pixel per unit). Primitives are always added to the list and not culled (culling is done at render time and at a higher-level by ImGui:: functions).
struct ImDrawList
{
@nogc nothrow:

    // This is what you have to render
    ImVector!ImDrawCmd      CmdBuffer;          // Commands. Typically 1 command = 1 gpu draw call.
    ImVector!ImDrawIdx      IdxBuffer;          // Index buffer. Each command consume ImDrawCmd::ElemCount of those
    ImVector!ImDrawVert     VtxBuffer;          // Vertex buffer.

    // [Internal, used while building lists]
    const(char)*            _OwnerName;         // Pointer to owner window's name (if any) for debugging
    uint                    _VtxCurrentIdx;     // [Internal] == VtxBuffer.Size
    ImDrawVert*             _VtxWritePtr;       // [Internal] point within VtxBuffer.Data after each add command (to avoid using the ImVector<> operators too much)
    ImDrawIdx*              _IdxWritePtr;       // [Internal] point within IdxBuffer.Data after each add command (to avoid using the ImVector<> operators too much)
    ImVector!ImVec4         _ClipRectStack;     // [Internal]
    ImVector!ImTextureID    _TextureIdStack;    // [Internal]
    ImVector!ImVec2         _Path;              // [Internal] current path building
    int                     _ChannelsCurrent;   // [Internal] current channel number (0)
    int                     _ChannelsCount;     // [Internal] number of active channels (1+)
    ImVector!ImDrawChannel  _Channels;          // [Internal] draw channels for columns API (not resized down so _ChannelsCount may be smaller than _Channels.Size)

    void  PushClipRect(ImVec2 clip_rect_min, ImVec2 clip_rect_max, bool intersect_with_current_clip_rect = false) { ImDrawList_PushClipRect(&this, clip_rect_min, clip_rect_max, intersect_with_current_clip_rect); }  // Render-level scissoring. This is passed down to your render function but not used for CPU-side coarse clipping. Prefer using higher-level ImGui::PushClipRect() to affect logic (hit-testing and widget culling)
    void  PushClipRectFullScreen() { ImDrawList_PushClipRectFullScreen(&this); }
    void  PopClipRect()            { ImDrawList_PopClipRect(&this); }
    void  PushTextureID(ImTextureID texture_id) { ImDrawList_PushTextureID(&this, texture_id); }
    void  PopTextureID()                        { ImDrawList_PopTextureID(&this); }

    void  AddLine(ImVec2 a, ImVec2 b, ImU32 col, float thickness = 1.0f)                                                                { ImDrawList_AddLine(&this, a, b, col, thickness); }
    void  AddRect(ImVec2 a, ImVec2 b, ImU32 col, float rounding = 0.0f, int rounding_corners = 0x0F, float thickness = 1.0f)            { ImDrawList_AddRect(&this, a, b, col, rounding, rounding_corners, thickness); }
    void  AddRectFilled(ImVec2 a, ImVec2 b, ImU32 col, float rounding = 0.0f, int rounding_corners = 0x0F)                              { ImDrawList_AddRectFilled(&this, a, b, col, rounding, rounding_corners); }
    void  AddRectFilledMultiColor(ImVec2 a, ImVec2 b, ImU32 col_upr_left, ImU32 col_upr_right, ImU32 col_bot_right, ImU32 col_bot_left) { ImDrawList_AddRectFilledMultiColor(&this, a, b, col_upr_left, col_upr_right, col_bot_right, col_bot_left); }
    void  AddQuad(ImVec2 a, ImVec2 b, ImVec2 c, ImVec2 d, ImU32 col, float thickness = 1.0f)                                            { ImDrawList_AddQuad(&this, a, b, c, d, col, thickness); }
    void  AddQuadFilled(ImVec2 a, ImVec2 b, ImVec2 c, ImVec2 d, ImU32 col)                                                              { ImDrawList_AddQuadFilled(&this, a, b, c, d, col); }
    void  AddTriangle(ImVec2 a, ImVec2 b, ImVec2 c, ImU32 col, float thickness = 1.0f)                                                  { ImDrawList_AddTriangle(&this, a, b, c, col, thickness); }
    void  AddTriangleFilled(ImVec2 a, ImVec2 b, ImVec2 c, ImU32 col)                                                                    { ImDrawList_AddTriangleFilled(&this, a, b, c, col); }
    void  AddCircle(ImVec2 centre, float radius, ImU32 col, int num_segments = 12, float thickness = 1.0f)                              { ImDrawList_AddCircle(&this, centre, radius, col, num_segments, thickness); }
    void  AddCircleFilled(ImVec2 centre, float radius, ImU32 col, int num_segments = 12)                                                { ImDrawList_AddCircleFilled(&this, centre, radius, col, num_segments); }
    void  AddText(ImVec2 pos, ImU32 col, const(char)* text_begin, const(char)* text_end = null)                                         { ImDrawList_AddText(&this, pos, col, text_begin, text_end); }
    void  AddText(const(ImFont)* font, float font_size, ImVec2 pos, ImU32 col, const(char)* text_begin, const(char)* text_end = null, float wrap_width = 0.0f, const(ImVec4)* cpu_fine_clip_rect = null) { ImDrawList_AddTextExt(&this, font, font_size, pos, col, text_begin, text_end, wrap_width, cpu_fine_clip_rect); }
    void  AddImage(ImTextureID user_texture_id, ImVec2 a, ImVec2 b, ImVec2 uv0 = ImVec2(0,0), ImVec2 uv1 = ImVec2(1,1), ImU32 col = 0xFFFFFFFF) { ImDrawList_AddImage(&this, user_texture_id, a, b, uv0, uv1, col); }
    void  AddPolyline(const(ImVec2)* points, int num_points, ImU32 col, bool closed, float thickness, bool anti_aliased)                        { ImDrawList_AddPolyline(&this, points, num_points, col, closed, thickness, anti_aliased); }
    void  AddConvexPolyFilled(const(ImVec2)* points, int num_points, ImU32 col, bool anti_aliased)                                              { ImDrawList_AddConvexPolyFilled(&this, points, num_points, col, anti_aliased); }
    void  AddBezierCurve(ImVec2 pos0, ImVec2 cp0, ImVec2 cp1, ImVec2 pos1, ImU32 col, float thickness, int num_segments = 0)                    { ImDrawList_AddBezierCurve(&this, pos0, cp0, cp1, pos1, col, thickness, num_segments); }

    // Stateful path API, add points then finish with PathFill() or PathStroke()
    void  PathClear()                                                 { ImDrawList_PathClear(&this); }
    void  PathLineTo(ImVec2 pos)                                      { ImDrawList_PathLineTo(&this, pos); }
    void  PathLineToMergeDuplicate(ImVec2 pos)                        { ImDrawList_PathLineToMergeDuplicate(&this, pos); }
    void  PathFill(ImU32 col)                                         { ImDrawList_PathFill(&this, col); }
    void  PathStroke(ImU32 col, bool closed, float thickness = 1.0f)  { ImDrawList_PathStroke(&this, col, closed, thickness); }
    void  PathArcTo(ImVec2 centre, float radius, float a_min, float a_max, int num_segments = 10) { ImDrawList_PathArcTo(&this, centre, radius, a_min, a_max, num_segments); }
    void  PathArcToFast(ImVec2 centre, float radius, int a_min_of_12, int a_max_of_12)            { ImDrawList_PathArcToFast(&this, centre, radius, a_min_of_12, a_max_of_12); } // Use precomputed angles for a 12 steps circle
    void  PathBezierCurveTo(ImVec2 p1, ImVec2 p2, ImVec2 p3, int num_segments = 0)                { ImDrawList_PathBezierCurveTo(&this, p1, p2, p3, num_segments); }
    void  PathRect(ImVec2 rect_min, ImVec2 rect_max, float rounding = 0.0f, int rounding_corners = 0x0F) { ImDrawList_PathRect(&this, rect_min, rect_max, rounding, rounding_corners); }

    // Channels
    // - Use to simulate layers. By switching channels to can render out-of-order (e.g. submit foreground primitives before background primitives)
    // - Use to minimize draw calls (e.g. if going back-and-forth between multiple non-overlapping clipping rectangles, prefer to append into separate channels then merge at the end)
    void  ChannelsSplit(int channels_count)     { ImDrawList_ChannelsSplit(&this, channels_count); }
    void  ChannelsMerge()                       { ImDrawList_ChannelsMerge(&this); }
    void  ChannelsSetCurrent(int channel_index) { ImDrawList_ChannelsSetCurrent(&this, channel_index); }

    // Advanced
    void  AddCallback(ImDrawCallback callback, void* callback_data) { ImDrawList_AddCallback(&this, callback, callback_data); } // Your rendering function must check for 'UserCallback' in ImDrawCmd and call the function instead of rendering triangles.
    void  AddDrawCmd()                                              { ImDrawList_AddDrawCmd(&this); }                           // This is useful if you need to forcefully create a new draw call (to allow for dependent rendering / blending). Otherwise primitives are merged into the same draw-call as much as possible

version(none)
{
    // Internal helpers
    // NB: all primitives needs to be reserved via PrimReserve() beforehand!
    void  Clear();
    void  ClearFreeMemory();
    void  PrimReserve(int idx_count, int vtx_count);
    void  PrimRect(ref const ImVec2 a, ref const ImVec2 b, ImU32 col);      // Axis aligned rectangle (composed of two triangles)
    void  PrimRectUV(ref const ImVec2 a, ref const ImVec2 b, ref const ImVec2 uv_a, ref const ImVec2 uv_b, ImU32 col);
    void  PrimQuadUV(ref const ImVec2 a, ref const ImVec2 b, ref const ImVec2 c, ref const ImVec2 d, ref const ImVec2 uv_a, ref const ImVec2 uv_b, ref const ImVec2 uv_c, ref const ImVec2 uv_d, ImU32 col);
    void  PrimWriteVtx(ref const ImVec2 pos, ref const ImVec2 uv, ImU32 col) { _VtxWritePtr.pos = pos; _VtxWritePtr.uv = uv; _VtxWritePtr.col = col; _VtxWritePtr++; _VtxCurrentIdx++; }
    void  PrimWriteIdx(ImDrawIdx idx)                                        { *_IdxWritePtr = idx; _IdxWritePtr++; }
    void  PrimVtx(ref const ImVec2 pos, ref const ImVec2 uv, ImU32 col)      { PrimWriteIdx(cast(ImDrawIdx)_VtxCurrentIdx); PrimWriteVtx(pos, uv, col); }
    void  UpdateClipRect();
    void  UpdateTextureID();
}
}

// All draw data to render an ImGui frame
struct ImDrawData
{
    bool            Valid;                  // Only valid after Render() is called and before the next NewFrame() is called.
    ImDrawList**    CmdLists;
    int             CmdListsCount;
    int             TotalVtxCount;          // For convenience, sum of all cmd_lists vtx_buffer.Size
    int             TotalIdxCount;          // For convenience, sum of all cmd_lists idx_buffer.Size
}

struct ImFontConfig
{
    void*           FontData;                   //          // TTF data
    int             FontDataSize;               //          // TTF data size
    bool            FontDataOwnedByAtlas;       // true     // TTF data ownership taken by the container ImFontAtlas (will delete memory itself). Set to true
    int             FontNo;                     // 0        // Index of font within TTF file
    float           SizePixels;                 //          // Size in pixels for rasterizer
    int             OversampleH, OversampleV;   // 3, 1     // Rasterize at higher quality for sub-pixel positioning. We don't use sub-pixel positions on the Y axis.
    bool            PixelSnapH;                 // false    // Align every character to pixel boundary (if enabled, set OversampleH/V to 1)
    ImVec2          GlyphExtraSpacing;          // 0, 0     // Extra spacing (in pixels) between glyphs
    const(ImWchar)* GlyphRanges;                //          // Pointer to a user-provided list of Unicode range (2 value per range, values are inclusive, zero-terminated list). THE ARRAY DATA NEEDS TO PERSIST AS LONG AS THE FONT IS ALIVE.
    bool            MergeMode;                  // false    // Merge into previous ImFont, so you can combine multiple inputs font into one ImFont (e.g. ASCII font + icons + Japanese glyphs).
    bool            MergeGlyphCenterV;          // false    // When merging (multiple ImFontInput for one ImFont), vertically center new glyphs instead of aligning their baseline

    // [Internal]
    char[32]        Name;                                   // Name (strictly for debugging)
    ImFont*         DstFont;

}

// Load and rasterize multiple TTF fonts into a same texture.
// Sharing a texture for multiple fonts allows us to reduce the number of draw calls during rendering.
// We also add custom graphic data into the texture that serves for ImGui.
//  1. (Optional) Call AddFont*** functions. If you don't call any, the default font will be loaded for you.
//  2. Call GetTexDataAsAlpha8() or GetTexDataAsRGBA32() to build and retrieve pixels data.
//  3. Upload the pixels data into a texture within your graphics system.
//  4. Call SetTexID(my_tex_id); and pass the pointer/identifier to your texture. This value will be passed back to you during rendering to identify the texture.
//  5. Call ClearTexData() to free textures memory on the heap.
// NB: If you use a 'glyph_ranges' array you need to make sure that your array persist up until the ImFont is cleared. We only copy the pointer, not the data.
struct ImFontAtlas
{

version(none)
{
    ImFont*           AddFont(const(ImFontConfig)* font_cfg);
    ImFont*           AddFontDefault(const(ImFontConfig)* font_cfg = null);
    ImFont*           AddFontFromFileTTF(const(char)* filename, float size_pixels, const(ImFontConfig)* font_cfg = null, const(ImWchar)* glyph_ranges = null);
    ImFont*           AddFontFromMemoryTTF(void* ttf_data, int ttf_size, float size_pixels, const(ImFontConfig)* font_cfg = null, const(ImWchar)* glyph_ranges = null);                                        // Transfer ownership of 'ttf_data' to ImFontAtlas, will be deleted after Build()
    ImFont*           AddFontFromMemoryCompressedTTF(const(void)* compressed_ttf_data, int compressed_ttf_size, float size_pixels, const(ImFontConfig)* font_cfg = null, const(ImWchar)* glyph_ranges = null);  // 'compressed_ttf_data' still owned by caller. Compress with binary_to_compressed_c.cpp
    ImFont*           AddFontFromMemoryCompressedBase85TTF(const(char)* compressed_ttf_data_base85, float size_pixels, const(ImFontConfig)* font_cfg = null, const(ImWchar)* glyph_ranges = null);              // 'compressed_ttf_data_base85' still owned by caller. Compress with binary_to_compressed_c.cpp with -base85 paramaeter
    void              ClearTexData();             // Clear the CPU-side texture data. Saves RAM once the texture has been copied to graphics memory.
    void              ClearInputData();           // Clear the input TTF data (inc sizes, glyph ranges)
    void              ClearFonts();               // Clear the ImGui-side font data (glyphs storage, UV coordinates)
    void              Clear();                    // Clear all
}

    // Retrieve texture data
    // User is in charge of copying the pixels into graphics memory, then call SetTextureUserID()
    // After loading the texture into your graphic system, store your texture handle in 'TexID' (ignore if you aren't using multiple fonts nor images)
    // RGBA32 format is provided for convenience and high compatibility, but note that all RGB pixels are white, so 75% of the memory is wasted.
    // Pitch = Width * BytesPerPixels
    void   GetTexDataAsAlpha8(ubyte** out_pixels, int* out_width, int* out_height, int* out_bytes_per_pixel = null) { ImFontAtlas_GetTexDataAsAlpha8(&this, out_pixels, out_width, out_height, out_bytes_per_pixel); }  // 1 byte per-pixel
    void   GetTexDataAsRGBA32(ubyte** out_pixels, int* out_width, int* out_height, int* out_bytes_per_pixel = null) { ImFontAtlas_GetTexDataAsRGBA32(&this, out_pixels, out_width, out_height, out_bytes_per_pixel); }  // 4 bytes-per-pixel
    void   SetTexID(void* id)  { TexID = id; }

version(none)
{
    // Helpers to retrieve list of common Unicode ranges (2 value per range, values are inclusive, zero-terminated list)
    // NB: Make sure that your string are UTF-8 and NOT in your local code page. See FAQ for details.
    const(ImWchar)*    GetGlyphRangesDefault();    // Basic Latin, Extended Latin
    const(ImWchar)*    GetGlyphRangesKorean();     // Default + Korean characters
    const(ImWchar)*    GetGlyphRangesJapanese();   // Default + Hiragana, Katakana, Half-Width, Selection of 1946 Ideographs
    const(ImWchar)*    GetGlyphRangesChinese();    // Japanese + full set of about 21000 CJK Unified Ideographs
    const(ImWchar)*    GetGlyphRangesCyrillic();   // Default + about 400 Cyrillic characters
}

    // Members
    // (Access texture data via GetTexData*() calls which will setup a default font for you.)
    void*                       TexID;              // User data to refer to the texture once it has been uploaded to user's graphic systems. It ia passed back to you during rendering.
    ubyte*                      TexPixelsAlpha8;    // 1 component per pixel, each component is unsigned 8-bit. Total size = TexWidth * TexHeight
    uint*                       TexPixelsRGBA32;    // 4 component per pixel, each component is unsigned 8-bit. Total size = TexWidth * TexHeight * 4
    int                         TexWidth;           // Texture width calculated during Build().
    int                         TexHeight;          // Texture height calculated during Build().
    int                         TexDesiredWidth;    // Texture width desired by user before Build(). Must be a power-of-two. If have many glyphs your graphics API have texture size restrictions you may want to increase texture width to decrease height.
    ImVec2                      TexUvWhitePixel;    // Texture coordinates to a white pixel
    ImVector!(ImFont*)          Fonts;              // Hold all the fonts returned by AddFont*. Fonts[0] is the default font upon calling ImGui::NewFrame(), use ImGui::PushFont()/PopFont() to change the current font.

}

// Font runtime data and rendering
// ImFontAtlas automatically loads a default embedded font for you when you call GetTexDataAsAlpha8() or GetTexDataAsRGBA32().
struct ImFont
{
    struct Glyph
    {
        ImWchar                 Codepoint;
        float                   XAdvance;
        float                   X0, Y0, X1, Y1;
        float                   U0, V0, U1, V1;     // Texture coordinates
    }

    // Members: Hot ~62/78 bytes
    float                       FontSize;           // <user set>   // Height of characters, set during loading (don't change after loading)
    float                       Scale;              // = 1.f        // Base font scale, multiplied by the per-window font scale which you can adjust with SetFontScale()
    ImVec2                      DisplayOffset;      // = (0.f,1.f)  // Offset font rendering by xx pixels
    ImVector!Glyph              Glyphs;             //              // All glyphs.
    ImVector!float              IndexXAdvance;      //              // Sparse. Glyphs->XAdvance in a directly indexable way (more cache-friendly, for CalcTextSize functions which are often bottleneck in large UI).
    ImVector!short              IndexLookup;        //              // Sparse. Index glyphs by Unicode code-point.
    const(Glyph)*               FallbackGlyph;      // == FindGlyph(FontFallbackChar)
    float                       FallbackXAdvance;   // == FallbackGlyph->XAdvance
    ImWchar                     FallbackChar;       // = '?'        // Replacement glyph if one isn't found. Only set via SetFallbackChar()

    // Members: Cold ~18/26 bytes
    short                       ConfigDataCount;    // ~ 1          // Number of ImFontConfig involved in creating this font. Bigger than 1 when merging multiple font sources into one ImFont.
    ImFontConfig*               ConfigData;         //              // Pointer within ContainerAtlas->ConfigData
    ImFontAtlas*                ContainerAtlas;     //              // What we has been loaded into
    float                       Ascent, Descent;    //              // Ascent: distance from top to bottom of e.g. 'A' [0..FontSize]

version(none)
{
    // Methods
    void              Clear();
    void              BuildLookupTable();
    const(Glyph)*     FindGlyph(ImWchar c) const;
    void              SetFallbackChar(ImWchar c);
    float             GetCharAdvance(ImWchar c) const     { return (cast(int)c < IndexXAdvance.Size) ? IndexXAdvance[cast(int)c] : FallbackXAdvance; }
    bool              IsLoaded() const                    { return ContainerAtlas != null; }

    // 'max_width' stops rendering after a certain width (could be turned into a 2d size). FLT_MAX to disable.
    // 'wrap_width' enable automatic word-wrapping across multiple lines to fit into given width. 0.0f to disable.
    ImVec2            CalcTextSizeA(float size, float max_width, float wrap_width, const(char)* text_begin, const(char)* text_end = null, const(char)** remaining = null) const; // utf8
    const(char)*      CalcWordWrapPositionA(float scale, const(char)* text, const(char)* text_end, float wrap_width) const;
    void              RenderChar(ImDrawList* draw_list, float size, ImVec2 pos, ImU32 col, ushort c) const;
    void              RenderText(ImDrawList* draw_list, float size, ImVec2 pos, ImU32 col, ref const ImVec4 clip_rect, const(char)* text_begin, const(char)* text_end, float wrap_width = 0.0f, bool cpu_fine_clip = false) const;

    // Private
    void              GrowIndex(int new_size);
    void              AddRemapChar(ImWchar dst, ImWchar src, bool overwrite_dst = true); // Makes 'dst' character/glyph points to 'src' character/glyph. Currently needs to be called AFTER fonts have been built.
}
}

// Transient per-window data, reset at the beginning of the frame
// FIXME: That's theory, in practice the delimitation between ImGuiWindow and ImGuiDrawContext is quite tenuous and could be reconsidered.
struct ImGuiDrawContext
{
    ImVec2                  CursorPos;
    ImVec2                  CursorPosPrevLine;
    ImVec2                  CursorStartPos;
    ImVec2                  CursorMaxPos;           // Implicitly calculate the size of our contents, always extending. Saved into window->SizeContents at the end of the frame
    float                   CurrentLineHeight;
    float                   CurrentLineTextBaseOffset;
    float                   PrevLineHeight;
    float                   PrevLineTextBaseOffset;
    float                   LogLinePosY;
    int                     TreeDepth;
    ImGuiID                 LastItemID;
    ImRect                  LastItemRect;
    bool                    LastItemHoveredAndUsable;  // Item rectangle is hovered, and its window is currently interactable with (not blocked by a popup preventing access to the window)
    bool                    LastItemHoveredRect;       // Item rectangle is hovered, but its window may or not be currently interactable with (might be blocked by a popup preventing access to the window)
    bool                    MenuBarAppending;
    float                   MenuBarOffsetX;
    ImVector!(ImGuiWindow*) ChildWindows;
    ImGuiStorage*           StateStorage;
    ImGuiLayoutType         LayoutType;

    // We store the current settings outside of the vectors to increase memory locality (reduce cache misses). The vectors are rarely modified. Also it allows us to not heap allocate for short-lived windows which are not using those settings.
    float                   ItemWidth;              // == ItemWidthStack.back(). 0.0: default, >0.0: width in pixels, <0.0: align xx pixels to the right of window
    float                   TextWrapPos;            // == TextWrapPosStack.back() [empty == -1.0f]
    bool                    AllowKeyboardFocus;     // == AllowKeyboardFocusStack.back() [empty == true]
    bool                    ButtonRepeat;           // == ButtonRepeatStack.back() [empty == false]
    ImVector!float          ItemWidthStack;
    ImVector!float          TextWrapPosStack;
    ImVector!bool           AllowKeyboardFocusStack;
    ImVector!bool           ButtonRepeatStack;
    ImVector!ImGuiGroupData GroupStack;
    ImGuiColorEditMode      ColorEditMode;
    int[6]                  StackSizesBackup;       // Store size of various stacks for asserting

    float                   IndentX;                // Indentation / start position from left of window (increased by TreePush/TreePop, etc.)
    float                   ColumnsOffsetX;         // Offset to the current column (if ColumnsCurrent > 0). FIXME: This and the above should be a stack to allow use cases like Tree->Column->Tree. Need revamp columns API.
    int                     ColumnsCurrent;
    int                     ColumnsCount;
    float                   ColumnsMinX;
    float                   ColumnsMaxX;
    float                   ColumnsStartPosY;
    float                   ColumnsCellMinY;
    float                   ColumnsCellMaxY;
    bool                    ColumnsShowBorders;
    ImGuiID                 ColumnsSetID;
    ImVector!ImGuiColumnData ColumnsData;
}

// FIXME: this is in development, not exposed/functional as a generic feature yet.
enum ImGuiLayoutType
{
    Vertical,
    Horizontal,
}

struct ImGuiGroupData
{
    ImVec2      BackupCursorPos;
    ImVec2      BackupCursorMaxPos;
    float       BackupIndentX;
    float       BackupCurrentLineHeight;
    float       BackupCurrentLineTextBaseOffset;
    float       BackupLogLinePosY;
    bool        AdvanceCursor;
}

// Per column data for Columns()
struct ImGuiColumnData
{
    float       OffsetNorm;     // Column start offset, normalized 0.0 (far left) -> 1.0 (far right)
    //float     IndentX;
}

// Simple column measurement currently used for MenuItem() only. This is very short-sighted/throw-away code and NOT a generic helper.
struct ImGuiSimpleColumns
{
    int         Count;
    float       Spacing;
    float       Width, NextWidth;
    float[8]    Pos;
    float[8]    NextWidths;
}

// Windows data
struct ImGuiWindow
{
    char*                   Name;
    ImGuiID                 ID;                                 // == ImHash(Name)
    ImGuiWindowFlags        Flags;                              // See enum ImGuiWindowFlags_
    int                     IndexWithinParent;                  // Order within immediate parent window, if we are a child window. Otherwise 0.
    ImVec2                  PosFloat;
    ImVec2                  Pos;                                // Position rounded-up to nearest pixel
    ImVec2                  Size;                               // Current size (==SizeFull or collapsed title bar size)
    ImVec2                  SizeFull;                           // Size when non collapsed
    ImVec2                  SizeContents;                       // Size of contents (== extents reach of the drawing cursor) from previous frame
    ImVec2                  SizeContentsExplicit;               // Size of contents explicitly set by the user via SetNextWindowContentSize()
    ImRect                  ContentsRegionRect;                 // Maximum visible content position in window coordinates. ~~ (SizeContentsExplicit ? SizeContentsExplicit : Size - ScrollbarSizes) - CursorStartPos, per axis
    ImVec2                  WindowPadding;                      // Window padding at the time of begin. We need to lock it, in particular manipulation of the ShowBorder would have an effect
    ImGuiID                 MoveID;                             // == window->GetID("#MOVE")
    ImVec2                  Scroll;
    ImVec2                  ScrollTarget;                       // target scroll position. stored as cursor position with scrolling canceled out, so the highest point is always 0.0f. (FLT_MAX for no change)
    ImVec2                  ScrollTargetCenterRatio;            // 0.0f = scroll so that target position is at top, 0.5f = scroll so that target position is centered
    bool                    ScrollbarX, ScrollbarY;
    ImVec2                  ScrollbarSizes;
    float                   BorderSize;
    bool                    Active;                             // Set to true on Begin()
    bool                    WasActive;
    bool                    Accessed;                           // Set to true when any widget access the current window
    bool                    Collapsed;                          // Set when collapsing window to become only title-bar
    bool                    SkipItems;                          // == Visible && !Collapsed
    int                     BeginCount;                         // Number of Begin() during the current frame (generally 0 or 1, 1+ if appending via multiple Begin/End pairs)
    ImGuiID                 PopupID;                            // ID in the popup stack when this window is used as a popup/menu (because we use generic Name/ID for recycling)
    int                     AutoFitFramesX, AutoFitFramesY;
    bool                    AutoFitOnlyGrows;
    int                     AutoPosLastDirection;
    int                     HiddenFrames;
    int                     SetWindowPosAllowFlags;             // bit ImGuiSetCond_*** specify if SetWindowPos() call will succeed with this particular flag.
    int                     SetWindowSizeAllowFlags;            // bit ImGuiSetCond_*** specify if SetWindowSize() call will succeed with this particular flag.
    int                     SetWindowCollapsedAllowFlags;       // bit ImGuiSetCond_*** specify if SetWindowCollapsed() call will succeed with this particular flag.
    bool                    SetWindowPosCenterWanted;

    ImGuiDrawContext        DC;                                 // Temporary per-window data, reset at the beginning of the frame
    ImVector!ImGuiID        IDStack;                            // ID stack. ID are hashes seeded with the value at the top of the stack
    ImRect                  ClipRect;                           // = DrawList->clip_rect_stack.back(). Scissoring / clipping rectangle. x1, y1, x2, y2.
    ImRect                  WindowRectClipped;                  // = WindowRect just after setup in Begin(). == window->Rect() for root window.
    int                     LastFrameActive;
    float                   ItemWidthDefault;
    ImGuiSimpleColumns      MenuColumns;                        // Simplified columns storage for menu items
    ImGuiStorage            StateStorage;
    float                   FontWindowScale;                    // Scale multiplier per-window
    ImDrawList*             DrawList;
    ImGuiWindow*            RootWindow;                         // If we are a child window, this is pointing to the first non-child parent window. Else point to ourself.
    ImGuiWindow*            RootNonPopupWindow;                 // If we are a child window, this is pointing to the first non-child non-popup parent window. Else point to ourself.
    ImGuiWindow*            ParentWindow;                       // If we are a child window, this is pointing to our parent window. Else point to NULL.

    // Focus
    int                     FocusIdxAllCounter;                 // Start at -1 and increase as assigned via FocusItemRegister()
    int                     FocusIdxTabCounter;                 // (same, but only count widgets which you can Tab through)
    int                     FocusIdxAllRequestCurrent;          // Item being requested for focus
    int                     FocusIdxTabRequestCurrent;          // Tab-able item being requested for focus
    int                     FocusIdxAllRequestNext;             // Item being requested for focus, for next update (relies on layout to be stable between the frame pressing TAB and the next frame)
    int                     FocusIdxTabRequestNext;             // "
}

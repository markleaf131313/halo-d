
module ImGuiC;

import core.stdc.stdarg : va_list, va_start, va_end;
public import ImGui;

bool igInputShort(const(char)* label, short* v, short step = 1, short step_fast = 100, ImGuiInputTextFlags extra_flags = 0)
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

// Context creation and access
// All contexts share a same ImFontAtlas by default. If you want different font atlas, you can new() them and overwrite the GetIO().Fonts variable of an ImGui context.
// All those functions are not reliant on the current context.
ImGuiContext* igCreateContext(ImFontAtlas* shared_font_atlas = null) { return CreateContext(shared_font_atlas); }
void          igDestroyContext(ImGuiContext* ctx = null) { DestroyContext(ctx); }
ImGuiContext* igGetCurrentContext() { return GetCurrentContext(); }
void          igSetCurrentContext(ImGuiContext* ctx) { SetCurrentContext(ctx); }
bool          igDebugCheckVersionAndDataLayout(const(char)* version_str, size_t sz_io, size_t sz_style, size_t sz_vec2, size_t sz_vec4, size_t sz_drawvert) { return DebugCheckVersionAndDataLayout(version_str, sz_io, sz_style, sz_vec2, sz_vec4, sz_drawvert); }

// Main
ImGuiIO*      igGetIO()         { return &GetIO(); }
ImGuiStyle*   igGetStyle()      { return &GetStyle(); }
void          igNewFrame()      { NewFrame(); }
void          igRender()        { Render(); }
ImDrawData*   igGetDrawData()   { return GetDrawData(); }
void          igEndFrame()      { EndFrame(); }

// Demo, Debug, Information
void          igShowDemoWindow(bool* p_open = null)      { ShowDemoWindow(p_open); }
void          igShowMetricsWindow(bool* p_open = null)   { ShowMetricsWindow(p_open); }
void          igShowStyleEditor(ImGuiStyle* ref_ = null) { ShowStyleEditor(ref_); }
bool          igShowStyleSelector(const(char)* label)    { return ShowStyleSelector(label); }
void          igShowFontSelector(const(char)* label)     { ShowFontSelector(label); }
void          igShowUserGuide()                          { ShowUserGuide(); }
const(char)*  igGetVersion()                             { return GetVersion(); }

// Styles
void          igStyleColorsDark(ImGuiStyle* dst = null)    { StyleColorsDark(dst); }
void          igStyleColorsClassic(ImGuiStyle* dst = null) { StyleColorsClassic(dst); }
void          igStyleColorsLight(ImGuiStyle* dst = null)   { StyleColorsLight(dst); }

// Windows
// (Begin = push window to the stack and start appending to it. End = pop window from the stack. You may append multiple times to the same window during the same frame)
// Begin()/BeginChild() return false to indicate the window being collapsed or fully clipped, so you may early out and omit submitting anything to the window.
// You need to always call a matching End()/EndChild() for a Begin()/BeginChild() call, regardless of its return value (this is due to legacy reason and is inconsistent with BeginMenu/EndMenu, BeginPopup/EndPopup and other functions where the End call should only be called if the corresponding Begin function returned true.)
// Passing 'bool* p_open != null' shows a close widget in the upper-right corner of the window, which when clicking will set the boolean to false.
// Use child windows to introduce independent scrolling/clipping regions within a host window. Child windows can embed their own child.
bool          igBegin(const(char)* name, bool* p_open = null, ImGuiWindowFlags flags = 0)                                   { return Begin(name, p_open, flags); }
void          igEnd()                                                                                                       { End(); }
bool          igBeginChild(const(char)* str_id, ImVec2 size = ImVec2(0,0), bool border = false, ImGuiWindowFlags flags = 0) { return BeginChild(str_id, size, border, flags); }
bool          igBeginChild(ImGuiID id, ImVec2 size = ImVec2(0,0), bool border = false, ImGuiWindowFlags flags = 0)          { return BeginChild(id, size, border, flags); }
void          igEndChild()                                                                                                  { EndChild(); }

bool          igIsWindowAppearing() { return IsWindowAppearing(); }
bool          igIsWindowCollapsed() { return IsWindowCollapsed(); }
bool          igIsWindowFocused(ImGuiFocusedFlags flags = 0) { return IsWindowFocused(flags); }
bool          igIsWindowHovered(ImGuiHoveredFlags flags = 0) { return IsWindowHovered(flags); }
ImDrawList*   igGetWindowDrawList()           { return GetWindowDrawList(); }
ImVec2        igGetWindowPos()                { return GetWindowPos(); }
ImVec2        igGetWindowSize()               { return GetWindowSize(); }
float         igGetWindowWidth()              { return GetWindowWidth(); }
float         igGetWindowHeight()             { return GetWindowHeight(); }
ImVec2        igGetContentRegionMax()         { return GetContentRegionMax(); }
ImVec2        igGetContentRegionAvail()       { return GetContentRegionAvail(); }
float         igGetContentRegionAvailWidth()  { return GetContentRegionAvailWidth(); }
ImVec2        igGetWindowContentRegionMin()   { return GetWindowContentRegionMin(); }
ImVec2        igGetWindowContentRegionMax()   { return GetWindowContentRegionMax(); }
float         igGetWindowContentRegionWidth() { return GetWindowContentRegionWidth(); }

void          igSetNextWindowPos(ImVec2 pos, ImGuiCond cond = 0, ImVec2 pivot = ImVec2(0,0))                                                                       { SetNextWindowPos(pos, cond, pivot); }
void          igSetNextWindowSize(ImVec2 size, ImGuiCond cond = 0)                                                                                                 { SetNextWindowSize(size, cond); }
void          igSetNextWindowSizeConstraints(ImVec2 size_min, ImVec2 size_max, ImGuiSizeCallback custom_callback = null, void* custom_callback_data = null)        { SetNextWindowSizeConstraints(size_min, size_max, custom_callback, custom_callback_data); }
void          igSetNextWindowContentSize(ImVec2 size)                                                                                                              { SetNextWindowContentSize(size); }
void          igSetNextWindowCollapsed(bool collapsed, ImGuiCond cond = 0)                                                                                         { SetNextWindowCollapsed(collapsed, cond); }
void          igSetNextWindowFocus()                                                                                                                               { SetNextWindowFocus(); }
void          igSetNextWindowBgAlpha(float alpha)                                                                                                                  { SetNextWindowBgAlpha(alpha); }
void          igSetWindowPos(ImVec2 pos, ImGuiCond cond = 0)                                                                                                       { SetWindowPos(pos, cond); }
void          igSetWindowSize(ImVec2 size, ImGuiCond cond = 0)                                                                                                     { SetWindowSize(size, cond); }
void          igSetWindowCollapsed(bool collapsed, ImGuiCond cond = 0)                                                                                             { SetWindowCollapsed(collapsed, cond); }
void          igSetWindowFocus()                                                                                                                                   { SetWindowFocus(); }
void          igSetWindowFontScale(float scale)                                                                                                                    { SetWindowFontScale(scale); }
void          igSetWindowPos(const(char)* name, ImVec2 pos, ImGuiCond cond = 0)                                                                                    { SetWindowPos(name, pos, cond); }
void          igSetWindowSize(const(char)* name, ImVec2 size, ImGuiCond cond = 0)                                                                                  { SetWindowSize(name, size, cond); }
void          igSetWindowCollapsed(const(char)* name, bool collapsed, ImGuiCond cond = 0)                                                                          { SetWindowCollapsed(name, collapsed, cond); }
void          igSetWindowFocus(const(char)* name)                                                                                                                  { SetWindowFocus(name); }

// Windows Scrolling
float         igGetScrollX()                                           { return GetScrollX(); }
float         igGetScrollY()                                           { return GetScrollY(); }
float         igGetScrollMaxX()                                        { return GetScrollMaxX(); }
float         igGetScrollMaxY()                                        { return GetScrollMaxY(); }
void          igSetScrollX(float scroll_x)                             { SetScrollX(scroll_x); }
void          igSetScrollY(float scroll_y)                             { SetScrollY(scroll_y); }
void          igSetScrollHere(float center_y_ratio = 0.5f)                  { SetScrollHere(center_y_ratio); }
void          igSetScrollFromPosY(float pos_y, float center_y_ratio = 0.5f) { SetScrollFromPosY(pos_y, center_y_ratio); }

// Parameters stacks (shared)
void          igPushFont(ImFont* font)                      { PushFont(font); }
void          igPopFont()                                   { PopFont(); }
void          igPushStyleColor(ImGuiCol idx, ImU32 col)     { PushStyleColor(idx, col); }
void          igPushStyleColor(ImGuiCol idx, ImVec4 col)    { PushStyleColor(idx, col); }
void          igPopStyleColor(int count = 1)                { PopStyleColor(count); }
void          igPushStyleVar(ImGuiStyleVar idx, float val)  { PushStyleVar(idx, val); }
void          igPushStyleVar(ImGuiStyleVar idx, ImVec2 val) { PushStyleVar(idx, val); }
void          igPopStyleVar(int count = 1)                  { PopStyleVar(count); }
ImVec4        igGetStyleColorVec4(ImGuiCol idx)             { return GetStyleColorVec4(idx); }
ImFont*       igGetFont()                                   { return GetFont(); }
float         igGetFontSize()                               { return GetFontSize(); }
ImVec2        igGetFontTexUvWhitePixel()                    { return GetFontTexUvWhitePixel(); }
ImU32         igGetColorU32(ImGuiCol idx, float alpha_mul = 1.0f) { return GetColorU32(idx, alpha_mul); }
ImU32         igGetColorU32(ImVec4 col)                     { return GetColorU32(col); }
ImU32         igGetColorU32(ImU32 col)                      { return GetColorU32(col); }

// Parameters stacks (current window)
void          igPushItemWidth(float item_width)             { PushItemWidth(item_width); }
void          igPopItemWidth()                              { PopItemWidth(); }
float         igCalcItemWidth()                             { return CalcItemWidth(); }
void          igPushTextWrapPos(float wrap_pos_x = 0.0f)    { PushTextWrapPos(wrap_pos_x); }
void          igPopTextWrapPos()                            { PopTextWrapPos(); }
void          igPushAllowKeyboardFocus(bool allow_keyboard_focus) { PushAllowKeyboardFocus(allow_keyboard_focus); }
void          igPopAllowKeyboardFocus()                     { PopAllowKeyboardFocus(); }
void          igPushButtonRepeat(bool repeat)               { PushButtonRepeat(repeat); }
void          igPopButtonRepeat()                           { PopButtonRepeat(); }

// Cursor / Layout
void          igSeparator()                                           { Separator(); }
void          igSameLine(float pos_x = 0.0f, float spacing_w = -1.0f) { SameLine(pos_x, spacing_w); }
void          igNewLine()                                             { NewLine(); }
void          igSpacing()                                             { Spacing(); }
void          igDummy(ImVec2 size)                                    { Dummy(size); }
void          igIndent(float indent_w = 0.0f)                         { Indent(indent_w); }
void          igUnindent(float indent_w = 0.0f)                       { Unindent(indent_w); }
void          igBeginGroup()                                          { BeginGroup(); }
void          igEndGroup()                                            { EndGroup(); }
ImVec2        igGetCursorPos()                   { return GetCursorPos(); }
float         igGetCursorPosX()                  { return GetCursorPosX(); }
float         igGetCursorPosY()                  { return GetCursorPosY(); }
void          igSetCursorPos(ImVec2 local_pos)   { return SetCursorPos(local_pos); }
void          igSetCursorPosX(float x)           { return SetCursorPosX(x); }
void          igSetCursorPosY(float y)           { return SetCursorPosY(y); }
ImVec2        igGetCursorStartPos()              { return GetCursorStartPos(); }
ImVec2        igGetCursorScreenPos()             { return GetCursorScreenPos(); }
void          igSetCursorScreenPos(ImVec2 screen_pos) { return SetCursorScreenPos(screen_pos); }
void          igAlignTextToFramePadding()        { return AlignTextToFramePadding(); }
float         igGetTextLineHeight()              { return GetTextLineHeight(); }
float         igGetTextLineHeightWithSpacing()   { return GetTextLineHeightWithSpacing(); }
float         igGetFrameHeight()                 { return GetFrameHeight(); }
float         igGetFrameHeightWithSpacing()      { return GetFrameHeightWithSpacing(); }

// ID stack/scopes
// Read the FAQ for more details about how ID are handled in dear imgui. If you are creating widgets in a loop you most
// likely want to push a unique identifier (e.g. object pointer, loop index) to uniquely differentiate them.
// You can also use the "##foobar" syntax within widget label to distinguish them from each others.
// In this header file we use the "label"/"name" terminology to denote a string that will be displayed and used as an ID,
// whereas "str_id" denote a string that is only used as an ID and not aimed to be displayed.
void          igPushID(const(char)* str_id)                { PushID(str_id); }
void          igPushID(const(char)* str_id_begin, const(char)* str_id_end) { PushID(str_id_begin, str_id_end); }
void          igPushID(const(void)* ptr_id)                { PushID(ptr_id); }
void          igPushID(int int_id)                         { PushID(int_id); }
void          igPopID()                                    { PopID(); }
ImGuiID       igGetID(const(char)* str_id)                                { return GetID(str_id); }
ImGuiID       igGetID(const(char)* str_id_begin, const(char)* str_id_end) { return GetID(str_id_begin, str_id_end); }
ImGuiID       igGetID(const(void)* ptr_id)                                { return GetID(ptr_id); }

// Widgets: Text
void          igTextUnformatted(const(char)* text, const(char)* text_end = null) { TextUnformatted(text, text_end); }

extern(C++)
{
void          igText(const(char)* fmt, ...)                          { va_list args; va_start(args, fmt); TextV(fmt, args); va_end(args); }
void          igTextColored(ImVec4 col, const(char)* fmt, ...)       { va_list args; va_start(args, fmt); TextColoredV(col, fmt, args); va_end(args); }
void          igTextDisabled(const(char)* fmt, ...)                  { va_list args; va_start(args, fmt); TextDisabledV(fmt, args); va_end(args); }
void          igTextWrapped(const(char)* fmt, ...)                   { va_list args; va_start(args, fmt); TextWrappedV(fmt, args); va_end(args); }
void          igLabelText(const(char)* label, const(char)* fmt, ...) { va_list args; va_start(args, fmt); LabelTextV(label, fmt, args); va_end(args); }
void          igBulletText(const(char)* fmt, ...)                    { va_list args; va_start(args, fmt); BulletTextV(fmt, args); va_end(args); }
}

void          igTextV(const(char)* fmt, va_list args)                          { TextV(fmt, args); }
void          igTextColoredV(ImVec4 col, const char* fmt, va_list args)        { TextColoredV(col, fmt, args); }
void          igTextDisabledV(const(char)* fmt, va_list args)                  { TextDisabledV(fmt, args); }
void          igTextWrappedV(const(char)* fmt, va_list args)                   { TextWrappedV(fmt, args); }
void          igLabelTextV(const(char)* label, const(char)* fmt, va_list args) { LabelTextV(label, fmt, args); }
void          igBulletTextV(const(char)* fmt, va_list args)                    { BulletTextV(fmt, args); }

// Widgets: Main
bool          igButton(const(char)* label, ImVec2 size = ImVec2(0,0)) { return Button(label, size); }
bool          igSmallButton(const(char)* label)                { return SmallButton(label); }
bool          igArrowButton(const(char)* str_id, ImGuiDir dir) { return ArrowButton(str_id, dir); }
bool          igInvisibleButton(const(char)* str_id, ImVec2 size) { return InvisibleButton(str_id, size); }
void          igImage(ImTextureID user_texture_id, ImVec2 size, ImVec2 uv0 = ImVec2(0,0), ImVec2 uv1 = ImVec2(1,1), ImVec4 tint_col = ImVec4(1,1,1,1), ImVec4 border_col = ImVec4(0,0,0,0)) { return Image(user_texture_id, size, uv0, uv1, tint_col, border_col); }
bool          igImageButton(ImTextureID user_texture_id, ImVec2 size, ImVec2 uv0 = ImVec2(0,0), ImVec2 uv1 = ImVec2(1,1), int frame_padding = -1, ImVec4 bg_col = ImVec4(0,0,0,0), ImVec4 tint_col = ImVec4(1,1,1,1)) { return ImageButton(user_texture_id, size, uv0, uv1, frame_padding, bg_col, tint_col); }
bool          igCheckbox(const(char)* label, bool* v)                            { return Checkbox(label, v); }
bool          igCheckboxFlags(const(char)* label, uint* flags, uint flags_value) { return CheckboxFlags(label, flags, flags_value); }
bool          igRadioButton(const(char)* label, bool active)                     { return RadioButton(label, active); }
bool          igRadioButton(const(char)* label, int* v, int v_button)            { return RadioButton(label, v, v_button); }
void          igPlotLines(const(char)* label, const(float)* values, int values_count, int values_offset = 0, const(char)* overlay_text = null, float scale_min = float.max, float scale_max = float.max, ImVec2 graph_size = ImVec2(0,0), int stride = float.sizeof)        { PlotLines(label, values, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size, stride); }
void          igPlotLines(const(char)* label, ImPlotDataGetterCallback values_getter, void* data, int values_count, int values_offset = 0, const(char)* overlay_text = null, float scale_min = float.max, float scale_max = float.max, ImVec2 graph_size = ImVec2(0,0))     { PlotLines(label, values_getter, data, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size); }
void          igPlotHistogram(const(char)* label, const(float)* values, int values_count, int values_offset = 0, const(char)* overlay_text = null, float scale_min = float.max, float scale_max = float.max, ImVec2 graph_size = ImVec2(0,0), int stride = float.sizeof)    { PlotHistogram(label, values, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size, stride); }
void          igPlotHistogram(const(char)* label, ImPlotDataGetterCallback values_getter, void* data, int values_count, int values_offset = 0, const(char)* overlay_text = null, float scale_min = float.max, float scale_max = float.max, ImVec2 graph_size = ImVec2(0,0)) { PlotHistogram(label, values_getter, data, values_count, values_offset, overlay_text, scale_min, scale_max, graph_size); }
void          igProgressBar(float fraction, ImVec2 size_arg = ImVec2(-1,0), const(char)* overlay = null) { ProgressBar(fraction, size_arg, overlay); }
void          igBullet();                                                       // draw a small circle and keep the cursor on the same line. advance cursor x position by GetTreeNodeToLabelSpacing(), same distance that TreeNode() uses

// Widgets: Combo Box
// The new BeginCombo()/EndCombo() api allows you to manage your contents and selection state however you want it.
// The old Combo() api are helpers over BeginCombo()/EndCombo() which are kept available for convenience purpose.
bool          igBeginCombo(const(char)* label, const(char)* preview_value, ImGuiComboFlags flags = 0) { return BeginCombo(label, preview_value, flags); }
void          igEndCombo() { EndCombo(); }
bool          igCombo(const(char)* label, int* current_item, const(char**) items, int items_count, int popup_max_height_in_items = -1)  { return Combo(label, current_item, items, items_count, popup_max_height_in_items); }
bool          igCombo(const(char)* label, int* current_item, const(char)* items_separated_by_zeros, int popup_max_height_in_items = -1) { return Combo(label, current_item, items_separated_by_zeros, popup_max_height_in_items); }
bool          igCombo(const(char)* label, int* current_item, ImComboGetterCallback items_getter, void* data, int items_count, int popup_max_height_in_items = -1) { return Combo(label, current_item, items_getter, data, items_count, popup_max_height_in_items); }

// Widgets: Drags (tip: ctrl+click on a drag box to input with keyboard. manually input values aren't clamped, can go off-bounds)
// For all the Float2/Float3/Float4/Int2/Int3/Int4 versions of every functions, note that a 'float v[X]' function argument is the same as 'float* v', the array syntax is just a way to document the number of elements that are expected to be accessible. You can pass address of your first element out of a contiguous set, e.g. &myvector.x
// Adjust format string to decorate the value with a prefix, a suffix, or adapt the editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs; "Biscuit: %.0f" -> Biscuit: 1; etc.
// Speed are per-pixel of mouse movement (v_speed=0.2f: mouse needs to move by 5 pixels to increase value by 1). For gamepad/keyboard navigation, minimum speed is Max(v_speed, minimum_step_at_given_precision).
bool          igDragFloat (const(char)* label, float* v, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* format = "%.3f", float power = 1.0f) { return DragFloat (label, v, v_speed, v_min, v_max, format, power); }
bool          igDragFloat2(const(char)* label, float* v, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* format = "%.3f", float power = 1.0f) { return DragFloat2(label, v, v_speed, v_min, v_max, format, power); }
bool          igDragFloat3(const(char)* label, float* v, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* format = "%.3f", float power = 1.0f) { return DragFloat3(label, v, v_speed, v_min, v_max, format, power); }
bool          igDragFloat4(const(char)* label, float* v, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* format = "%.3f", float power = 1.0f) { return DragFloat4(label, v, v_speed, v_min, v_max, format, power); }
bool          igDragFloatRange2(const(char)* label, float* v_current_min, float* v_current_max, float v_speed = 1.0f, float v_min = 0.0f, float v_max = 0.0f, const(char)* format = "%.3f", const(char)* format_max = null, float power = 1.0f) { return DragFloatRange2(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max, power); }
bool          igDragInt (const(char)* label, int* v, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* format = "%d") { return DragInt (label, v, v_speed, v_min, v_max, format); }
bool          igDragInt2(const(char)* label, int* v, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* format = "%d") { return DragInt2(label, v, v_speed, v_min, v_max, format); }
bool          igDragInt3(const(char)* label, int* v, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* format = "%d") { return DragInt3(label, v, v_speed, v_min, v_max, format); }
bool          igDragInt4(const(char)* label, int* v, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* format = "%d") { return DragInt4(label, v, v_speed, v_min, v_max, format); }
bool          igDragIntRange2(const(char)* label, int* v_current_min, int* v_current_max, float v_speed = 1.0f, int v_min = 0, int v_max = 0, const(char)* format = "%d", const(char)* format_max = null) { return DragIntRange2(label, v_current_min, v_current_max, v_speed, v_min, v_max, format, format_max); }
bool          igDragScalar(const(char)* label, ImGuiDataType data_type, void* v, float v_speed, const(void)* v_min = null, const(void)* v_max = null, const(char)* format = null, float power = 1.0f) { return DragScalar(label, data_type, v, v_speed, v_min, v_max, format, power); }
bool          igDragScalarN(const(char)* label, ImGuiDataType data_type, void* v, int components, float v_speed, const(void)* v_min = null, const(void)* v_max = null, const(char)* format = null, float power = 1.0f) { return DragScalarN(label, data_type, v, components, v_speed, v_min, v_max, format, power); }

// Widgets: Input with Keyboard
bool          igInputText(const(char)* label, char* buf, size_t buf_size, ImGuiInputTextFlags flags = 0, ImGuiTextEditCallback callback = null, void* user_data = null)                                     { return InputText(label, buf, buf_size, flags, callback, user_data); }
bool          igInputTextMultiline(const(char)* label, char* buf, size_t buf_size, ImVec2 size = ImVec2(0,0), ImGuiInputTextFlags flags = 0, ImGuiTextEditCallback callback = null, void* user_data = null) { return InputTextMultiline(label, buf, buf_size, size, flags, callback, user_data); }
bool          igInputFloat (const(char)* label, float* v, float step = 0.0f, float step_fast = 0.0f, const(char)* format = "%.3f", ImGuiInputTextFlags extra_flags = 0)                                     { return InputFloat(label, v, step, step_fast, format, extra_flags); }
bool          igInputFloat2(const(char)* label, float* v, const(char)* format = "%.3f", ImGuiInputTextFlags extra_flags = 0) { return InputFloat2(label, v, format, extra_flags); }
bool          igInputFloat3(const(char)* label, float* v, const(char)* format = "%.3f", ImGuiInputTextFlags extra_flags = 0) { return InputFloat3(label, v, format, extra_flags); }
bool          igInputFloat4(const(char)* label, float* v, const(char)* format = "%.3f", ImGuiInputTextFlags extra_flags = 0) { return InputFloat4(label, v, format, extra_flags); }
bool          igInputInt (const(char)* label, int* v, int step = 1, int step_fast = 100, ImGuiInputTextFlags extra_flags = 0) { return InputInt(label, v, step, step_fast, extra_flags); }
bool          igInputInt2(const(char)* label, int* v, ImGuiInputTextFlags extra_flags = 0) { return InputInt2(label, v, extra_flags); }
bool          igInputInt3(const(char)* label, int* v, ImGuiInputTextFlags extra_flags = 0) { return InputInt3(label, v, extra_flags); }
bool          igInputInt4(const(char)* label, int* v, ImGuiInputTextFlags extra_flags = 0) { return InputInt4(label, v, extra_flags); }
bool          igInputDouble(const(char)* label, double* v, double step = 0.0f, double step_fast = 0.0f, const(char)* format = "%.6f", ImGuiInputTextFlags extra_flags = 0)                                  { return InputDouble(label, v, step, step_fast, format, extra_flags); }
bool          igInputScalar(const(char)* label, ImGuiDataType data_type, void* v, const(void)* step = null, const(void)* step_fast = null, const(char)* format = null, ImGuiInputTextFlags extra_flags = 0) { return InputScalar(label, data_type, v, step, step_fast, format, extra_flags); }
bool          igInputScalarN(const(char)* label, ImGuiDataType data_type, void* v, int components, const(void)* step = null, const(void)* step_fast = null, const(char)* format = null, ImGuiInputTextFlags extra_flags = 0) { return InputScalarN(label, data_type, v, components, step, step_fast, format, extra_flags); }

// Widgets: Sliders (tip: ctrl+click on a slider to input with keyboard. manually input values aren't clamped, can go off-bounds)
// Adjust format string to decorate the value with a prefix, a suffix, or adapt the editing and display precision e.g. "%.3f" -> 1.234; "%5.2f secs" -> 01.23 secs; "Biscuit: %.0f" -> Biscuit: 1; etc.
bool          igSliderFloat (const(char)* label, float* v, float v_min, float v_max, const(char)* format = "%.3f", float power = 1.0f) { return SliderFloat (label, v, v_min, v_max, format, power); }
bool          igSliderFloat2(const(char)* label, float* v, float v_min, float v_max, const(char)* format = "%.3f", float power = 1.0f) { return SliderFloat2(label, v, v_min, v_max, format, power); }
bool          igSliderFloat3(const(char)* label, float* v, float v_min, float v_max, const(char)* format = "%.3f", float power = 1.0f) { return SliderFloat3(label, v, v_min, v_max, format, power); }
bool          igSliderFloat4(const(char)* label, float* v, float v_min, float v_max, const(char)* format = "%.3f", float power = 1.0f) { return SliderFloat4(label, v, v_min, v_max, format, power); }
bool          igSliderAngle(const(char)* label, float* v_rad, float v_degrees_min = -360.0f, float v_degrees_max = +360.0f) { return SliderAngle(label, v_rad, v_degrees_min, v_degrees_max); }
bool          igSliderInt (const(char)* label, int* v, int v_min, int v_max, const(char)* format = "%d") { return SliderInt (label, v, v_min, v_max, format); }
bool          igSliderInt2(const(char)* label, int* v, int v_min, int v_max, const(char)* format = "%d") { return SliderInt2(label, v, v_min, v_max, format); }
bool          igSliderInt3(const(char)* label, int* v, int v_min, int v_max, const(char)* format = "%d") { return SliderInt3(label, v, v_min, v_max, format); }
bool          igSliderInt4(const(char)* label, int* v, int v_min, int v_max, const(char)* format = "%d") { return SliderInt4(label, v, v_min, v_max, format); }
bool          igSliderScalar(const(char)* label, ImGuiDataType data_type, void* v, const(void)* v_min, const(void)* v_max, const(char)* format = null, float power = 1.0f)                  { return SliderScalar(label, data_type, v, v_min, v_max, format, power); }
bool          igSliderScalarN(const(char)* label, ImGuiDataType data_type, void* v, int components, const(void)* v_min, const(void)* v_max, const(char)* format = null, float power = 1.0f) { return SliderScalarN(label, data_type, v, components, v_min, v_max, format, power); }
bool          igVSliderFloat(const(char)* label, ImVec2 size, float* v, float v_min, float v_max, const(char)* format = "%.3f", float power = 1.0f) { return VSliderFloat(label, size, v, v_min, v_max, format, power); }
bool          igVSliderInt(const(char)* label, ImVec2 size, int* v, int v_min, int v_max, const(char)* format = "%d")                               { return VSliderInt(label, size, v, v_min, v_max, format); }
bool          igVSliderScalar(const(char)* label, ImVec2 size, ImGuiDataType data_type, void* v, const(void)* v_min, const(void)* v_max, const(char)* format = null, float power = 1.0f) { return VSliderScalar(label, size, data_type, v, v_min, v_max, format, power); }

// Widgets: Color Editor/Picker (tip: the ColorEdit* functions have a little colored preview square that can be left-clicked to open a picker, and right-clicked to open an option menu.)
// Note that a 'float v[X]' function argument is the same as 'float* v', the array syntax is just a way to document the number of elements that are expected to be accessible. You can the pass the address of a first float element out of a contiguous structure, e.g. &myvector.x
bool          igColorEdit3(const(char)* label, float* col, ImGuiColorEditFlags flags = 0)                                 { return ColorEdit3(label, col, flags); }
bool          igColorEdit4(const(char)* label, float* col, ImGuiColorEditFlags flags = 0)                                 { return ColorEdit4(label, col, flags); }
bool          igColorPicker3(const(char)* label, float* col, ImGuiColorEditFlags flags = 0)                               { return ColorPicker3(label, col, flags); }
bool          igColorPicker4(const(char)* label, float* col, ImGuiColorEditFlags flags = 0, const(float)* ref_col = null) { return ColorPicker4(label, col, flags); }
bool          igColorButton(const(char)* desc_id, ImVec4 col, ImGuiColorEditFlags flags = 0, ImVec2 size = ImVec2(0,0))   { return ColorButton(desc_id, col, flags, size); }
void          igSetColorEditOptions(ImGuiColorEditFlags flags)                                                            { return SetColorEditOptions(flags); }

// Widgets: Trees
bool          igTreeNode(const(char)* label)                                 { return TreeNode(label); }
bool          igTreeNodeEx(const(char)* label, ImGuiTreeNodeFlags flags = 0) { return TreeNodeEx(label, flags); }

extern(C++)
{
bool          igTreeNode(const(char)* str_id, const(char)* fmt, ...)   { va_list args; va_start(args, fmt); scope(exit) va_end(args); return TreeNodeV(str_id, fmt, args); }
bool          igTreeNode(const(void)* ptr_id, const(char)* fmt, ...)   { va_list args; va_start(args, fmt); scope(exit) va_end(args); return TreeNodeV(ptr_id, fmt, args); }
bool          igTreeNodeEx(const(char)* str_id, ImGuiTreeNodeFlags flags, const(char)* fmt, ...) { va_list args; va_start(args, fmt); scope(exit) va_end(args); return TreeNodeExV(str_id, flags, fmt, args); }
bool          igTreeNodeEx(const(void)* ptr_id, ImGuiTreeNodeFlags flags, const(char)* fmt, ...) { va_list args; va_start(args, fmt); scope(exit) va_end(args); return TreeNodeExV(ptr_id, flags, fmt, args); }
}

bool          igTreeNodeV(const(char)* str_id, const(char)* fmt, va_list args) { return TreeNodeV(str_id, fmt, args); }
bool          igTreeNodeV(const(void)* ptr_id, const(char)* fmt, va_list args) { return TreeNodeV(ptr_id, fmt, args); }
bool          igTreeNodeExV(const(char)* str_id, ImGuiTreeNodeFlags flags, const(char)* fmt, va_list args) { return TreeNodeExV(str_id, flags, fmt, args); }
bool          igTreeNodeExV(const(void)* ptr_id, ImGuiTreeNodeFlags flags, const(char)* fmt, va_list args) { return TreeNodeExV(ptr_id, flags, fmt, args); }
void          igTreePush(const(char)* str_id)          { TreePush(str_id); }
void          igTreePush(const(void)* ptr_id = null)   { TreePush(ptr_id); }
void          igTreePop()                              { TreePop(); }
void          igTreeAdvanceToLabelPos()                { TreeAdvanceToLabelPos(); }
float         igGetTreeNodeToLabelSpacing()            { return GetTreeNodeToLabelSpacing(); }
void          igSetNextTreeNodeOpen(bool is_open, ImGuiCond cond = 0) { SetNextTreeNodeOpen(is_open, cond); }
bool          igCollapsingHeader(const(char)* label, ImGuiTreeNodeFlags flags = 0) { return CollapsingHeader(label, flags); }
bool          igCollapsingHeader(const(char)* label, bool* p_open, ImGuiTreeNodeFlags flags = 0) { return CollapsingHeader(label, p_open, flags); }

// Widgets: Selectable / Lists
bool          igSelectable(const(char)* label, bool selected = false, ImGuiSelectableFlags flags = 0, ImVec2 size = ImVec2(0,0))    { return Selectable(label, selected, flags, size); }
bool          igSelectable(const(char)* label, bool* p_selected, ImGuiSelectableFlags flags = 0, ImVec2 size = ImVec2(0,0))         { return Selectable(label, p_selected, flags, size); }
bool          igListBox(const(char)* label, int* current_item, const(char)** items, int items_count, int height_in_items = -1)      { return ListBox(label, current_item, items, items_count, height_in_items); }
bool          igListBox(const(char)* label, int* current_item, ImListBoxGetterCallback items_getter, void* data, int items_count, int height_in_items = -1) { return ListBox(label, current_item, items_getter, data, items_count, height_in_items); }
bool          igListBoxHeader(const(char)* label, ImVec2 size = ImVec2(0,0))                 { return ListBoxHeader(label, size); }
bool          igListBoxHeader(const(char)* label, int items_count, int height_in_items = -1) { return ListBoxHeader(label, items_count, height_in_items); }
void          igListBoxFooter()                                                              { ListBoxFooter(); }

// Widgets: Value() Helpers. Output single value in "name: value" format (tip: freely declare more in your code to handle your types. you can add functions to the ImGui namespace)
void          igValue(const(char)* prefix, bool b) { Value(prefix, b); }
void          igValue(const(char)* prefix, int v)  { Value(prefix, v); }
void          igValue(const(char)* prefix, uint v) { Value(prefix, v); }
void          igValue(const(char)* prefix, float v, const(char)* float_format = null) { Value(prefix, v, float_format); }

// Tooltips
extern(C++) void          igSetTooltip(const(char)* fmt, ...)            { va_list args; va_start(args, fmt); SetTooltipV(fmt, args); va_end(args); }
void          igSetTooltipV(const(char)* fmt, va_list args)  { SetTooltipV(fmt, args); }
void          igBeginTooltip()                               { BeginTooltip(); }
void          igEndTooltip()                                 { EndTooltip(); }

// Menus
bool          igBeginMainMenuBar() { return BeginMainMenuBar(); }
void          igEndMainMenuBar()   { EndMainMenuBar(); }
bool          igBeginMenuBar()     { return BeginMenuBar(); }
void          igEndMenuBar()       { EndMenuBar(); }
bool          igBeginMenu(const(char)* label, bool enabled = true) { return BeginMenu(label, enabled); }
void          igEndMenu()                                          { EndMenu(); }
bool          igMenuItem(const(char)* label, const(char)* shortcut = null, bool selected = false, bool enabled = true) { return MenuItem(label, shortcut, selected, enabled); }
bool          igMenuItem(const(char)* label, const(char)* shortcut, bool* p_selected, bool enabled = true)             { return MenuItem(label, shortcut, p_selected, enabled); }

// Popups
void          igOpenPopup(const(char)* str_id)                                          { OpenPopup(str_id); }
bool          igBeginPopup(const(char)* str_id, ImGuiWindowFlags flags = 0)             { return BeginPopup(str_id, flags); }
bool          igBeginPopupContextItem(const(char)* str_id = null, int mouse_button = 1) { return BeginPopupContextItem(str_id, mouse_button); }
bool          igBeginPopupContextWindow(const(char)* str_id = null, int mouse_button = 1, bool also_over_items = true) { return BeginPopupContextWindow(str_id, mouse_button, also_over_items); }
bool          igBeginPopupContextVoid(const(char)* str_id = null, int mouse_button = 1)             { return BeginPopupContextVoid(str_id, mouse_button); }
bool          igBeginPopupModal(const(char)* name, bool* p_open = null, ImGuiWindowFlags flags = 0) { return BeginPopupModal(name, p_open, flags); }
void          igEndPopup()                                                                          { EndPopup(); }
bool          igOpenPopupOnItemClick(const(char)* str_id = null, int mouse_button = 1)              { return OpenPopupOnItemClick(str_id, mouse_button); }
bool          igIsPopupOpen(const(char)* str_id) { return IsPopupOpen(str_id); }
void          igCloseCurrentPopup()              { CloseCurrentPopup(); }

// Columns
// You can also use SameLine(pos_x) for simplified columns. The columns API is still work-in-progress and rather lacking.
void          igColumns(int count = 1, const(char)* id = null, bool border = true) { Columns(count, id, border); }
void          igNextColumn()                                      { NextColumn(); }
int           igGetColumnIndex()                                  { return GetColumnIndex(); }
float         igGetColumnWidth(int column_index = -1)             { return GetColumnWidth(column_index); }
void          igSetColumnWidth(int column_index, float width)     { SetColumnWidth(column_index, width); }
float         igGetColumnOffset(int column_index = -1)            { return GetColumnOffset(column_index); }
void          igSetColumnOffset(int column_index, float offset_x) { SetColumnOffset(column_index, offset_x); }
int           igGetColumnsCount()                                 { return GetColumnsCount(); }

// Logging/Capture: all text output from interface is captured to tty/file/clipboard. By default, tree nodes are automatically opened during logging.
void          igLogToTTY(int max_depth = -1)                                { LogToTTY(max_depth); }
void          igLogToFile(int max_depth = -1, const(char)* filename = null) { LogToFile(max_depth, filename); }
void          igLogToClipboard(int max_depth = -1)                          { LogToClipboard(max_depth); }
void          igLogFinish()                                                 { LogFinish(); }
void          igLogButtons()                                                { LogButtons(); }
void          igLogText(Args...)(const(char)* fmt, auto ref Args args)      { LogText(fmt, args); }

// Drag and Drop
// [BETA API] Missing Demo code. API may evolve.
bool          igBeginDragDropSource(ImGuiDragDropFlags flags = 0)                                         { return BeginDragDropSource(flags); }
bool          igSetDragDropPayload(const(char)* type, const(void)* data, size_t size, ImGuiCond cond = 0) { return SetDragDropPayload(type, data, size, cond); }
void          igEndDragDropSource()                                                                       { EndDragDropSource(); }
bool          igBeginDragDropTarget()                                                                     { return BeginDragDropTarget(); }
const(ImGuiPayload)* igAcceptDragDropPayload(const(char)* type, ImGuiDragDropFlags flags = 0)             { return AcceptDragDropPayload(type, flags); }
void          igEndDragDropTarget()                                                                       { EndDragDropTarget(); }

// Clipping
void          igPushClipRect(ImVec2 clip_rect_min, ImVec2 clip_rect_max, bool intersect_with_current_clip_rect) { PushClipRect(clip_rect_min, clip_rect_max, intersect_with_current_clip_rect); }
void          igPopClipRect()                                                                                   { PopClipRect(); }

// Focus, Activation
// (Prefer using "SetItemDefaultFocus()" over "if (IsWindowAppearing()) SetScrollHere()" when applicable, to make your code more forward compatible when navigation branch is merged)
void          igSetItemDefaultFocus()                { SetItemDefaultFocus(); }
void          igSetKeyboardFocusHere(int offset = 0) { SetKeyboardFocusHere(offset); }

// Utilities
bool          igIsItemHovered(ImGuiHoveredFlags flags = 0) { return IsItemHovered(flags); }
bool          igIsItemActive()                             { return IsItemActive(); }
bool          igIsItemFocused()                            { return IsItemFocused(); }
bool          igIsItemClicked(int mouse_button = 0)        { return IsItemClicked(mouse_button); }
bool          igIsItemVisible()                            { return IsItemVisible(); }
bool          igIsAnyItemHovered()                         { return IsAnyItemHovered(); }
bool          igIsAnyItemActive()                          { return IsAnyItemActive(); }
bool          igIsAnyItemFocused()                         { return IsAnyItemFocused(); }
ImVec2        igGetItemRectMin()                           { return GetItemRectMin(); }
ImVec2        igGetItemRectMax()                           { return GetItemRectMax(); }
ImVec2        igGetItemRectSize()                          { return GetItemRectSize(); }
void          igSetItemAllowOverlap()                      { return SetItemAllowOverlap(); }
bool          igIsRectVisible(ImVec2 size)                 { return IsRectVisible(size); }
bool          igIsRectVisible(ImVec2 rect_min, ImVec2 rect_max) { return IsRectVisible(rect_min, rect_max); }
float         igGetTime()                                  { return GetTime(); }
int           igGetFrameCount()                            { return GetFrameCount(); }
ImDrawList*   igGetOverlayDrawList()                       { return GetOverlayDrawList(); }
ImDrawListSharedData* igGetDrawListSharedData()            { return GetDrawListSharedData(); }
const(char)*   igGetStyleColorName(ImGuiCol idx)           { return GetStyleColorName(idx); }
void          igSetStateStorage(ImGuiStorage* storage)     { SetStateStorage(storage); }
ImGuiStorage* igGetStateStorage()                          { return GetStateStorage(); }
ImVec2        igCalcTextSize(const(char)* text, const(char)* text_end = null, bool hide_text_after_double_hash = false, float wrap_width = -1.0f) { return CalcTextSize(text, text_end, hide_text_after_double_hash, wrap_width); }
void          igCalcListClipping(int items_count, float items_height, int* out_items_display_start, int* out_items_display_end)                   { return CalcListClipping(items_count, items_height, out_items_display_start, out_items_display_end); }

bool          igBeginChildFrame(ImGuiID id, ImVec2 size, ImGuiWindowFlags flags = 0) { return BeginChildFrame(id, size, flags); }
void          igEndChildFrame() { EndChildFrame(); }

ImVec4        igColorConvertU32ToFloat4(ImU32 in_) { return ColorConvertU32ToFloat4(in_); }
ImU32         igColorConvertFloat4ToU32(ref const ImVec4 in_) { return ColorConvertFloat4ToU32(in_); }
void          igColorConvertRGBtoHSV(float r, float g, float b, ref float out_h, ref float out_s, ref float out_v) { ColorConvertRGBtoHSV(r, g, b, out_h, out_s, out_v); }
void          igColorConvertHSVtoRGB(float h, float s, float v, ref float out_r, ref float out_g, ref float out_b) { ColorConvertHSVtoRGB(h, s, v, out_r, out_g, out_b); }

// Inputs
int           igGetKeyIndex(ImGuiKey imgui_key)                      { return GetKeyIndex(imgui_key); }
bool          igIsKeyDown(int user_key_index)                        { return IsKeyDown(user_key_index); }
bool          igIsKeyPressed(int user_key_index, bool repeat = true) { return IsKeyPressed(user_key_index, repeat); }
bool          igIsKeyReleased(int user_key_index)                    { return IsKeyReleased(user_key_index); }
int           igGetKeyPressedAmount(int key_index, float repeat_delay, float rate) { return GetKeyPressedAmount(key_index, repeat_delay, rate); }
bool          igIsMouseDown(int button)                              { return IsMouseDown(button); }
bool          igIsAnyMouseDown()                                     { return IsAnyMouseDown(); }
bool          igIsMouseClicked(int button, bool repeat = false)      { return IsMouseClicked(button, repeat); }
bool          igIsMouseDoubleClicked(int button)                     { return IsMouseDoubleClicked(button); }
bool          igIsMouseReleased(int button)                          { return IsMouseReleased(button); }
bool          igIsMouseDragging(int button = 0, float lock_threshold = -1.0f) { return IsMouseDragging(button, lock_threshold); }
bool          igIsMouseHoveringRect(ImVec2 r_min, ImVec2 r_max, bool clip = true) { return IsMouseHoveringRect(r_min, r_max, clip); }
bool          igIsMousePosValid(const ImVec2* mouse_pos = null)      { return IsMousePosValid(mouse_pos); }
ImVec2        igGetMousePos()                                        { return GetMousePos(); }
ImVec2        igGetMousePosOnOpeningCurrentPopup()                   { return GetMousePosOnOpeningCurrentPopup(); }
ImVec2        igGetMouseDragDelta(int button = 0, float lock_threshold = -1.0f) { return GetMouseDragDelta(button, lock_threshold); }
void          igResetMouseDragDelta(int button = 0)                 { return ResetMouseDragDelta(button); }
ImGuiMouseCursor igGetMouseCursor()                                 { return GetMouseCursor(); }
void          SetMouseCursor(ImGuiMouseCursor type)                 { SetMouseCursor(type); }
void          CaptureKeyboardFromApp(bool capture = true)           { CaptureKeyboardFromApp(capture); }
void          CaptureMouseFromApp(bool capture = true)              { CaptureMouseFromApp(capture); }

// Clipboard Utilities (also see the LogToClipboard() function to capture or output text data to the clipboard)
const(char)*  igGetClipboardText()                  { return GetClipboardText(); }
void          igSetClipboardText(const(char)* text) { SetClipboardText(text); }

// Settings/.Ini Utilities
// The disk functions are automatically called if io.IniFilename != null (default is "imgui.ini").
// Set io.IniFilename to null to load/save manually. Read io.WantSaveIniSettings description about handling .ini saving manually.
void          igLoadIniSettingsFromDisk(const(char)* ini_filename)                  { LoadIniSettingsFromDisk(ini_filename); }
void          igLoadIniSettingsFromMemory(const(char)* ini_data, size_t ini_size=0) { LoadIniSettingsFromMemory(ini_data, ini_size); }
void          igSaveIniSettingsToDisk(const(char)* ini_filename)                    { SaveIniSettingsToDisk(ini_filename); }
const(char)*  igSaveIniSettingsToMemory(size_t* out_ini_size = null)                { return SaveIniSettingsToMemory(out_ini_size); }

// Memory Utilities
// All those functions are not reliant on the current context.
// If you reload the contents of imgui.cpp at runtime, you may need to call SetCurrentContext() + SetAllocatorFunctions() again.
void          igSetAllocatorFunctions(ImAllocCallback alloc_func, ImFreeCallback free_func, void* user_data = null) { SetAllocatorFunctions(alloc_func, free_func, user_data); }
void*         igMemAlloc(size_t size) { return MemAlloc(size); }
void          igMemFree(void* ptr)    { MemFree(ptr); }


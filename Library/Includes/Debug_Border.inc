// ============================================================================
// IOTA Border Debug Utility
// Nested Stack + Scoped Blocks + Inline Colour Version (KickAssembler Compatible)
// Author: Gareth (IOTA Project)
// Purpose: Visual raster‑time debugging with nested border colour tracking
// ============================================================================

// ============================================================================
// HOW IT WORKS
// ============================================================================
//
// This debugging utility provides real-time visual feedback on the Commodore 64
// screen border to measure raster time consumption of subroutines and code blocks.
//
// Assembly-time state tracking:
//   - A Hashtable maps subsystem names to assigned colours (stable across calls)
//   - A List stack tracks colour history for proper nesting
//   - Global variables maintain current border colour
//
// Runtime border writes:
//   - When enabled, each debug scope writes to VIC._BORDER ($D020)
//   - Different colours show different code sections
//   - Nested calls automatically restore the previous colour when exiting
//
// The debugStart() and debugEnd() macros manage a colour stack that handles
// arbitrary nesting depth, ensuring correct colour restoration even in complex
// scenarios.
//
// ============================================================================
// USAGE INSTRUCTIONS
// ============================================================================
//
// 0. Enable or disable border debugging globally:
//
//      .var BORDER_DEBUG_ENABLED = true   // Enable all debug output
//      .var BORDER_DEBUG_ENABLED = false  // Strip all debug code at build time
//
// 1. With explicit colour (RECOMMENDED):
//
//      debugStart("Physics", Green)
//          jsr UpdatePhysics
//      debugEnd()
//
// 2. With auto-assigned colour:
//
//      debugStart("AI", null)
//          jsr UpdateAI
//      debugEnd()
//
// 3. Nested debugging (automatically manages stack):
//
//      debugStart("AI", Purple)
//          jsr Think
//
//          debugStart("Pathfinding", Yellow)
//              jsr BuildGraph
//
//              debugStart("Heuristic", Cyan)
//                  jsr EvaluateHeuristic
//              debugEnd()
//          debugEnd()
//      debugEnd()
//
//      This produces a layered raster pattern showing the call hierarchy
//      and relative time spent in each section. The stack ensures each
//      debugEnd() restores the correct previous colour.
//
//
// ============================================================================
// IMPLEMENTATION NOTES
// ============================================================================
//
// - Default colour on init/reset is 0 (Black). Modify debugEnd() if needed.
// - Inline colours always override auto-assignment.
// - The stack ensures correct restoration even in deep, complex nesting.
// - When BORDER_DEBUG_ENABLED = false, all debug writes are stripped at build.
// - Colours start at 2 (avoiding black/white for better visibility).
//
// ============================================================================

// ---------------------------------------------------------------------------
// Global toggle — set to false to strip ALL border debug writes at build time
// ---------------------------------------------------------------------------
.var BORDER_DEBUG_ENABLED = true

// ---------------------------------------------------------------------------
// INTERNAL ARCHITECTURE
// ---------------------------------------------------------------------------
//
// Assembly-time state (KickAssembler variables):
//   - BorderDebugColours (Hashtable): Maps subsystem names to assigned colours
//   - BorderDebugNextColour (int): Counter for next available auto-assigned colour
//   - BorderStack (List): LIFO stack tracking nested colour history
//   - CurrentBorderColour (int): Current border colour value (for reference)
//
// Runtime operations:
//   - debugStart(name, colour): Push current colour onto stack, set new border colour
//   - debugEnd(): Pop and restore previous colour from stack
//
// Colour flow in a nested call:
//   1. .debugStart("Outer", Green) → Push 0, set border = Green
//   2. .debugStart("Inner", Yellow) → Push Green, set border = Yellow
//   3. .debugEnd() → Pop Yellow, restore Green
//   4. .debugEnd() → Pop Green, restore 0
//
// ---------------------------------------------------------------------------
.var BorderDebugColours = Hashtable()
.var BorderDebugNextColour = 2   // start at colour 2 (avoid black/white)

// ---------------------------------------------------------------------------
// Nested border stack
// ---------------------------------------------------------------------------
.var BorderStack = List()

// Track current border colour (assembly-time only)
.var CurrentBorderColour = 0

.function GetCurrentBorderColour() {
    .return CurrentBorderColour
}

.macro SetCurrentBorderColour(c) {
.eval CurrentBorderColour = c
}

// ---------------------------------------------------------------------------
// Macro: GetBorderColour(name, returnVar)
//
// Returns a stable colour for the given subsystem name.
// If name is new, assigns the next auto-colour and stores it.
// If name already exists, returns its previously assigned colour.
//
// This ensures that a subsystem always gets the same colour across multiple
// debug calls, making the raster display consistent.
//
// MUST be a macro (not a function) to access and modify global .var tables.
// ---------------------------------------------------------------------------
.macro GetBorderColour(name, returnVar) {
    .if (BorderDebugColours.containsKey(name)) {
        .eval returnVar = BorderDebugColours.get(name)
    } else {
        .var c = BorderDebugNextColour
        .eval BorderDebugColours.put(name, c)
        .eval BorderDebugNextColour = BorderDebugNextColour + 1
        .eval returnVar = c
    }
}

// ---------------------------------------------------------------------------
// Macro: debugStart(name, colour)
//
// Enters a debug scope: pushes current colour onto stack and sets new colour.
//
// Parameters:
//   name   - String label for this debug section (used for auto-colour mapping)
//   colour - Explicit colour value, or null for auto-assignment
//
// Runtime output:
//   - lda #colour
//   - sta VIC._BORDER
//
// Notes:
//   - Wrapper macro for optional colour parameter handling
//   - Automatically calls GetBorderColour if colour is null
//   - Updates assembly-time CurrentBorderColour tracking
// ---------------------------------------------------------------------------
.macro debugStart(name, colour) {
    .if (BORDER_DEBUG_ENABLED) {

        // Push current colour onto stack
        .eval BorderStack.add(CurrentBorderColour)

        // Determine colour: explicit or auto-assigned
        .var c

        .if(colour != null) {
            .eval c = colour
        } else {
            .var tmp
            GetBorderColour(name, tmp)
            .eval c = tmp
        }

        lda #c
        sta VIC._BORDER

        .eval CurrentBorderColour = c
    }
}

// ---------------------------------------------------------------------------
// Macro: debugEnd()
//
// Exits a debug scope: pops the previous colour from stack and restores it.
//
// Runtime output:
//   - lda #prev_colour
//   - sta VIC._BORDER
//
// Notes:
//   - Called automatically by debugBorder pseudocommand
//   - Updates assembly-time CurrentBorderColour tracking
//   - If stack is empty, restores to colour 0 (Black) as default
//   - Modify the default prev value if a different reset colour is desired
// ---------------------------------------------------------------------------
.macro debugEnd() {
    .if (BORDER_DEBUG_ENABLED) {

        .var prev = 0

        .if (BorderStack.size() > 0) {
            .eval prev = BorderStack.get(BorderStack.size()-1)
            .eval BorderStack.remove(BorderStack.size()-1)
        }

        lda #prev
        sta VIC._BORDER

        .eval CurrentBorderColour = prev
    }
}





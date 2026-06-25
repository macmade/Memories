/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, Jean-David Gadina - www.xs-labs.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the Software), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 ******************************************************************************/

import SwiftUI

/// The file-related actions the focused window exposes to the menu bar.
///
/// `AppModel` lives in `ContentView`'s state, so menu commands cannot reach it
/// directly. The focused window publishes the actions it can currently perform
/// through ``FocusedValues/memoryFileActions``; a `nil` closure means the
/// corresponding command is unavailable and the menu item disables itself.
struct MemoryFileActions
{
    /// Exports a copy of the current memory file, or `nil` when no file is
    /// selected.
    var saveCurrentFileAs: ( () -> Void )?

    /// Exports all of the selected project's memory files, or `nil` when no
    /// project is selected.
    var exportProjectMemory: ( () -> Void )?
}

private struct MemoryFileActionsKey: FocusedValueKey
{
    typealias Value = MemoryFileActions
}

extension FocusedValues
{
    /// The file actions published by the focused window, if any.
    var memoryFileActions: MemoryFileActions?
    {
        get { self[ MemoryFileActionsKey.self ] }
        set { self[ MemoryFileActionsKey.self ] = newValue }
    }
}

/// The app's contributions to the standard *File* menu.
struct FileCommands: View
{
    @FocusedValue( \.memoryFileActions ) private var actions

    var body: some View
    {
        Button( "Save As\u{2026}" )
        {
            self.actions?.saveCurrentFileAs?()
        }
        .keyboardShortcut( "s", modifiers: [ .command, .shift ] )
        .disabled( self.actions?.saveCurrentFileAs == nil )

        Button( "Export Memory\u{2026}" )
        {
            self.actions?.exportProjectMemory?()
        }
        .disabled( self.actions?.exportProjectMemory == nil )
    }
}

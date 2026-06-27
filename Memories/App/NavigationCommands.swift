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

/// The back / next navigation actions the focused window exposes to the menu
/// bar.
///
/// `AppModel` lives in `ContentView`'s state, so menu commands cannot reach it
/// directly. The focused window publishes the moves it can currently perform
/// through ``FocusedValues/memoryNavigationActions``; a `nil` closure means the
/// corresponding command is unavailable and the menu item disables itself,
/// mirroring the toolbar buttons' enabled state.
struct MemoryNavigationActions
{
    /// Goes back to the previous file, or `nil` when there is none.
    var goBack: ( () -> Void )?

    /// Goes forward to the next file, or `nil` when there is none.
    var goForward: ( () -> Void )?
}

private struct MemoryNavigationActionsKey: FocusedValueKey
{
    typealias Value = MemoryNavigationActions
}

extension FocusedValues
{
    /// The navigation actions published by the focused window, if any.
    var memoryNavigationActions: MemoryNavigationActions?
    {
        get { self[ MemoryNavigationActionsKey.self ] }
        set { self[ MemoryNavigationActionsKey.self ] = newValue }
    }
}

/// The app's contributions to the *Go* menu: back and next, with the standard
/// `⌘[` and `⌘]` shortcuts.
struct NavigationCommands: View
{
    @FocusedValue( \.memoryNavigationActions ) private var actions

    var body: some View
    {
        Button( "Back" )
        {
            self.actions?.goBack?()
        }
        .keyboardShortcut( "[", modifiers: .command )
        .disabled( self.actions?.goBack == nil )

        Button( "Next" )
        {
            self.actions?.goForward?()
        }
        .keyboardShortcut( "]", modifiers: .command )
        .disabled( self.actions?.goForward == nil )
    }
}

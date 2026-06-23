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

@main
struct MemoriesApp: App
{
    @Environment( \.openWindow ) private var openWindow

    var body: some Scene
    {
        WindowGroup
        {
            ContentView()
        }
        .commands
        {
            CommandGroup( replacing: CommandGroupPlacement.appInfo )
            {
                Button( "About \( Bundle.main.title )\u{2026}" )
                {
                    self.openWindow( id: "AboutWindow" )
                }
            }

            CommandGroup( after: CommandGroupPlacement.sidebar )
            {
                ViewCommands()
            }
        }

        Window( "About \( Bundle.main.title )", id: "AboutWindow" )
        {
            AboutView()
                .padding()
                .fixedSize()
        }
        .windowStyle( .hiddenTitleBar )
        .windowResizability( .contentSize )
        .restorationBehavior( .disabled )
        // Open centered on screen rather than cascaded as an "additional" window.
        // This is only the initial default: while the window is open, re-issuing
        // the About command just brings it forward without moving it.
        .defaultPosition( .center )
    }
}

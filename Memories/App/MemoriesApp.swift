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

import AppKit
import SwiftUI
import SwiftUtilities

@main
struct MemoriesApp: App
{
    /// Checks the GitHub repository for newer published releases of the app.
    ///
    /// `nil` only if a valid releases URL cannot be built, which the menu item
    /// reflects by disabling itself.
    private let updater = GitHubUpdater( owner: "macmade", repository: "Memories" )

    init()
    {
        // Check for a newer release once at launch, silently: the user is only
        // alerted when an update is actually available. Dispatched after a short
        // delay so the check never competes with the app finishing launching.
        let updater = self.updater

        Task
        {
            try? await Task.sleep( for: .seconds( 5 ) )

            updater?.checkForUpdatesInBackground()
        }
    }

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
                    AboutWindowController.show()
                }

                Divider()

                Button( "Check for Updates\u{2026}" )
                {
                    self.updater?.checkForUpdates()
                }
                .disabled( self.updater == nil )
            }

            CommandGroup( after: CommandGroupPlacement.newItem )
            {
                Button( "Close" )
                {
                    NSApp.keyWindow?.performClose( nil )
                }
                .keyboardShortcut( "w", modifiers: .command )
            }

            CommandGroup( replacing: CommandGroupPlacement.saveItem )
            {
                FileCommands()
            }

            CommandGroup( after: CommandGroupPlacement.sidebar )
            {
                ViewCommands()
            }

            CommandMenu( "Go" )
            {
                NavigationCommands()
            }
        }
    }
}

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

/// The detail pane previewing a project's `MEMORY.md` index.
struct MemoryView: View
{
    let project: Project

    @State private var state = MemoryLoadState.loading

    var body: some View
    {
        Group
        {
            switch self.state
            {
                case .loading:

                    ProgressView()

                case .loaded( let text ):

                    ScrollView
                    {
                        Text( text )
                            .textSelection( .enabled )
                            .frame( maxWidth: .infinity, alignment: .leading )
                            .padding()
                    }

                case .failed( let message ):

                    ContentUnavailableView( "Unable to Read Memory", systemImage: "exclamationmark.triangle", description: Text( message ) )
            }
        }
        .navigationTitle( self.project.displayName )
        .navigationSubtitle( self.project.decodedPath )
        .task( id: self.project.id )
        {
            await self.load()
        }
    }

    private func load() async
    {
        self.state = .loading

        let url   = self.project.memoryURL
        let state = await Task.detached
        {
            MemoryLoader.load( from: url )
        }
        .value

        self.state = state
    }
}

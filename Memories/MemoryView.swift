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
    let project:  Project
    let file:     MemoryFile
    let files:    [ MemoryFile ]
    let viewMode: MemoryViewMode

    @Binding var selection: MemoryFile.ID?

    @State private var state       = MemoryLoadState.loading
    @State private var isBarVisible = true
    @State private var hideTask:    Task<Void, Never>?

    var body: some View
    {
        Group
        {
            switch self.state
            {
                case .loading:

                    ProgressView()

                case .loaded( let text ):

                    self.content( for: text )

                case .failed( let message ):

                    ContentUnavailableView( "Unable to Read Memory", systemImage: "exclamationmark.triangle", description: Text( message ) )
            }
        }
        .overlay( alignment: .bottom )
        {
            if self.files.count > 1, self.isBarVisible
            {
                FileSwitcherBar( files: self.files, selection: self.$selection )
                    .transition( .move( edge: .bottom ).combined( with: .opacity ) )
            }
        }
        .onContinuousHover
        {
            phase in

            if case .active = phase
            {
                self.registerInteraction()
            }
        }
        .onAppear
        {
            self.registerInteraction()
        }
        .navigationTitle( self.project.title )
        .navigationSubtitle( self.project.decodedPath )
        .task( id: self.file.id )
        {
            await self.load()
        }
    }

    /// Reveals the floating bar and (re)arms a timer that hides it after two
    /// seconds without mouse movement.
    private func registerInteraction()
    {
        if self.isBarVisible == false
        {
            withAnimation
            {
                self.isBarVisible = true
            }
        }

        self.hideTask?.cancel()
        self.hideTask = Task
        {
            try? await Task.sleep( for: .seconds( 2 ) )

            guard Task.isCancelled == false
            else
            {
                return
            }

            withAnimation
            {
                self.isBarVisible = false
            }
        }
    }

    @ViewBuilder
    private func content( for text: String ) -> some View
    {
        switch self.viewMode
        {
            case .preview:

                MarkdownTextView( attributedString: MarkdownRenderer.attributedString( from: text ) )

            case .source:

                ScrollView
                {
                    Text( text )
                        .font( .system( .body, design: .monospaced ) )
                        .textSelection( .enabled )
                        .frame( maxWidth: .infinity, alignment: .leading )
                        .padding()
                }
        }
    }

    private func load() async
    {
        self.state = .loading

        let url   = self.file.url
        let state = await Task.detached
        {
            MemoryLoader.load( from: url )
        }
        .value

        self.state = state
    }
}

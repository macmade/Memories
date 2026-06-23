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

struct ContentView: View
{
    @State private var model = AppModel()
    @State private var projectPendingTrash: Project?
    @State private var errorMessage:        String?

    var body: some View
    {
        @Bindable var model = self.model

        NavigationSplitView
        {
            List( selection: $model.selection )
            {
                ForEach( self.model.projects )
                {
                    project in

                    ProjectRow( project: project )
                        .tag( project.id )
                        .contextMenu
                        {
                            self.contextMenu( for: project )
                        }
                }
            }
            .overlay
            {
                if self.model.projects.isEmpty
                {
                    ContentUnavailableView( "No Projects", systemImage: "tray", description: Text( "No Claude projects with a memory index were found." ) )
                }
            }
            .navigationTitle( "Memories" )
        }
        detail:
        {
            if let project = self.model.selectedProject
            {
                MemoryView( project: project, viewMode: self.model.viewMode )
            }
            else
            {
                ContentUnavailableView( "No Selection", systemImage: "sidebar.left", description: Text( "Select a project to preview its memory." ) )
            }
        }
        .task
        {
            await self.model.loadProjects()
        }
        .alert(
            "Move \u{201C}\( self.projectPendingTrash?.displayName ?? "" )\u{201D} to the Trash?",
            isPresented: Binding( get: { self.projectPendingTrash != nil }, set: { if $0 == false { self.projectPendingTrash = nil } } ),
            presenting:  self.projectPendingTrash
        )
        {
            project in

            Button( "Move to Trash", role: .destructive )
            {
                self.trash( project )
            }

            Button( "Cancel", role: .cancel ) {}
        }
        message:
        {
            _ in

            Text( "The entire project folder will be moved to the Trash." )
        }
        .alert(
            "Operation Failed",
            isPresented: Binding( get: { self.errorMessage != nil }, set: { if $0 == false { self.errorMessage = nil } } ),
            presenting:  self.errorMessage
        )
        {
            _ in

            Button( "OK", role: .cancel ) {}
        }
        message:
        {
            message in

            Text( message )
        }
    }

    @ViewBuilder
    private func contextMenu( for project: Project ) -> some View
    {
        Button( "Reveal in Finder" )
        {
            NSWorkspace.shared.activateFileViewerSelecting( [ project.folderURL ] )
        }

        Button( "Move to Trash", role: .destructive )
        {
            self.projectPendingTrash = project
        }
    }

    private func trash( _ project: Project )
    {
        do
        {
            try self.model.trashProject( project )
        }
        catch
        {
            self.errorMessage = error.localizedDescription
        }
    }
}

#Preview
{
    ContentView()
}

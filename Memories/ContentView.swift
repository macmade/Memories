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
    @Environment( \.scenePhase ) private var scenePhase

    @State private var model = AppModel()
    @State private var projectPendingTrash: Project?
    @State private var memoryPendingTrash:  Project?
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

                    self.sidebarRow( for: project )
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
        .onChange( of: self.scenePhase )
        {
            _, phase in

            guard phase == .active
            else
            {
                return
            }

            Task
            {
                await self.model.loadProjects()
            }
        }
        .toolbar
        {
            if let project = self.model.selectedProject
            {
                ToolbarItemGroup( placement: .primaryAction )
                {
                    self.openWithMenu( for: project )
                        .help( "Open the memory file with another application" )

                    Button
                    {
                        self.memoryPendingTrash = project
                    }
                    label:
                    {
                        Label( "Move Memory to Trash", systemImage: "trash" )
                    }
                    .help( "Move this project's memory file to the Trash" )

                    Picker( "View Mode", selection: $model.viewMode )
                    {
                        ForEach( MemoryViewMode.allCases )
                        {
                            mode in

                            Label( mode.title, systemImage: mode.systemImage )
                                .help( mode == .preview ? "Show the rendered Markdown preview" : "Show the raw Markdown source" )
                                .tag( mode )
                        }
                    }
                    .pickerStyle( .segmented )
                    .help( "Switch between the rendered preview and the Markdown source" )
                }
            }
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
            "Move the memory of \u{201C}\( self.memoryPendingTrash?.displayName ?? "" )\u{201D} to the Trash?",
            isPresented: Binding( get: { self.memoryPendingTrash != nil }, set: { if $0 == false { self.memoryPendingTrash = nil } } ),
            presenting:  self.memoryPendingTrash
        )
        {
            project in

            Button( "Move to Trash", role: .destructive )
            {
                self.trashMemory( project )
            }

            Button( "Cancel", role: .cancel ) {}
        }
        message:
        {
            _ in

            Text( "Only the MEMORY.md file will be moved to the Trash; the project folder is left intact." )
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
        .frame( minWidth: 700, minHeight: 450 )
    }

    @ViewBuilder
    private func sidebarRow( for project: Project ) -> some View
    {
        ProjectRow( project: project, isSelected: self.model.selection == project.id )
            .tag( project.id )
            .contextMenu
            {
                self.contextMenu( for: project )
            }
    }

    @ViewBuilder
    private func contextMenu( for project: Project ) -> some View
    {
        if let directory = project.resolvedDirectoryURL
        {
            Button( "Open Project Directory" )
            {
                NSWorkspace.shared.open( directory )
            }
            .help( "Open the project's directory in Finder" )
        }

        Button( "Reveal in Finder" )
        {
            NSWorkspace.shared.activateFileViewerSelecting( [ project.folderURL ] )
        }
        .help( "Reveal the Claude project folder in Finder" )

        Button( "Move to Trash", role: .destructive )
        {
            self.projectPendingTrash = project
        }
        .help( "Move the entire project folder to the Trash" )
    }

    @ViewBuilder
    private func openWithMenu( for project: Project ) -> some View
    {
        Menu
        {
            // Computed lazily here, only when the menu is opened, so the
            // LaunchServices lookup never runs during a normal render pass.
            let applications = self.applications( toOpen: project.memoryURL )

            if applications.isEmpty
            {
                Text( "No Applications" )
            }
            else
            {
                ForEach( applications, id: \.self )
                {
                    application in

                    Button
                    {
                        self.open( project.memoryURL, with: application )
                    }
                    label:
                    {
                        Label
                        {
                            Text( self.applicationName( application ) )
                        }
                        icon:
                        {
                            Image( nsImage: NSWorkspace.shared.icon( forFile: application.path ) )
                        }
                    }
                }
            }
        }
        label:
        {
            Label( "Open With", systemImage: "arrow.up.forward.app" )
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

    private func trashMemory( _ project: Project )
    {
        do
        {
            try self.model.trashMemory( project )
        }
        catch
        {
            self.errorMessage = error.localizedDescription
        }
    }

    /// The applications able to open the given file, de-duplicated and sorted
    /// by display name.
    private func applications( toOpen url: URL ) -> [ URL ]
    {
        var seen = Set<URL>()

        return NSWorkspace.shared.urlsForApplications( toOpen: url )
            .filter { seen.insert( $0 ).inserted }
            .sorted { self.applicationName( $0 ).localizedCaseInsensitiveCompare( self.applicationName( $1 ) ) == .orderedAscending }
    }

    private func applicationName( _ url: URL ) -> String
    {
        FileManager.default.displayName( atPath: url.path )
    }

    private func open( _ url: URL, with application: URL )
    {
        NSWorkspace.shared.open( [ url ], withApplicationAt: application, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil )
    }
}

#Preview
{
    ContentView()
}

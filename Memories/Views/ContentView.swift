/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) 2026, DigiDNA
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
    @State private var memoryTrashTarget:   Project?
    @State private var errorMessage:        String?

    var body: some View
    {
        self.content
            .frame( minWidth: 800, minHeight: 600 )
    }

    private var content: some View
    {
        @Bindable var model = self.model

        let base = self.splitView
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
            .onChange( of: self.model.selection )
            {
                _, _ in

                Task
                {
                    await self.model.loadMemoryFiles()
                }
            }
            .toolbar
            {
                self.toolbarContent( viewMode: $model.viewMode )
            }

        return self.withAlerts( base )
    }

    private var splitView: some View
    {
        @Bindable var model = self.model

        return NavigationSplitView
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
            .navigationSplitViewColumnWidth( min: 250, ideal: 250 )
        }
        detail:
        {
            self.detailView
                .frame( minWidth: 500 )
        }
    }

    private func withAlerts( _ view: some View ) -> some View
    {
        view
            .alert(
                "Move the Claude project folder for \u{201C}\( self.projectPendingTrash?.title ?? "" )\u{201D} to the Trash?",
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

                Text( "This moves the project's folder under ~/.claude/projects, with its stored memory, to the Trash. The real project on disk is not affected." )
            }
            .confirmationDialog(
                "Move memory to the Trash?",
                isPresented: Binding( get: { self.memoryTrashTarget != nil }, set: { if $0 == false { self.memoryTrashTarget = nil } } ),
                presenting:  self.memoryTrashTarget
            )
            {
                project in

                Button( "This File", role: .destructive )
                {
                    self.trashSelectedFile()
                }

                Button( "All Files", role: .destructive )
                {
                    self.trashAllMemory( project )
                }

                Button( "Cancel", role: .cancel ) {}
            }
            message:
            {
                _ in

                Text( "\u{201C}This File\u{201D} moves only the current memory file to the Trash. \u{201C}All Files\u{201D} moves the project's entire memory folder to the Trash, removing it from the list." )
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

    @ToolbarContentBuilder
    private func toolbarContent( viewMode: Binding< MemoryViewMode > ) -> some ToolbarContent
    {
        if let project = self.model.selectedProject
        {
            ToolbarItemGroup( placement: .primaryAction )
            {
                if let file = self.model.selectedMemoryFile
                {
                    self.openWithMenu( for: file )
                        .help( "Open the current memory file with another application" )
                }

                Button
                {
                    self.memoryTrashTarget = project
                }
                label:
                {
                    Label( "Move to Trash", systemImage: "trash" )
                }
                .help( "Move the current file, or all memory files, to the Trash" )

                Picker( "View Mode", selection: viewMode )
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

    @ViewBuilder     private var detailView: some View
    {
        @Bindable var model = self.model

        if let project = self.model.selectedProject, let file = self.model.selectedMemoryFile
        {
            MemoryView( project: project, file: file, files: self.model.memoryFiles, viewMode: self.model.viewMode, selection: $model.selectedFile )
        }
        else if self.model.selectedProject != nil
        {
            ProgressView()
        }
        else
        {
            ContentUnavailableView( "No Selection", systemImage: "sidebar.left", description: Text( "Select a project to preview its memory." ) )
        }
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
            Button
            {
                NSWorkspace.shared.open( directory )
            }
            label:
            {
                Label( "Open Project Folder", systemImage: "folder" )
            }
            .help( "Open the project's real folder on disk in Finder" )
        }

        Button
        {
            NSWorkspace.shared.activateFileViewerSelecting( [ project.folderURL ] )
        }
        label:
        {
            Label( "Reveal Claude Project Folder in Finder", systemImage: "magnifyingglass" )
        }
        .help( "Reveal the project's Claude folder, under ~/.claude/projects, in Finder" )

        Divider()

        Button( role: .destructive )
        {
            self.projectPendingTrash = project
        }
        label:
        {
            Label( "Move Claude Project Folder to Trash", systemImage: "trash" )
        }
        .help( "Move the project's Claude folder, under ~/.claude/projects, to the Trash. The real project on disk is not affected." )
    }

    @ViewBuilder
    private func openWithMenu( for file: MemoryFile ) -> some View
    {
        Menu
        {
            // Computed lazily here, only when the menu is opened, so the
            // LaunchServices lookup never runs during a normal render pass.
            let applications = self.applications( toOpen: file.url )

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
                        self.open( file.url, with: application )
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

    private func trashSelectedFile()
    {
        guard let file = self.model.selectedMemoryFile
        else
        {
            return
        }

        do
        {
            try self.model.trashFile( file )
        }
        catch
        {
            self.errorMessage = error.localizedDescription
        }
    }

    private func trashAllMemory( _ project: Project )
    {
        do
        {
            try self.model.trashAllMemory( project )
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
        var seen = Set< URL >()

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

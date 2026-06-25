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

import Foundation
import Observation

/// The app-wide model holding the discovered projects and the current selection.
@MainActor
@Observable
final class AppModel
{
    /// The discovered projects, sorted by display name.
    private( set ) var projects: [ Project ] = []

    /// The identity of the currently selected project, if any.
    var selection: Project.ID?

    /// How the detail view presents the selected memory.
    var viewMode = MemoryViewMode.preview

    /// The Markdown files of the selected project's `memory/` folder.
    private( set ) var memoryFiles: [ MemoryFile ] = []

    /// The identity of the currently selected memory file, if any.
    var selectedFile: MemoryFile.ID?

    /// The directory scanned for projects.
    let projectsDirectory: URL

    /// Moves an item to the Trash. Injectable so tests need not touch the real
    /// Trash; defaults to `FileManager.trashItem(at:resultingItemURL:)`.
    private let trashItem: ( URL ) throws -> Void

    /// Copies a single memory file from a source to a destination. Injectable so
    /// tests need not touch the filesystem; defaults to
    /// ``MemoryExporter/export(file:to:fileManager:)``.
    private let exportFile: ( URL, URL ) throws -> Void

    /// Copies all memory files under a source directory into a destination
    /// folder, preserving structure. `@Sendable` because the export runs off the
    /// main actor; injectable so tests need not touch the filesystem. Defaults to
    /// ``MemoryExporter/export(memoryDirectory:to:fileManager:)``.
    private let exportProject: @Sendable ( URL, URL ) throws -> Void

    /// The currently selected project, resolved from ``selection``.
    var selectedProject: Project?
    {
        self.projects.first { $0.id == self.selection }
    }

    /// The currently selected memory file, resolved from ``selectedFile``.
    var selectedMemoryFile: MemoryFile?
    {
        self.memoryFiles.first { $0.id == self.selectedFile }
    }

    init( projectsDirectory: URL = MemoryDiscovery.defaultProjectsDirectory, trashItem: @escaping ( URL ) throws -> Void = { try FileManager.default.trashItem( at: $0, resultingItemURL: nil ) }, exportFile: @escaping ( URL, URL ) throws -> Void = { try MemoryExporter.export( file: $0, to: $1 ) }, exportProject: @escaping @Sendable ( URL, URL ) throws -> Void = { try MemoryExporter.export( memoryDirectory: $0, to: $1 ) } )
    {
        self.projectsDirectory = projectsDirectory
        self.trashItem         = trashItem
        self.exportFile        = exportFile
        self.exportProject     = exportProject
    }

    /// Exports a copy of the currently selected memory file to `destination`.
    ///
    /// Does nothing when no file is selected (the menu and toolbar actions are
    /// disabled in that case). Throws if the copy fails, surfacing the error to
    /// the caller.
    func exportCurrentFile( to destination: URL ) throws
    {
        guard let file = self.selectedMemoryFile
        else
        {
            return
        }

        try self.exportFile( file.url, destination )
    }

    /// Exports all of `project`'s memory files into `destination`, preserving
    /// their structure relative to the `memory/` folder.
    ///
    /// The copy runs off the main actor so a large export does not block the UI.
    /// Throws if the export fails, surfacing the error to the caller.
    func exportProject( _ project: Project, to destination: URL ) async throws
    {
        let source = project.memoryDirectoryURL
        let export = self.exportProject

        try await Task.detached
        {
            try export( source, destination )
        }
        .value
    }

    /// Moves a project's entire folder to the Trash, then drops it from the
    /// list and clears the selection if it pointed at the trashed project.
    ///
    /// Throws if the trash operation fails, leaving the list unchanged.
    func trashProject( _ project: Project ) throws
    {
        try self.trashItem( project.folderURL )

        self.forget( project )
    }

    /// Moves a single memory file to the Trash, drops it from the file list, and
    /// repoints the selection to the index (or first remaining file). When no
    /// files remain, the project is dropped from the list as well.
    ///
    /// Throws if the trash operation fails, leaving everything unchanged.
    func trashFile( _ file: MemoryFile ) throws
    {
        try self.trashItem( file.url )

        self.memoryFiles.removeAll { $0.id == file.id }

        if self.selectedFile == file.id
        {
            self.selectedFile = ( self.memoryFiles.first { $0.isIndex } ?? self.memoryFiles.first )?.id
        }

        if self.memoryFiles.isEmpty, let project = self.selectedProject
        {
            self.forget( project )
        }
    }

    /// Moves the project's entire `memory/` folder to the Trash. The project no
    /// longer has any memory, so it is dropped from the list and its files
    /// cleared.
    ///
    /// Throws if the trash operation fails, leaving everything unchanged.
    func trashAllMemory( _ project: Project ) throws
    {
        try self.trashItem( project.memoryDirectoryURL )

        self.memoryFiles  = []
        self.selectedFile = nil

        self.forget( project )
    }

    /// Removes a project from the list and clears the selection if it pointed
    /// at it.
    private func forget( _ project: Project )
    {
        self.projects.removeAll { $0.id == project.id }

        if self.selection == project.id
        {
            self.selection = nil
        }
    }

    /// Discovers the projects under ``projectsDirectory`` off the main actor and
    /// publishes the result.
    func loadProjects() async
    {
        let directory = self.projectsDirectory
        let projects  = await Task.detached
        {
            MemoryDiscovery.discoverProjects( in: directory )
        }
        .value

        self.projects = projects

        if let selection = self.selection, projects.contains( where: { $0.id == selection } ) == false
        {
            self.selection = nil
        }
    }

    /// Lists the memory files of the selected project off the main actor and
    /// publishes them, defaulting the selection to the index (`MEMORY.md`) when
    /// present, otherwise the first file. Clears the files when no project is
    /// selected.
    func loadMemoryFiles() async
    {
        guard let project = self.selectedProject
        else
        {
            self.memoryFiles  = []
            self.selectedFile = nil

            return
        }

        let directory = project.memoryDirectoryURL
        let files     = await Task.detached
        {
            MemoryFileLister.files( in: directory )
        }
        .value

        self.memoryFiles  = files
        self.selectedFile = ( files.first { $0.isIndex } ?? files.first )?.id
    }
}

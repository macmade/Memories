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

    /// The directory scanned for projects.
    let projectsDirectory: URL

    /// Moves an item to the Trash. Injectable so tests need not touch the real
    /// Trash; defaults to `FileManager.trashItem(at:resultingItemURL:)`.
    private let trashItem: ( URL ) throws -> Void

    /// The currently selected project, resolved from ``selection``.
    var selectedProject: Project?
    {
        self.projects.first { $0.id == self.selection }
    }

    init( projectsDirectory: URL = MemoryDiscovery.defaultProjectsDirectory, trashItem: @escaping ( URL ) throws -> Void = { try FileManager.default.trashItem( at: $0, resultingItemURL: nil ) } )
    {
        self.projectsDirectory = projectsDirectory
        self.trashItem         = trashItem
    }

    /// Moves a project's entire folder to the Trash, then drops it from the
    /// list and clears the selection if it pointed at the trashed project.
    ///
    /// Throws if the trash operation fails, leaving the list unchanged.
    func trashProject( _ project: Project ) throws
    {
        try self.trashItem( project.folderURL )

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
    }
}

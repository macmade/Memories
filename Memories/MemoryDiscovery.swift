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

/// Discovers Claude projects that own a memory index.
enum MemoryDiscovery
{
    /// The default location Claude stores its per-project data in.
    static var defaultProjectsDirectory: URL
    {
        FileManager.default.homeDirectoryForCurrentUser.appending( path: ".claude", directoryHint: .isDirectory ).appending( path: "projects", directoryHint: .isDirectory )
    }

    /// Scans `projectsDirectory` and returns one ``Project`` per immediate
    /// subdirectory that contains a `memory/MEMORY.md` file.
    ///
    /// The result is sorted by title, case-insensitively. A missing or
    /// unreadable directory yields an empty array rather than an error.
    ///
    /// For projects whose real directory exists and is a git repository, the
    /// `origin` repository name and current branch are attached.
    static func discoverProjects( in projectsDirectory: URL = MemoryDiscovery.defaultProjectsDirectory, fileManager: FileManager = .default, resolver: ProjectPathResolver = ProjectPathResolver(), gitInspector: GitInspecting = GitInspector() ) -> [ Project ]
    {
        let entries = ( try? fileManager.contentsOfDirectory( at: projectsDirectory, includingPropertiesForKeys: [ .isDirectoryKey ], options: [ .skipsHiddenFiles ] ) ) ?? []

        let projects = entries.compactMap
        {
            url -> Project? in

            guard ( try? url.resourceValues( forKeys: [ .isDirectoryKey ] ) )?.isDirectory == true
            else
            {
                return nil
            }

            let base = Project( folderURL: url, decodedPath: resolver.resolvedPath( forFolder: url ) )

            guard MemoryFileLister.files( in: base.memoryDirectoryURL, fileManager: fileManager ).isEmpty == false
            else
            {
                return nil
            }

            let git = base.resolvedDirectoryURL.flatMap { gitInspector.info( forDirectory: $0 ) }

            return Project( folderURL: url, decodedPath: base.decodedPath, repositoryName: git?.repositoryName, branch: git?.branch, isGitRepository: git != nil )
        }

        return projects.sorted
        {
            $0.title.localizedCaseInsensitiveCompare( $1.title ) == .orderedAscending
        }
    }
}

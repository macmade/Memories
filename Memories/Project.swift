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

/// A Claude project that owns a memory index.
///
/// One value corresponds to one directory under `~/.claude/projects/`. The
/// directory name is an encoded filesystem path where every path separator has
/// been replaced by a dash (e.g. `-Users-macmade-Documents-Memories`).
struct Project: Identifiable, Hashable, Sendable
{
    /// The encoded directory name, used as the stable identity of the project.
    let encodedName: String

    /// The reconstructed original filesystem path of the project.
    let decodedPath: String

    /// The human-readable project name, i.e. the last component of the decoded path.
    let displayName: String

    /// The project directory under `~/.claude/projects/`.
    let folderURL: URL

    /// The `memory/MEMORY.md` index file inside the project directory.
    let memoryURL: URL

    /// The repository name from the `origin` remote, when the project is a git
    /// repository with an origin; otherwise `nil`.
    let repositoryName: String?

    /// The checked-out git branch, when the project is a git repository on a
    /// branch; otherwise `nil`.
    let branch: String?

    var id: String { self.encodedName }

    /// The name shown for the project: the repository name when available,
    /// otherwise the last component of the decoded path.
    var title: String
    {
        self.repositoryName ?? self.displayName
    }

    /// The real project directory on disk, or `nil` when the decoded path could
    /// not be resolved to an existing directory (e.g. it fell back to naive
    /// decoding, or the repository has since moved or been deleted).
    var resolvedDirectoryURL: URL?
    {
        let url = URL( fileURLWithPath: self.decodedPath, isDirectory: true )

        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists( atPath: url.path, isDirectory: &isDirectory ), isDirectory.boolValue
        else
        {
            return nil
        }

        return url
    }

    /// Builds a project from its directory under `~/.claude/projects/`.
    ///
    /// `decodedPath` is the resolved real filesystem path; when omitted it falls
    /// back to naive `-` → `/` decoding of the directory name.
    init( folderURL: URL, decodedPath: String? = nil, repositoryName: String? = nil, branch: String? = nil )
    {
        self.folderURL      = folderURL
        self.encodedName    = folderURL.lastPathComponent
        self.decodedPath    = decodedPath ?? Project.decodePath( self.encodedName )
        self.displayName    = URL( fileURLWithPath: self.decodedPath ).lastPathComponent
        self.memoryURL      = folderURL.appending( path: "memory", directoryHint: .isDirectory ).appending( path: "MEMORY.md" )
        self.repositoryName = repositoryName
        self.branch         = branch
    }

    /// Decodes an encoded project directory name back into a filesystem path.
    ///
    /// Decoding simply turns each dash into a slash. This is lossy: any original
    /// path segment that itself contained a dash cannot be recovered, since every
    /// dash becomes a separator.
    static func decodePath( _ encodedName: String ) -> String
    {
        encodedName.replacingOccurrences( of: "-", with: "/" )
    }
}

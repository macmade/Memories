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

/// A ``GitInspecting`` backed by the `git` command-line tool.
///
/// Using `git` rather than parsing `.git` by hand handles worktrees, shared
/// remotes, and detached heads correctly.
struct GitInspector: GitInspecting
{
    func info( forDirectory url: URL ) -> GitInfo?
    {
        guard self.run( [ "rev-parse", "--is-inside-work-tree" ], in: url )?.trimmed == "true"
        else
        {
            return nil
        }

        let branch = self.run( [ "branch", "--show-current" ], in: url )?.trimmed.nonEmpty
        let origin = self.run( [ "remote", "get-url", "origin" ], in: url )?.trimmed.nonEmpty

        return GitInfo( repositoryName: origin.flatMap( GitInspector.repositoryName( fromOriginURL: ) ), branch: branch )
    }

    /// Derives the repository name from an `origin` remote URL, stripping a
    /// trailing slash and `.git` suffix and taking the last path component.
    static func repositoryName( fromOriginURL url: String ) -> String?
    {
        var name = url.trimmingCharacters( in: .whitespacesAndNewlines )

        if name.hasSuffix( "/" )
        {
            name.removeLast()
        }

        if name.hasSuffix( ".git" )
        {
            name.removeLast( 4 )
        }

        if let separator = name.lastIndex( where: { $0 == "/" || $0 == ":" } )
        {
            name = String( name[ name.index( after: separator )... ] )
        }

        return name.isEmpty ? nil : name
    }

    private func run( _ arguments: [ String ], in directory: URL ) -> String?
    {
        let process = Process()

        process.executableURL  = URL( fileURLWithPath: "/usr/bin/git" )
        process.arguments      = [ "-C", directory.path ] + arguments
        process.standardError  = Pipe()

        let pipe = Pipe()

        process.standardOutput = pipe

        do
        {
            try process.run()
        }
        catch
        {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()

        process.waitUntilExit()

        guard process.terminationStatus == 0
        else
        {
            return nil
        }

        return String( data: data, encoding: .utf8 )
    }
}

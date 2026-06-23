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
@testable import Memories
import Testing

struct GitInspectorTests
{
    // MARK: - Repository name parsing

    @Test( arguments:
    [
        ( "git@github.com:macmade/iMazing-Mac.git", "iMazing-Mac" ),
        ( "https://github.com/macmade/Memories.git", "Memories" ),
        ( "https://github.com/macmade/Memories", "Memories" ),
        ( "https://github.com/macmade/Memories.git/", "Memories" ),
        ( "ssh://git@host.example.com/team/Project.git", "Project" ),
        ( "/Users/macmade/repos/local-repo.git", "local-repo" ),
    ] )
    func repositoryNameIsParsedFromOriginURL( url: String, expected: String ) throws
    {
        #expect( GitInspector.repositoryName( fromOriginURL: url ) == expected )
    }

    // MARK: - Inspecting a real repository

    @Test
    func inspectingAGitRepositoryReportsOriginNameAndBranch() throws
    {
        let directory = try TemporaryGitDirectory()

        try directory.git( "init", "-b", "feature-x" )
        try directory.git( "remote", "add", "origin", "git@github.com:macmade/SampleRepo.git" )

        let info = try #require( GitInspector().info( forDirectory: directory.url ) )

        #expect( info.repositoryName == "SampleRepo" )
        #expect( info.branch == "feature-x" )
    }

    @Test
    func inspectingANonRepositoryReturnsNil() throws
    {
        let directory = try TemporaryGitDirectory()

        #expect( GitInspector().info( forDirectory: directory.url ) == nil )
    }
}

/// A self-cleaning temporary directory with a helper to run `git` inside it.
private final class TemporaryGitDirectory
{
    let url: URL

    init() throws
    {
        self.url = FileManager.default.temporaryDirectory.appending( path: "GitInspectorTests-\( UUID().uuidString )", directoryHint: .isDirectory )

        try FileManager.default.createDirectory( at: self.url, withIntermediateDirectories: true )
    }

    deinit
    {
        try? FileManager.default.removeItem( at: self.url )
    }

    func git( _ arguments: String... ) throws
    {
        let process = Process()

        process.executableURL = URL( fileURLWithPath: "/usr/bin/git" )
        process.arguments     = [ "-C", self.url.path ] + arguments
        process.standardOutput = Pipe()
        process.standardError  = Pipe()

        try process.run()
        process.waitUntilExit()
    }
}

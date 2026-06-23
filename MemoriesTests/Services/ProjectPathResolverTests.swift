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

struct ProjectPathResolverTests
{
    @Test
    func registryPathTakesPriorityAndDisambiguatesDashes() throws
    {
        let real     = "/Users/macmade/Documents/Macmade/DigiDNA/GitHub/iMazing-Mac/main"
        let folder   = URL( fileURLWithPath: "/private/tmp/projects/-Users-macmade-Documents-Macmade-DigiDNA-GitHub-iMazing-Mac-main", isDirectory: true )
        let resolver = ProjectPathResolver( registryPaths: [ real ] )

        #expect( resolver.resolvedPath( forFolder: folder ) == real )
    }

    @Test
    func transcriptCwdIsUsedWhenNotInTheRegistry() throws
    {
        let tree   = try TemporaryDirectory()
        let folder = tree.url.appending( path: "-a-b-c", directoryHint: .isDirectory )

        try FileManager.default.createDirectory( at: folder, withIntermediateDirectories: true )
        try "{\"type\":\"summary\"}\n{\"cwd\":\"/a-b/c\",\"role\":\"user\"}\n".write( to: folder.appending( path: "session.jsonl" ), atomically: true, encoding: .utf8 )

        let resolver = ProjectPathResolver( registryPaths: [] )

        #expect( resolver.resolvedPath( forFolder: folder ) == "/a-b/c" )
    }

    @Test
    func naiveDecodingIsTheFinalFallback() throws
    {
        let folder   = URL( fileURLWithPath: "/private/tmp/projects/-x-y-z", isDirectory: true )
        let resolver = ProjectPathResolver( registryPaths: [] )

        #expect( resolver.resolvedPath( forFolder: folder ) == "/x/y/z" )
    }

    @Test
    func filesystemProbeGroupsExistingDashedFolders() throws
    {
        let tree = try TemporaryDirectory()

        try FileManager.default.createDirectory( at: tree.url.appending( path: "iMazing-Mac", directoryHint: .isDirectory ).appending( path: "main", directoryHint: .isDirectory ), withIntermediateDirectories: true )

        let resolved = ProjectPathResolver.resolveByFilesystem( tokens: [ "iMazing", "Mac", "main" ], under: tree.url, fileManager: .default )

        #expect( resolved == [ "iMazing-Mac", "main" ] )
        #expect( ProjectPathResolver.resolveByFilesystem( tokens: [ "does", "not", "exist" ], under: tree.url, fileManager: .default ) == nil )
    }
}

/// A self-cleaning temporary directory.
private final class TemporaryDirectory
{
    let url: URL

    init() throws
    {
        self.url = FileManager.default.temporaryDirectory.appending( path: "ProjectPathResolverTests-\( UUID().uuidString )", directoryHint: .isDirectory )

        try FileManager.default.createDirectory( at: self.url, withIntermediateDirectories: true )
    }

    deinit
    {
        try? FileManager.default.removeItem( at: self.url )
    }
}

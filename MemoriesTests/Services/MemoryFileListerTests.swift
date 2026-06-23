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

struct MemoryFileListerTests
{
    @Test
    func listsMarkdownFilesRecursivelyAndIgnoresOtherFiles() throws
    {
        let tree = try TemporaryDirectory()

        try tree.write( "# index", to: "MEMORY.md" )
        try tree.write( "a",       to: "alpha.md" )
        try tree.write( "b",       to: "nested/beta.md" )
        try tree.write( "x",       to: "notes.txt" )
        try tree.write( "y",       to: "nested/image.png" )

        let names = MemoryFileLister.files( in: tree.url ).map { $0.name }

        #expect( names.contains( "MEMORY.md" ) )
        #expect( names.contains( "alpha.md" ) )
        #expect( names.contains( "beta.md" ) )
        #expect( names.contains( "notes.txt" ) == false )
        #expect( names.contains( "image.png" ) == false )
        #expect( names.count == 3 )
    }

    @Test
    func theIndexFileSortsFirstThenAlphabetically() throws
    {
        let tree = try TemporaryDirectory()

        try tree.write( "z", to: "Zebra.md" )
        try tree.write( "a", to: "apple.md" )
        try tree.write( "i", to: "MEMORY.md" )

        let files = MemoryFileLister.files( in: tree.url )

        #expect( files.map { $0.name } == [ "MEMORY.md", "apple.md", "Zebra.md" ] )
        #expect( files.first?.isIndex == true )
    }

    @Test
    func aFolderWithoutMarkdownReturnsEmpty() throws
    {
        let tree = try TemporaryDirectory()

        try tree.write( "x", to: "notes.txt" )

        #expect( MemoryFileLister.files( in: tree.url ).isEmpty )
    }

    @Test
    func aMissingFolderReturnsEmpty() throws
    {
        let missing = FileManager.default.temporaryDirectory.appending( path: "missing-\( UUID().uuidString )", directoryHint: .isDirectory )

        #expect( MemoryFileLister.files( in: missing ).isEmpty )
    }
}

/// A self-cleaning temporary directory with a helper to write nested files.
private final class TemporaryDirectory
{
    let url: URL

    init() throws
    {
        self.url = FileManager.default.temporaryDirectory.appending( path: "MemoryFileListerTests-\( UUID().uuidString )", directoryHint: .isDirectory )

        try FileManager.default.createDirectory( at: self.url, withIntermediateDirectories: true )
    }

    deinit
    {
        try? FileManager.default.removeItem( at: self.url )
    }

    func write( _ contents: String, to relativePath: String ) throws
    {
        let url = self.url.appending( path: relativePath )

        try FileManager.default.createDirectory( at: url.deletingLastPathComponent(), withIntermediateDirectories: true )
        try contents.write( to: url, atomically: true, encoding: .utf8 )
    }
}

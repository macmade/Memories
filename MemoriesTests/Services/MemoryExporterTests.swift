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

struct MemoryExporterTests
{
    @Test
    func exportingAFileCopiesItToTheDestinationCreatingDirectories() throws
    {
        let tree = try TemporaryDirectory()

        try tree.write( "hello", to: "MEMORY.md" )

        let source      = tree.url.appending( path: "MEMORY.md" )
        let destination = tree.url.appending( path: "out/nested/MEMORY.md" )

        try MemoryExporter.export( file: source, to: destination )

        #expect( try String( contentsOf: destination, encoding: .utf8 ) == "hello" )
    }

    @Test
    func exportingAFileOverwritesAnExistingDestination() throws
    {
        let tree = try TemporaryDirectory()

        try tree.write( "new", to: "MEMORY.md" )
        try tree.write( "old", to: "out/MEMORY.md" )

        let source      = tree.url.appending( path: "MEMORY.md" )
        let destination = tree.url.appending( path: "out/MEMORY.md" )

        try MemoryExporter.export( file: source, to: destination )

        #expect( try String( contentsOf: destination, encoding: .utf8 ) == "new" )
    }

    @Test
    func exportingAMissingFileThrowsSourceNotFound() throws
    {
        let tree = try TemporaryDirectory()

        let source      = tree.url.appending( path: "missing.md" )
        let destination = tree.url.appending( path: "out/missing.md" )

        #expect( throws: MemoryExportError.sourceNotFound( source ) )
        {
            try MemoryExporter.export( file: source, to: destination )
        }
    }

    @Test
    func exportingAProjectCopiesEveryMarkdownFilePreservingStructure() throws
    {
        let tree = try TemporaryDirectory()

        try tree.write( "# index", to: "memory/MEMORY.md" )
        try tree.write( "a",       to: "memory/alpha.md" )
        try tree.write( "b",       to: "memory/nested/beta.md" )
        try tree.write( "x",       to: "memory/notes.txt" )

        let memory      = tree.url.appending( path: "memory", directoryHint: .isDirectory )
        let destination = tree.url.appending( path: "export", directoryHint: .isDirectory )

        try MemoryExporter.export( memoryDirectory: memory, to: destination )

        #expect( try String( contentsOf: destination.appending( path: "MEMORY.md" ), encoding: .utf8 ) == "# index" )
        #expect( try String( contentsOf: destination.appending( path: "alpha.md" ), encoding: .utf8 ) == "a" )
        #expect( try String( contentsOf: destination.appending( path: "nested/beta.md" ), encoding: .utf8 ) == "b" )
        #expect( FileManager.default.fileExists( atPath: destination.appending( path: "notes.txt" ).path ) == false )
    }

    @Test
    func exportingAProjectOverwritesExistingFiles() throws
    {
        let tree = try TemporaryDirectory()

        try tree.write( "new", to: "memory/MEMORY.md" )
        try tree.write( "old", to: "export/MEMORY.md" )

        let memory      = tree.url.appending( path: "memory", directoryHint: .isDirectory )
        let destination = tree.url.appending( path: "export", directoryHint: .isDirectory )

        try MemoryExporter.export( memoryDirectory: memory, to: destination )

        #expect( try String( contentsOf: destination.appending( path: "MEMORY.md" ), encoding: .utf8 ) == "new" )
    }

    @Test
    func exportingAProjectWithoutMarkdownCopiesNothing() throws
    {
        let tree = try TemporaryDirectory()

        try tree.write( "x", to: "memory/notes.txt" )

        let memory      = tree.url.appending( path: "memory", directoryHint: .isDirectory )
        let destination = tree.url.appending( path: "export", directoryHint: .isDirectory )

        try MemoryExporter.export( memoryDirectory: memory, to: destination )

        #expect( FileManager.default.fileExists( atPath: destination.appending( path: "notes.txt" ).path ) == false )
    }
}

/// A self-cleaning temporary directory with a helper to write nested files.
private final class TemporaryDirectory
{
    let url: URL

    init() throws
    {
        self.url = FileManager.default.temporaryDirectory.appending( path: "MemoryExporterTests-\( UUID().uuidString )", directoryHint: .isDirectory )

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

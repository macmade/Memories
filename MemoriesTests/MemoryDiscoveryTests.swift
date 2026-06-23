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

struct MemoryDiscoveryTests
{
    // MARK: - Path decoding

    @Test
    func decodingReplacesDashesWithSlashes() throws
    {
        let decoded = Project.decodePath( "-Users-macmade-Documents-Macmade-GitHub-Memories" )

        #expect( decoded == "/Users/macmade/Documents/Macmade/GitHub/Memories" )
    }

    @Test
    func displayNameIsTheLastPathComponent() throws
    {
        let project = Project( folderURL: URL( fileURLWithPath: "/tmp/projects/-Users-macmade-Documents-Macmade-GitHub-Memories", isDirectory: true ) )

        #expect( project.displayName == "Memories" )
        #expect( project.decodedPath == "/Users/macmade/Documents/Macmade/GitHub/Memories" )
    }

    @Test
    func encodedNameIsTheFolderName() throws
    {
        let project = Project( folderURL: URL( fileURLWithPath: "/tmp/projects/-Users-macmade-Foo", isDirectory: true ) )

        #expect( project.encodedName == "-Users-macmade-Foo" )
    }

    @Test
    func titleIsTheRepositoryNameWhenAvailableOtherwiseTheLeaf() throws
    {
        let folder = URL( fileURLWithPath: "/private/tmp/projects/-Users-macmade-iMazing-Mac-main", isDirectory: true )

        let plain = Project( folderURL: folder, decodedPath: "/Users/macmade/iMazing-Mac/main" )
        let repo  = Project( folderURL: folder, decodedPath: "/Users/macmade/iMazing-Mac/main", repositoryName: "iMazing-Mac", branch: "main" )

        #expect( plain.title == "main" )
        #expect( repo.title  == "iMazing-Mac" )
        #expect( repo.branch == "main" )
    }

    @Test
    func iconReflectsWhetherTheProjectIsAGitRepository() throws
    {
        let folder = URL( fileURLWithPath: "/private/tmp/projects/-Users-macmade-Foo", isDirectory: true )

        let plain = Project( folderURL: folder )
        let git   = Project( folderURL: folder, repositoryName: "Foo", branch: "main", isGitRepository: true )

        #expect( plain.isGitRepository == false )
        #expect( plain.iconSystemName == "folder" )
        #expect( git.isGitRepository )
        #expect( git.iconSystemName == "shippingbox" )
    }

    @Test
    func resolvedDirectoryURLIsTheRealPathWhenItExists() throws
    {
        let directory = FileManager.default.temporaryDirectory.appending( path: "MemoriesTests-real-\( UUID().uuidString )", directoryHint: .isDirectory )

        try FileManager.default.createDirectory( at: directory, withIntermediateDirectories: true )

        defer { try? FileManager.default.removeItem( at: directory ) }

        let project = Project( folderURL: URL( fileURLWithPath: "/private/tmp/projects/-encoded", isDirectory: true ), decodedPath: directory.path )

        #expect( project.resolvedDirectoryURL?.path == directory.path )
    }

    @Test
    func resolvedDirectoryURLIsNilWhenThePathDoesNotExist() throws
    {
        let project = Project( folderURL: URL( fileURLWithPath: "/private/tmp/projects/-x-y-z", isDirectory: true ), decodedPath: "/x/y/z-\( UUID().uuidString )" )

        #expect( project.resolvedDirectoryURL == nil )
    }

    @Test
    func memoryURLPointsAtTheMemoryIndex() throws
    {
        let folder  = URL( fileURLWithPath: "/tmp/projects/-Users-macmade-Foo", isDirectory: true )
        let project = Project( folderURL: folder )

        #expect( project.memoryURL.path == "/tmp/projects/-Users-macmade-Foo/memory/MEMORY.md" )
        #expect( project.folderURL.path == "/tmp/projects/-Users-macmade-Foo" )
    }

    @Test
    func decodingIsLossyWhenOriginalSegmentsContainDashes() throws
    {
        // A real path segment that itself contains a dash (e.g. "my-project") cannot be
        // recovered, since every dash becomes a slash. This documents the known limitation.
        let decoded = Project.decodePath( "-Users-macmade-my-project" )

        #expect( decoded == "/Users/macmade/my/project" )
    }

    // MARK: - Discovery

    @Test
    func discoveryReturnsOneProjectPerDirectoryWithAMemoryIndex() throws
    {
        let root = try TemporaryTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.makeProject( encodedName: "-Users-macmade-Beta", withMemory: true )
        try root.makeProject( encodedName: "-Users-macmade-NoMemory", withMemory: false )

        let projects = MemoryDiscovery.discoverProjects( in: root.url )

        #expect( projects.count == 2 )
        #expect( projects.contains { $0.encodedName == "-Users-macmade-Alpha" } )
        #expect( projects.contains { $0.encodedName == "-Users-macmade-Beta" } )
        #expect( projects.contains { $0.encodedName == "-Users-macmade-NoMemory" } == false )
    }

    @Test
    func discoveryAcceptsAProjectWithAnyMarkdownFileEvenWithoutAnIndex() throws
    {
        let root   = try TemporaryTree()
        let memory = root.url.appending( path: "-Users-macmade-NoIndex", directoryHint: .isDirectory ).appending( path: "memory", directoryHint: .isDirectory )

        try FileManager.default.createDirectory( at: memory, withIntermediateDirectories: true )
        try "note".write( to: memory.appending( path: "note.md" ), atomically: true, encoding: .utf8 )

        let projects = MemoryDiscovery.discoverProjects( in: root.url )

        #expect( projects.contains { $0.encodedName == "-Users-macmade-NoIndex" } )
    }

    @Test
    func discoveryIgnoresLooseFilesAndEmptyMemoryFolders() throws
    {
        let root = try TemporaryTree()

        // A loose file at the top level must not be treated as a project.
        try Data().write( to: root.url.appending( path: "loose.txt" ) )

        // A project folder with a memory directory but no MEMORY.md must be ignored.
        let folder = root.url.appending( path: "-Users-macmade-Empty", directoryHint: .isDirectory )
        try FileManager.default.createDirectory( at: folder.appending( path: "memory", directoryHint: .isDirectory ), withIntermediateDirectories: true )

        let projects = MemoryDiscovery.discoverProjects( in: root.url )

        #expect( projects.isEmpty )
    }

    @Test
    func discoverySortsByDisplayNameCaseInsensitively() throws
    {
        let root = try TemporaryTree()

        try root.makeProject( encodedName: "-Users-macmade-Zebra", withMemory: true )
        try root.makeProject( encodedName: "-Users-macmade-apple", withMemory: true )
        try root.makeProject( encodedName: "-Users-macmade-Mango", withMemory: true )

        let names = MemoryDiscovery.discoverProjects( in: root.url ).map { $0.displayName }

        #expect( names == [ "apple", "Mango", "Zebra" ] )
    }

    @Test
    func discoveryOfMissingDirectoryReturnsEmpty() throws
    {
        let missing = URL( fileURLWithPath: "/tmp/this-path-should-not-exist-\( UUID().uuidString )", isDirectory: true )

        #expect( MemoryDiscovery.discoverProjects( in: missing ).isEmpty )
    }

    @Test
    func discoveryAppliesTheResolvedPathToProjects() throws
    {
        let root = try TemporaryTree()

        try root.makeProject( encodedName: "-a-b-c", withMemory: true )

        let resolver = ProjectPathResolver( registryPaths: [ "/a-b/c" ] )
        let projects = MemoryDiscovery.discoverProjects( in: root.url, resolver: resolver )

        let project = try #require( projects.first )

        #expect( project.decodedPath == "/a-b/c" )
        #expect( project.displayName == "c" )
    }
}

/// A self-cleaning temporary directory used to build project-tree fixtures.
private final class TemporaryTree
{
    let url: URL

    init() throws
    {
        self.url = FileManager.default.temporaryDirectory.appending( path: "MemoriesTests-\( UUID().uuidString )", directoryHint: .isDirectory )

        try FileManager.default.createDirectory( at: self.url, withIntermediateDirectories: true )
    }

    deinit
    {
        try? FileManager.default.removeItem( at: self.url )
    }

    func makeProject( encodedName: String, withMemory: Bool ) throws
    {
        let folder = self.url.appending( path: encodedName, directoryHint: .isDirectory )
        let memory = folder.appending( path: "memory", directoryHint: .isDirectory )

        try FileManager.default.createDirectory( at: memory, withIntermediateDirectories: true )

        if withMemory
        {
            try "# Memory\n".data( using: .utf8 )?.write( to: memory.appending( path: "MEMORY.md" ) )
        }
    }
}

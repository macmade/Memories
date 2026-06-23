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

@MainActor
struct AppModelTests
{
    @Test
    func loadingPopulatesProjectsSortedByDisplayName() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Zebra", withMemory: true )
        try root.makeProject( encodedName: "-Users-macmade-apple", withMemory: true )
        try root.makeProject( encodedName: "-Users-macmade-NoMemory", withMemory: false )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        #expect( model.projects.map { $0.displayName } == [ "apple", "Zebra" ] )
    }

    @Test
    func loadingAnEmptyDirectoryLeavesNoProjects() async throws
    {
        let root  = try TemporaryProjectTree()
        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        #expect( model.projects.isEmpty )
    }

    @Test
    func selectionStartsEmptyAndCanBeSet() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )

        let model = AppModel( projectsDirectory: root.url )

        #expect( model.selection == nil )

        await model.loadProjects()

        model.selection = model.projects.first?.id

        #expect( model.selection == "-Users-macmade-Alpha" )
    }

    @Test
    func selectedProjectResolvesFromSelection() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.makeProject( encodedName: "-Users-macmade-Beta", withMemory: true )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        #expect( model.selectedProject == nil )

        model.selection = "-Users-macmade-Beta"

        #expect( model.selectedProject?.displayName == "Beta" )

        model.selection = "-does-not-exist"

        #expect( model.selectedProject == nil )
    }

    @Test
    func viewModeDefaultsToPreview() async throws
    {
        let model = AppModel( projectsDirectory: FileManager.default.temporaryDirectory )

        #expect( model.viewMode == .preview )
    }

    @Test
    func trashingRemovesTheProjectAndTrashesItsFolder() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.makeProject( encodedName: "-Users-macmade-Beta", withMemory: true )

        var trashed: [ URL ] = []
        let model            = AppModel( projectsDirectory: root.url, trashItem: { trashed.append( $0 ) } )

        await model.loadProjects()

        let alpha = try #require( model.projects.first { $0.displayName == "Alpha" } )

        try model.trashProject( alpha )

        #expect( model.projects.contains { $0.id == alpha.id } == false )
        #expect( model.projects.count == 1 )
        #expect( trashed == [ alpha.folderURL ] )
    }

    @Test
    func trashingTheSelectedProjectClearsTheSelection() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )

        let model = AppModel( projectsDirectory: root.url, trashItem: { _ in } )

        await model.loadProjects()

        let alpha = try #require( model.projects.first )

        model.selection = alpha.id

        try model.trashProject( alpha )

        #expect( model.selection == nil )
    }

    @Test
    func trashingFailurePropagatesAndKeepsTheProject() async throws
    {
        struct TrashError: Error {}

        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )

        let model = AppModel( projectsDirectory: root.url, trashItem: { _ in throw TrashError() } )

        await model.loadProjects()

        let alpha = try #require( model.projects.first )

        #expect( throws: TrashError.self )
        {
            try model.trashProject( alpha )
        }

        #expect( model.projects.count == 1 )
    }

    @Test
    func trashingTheMemoryTrashesOnlyTheIndexFileAndRemovesTheProject() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.makeProject( encodedName: "-Users-macmade-Beta", withMemory: true )

        var trashed: [ URL ] = []
        let model            = AppModel( projectsDirectory: root.url, trashItem: { trashed.append( $0 ) } )

        await model.loadProjects()

        let alpha = try #require( model.projects.first { $0.displayName == "Alpha" } )

        try model.trashMemory( alpha )

        #expect( trashed == [ alpha.memoryURL ] )
        #expect( model.projects.contains { $0.id == alpha.id } == false )
        #expect( model.projects.count == 1 )
    }

    @Test
    func trashingTheMemoryClearsTheSelectionIfSelected() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )

        let model = AppModel( projectsDirectory: root.url, trashItem: { _ in } )

        await model.loadProjects()

        let alpha = try #require( model.projects.first )

        model.selection = alpha.id

        try model.trashMemory( alpha )

        #expect( model.selection == nil )
    }

    @Test
    func trashingTheMemoryFailurePropagatesAndKeepsTheProject() async throws
    {
        struct TrashError: Error {}

        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )

        let model = AppModel( projectsDirectory: root.url, trashItem: { _ in throw TrashError() } )

        await model.loadProjects()

        let alpha = try #require( model.projects.first )

        #expect( throws: TrashError.self )
        {
            try model.trashMemory( alpha )
        }

        #expect( model.projects.count == 1 )
    }

    @Test
    func reloadingClearsTheSelectionWhenTheSelectedProjectDisappears() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.makeProject( encodedName: "-Users-macmade-Beta", withMemory: true )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        model.selection = "-Users-macmade-Beta"

        try FileManager.default.removeItem( at: root.url.appending( path: "-Users-macmade-Beta", directoryHint: .isDirectory ) )

        await model.loadProjects()

        #expect( model.selection == nil )
    }

    @Test
    func reloadingKeepsTheSelectionWhenTheSelectedProjectRemains() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadProjects()

        #expect( model.selection == "-Users-macmade-Alpha" )
    }

    @Test
    func loadingMemoryFilesDefaultsToTheIndex() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.writeMemoryFile( "note.md", inProject: "-Users-macmade-Alpha" )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        #expect( model.memoryFiles.count == 2 )
        #expect( model.selectedMemoryFile?.name == "MEMORY.md" )
        #expect( model.selectedMemoryFile?.isIndex == true )
    }

    @Test
    func loadingMemoryFilesDefaultsToTheFirstFileWhenThereIsNoIndex() async throws
    {
        let root = try TemporaryProjectTree()

        try root.writeMemoryFile( "zeta.md", inProject: "-Users-macmade-Beta" )
        try root.writeMemoryFile( "alpha.md", inProject: "-Users-macmade-Beta" )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        model.selection = "-Users-macmade-Beta"

        await model.loadMemoryFiles()

        #expect( model.memoryFiles.count == 2 )
        #expect( model.selectedMemoryFile?.name == "alpha.md" )
    }

    @Test
    func loadingMemoryFilesWithNoSelectionClearsThem() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()
        await model.loadMemoryFiles()

        #expect( model.memoryFiles.isEmpty )
        #expect( model.selectedFile == nil )
    }
}

/// A self-cleaning temporary directory used to build project-tree fixtures.
private final class TemporaryProjectTree
{
    let url: URL

    init() throws
    {
        self.url = FileManager.default.temporaryDirectory.appending( path: "AppModelTests-\( UUID().uuidString )", directoryHint: .isDirectory )

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

    func writeMemoryFile( _ name: String, inProject encodedName: String ) throws
    {
        let memory = self.url.appending( path: encodedName, directoryHint: .isDirectory ).appending( path: "memory", directoryHint: .isDirectory )

        try FileManager.default.createDirectory( at: memory, withIntermediateDirectories: true )
        try "content".write( to: memory.appending( path: name ), atomically: true, encoding: .utf8 )
    }
}

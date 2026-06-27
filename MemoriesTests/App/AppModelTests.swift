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
    func trashingAFileRemovesItAndRepointsToTheIndex() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.writeMemoryFile( "note.md", inProject: "-Users-macmade-Alpha" )

        var trashed: [ URL ] = []
        let model            = AppModel( projectsDirectory: root.url, trashItem: { trashed.append( $0 ) } )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        let note = try #require( model.memoryFiles.first { $0.name == "note.md" } )

        model.selectedFile = note.id

        try model.trashFile( note )

        #expect( trashed == [ note.url ] )
        #expect( model.memoryFiles.contains { $0.id == note.id } == false )
        #expect( model.memoryFiles.count == 1 )
        #expect( model.selectedMemoryFile?.name == "MEMORY.md" )
    }

    @Test
    func trashingTheLastRemainingFileDropsTheProject() async throws
    {
        let root = try TemporaryProjectTree()

        try root.writeMemoryFile( "only.md", inProject: "-Users-macmade-Solo" )

        let model = AppModel( projectsDirectory: root.url, trashItem: { _ in } )

        await model.loadProjects()

        model.selection = "-Users-macmade-Solo"

        await model.loadMemoryFiles()

        let only = try #require( model.memoryFiles.first )

        try model.trashFile( only )

        #expect( model.memoryFiles.isEmpty )
        #expect( model.selectedFile == nil )
        #expect( model.projects.contains { $0.id == "-Users-macmade-Solo" } == false )
        #expect( model.selection == nil )
    }

    @Test
    func trashingAFileFailurePropagatesAndKeepsTheFile() async throws
    {
        struct TrashError: Error {}

        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )

        let model = AppModel( projectsDirectory: root.url, trashItem: { _ in throw TrashError() } )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        let file = try #require( model.memoryFiles.first )

        #expect( throws: TrashError.self )
        {
            try model.trashFile( file )
        }

        #expect( model.memoryFiles.count == 1 )
    }

    @Test
    func trashingAllMemoryTrashesTheFolderAndDropsTheProject() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.writeMemoryFile( "note.md", inProject: "-Users-macmade-Alpha" )

        var trashed: [ URL ] = []
        let model            = AppModel( projectsDirectory: root.url, trashItem: { trashed.append( $0 ) } )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        let alpha = try #require( model.selectedProject )

        try model.trashAllMemory( alpha )

        #expect( trashed == [ alpha.memoryDirectoryURL ] )
        #expect( model.memoryFiles.isEmpty )
        #expect( model.selectedFile == nil )
        #expect( model.projects.contains { $0.id == alpha.id } == false )
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

    @Test
    func exportingTheCurrentFileCopiesItToTheChosenDestination() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )

        var exported: [ [ URL ] ] = []
        let model                 = AppModel( projectsDirectory: root.url, exportFile: { exported.append( [ $0, $1 ] ) } )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        let file        = try #require( model.selectedMemoryFile )
        let destination = root.url.appending( path: "copy/MEMORY.md" )

        try model.exportCurrentFile( to: destination )

        #expect( exported == [ [ file.url, destination ] ] )
    }

    @Test
    func exportingWithNoSelectedFileDoesNothing() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )

        var exported: [ [ URL ] ] = []
        let model                 = AppModel( projectsDirectory: root.url, exportFile: { exported.append( [ $0, $1 ] ) } )

        await model.loadProjects()

        try model.exportCurrentFile( to: root.url.appending( path: "copy.md" ) )

        #expect( exported.isEmpty )
    }

    @Test
    func exportingTheCurrentFileFailurePropagates() async throws
    {
        struct ExportError: Error {}

        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )

        let model = AppModel( projectsDirectory: root.url, exportFile: { _, _ in throw ExportError() } )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        #expect( throws: ExportError.self )
        {
            try model.exportCurrentFile( to: root.url.appending( path: "copy.md" ) )
        }
    }

    @Test
    func exportingAProjectCopiesItsMemoryWithoutPromptingWhenThereAreNoConflicts() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.writeMemoryFile( "note.md", inProject: "-Users-macmade-Alpha" )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        let alpha       = try #require( model.projects.first )
        let destination = root.url.appending( path: "export", directoryHint: .isDirectory )

        var prompted: [ URL ] = []
        let completed         = try await model.exportProject( alpha, to: destination ) { prompted.append( $0 ); return .overwrite }

        #expect( completed )
        #expect( prompted.isEmpty )
        #expect( FileManager.default.fileExists( atPath: destination.appending( path: "MEMORY.md" ).path ) )
        #expect( FileManager.default.fileExists( atPath: destination.appending( path: "note.md" ).path ) )
    }

    @Test
    func exportingAProjectOverwritesAConflictWhenResolutionIsOverwrite() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        let alpha       = try #require( model.projects.first )
        let destination = root.url.appending( path: "export", directoryHint: .isDirectory )

        try FileManager.default.createDirectory( at: destination, withIntermediateDirectories: true )
        try "old".write( to: destination.appending( path: "MEMORY.md" ), atomically: true, encoding: .utf8 )

        var prompted: [ URL ] = []
        let completed         = try await model.exportProject( alpha, to: destination ) { prompted.append( $0 ); return .overwrite }

        #expect( completed )
        #expect( prompted.map { $0.lastPathComponent } == [ "MEMORY.md" ] )
        #expect( try String( contentsOf: destination.appending( path: "MEMORY.md" ), encoding: .utf8 ) == "# Memory\n" )
    }

    @Test
    func exportingAProjectSkipsAConflictButCopiesTheRestWhenResolutionIsSkip() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.writeMemoryFile( "note.md", inProject: "-Users-macmade-Alpha" )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        let alpha       = try #require( model.projects.first )
        let destination = root.url.appending( path: "export", directoryHint: .isDirectory )

        try FileManager.default.createDirectory( at: destination, withIntermediateDirectories: true )
        try "old".write( to: destination.appending( path: "MEMORY.md" ), atomically: true, encoding: .utf8 )

        let completed = try await model.exportProject( alpha, to: destination ) { _ in .skip }

        #expect( completed )
        #expect( try String( contentsOf: destination.appending( path: "MEMORY.md" ), encoding: .utf8 ) == "old" )
        #expect( try String( contentsOf: destination.appending( path: "note.md" ), encoding: .utf8 ) == "content" )
    }

    @Test
    func cancellingAProjectExportCopiesNothingAndReturnsFalse() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.writeMemoryFile( "note.md", inProject: "-Users-macmade-Alpha" )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        let alpha       = try #require( model.projects.first )
        let destination = root.url.appending( path: "export", directoryHint: .isDirectory )

        try FileManager.default.createDirectory( at: destination, withIntermediateDirectories: true )
        try "old".write( to: destination.appending( path: "MEMORY.md" ), atomically: true, encoding: .utf8 )

        let completed = try await model.exportProject( alpha, to: destination ) { _ in .cancel }

        #expect( completed == false )
        #expect( try String( contentsOf: destination.appending( path: "MEMORY.md" ), encoding: .utf8 ) == "old" )
        #expect( FileManager.default.fileExists( atPath: destination.appending( path: "note.md" ).path ) == false )
    }

    @Test
    func selectingAFileRecordsItInTheProjectHistory() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.writeMemoryFile( "note.md", inProject: "-Users-macmade-Alpha" )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        #expect( model.canGoBack == false )
        #expect( model.canGoForward == false )

        let note = try #require( model.memoryFiles.first { $0.name == "note.md" } )

        model.selectedFile = note.id

        #expect( model.canGoBack )
        #expect( model.canGoForward == false )
    }

    @Test
    func goingBackAndForwardMovesTheSelectedFile() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.writeMemoryFile( "note.md", inProject: "-Users-macmade-Alpha" )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        let note = try #require( model.memoryFiles.first { $0.name == "note.md" } )

        model.selectedFile = note.id

        model.goBack()

        #expect( model.selectedMemoryFile?.name == "MEMORY.md" )
        #expect( model.canGoForward )

        model.goForward()

        #expect( model.selectedMemoryFile?.name == "note.md" )
        #expect( model.canGoForward == false )
    }

    @Test
    func navigatingToANewFileTruncatesTheForwardHistory() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.writeMemoryFile( "a.md", inProject: "-Users-macmade-Alpha" )
        try root.writeMemoryFile( "b.md", inProject: "-Users-macmade-Alpha" )
        try root.writeMemoryFile( "c.md", inProject: "-Users-macmade-Alpha" )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        let a = try #require( model.memoryFiles.first { $0.name == "a.md" } )
        let b = try #require( model.memoryFiles.first { $0.name == "b.md" } )
        let c = try #require( model.memoryFiles.first { $0.name == "c.md" } )

        model.selectedFile = a.id
        model.selectedFile = b.id

        model.goBack()

        #expect( model.selectedMemoryFile?.name == "a.md" )

        model.selectedFile = c.id

        #expect( model.canGoForward == false )

        model.goBack()

        #expect( model.selectedMemoryFile?.name == "a.md" )

        model.goForward()

        #expect( model.selectedMemoryFile?.name == "c.md" )
    }

    @Test
    func historyIsPreservedPerProjectAcrossSwitches() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.writeMemoryFile( "alpha-note.md", inProject: "-Users-macmade-Alpha" )
        try root.makeProject( encodedName: "-Users-macmade-Beta", withMemory: true )
        try root.writeMemoryFile( "beta-note.md", inProject: "-Users-macmade-Beta" )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        let alphaNote = try #require( model.memoryFiles.first { $0.name == "alpha-note.md" } )

        model.selectedFile = alphaNote.id

        model.selection = "-Users-macmade-Beta"

        await model.loadMemoryFiles()

        #expect( model.selectedMemoryFile?.name == "MEMORY.md" )
        #expect( model.canGoBack == false )

        let betaNote = try #require( model.memoryFiles.first { $0.name == "beta-note.md" } )

        model.selectedFile = betaNote.id

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        #expect( model.selectedMemoryFile?.name == "alpha-note.md" )
        #expect( model.canGoBack )

        model.goBack()

        #expect( model.selectedMemoryFile?.name == "MEMORY.md" )

        model.selection = "-Users-macmade-Beta"

        await model.loadMemoryFiles()

        #expect( model.selectedMemoryFile?.name == "beta-note.md" )
        #expect( model.canGoBack )
    }

    @Test
    func reloadingPrunesHistoryEntriesNoLongerOnDisk() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.writeMemoryFile( "n1.md", inProject: "-Users-macmade-Alpha" )
        try root.writeMemoryFile( "n2.md", inProject: "-Users-macmade-Alpha" )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        let n1 = try #require( model.memoryFiles.first { $0.name == "n1.md" } )
        let n2 = try #require( model.memoryFiles.first { $0.name == "n2.md" } )

        model.selectedFile = n1.id
        model.selectedFile = n2.id

        try FileManager.default.removeItem( at: n1.url )

        await model.loadMemoryFiles()

        #expect( model.selectedMemoryFile?.name == "n2.md" )
        #expect( model.canGoBack )

        model.goBack()

        #expect( model.selectedMemoryFile?.name == "MEMORY.md" )
        #expect( model.canGoBack == false )
    }

    @Test
    func trashingTheCurrentFilePrunesItFromHistoryAndSelectsANeighbour() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.writeMemoryFile( "n1.md", inProject: "-Users-macmade-Alpha" )
        try root.writeMemoryFile( "n2.md", inProject: "-Users-macmade-Alpha" )

        let model = AppModel( projectsDirectory: root.url, trashItem: { _ in } )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        let n1 = try #require( model.memoryFiles.first { $0.name == "n1.md" } )
        let n2 = try #require( model.memoryFiles.first { $0.name == "n2.md" } )

        model.selectedFile = n1.id
        model.selectedFile = n2.id

        try model.trashFile( n2 )

        #expect( model.selectedMemoryFile?.name == "n1.md" )
        #expect( model.canGoForward == false )

        model.goBack()

        #expect( model.selectedMemoryFile?.name == "MEMORY.md" )
    }

    @Test
    func trashingAllMemoryClearsTheNavigationState() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )
        try root.writeMemoryFile( "note.md", inProject: "-Users-macmade-Alpha" )

        let model = AppModel( projectsDirectory: root.url, trashItem: { _ in } )

        await model.loadProjects()

        model.selection = "-Users-macmade-Alpha"

        await model.loadMemoryFiles()

        let note = try #require( model.memoryFiles.first { $0.name == "note.md" } )

        model.selectedFile = note.id

        let alpha = try #require( model.selectedProject )

        try model.trashAllMemory( alpha )

        #expect( model.selectedFile == nil )
        #expect( model.canGoBack == false )
        #expect( model.canGoForward == false )
    }

    @Test
    func exportingAProjectFailurePropagates() async throws
    {
        let root = try TemporaryProjectTree()

        try root.makeProject( encodedName: "-Users-macmade-Alpha", withMemory: true )

        let model = AppModel( projectsDirectory: root.url )

        await model.loadProjects()

        let alpha = try #require( model.projects.first )

        // Block the destination's parent with a regular file so creating the
        // destination directory fails.
        let blocker = root.url.appending( path: "blocker" )

        try "x".write( to: blocker, atomically: true, encoding: .utf8 )

        let destination = blocker.appending( path: "export", directoryHint: .isDirectory )

        await #expect( throws: ( any Error ).self )
        {
            _ = try await model.exportProject( alpha, to: destination ) { _ in .overwrite }
        }
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

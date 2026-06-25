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

/// An error raised by ``MemoryExporter`` for conditions it detects itself.
///
/// Failures from the underlying `FileManager` (a copy failure, an unwritable
/// destination, etc.) are not wrapped: they propagate as the thrown Cocoa
/// errors so callers can present their localized descriptions directly.
enum MemoryExportError: Error, Equatable
{
    /// The source file to export does not exist on disk.
    case sourceNotFound( URL )
}

/// How to resolve a project export that would overwrite an existing file at the
/// destination.
enum MemoryExportConflictResolution: Sendable, Equatable
{
    /// Replace the existing file.
    case overwrite

    /// Leave the existing file untouched and skip the source file.
    case skip

    /// Abort the whole export, leaving the destination untouched.
    case cancel
}

/// Copies memory files to a user-chosen destination.
///
/// Existing files at the destination are overwritten.
enum MemoryExporter
{
    /// A single file scheduled for export, paired with the destination it will
    /// be copied to and whether a file already exists there.
    struct PlannedExport: Sendable, Equatable
    {
        /// The source file to copy.
        let source: URL

        /// The destination the source will be copied to.
        let destination: URL

        /// Whether a file already exists at ``destination``.
        let destinationExists: Bool
    }

    /// Copies a single file to `destination`, creating any intermediate
    /// directories and overwriting an existing file there.
    ///
    /// Throws ``MemoryExportError/sourceNotFound(_:)`` when `source` does not
    /// exist; any filesystem failure propagates from `FileManager`.
    static func export( file source: URL, to destination: URL, fileManager: FileManager = .default ) throws
    {
        guard fileManager.fileExists( atPath: source.path )
        else
        {
            throw MemoryExportError.sourceNotFound( source )
        }

        try self.copy( source, to: destination, fileManager: fileManager )
    }

    /// Builds the export plan for a project: one ``PlannedExport`` per `.md` file
    /// under `memoryDirectory`, each mapped to a destination under
    /// `destinationFolder` that preserves the file's path relative to
    /// `memoryDirectory` (nested subfolders are recreated).
    ///
    /// Discovery reuses ``MemoryFileLister``, so a missing or empty memory
    /// directory yields an empty plan. Each entry records whether a file already
    /// exists at its destination so the caller can resolve conflicts before
    /// copying.
    static func plannedExports( memoryDirectory: URL, to destinationFolder: URL, fileManager: FileManager = .default ) -> [ PlannedExport ]
    {
        let baseComponents = memoryDirectory.standardizedFileURL.pathComponents

        return MemoryFileLister.files( in: memoryDirectory, fileManager: fileManager ).map
        {
            file in

            let relativeComponents = file.url.standardizedFileURL.pathComponents.dropFirst( baseComponents.count )
            let destination        = relativeComponents.reduce( destinationFolder ) { $0.appending( path: $1 ) }

            return PlannedExport( source: file.url, destination: destination, destinationExists: fileManager.fileExists( atPath: destination.path ) )
        }
    }

    /// Copies every planned export to its destination, creating intermediate
    /// directories and overwriting any existing file. Any filesystem failure
    /// propagates from `FileManager`.
    static func copy( _ exports: [ PlannedExport ], fileManager: FileManager = .default ) throws
    {
        for export in exports
        {
            try self.copy( export.source, to: export.destination, fileManager: fileManager )
        }
    }

    /// Copies `source` to `destination`, creating intermediate directories and
    /// replacing any existing file at the destination.
    private static func copy( _ source: URL, to destination: URL, fileManager: FileManager ) throws
    {
        try fileManager.createDirectory( at: destination.deletingLastPathComponent(), withIntermediateDirectories: true )

        if fileManager.fileExists( atPath: destination.path )
        {
            try fileManager.removeItem( at: destination )
        }

        try fileManager.copyItem( at: source, to: destination )
    }
}

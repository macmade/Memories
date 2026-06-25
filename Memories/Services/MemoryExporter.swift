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

/// Copies memory files to a user-chosen destination.
///
/// Existing files at the destination are overwritten.
enum MemoryExporter
{
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

    /// Copies every `.md` file under `memoryDirectory` into `destinationFolder`,
    /// preserving each file's path relative to `memoryDirectory` so nested
    /// subfolders are recreated. Existing files are overwritten.
    ///
    /// Discovery reuses ``MemoryFileLister``, so a missing or empty memory
    /// directory simply copies nothing. Any filesystem failure propagates from
    /// `FileManager`.
    static func export( memoryDirectory: URL, to destinationFolder: URL, fileManager: FileManager = .default ) throws
    {
        let baseComponents = memoryDirectory.standardizedFileURL.pathComponents

        for file in MemoryFileLister.files( in: memoryDirectory, fileManager: fileManager )
        {
            let relativeComponents = file.url.standardizedFileURL.pathComponents.dropFirst( baseComponents.count )
            let destination        = relativeComponents.reduce( destinationFolder ) { $0.appending( path: $1 ) }

            try self.copy( file.url, to: destination, fileManager: fileManager )
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

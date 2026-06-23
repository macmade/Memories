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

/// Lists the Markdown files inside a project's `memory/` folder.
enum MemoryFileLister
{
    /// Recursively finds every `.md` file under `memoryDirectory`, sorted with
    /// the index (`MEMORY.md`) first, then case-insensitively by filename.
    ///
    /// A missing or unreadable directory yields an empty array.
    static func files( in memoryDirectory: URL, fileManager: FileManager = .default ) -> [ MemoryFile ]
    {
        guard let enumerator = fileManager.enumerator( at: memoryDirectory, includingPropertiesForKeys: [ .isRegularFileKey ], options: [ .skipsHiddenFiles ] )
        else
        {
            return []
        }

        let files = enumerator.compactMap
        {
            element -> MemoryFile? in

            guard let url = element as? URL,
                  url.pathExtension.lowercased() == "md",
                  ( try? url.resourceValues( forKeys: [ .isRegularFileKey ] ) )?.isRegularFile == true
            else
            {
                return nil
            }

            return MemoryFile( url: url )
        }

        return files.sorted
        {
            lhs, rhs in

            if lhs.isIndex != rhs.isIndex
            {
                return lhs.isIndex
            }

            return lhs.name.localizedCaseInsensitiveCompare( rhs.name ) == .orderedAscending
        }
    }
}

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

struct MemoryLoaderTests
{
    @Test
    func loadingReturnsTheFileContents() throws
    {
        let url = FileManager.default.temporaryDirectory.appending( path: "MemoryLoaderTests-\( UUID().uuidString ).md" )

        try "# Title\n\nBody text.\n".write( to: url, atomically: true, encoding: .utf8 )

        defer { try? FileManager.default.removeItem( at: url ) }

        #expect( MemoryLoader.load( from: url ) == .loaded( "# Title\n\nBody text.\n" ) )
    }

    @Test
    func loadingAnEmptyFileReturnsAnEmptyString() throws
    {
        let url = FileManager.default.temporaryDirectory.appending( path: "MemoryLoaderTests-\( UUID().uuidString ).md" )

        try Data().write( to: url )

        defer { try? FileManager.default.removeItem( at: url ) }

        #expect( MemoryLoader.load( from: url ) == .loaded( "" ) )
    }

    @Test
    func loadingAMissingFileReturnsFailure() throws
    {
        let url = FileManager.default.temporaryDirectory.appending( path: "MemoryLoaderTests-missing-\( UUID().uuidString ).md" )

        guard case .failed = MemoryLoader.load( from: url )
        else
        {
            Issue.record( "Expected a failure for a missing file." )

            return
        }
    }
}

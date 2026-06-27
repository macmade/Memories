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

/// A browser-style back / forward history of memory files.
///
/// The history is an ordered stack of ``MemoryFile/ID`` values plus an index
/// marking the current entry. A fresh navigation truncates any forward entries,
/// appends the new file, and makes it current; ``goBack()`` / ``goForward()``
/// only move the index, never mutating the stack.
struct FileNavigationHistory
{
    /// The ordered visited files, oldest first.
    private var entries: [ MemoryFile.ID ] = []

    /// The index of the current entry within ``entries``.
    private var index = 0

    /// The file the history currently points at, or `nil` when empty.
    var current: MemoryFile.ID?
    {
        self.entries.indices.contains( self.index ) ? self.entries[ self.index ] : nil
    }

    /// Whether there is an older entry to go back to.
    var canGoBack: Bool
    {
        self.entries.isEmpty == false && self.index > 0
    }

    /// Whether there is a newer entry to go forward to.
    var canGoForward: Bool
    {
        self.index < self.entries.count - 1
    }

    /// Records a fresh navigation to `id`: truncates any forward entries,
    /// appends `id`, and makes it current. A no-op when `id` is already current.
    mutating func navigate( to id: MemoryFile.ID )
    {
        if id == self.current
        {
            return
        }

        if self.entries.isEmpty
        {
            self.entries = [ id ]
            self.index   = 0

            return
        }

        self.entries.removeSubrange( ( self.index + 1 )... )
        self.entries.append( id )

        self.index = self.entries.count - 1
    }

    /// Moves the current entry one step back and returns the new ``current``.
    @discardableResult
    mutating func goBack() -> MemoryFile.ID?
    {
        if self.canGoBack
        {
            self.index -= 1
        }

        return self.current
    }

    /// Moves the current entry one step forward and returns the new ``current``.
    @discardableResult
    mutating func goForward() -> MemoryFile.ID?
    {
        if self.canGoForward
        {
            self.index += 1
        }

        return self.current
    }

    /// Drops every occurrence of `id` from the history, keeping the current
    /// index pointing at a valid entry (the following file when the current one
    /// is removed, clamped to the last entry).
    mutating func remove( _ id: MemoryFile.ID )
    {
        var kept     = [ MemoryFile.ID ]()
        var newIndex = self.index

        for ( offset, entry ) in self.entries.enumerated()
        {
            if entry == id
            {
                if offset < self.index
                {
                    newIndex -= 1
                }
            }
            else
            {
                kept.append( entry )
            }
        }

        self.entries = kept
        self.index   = kept.isEmpty ? 0 : min( max( newIndex, 0 ), kept.count - 1 )
    }
}

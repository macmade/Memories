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

// MARK: - PresentationIntent helpers

extension PresentationIntent
{
    /// The identity of the innermost block component, used to group runs.
    var blockIdentity: Int
    {
        self.components.first?.identity ?? 0
    }

    var headerLevel: Int?
    {
        for component in self.components
        {
            if case .header( let level ) = component.kind
            {
                return level
            }
        }

        return nil
    }

    var isCodeBlock: Bool
    {
        self.components.contains
        {
            if case .codeBlock = $0.kind { return true }

            return false
        }
    }

    var isBlockQuote: Bool
    {
        self.components.contains
        {
            if case .blockQuote = $0.kind { return true }

            return false
        }
    }

    var listItemOrdinal: Int?
    {
        for component in self.components
        {
            if case .listItem( let ordinal ) = component.kind
            {
                return ordinal
            }
        }

        return nil
    }

    var isOrderedList: Bool
    {
        self.components.contains
        {
            if case .orderedList = $0.kind { return true }

            return false
        }
    }

    /// The number of nested lists enclosing this block.
    var listDepth: Int
    {
        self.components.reduce( 0 )
        {
            count, component in

            switch component.kind
            {
                case .orderedList, .unorderedList: return count + 1
                default:                           return count
            }
        }
    }
}

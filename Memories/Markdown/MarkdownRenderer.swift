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

import AppKit
import Foundation

/// Renders Markdown source into an attributed string for display.
///
/// `NSAttributedString(markdown:)` only annotates the text with *semantic*
/// presentation intents (headings, lists, emphasis) and discards the line
/// breaks between blocks. AppKit does not turn those intents into visible
/// styling, so this renderer walks the parsed runs itself and applies concrete
/// fonts, paragraph styles, list bullets, and block separators.
///
/// Tables and images are not supported (an AppKit Markdown limitation); they
/// are dropped to their text content. This is acceptable for a read-only
/// preview.
enum MarkdownRenderer
{
    /// Parses `markdown` and converts it into a fully styled attributed string,
    /// falling back to the raw text if parsing fails.
    ///
    /// Links are resolved against the memory the text comes from: a relative
    /// (file) link is kept only when it points at one of `memoryFiles`,
    /// resolved against `baseDirectory` (the directory of the current file).
    /// Such a link carries the matched file's own URL as its destination, so a
    /// click can be routed back to that file. Relative links with no matching
    /// file are dropped (the text stays, the link does not). Links with a
    /// non-`file` scheme (`http`, `https`, `mailto`, …) are always kept.
    static func attributedString( from markdown: String, baseDirectory: URL? = nil, memoryFiles: [ MemoryFile ] = [] ) -> NSAttributedString
    {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: true,
            interpretedSyntax:        .full,
            failurePolicy:            .returnPartiallyParsedIfPossible
        )

        guard let parsed = try? AttributedString( markdown: markdown, options: options )
        else
        {
            return NSAttributedString( string: markdown )
        }

        return MarkdownConverter( baseDirectory: baseDirectory, memoryFiles: memoryFiles ).convert( parsed )
    }
}

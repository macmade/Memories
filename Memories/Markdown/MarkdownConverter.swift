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

/// Converts a parsed Markdown ``AttributedString`` into a concretely styled
/// `NSAttributedString`, one block at a time.
struct MarkdownConverter
{
    let bodySize  = NSFont.preferredFont( forTextStyle: .body ).pointSize
    let textColor = NSColor.labelColor

    /// The directory of the file being rendered, used to resolve relative
    /// (file) links. `nil` means relative links cannot be resolved and are
    /// therefore dropped.
    let baseDirectory: URL?

    /// The memory files a relative link may legitimately point at.
    let memoryFiles: [ MemoryFile ]

    /// A contiguous range of runs sharing the same innermost block.
    private struct Block
    {
        let intent: PresentationIntent
        var runs:   [ ( text: String, inline: InlinePresentationIntent, link: URL? ) ] = []
    }

    func convert( _ attributed: AttributedString ) -> NSAttributedString
    {
        let blocks = self.blocks( from: attributed )
        let output = NSMutableAttributedString()

        for ( index, block ) in blocks.enumerated()
        {
            if index > 0
            {
                output.append( NSAttributedString( string: "\n" ) )
            }

            output.append( self.render( block ) )
        }

        return output
    }

    // MARK: - Grouping

    private func blocks( from attributed: AttributedString ) -> [ Block ]
    {
        var blocks: [ Block ] = []

        for run in attributed.runs
        {
            let text   = String( attributed[ run.range ].characters )
            let inline = run[ AttributeScopes.FoundationAttributes.InlinePresentationIntentAttribute.self ] ?? []
            let link   = run[ AttributeScopes.FoundationAttributes.LinkAttribute.self ]
            let intent = run[ AttributeScopes.FoundationAttributes.PresentationIntentAttribute.self ] ?? PresentationIntent( .paragraph, identity: 0 )

            if let last = blocks.last, last.intent.blockIdentity == intent.blockIdentity
            {
                blocks[ blocks.count - 1 ].runs.append( ( text, inline, link ) )
            }
            else
            {
                var block = Block( intent: intent )

                block.runs.append( ( text, inline, link ) )
                blocks.append( block )
            }
        }

        return blocks
    }

    // MARK: - Block rendering

    private func render( _ block: Block ) -> NSAttributedString
    {
        let baseFont   = self.baseFont( for: block.intent )
        let result     = NSMutableAttributedString()
        let isCodeBlock = block.intent.isCodeBlock

        if let prefix = self.listPrefix( for: block.intent )
        {
            result.append( NSAttributedString( string: prefix, attributes: [ .font: baseFont, .foregroundColor: self.textColor ] ) )
        }

        for run in block.runs
        {
            // Code blocks keep their internal newlines but should not carry a
            // trailing one into the joined output.
            let text = isCodeBlock ? String( run.text.reversed().drop { $0 == "\n" }.reversed() ) : run.text
            let font = isCodeBlock ? self.monospacedFont( size: baseFont.pointSize ) : self.inlineFont( base: baseFont, inline: run.inline )

            var attributes: [ NSAttributedString.Key: Any ] =
            [
                .font:            font,
                .foregroundColor: block.intent.isBlockQuote ? NSColor.secondaryLabelColor : self.textColor,
                .paragraphStyle:  self.paragraphStyle( for: block.intent ),
            ]

            if let link = run.link, let destination = self.resolvedLink( link )
            {
                attributes[ .link ]            = destination
                attributes[ .foregroundColor ] = NSColor.linkColor
                attributes[ .underlineStyle ]  = NSUnderlineStyle.single.rawValue
            }

            result.append( NSAttributedString( string: text, attributes: attributes ) )
        }

        return result
    }

    /// The destination to attach to a parsed `link`, or `nil` when the link
    /// should be dropped and its text rendered plainly.
    ///
    /// Non-`file` schemes (`http`, `https`, `mailto`, …) pass through unchanged.
    /// A relative file reference is resolved against ``baseDirectory`` and kept
    /// only when it matches one of ``memoryFiles``, in which case that file's
    /// own URL is returned so a click can be routed back to it.
    private func resolvedLink( _ link: URL ) -> URL?
    {
        if let scheme = link.scheme, scheme != "file"
        {
            return link
        }

        guard let baseDirectory = self.baseDirectory
        else
        {
            return nil
        }

        let resolved = baseDirectory.appendingPathComponent( link.relativePath ).standardizedFileURL

        return self.memoryFiles.first { $0.url.standardizedFileURL == resolved }?.url
    }

    // MARK: - Fonts

    private func baseFont( for intent: PresentationIntent ) -> NSFont
    {
        if let level = intent.headerLevel
        {
            let bump: CGFloat

            switch level
            {
                case 1:  bump = 10
                case 2:  bump = 7
                case 3:  bump = 4
                case 4:  bump = 2
                default: bump = 1
            }

            return NSFont.boldSystemFont( ofSize: self.bodySize + bump )
        }

        if intent.isCodeBlock
        {
            return self.monospacedFont( size: self.bodySize )
        }

        return NSFont.systemFont( ofSize: self.bodySize )
    }

    private func inlineFont( base: NSFont, inline: InlinePresentationIntent ) -> NSFont
    {
        if inline.contains( .code )
        {
            return self.monospacedFont( size: base.pointSize )
        }

        var traits = base.fontDescriptor.symbolicTraits

        if inline.contains( .stronglyEmphasized )
        {
            traits.insert( .bold )
        }

        if inline.contains( .emphasized )
        {
            traits.insert( .italic )
        }

        let descriptor = base.fontDescriptor.withSymbolicTraits( traits )

        return NSFont( descriptor: descriptor, size: base.pointSize ) ?? base
    }

    private func monospacedFont( size: CGFloat ) -> NSFont
    {
        NSFont.monospacedSystemFont( ofSize: size, weight: .regular )
    }

    // MARK: - Paragraph styling

    private func paragraphStyle( for intent: PresentationIntent ) -> NSParagraphStyle
    {
        let style = NSMutableParagraphStyle()

        style.paragraphSpacing = self.bodySize * 0.6

        if intent.headerLevel != nil
        {
            style.paragraphSpacingBefore = self.bodySize * 0.4
        }

        let depth = intent.listDepth

        if depth > 0
        {
            let indent = CGFloat( depth ) * 18

            style.firstLineHeadIndent = indent
            style.headIndent          = indent + 14
        }

        if intent.isBlockQuote
        {
            style.firstLineHeadIndent = 18
            style.headIndent          = 18
        }

        return style
    }

    private func listPrefix( for intent: PresentationIntent ) -> String?
    {
        guard let ordinal = intent.listItemOrdinal
        else
        {
            return nil
        }

        return intent.isOrderedList ? "\( ordinal ).\t" : "•\t"
    }
}

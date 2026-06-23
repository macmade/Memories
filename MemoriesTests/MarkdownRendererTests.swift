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
@testable import Memories
import Testing

struct MarkdownRendererTests
{
    @Test
    func renderingKeepsPlainText() throws
    {
        let rendered = MarkdownRenderer.attributedString( from: "Hello, world." )

        #expect( rendered.string.contains( "Hello, world." ) )
    }

    @Test
    func renderingStripsInlineEmphasisSyntax() throws
    {
        let rendered = MarkdownRenderer.attributedString( from: "This is **bold** text." )

        // Full Markdown interpretation removes the literal asterisks.
        #expect( rendered.string.contains( "This is bold text." ) )
        #expect( rendered.string.contains( "*" ) == false )
    }

    @Test
    func renderingStripsHeadingSyntax() throws
    {
        let rendered = MarkdownRenderer.attributedString( from: "# Title\n\nBody." )

        #expect( rendered.string.contains( "Title" ) )
        #expect( rendered.string.contains( "Body." ) )
        #expect( rendered.string.contains( "#" ) == false )
    }

    @Test
    func renderingAnEmptyDocumentProducesEmptyText() throws
    {
        let rendered = MarkdownRenderer.attributedString( from: "" )

        #expect( rendered.string.isEmpty )
    }

    // MARK: - Rich formatting

    @Test
    func separateBlocksAreBrokenOntoSeparateLines() throws
    {
        let rendered = MarkdownRenderer.attributedString( from: "# Title\n\nBody." )

        // The raw markdown attributed string concatenates blocks with no breaks;
        // the renderer must insert a line break between them.
        #expect( rendered.string.contains( "\n" ) )
    }

    @Test
    func headingsAreBoldAndLargerThanBody() throws
    {
        let rendered = MarkdownRenderer.attributedString( from: "# Title\n\nBody." )

        let heading = try #require( font( for: "Title", in: rendered ) )
        let body    = try #require( font( for: "Body.", in: rendered ) )

        #expect( heading.fontDescriptor.symbolicTraits.contains( .bold ) )
        #expect( heading.pointSize > body.pointSize )
    }

    @Test
    func strongEmphasisProducesABoldFont() throws
    {
        let rendered = MarkdownRenderer.attributedString( from: "normal **strong** end" )

        let strong = try #require( font( for: "strong", in: rendered ) )

        #expect( strong.fontDescriptor.symbolicTraits.contains( .bold ) )
    }

    @Test
    func emphasisProducesAnItalicFont() throws
    {
        let rendered = MarkdownRenderer.attributedString( from: "normal *slanted* end" )

        let slanted = try #require( font( for: "slanted", in: rendered ) )

        #expect( slanted.fontDescriptor.symbolicTraits.contains( .italic ) )
    }

    @Test
    func inlineCodeUsesAMonospacedFont() throws
    {
        let rendered = MarkdownRenderer.attributedString( from: "call `compute()` now" )

        let code     = try #require( font( for: "compute()", in: rendered ) )
        let expected = NSFont.monospacedSystemFont( ofSize: code.pointSize, weight: .regular )

        #expect( code.fontName == expected.fontName )
    }

    @Test
    func unorderedListItemsAreBulleted() throws
    {
        let rendered = MarkdownRenderer.attributedString( from: "- one\n- two" )

        #expect( rendered.string.contains( "•" ) )
        #expect( rendered.string.contains( "one" ) )
        #expect( rendered.string.contains( "two" ) )
    }

    @Test
    func linksCarryTheirDestinationURL() throws
    {
        let rendered = MarkdownRenderer.attributedString( from: "see [the site](https://xs-labs.com) now" )

        let range = ( rendered.string as NSString ).range( of: "the site" )

        let link = try #require( rendered.attributes( at: range.location, effectiveRange: nil )[ .link ] as? URL )

        #expect( link == URL( string: "https://xs-labs.com" ) )
    }

    @Test
    func renderingTheSameSourceTwiceProducesEqualOutput() throws
    {
        let a = MarkdownRenderer.attributedString( from: "# Title\n\nBody with **bold**, `code`, and [a link](https://xs-labs.com)." )
        let b = MarkdownRenderer.attributedString( from: "# Title\n\nBody with **bold**, `code`, and [a link](https://xs-labs.com)." )

        #expect( a.isEqual( b ) )
    }

    // MARK: - Memory-file links

    @Test
    func linkToAnExistingMemoryFileResolvesToThatFilesURL() throws
    {
        let base   = URL( fileURLWithPath: "/projects/demo/memory" )
        let target = MemoryFile( url: base.appendingPathComponent( "notes.md" ) )

        let rendered = MarkdownRenderer.attributedString( from: "see [the notes](notes.md) now", baseDirectory: base, memoryFiles: [ target ] )

        let range = ( rendered.string as NSString ).range( of: "the notes" )
        let link  = try #require( rendered.attributes( at: range.location, effectiveRange: nil )[ .link ] as? URL )

        #expect( link == target.url )
    }

    @Test
    func relativeParentPathsResolveAgainstTheBaseDirectory() throws
    {
        let base   = URL( fileURLWithPath: "/projects/demo/memory/sub" )
        let target = MemoryFile( url: URL( fileURLWithPath: "/projects/demo/memory/top.md" ) )

        let rendered = MarkdownRenderer.attributedString( from: "see [top](../top.md) now", baseDirectory: base, memoryFiles: [ target ] )

        let range = ( rendered.string as NSString ).range( of: "top" )
        let link  = try #require( rendered.attributes( at: range.location, effectiveRange: nil )[ .link ] as? URL )

        #expect( link == target.url )
    }

    @Test
    func linkToAMissingMemoryFileIsRenderedAsPlainText() throws
    {
        let base = URL( fileURLWithPath: "/projects/demo/memory" )

        let rendered = MarkdownRenderer.attributedString( from: "see [the notes](ghost.md) now", baseDirectory: base, memoryFiles: [] )

        let range = ( rendered.string as NSString ).range( of: "the notes" )

        #expect( rendered.string.contains( "the notes" ) )
        #expect( rendered.attributes( at: range.location, effectiveRange: nil )[ .link ] == nil )
    }

    @Test
    func externalLinksAreKeptEvenWithMemoryContext() throws
    {
        let rendered = MarkdownRenderer.attributedString( from: "see [the site](https://xs-labs.com) now", baseDirectory: URL( fileURLWithPath: "/projects/demo/memory" ), memoryFiles: [] )

        let range = ( rendered.string as NSString ).range( of: "the site" )
        let link  = try #require( rendered.attributes( at: range.location, effectiveRange: nil )[ .link ] as? URL )

        #expect( link == URL( string: "https://xs-labs.com" ) )
    }

    private func font( for substring: String, in attributed: NSAttributedString ) -> NSFont?
    {
        let range = ( attributed.string as NSString ).range( of: substring )

        guard range.location != NSNotFound
        else
        {
            return nil
        }

        return attributed.attributes( at: range.location, effectiveRange: nil )[ .font ] as? NSFont
    }
}

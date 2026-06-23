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
import SwiftUI

/// Decides what a clicked Markdown link should do.
///
/// The renderer guarantees that a `.link` carrying a `file` URL is always a
/// known memory file (relative links that do not resolve to one are dropped),
/// so the only distinction left at click time is file versus everything else.
enum MarkdownLinkRouter
{
    enum Route: Equatable
    {
        /// Navigate to the memory file with this identity (its path).
        case openMemoryFile( MemoryFile.ID )

        /// Let the system open the link (a web or other external destination).
        case external
    }

    static func route( _ url: URL ) -> Route
    {
        url.isFileURL ? .openMemoryFile( url.path ) : .external
    }
}

/// A read-only, selectable `NSTextView` for displaying a rendered attributed
/// string with native scrolling.
struct MarkdownTextView: NSViewRepresentable
{
    let attributedString: NSAttributedString

    /// Invoked when the user clicks an in-app link to another memory file,
    /// with that file's identity. External links are left to the system.
    var onOpenFile: ( MemoryFile.ID ) -> Void = { _ in }

    func makeCoordinator() -> Coordinator
    {
        Coordinator( onOpenFile: self.onOpenFile )
    }

    func makeNSView( context: Context ) -> NSScrollView
    {
        let scrollView = NSTextView.scrollableTextView()

        scrollView.drawsBackground      = false
        scrollView.hasVerticalScroller  = true
        scrollView.autohidesScrollers   = true

        if let textView = scrollView.documentView as? NSTextView
        {
            textView.isEditable             = false
            textView.isSelectable           = true
            textView.drawsBackground        = false
            textView.textContainerInset     = NSSize( width: 16, height: 16 )
            textView.isVerticallyResizable   = true
            textView.isHorizontallyResizable = false
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.lineFragmentPadding  = 0
            textView.delegate                = context.coordinator
        }

        return scrollView
    }

    func updateNSView( _ scrollView: NSScrollView, context: Context )
    {
        guard let textView = scrollView.documentView as? NSTextView
        else
        {
            return
        }

        context.coordinator.onOpenFile = self.onOpenFile

        // SwiftUI calls this on every re-render of the enclosing view (e.g. the
        // floating file switcher's visibility timer, or hover tracking). Resetting
        // the text storage clears the user's selection, so only replace it when
        // the rendered content has actually changed. The comparison is against the
        // last string we applied rather than the live text storage, which the text
        // system mutates after assignment (so comparing against it never matches).
        if context.coordinator.appliedString?.isEqual( self.attributedString ) != true
        {
            textView.textStorage?.setAttributedString( self.attributedString )

            context.coordinator.appliedString = self.attributedString
        }
    }

    /// Routes clicked links: in-app memory-file links navigate within the app,
    /// everything else falls through to the system's default handling.
    final class Coordinator: NSObject, NSTextViewDelegate
    {
        var onOpenFile: ( MemoryFile.ID ) -> Void

        /// The last attributed string applied to the text view. Used to skip
        /// redundant resets that would otherwise clear the user's selection.
        var appliedString: NSAttributedString?

        init( onOpenFile: @escaping ( MemoryFile.ID ) -> Void )
        {
            self.onOpenFile = onOpenFile
        }

        func textView( _ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int ) -> Bool
        {
            guard let url = link as? URL
            else
            {
                return false
            }

            switch MarkdownLinkRouter.route( url )
            {
                case .openMemoryFile( let id ):

                    self.onOpenFile( id )

                    return true

                case .external:

                    return false
            }
        }
    }
}

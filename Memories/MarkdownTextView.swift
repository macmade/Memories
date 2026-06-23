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

/// A read-only, selectable `NSTextView` for displaying a rendered attributed
/// string with native scrolling.
struct MarkdownTextView: NSViewRepresentable
{
    let attributedString: NSAttributedString

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

        textView.textStorage?.setAttributedString( self.attributedString )
    }
}

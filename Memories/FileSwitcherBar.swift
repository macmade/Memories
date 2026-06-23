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

import SwiftUI

/// A floating popup, shown over the preview, for picking which memory file to
/// display.
struct FileSwitcherBar: View
{
    let files: [ MemoryFile ]

    @Binding var selection: MemoryFile.ID?

    var body: some View
    {
        Picker( "Memory File", selection: self.$selection )
        {
            ForEach( self.files )
            {
                file in

                Label( file.name, systemImage: file.isIndex ? "doc.text.magnifyingglass" : "doc.text" )
                    .tag( file.id as MemoryFile.ID? )
            }
        }
        .labelsHidden()
        .pickerStyle( .menu )
        .fixedSize()
        .padding( .horizontal, 14 )
        .padding( .vertical, 8 )
        .background( .regularMaterial, in: Capsule() )
        .overlay( Capsule().strokeBorder( Color.secondary.opacity( 0.25 ) ) )
        .shadow( radius: 10, y: 3 )
        .padding( .bottom, 18 )
        .help( "Choose which memory file to display" )
    }
}

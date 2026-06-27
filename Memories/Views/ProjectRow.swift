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

/// A single sidebar row presenting a project's name and decoded path.
struct ProjectRow: View
{
    @Environment( \.controlActiveState ) private var controlActiveState

    let project:    Project
    var isSelected: Bool = false

    /// The icon turns white when its row is the active selection, otherwise it
    /// keeps the tint colour. The selection highlight is only prominent while
    /// the window is active, so an inactive window keeps the tint.
    private var iconStyle: AnyShapeStyle
    {
        self.isActiveSelection ? AnyShapeStyle( .white ) : AnyShapeStyle( .tint )
    }

    /// Whether the row is the active, prominently-highlighted selection.
    private var isActiveSelection: Bool
    {
        self.isSelected && self.controlActiveState != .inactive
    }

    /// The badge capsule fill: solid white on the active selection, otherwise a
    /// faint secondary tint.
    private var badgeCapsuleStyle: AnyShapeStyle
    {
        self.isActiveSelection ? AnyShapeStyle( .white ) : AnyShapeStyle( Color.secondary.opacity( 0.18 ) )
    }

    /// The badge icon and text colour: the tint on the white capsule of the
    /// active selection, otherwise the secondary colour.
    private var badgeForegroundStyle: AnyShapeStyle
    {
        self.isActiveSelection ? AnyShapeStyle( .tint ) : AnyShapeStyle( .secondary )
    }

    var body: some View
    {
        HStack( spacing: 10 )
        {
            Image( systemName: self.project.iconSystemName )
                .foregroundStyle( self.iconStyle )
                .help( self.project.isGitRepository ? "Git repository" : "Directory" )

            VStack( alignment: .leading, spacing: 1 )
            {
                Text( self.project.title )

                Text( self.project.decodedPath )
                    .font( .caption )
                    .foregroundStyle( .secondary )
                    .lineLimit( 1 )
                    .truncationMode( .tail )
            }
            .help( self.project.decodedPath )

            if let branch = self.project.branch
            {
                Spacer( minLength: 6 )

                self.branchBadge( branch )
            }
        }
        .padding( .vertical, 2 )
    }

    private func branchBadge( _ branch: String ) -> some View
    {
        Label( branch, systemImage: "arrow.triangle.branch" )
            .labelStyle( .titleAndIcon )
            .font( .caption2 )
            .lineLimit( 1 )
            .padding( .horizontal, 6 )
            .padding( .vertical, 2 )
            .background( Capsule().fill( self.badgeCapsuleStyle ) )
            .foregroundStyle( self.badgeForegroundStyle )
            .help( "Current branch: \( branch )" )
    }
}

#Preview
{
    List
    {
        ProjectRow( project: Project( folderURL: URL( fileURLWithPath: "/tmp/-Users-macmade-Documents-Macmade-GitHub-Memories", isDirectory: true ) ) )
    }
}

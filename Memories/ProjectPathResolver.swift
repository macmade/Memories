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

/// Reconstructs the real filesystem path of a Claude project from its encoded
/// directory name.
///
/// The directory name is the real path with every `/` replaced by `-`, which is
/// lossy because real path segments may themselves contain dashes (e.g.
/// `iMazing-Mac`). To recover the true path, the resolver consults, in order of
/// authority:
///
/// 1. The `projects` registry in `~/.claude.json`, keyed by real absolute paths.
/// 2. The `cwd` recorded in the project's `.jsonl` session transcripts.
/// 3. The filesystem, grouping the dash-separated tokens by what actually exists.
/// 4. Naive `-` → `/` decoding, the inherent floor when nothing else resolves.
///
/// A candidate path is only accepted from sources 1 and 2 when re-encoding it
/// (`/` → `-`) reproduces the folder name exactly, which removes the ambiguity.
struct ProjectPathResolver
{
    private let registryPaths: [ String ]
    private let fileManager:   FileManager

    /// The location of Claude's global configuration file.
    static var defaultRegistryURL: URL
    {
        FileManager.default.homeDirectoryForCurrentUser.appending( path: ".claude.json" )
    }

    /// Creates a resolver, loading the project registry from `registryURL`.
    init( registryURL: URL = ProjectPathResolver.defaultRegistryURL, fileManager: FileManager = .default )
    {
        self.init( registryPaths: ProjectPathResolver.loadRegistry( from: registryURL ), fileManager: fileManager )
    }

    /// Creates a resolver from an explicit list of registry paths. Used by tests.
    init( registryPaths: [ String ], fileManager: FileManager = .default )
    {
        self.registryPaths = registryPaths
        self.fileManager   = fileManager
    }

    /// Resolves the real path of the project stored in `folderURL`.
    func resolvedPath( forFolder folderURL: URL ) -> String
    {
        let encodedName = folderURL.lastPathComponent

        // 1. The global registry of real project paths.
        let matches = self.registryPaths.filter { ProjectPathResolver.encode( $0 ) == encodedName }

        if let match = matches.first( where: { self.fileManager.fileExists( atPath: $0 ) } ) ?? matches.first
        {
            return match
        }

        // 2. The working directory recorded in the session transcripts.
        if let cwd = self.transcriptCWD( in: folderURL, matching: encodedName )
        {
            return cwd
        }

        // 3. The filesystem, grouping the tokens by what exists on disk.
        let tokens = ProjectPathResolver.tokens( of: encodedName )

        if let components = ProjectPathResolver.resolveByFilesystem( tokens: tokens, under: URL( fileURLWithPath: "/", isDirectory: true ), fileManager: self.fileManager )
        {
            return "/" + components.joined( separator: "/" )
        }

        // 4. Naive decoding.
        return Project.decodePath( encodedName )
    }

    // MARK: - Sources

    private static func loadRegistry( from url: URL ) -> [ String ]
    {
        guard let data   = try? Data( contentsOf: url ),
              let object  = try? JSONSerialization.jsonObject( with: data ) as? [ String: Any ],
              let projects = object[ "projects" ] as? [ String: Any ]
        else
        {
            return []
        }

        return Array( projects.keys )
    }

    private func transcriptCWD( in folderURL: URL, matching encodedName: String ) -> String?
    {
        let transcripts = ( try? self.fileManager.contentsOfDirectory( at: folderURL, includingPropertiesForKeys: nil ) )?.filter { $0.pathExtension == "jsonl" } ?? []

        for transcript in transcripts
        {
            guard let contents = try? String( contentsOf: transcript, encoding: .utf8 )
            else
            {
                continue
            }

            for cwd in ProjectPathResolver.cwdValues( in: contents ) where ProjectPathResolver.encode( cwd ) == encodedName
            {
                return cwd
            }
        }

        return nil
    }

    // MARK: - Helpers

    /// Encodes a real path the way Claude names its project directories.
    static func encode( _ path: String ) -> String
    {
        path.replacingOccurrences( of: "/", with: "-" )
    }

    /// Splits an encoded directory name into its dash-separated path tokens,
    /// dropping the leading empty token produced by the leading dash.
    static func tokens( of encodedName: String ) -> [ String ]
    {
        Array( encodedName.split( separator: "-", omittingEmptySubsequences: false ).map( String.init ).drop { $0.isEmpty } )
    }

    /// Extracts every `cwd` string value found in raw transcript text.
    static func cwdValues( in text: String ) -> [ String ]
    {
        guard let regex = try? NSRegularExpression( pattern: "\"cwd\"\\s*:\\s*\"([^\"]*)\"" )
        else
        {
            return []
        }

        let range = NSRange( text.startIndex ..< text.endIndex, in: text )

        return regex.matches( in: text, range: range ).compactMap
        {
            match in

            guard let valueRange = Range( match.range( at: 1 ), in: text )
            else
            {
                return nil
            }

            return String( text[ valueRange ] )
        }
    }

    /// Reconstructs path components by grouping `tokens` into the longest runs
    /// that name directories actually existing under `root`, backtracking so the
    /// whole path resolves. Returns `nil` if no grouping fully exists.
    static func resolveByFilesystem( tokens: ArraySlice<String>, under root: URL, fileManager: FileManager ) -> [ String ]?
    {
        guard tokens.isEmpty == false
        else
        {
            return []
        }

        var end = tokens.endIndex

        while end > tokens.startIndex
        {
            let candidate = tokens[ tokens.startIndex ..< end ].joined( separator: "-" )
            let child     = root.appending( path: candidate, directoryHint: .isDirectory )

            var isDirectory: ObjCBool = false

            if fileManager.fileExists( atPath: child.path, isDirectory: &isDirectory ), isDirectory.boolValue
            {
                if let rest = resolveByFilesystem( tokens: tokens[ end... ], under: child, fileManager: fileManager )
                {
                    return [ candidate ] + rest
                }
            }

            end = tokens.index( before: end )
        }

        return nil
    }

    static func resolveByFilesystem( tokens: [ String ], under root: URL, fileManager: FileManager ) -> [ String ]?
    {
        self.resolveByFilesystem( tokens: tokens[ ... ], under: root, fileManager: fileManager )
    }
}

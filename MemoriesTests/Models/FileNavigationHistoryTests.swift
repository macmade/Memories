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
@testable import Memories
import Testing

struct FileNavigationHistoryTests
{
    @Test
    func aFreshHistoryIsEmpty()
    {
        let history = FileNavigationHistory()

        #expect( history.current == nil )
        #expect( history.canGoBack == false )
        #expect( history.canGoForward == false )
    }

    @Test
    func navigatingToAFileMakesItCurrentWithNoMovesAvailable()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )

        #expect( history.current == "a" )
        #expect( history.canGoBack == false )
        #expect( history.canGoForward == false )
    }

    @Test
    func navigatingThroughSeveralFilesTracksTheCurrentOne()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )
        history.navigate( to: "b" )
        history.navigate( to: "c" )

        #expect( history.current == "c" )
        #expect( history.canGoBack )
        #expect( history.canGoForward == false )
    }

    @Test
    func goingBackThenForwardWalksTheStackWithoutMutatingIt()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )
        history.navigate( to: "b" )
        history.navigate( to: "c" )

        #expect( history.goBack() == "b" )
        #expect( history.current == "b" )
        #expect( history.canGoBack )
        #expect( history.canGoForward )

        #expect( history.goBack() == "a" )
        #expect( history.current == "a" )
        #expect( history.canGoBack == false )
        #expect( history.canGoForward )

        #expect( history.goForward() == "b" )
        #expect( history.current == "b" )

        #expect( history.goForward() == "c" )
        #expect( history.current == "c" )
        #expect( history.canGoForward == false )
    }

    @Test
    func goingBackWhenAtTheStartIsANoOp()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )

        #expect( history.goBack() == "a" )
        #expect( history.current == "a" )
    }

    @Test
    func goingForwardWhenAtTheEndIsANoOp()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )
        history.navigate( to: "b" )

        #expect( history.goForward() == "b" )
        #expect( history.current == "b" )
    }

    @Test
    func navigatingAfterGoingBackTruncatesTheForwardEntries()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )
        history.navigate( to: "b" )
        history.navigate( to: "c" )

        _ = history.goBack()

        history.navigate( to: "d" )

        #expect( history.current == "d" )
        #expect( history.canGoForward == false )

        #expect( history.goBack() == "b" )
        #expect( history.canGoBack )
        #expect( history.goForward() == "d" )
    }

    @Test
    func reSelectingTheCurrentFileIsANoOp()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )
        history.navigate( to: "b" )
        history.navigate( to: "b" )

        #expect( history.current == "b" )
        #expect( history.canGoForward == false )

        #expect( history.goBack() == "a" )
        #expect( history.canGoBack == false )
    }

    @Test
    func removingAFileBeforeTheCurrentOneKeepsTheCurrentSelection()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )
        history.navigate( to: "b" )
        history.navigate( to: "c" )

        history.remove( "a" )

        #expect( history.current == "c" )
        #expect( history.goBack() == "b" )
        #expect( history.canGoBack == false )
    }

    @Test
    func removingTheCurrentFileSelectsANeighbour()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )
        history.navigate( to: "b" )
        history.navigate( to: "c" )

        _ = history.goBack()

        history.remove( "b" )

        #expect( history.current == "c" )
        #expect( history.goBack() == "a" )
    }

    @Test
    func removingTheCurrentLastFileFallsBackToThePreviousOne()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )
        history.navigate( to: "b" )

        history.remove( "b" )

        #expect( history.current == "a" )
        #expect( history.canGoForward == false )
        #expect( history.canGoBack == false )
    }

    @Test
    func removingEveryOccurrenceLeavesTheHistoryEmpty()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )

        history.remove( "a" )

        #expect( history.current == nil )
        #expect( history.canGoBack == false )
        #expect( history.canGoForward == false )
    }

    @Test
    func removingAnAbsentFileDoesNothing()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )
        history.navigate( to: "b" )

        history.remove( "z" )

        #expect( history.current == "b" )
        #expect( history.goBack() == "a" )
    }

    @Test
    func retainingOnlyASetDropsEveryOtherEntryAndKeepsACurrentNeighbour()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )
        history.navigate( to: "b" )
        history.navigate( to: "c" )

        history.retainOnly( [ "a", "c" ] )

        #expect( history.current == "c" )
        #expect( history.goBack() == "a" )
        #expect( history.canGoBack == false )
    }

    @Test
    func retainingOnlyAnEmptySetEmptiesTheHistory()
    {
        var history = FileNavigationHistory()

        history.navigate( to: "a" )
        history.navigate( to: "b" )

        history.retainOnly( [] )

        #expect( history.current == nil )
        #expect( history.canGoBack == false )
        #expect( history.canGoForward == false )
    }
}

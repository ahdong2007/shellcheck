{-
    This file is part of ShellCheck.
    http://www.vidarholen.net/contents/shellcheck

    ShellCheck is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    ShellCheck is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
-}
module ShellCheck.Simple (shellCheck, ShellCheckComment, scLine, scColumn, scSeverity, scCode, scMessage) where

import ShellCheck.Parser
import ShellCheck.Analytics
import Data.Maybe
import Text.Parsec.Pos
import Data.List


prop_findsParseIssue =
    let comments = shellCheck "echo \"$12\"" in
        (length comments) == 1 && (scCode $ head comments) == 1037
prop_commentDisablesParseIssue1 =
    null $ shellCheck "#shellcheck disable=SC1037\necho \"$12\""
prop_commentDisablesParseIssue2 =
    null $ shellCheck "#shellcheck disable=SC1037\n#lol\necho \"$12\""

prop_findsAnalysisIssue =
    let comments = shellCheck "echo $1" in
        (length comments) == 1 && (scCode $ head comments) == 2086
prop_commentDisablesAnalysisIssue1 =
    null $ shellCheck "#shellcheck disable=SC2086\necho $1"
prop_commentDisablesAnalysisIssue2 =
    null $ shellCheck "#shellcheck disable=SC2086\n#lol\necho $1"

shellCheck :: String -> [ShellCheckComment]
shellCheck script =
    let (ParseResult result notes) = parseShell "-" script in
        let allNotes = notes ++ (concat $ maybeToList $ do
            (tree, map) <- result
            let newMap = runAllAnalytics tree map
            return $ notesFromMap $ filterByAnnotation tree newMap
            )
        in
            map formatNote $ nub $ sortNotes allNotes

data ShellCheckComment = ShellCheckComment { scLine :: Int, scColumn :: Int, scSeverity :: String, scCode :: Int, scMessage :: String }

instance Show ShellCheckComment where
    show c = concat ["(", show $ scLine c, ",", show $ scColumn c, ") ", scSeverity c, ": ", show (scCode c), " ", scMessage c]

severityToString s =
    case s of
        ErrorC -> "error"
        WarningC -> "warning"
        InfoC -> "info"
        StyleC -> "style"

formatNote (ParseNote pos severity code text) =
    ShellCheckComment (sourceLine pos) (sourceColumn pos) (severityToString severity) (fromIntegral code) text

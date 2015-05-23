module Game (
  Game (..),
  GameType (..),
  GameSettings (..),
  GameResult (..),
  turnToGameResult,
  GameInfo (..)
) where

import Api
import Rating

data GameType =  Blitz | Lightning | Untimed | ExaminedGame | Standard | Wild | Atomic |
                 Crazyhouse | Bughouse | Losers | Suicide | NonStandardGame  deriving (Show)

data Game = Game {
    id :: Int
  , isExample :: Bool
  , isSetup :: Bool
  , ratingW :: Rating
  , nameW :: String
  , ratingB :: Rating
  , nameB :: String
  , settings :: GameSettings } deriving (Show)

data GameSettings = GameSettings {
    isPrivate :: Bool
  , gameType :: GameType
  , isRated :: Bool} deriving (Show)

data GameInfo = GameInfo {
    _nameW :: String
  , _ratingW :: Rating
  , _nameB :: String
  , _ratingB :: Rating
} deriving (Show)

data GameResult = WhiteWins | BlackWins | Draw

instance Show GameResult where
  show WhiteWins = "1-0"
  show BlackWins = "0-1"
  show Draw      = "1/2-1/2"


turnToGameResult :: PColor -> GameResult
turnToGameResult Black = WhiteWins
turnToGameResult White = BlackWins

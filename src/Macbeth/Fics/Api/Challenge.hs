module Macbeth.Fics.Api.Challenge (
  Challenge (..),
  displayChallenge
) where

import Macbeth.Fics.Api.Rating

data Challenge = Challenge { nameW :: String
                           , ratingW :: Rating
                           , nameB :: String
                           , ratingB :: Rating
                           , params :: String } deriving (Show, Eq)

displayChallenge :: Challenge -> String
displayChallenge c = nameW c ++ " (" ++ show (ratingW c) ++ ") vs. " ++ nameB c ++ " (" ++ show (ratingB c) ++ ") " ++ params c

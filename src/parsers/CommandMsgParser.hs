{-# LANGUAGE OverloadedStrings #-}

module CommandMsgParser (
 parseCommandMsg
) where

import Api
import CommandMsg
import GamesParser
import Move
import MoveParser2
import qualified SeekMsgParsers as SP
import qualified MatchMsgParsers as MP

import Control.Applicative
import Data.Attoparsec.ByteString.Char8
import qualified Data.ByteString.Char8 as BS
import Data.Char
import Data.List.Split (splitOn)


parseCommandMsg :: BS.ByteString -> Either String CommandMsg
parseCommandMsg str = parseOnly parser str where
  parser = choice [ SP.clearSeek
                  , SP.newSeek
                  , SP.removeSeeks

                  , MP.gameResult
                  , MP.match'
                  , MP.challenge
                  , MP.declinedChallenge
                  , MP.drawOffered

                  , games
                  , observe
                  , accept
                  , gameResult
                  , confirmMove
                  , seekInfoBlock
                  , move'

                  , login
                  , password
                  , guestLogin
                  , unknownUsername
                  , loggedIn
                  , invalidPassword
                  , prompt
                  , acknoledge
                  , settingsDone
                  ]

games :: Parser CommandMsg
games = Games <$> (commandHead 43 *> paresGamesList)

observe :: Parser CommandMsg
observe = Observe <$> (commandHead 80 *> move'')

accept :: Parser CommandMsg
accept = Accept <$> (commandHead 11 *> move'')

gameResult :: Parser CommandMsg
gameResult = commandHead 103 >> MP.gameResult

confirmMove :: Parser CommandMsg
confirmMove = ConfirmMove <$> (commandHead 1 *> move'')

seekInfoBlock :: Parser CommandMsg
seekInfoBlock = SeekInfoBlock
  <$> (commandHead 56 *> "seekinfo set.\n" *> sepBy (choice [ SP.clearSeek, SP.newSeek <* takeTill (== '\n')]) "\n")

move' :: Parser CommandMsg
move' = parseMove >>= return . CommandMsg.Move

login :: Parser CommandMsg
login = "login: " >> return Login

password :: Parser CommandMsg
password = "password: " >> return Password

guestLogin :: Parser CommandMsg
guestLogin = "Press return to enter the server as \"" >>
  manyTill anyChar "\":" >>=
  return . GuestLogin

unknownUsername :: Parser CommandMsg
unknownUsername = "\"" >>
  manyTill anyChar "\" is not a registered name." >>=
  return . UnkownUsername

loggedIn :: Parser CommandMsg
loggedIn = "**** Starting FICS session as " >>
  manyTill anyChar " ****" >>=
  return . LoggedIn . Prelude.head . splitOn "(" -- | Beware the guest handles: ie GuestXWLW(U)

invalidPassword :: Parser CommandMsg
invalidPassword = "**** Invalid password! ****" >> return InvalidPassword

prompt :: Parser CommandMsg
prompt = "fics% " >> return Prompt

acknoledge :: Parser CommandMsg
acknoledge = commandHead 519 >> (char $ chr 23) >> return Acknoledge

settingsDone :: Parser CommandMsg
settingsDone = (char $ chr 23) >> return SettingsDone


{- HELPER -}

move'' :: Parser Move
move'' = takeTill (== '<') >> parseMove >>= return


commandHead :: Int -> Parser CommandHead
commandHead code = do
  char $ chr 21
  id <- decimal
  char $ chr 22
  string $ BS.pack $ show code
  char $ chr 22
  return $ CommandHead id


{- TEST DATA -}

seekInfoBlock' = BS.pack "seekinfo set.\n<sc>\n<s> 16 w=CatNail ti=02 rt=1997  t=3 i=0 r=u tp=suicide c=? rr=0-9999 a=f f=f\n<s> 44 w=masheen ti=02 rt=2628  t=5 i=0 r=u tp=suicide c=? rr=0-9999 a=t f=f\n<s> 51 w=masheen ti=02 rt=2628  t=2 i=12 r=u tp=suicide c=? rr=0-9999 a=t f=f\n<s> 81 w=GuestHZLT ti=01 rt=0P t=2 i=0 r=u tp=lightning c=? rr=0-9999 a=t f=f\n"
playMsg = BS.pack "Creating: GuestCCFP (++++) GuestGVJK (++++) unrated blitz 0 20 {Game 132 (GuestCCFP vs. GuestGVJK) Creating unrated blitz match.} <12> rnbqkbnr pppppppp ———— ———— ———— ———— PPPPPPPP RNBQKBNR W -1 1 1 1 1 0 132 GuestCCFP GuestGVJK -1 0 20 39 39 10 10 1 none (0:00) none 1 0 0"
obs = BS.pack "You are now observing game 157.Game 157: IMUrkedal (2517) GMRomanov (2638) unrated standard 120 0<12> -------- -pp-Q--- pk------ ----p--- -P---p-- --qB---- -------- ---R-K-- B -1 0 0 0 0 9 157 IMUrkedal GMRomanov 0 120 0 18 14 383 38 57 K/e1-f1 (0:03) Kf1 0 0 0"
guestLoginTxt = BS.pack $ "Press return to enter the server as \"FOOBAR\":"

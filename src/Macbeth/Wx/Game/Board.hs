{-# LANGUAGE LambdaCase #-}

module Macbeth.Wx.Game.Board (
  draw,
  onMouseEvent
) where

import Macbeth.Fics.Api.Api
import Macbeth.Fics.Api.Move
import Macbeth.Utils.BoardUtils
import Macbeth.Wx.Game.BoardState

import Control.Monad.Reader
import Control.Monad.Trans.Maybe
import Data.Maybe
import Control.Concurrent.STM
import Graphics.UI.WX hiding (position, update, resize, when, pt, size, value, color)
import Graphics.UI.WXCore hiding (Row, Column, when, pt)
import System.IO

type BoardT a = ReaderT (DC a, BoardState) IO ()

draw :: TVar BoardState -> DC a -> t -> IO ()
draw vState dc _ = do
  state <- readTVarIO vState
  flip runReaderT (dc, state) $ do
    setScale
    drawBoard
    drawHighlightLastMove
    drawHighlightPreMove
    drawPieces
    drawSelectedSquare
    drawDraggedPiece


setScale :: BoardT a
setScale = do
  (dc, state) <- ask
  liftIO $ dcSetUserScale dc (scale state) (scale state)


drawBoard :: BoardT a
drawBoard = do
  (dc, state) <- ask
  let bw = let seed = (concat $ replicate 4 [Black, White]) in seed ++ reverse seed ++ bw
  let sq = [Square c r  | c <- [A .. H], r <- [One .. Eight]]
  lift $ set dc [ pen := penTransparent ]
  lift $ withBrushStyle (BrushStyle BrushSolid (rgb (180::Int) 150 100)) $ \blackBrush ->
    withBrushStyle (BrushStyle BrushSolid white) $ \whiteBrush ->
      mapM_ (\(c,sq') -> do
        dcSetBrush dc $ if c == White then whiteBrush else blackBrush
        paintSquare dc state sq')
          (zip bw sq)


drawHighlightLastMove :: BoardT a
drawHighlightLastMove = do
  (dc, state) <- ask
  liftIO $ when (isHighlightMove $ lastMove state) $
    sequence_ $ paintHighlight dc state blue <$> pieceMove state
  where
    isHighlightMove :: Move -> Bool
    isHighlightMove m = (isJust . moveVerbose) m && (wasOponentMove m || relation m == Observing)


drawHighlightPreMove :: BoardT a
drawHighlightPreMove = do
  (dc, state) <- ask
  liftIO $ sequence_ $ paintHighlight dc state yellow <$> preMoves state


drawPieces :: BoardT a
drawPieces = do
  (dc, state) <- ask
  liftIO $ sequence_ $ drawPiece dc state <$> virtualPosition state
  where
    drawPiece :: DC a -> BoardState -> (Square, Piece) -> IO ()
    drawPiece dc state (sq, p) = drawBitmap dc
      (pieceToBitmap (psize state) (pieceSet state) p)
      (toPos' (psize state) sq (perspective state)) True []


drawSelectedSquare :: BoardT a
drawSelectedSquare = do
  (dc, state) <- ask
  liftIO $ when (isGameUser state && isNothing (gameResult state)) $
    withBrushStyle brushTransparent $ \transparent -> do
      dcSetBrush dc transparent
      set dc [pen := penColored red 1]
      void $ runMaybeT $ do
        square <- MaybeT $ return $ pointToSquare state $ mousePt state
        liftIO $ paintSquare dc state square


drawDraggedPiece :: BoardT a
drawDraggedPiece = do
  (dc, state) <- ask
  case draggedPiece state of
    Just dp -> liftIO $ drawDraggedPiece'' state dc dp
    _ -> return ()


drawDraggedPiece'' :: BoardState -> DC a -> DraggedPiece -> IO ()
drawDraggedPiece'' state dc (DraggedPiece pt piece' _) = drawBitmap dc (pieceToBitmap size (pieceSet state) piece') scalePoint True []
  where
    scale' = scale state
    size = psize state
    scalePoint = point (scaleValue $ pointX pt) (scaleValue $ pointY pt)
    scaleValue value = round $ (fromIntegral value - fromIntegral size / 2 * scale') / scale'


paintHighlight :: DC a -> BoardState -> Color -> PieceMove -> IO ()
paintHighlight dc state color (PieceMove _ s1 s2) = do
  set dc [pen := penColored color 1]
  withBrushStyle (BrushStyle (BrushHatch HatchBDiagonal) color) $ \brushBg -> do
    dcSetBrush dc brushBg
    mapM_ (paintSquare dc state) [s1, s2]
  withBrushStyle (BrushStyle BrushSolid color) $ \brushArrow -> do
    dcSetBrush dc brushArrow
    drawArrow dc (psize state) s1 s2 (perspective state)
paintHighlight dc state color (DropMove _ s1) = do
  set dc [pen := penColored color 1]
  withBrushStyle (BrushStyle (BrushHatch HatchBDiagonal) color) $ \brushBg -> do
    dcSetBrush dc brushBg
    paintSquare dc state s1


paintSquare :: DC a -> BoardState -> Square -> IO ()
paintSquare dc state sq = drawRect dc (squareToRect' (psize state) sq (perspective state)) []


onMouseEvent :: Handle -> Var BoardState -> EventMouse -> IO ()
onMouseEvent h vState = \case

    MouseMotion pt _ -> updateMousePosition vState pt

    MouseLeftDown pt _ -> do
      dp <- draggedPiece <$> readTVarIO vState
      case dp of
        (Just _) -> dropDraggedPiece vState h pt -- if draggedPiece is from holding
        Nothing -> pickUpPiece vState pt

    MouseLeftUp click_pt _ -> dropDraggedPiece vState h click_pt

    MouseLeftDrag pt _ -> updateMousePosition vState pt

    _ -> return ()


updateMousePosition :: TVar BoardState -> Point -> IO ()
updateMousePosition vState pt = atomically $ modifyTVar vState
  (\s -> s{ mousePt = pt, draggedPiece = setNewPoint <$> draggedPiece s})
  where
    setNewPoint :: DraggedPiece -> DraggedPiece
    setNewPoint (DraggedPiece _ p o) = DraggedPiece pt p o


dropDraggedPiece :: TVar BoardState -> Handle -> Point -> IO ()
dropDraggedPiece vState h click_pt = do
  state <- readTVarIO vState
  void $ runMaybeT $ do
      dp <- MaybeT $ return $ draggedPiece state
      case toPieceMove dp <$> pointToSquare state click_pt  of
        Just pieceMove' -> do
          let newPosition = movePiece pieceMove' (virtualPosition state)
          liftIO $ do
              varSet vState state { virtualPosition = newPosition, draggedPiece = Nothing}
              if isWaiting state
                then hPutStrLn h $ "6 " ++ show pieceMove'
                else addPreMove pieceMove'
        Nothing -> liftIO $ discardDraggedPiece vState

  where
    toPieceMove :: DraggedPiece -> Square -> PieceMove
    toPieceMove (DraggedPiece _ piece' (FromBoard fromSq)) toSq = PieceMove piece' fromSq toSq
    toPieceMove (DraggedPiece _ piece' FromHolding) toSq = DropMove piece' toSq

    addPreMove :: PieceMove -> IO ()
    addPreMove pm = atomically $ modifyTVar vState (\s -> s {preMoves = preMoves s ++ [pm]})


-- | Pick up piece from board
-- only possible if, user is playing (has a color) and color of piece matches color of user
pickUpPiece :: TVar BoardState -> Point -> IO ()
pickUpPiece vState pt =
  atomically $ modifyTVar vState (\state' -> fromMaybe state' $ do
    sq' <- pointToSquare state' pt
    color' <- userColor_ state'
    piece' <- mfilter (hasColor color') (getPiece (virtualPosition state') sq')
    return state' { virtualPosition = removePiece (virtualPosition state') sq'
                  , draggedPiece = Just $ DraggedPiece pt piece' $ FromBoard sq'})


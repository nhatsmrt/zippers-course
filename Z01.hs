{-# OPTIONS_GHC -Wall #-}
{-# OPTIONS_GHC -fno-warn-unused-imports #-}

module Z01 where

import Control.Monad((>=>))
import Data.Bool(bool)
import Data.List(unfoldr, find)
import Data.Maybe(fromMaybe)

-- List x ~ 1 + x * List x
type List x = [x]

-- d/dx. List x
data ListDerivative x =
  ListDerivative [x] [x]
  deriving (Eq, Show)

instance Functor ListDerivative where
  fmap f (ListDerivative l r) =
    ListDerivative (fmap f l) (fmap f r)

data ListZipper x =
  ListZipper
    x -- 1-hole
    (ListDerivative x)
  deriving (Eq, Show)

-- | Reverse a list with one or more elements.
reverse1 ::
  (x, [x])
  -> (x, [x])
reverse1 (h, t) =
  let cons x (h', t') =
        (x, h':t')
  in  foldl (flip cons) (h, []) t

-- | Produces a list of `x` values, starting at the given seed,
-- and until the function returns `Nothing`.
unfoldDup ::
  (x -> Maybe x)
  -> x
  -> [x]
unfoldDup k =
  unfoldr (fmap (\x -> (x, x)) . k)

-- | Returns the values to the left of the focus.
rights ::
  ListZipper x
  -> [x]
rights (ListZipper _ (ListDerivative _ r)) =
  r

-- | Returns the values to the right of the focus.
lefts ::
  ListZipper x
  -> [x]
lefts (ListZipper _ (ListDerivative l _)) =
  l

instance Functor ListZipper where
  fmap f (ListZipper x d) =
    ListZipper (f x) (fmap f d)

-- | Take a list zipper back to a list.
--
-- >>> fromListZipper (ListZipper 1 (ListDerivative [] [2,3,4,5]))
-- [1,2,3,4,5]
--
-- >>> fromListZipper (ListZipper 3 (ListDerivative [2,1] [4,5]))
-- [1,2,3,4,5]
fromListZipper ::
  ListZipper x
  -> [x]
fromListZipper zipper = ((reverse . lefts) zipper) ++ [getFocus zipper] ++ (rights zipper)

-- | Create a zipper for a list of values, with focus on the first value.
-- Returns `Nothing` if given an empty list.
--
-- >>> toListZipper [1,2,3,4,5]
-- Just (ListZipper 1 (ListDerivative [] [2,3,4,5]))
toListZipper ::
  [x]
  -> Maybe (ListZipper x)
toListZipper lst = case lst of
  h : t -> Just (ListZipper h (ListDerivative [] t))
  _ -> Nothing

-- | Move the zipper focus one position to the right.
--
-- If the zipper focus is already at the right-most position, return `Nothing`.
--
-- >>> moveRight (ListZipper 1 (ListDerivative [] [2,3,4,5]))
-- Just (ListZipper 2 (ListDerivative [1] [3,4,5]))
--
-- >>> moveRight (ListZipper 3 (ListDerivative [2,1] [4,5]))
-- Just (ListZipper 4 (ListDerivative [3,2,1] [5]))
--
-- >>> moveRight (ListZipper 5 (ListDerivative [4,3,2,1] []))
-- Nothing
moveRight ::
  ListZipper x
  -> Maybe (ListZipper x)
moveRight zipper = case rights zipper of
  h : t -> Just (ListZipper h (ListDerivative ((getFocus zipper) : (lefts zipper)) t))
  _ -> Nothing

-- | Move the zipper focus one position to the left.
--
-- If the zipper focus is already at the left-most position, return `Nothing`.
--
-- >>> moveLeft (ListZipper 5 (ListDerivative [4,3,2,1] []))
-- Just (ListZipper 4 (ListDerivative [3,2,1] [5]))
--
-- >>> moveLeft (ListZipper 3 (ListDerivative [2,1] [4,5]))
-- Just (ListZipper 2 (ListDerivative [1] [3,4,5]))
--
-- >>> moveLeft (ListZipper 1 (ListDerivative [] [2,3,4,5]))
-- Nothing
moveLeft ::
  ListZipper x
  -> Maybe (ListZipper x)
moveLeft zipper = case lefts zipper of
  h : t -> Just (ListZipper h (ListDerivative t ((getFocus zipper) : (rights zipper))))
  _ -> Nothing

-- | Move the zipper focus one position to the right.
--
-- If the zipper focus is already at the right-most position, move the focus to the start position.
--
-- /Tip/ Use `reverse1`
--
-- >>> moveRightCycle (ListZipper 5 (ListDerivative [4,3,2,1] []))
-- ListZipper 1 (ListDerivative [] [2,3,4,5])
--
-- >>> moveRightCycle (ListZipper 3 (ListDerivative [2,1] [4,5]))
-- ListZipper 4 (ListDerivative [3,2,1] [5])
--
-- >>> moveRightCycle (ListZipper 1 (ListDerivative [] [2,3,4,5]))
-- ListZipper 2 (ListDerivative [1] [3,4,5])
moveRightCycle ::
  ListZipper x
  -> ListZipper x
moveRightCycle zipper = case rights zipper of
  h : t -> ListZipper h (ListDerivative ((getFocus zipper) : (lefts zipper)) t)
  [] -> case reverse1 (getFocus zipper, lefts zipper) of
    (newFocus, newRight) -> ListZipper newFocus (ListDerivative [] newRight)

-- | Move the zipper focus one position to the left.
--
-- If the zipper focus is already at the left-most position, move the focus to the end position.
--
-- /Tip/ Use `reverse1`
--
-- >>> moveLeftCycle (ListZipper 5 (ListDerivative [4,3,2,1] []))
-- ListZipper 4 (ListDerivative [3,2,1] [5])
--
-- >>> moveLeftCycle (ListZipper 3 (ListDerivative [2,1] [4,5]))
-- ListZipper 2 (ListDerivative [1] [3,4,5])
--
-- >>> moveLeftCycle (ListZipper 1 (ListDerivative [] [2,3,4,5]))
-- ListZipper 5 (ListDerivative [4,3,2,1] [])
moveLeftCycle ::
  ListZipper x
  -> ListZipper x
moveLeftCycle zipper = case lefts zipper of
  h : t -> ListZipper h (ListDerivative t ((getFocus zipper) : (rights zipper)))
  [] -> case reverse1 (getFocus zipper, rights zipper) of
    (newFocus, newLeft) -> ListZipper newFocus (ListDerivative newLeft [])

-- | Modify the zipper focus using the given function.
--
-- >>> modifyFocus (+10) (ListZipper 5 (ListDerivative [4,3,2,1] []))
-- ListZipper 15 (ListDerivative [4,3,2,1] [])
--
-- >>> modifyFocus (+10) (ListZipper 3 (ListDerivative [2,1] [4,5]))
-- ListZipper 13 (ListDerivative [2,1] [4,5])
--
-- >>> modifyFocus (+10) (ListZipper 1 (ListDerivative [] [2,3,4,5]))
-- ListZipper 11 (ListDerivative [] [2,3,4,5])
modifyFocus ::
  (x -> x)
  -> ListZipper x
  -> ListZipper x
modifyFocus f (ListZipper focus (ListDerivative left right)) =
  (ListZipper (f focus) (ListDerivative left right))

-- | Set the zipper focus to the given value.
--
-- /Tip/ Use `modifyFocus`
--
-- >>> setFocus 99 (ListZipper 5 (ListDerivative [4,3,2,1] []))
-- ListZipper 99 (ListDerivative [4,3,2,1] [])
--
-- >>> setFocus 99 (ListZipper 3 (ListDerivative [2,1] [4,5]))
-- ListZipper 99 (ListDerivative [2,1] [4,5])
--
-- >>> setFocus 99 (ListZipper 1 (ListDerivative [] [2,3,4,5]))
-- ListZipper 99 (ListDerivative [] [2,3,4,5])
setFocus ::
  x
  -> ListZipper x
  -> ListZipper x
setFocus x = modifyFocus (\_ -> x)

-- | Return the zipper focus.
--
-- getFocus (ListZipper 5 (ListDerivative [4,3,2,1] []))
-- 5
--
-- >>> getFocus (ListZipper 3 (ListDerivative [2,1] [4,5]))
-- 3
--
-- >>> getFocus (ListZipper 1 (ListDerivative [] [2,3,4,5]))
-- 1
getFocus ::
  ListZipper x
  -> x
getFocus (ListZipper focus _) = focus

-- | Duplicate a zipper of zippers, from the given zipper.
--
-- /Tip/ Use `unfoldDup`
-- /Tip/ Use `moveRight`
-- /Tip/ Use `moveLeft`
--
-- >>> duplicate (ListZipper 1 (ListDerivative [] [2,3,4,5]))
-- ListZipper (ListZipper 1 (ListDerivative [] [2,3,4,5])) (ListDerivative [] [ListZipper 2 (ListDerivative [1] [3,4,5]),ListZipper 3 (ListDerivative [2,1] [4,5]),ListZipper 4 (ListDerivative [3,2,1] [5]),ListZipper 5 (ListDerivative [4,3,2,1] [])])
--
-- >>> duplicate (ListZipper 3 (ListDerivative [2,1] [4,5]))
-- ListZipper (ListZipper 3 (ListDerivative [2,1] [4,5])) (ListDerivative [ListZipper 2 (ListDerivative [1] [3,4,5]),ListZipper 1 (ListDerivative [] [2,3,4,5])] [ListZipper 4 (ListDerivative [3,2,1] [5]),ListZipper 5 (ListDerivative [4,3,2,1] [])])
--
-- >>> duplicate (ListZipper 5 (ListDerivative [4,3,2,1] []))
-- ListZipper (ListZipper 5 (ListDerivative [4,3,2,1] [])) (ListDerivative [ListZipper 4 (ListDerivative [3,2,1] [5]),ListZipper 3 (ListDerivative [2,1] [4,5]),ListZipper 2 (ListDerivative [1] [3,4,5]),ListZipper 1 (ListDerivative [] [2,3,4,5])] [])
duplicate ::
  ListZipper x
  -> ListZipper (ListZipper x)
duplicate zipper = ListZipper zipper (ListDerivative (unfoldDup moveLeft zipper) (unfoldDup moveRight zipper))

-- | This is a test of `getFocus` and `duplicate` that should always return `Nothing`.
-- If the test fails, two unequal values (which should be equal) are returned in `Just`.
--
-- >>> law1 (ListZipper 10 (ListDerivative [] []))
-- Nothing
--
-- >>> law1 (ListZipper 10 (ListDerivative [11] []))
-- Nothing
--
-- >>> law1 (ListZipper 10 (ListDerivative [] [13]))
-- Nothing
--
-- >>> law1 (ListZipper 10 (ListDerivative [11, 12] [13, 14]))
-- Nothing
law1 ::
  Eq x =>
  ListZipper x
  -> Maybe (ListZipper x, ListZipper x)
law1 x =
  let x' = getFocus (duplicate x)
  in  if x == x'
        then
          Nothing
        else
          Just (x, x')

-- | This is a test of `getFocus` and `duplicate` that should always return `Nothing`.
-- If the test fails, two unequal values (which should be equal) are returned in `Just`.
--
-- >>> law2 (ListZipper 10 (ListDerivative [] []))
-- Nothing
--
-- >>> law2 (ListZipper 10 (ListDerivative [11] []))
-- Nothing
--
-- >>> law2 (ListZipper 10 (ListDerivative [] [13]))
-- Nothing
--
-- >>> law2 (ListZipper 10 (ListDerivative [11, 12] [13, 14]))
-- Nothing
law2 ::
  Eq x =>
  ListZipper x
  -> Maybe (ListZipper x, ListZipper x)
law2 x =
  let x' = fmap getFocus (duplicate x)
  in  if x == x'
        then
          Nothing
        else
          Just (x, x')

-- | This is a test of `duplicate` that should always return `Nothing`.
-- If the test fails, two unequal values (which should be equal) are returned in `Just`.
--
-- >>> law3 (ListZipper 10 (ListDerivative [] []))
-- Nothing
--
-- >>> law3 (ListZipper 10 (ListDerivative [11] []))
-- Nothing
--
-- >>> law3 (ListZipper 10 (ListDerivative [] [13]))
-- Nothing
--
-- >>> law3 (ListZipper 10 (ListDerivative [11, 12] [13, 14]))
-- Nothing
law3 ::
  Eq x =>
  ListZipper x
  -> Maybe (ListZipper x, ListZipper (ListZipper (ListZipper x)), ListZipper (ListZipper (ListZipper x)))
law3 x =
  let x' = duplicate (duplicate x)
      x'' = fmap duplicate (duplicate x)
  in  if x' == x''
        then
          Nothing
        else
          Just (x, x', x'')

-- | Move the zipper focus to the end position.
--
-- /Tip/ Use `moveRight` and `moveEnd`
--
-- >>> moveEnd (ListZipper 1 (ListDerivative [] [2,3,4,5]))
-- ListZipper 5 (ListDerivative [4,3,2,1] [])
--
-- >>> moveEnd (ListZipper 3 (ListDerivative [2,1] [4,5]))
-- ListZipper 5 (ListDerivative [4,3,2,1] [])
--
-- >>> moveEnd (ListZipper 5 (ListDerivative [4,3,2,1] []))
-- ListZipper 5 (ListDerivative [4,3,2,1] [])
moveEnd ::
  ListZipper x
  -> ListZipper x
moveEnd zipper = case moveRight zipper of
  Nothing -> zipper -- can't move right anymore
  Just righted -> moveEnd righted

-- | Move the zipper focus to the start position.
--
-- /Tip/ Use `moveLeft` and `moveStart`
--
-- >>> moveStart (ListZipper 1 (ListDerivative [] [2,3,4,5]))
-- ListZipper 1 (ListDerivative [] [2,3,4,5])
--
-- >>> moveStart (ListZipper 3 (ListDerivative [2,1] [4,5]))
-- ListZipper 1 (ListDerivative [] [2,3,4,5])
--
-- >>> moveStart (ListZipper 5 (ListDerivative [4,3,2,1] []))
-- ListZipper 1 (ListDerivative [] [2,3,4,5])
moveStart ::
  ListZipper x
  -> ListZipper x
moveStart zipper = case moveLeft zipper of
  Nothing -> zipper -- can't move left anymore
  Just lefted -> moveStart lefted

-- | Move the zipper focus right until the focus satisfies the given predicate.
--
-- /Tip/ Use `duplicate` and `rights`
--
-- >>> findRight even (ListZipper 1 (ListDerivative [] [2,3,4,5]))
-- Just (ListZipper 2 (ListDerivative [1] [3,4,5]))
--
-- >>> findRight even (ListZipper 3 (ListDerivative [2,1] [4,5]))
-- Just (ListZipper 4 (ListDerivative [3,2,1] [5]))
--
-- >>> findRight even (ListZipper 5 (ListDerivative [4,3,2,1] []))
-- Nothing
findRight ::
  (x -> Bool)
  -> ListZipper x
  -> Maybe (ListZipper x)
findRight cond zipper = find (cond . getFocus) ((rights . duplicate) zipper)

-- | Move the zipper focus left until the focus satisfies the given predicate.
--
-- /Tip/ Use `duplicate` and `lefts`
--
-- >>> findLeft even (ListZipper 1 (ListDerivative [] [2,3,4,5]))
-- Nothing
--
-- >>> findLeft even (ListZipper 3 (ListDerivative [2,1] [4,5]))
-- Just (ListZipper 2 (ListDerivative [1] [3,4,5]))
--
-- >>> findLeft even (ListZipper 5 (ListDerivative [4,3,2,1] []))
-- Just (ListZipper 4 (ListDerivative [3,2,1] [5]))
findLeft ::
  (x -> Bool)
  -> ListZipper x
  -> Maybe (ListZipper x)
findLeft cond zipper = find (cond . getFocus) ((lefts . duplicate) zipper)

-- | If the zipper focus satisfies the given predicate, return the given zipper.
-- Otherwise, move the zipper focus left until the focus satisfies the given predicate.
-- This may be the thought of as `findRight` but the zipper may not move, if the focus satisfies the predicate.
findLeftIncl ::
  (x -> Bool)
  -> ListZipper x
  -> Maybe (ListZipper x)
findLeftIncl p z =
  bool (findLeft p z) (Just z) (p (getFocus z))

-- | Given a list of integers, on the second-to-last even integer in the list,
-- add 99 to the subsequent element.
-- If the list does not have a second-to-last even number, leave the list
-- unchanged.
-- Assume all lists are finite length.
--
-- /Tip/ Use `findLeftIncl` to find the last and `findLeft` to find the second-to-last
-- /Tip/ Write a utility function :: (x -> Bool) -> [x] -> Maybe (ListZipper x)
--       which makes a zipper, moves the focus to the end, moves left to the last even number,
--       then moves left to the second-to-last even number.
--
-- >>> example1 []
-- []
--
-- >>> example1 [1]
-- [1]
--
-- >>> example1 [2]
-- [2]
--
-- >>> example1 [2,3]
-- [2,3]
--
-- >>> example1 [2,3,4]
-- [2,102,4]
--
-- >>> example1 [1,33,77,222,3,4]
-- [1,33,77,222,102,4]
example1 ::
  Integral x =>
  [x]
  -> [x]
example1 lst = case findDesiredFocus even lst of
  Nothing -> lst
  Just zipper -> fromListZipper (modifyFocus ((+) 99) zipper)
  where
    findDesiredFocus :: (x -> Bool) -> [x] -> Maybe (ListZipper x)
    findDesiredFocus cond lst = (moveEnd <$> (toListZipper lst)) >>= (findLeftIncl cond) >>= (findLeft cond) >>= moveRight

data Move =
  MoveLeft
  | MoveRight
  | MoveLeftCycle
  | MoveRightCycle
  | MoveStart
  | MoveEnd
  deriving (Eq, Show)

makeMoves ::
  [Move]
  -> ListZipper x
  -> Maybe (ListZipper x)
makeMoves =
  let m MoveLeft =
        moveLeft
      m MoveRight =
        moveRight
      m MoveLeftCycle =
        Just . moveLeftCycle
      m MoveRightCycle =
        Just . moveRightCycle
      m MoveStart =
        Just . moveStart
      m MoveEnd =
        Just . moveEnd
  in  foldr (\mv k -> k >=> m mv) pure

-- | Write a function that takes:
-- * a string modifier
-- * a list of zipper moves
-- * a list of pairs of zipper moves and string
-- Move a zipper on the given list, according to the given list of moves.
-- If that zipper position has been visited before, stop and return the zipper as a list.
-- Otherwise, update the string at the focus with the given function, then move the zipper
-- according to the list of zipper moves at the focus.
-- Continue this until an already-visited position is arrived at, or the zipper moves off bounds.
--
-- /Tip/ Use `makeMoves`
-- /Tip/ Write a recursive function that loops on moves and a zipper, while keeping track of visited focii
example2 ::
  (String -> String)
  -> [Move]
  -> [([Move], String)]
  -> [([Move], String)]
example2 =
  error "todo: Z01#example2"

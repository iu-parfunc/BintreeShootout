{-# LANGUAGE CPP #-}

-- |

module Main where

import Data.List (sort)
import Control.Exception
import Control.Monad
import Data.Time.Clock
import System.Environment

import GHC.Conc (par, pseq)
    
-- Strict version
--------------------------------------------------------------------------------

data Tree = Leaf {-# UNPACK #-} !Int
          | Node !Tree !Tree
  deriving Show
            
-- | Build a fully-evaluated tree
buildTree :: Int -> IO Tree
buildTree n = evaluate $ go 1 n
  where
  go root 0 = Leaf root
  go root n = Node (go root (n-1))
                   (go (root + 2^(n-1)) (n-1))

add1Tree :: Tree -> Tree
add1Tree (Leaf n)   = Leaf (n+1)
add1Tree (Node x y) = Node (add1Tree x) (add1Tree y)

sumtree :: Tree -> Int
sumtree (Leaf n)   = n
sumtree (Node x y) = (sumtree x) + (sumtree y)


#ifdef PARALLEL
add1Par :: Tree -> Int -> Tree
add1Par x          0 = add1Tree x
add1Par (Leaf n)   i = Leaf (n+1)
add1Par (Node x y) i =
    let x' = add1Par x (i-1)
        y' = add1Par y (i-1)
    in x' `par` y' `pseq`
       Node x' y'

{-# NOINLINE benchParAdd1 #-}
benchParAdd1 :: Int -> Tree -> IO Tree
benchParAdd1 _ tr = evaluate (add1Par tr 6)
#endif
                     
-- leftmost (Leaf n) = n
-- leftmost (Node x _) = leftmost x

--------------------------------------------------------------------------------

timeit act =
    do tm1 <- getCurrentTime
       x <- act
       tm2 <- getCurrentTime
       return (tm1,tm2,x)

{-# NOINLINE benchAdd1 #-}
benchAdd1 :: Int -> Tree -> IO Tree
benchAdd1 _ tr = evaluate (add1Tree tr)

{-# NOINLINE benchSum #-}
benchSum :: Int -> Tree -> IO Int
benchSum _ tr = evaluate (sumtree tr)

main :: IO ()
main =
 do args <- getArgs
    let (which,mode,power,iters) =
                case args of
                  [wh,md,p,i] -> (wh, md, read p, read i)
                  _   -> error $ "Bad command line args." ++
                            "  Expected <bench>=sum|build|add1 <mode>=par|seq <depth> <iters> got: "
                            ++show args
    tr0  <- buildTree power
    t1   <- getCurrentTime
    times <- forM [1 .. iters :: Int] $ \ix -> do      
      tr' <- case (which,mode) of
#ifdef PARALLEL               
               ("add1","par") -> void (benchParAdd1 ix tr0)
               (oth,   "par") -> error ("Benchmark mode unimplemented (in parallel): "++oth)
#endif
               ("add1","seq") -> void (benchAdd1    ix tr0)
               ("sum","seq")  -> void (benchSum     ix tr0)
               pr -> error$ "does not support (or was not compiled with) mode: "++show pr
      putStr "."
      return ()
--      return tr'
      --evaluate (leftmost tr')
      -- return (diffUTCTime en st)
    t2 <- getCurrentTime
    --let sorted = sort times
    let diffT = diffUTCTime t2 t1
    putStrLn $ ""
    putStrLn $ " BATCHTIME: " ++ show (fromRational (toRational diffT) :: Double)
    --putStrLn $ "\nAll times: " ++ show sorted
    --putStrLn $ "MEDIANTIME: "++ show (sorted !! (iters `quot` 2))

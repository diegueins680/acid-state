{-# LANGUAGE DeriveDataTypeable, TypeFamilies, StandaloneDeriving #-}
module Main (main) where

import Data.Acid.Core
import Data.Acid.Local

import qualified Control.Monad.State as State
import Control.Monad.Reader
import System.Environment
import Data.Binary

import Data.Typeable

------------------------------------------------------
-- The Haskell structure that we want to encapsulate

data HelloWorldState = HelloWorldState String
    deriving (Show, Typeable)

instance Binary HelloWorldState where
    put (HelloWorldState state) = put state
    get = liftM HelloWorldState get

------------------------------------------------------
-- The transaction we will execute over the state.

writeState :: String -> Update HelloWorldState ()
writeState newValue
    = State.put (HelloWorldState newValue)

queryState :: Query HelloWorldState String
queryState = do HelloWorldState string <- ask
                return string


------------------------------------------------------
-- This is how AcidState is used:

main :: IO ()
main = do acid <- openAcidState (HelloWorldState "Hello world")
          args <- getArgs
          if null args
             then do string <- query acid QueryState
                     putStrLn $ "The state is: " ++ string
             else do update acid (WriteState (unwords args))
                     putStrLn $ "The state has been modified!"


------------------------------------------------------
-- The gritty details. These things may be done with
-- Template Haskell in the future.

data WriteState = WriteState String
data QueryState = QueryState


deriving instance Typeable WriteState
instance Binary WriteState where
    put (WriteState st) = put st
    get = liftM WriteState get
instance Method WriteState where
    type MethodResult WriteState = ()
    type MethodState WriteState = HelloWorldState
instance UpdateEvent WriteState

deriving instance Typeable QueryState
instance Binary QueryState where
    put QueryState = return ()
    get = return QueryState
instance Method QueryState where
    type MethodResult QueryState = String
    type MethodState QueryState = HelloWorldState
instance QueryEvent QueryState


instance IsAcidic HelloWorldState where
    acidEvents = [ UpdateEvent (\(WriteState newState) -> writeState newState)
                 , QueryEvent (\QueryState             -> queryState)
                 ]
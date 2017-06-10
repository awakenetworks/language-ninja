-- Copyright Neil Mitchell 2011-2017.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are
-- met:
--
--     * Redistributions of source code must retain the above copyright
--       notice, this list of conditions and the following disclaimer.
--
--     * Redistributions in binary form must reproduce the above
--       copyright notice, this list of conditions and the following
--       disclaimer in the documentation and/or other materials provided
--       with the distribution.
--
--     * Neither the name of Neil Mitchell nor the names of other
--       contributors may be used to endorse or promote products derived
--       from this software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
-- "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
-- LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
-- A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
-- OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
-- SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
-- LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
-- DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
-- THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
-- (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
-- OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

{-# LANGUAGE TupleSections #-}

-- | The IO in this module is only to evaluate an environment variable,
--   the 'Env' itself is passed around purely.
module Language.Ninja.Types
  ( Str, FileStr
  , Expr (..), Env, newEnv, askVar, askExpr, addEnv, addBind, addBinds
  , Ninja (..), newNinja, Build (..), Rule (..)
  ) where

import           Control.Applicative
import           Control.Monad.IO.Class

import qualified Data.ByteString.Char8  as BS
import           Data.Maybe

import           Language.Ninja.Env

-- | FIXME: doc
type Str = BS.ByteString

-- | FIXME: doc
type FileStr = Str

-- | FIXME: doc
data Expr
  = Exprs [Expr]
  -- ^ FIXME: doc
  | Lit Str
  -- ^ FIXME: doc
  | Var Str
  -- ^ FIXME: doc
  deriving (Eq, Show)

-- | FIXME: doc
askExpr :: (MonadIO m) => Env Str Str -> Expr -> m Str
askExpr e (Exprs xs) = BS.concat <$> mapM (askExpr e) xs
askExpr _ (Lit x)    = pure x
askExpr e (Var x)    = askVar e x

-- | FIXME: doc
askVar :: (MonadIO m) => Env Str Str -> Str -> m Str
askVar e x = fromMaybe BS.empty <$> askEnv e x

-- | FIXME: doc
addBind :: (MonadIO m) => Env Str Str -> Str -> Expr -> m ()
addBind e k v = askExpr e v >>= addEnv e k

-- | FIXME: doc
addBinds :: (MonadIO m) => Env Str Str -> [(Str, Expr)] -> m ()
addBinds e bs = mapM (\(a, b) -> (a,) <$> askExpr e b) bs
                >>= mapM_ (uncurry (addEnv e))

-- | FIXME: doc
data Ninja
  = MkNinja
    { rules     :: [(Str, Rule)]
      -- ^ FIXME: doc
    , singles   :: [(FileStr, Build)]
      -- ^ FIXME: doc
    , multiples :: [([FileStr], Build)]
      -- ^ FIXME: doc
    , phonys    :: [(Str, [FileStr])]
      -- ^ FIXME: doc
    , defaults  :: [FileStr]
      -- ^ FIXME: doc
    , pools     :: [(Str, Int)]
      -- ^ FIXME: doc
    }
  deriving (Show)

-- | FIXME: doc
newNinja :: Ninja
newNinja = MkNinja [] [] [] [] [] []

-- | FIXME: doc
data Build
  = MkBuild
    { ruleName      :: Str
      -- ^ FIXME: doc
    , env           :: Env Str Str
      -- ^ FIXME: doc
    , depsNormal    :: [FileStr]
      -- ^ FIXME: doc
    , depsImplicit  :: [FileStr]
      -- ^ FIXME: doc
    , depsOrderOnly :: [FileStr]
      -- ^ FIXME: doc
    , buildBind     :: [(Str, Str)]
      -- ^ FIXME: doc
    }
  deriving (Show)

-- | FIXME: doc
newtype Rule
  = MkRule
    { ruleBind :: [(Str, Expr)]
      -- ^ FIXME: doc
    }
  deriving (Show)
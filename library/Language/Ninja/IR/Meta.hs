-- -*- coding: utf-8; mode: haskell; -*-

-- File: library/Language/Ninja/IR/Meta.hs
--
-- License:
--     Copyright 2017 Awake Security
--
--     Licensed under the Apache License, Version 2.0 (the "License");
--     you may not use this file except in compliance with the License.
--     You may obtain a copy of the License at
--
--       http://www.apache.org/licenses/LICENSE-2.0
--
--     Unless required by applicable law or agreed to in writing, software
--     distributed under the License is distributed on an "AS IS" BASIS,
--     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--     See the License for the specific language governing permissions and
--     limitations under the License.

{-# OPTIONS_GHC #-}
{-# OPTIONS_HADDOCK #-}

{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE RecordWildCards       #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE StandaloneDeriving    #-}
{-# LANGUAGE UndecidableInstances  #-}

-- |
--   Module      : Language.Ninja.IR.Meta
--   Copyright   : Copyright 2017 Awake Security
--   License     : Apache-2.0
--   Maintainer  : opensource@awakesecurity.com
--   Stability   : experimental
--
--   A datatype for Ninja top-level variables and other metadata.
module Language.Ninja.IR.Meta
  ( -- * @Meta@
    Meta, makeMeta, metaReqVersion, metaBuildDir
  ) where

import           Data.Aeson               as Aeson
import qualified Data.Aeson.Types         as Aeson

import           Data.Text                (Text)
import qualified Data.Text                as T

import           Data.Hashable            (Hashable (..))
import           GHC.Generics             (Generic)
import qualified Test.SmallCheck.Series   as SC

import qualified Data.Versions            as Ver

import qualified Text.Megaparsec          as Mega

import           Language.Ninja.Misc.Path (Path)

import qualified Control.Lens
import           Control.Lens.Lens        (Lens')

import           Flow                     ((.>), (|>))

--------------------------------------------------------------------------------

-- | Ninja top-level metadata, as documented
--   <https://ninja-build.org/manual.html#ref_toplevel here>.
data Meta
  = MkMeta
    { _metaReqVersion :: !(Maybe Ver.Version)
    , _metaBuildDir   :: !(Maybe Path)
    }
  deriving (Eq, Ord, Show, Generic)

-- | Construct a default 'Meta' value.
{-# INLINE makeMeta #-}
makeMeta :: Meta
makeMeta = MkMeta
           { _metaReqVersion = Nothing
           , _metaBuildDir   = Nothing
           }

-- | Corresponds to the @ninja_required_version@ top-level variable.
{-# INLINE metaReqVersion #-}
metaReqVersion :: Lens' Meta (Maybe Ver.Version)
metaReqVersion = Control.Lens.lens _metaReqVersion
                 $ \(MkMeta {..}) x -> MkMeta { _metaReqVersion = x, .. }

-- | Corresponds to the @builddir@ top-level variable.
{-# INLINE metaBuildDir #-}
metaBuildDir :: Lens' Meta (Maybe Path)
metaBuildDir = Control.Lens.lens _metaBuildDir
               $ \(MkMeta {..}) x -> MkMeta { _metaBuildDir = x, .. }

-- | Default 'Hashable' instance via 'Generic'.
instance Hashable Meta

-- | Converts to @{req-version: …, build-dir: …}@.
instance ToJSON Meta where
  toJSON (MkMeta {..})
    = [ "req-version" .= fmap versionJ _metaReqVersion
      , "build-dir"   .= _metaBuildDir
      ] |> object
    where
      versionJ :: Ver.Version -> Value
      versionJ = Ver.prettyVer .> toJSON

-- | Inverse of the 'ToJSON' instance.
instance FromJSON Meta where
  parseJSON = (withObject "Meta" $ \o -> do
                  _metaReqVersion <- (o .: "req-version") >>= maybeVersionP
                  _metaBuildDir   <- (o .: "build-dir")   >>= pure
                  pure (MkMeta {..}))
    where
      maybeVersionP :: Maybe Value -> Aeson.Parser (Maybe Ver.Version)
      maybeVersionP = fmap versionP .> sequenceA

      versionP :: Value -> Aeson.Parser Ver.Version
      versionP = withText "Version" (megaparsecToAeson Ver.version')

-- | Default 'SC.Serial' instance via 'Generic'.
instance ( Monad m
         , SC.Serial m Ver.Version
         , SC.Serial m Text
         ) => SC.Serial m Meta

-- | Default 'SC.CoSerial' instance via 'Generic'.
instance ( Monad m
         , SC.CoSerial m Ver.Version
         , SC.CoSerial m Text
         ) => SC.CoSerial m Meta

--------------------------------------------------------------------------------

-- HELPER FUNCTIONS

-- | This function converts a @megaparsec@ parser to an @aeson@ parser.
--   Mainly, it handles converting the error output from @megaparsec@ to a
--   string that is appropriate for 'fail'.
megaparsecToAeson :: Mega.Parsec Mega.Dec Text t
                  -> (Text -> Aeson.Parser t)
megaparsecToAeson parser text = case Mega.runParser parser "" text of
                                  Left  e -> fail (Mega.parseErrorPretty e)
                                  Right x -> pure x

--------------------------------------------------------------------------------
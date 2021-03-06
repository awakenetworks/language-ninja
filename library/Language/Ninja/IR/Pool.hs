-- -*- coding: utf-8; mode: haskell; -*-

-- File: library/Language/Ninja/IR/Pool.hs
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

{-# LANGUAGE DeriveGeneric         #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE InstanceSigs          #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE RecordWildCards       #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE UndecidableInstances  #-}

-- |
--   Module      : Language.Ninja.IR.Pool
--   Copyright   : Copyright 2017 Awake Security
--   License     : Apache-2.0
--   Maintainer  : opensource@awakesecurity.com
--   Stability   : experimental
--
--   Types relating to Ninja @pool@s.
--
--   @since 0.1.0
module Language.Ninja.IR.Pool
  ( -- * @Pool@
    Pool, makePool, makePoolDefault, makePoolConsole, makePoolCustom
  , poolName, poolDepth

    -- * @PoolName@
  , PoolName, makePoolNameDefault, makePoolNameConsole, makePoolNameCustom
  , _PoolNameDefault, _PoolNameConsole, _PoolNameCustom
  , poolNameText, printPoolName, parsePoolName

    -- * @PoolDepth@
  , PoolDepth
  , makePoolDepth, makePoolInfinite
  , poolDepthPositive
  ) where

import           Control.Applicative          (empty)

import qualified Control.Lens                 as Lens

import           Data.Aeson                   ((.:), (.=))
import qualified Data.Aeson                   as Aeson
import qualified Data.Aeson.Types             as Aeson

import           Data.Text                    (Text)
import qualified Data.Text                    as Text

import           Control.DeepSeq              (NFData)
import           Data.Hashable                (Hashable)
import           Data.String                  (IsString (fromString))
import           GHC.Generics                 (Generic)

import           Test.SmallCheck.Series       ((<~>), (\/))
import qualified Test.SmallCheck.Series       as SC

import qualified Language.Ninja.Misc.Positive as Misc

import           Flow                         ((.>), (|>))

--------------------------------------------------------------------------------

-- | A Ninja @pool@ declaration, as documented
--   <https://ninja-build.org/manual.html#ref_pool here>.
--
--   @since 0.1.0
data Pool
  = MkPool
    { _poolName  :: !PoolName
    , _poolDepth :: !PoolDepth
    }
  deriving (Eq, Ord, Show, Read, Generic)

-- | Construct a 'Pool', given its name and depth.
--
--   @since 0.1.0
{-# INLINEABLE makePool #-}
makePool :: PoolName -> PoolDepth -> Maybe Pool
makePool PoolNameDefault    PoolInfinite  = Just makePoolDefault
makePool PoolNameConsole    (PoolDepth 1) = Just makePoolConsole
makePool (PoolNameCustom t) (PoolDepth d) = if d >= 1
                                            then Just (makePoolCustom t d)
                                            else Nothing
makePool _                  _             = Nothing

-- | The default pool, i.e.: the one whose name is the empty string.
--
--   @since 0.1.0
{-# INLINE makePoolDefault #-}
makePoolDefault :: Pool
makePoolDefault = MkPool makePoolNameDefault PoolInfinite

-- | The @console@ pool.
--
--   @since 0.1.0
{-# INLINE makePoolConsole #-}
makePoolConsole :: Pool
makePoolConsole = MkPool makePoolNameConsole (PoolDepth 1)

-- | Create a pool with the given name and depth.
--
--   @since 0.1.0
{-# INLINE makePoolCustom #-}
makePoolCustom :: Text          -- ^ The pool name.
               -> Misc.Positive -- ^ The pool depth.
               -> Pool
makePoolCustom name depth = MkPool (makePoolNameCustom name) (PoolDepth depth)

-- | A 'Getter' that gives the name of a pool.
--
--   @since 0.1.0
{-# INLINE poolName #-}
poolName :: Lens.Getter Pool PoolName
poolName = Lens.to _poolName

-- | A 'Getter' that gives the depth of a pool.
--
--   @since 0.1.0
{-# INLINE poolDepth #-}
poolDepth :: Lens.Getter Pool PoolDepth
poolDepth = Lens.to _poolDepth

-- | Converts to @{name: …, depth: …}@.
--
--   @since 0.1.0
instance Aeson.ToJSON Pool where
  toJSON (MkPool {..})
    = [ "name"  .= _poolName
      , "depth" .= _poolDepth
      ] |> Aeson.object

-- | Inverse of the 'Aeson.ToJSON' instance.
--
--   @since 0.1.0
instance Aeson.FromJSON Pool where
  parseJSON = (Aeson.withObject "Pool" $ \o -> do
                  _poolName  <- (o .: "name")  >>= pure
                  _poolDepth <- (o .: "depth") >>= pure
                  pure (MkPool {..}))

-- | Uses the underlying instances.
--
--   @since 0.1.0
instance forall m. (Monad m, SC.Serial m Text) => SC.Serial m Pool where
  series = pure makePoolDefault
           \/ pure makePoolConsole
           \/ (let nameSeries :: SC.Series m Text
                   nameSeries = SC.series >>= (\case ""        -> empty
                                                     "console" -> empty
                                                     x         -> pure x)
               in makePoolCustom <$> nameSeries <~> SC.series)

-- | Uses the underlying instances.
--
--   @since 0.1.0
instance (Monad m, SC.CoSerial m Text) => SC.CoSerial m Pool where
  coseries = SC.coseries .> fmap (\f -> convert .> f)
    where
      convert :: Pool -> (PoolName, PoolDepth)
      convert pool = (Lens.view poolName pool, Lens.view poolDepth pool)

-- | Default 'Hashable' instance via 'Generic'.
--
--   @since 0.1.0
instance Hashable Pool

-- | Default 'NFData' instance via 'Generic'.
--
--   @since 0.1.0
instance NFData Pool

--------------------------------------------------------------------------------

-- | The name of a Ninja pool.
--
--   More information is available
--   <https://ninja-build.org/manual.html#ref_pool here>.
--
--   @since 0.1.0
data PoolName
  = PoolNameDefault
  | PoolNameConsole
  | PoolNameCustom !Text
  deriving (Eq, Ord, Show, Read, Generic)

-- | Create a 'PoolName' corresponding to the built-in default pool, i.e.: the
--   pool that is selected if the @pool@ attribute is set to the empty string.
--
--   @since 0.1.0
{-# INLINE makePoolNameDefault #-}
makePoolNameDefault :: PoolName
makePoolNameDefault = PoolNameDefault

-- | Create a 'PoolName' corresponding to the built-in @console@ pool.
--
--   @since 0.1.0
{-# INLINE makePoolNameConsole #-}
makePoolNameConsole :: PoolName
makePoolNameConsole = PoolNameConsole

-- | Create a 'PoolName' corresponding to a custom pool.
--   Note: this can fail at runtime if given the empty string or @"console"@,
--   so you should consider 'parsePoolName' as a safer alternative.
--
--   @since 0.1.0
{-# INLINEABLE makePoolNameCustom #-}
makePoolNameCustom :: Text -> PoolName
makePoolNameCustom ""        = error "Invalid pool name: \"\""
makePoolNameCustom "console" = error "Invalid pool name: \"console\""
makePoolNameCustom text      = PoolNameCustom text

-- | A one-way prism corresponding to the 'poolNameDefault' constructor.
--
--   @since 0.1.0
{-# INLINE _PoolNameDefault #-}
_PoolNameDefault :: Lens.Getter PoolName (Maybe ())
_PoolNameDefault = Lens.to (\case PoolNameDefault -> Just ()
                                  _               -> Nothing)

-- | A one-way prism corresponding to the 'poolNameConsole' constructor.
--
--   @since 0.1.0
{-# INLINE _PoolNameConsole #-}
_PoolNameConsole :: Lens.Getter PoolName (Maybe ())
_PoolNameConsole = Lens.to (\case PoolNameConsole -> Just ()
                                  _               -> Nothing)

-- | A one-way prism corresponding to the 'poolNameConsole' constructor.
--
--   @since 0.1.0
{-# INLINE _PoolNameCustom #-}
_PoolNameCustom :: Lens.Getter PoolName (Maybe Text)
_PoolNameCustom = Lens.to (\case (PoolNameCustom t) -> Just t
                                 _                  -> Nothing)

-- | An isomorphism between a 'PoolName' and the corresponding 'Text'.
--   Equivalent to @'Lens.iso' 'printPoolName' 'parsePoolName'@.
--
--   @since 0.1.0
{-# INLINE poolNameText #-}
poolNameText :: Lens.Iso' PoolName Text
poolNameText = Lens.iso printPoolName parsePoolName

-- | Convert a 'PoolName' to the string that, if the @pool@ attribute is set to
--   it, will cause the given 'PoolName' to be parsed.
--
--   >>> printPoolName makePoolNameDefault
--   ""
--
--   >>> printPoolName makePoolNameConsole
--   "console"
--
--   >>> printPoolName (makePoolNameCustom "foobar")
--   "foobar"
--
--   @since 0.1.0
{-# INLINEABLE printPoolName #-}
printPoolName :: PoolName -> Text
printPoolName PoolNameDefault    = ""
printPoolName PoolNameConsole    = "console"
printPoolName (PoolNameCustom t) = t

-- | Inverse of 'printPoolName'.
--
--   >>> parsePoolName ""
--   PoolNameDefault
--
--   >>> parsePoolName "console"
--   PoolNameConsole
--
--   >>> parsePoolName "foobar"
--   PoolNameCustom "foobar"
--
--   @since 0.1.0
{-# INLINEABLE parsePoolName #-}
parsePoolName :: Text -> PoolName
parsePoolName ""        = makePoolNameDefault
parsePoolName "console" = makePoolNameConsole
parsePoolName t         = makePoolNameCustom t

-- | Converts from string via 'parsePoolName'.
--
--   @since 0.1.0
instance IsString PoolName where
  fromString = Text.pack .> parsePoolName

-- | Converts to JSON string via 'printPoolName'.
--
--   @since 0.1.0
instance Aeson.ToJSON PoolName where
  toJSON = printPoolName .> Aeson.String

-- | Inverse of the 'Aeson.ToJSON' instance.
--
--   @since 0.1.0
instance Aeson.FromJSON PoolName where
  parseJSON = Aeson.withText "PoolName" (parsePoolName .> pure)

-- | Converts to JSON string via 'printPoolName'.
--
--   @since 0.1.0
instance Aeson.ToJSONKey PoolName where
  toJSONKey = Aeson.toJSONKeyText printPoolName

-- | Inverse of the 'Aeson.ToJSONKey' instance.
--
--   @since 0.1.0
instance Aeson.FromJSONKey PoolName where
  fromJSONKey = Aeson.mapFromJSONKeyFunction parsePoolName Aeson.fromJSONKey

-- | Uses the underlying 'Text' instance.
--
--   @since 0.1.0
instance (Monad m, SC.Serial m Text) => SC.Serial m PoolName where
  series = parsePoolName <$> (pure "" \/ pure "console" \/ SC.series)

-- | Uses the underlying 'Text' instance.
--
--   @since 0.1.0
instance (Monad m, SC.CoSerial m Text) => SC.CoSerial m PoolName where
  coseries = SC.coseries
             .> fmap (\f -> printPoolName .> f)

-- | Default 'Hashable' instance via 'Generic'.
--
--   @since 0.1.0
instance Hashable PoolName

-- | Default 'NFData' instance via 'Generic'.
--
--   @since 0.1.0
instance NFData PoolName

--------------------------------------------------------------------------------

-- | The depth of a Ninja pool.
--
--   More information is available
--   <https://ninja-build.org/manual.html#ref_pool here>.
--
--   @since 0.1.0
data PoolDepth
  = PoolDepth !Misc.Positive
  | PoolInfinite
  deriving (Eq, Ord, Show, Read, Generic)

-- | Construct a finite 'PoolDepth' from an integer, which should be a number
--   greater than or equal to 1.
--
--   @since 0.1.0
{-# INLINE makePoolDepth #-}
makePoolDepth :: Misc.Positive -> PoolDepth
makePoolDepth = PoolDepth

-- | Construct an infinite 'PoolDepth'. This constructor is needed for the
--   default pool (@pool = ""@), which has an infinite depth.
--
--   @since 0.1.0
{-# INLINE makePoolInfinite #-}
makePoolInfinite :: PoolDepth
makePoolInfinite = PoolInfinite

-- | An isomorphism between a 'PoolDepth' and a @'Maybe' 'Misc.Positive'@;
--   the 'Nothing' case maps to 'makePoolInfinite' and the 'Just' case
--   maps to 'makePoolDepth'.
--
--   @since 0.1.0
{-# INLINE poolDepthPositive #-}
poolDepthPositive :: Lens.Iso' PoolDepth (Maybe Misc.Positive)
poolDepthPositive = Lens.iso fromPD toPD
  where
    {-# INLINE fromPD #-}
    fromPD :: PoolDepth -> Maybe Misc.Positive
    fromPD (PoolDepth p) = Just p
    fromPD PoolInfinite  = Nothing

    {-# INLINE toPD #-}
    toPD :: Maybe Misc.Positive -> PoolDepth
    toPD (Just p) = PoolDepth p
    toPD Nothing  = PoolInfinite

-- | Converts 'makePoolInfinite' to @"infinite"@ and 'makePoolDepth' to the
--   corresponding JSON number.
--
--   @since 0.1.0
instance Aeson.ToJSON PoolDepth where
  toJSON (PoolDepth i) = Aeson.toJSON i
  toJSON PoolInfinite  = "infinite"

-- | Inverse of the 'Aeson.ToJSON' instance.
--
--   @since 0.1.0
instance Aeson.FromJSON PoolDepth where
  parseJSON (v@(Aeson.Number _))      = PoolDepth <$> Aeson.parseJSON v
  parseJSON (Aeson.String "infinite") = pure PoolInfinite
  parseJSON owise                     = Aeson.typeMismatch "PoolDepth" owise

-- | Default 'SC.Serial' instance via 'Generic'.
--
--   @since 0.1.0
instance (Monad m) => SC.Serial m PoolDepth where
  series = pure PoolInfinite
           \/ (SC.series |> fmap PoolDepth)

-- | Default 'SC.CoSerial' instance via 'Generic'.
--
--   @since 0.1.0
instance (Monad m) => SC.CoSerial m PoolDepth where
  coseries = SC.coseries
             .> fmap (\f -> \case (PoolDepth i) -> f (Just i)
                                  PoolInfinite  -> f Nothing)

-- | Default 'Hashable' instance via 'Generic'.
--
--   @since 0.1.0
instance Hashable PoolDepth

-- | Default 'NFData' instance via 'Generic'.
--
--   @since 0.1.0
instance NFData PoolDepth

--------------------------------------------------------------------------------

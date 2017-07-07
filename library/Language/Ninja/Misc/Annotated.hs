-- -*- coding: utf-8; mode: haskell; -*-

-- File: library/Language/Ninja/Misc/Annotated.hs
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

{-# LANGUAGE KindSignatures #-}

-- |
--   Module      : Language.Ninja.Misc.Annotated
--   Copyright   : Copyright 2017 Awake Security
--   License     : Apache-2.0
--   Maintainer  : opensource@awakesecurity.com
--   Stability   : experimental
--
--   FIXME: doc
module Language.Ninja.Misc.Annotated
  ( Annotated (..)
  ) where

import           Control.Lens.Lens (Lens')

--------------------------------------------------------------------------------

-- | FIXME: doc
class (Functor ty) => Annotated (ty :: * -> *) where
  -- | FIXME: doc
  annotation :: Lens' (ty ann) ann
  -- annotation :: Lens (ty ann) (ty ann') ann ann'

--------------------------------------------------------------------------------
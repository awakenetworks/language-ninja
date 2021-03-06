-- -*- coding: utf-8; mode: haskell; -*-

-- File: tests/Tests/ReferenceLexer/Str0.hs
--
-- License:
--     Copyright Neil Mitchell  2011-2017.
--     Copyright Awake Security 2017.
--     All rights reserved.
--
--     Redistribution and use in source and binary forms, with or without
--     modification, are permitted provided that the following conditions are
--     met:
--
--         * Redistributions of source code must retain the above copyright
--           notice, this list of conditions and the following disclaimer.
--
--         * Redistributions in binary form must reproduce the above
--           copyright notice, this list of conditions and the following
--           disclaimer in the documentation and/or other materials provided
--           with the distribution.
--
--         * Neither the name of Neil Mitchell nor the names of other
--           contributors may be used to endorse or promote products derived
--           from this software without specific prior written permission.
--
--     THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
--     "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
--     LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
--     A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
--     OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
--     SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
--     LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
--     DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
--     THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
--     (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
--     OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

-- |
--   Module      : Tests.ReferenceLexer.Str0
--   Copyright   : Copyright 2011-2017 Neil Mitchell
--   License     : BSD3
--   Maintainer  : opensource@awakesecurity.com
--   Stability   : experimental
--
--   A NUL-terminated bytestring type used in the reference lexer.
module Tests.ReferenceLexer.Str0
  ( Str0 (..)
  , break0, break00, dropWhile0, head0, list0, span0, tail0, take0
  ) where

import           Data.ByteString          (ByteString)
import qualified Data.ByteString.Char8    as BSC8
import qualified Data.ByteString.Internal as BS.Internal
import qualified Data.ByteString.Unsafe   as BS.Unsafe

import           Data.Word                (Word8)
import qualified Foreign.Ptr
import qualified Foreign.Storable
import           GHC.Exts                 (Ptr (Ptr))
import           System.IO.Unsafe         (unsafePerformIO)

--------------------------------------------------------------------------------

-- | A null-terminated strict bytestring.
newtype Str0
  = MkStr0 ByteString

-- | Convert a pointer to a 'Word8' to a 'Char'.
--
--   TODO: uses unsafePerformIO
char :: Ptr Word8 -> Char
char x = BS.Internal.w2c $ unsafePerformIO $ Foreign.Storable.peek x

-- | Increment a pointer by one byte.
next :: Ptr Word8 -> Ptr Word8
next x = x `Foreign.Ptr.plusPtr` 1

-- | Similar to 'BSC8.dropWhile', but for null-terminated bytestrings.
{-# INLINE dropWhile0 #-}
dropWhile0 :: (Char -> Bool) -> Str0 -> Str0
dropWhile0 f x = snd $ span0 f x

-- | Similar to 'BSC8.span', but for null-terminated bytestrings.
{-# INLINE span0 #-}
span0 :: (Char -> Bool) -> Str0 -> (ByteString, Str0)
span0 f = break0 (not . f)

-- | Similar to 'BSC8.break', but for null-terminated bytestrings.
{-# INLINE break0 #-}
break0 :: (Char -> Bool) -> Str0 -> (ByteString, Str0)
break0 f = break00 (\c -> (c == '\0') || f c)

-- | Similar to 'break0', but it assumes that the given predicate will return
--   true for @'\0'@, allowing it to be slightly faster.
{-# INLINE break00 #-}
break00 :: (Char -> Bool) -> Str0 -> (ByteString, Str0)
break00 f (MkStr0 bs) = (initial, rest)
  where
    initial = BS.Unsafe.unsafeTake i bs
    rest    = MkStr0 $ BS.Unsafe.unsafeDrop i bs

    i = System.IO.Unsafe.unsafePerformIO $
      BS.Unsafe.unsafeUseAsCString bs $ \ptr -> do
      let start = Foreign.Ptr.castPtr ptr :: Ptr Word8
      let end = go start
      pure $! Ptr end `Foreign.Ptr.minusPtr` start

    go s@(Ptr a) | f (char s) = a
                 | otherwise  = go (next s)

-- | Similar to 'BSC8.head', but for null-terminated bytestrings.
head0 :: Str0 -> Char
head0 (MkStr0 x) = BS.Internal.w2c $ BS.Unsafe.unsafeHead x

-- | Similar to 'BSC8.tail', but for null-terminated bytestrings.
tail0 :: Str0 -> Str0
tail0 (MkStr0 x) = MkStr0 $ BS.Unsafe.unsafeTail x

-- | Similar to 'BSC8.uncons', but for null-terminated bytestrings.
list0 :: Str0 -> (Char, Str0)
list0 x = (head0 x, tail0 x)

-- | Similar to 'BSC8.take', but for null-terminated bytestrings.
take0 :: Int -> Str0 -> ByteString
take0 i (MkStr0 x) = BSC8.takeWhile (/= '\0') $ BSC8.take i x

--------------------------------------------------------------------------------

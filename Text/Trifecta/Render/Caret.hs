module Text.Trifecta.Render.Caret
  ( Caret(..)
  , HasCaret(..)
  , Careted(..)
  , careted
  -- * Internals
  , drawCaret
  , addCaret
  , caretEffects
  ) where

import Control.Applicative
import Control.Comonad
import Data.ByteString (ByteString)
import Data.Foldable
import Data.Functor.Bind
import Data.Hashable
import Data.Semigroup
import Data.Semigroup.Foldable
import Data.Semigroup.Traversable
import Data.Traversable
import Prelude hiding (span)
import System.Console.Terminfo.Color
import System.Console.Terminfo.PrettyPrint
import Text.Trifecta.Bytes
import Text.Trifecta.Delta
import Text.Trifecta.It
import Text.Trifecta.Parser.Class
import Text.Trifecta.Render.Prim

-- |
-- > In file included from baz.c:9
-- > In file included from bar.c:4
-- > foo.c:8:36: note
-- > int main(int argc, char ** argv) { int; }
-- >                                    ^
data Caret = Caret !Delta {-# UNPACK #-} !ByteString deriving (Eq,Ord,Show)

instance Hashable Caret where
  hash (Caret d bs) = hash d `hashWithSalt` bs

caretEffects :: [ScopedEffect]
caretEffects = [soft (Foreground Green), soft Bold]

drawCaret :: Delta -> Delta -> Lines -> Lines
drawCaret p = ifNear p $ draw caretEffects 1 (column p) "^"

addCaret :: Delta -> Render -> Render
addCaret p r = drawCaret p .# r

class HasCaret t where
  caret :: t -> Caret

instance HasCaret Caret where
  caret = id

instance HasBytes Caret where
  bytes = bytes . delta

instance HasDelta Caret where
  delta (Caret d _) = d

instance Renderable Caret where
  render (Caret d bs) = addCaret d $ surface d bs

instance Semigroup Caret where
  a <> _ = a

data Careted a = a :^ Caret deriving (Eq,Ord,Show)

instance Functor Careted where
  fmap f (a :^ s) = f a :^ s

instance Extend Careted where
  extend f as@(_ :^ s) = f as :^ s

instance Comonad Careted where
  extract (a :^ _) = a

instance Foldable Careted where
  foldMap f (a :^ _) = f a

instance Traversable Careted where
  traverse f (a :^ s) = (:^ s) <$> f a

instance Foldable1 Careted where
  foldMap1 f (a :^ _) = f a

instance Traversable1 Careted where
  traverse1 f (a :^ s) = (:^ s) <$> f a

instance Renderable (Careted a) where
  render = render . caret

instance HasCaret (Careted a) where
  caret (_ :^ c) = c

instance Hashable a => Hashable (Careted a) where
  
careted :: MonadParser m => m a -> m (Careted a)
careted p = do
  m <- getInput
  l <- line m
  a <- p
  return $ a :^ Caret m l
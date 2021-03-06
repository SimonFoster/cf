-- |
-- A "standard" continued fraction, whose terms are all either
-- positive or negative.
module Math.ContinuedFraction.Simple
  (
    CF,
    showCF,
    sqrt2,
    exp1
  ) where

import Data.Ratio

newtype CF = CF [Integer]

-- The coefficients of the homographic function (ax + b) / (cx + d)
type Hom = (Integer, Integer,
            Integer, Integer)

-- Possibly output a term
homEmittable :: Hom -> Maybe Integer
homEmittable (n0, n1,
              d0, d1) = if d0 /= 0 && d1 /= 0 && r == s then
                        Just r
                      else
                        Nothing
  where r = n0 `quot` d0
        s = n1 `quot` d1

homEmit :: Hom -> Integer -> Hom
homEmit (n0, n1,
         d0, d1) x = (d0,        d1,
                      n0 - d0*x, n1 - d1*x)

homAbsorb :: Hom -> Integer -> Hom
homAbsorb (n0, n1,
           d0, d1) x = (n0*x + n1, n0,
                        d0*x + d1, d0)

-- Apply a hom to a continued fraction
hom :: Hom -> CF -> CF
hom (0, 0,
     _, _) _ = CF [0]
hom (_, _,
     0, 0) _ = CF []
hom (n0, _,
     d0, _) (CF []) = fromRational (n0 % d0)
hom h (CF (x:xs)) = case homEmittable h of
                     Just d -> let (CF rest) = hom (homEmit h d) (CF (x:xs)) in CF (d : rest)
                     Nothing -> hom (homAbsorb h x) (CF xs)

-- The coefficients of the bihomographic function (axy + by + cx + d) / (exy + fy + gx + h)
type Bihom = (Integer, Integer, Integer, Integer,
              Integer, Integer, Integer, Integer)

bihomEmittable :: Bihom -> Maybe Integer
bihomEmittable (n0, n1, n2, n3,
                d0, d1, d2, d3) = if d0 /= 0 && d1 /= 0 && d2 /= 0 && d3 /= 0 && ratiosAgree then
                                Just r
                              else
                                Nothing
  where r = n0 `quot` d0
        ratiosAgree = r == n1 `quot` d1 && r == n2 `quot` d2 && r == n3 `quot` d3

bihomEmit :: Bihom -> Integer -> Bihom
bihomEmit (n0, n1, n2, n3,
           d0, d1, d2, d3) x = (d0,        d1,        d2,        d3,
                                n0 - d0*x, n1 - d1*x, n2 - d2*x, n3 - d3*x)

bihomAbsorbX :: Bihom -> Integer -> Bihom
bihomAbsorbX (n0, n1, n2, n3,
              d0, d1, d2, d3) x = (n0*x + n1, n0, n2*x + n3, n2,
                                   d0*x + d1, d0, d2*x + d3, d2)

bihomAbsorbY :: Bihom -> Integer -> Bihom
bihomAbsorbY (n0, n1, n2, n3,
              d0, d1, d2, d3) y = (n0*y + n2, n1*y + n3, n0, n1,
                                   d0*y + d2, d1*y + d3, d0, d1)

-- Decide which of x and y to pull a term from
shouldIngestX :: Bihom -> Bool
shouldIngestX (_, _, _, _,
               _, 0, _, 0) = True
shouldIngestX (_, _, _, _,
               _, _, 0, 0) = False
shouldIngestX (_a, b, c, d,
               _e, f, g, h) = abs (g*h*b - g*d*f) < abs (f*h*c - g*d*f)

-- Apply a bihom to two continued fractions
bihom :: Bihom -> CF -> CF -> CF
bihom (_, _, _, _,
       0, 0, 0, 0) _ _ = CF []
bihom (0, 0, 0, 0,
       _, _, _, _) _ _ = CF [0]
bihom (n0, _n1, n2, _n3,
       d0, _d1, d2, _d3) (CF []) y = hom (n0, n2,
                                          d0, d2) y
bihom (n0, n1, _n2, _n3,
       d0, d1, _d2, _d3) x (CF []) = hom (n0, n1,
                                          d0, d1) x
bihom bh (CF (x:xs)) (CF (y:ys)) = case bihomEmittable bh of
                                    Just d -> CF $ d : rest
                                      where (CF rest) = bihom (bihomEmit bh d) (CF (x:xs)) (CF (y:ys))
                                    Nothing -> if shouldIngestX bh then
                                                 bihom (bihomAbsorbX bh x) (CF xs) (CF (y:ys))
                                               else
                                                 bihom (bihomAbsorbY bh y) (CF (x:xs)) (CF ys)

-- | The square root of 2
sqrt2 :: CF
sqrt2 = CF $ 1 : repeat 2

-- | e
exp1 :: CF
exp1 = CF (2 : concatMap triple [1..])
  where triple n = [1, 2 * n, 1]

instance Eq CF where
  x == y = compare x y == EQ

instance Ord CF where
  -- As [..., n, 1] represents the same number as [..., n+1]
  compare (CF [x]) (CF [y, 1]) = compare x (y+1)
  compare (CF [x, 1]) (CF [y]) = compare (x+1) y
  compare (CF [x]) (CF [y]) = compare x y

  compare (CF (x:_)) (CF [y]) = if x < y then LT else GT
  compare (CF [x]) (CF (y:_)) = if x > y then GT else LT

  compare (CF (x:xs)) (CF (y:ys)) = case compare x y of
                                     EQ -> opposite $ compare (CF xs) (CF ys)
                                     o  -> o
    where opposite LT = GT
          opposite EQ = EQ
          opposite GT = LT

instance Num CF where
  (+) = bihom (0, 1, 1, 0,
               0, 0, 0, 1)
  (*) = bihom (1, 0, 0, 0,
               0, 0, 0, 1)
  (-) = bihom (0, -1, 1, 0,
               0,  0, 0, 1)

  fromInteger i = CF [i]
  abs x = if x > 0 then
             x
          else
            -x
  signum x | x < 0  = -1
           | x == 0 = 0
           | x > 0 = 1


instance Fractional CF where
  (/) = bihom (0, 0, 1, 0,
               0, 1, 0, 0)

  recip (CF [1]) = CF [1]
  recip (CF (0:xs)) = CF xs
  recip (CF xs) = CF (0:xs)

  fromRational r = if rest == 0 then
                CF [d]
              else
                let (CF ds)  = fromRational (recip rest) in CF (d:ds)
    where (d, rest) = properFraction r

instance Real CF where
  toRational _ = undefined

instance RealFrac CF where
  properFraction (CF [i]) = (fromIntegral i, 0)
  properFraction cf | cf < 0 = case properFraction (-cf) of
                                (b, a) -> (-b, -a)
  properFraction (CF (i:r)) = (fromIntegral i, CF r)

rationalDigits :: Rational -> [Integer]
rationalDigits 0 = []
rationalDigits r = let d = num `quot` den in
                   d : rationalDigits (10 * (r - fromInteger d))
  where num = numerator r
        den = denominator r

digits :: CF -> [Integer]
digits = go (1, 0, 0, 1)
  where go (0, 0, _, _) _ = []
        go (p, _, q, _) (CF []) = rationalDigits (p % q)
        go h (CF (c:cs)) = case homEmittable h of
                            Nothing -> let h' = homAbsorb h c in go h' (CF cs)
                            Just d  -> d : go (homEmitDigit h d) (CF (c:cs))
        homEmitDigit (n0, n1,
                      d0, d1) d = (10 * (n0 - d0*d), 10 * (n1 - d1*d),
                                   d0,               d1)

-- | Produce the (possibly infinite) decimal expansion of a continued
-- fraction
showCF :: CF -> String
showCF cf | cf < 0 = "-" ++ show (-cf)
showCF (CF [i])   = show i
showCF (CF (i:r)) = show i ++ "." ++ decimalDigits
  where decimalDigits = concatMap show $ tail $ digits (CF (0:r))

-- Should make this cleverer
instance Show CF where
  show = take 15 . showCF

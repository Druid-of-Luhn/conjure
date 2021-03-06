{-# LANGUAGE DeriveGeneric, DeriveDataTypeable, DeriveFunctor, DeriveTraversable, DeriveFoldable, ViewPatterns #-}
{-# LANGUAGE UndecidableInstances #-}

module Conjure.Language.Expression.Op.Min where

import Conjure.Prelude
import Conjure.Language.Expression.Op.Internal.Common

import qualified Data.Aeson as JSON             -- aeson
import qualified Data.HashMap.Strict as M       -- unordered-containers
import qualified Data.Vector as V               -- vector


data OpMin x = OpMin x
    deriving (Eq, Ord, Show, Data, Functor, Traversable, Foldable, Typeable, Generic)

instance Serialize x => Serialize (OpMin x)
instance Hashable  x => Hashable  (OpMin x)
instance ToJSON    x => ToJSON    (OpMin x) where toJSON = genericToJSON jsonOptions
instance FromJSON  x => FromJSON  (OpMin x) where parseJSON = genericParseJSON jsonOptions

instance ( TypeOf x, Pretty x
         , Domain () x :< x
         ) => TypeOf (OpMin x) where
    typeOf p@(OpMin x) | Just (dom :: Domain () x) <- project x = do
        ty <- typeOf dom
        case ty of
            TypeBool{} -> return ty
            TypeInt{}  -> return ty
            TypeEnum{} -> return ty
            _ -> raiseTypeError p
    typeOf p@(OpMin x) = do
        ty <- typeOf x
        case ty of
            TypeList TypeInt -> return TypeInt
            TypeMatrix _ TypeInt -> return TypeInt
            TypeSet TypeInt -> return TypeInt
            TypeMSet TypeInt -> return TypeInt
            _ -> raiseTypeError p

instance EvaluateOp OpMin where
    evaluateOp p | any isUndef (childrenBi p) = return $ mkUndef TypeInt $ "Has undefined children:" <+> pretty p
    evaluateOp (OpMin (DomainInConstant DomainBool)) = return (ConstantBool False)
    evaluateOp (OpMin (DomainInConstant (DomainInt rs))) = do
        is <- rangesInts rs
        return $ if null is
            then mkUndef TypeInt "Empty collection in min"
            else ConstantInt (minimum is)
    evaluateOp (OpMin (viewConstantMatrix -> Just (_, xs))) = do
        is <- concatMapM (intsOut "OpMin 1") xs
        return $ if null is
            then mkUndef TypeInt "Empty collection in min"
            else ConstantInt (minimum is)
    evaluateOp (OpMin (viewConstantSet -> Just xs)) = do
        is <- concatMapM (intsOut "OpMin 2") xs
        return $ if null is
            then mkUndef TypeInt "Empty collection in min"
            else ConstantInt (minimum is)
    evaluateOp (OpMin (viewConstantMSet -> Just xs)) = do
        is <- concatMapM (intsOut "OpMin 3") xs
        return $ if null is
            then mkUndef TypeInt "Empty collection in min"
            else ConstantInt (minimum is)
    evaluateOp op = na $ "evaluateOp{OpMin}" <+> pretty (show op)

instance SimplifyOp OpMin x where
    simplifyOp _ = na "simplifyOp{OpMin}"

instance Pretty x => Pretty (OpMin x) where
    prettyPrec _ (OpMin x) = "min" <> prParens (pretty x)

instance (VarSymBreakingDescription x, ExpressionLike x) => VarSymBreakingDescription (OpMin x) where
    varSymBreakingDescription (OpMin x) | Just xs <- listOut x = JSON.Object $ M.fromList
        [ ("type", JSON.String "OpMin")
        , ("children", JSON.Array $ V.fromList $ map varSymBreakingDescription xs)
        , ("symmetricChildren", JSON.Bool True)
        ]
    varSymBreakingDescription (OpMin x) = JSON.Object $ M.fromList
        [ ("type", JSON.String "OpMin")
        , ("children", varSymBreakingDescription x)
        ]

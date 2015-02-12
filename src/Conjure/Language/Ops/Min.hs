{-# LANGUAGE DeriveGeneric, DeriveDataTypeable, DeriveFunctor, DeriveTraversable, DeriveFoldable #-}

module Conjure.Language.Ops.Min where

import Conjure.Prelude
import Conjure.Language.Ops.Common


data OpMin x = OpMin x
    deriving (Eq, Ord, Show, Data, Functor, Traversable, Foldable, Typeable, Generic)

instance Serialize x => Serialize (OpMin x)
instance Hashable  x => Hashable  (OpMin x)
instance ToJSON    x => ToJSON    (OpMin x) where toJSON = genericToJSON jsonOptions
instance FromJSON  x => FromJSON  (OpMin x) where parseJSON = genericParseJSON jsonOptions

instance (TypeOf x, Pretty x, ExpressionLike x) => TypeOf (OpMin x) where
    typeOf p@(OpMin x) = do
        ty <- typeOf x
        case ty of
            TypeList TypeInt -> return TypeInt
            TypeMatrix _ TypeInt -> return TypeInt
            TypeSet TypeInt -> return TypeInt
            TypeMSet TypeInt -> return TypeInt
            _ -> raiseTypeError p

instance EvaluateOp OpMin where
    evaluateOp p | any isUndef (universeBi p) = return $ mkUndef $ "Contains undefined things in it:" <+> pretty p
    evaluateOp (OpMin (ConstantAbstract (AbsLitMatrix _ xs))) = do
        is <- concatMapM intsOut xs
        return $ if null is
            then mkUndef "Empty collection in min"
            else ConstantInt (minimum is)
    evaluateOp (OpMin (ConstantAbstract (AbsLitSet      xs))) = do
        is <- concatMapM intsOut xs
        return $ if null is
            then mkUndef "Empty collection in min"
            else ConstantInt (minimum is)
    evaluateOp (OpMin (ConstantAbstract (AbsLitMSet     xs))) = do
        is <- concatMapM intsOut xs
        return $ if null is
            then mkUndef "Empty collection in min"
            else ConstantInt (minimum is)
    evaluateOp _ = na "evaluateOp{OpMin}"

instance SimplifyOp OpMin where
    simplifyOp _ _ = na "simplifyOp{OpMin}"

instance (Pretty x, ExpressionLike x) => Pretty (OpMin x) where
    prettyPrec _ (OpMin x) | Just [a,b] <- listOut x = "min" <> prettyList prParens "," [a,b]
    prettyPrec _ (OpMin x) = "min" <> prParens (pretty x)

{-# LANGUAGE DeriveGeneric, DeriveDataTypeable, DeriveFunctor, DeriveTraversable, DeriveFoldable #-}

module Conjure.Language.Expression.Op.Parts where

import Conjure.Prelude
import Conjure.Language.Expression.Op.Internal.Common

import qualified Data.Aeson as JSON             -- aeson
import qualified Data.HashMap.Strict as M       -- unordered-containers
import qualified Data.Vector as V               -- vector


data OpParts x = OpParts x
    deriving (Eq, Ord, Show, Data, Functor, Traversable, Foldable, Typeable, Generic)

instance Serialize x => Serialize (OpParts x)
instance Hashable  x => Hashable  (OpParts x)
instance ToJSON    x => ToJSON    (OpParts x) where toJSON = genericToJSON jsonOptions
instance FromJSON  x => FromJSON  (OpParts x) where parseJSON = genericParseJSON jsonOptions

instance (TypeOf x, Pretty x) => TypeOf (OpParts x) where
    typeOf p@(OpParts x) = do
        ty <- typeOf x
        case ty of
            TypePartition a -> return (TypeSet (TypeSet a))
            _ -> raiseTypeError $ vcat [ pretty p
                                       , "The argument has type:" <+> pretty ty
                                       ]

instance (Pretty x, DomainOf x x) => DomainOf (OpParts x) x where
    domainOf (OpParts p) = do
        dom <- domainOf p
        case dom of
            DomainPartition _ _ inner -> return $ DomainSet def def $ DomainSet def def inner
            _ -> fail "domainOf, OpParts, not a partition"

instance EvaluateOp OpParts where
    evaluateOp (OpParts (ConstantAbstract (AbsLitPartition xs))) =
        return (ConstantAbstract (AbsLitSet (map (ConstantAbstract . AbsLitSet) xs)))
    evaluateOp op = na $ "evaluateOp{OpParts}:" <++> pretty (show op)

instance SimplifyOp OpParts x where
    simplifyOp _ = na "simplifyOp{OpParts}"

instance Pretty x => Pretty (OpParts x) where
    prettyPrec _ (OpParts a) = "parts" <> prParens (pretty a)

instance VarSymBreakingDescription x => VarSymBreakingDescription (OpParts x) where
    varSymBreakingDescription (OpParts a) = JSON.Object $ M.fromList
        [ ("type", JSON.String "OpParts")
        , ("children", JSON.Array $ V.fromList
            [ varSymBreakingDescription a
            ])
        ]

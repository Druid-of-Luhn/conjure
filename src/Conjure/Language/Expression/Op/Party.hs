{-# LANGUAGE DeriveGeneric, DeriveDataTypeable, DeriveFunctor, DeriveTraversable, DeriveFoldable, ViewPatterns #-}

module Conjure.Language.Expression.Op.Party where

import Conjure.Prelude
import Conjure.Language.Expression.Op.Internal.Common

import qualified Data.Aeson as JSON             -- aeson
import qualified Data.HashMap.Strict as M       -- unordered-containers
import qualified Data.Vector as V               -- vector


data OpParty x = OpParty x x
    deriving (Eq, Ord, Show, Data, Functor, Traversable, Foldable, Typeable, Generic)

instance Serialize x => Serialize (OpParty x)
instance Hashable  x => Hashable  (OpParty x)
instance ToJSON    x => ToJSON    (OpParty x) where toJSON = genericToJSON jsonOptions
instance FromJSON  x => FromJSON  (OpParty x) where parseJSON = genericParseJSON jsonOptions

instance (TypeOf x, Pretty x) => TypeOf (OpParty x) where
    typeOf inp@(OpParty x p) = do
        xTy <- typeOf x
        pTy <- typeOf p
        case pTy of
            TypePartition pTyInner | typesUnify [xTy, pTyInner] -> return $ TypeSet $ mostDefined [xTy, pTyInner]
            _ -> raiseTypeError inp

instance EvaluateOp OpParty where
    evaluateOp op@(OpParty x p@(viewConstantPartition -> Just xss)) = do
        TypePartition tyInner <- typeOf p
        let
            outSet = [ xs
                     | xs <- xss
                     , x `elem` xs
                     ]
        case outSet of
            [s] -> return $ ConstantAbstract (AbsLitSet s)
            []  -> return $ TypedConstant (ConstantAbstract (AbsLitSet [])) (TypeSet tyInner)
            _   -> return $ mkUndef (TypeSet tyInner) $ "Element found in multiple parts of the partition:"
                                                                                                <++> pretty op
    evaluateOp op = na $ "evaluateOp{OpParty}:" <++> pretty (show op)

instance SimplifyOp OpParty x where
    simplifyOp _ = na "simplifyOp{OpParty}"

instance Pretty x => Pretty (OpParty x) where
    prettyPrec _ (OpParty a b) = "party" <> prettyList prParens "," [a,b]

instance VarSymBreakingDescription x => VarSymBreakingDescription (OpParty x) where
    varSymBreakingDescription (OpParty a b) = JSON.Object $ M.fromList
        [ ("type", JSON.String "OpParty")
        , ("children", JSON.Array $ V.fromList
            [ varSymBreakingDescription a
            , varSymBreakingDescription b
            ])
        ]

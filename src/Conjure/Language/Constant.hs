{-# LANGUAGE DeriveGeneric, DeriveDataTypeable #-}
{-# LANGUAGE MultiParamTypeClasses, FlexibleInstances #-}

module Conjure.Language.Constant where

-- conjure
import Conjure.Prelude
import Conjure.Bug
import Conjure.Language.Name
import Conjure.Language.DomainDefn
import Conjure.Language.Domain
import Conjure.Language.Type

import Conjure.Language.TypeOf
import Conjure.Language.IntContainer
import Conjure.Language.Pretty

-- aeson
import qualified Data.Aeson as JSON

-- QuickCheck
import Test.QuickCheck ( Arbitrary(..), oneof )



data Constant
    = ConstantBool Bool
    | ConstantInt Int
    | ConstantEnum DomainDefnEnum Name
    | ConstantTuple [Constant]
    | ConstantMatrix (Domain () Constant) [Constant]
    | ConstantSet [Constant]
    | ConstantMSet [Constant]
    | ConstantFunction [(Constant, Constant)]
    | ConstantRelation [[Constant]]
    | ConstantPartition [[Constant]]
    deriving (Eq, Ord, Show, Data, Typeable, Generic)

instance Serialize Constant
instance Hashable  Constant
instance ToJSON    Constant where toJSON = JSON.genericToJSON jsonOptions
instance FromJSON  Constant where parseJSON = JSON.genericParseJSON jsonOptions

instance Arbitrary Constant where
    arbitrary = oneof
        [ ConstantBool <$> arbitrary
        , ConstantInt <$> arbitrary
        ]

instance TypeOf Constant where
    typeOf ConstantBool{}            = return TypeBool
    typeOf ConstantInt{}             = return TypeInt
    typeOf (ConstantEnum defn _    ) = return (TypeEnum defn)
    typeOf (ConstantTuple        xs) = TypeTuple    <$> mapM typeOf xs
    typeOf (ConstantMatrix ind inn ) = TypeMatrix   <$> typeOf ind <*> (homoType <$> mapM typeOf inn)
    typeOf (ConstantSet         xs ) = TypeSet      <$> (homoType <$> mapM typeOf xs)
    typeOf (ConstantMSet        xs ) = TypeMSet     <$> (homoType <$> mapM typeOf xs)
    typeOf (ConstantFunction    xs ) = TypeFunction <$> (homoType <$> mapM (typeOf . fst) xs)
                                                    <*> (homoType <$> mapM (typeOf . fst) xs)
    typeOf (ConstantRelation    xss) = do
        ty <- homoType <$> mapM (typeOf . ConstantTuple) xss
        case ty of
            TypeTuple ts -> return (TypeRelation ts)
            _ -> bug "expecting TypeTuple in typeOf"
    typeOf (ConstantPartition   xss) = TypePartition <$> (homoType <$> mapM typeOf (concat xss))

instance Pretty Constant where
    pretty (ConstantBool False) = "false"
    pretty (ConstantBool True) = "true"
    pretty (ConstantInt x) = pretty x
    pretty (ConstantEnum _ x) = pretty x
    pretty (ConstantTuple xs) = (if length xs < 2 then "tuple" else prEmpty) <+> prettyList prParens "," xs
    pretty (ConstantMatrix index xs) = let f i = prBrackets (i <> ";" <+> pretty index) in prettyList f "," xs
    pretty (ConstantSet       xs ) =                prettyList prBraces "," xs
    pretty (ConstantMSet      xs ) = "mset"      <> prettyList prParens "," xs
    pretty (ConstantFunction  xs ) = "function"  <> prettyListDoc prParens "," [ pretty a <+> "-->" <+> pretty b | (a,b) <- xs ]
    pretty (ConstantRelation  xss) = "relation"  <> prettyListDoc prParens "," [ pretty (ConstantTuple xs)       | xs <- xss   ]
    pretty (ConstantPartition xss) = "partition" <> prettyListDoc prParens "," [ prettyList prBraces "," xs      | xs <- xss   ]

instance IntContainer Constant where
    intOut (ConstantInt x) = x
    intOut c = bug $ "Expecting an integer, but found:" <+> pretty c

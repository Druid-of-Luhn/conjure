{-# LANGUAGE DeriveGeneric, DeriveDataTypeable, DeriveFunctor, DeriveTraversable, DeriveFoldable #-}

module Conjure.Language.AbstractLiteral where

-- conjure
import Conjure.Prelude
import Conjure.Bug
import Conjure.Language.Domain
import Conjure.Language.Type

import Conjure.Language.TypeOf
import Conjure.Language.Pretty

-- aeson
import qualified Data.Aeson as JSON


data AbstractLiteral x
    = AbsLitTuple [x]
    | AbsLitList [x]
    | AbsLitMatrix (Domain () x) [x]
    | AbsLitSet [x]
    | AbsLitMSet [x]
    | AbsLitFunction [(x, x)]
    | AbsLitRelation [[x]]
    | AbsLitPartition [[x]]
    deriving (Eq, Ord, Show, Data, Functor, Traversable, Foldable, Typeable, Generic)

instance Serialize x => Serialize (AbstractLiteral x)
instance Hashable  x => Hashable  (AbstractLiteral x)
instance ToJSON    x => ToJSON    (AbstractLiteral x) where toJSON = JSON.genericToJSON jsonOptions
instance FromJSON  x => FromJSON  (AbstractLiteral x) where parseJSON = JSON.genericParseJSON jsonOptions

instance Pretty a => Pretty (AbstractLiteral a) where
    pretty (AbsLitTuple xs) = (if length xs < 2 then "tuple" else prEmpty) <+> prettyList prParens "," xs
    pretty (AbsLitList  xs) =                                                  prettyList prBrackets "," xs
    pretty (AbsLitMatrix index xs) = let f i = prBrackets (i <> ";" <+> pretty index) in prettyList f "," xs
    pretty (AbsLitSet       xs ) =                prettyList prBraces "," xs
    pretty (AbsLitMSet      xs ) = "mset"      <> prettyList prParens "," xs
    pretty (AbsLitFunction  xs ) = "function"  <> prettyListDoc prParens "," [ pretty a <+> "-->" <+> pretty b | (a,b) <- xs ]
    pretty (AbsLitRelation  xss) = "relation"  <> prettyListDoc prParens "," [ pretty (AbsLitTuple xs)         | xs <- xss   ]
    pretty (AbsLitPartition xss) = "partition" <> prettyListDoc prParens "," [ prettyList prBraces "," xs      | xs <- xss   ]

instance TypeOf a => TypeOf (AbstractLiteral a) where
    typeOf (AbsLitTuple        xs) = TypeTuple    <$> mapM typeOf xs
    typeOf (AbsLitList         xs) = TypeList     <$>                (homoType <$> mapM typeOf xs )
    typeOf (AbsLitMatrix ind inn ) = TypeMatrix   <$> typeOf ind <*> (homoType <$> mapM typeOf inn)
    typeOf (AbsLitSet         xs ) = TypeSet      <$> (homoType <$> mapM typeOf xs)
    typeOf (AbsLitMSet        xs ) = TypeMSet     <$> (homoType <$> mapM typeOf xs)
    typeOf (AbsLitFunction    xs ) = TypeFunction <$> (homoType <$> mapM (typeOf . fst) xs)
                                                  <*> (homoType <$> mapM (typeOf . fst) xs)
    typeOf (AbsLitRelation    xss) = do
        ty <- homoType <$> mapM (typeOf . AbsLitTuple) xss
        case ty of
            TypeTuple ts -> return (TypeRelation ts)
            _ -> bug "expecting TypeTuple in typeOf"
    typeOf (AbsLitPartition   xss) = TypePartition <$> (homoType <$> mapM typeOf (concat xss))

normaliseAbsLit :: Ord c => (c -> c) -> AbstractLiteral c -> AbstractLiteral c
normaliseAbsLit norm (AbsLitTuple     xs ) = AbsLitTuple     $ map norm xs
normaliseAbsLit norm (AbsLitList      xs ) = AbsLitList      $ map norm xs
normaliseAbsLit norm (AbsLitMatrix d  xs ) = AbsLitMatrix d  $ map norm xs
normaliseAbsLit norm (AbsLitSet       xs ) = AbsLitSet       $ sortNub $ map norm xs
normaliseAbsLit norm (AbsLitMSet      xs ) = AbsLitMSet      $ sort $ map norm xs
normaliseAbsLit norm (AbsLitFunction  xs ) = AbsLitFunction  $ sortNub [ (norm x, norm y) | (x, y) <- xs ]
normaliseAbsLit norm (AbsLitRelation  xss) = AbsLitRelation  $ sortNub $ map (map norm) xss
normaliseAbsLit norm (AbsLitPartition xss) = AbsLitPartition $ sortNub $ map (sortNub . map norm) xss
{-# LANGUAGE QuasiQuotes #-}

module Conjure.Representations.Relation.RelationAsMatrix ( relationAsMatrix ) where

-- conjure
import Conjure.Prelude
import Conjure.Bug
import Conjure.Language.Definition
import Conjure.Language.Domain
import Conjure.Language.Type
import Conjure.Language.TH
import Conjure.Language.Pretty
import Conjure.Representations.Internal
import Conjure.Representations.Common
import Conjure.Representations.Function.Function1D ( domainCanIndexMatrix, domainValues, toIntDomain )


relationAsMatrix :: MonadFail m => Representation m
relationAsMatrix = Representation chck downD structuralCons downC up

    where

        chck f (DomainRelation _ attrs innerDomains) | all domainCanIndexMatrix innerDomains =
            DomainRelation "RelationAsMatrix" attrs <$> mapM f innerDomains
        chck _ _ = []

        outName name = mconcat [name, "_", "RelationAsMatrix"]

        downD (name, DomainRelation "RelationAsMatrix" _ innerDomains') | all domainCanIndexMatrix innerDomains' = do
            innerDomains <- mapM toIntDomain innerDomains'
            let unroll []     j = j
                unroll (i:is) j = DomainMatrix i (unroll is j)
            return $ Just
                [ ( outName name
                  , unroll (map forgetRepr innerDomains) DomainBool
                  ) ]
        downD _ = fail "N/A {downD}"

        structuralCons _ _
            (DomainRelation "RelationAsMatrix" (RelationAttr sizeAttr) innerDomains')
                | all domainCanIndexMatrix innerDomains' = do
            innerDomains <- mapM toIntDomain innerDomains'
            let cardinality fresh m =
                    let unroll _ [] = bug "RelationAsMatrix.cardinality.unroll []"
                        unroll n [((iPat, i), dom)] =
                                [essence| sum &iPat : &dom . &n[&i] |]
                        unroll n (((iPat, i), dom) : rest) =
                            let r = unroll [essence| &n[&i] |] rest
                            in  [essence| sum &iPat : &dom . &r |]
                    in  unroll m (zip [ quantifiedVar f TypeInt | f <- fresh ] innerDomains)
            return $ \ fresh refs ->
                case refs of
                    [m] -> return (mkSizeCons sizeAttr (cardinality fresh m))
                    _ -> fail "N/A {structuralCons} RelationAsMatrix"
        structuralCons _ _ _ = fail "N/A {structuralCons} RelationAsMatrix"

        downC ( name
              , DomainRelation "RelationAsMatrix" _ innerDomains'
              , ConstantRelation vals
              ) | all domainCanIndexMatrix innerDomains' = do
            innerDomains <- fmap (fmap e2c) <$> mapM toIntDomain (fmap (fmap Constant) innerDomains')
            let
                check :: [Constant] -> Bool
                check indices = indices `elem` vals

            let
                unrollD :: [Domain () Constant] -> Domain r Constant -> Domain r Constant
                unrollD []     j = j
                unrollD (i:is) j = DomainMatrix i (unrollD is j)

            let
                unrollC :: MonadFail m
                        => [ ( Domain () Constant       -- the int domain
                             , Domain () Constant       -- the actial domain
                             ) ]
                        -> [Constant]               -- indices
                        -> m Constant
                unrollC [(i,i')] prevIndices = do
                    domVals <- domainValues i'
                    return (ConstantMatrix i [ ConstantBool $ check $ prevIndices ++ [val]
                                             | val <- domVals ])
                unrollC ((i,i'):is) prevIndices = do
                    domVals <- domainValues i'
                    matrixVals <- forM domVals $ \ val ->
                        unrollC is (prevIndices ++ [val])
                    return (ConstantMatrix i matrixVals)
                unrollC is prevIndices = fail $ vcat [ "RelationAsMatrix.up.unrollC"
                                                     , "    is         :" <+> vcat (map pretty is)
                                                     , "    prevIndices:" <+> pretty (show prevIndices)
                                                     ]

            outConstant <- unrollC (zip (map forgetRepr innerDomains)
                                        (map forgetRepr innerDomains')) []

            return $ Just
                [ ( outName name
                  , unrollD (map forgetRepr innerDomains) DomainBool
                  , outConstant
                  ) ]

        downC _ = fail "N/A {downC}"

        up ctxt (name, domain@(DomainRelation "RelationAsMatrix" _ innerDomains')) = do

            innerDomains <- fmap (fmap e2c) <$> mapM toIntDomain (fmap (fmap Constant) innerDomains')
            
            case lookup (outName name) ctxt of
                Nothing -> fail $ vcat $
                    [ "No value for:" <+> pretty (outName name)
                    , "When working on:" <+> pretty name
                    , "With domain:" <+> pretty domain
                    ] ++
                    ("Bindings in context:" : prettyContext ctxt)
                Just constant -> do
                    let
                        allIndices :: (MonadFail m, Pretty r) => [Domain r Constant] -> m [[Constant]]
                        allIndices = fmap sequence . mapM domainValues

                        index :: MonadFail m => Constant -> [Constant] -> m Constant
                        index m [] = return m
                        index (ConstantMatrix indexDomain vals) (i:is) = do
                            froms <- domainValues indexDomain
                            case lookup i (zip froms vals) of
                                Nothing -> fail "Value not found. RelationAsMatrix.up.index"
                                Just v  -> index v is
                        index m is = bug ("RelationAsMatrix.up.index" <+> pretty m <+> pretty (show is))

                    indices' <- allIndices innerDomains'
                    indices  <- allIndices innerDomains
                    vals     <- forM (zip indices indices') $ \ (these, these') -> do
                        indexed <- index constant these
                        case indexed of
                            ConstantBool False -> return Nothing
                            ConstantBool True  -> return (Just these')
                            _ -> fail $ vcat
                                [ "Expecting a boolean literal, but got:" <+> pretty indexed
                                , "When working on:" <+> pretty name
                                , "With domain:" <+> pretty domain
                                ]

                    return ( name
                           , ConstantRelation (catMaybes vals)
                           )
        up _ _ = fail "N/A {up}"

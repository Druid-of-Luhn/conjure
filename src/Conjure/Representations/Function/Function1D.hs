{-# LANGUAGE QuasiQuotes #-}

module Conjure.Representations.Function.Function1D
    ( function1D
    , domainCanIndexMatrix, domainValues, toIntDomain
    ) where

-- conjure
import Conjure.Prelude
import Conjure.Language.Definition
import Conjure.Language.Domain
import Conjure.Language.DomainSize
import Conjure.Language.TH
import Conjure.Language.TypeOf
import Conjure.Language.Pretty
import Conjure.Representations.Internal
import Conjure.Representations.Common


function1D :: MonadFail m => Representation m
function1D = Representation chck downD structuralCons downC up

    where

        chck f (DomainFunction _
                    attrs@(FunctionAttr _ FunctionAttr_Total _)
                    innerDomainFr
                    innerDomainTo) | domainCanIndexMatrix innerDomainFr =
            DomainFunction "Function1D" attrs
                <$> f innerDomainFr
                <*> f innerDomainTo
        chck _ _ = []

        outName name = mconcat [name, "_", "Function1D"]

        downD (name, DomainFunction "Function1D"
                    (FunctionAttr _ FunctionAttr_Total _)
                    innerDomainFr'
                    innerDomainTo) | domainCanIndexMatrix innerDomainFr' = do
            innerDomainFr <- toIntDomain innerDomainFr'
            return $ Just
                [ ( outName name
                  , DomainMatrix
                      (forgetRepr innerDomainFr)
                      innerDomainTo
                  ) ]
        downD _ = fail "N/A {downD}"

        -- FIX
        structuralCons _ _
            (DomainFunction "Function1D"
                (FunctionAttr sizeAttr FunctionAttr_Total jectivityAttr)
                innerDomainFr'
                innerDomainTo) | domainCanIndexMatrix innerDomainFr' = do
            innerDomainFr   <- toIntDomain innerDomainFr'
            innerDomainFrTy <- typeOf innerDomainFr
            innerDomainToTy <- typeOf innerDomainTo

            let injectiveCons m = return $ [essence| allDiff(&m) |]

            let surjectiveCons fresh m = return $ -- list
                    let
                        (iPat, i) = quantifiedVar (fresh `at` 0) innerDomainToTy
                        (jPat, j) = quantifiedVar (fresh `at` 1) innerDomainFrTy
                    in
                        [essence|
                            forAll &iPat : &innerDomainTo .
                                exists &jPat : &innerDomainFr .
                                    &m[&j] = &i
                        |]
            let jectivityCons fresh m = case jectivityAttr of
                    ISBAttr_None       -> []
                    ISBAttr_Injective  -> injectiveCons        m
                    ISBAttr_Surjective -> surjectiveCons fresh m
                    ISBAttr_Bijective  -> injectiveCons        m
                                       ++ surjectiveCons fresh m

            cardinality <- domainSizeOf innerDomainFr

            return $ \ fresh refs ->
                case refs of
                    [m] -> return (jectivityCons fresh m ++ mkSizeCons sizeAttr cardinality)
                    _ -> fail "N/A {structuralCons} Function1D"

        structuralCons _ _ _ = fail "N/A {structuralCons} Function1D"

        downC ( name
              , DomainFunction "Function1D"
                    (FunctionAttr _ FunctionAttr_Total _)
                    innerDomainFr
                    innerDomainTo
              , ConstantFunction vals
              ) | domainCanIndexMatrix innerDomainFr = do
            innerDomainFrInt <- fmap e2c <$> toIntDomain (fmap Constant innerDomainFr)
            froms            <- domainValues innerDomainFr
            valsOut          <- sequence
                [ val
                | fr <- froms
                , let val = case lookup fr vals of
                                Nothing -> fail $ vcat [ "No value for " <+> pretty fr
                                                       , "In:" <+> pretty (ConstantFunction vals)
                                                       ]
                                Just v  -> return v
                ]
            return $ Just
                [ ( outName name
                  , DomainMatrix
                      (forgetRepr innerDomainFrInt)
                      innerDomainTo
                  , ConstantMatrix (forgetRepr innerDomainFrInt) valsOut
                  ) ]
        downC _ = fail "N/A {downC}"

        up ctxt (name, domain@(DomainFunction "Function1D"
                                (FunctionAttr _ FunctionAttr_Total _)
                                innerDomainFr _)) =
            case lookup (outName name) ctxt of
                Nothing -> fail $ vcat $
                    [ "No value for:" <+> pretty (outName name)
                    , "When working on:" <+> pretty name
                    , "With domain:" <+> pretty domain
                    ] ++
                    ("Bindings in context:" : prettyContext ctxt)
                Just constant ->
                    case constant of
                        ConstantMatrix _ vals -> do
                            froms <- domainValues innerDomainFr
                            return ( name
                                   , ConstantFunction (zip froms vals)
                                   )
                        _ -> fail $ vcat
                                [ "Expecting a matrix literal for:" <+> pretty (outName name)
                                , "But got:" <+> pretty constant
                                , "When working on:" <+> pretty name
                                , "With domain:" <+> pretty domain
                                ]
        up _ _ = fail "N/A {up}"


domainCanIndexMatrix :: Domain r x -> Bool
domainCanIndexMatrix DomainBool{} = True
domainCanIndexMatrix DomainInt {} = True
domainCanIndexMatrix DomainEnum{} = True
domainCanIndexMatrix _            = False


domainValues :: (MonadFail m, Pretty r) => Domain r Constant -> m [Constant]
domainValues dom =
    case dom of
        DomainBool -> return [ConstantBool False, ConstantBool True]
        DomainInt rs -> map ConstantInt <$> valuesInIntDomain rs
        _ -> fail ("domainValues, not supported:" <+> pretty dom)


toIntDomain :: MonadFail m => Domain HasRepresentation Expression -> m (Domain HasRepresentation Expression)
toIntDomain dom =
    case dom of
        DomainBool -> return (DomainInt [RangeBounded (fromInt 0) (fromInt 1)])
        DomainInt{} -> return dom
        _ -> fail ("toIntDomain, not supported:" <+> pretty dom)

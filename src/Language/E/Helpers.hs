{-# LANGUAGE QuasiQuotes, ViewPatterns, OverloadedStrings #-}
{-# LANGUAGE FlexibleContexts #-}

module Language.E.Helpers where

import Language.E.Imports
import Language.E.Definition
import Language.E.CompE
import Language.E.TH

import qualified Data.Text as T



identifierSplit :: Text -> (Text, Maybe Text, Maybe Text)
identifierSplit t =
    case T.splitOn "§" t of
        [base, rest] -> case T.splitOn "#" rest of
            [region, repr] -> (base, Just region, Just repr)
            _              -> (base, Just rest  , Nothing  )
        _            -> case T.splitOn "#" t of
            [base  , repr] -> (base, Nothing    , Just repr)
            _              -> (t   , Nothing    , Nothing  )

identifierConstruct :: Text -> Maybe Text -> Maybe Text -> Text
identifierConstruct base mregion mrepr =
    mconcat [ base
            , maybe mempty ("§" `mappend`) mregion
            , maybe mempty ("#" `mappend`) mrepr
            ]


conjunct :: [E] -> E
conjunct []     = [eMake| true |]
conjunct [x]    = x
conjunct (x:xs) = let y = conjunct xs in [eMake| &x /\ &y |]


disjunct :: [E] -> E
disjunct []     = [eMake| false |]
disjunct [x]    = x
disjunct (x:xs) = let y = disjunct xs in [eMake| &x \/ &y |]


traceBindings :: MonadConjure m => String -> m ()
traceBindings msg = do
    bs <- gets binders
    trace (msg ++ " " ++ show [ nm | Binder nm _ <- bs ]) (return ())


freshQuanVar :: MonadConjure m => m (Text, E)
freshQuanVar = do
    quanVarStr <- nextUniqueName
    let quanVar = [xMake| structural.single.reference := [Prim $ S quanVarStr] |]
    return (quanVarStr, quanVar)

inForAll :: Text -> E -> E -> E
inForAll quanVar quanOverDom body =
    [xMake| quantified.quantifier.reference                := [Prim $ S "forAll"]
          | quantified.quanVar.structural.single.reference := [Prim $ S quanVar ]
          | quantified.quanOverDom                         := [quanOverDom]
          | quantified.quanOverOp                          := []
          | quantified.quanOverExpr                        := []
          | quantified.guard.emptyGuard                    := []
          | quantified.body                                := [body]
          |]

inForAlls :: [(Text,E)] -> E -> E
inForAlls = go . reverse
    where
        go []         body = body
        go ((i,j):ks) body = go ks $ inForAll i j body


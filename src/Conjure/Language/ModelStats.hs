module Conjure.Language.ModelStats
    ( givens, nbGivens, nbAbstractGivens
    , finds, nbFinds, nbAbstractFinds
    , domainNeedsRepresentation
    , modelInfo
    ) where

import Conjure.Prelude
import Conjure.Bug
import Conjure.Language.Definition
import Conjure.Language.Pretty


givens :: Model -> [(Name, Domain () Expression)]
givens m = [ (nm,d) | Declaration (Given nm d) <- mStatements m ]

nbGivens :: Model -> Int
nbGivens = length . givens

nbAbstractGivens :: Model -> Int
nbAbstractGivens = length . filter domainNeedsRepresentation . map snd . givens

finds :: Model -> [(Name, Domain () Expression)]
finds m = [ (nm,d) | Declaration (Find nm d) <- mStatements m ]

nbFinds :: Model -> Int
nbFinds = length . finds

nbAbstractFinds :: Model -> Int
nbAbstractFinds = length . filter domainNeedsRepresentation . map snd . finds

domainNeedsRepresentation :: (Pretty r, Pretty x) => Domain r x -> Bool
domainNeedsRepresentation DomainBool{} = False
domainNeedsRepresentation DomainInt{} = False
domainNeedsRepresentation DomainEnum{} = False
domainNeedsRepresentation DomainUnnamed{} = False
domainNeedsRepresentation DomainTuple{} = False
domainNeedsRepresentation (DomainMatrix _ inner) = domainNeedsRepresentation inner
domainNeedsRepresentation DomainSet{}       = True
domainNeedsRepresentation DomainMSet{}      = True
domainNeedsRepresentation DomainFunction{}  = True
domainNeedsRepresentation DomainRelation{}  = True
domainNeedsRepresentation DomainPartition{} = True
domainNeedsRepresentation d = bug $ "domainNeedsRepresentation:" <+> pretty d

modelInfo :: Model -> Doc
modelInfo m = vcat
    [ "Contains" <+> pretty (nbGivens m) <+> "parameters        "
                 <+> parens (pretty (nbAbstractGivens m) <+> "abstract")
    , "        " <+> pretty (nbFinds  m) <+> "decision variables"
                 <+> parens (pretty (nbAbstractFinds m ) <+> "abstract")
    ]

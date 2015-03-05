{-# LANGUAGE FunctionalDependencies #-}

module Conjure.Language.DomainOf where

-- conjure
import Conjure.Prelude
import Conjure.Language.Domain


class DomainOf a x | a -> x where
    domainOf ::
        ( MonadFail m
        , Monoid (Domain () x)              -- ability to "combine" domains
        ) => a -> m (Domain () x)

{-# LANGUAGE TupleSections #-}

module Conjure.Language.NameResolution
    ( resolveNames
    , resolveNamesX
    ) where

import Conjure.Prelude
import Conjure.Bug
import Conjure.Language.Definition
import Conjure.Language.Domain
import Conjure.Language.TypeOf
import Conjure.Language.Pretty


resolveNames :: (MonadLog m, MonadFail m, NameGen m) => Model -> m Model
resolveNames model = flip evalStateT [] $ do
    statements <- mapM resolveStatement (mStatements model)
    mapM_ check (universeBi statements)
    duplicateNames <- gets (id                                   -- all names defined in the model
                            >>> filter (\ (_,d) -> case d of
                                    RecordField{}  -> False      -- filter out the RecordField's
                                    VariantField{} -> False      --        and the VariantField's
                                    _              -> True )
                            >>> map fst                          -- strip the ReferenceTo's
                            >>> histogram
                            >>> filter (\ (_,n) -> n > 1 )       -- keep those that are defined multiple times
                            >>> map fst)
    unless (null duplicateNames) $
        userErr ("Some names are defined multiple times:" <+> prettyList id "," duplicateNames)
    return model { mStatements = statements }

shadowing
    :: ( MonadFail m
       , MonadState [(Name, ReferenceTo)] m
       , NameGen m
       )
    => Expression
    -> m Expression
shadowing p@(Comprehension _ is) = do
    let generators = concat
            [ names
            | Generator gen <- is
            , let pat = generatorPat gen
            , let names = [ n | n@Name{} <- universeBi pat ]
            ]
    ctxt <- gets id
    let shadows = [ g | g <- generators, g `elem` map fst ctxt ]
    shadowsNew <- forM shadows $ \ s -> do n <- nextName "shadow" ; return (s,n)
    let f n = fromMaybe n (lookup n shadowsNew)
    return (transformBi f p)
shadowing p = return p


resolveNamesX :: (MonadFail m, NameGen m) => Expression -> m Expression
resolveNamesX x = do
    x' <- evalStateT (resolveX x) []
    mapM_ check (universe x')
    return x'


check :: MonadFail m => Expression -> m ()
check (Reference nm Nothing) = fail ("Undefined:" <+> pretty nm)
check _ = return ()


resolveStatement
    :: ( MonadFail m
       , MonadState [(Name, ReferenceTo)] m
       , NameGen m
       )
    => Statement
    -> m Statement

resolveStatement st =
    case st of
        Declaration decl ->
            case decl of
                FindOrGiven forg nm dom       -> do
                    dom' <- resolveD dom
                    modify ((nm, DeclNoRepr forg nm dom') :)
                    return (Declaration (FindOrGiven forg nm dom'))
                Letting nm x                  -> do
                    x' <- resolveX x
                    modify ((nm, Alias x') :)
                    return (Declaration (Letting nm x'))
                _ -> fail ("Unexpected declaration:" <+> pretty st)
        SearchOrder xs -> SearchOrder <$> mapM resolveSearchOrder xs
        Where xs -> Where <$> mapM resolveX xs
        Objective obj x -> Objective obj <$> resolveX x
        SuchThat xs -> SuchThat <$> mapM resolveX xs


resolveSearchOrder
    :: ( MonadFail m
       , MonadState [(Name, ReferenceTo)] m
       , NameGen m
       )
    => SearchOrder
    -> m SearchOrder
resolveSearchOrder (BranchingOn nm) = do
    ctxt <- gets id
    mval <- gets (lookup nm)
    case mval of
        Nothing -> fail $ vcat $ ("Undefined reference:" <+> pretty nm)
                               : ("Bindings in context:" : prettyContext ctxt)
        Just{}  -> return (BranchingOn nm)
resolveSearchOrder (Cut x) =
    let f Find = CutFind
        f forg = forg
    in  Cut . transformBi f <$> resolveX x


resolveX
    :: ( MonadFail m
       , MonadState [(Name, ReferenceTo)] m
       , NameGen m
       )
    => Expression
    -> m Expression

resolveX (Reference nm Nothing) = do
    ctxt <- gets id
    mval <- gets (lookup nm)
    case mval of
        Nothing -> fail $ vcat $ ("Undefined reference:" <+> pretty nm)
                               : ("Bindings in context:" : prettyContext ctxt)
        Just r  -> return (Reference nm (Just r))

resolveX p@(Reference nm (Just refto)) = do             -- this is for re-resolving
    mval <- gets (lookup nm)
    case mval of
        Nothing -> return p                             -- hence, do not fail if not in the context
        Just DeclNoRepr{}                               -- if the newly found guy doesn't have a repr
            | DeclHasRepr{} <- refto                    -- but the old one did, do not update
            -> return p
        Just r  -> return (Reference nm (Just r))

resolveX (AbstractLiteral lit) = AbstractLiteral <$> resolveAbsLit lit

resolveX (Domain x) = Domain <$> resolveD x

resolveX p@Comprehension{} = scope $ do
    p' <- shadowing p
    case p' of
        Comprehension x is -> do
            is' <- forM is $ \ i -> case i of
                Generator gen -> do
                    (gen', refto) <- case gen of
                        GenDomainNoRepr pat dom -> do
                            dom' <- resolveD dom
                            let gen'' = GenDomainNoRepr pat dom'
                            return
                                ( gen''
                                , case pat of
                                    Single nm' -> DeclNoRepr Quantified nm' dom'
                                    _ -> InComprehension gen''
                                )
                        GenDomainHasRepr nm dom ->
                            return
                                ( GenDomainHasRepr nm dom
                                , DeclHasRepr Quantified nm dom
                                )
                        GenInExpr pat expr -> do
                            expr' <- resolveX expr
                            let gen'' = GenInExpr pat expr'
                            return ( gen'' , InComprehension gen'' )
                    forM_ (universeBi (generatorPat gen)) $ \ nm ->
                        modify ((nm, refto) :)
                    return (Generator gen')
                Condition y -> Condition <$> resolveX y
            x' <- resolveX x
            return (Comprehension x' is')
        _ -> bug "NameResolution.resolveX.shadowing"

resolveX (WithLocals body (Left  locals)) = scope $ do
    locals' <- mapM resolveStatement locals
    body'   <- resolveX body
    return (WithLocals body' (Left  locals'))

resolveX (WithLocals body (Right locals)) = scope $ do
    locals' <- mapM resolveX locals
    body'   <- resolveX body
    return (WithLocals body' (Right locals'))

resolveX x = descendM resolveX x


resolveD
    :: ( MonadFail m
       , MonadState [(Name, ReferenceTo)] m
       , NameGen m
       )
    => Domain () Expression
    -> m (Domain () Expression)
resolveD (DomainReference _ (Just d)) = resolveD d
resolveD (DomainReference nm Nothing) = do
    mval <- gets (lookup nm)
    case mval of
        Nothing -> userErr ("Undefined reference to a domain:" <+> pretty nm)
        Just (Alias (Domain r)) -> resolveD r
        Just x -> userErr ("Expected a domain, but got an expression:" <+> pretty x)
resolveD (DomainRecord ds) = fmap DomainRecord $ forM ds $ \ (n, d) -> do
    d' <- resolveD d
    t  <- typeOf d'
    modify ((n, RecordField n t) :)
    return (n, d')
resolveD (DomainVariant ds) = fmap DomainVariant $ forM ds $ \ (n, d) -> do
    d' <- resolveD d
    t  <- typeOf d'
    modify ((n, VariantField n t) :)
    return (n, d')
resolveD d = do
    d' <- descendM resolveD d
    mapM resolveX d'


resolveAbsLit
    :: ( MonadFail m
       , MonadState [(Name, ReferenceTo)] m
       , NameGen m
       )
    => AbstractLiteral Expression
    -> m (AbstractLiteral Expression)
resolveAbsLit p@(AbsLitVariant Nothing n x) = do
    x'   <- resolveX x
    mval <- gets id
    let
        isTheVariant (Alias (Domain d@(DomainVariant nms))) | Just{} <- lookup n nms = Just d
        isTheVariant _ = Nothing
    case mapMaybe isTheVariant (map snd mval) of
        (DomainVariant dom:_) -> return (AbsLitVariant (Just dom) n x')
        _ -> userErr ("Not a member of a variant type:" <+> pretty p)
resolveAbsLit lit = descendBiM resolveX lit

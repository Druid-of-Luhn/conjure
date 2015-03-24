{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE BangPatterns #-}

module Conjure.Process.DealWithCuts ( dealWithCuts ) where

import Conjure.Prelude
import Conjure.Language.Definition
import Conjure.Language.Domain
import Conjure.Language.TH


data St = St { varCounter :: Int, seenSearchOrder :: Bool, finds :: [Name] }

dealWithCuts
    :: (MonadFail m, MonadLog m)
    => Model
    -> m Model
dealWithCuts m = flip evalStateT (St 1 False []) $ do
    statements <- forM (mStatements m) $ \ statement ->
        case statement of
            SearchOrder orders0 -> do
                seen <- gets seenSearchOrder
                when seen $ fail "At most one 'branching on' statement is allowed."
                modify $ \ st -> st { seenSearchOrder = True }
                (orders1, (newVars, newCons)) <- runWriterT $ forM orders0 $ \ order ->
                    case order of
                        Cut x -> do
                            varName <- nextName
                            let varDecl = Declaration (FindOrGiven Find varName DomainBool)
                            let varRef  = Reference varName (Just (DeclNoRepr Find varName DomainBool))
                            tell ( [ varDecl ]
                                 , [ [essence| !&varRef <-> &x |] ]
                                 )
                            return $ BranchingOn varName
                        _ -> return order
                orders2 <-
                        if null [ () | BranchingOn{} <- orders0 ]     -- no variables were given, all assumed non-aux
                            then map BranchingOn <$> gets finds
                            else return []
                return $ concat
                    [ newVars
                    , [SearchOrder (orders1++orders2)]
                    , [SuchThat newCons]
                    ]
            Declaration (FindOrGiven Find nm _) -> do
                seen <- gets seenSearchOrder
                when seen $ fail "A 'find' statement cannot occur after the 'branching on' statement."
                modify $ \ st -> st { finds = finds st ++ [nm] }
                return [statement]
            _ -> return [statement]
    return m { mStatements = concat statements }

nextName :: MonadState St m => m Name
nextName = do
    !i <- gets varCounter
    modify $ \ st -> st { varCounter = succ (varCounter st) }
    return (MachineName "cut" i [])

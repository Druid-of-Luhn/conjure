{-# LANGUAGE RecordWildCards #-}

module Conjure.Custom ( tests ) where

-- conjure
import Conjure.Prelude
import Conjure.Language.Pretty ( pretty, (<++>), renderNormal )
import Conjure.ModelAllSolveAll ( TestTimeLimit(..) )

-- tasty
import Test.Tasty ( TestTree, testGroup )
import Test.Tasty.HUnit ( testCaseSteps, assertFailure )

-- text
import Data.Text.IO as T ( readFile, writeFile )

-- shelly
import Shelly ( cd, bash, errExit, lastStderr )

-- system-filepath
import Filesystem.Path.CurrentOS as Path ( fromText )


tests :: IO (TestTimeLimit -> TestTree)
tests = do
    let baseDir = "tests/custom"
    dirs <- mapM (isTestDir baseDir) =<< getAllDirs baseDir
    let testCases tl = concatMap (testSingleDir tl) (catMaybes dirs)
    return $ \ tl -> testGroup "custom" (testCases tl)


data TestDirFiles = TestDirFiles
    { name           :: String          -- a name for the test case
    , tBaseDir       :: FilePath        -- dir
    , expectedTime   :: Int
    }
    deriving Show


-- returns True if the argument points to a directory that is not hidden
isTestDir :: FilePath -> FilePath -> IO (Maybe TestDirFiles)
isTestDir baseDir dir = do
    dirContents <- getDirectoryContents dir
    let runSh = filter ("run.sh" ==) dirContents
    case runSh of
        [_] -> do
            expectedTime <-
                if "expected-time.txt" `elem` dirContents
                    then fromMaybe 0 . readMay . textToString <$> T.readFile (dir ++ "/expected-time.txt")
                    else return 0
            return $ Just TestDirFiles
                        { name           = drop (length baseDir + 1) dir
                        , tBaseDir       = dir
                        , expectedTime   = expectedTime
                        }
        _ -> return Nothing


testSingleDir :: TestTimeLimit -> TestDirFiles -> [TestTree]
testSingleDir (TestTimeLimit timeLimit) TestDirFiles{..} =
    let
        shouldRun = or [ timeLimit == 0
                       , expectedTime <= timeLimit
                       ]
    in
        if shouldRun
            then return $ testCaseSteps name $ \ step -> do
                step "Running"
                (stdout, stderr) <- sh $ errExit False $ do
                    -- stdout <- run (tBaseDir </> "run.sh") []
                    cd (Path.fromText $ stringToText $ tBaseDir)
                    stdout <- bash "./run.sh" []
                    stderr <- lastStderr
                    return (stdout, stderr)
                T.writeFile (tBaseDir </> "stdout") stdout
                T.writeFile (tBaseDir </> "stderr") stderr

                let
                    readIfExists :: FilePath -> IO String
                    readIfExists f = fromMaybe "" <$> readFileIfExists f

                step "Checking stdout"
                stdoutG <- readIfExists (tBaseDir </> "stdout")
                stdoutE <- readIfExists (tBaseDir </> "stdout.expected")
                unless (stdoutE == stdoutG) $
                    assertFailure $ renderNormal $ vcat [ "unexpected stdout:" <++> pretty stdoutG
                                                        , "was expecting:    " <++> pretty stdoutE ]
                step "Checking stderr"
                stderrG <- readIfExists (tBaseDir </> "stderr")
                stderrE <- readIfExists (tBaseDir </> "stderr.expected")
                unless (stderrE == stderrG) $
                    assertFailure $ renderNormal $ vcat [ "unexpected stderr:" <++> pretty stderrG
                                                        , "was expecting:    " <++> pretty stderrE ]
            else []


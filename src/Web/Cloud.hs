module Web.Cloud where

import Data.List
import Data.IORef
import Data.ByteString.Lazy.Char8 (pack, unpack)
import System.Environment
import Options.Applicative
import Options.Applicative.Types
import Options.Applicative.Help.Chunk
import Network.CGI
import Network.CGI.Monad
import Network.CGI.Protocol
import System.Exit

execParserWebCloud :: ParserInfo a -> IO a
execParserWebCloud pinfo = do
  ref <- newIORef Nothing
  title <- (\x -> "<title>" ++ x ++ "</title>") `fmap` getProgName
  runCGI . handleErrors $ do
    setHeader "Content-Type" "text/html; charset=utf-8" 
    clouds <- cgiGet (execParserPure (prefs idm) pinfo . getCloud . cgiInputs)
    val <- mkWebCloud clouds
    case val of
      Left e -> do
        output $ title
                 ++ "<code><pre>"
                 ++ e
                 ++ "</code></pre>"
                 ++ "<form action=\"\" method=\"get\">" ++ form (infoParser pinfo) ++ "<input type=submit></form>"
      Right v -> do
        liftIO $ writeIORef ref (Just v)
        output $ title ++ "<code><pre>"
  r <- readIORef ref
  case r of
    Just v -> return v
    Nothing -> exitWith ExitSuccess -- it's ok to error! :)

-- getCloud :: [(String, Input)]
getCloud =
  flip (>>=) $ \(k, v) ->
    if unpack (inputValue v) == ""
      then []
      else if unpack (inputValue v) == "on"
        then ["--" ++ k]
        else ["--" ++ k, show (inputValue v)]

mkWebCloud :: Monad m => ParserResult a -> m (Either String a)
mkWebCloud (Success a) = return (Right a)
mkWebCloud (Failure failure) = return (Left (fst (renderFailure failure "cloud")))
mkWebCloud (CompletionInvoked _) = return (Left "not web")

form :: Parser a -> String
form (NilP _) = ""
form (OptP opt) = formatOpt (optProps opt) (optMain opt)
form (MultP pf pa) = form pf ++ form pa
form (AltP pa pb) = form pa ++ form pb
form (BindP px pf) = form px -- TODO: bind... ++ form pf

formatOpt (OptProperties vis halp metavar def) (OptReader names _ _) =
  fmt metavar halp names (getName names == "help")
formatOpt (OptProperties vis halp metavar def) (FlagReader names _) =
  fmt metavar halp names True
formatOpt (OptProperties vis halp metavar def) (ArgReader _) =
  "TODO"
formatOpt (OptProperties vis halp metavar def) (CmdReader cmd _) =
  "TODO"

fmt metavar halp names isFlag =
     "<p>"
  ++ "<strong>--"
  ++ getName names
  ++ "</strong><br/>"
  ++ maybe "" show (unChunk halp)
  ++ "<br/><input type=\"" ++ (if isFlag then "checkbox" else "text") ++ "\" name=\"" ++ getName names ++ "\" placeholder=\"" ++ metavar ++ "\"></input><br/></p>"

getName = head . sortBy (\x y -> length y `compare` length x) . map n
   where
     n (OptShort c) = return c
     n (OptLong s) = s

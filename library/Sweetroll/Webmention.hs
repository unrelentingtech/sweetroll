{-# LANGUAGE NoImplicitPrelude, OverloadedStrings, UnicodeSyntax #-}

module Sweetroll.Webmention (
  discoverWebmentionEndpoint
, sendWebmention
, sendWebmentions
) where

import           ClassyPrelude
import           Text.HTML.DOM
import           Text.XML.Lens hiding (to, from)
import qualified Text.Pandoc as P
import qualified Text.Pandoc.Walk as PW
import           Data.Conduit
import           Data.Microformats2
import           Data.Foldable (asum)
import           Data.Stringable (toText)
import qualified Data.Set as S
import           Network.HTTP.Link
import           Network.HTTP.Types
import           Network.HTTP.Client.Conduit
import           Network.URI
import           Sweetroll.Util
import           Sweetroll.Monads
import           Sweetroll.Conf

hLink ∷ HeaderName
hLink = "Link"

isWebmentionRel ∷ (EqSequence seq, IsString seq) ⇒ seq → Bool
isWebmentionRel = isInfixOf "webmention"

-- | Discovers a webmention endpoint for an address.
discoverWebmentionEndpoint ∷ URI → Response (Source SweetrollBase ByteString) → SweetrollBase (Maybe URI)
discoverWebmentionEndpoint to r = do
  htmlDoc ← responseBody r $$ sinkDoc
  let findInHeader = (lookup hLink $ responseHeaders r)
                     >>= parseLinkHeader . decodeUtf8
                     >>= find (isWebmentionRel . fromMaybe "" . lookup Rel . linkParams)
                     >>= return . unpack . href
      findInBody = unpack <$> htmlDoc ^. root . entire ./ attributeSatisfies "rel" isWebmentionRel . attribute "href"
      baseInBody = parseAbsoluteURI =<< unpack <$> htmlDoc ^. root . entire ./ el "base" . attribute "href"
      lnk = asum [findInHeader, findInBody]
      base = fromMaybe to baseInBody
  return $ asum [ lnk >>= parseAbsoluteURI
                , lnk >>= parseRelativeReference >>= return . (`relativeTo` base) ]

-- | Sends one single webmention.
sendWebmention ∷ String → String → SweetrollBase (String, Bool)
sendWebmention from to = do
  tReq ← liftIO $ parseUrl to
  endp ← withResponse tReq $ discoverWebmentionEndpoint $ getUri tReq
  case endp of
    Just u → do
      eReq ← liftIO $ parseUrl $ uriToString id u ""
      let reqBody = writeForm [("source", from), ("target", to)]
      eResp ← request eReq { method = "POST"
                            , requestHeaders = [ (hContentType, "application/x-www-form-urlencoded; charset=utf-8") ]
                            , requestBody = RequestBodyBS reqBody } ∷ SweetrollBase (Response String)
      putStrLn $ "Webmention status for <" ++ (asText . pack $ to) ++ ">: " ++ (toText . show . statusCode $ responseStatus eResp)
      return $ (to, responseStatus eResp == ok200 || responseStatus eResp == accepted202)
    _ → do
      putStrLn $ "No webmention endpoint found for <" ++ (asText . pack $ to) ++ ">"
      return (to, False)

-- | Send all webmentions required for an entry, including the ones from
-- metadata (in-reply-to, like-of, repost-of).
sendWebmentions ∷ Entry → SweetrollBase [(String, Bool)]
sendWebmentions e = mapM (sendWebmention from) links
  where links = S.toList $ S.fromList $ contentLinks ++ metaLinks
        metaLinks = map unpack $ catMaybes $ map derefEntry $ catMaybes [entryInReplyTo e, entryLikeOf e, entryRepostOf e]
        contentLinks = PW.query extractLink $ pandocContent $ entryContent e
        from = unpack $ fromMaybe "" $ entryUrl e
        pandocContent (Just (Left p)) = p
        pandocContent (Just (Right t)) = P.readMarkdown pandocReaderOptions $ unpack t
        pandocContent _ = P.readMarkdown pandocReaderOptions ""
        extractLink (P.Link _ (u, _)) = [u]
        extractLink _ = []

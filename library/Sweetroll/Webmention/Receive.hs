{-# LANGUAGE NoImplicitPrelude, OverloadedStrings, UnicodeSyntax, TupleSections #-}
{-# LANGUAGE RankNTypes, FlexibleContexts #-}

module Sweetroll.Webmention.Receive where

import           ClassyPrelude
import           Control.Lens
import           Control.Monad.Except (throwError)
import           Control.Concurrent.Lifted (fork)
import qualified Data.HashMap.Strict as HMS
import qualified Data.Vector as V
import           Data.String.Conversions
import           Data.Aeson
import           Data.Aeson.Lens
import           Network.URI
import           Network.HTTP.Types
import           Network.HTTP.Client.Conduit
import           Servant
import           Gitson
import           Sweetroll.Conf
import           Sweetroll.Monads

receiveWebmention ∷ [(Text, Text)] → Sweetroll ()
receiveWebmention allParams = do
  source ← guardJustP (errNoURIInField "source") $ parseURI =<< cs <$> lookup "source" allParams
  target ← guardJustP (errNoURIInField "target") $ parseURI =<< cs <$> lookup "target" allParams
  (category, slug) ← parseEntryURI target
  void $ guardJust errWrongPath $ documentIdFromName category slug
  shouldBeSync ← getConfOpt testMode
  (if shouldBeSync then void else void . fork) $ processWebmention category slug source target
  throwError respAccepted

processWebmention ∷ String → String → URI → URI → Sweetroll ()
processWebmention category slug source target =
  void $ withRequestHtml source $ \resp → do
    let withEntry x =
          transaction "." $ do
            entrym ← readDocumentByName category slug
            case entrym of
              Just entry → x entry
              _ → putStrLn $ "Received webmention for nonexistent " ++ tshow target ++ " from " ++ tshow source
    case statusCode $ responseStatus resp of
      410 → withEntry $ \entry → do
              putStrLn $ "Received gone webmention for " ++ tshow target ++ " from " ++ tshow source
              let updatedEntry = key "properties" %~ removeMentionOf source $ (entry ∷ Value)
              saveDocumentByName category slug updatedEntry
      200 → void $ withFetchEntryWithAuthors source resp $ \_ (mention, _) →
              if verifyMention target mention
                 then withEntry $ \entry → do
                   putStrLn $ "Received correct webmention for " ++ tshow target ++ " from " ++ tshow source
                   let updatedEntry = key "properties" %~ addMention mention $ (entry ∷ Value)
                   saveDocumentByName category slug updatedEntry
                 else putStrLn $ "Received unverified webmention for " ++ tshow target ++ " from " ++ tshow source ++ ": " ++ tshow mention
      _ → return ()
    return $ Just ()

verifyMention ∷ URI → Value → Bool
verifyMention t m | propIncludesURI t "in-reply-to" m = True
verifyMention t m | propIncludesURI t "like-of"     m = True
verifyMention t m | propIncludesURI t "repost-of"   m = True
-- TODO: check content (if we're going to support mentions that aren't replies, etc.)
verifyMention _ _ = False

propIncludesURI ∷ URI → Text → Value → Bool
propIncludesURI t p m = elem t $ catMaybes $ map (parseURI <=< unCite) $ fromMaybe V.empty $ m ^? key "properties" . key p . _Array
  where unCite v@(Object _) = cs <$> v ^? key "value" . _String
        unCite (String s)   = Just $ cs s
        unCite _            = Nothing

-- 0. write tests for this! and rename to upsert, not add
-- 1. don't write it all into "comment", keep likes and reposts separate
-- 2. first, check if entry is contained in nested entries -- update there if it is
--    (so, fromMaybe newAtRoot findEntry, where findEntry is depth-first search, and it returns a lens)
-- 3. delete first-level entries that are duplicates of nested entires (entries that reply to posts on two levels)
--    (filter where findEntry returns None)
addMention ∷ Value → Value → Value
addMention m (Object props) = Object $ HMS.insertWith updateOrAdd "comment" (Array $ V.singleton m) props
  -- XXX: This is terrible.
  where updateOrAdd (Array new) (Array old) = Array $ case V.findIndex (intersectingUrls $ urls m) old of
                                                        Just idx → old V.// [(idx, m)]
                                                        Nothing → old ++ new
        updateOrAdd anew@(Array _) _ = anew
        updateOrAdd _ old = old
addMention _ x = x

removeMentionOf ∷ URI → Value → Value
removeMentionOf uri (Object props) = Object $ HMS.adjust removeMention "comment" props
  -- XXX: Use URI equality, not text equality?
  where removeMention (Array ms) = Array $ V.filter (not . intersectingUrls (V.fromList [String $ tshow uri])) ms
        removeMention x = x
removeMentionOf _ x = x

intersectingUrls ∷ Vector Value → Value → Bool
intersectingUrls us e = hasIntersection us (urls e)
  where hasIntersection x = not . null . V.filter (`V.elem` x)

urls ∷ Value → Vector Value
urls x = fromMaybe V.empty $ x ^? key "properties" . key "url" . _Array

respAccepted ∷ ServantErr -- XXX: Only way to return custom HTTP response codes
respAccepted = ServantErr { errHTTPCode = 202
                          , errReasonPhrase = "Accepted"
                          , errHeaders = [ (hContentType, "text/plain; charset=utf-8") ]
                          , errBody    = "Your webmention will be processed soon." }

{-# LANGUAGE OverloadedStrings, ScopedTypeVariables #-}

-- | The module that contains the Sweetroll WAI application.
module Sweetroll (app) where

import           Network.Wai (Application)
import           Network.Wai.Middleware.Autohead
import           Network.HTTP.Types.Status
import           Control.Monad.IO.Class (liftIO)
import           Data.Text.Lazy (Text, split, unpack)
import           Data.Time.Clock
import           Data.Monoid
import           Data.Maybe
import           Web.Scotty.Trans (ActionT)
import           Web.Scotty
import           Gitson
import           Sweetroll.Types
import           Sweetroll.Util

getHost :: ActionT Text IO Text
getHost = header "Host" >>= return . (fromMaybe "localhost")

created :: [Text] -> ActionT Text IO ()
created urlParts = do
  status created201
  host <- getHost
  setHeader "Location" $ mconcat $ ["http://", host, "/"] ++ urlParts

-- | The Sweetroll WAI application.
app :: IO Application
app = scottyApp $ do
  middleware autohead -- XXX: does it even work properly?

  post "/micropub" $ do
    h :: Text <- param "h"
    allParams <- params
    let findParam = findByKey allParams
        category = fromMaybe "notes" $ findParam "category"
        slug = fromMaybe "" $ findParam "slug" -- TODO: auto slug
        save x = liftIO $ transaction "./" $ saveNextEntry (unpack category) (unpack slug) x
    now <- liftIO $ getCurrentTime
    case h of
      "entry" -> do
        save Entry {
              entryName      = findParam "name"
            , entrySummary   = findParam "summary"
            , entryContent   = findParam "content"
            , entryPublished = fromMaybe now $ parseTime $ findParam "published"
            , entryUpdated   = now
            , entryTags      = split (== ',') $ fromMaybe "" $ findParam "tags"
            , entryAuthor    = findParam "author"
            , entryInReplyTo = findParam "in-reply-to"
            , entryLikeOf    = findParam "like-of"
            , entryRepostOf  = findParam "repost-of" }
        created [category, "/", slug]
      _ -> status badRequest400

  matchAny "/micropub" $ status methodNotAllowed405

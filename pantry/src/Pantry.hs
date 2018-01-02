module Pantry where

import RIO
import RIO.FilePath
import qualified RIO.HashMap as HashMap
import qualified RIO.Text as T

class HasPantryBackend env where
  pantryBackendL :: Lens' env PantryBackend

newtype SHA256 = SHA256 ShortByteString -- FIXME consider using Word64s
  deriving (Generic, Show, Eq, NFData, Data, Typeable, Ord, Hashable)

newtype BlobKey = BlobKey SHA256
  deriving (Generic, Show, Eq, NFData, Data, Typeable, Ord, Hashable)

newtype TreeKey = TreeKey SHA256
  deriving (Generic, Show, Eq, NFData, Data, Typeable, Ord, Hashable)

newtype Tree = Tree (Map SafeFilePath TreeEntry)
  deriving (Generic, Show, Eq, NFData, Data, Typeable)

newtype SafeFilePath = SafeFilePath ShortByteString
  deriving (Generic, Show, Eq, NFData, Data, Typeable, Ord, Hashable)

data UnsafeFilePath = UnsafeFilePath !FilePath !Text
  deriving (Show, Eq, Typeable)
instance Exception UnsafeFilePath

toSafeFilePath :: MonadThrow m => FilePath -> m SafeFilePath
toSafeFilePath fp = do
  (head', last') <-
    case fp of
      [] -> err "empty path"
      head':rest -> return $
        case reverse rest of
          [] -> (head', head')
          last':_ -> (head', last')

  when (any (== '\\') fp) $ err "contains backslash"
  when (any (== '\0') fp) $ err "contains NUL"
  when (head' == '/') $ err "begins with slash"
  when (last' == '/') $ err "ends with slash"

  let segments = map dropTrailingSlash $ splitPath fp
      dropTrailingSlash x =
        case reverse x of
          '/':rest -> reverse rest
          _ -> x
  for_ [".", ".."]
    $ \bad -> when (bad `elem` segments)
    $ err $ "invalid segment: " <> tshow bad

  let checkDouble [] = return ()
      checkDouble [_] = return ()
      checkDouble ('/':'/':_) = err "double slash"
      checkDouble (_:rest) = checkDouble rest
  checkDouble fp

  return $ SafeFilePath $ toShort $ T.encodeUtf8 $ T.pack fp
  where
    err = throwM . UnsafeFilePath fp

fromSafeFilePath :: SafeFilePath -> FilePath
fromSafeFilePath (SafeFilePath sbs) =
  case T.decodeUtf8' $ fromShort sbs of
    Left e -> error $ "fromSafeFilePath: impossible invalid UTF-8 sequence: " ++ show (sbs, e)
    Right x -> T.unpack x

data TreeEntry = TreeEntry
  { teExecutable :: !Bool
  , teBlob :: !BlobKey
  }
  deriving (Generic, Show, Eq, Data, Typeable)
instance NFData TreeEntry

data PantryBackend = PantryBackend
  { pbSaveBlob :: !(ByteString -> IO BlobKey)
  , pbLoadBlob :: !(BlobKey -> IO (Maybe ByteString))
  , pbSaveTree :: !(Tree -> IO TreeKey)
  , pbLoadTree :: !(TreeKey -> IO (Maybe Tree))
  }

newMemoryBackend :: MonadIO m => m PantryBackend
newMemoryBackend = do
  blobRef <- newIORef mempty
  treeRef <- newIORef mempty
  return PantryBackend
    { pbSaveBlob = \bs -> do
        let key = BlobKey $ bytesToSHA256 bs
        atomicModifyIORef' blobRef $ \m ->
          let m' =
               case HashMap.lookup key m of
                 Nothing -> m''
                 Just bs'
                   | bs == bs' -> m''
                   | otherwise -> error "Invariant violated in newMemoryBackend.pbSaveBlob"
              m'' = HashMap.insert key bs m
           in (m'', key)
    , pbLoadBlob = \key -> HashMap.lookup key <$> readIORef blobRef
    , pbSaveTree = \tree -> do
        let bs = encodeTree tree
            key = TreeKey $ bytesToSHA256 bs
        atomicModifyIORef' treeRef $ \m ->
          let m' =
                case HashMap.lookup key m of
                  Nothing -> m''
                  Just bs'
                    | bs == bs' -> m''
                    | otherwise -> error "Invariant violated in newMemoryBackend.pbSaveTree"
              m'' = HashMap.insert key bs m
           in (m'', key)
    , pbLoadTree =
            \key ->
            (HashMap.lookup key <$> readIORef treeRef) >>=
            maybe (return Nothing) (fmap Just . decodeTree)
    }

encodeTree :: Tree -> ByteString
encodeTree = error "encodeTree"

decodeTree :: MonadThrow m => ByteString -> m Tree
decodeTree = error "decodeTree"

bytesToSHA256 :: ByteString -> SHA256
bytesToSHA256 = error "bytesToSHA256"

-- FIXME directoryToTree

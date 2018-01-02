module PantrySpec (spec) where

import Test.Hspec
import Test.Hspec.QuickCheck
import Test.QuickCheck.Arbitrary
import RIO
import Pantry

instance Arbitrary Tree

spec :: Spec
spec = do
  describe "toSafeFilePath" $ do
    let good fp = it fp $ fmap fromSafeFilePath (toSafeFilePath fp) `shouldBe` Just fp
        bad fp = it fp $ toSafeFilePath fp `shouldBe` Nothing
    good "hello"
    good "hello/world"
    bad "hello//world"
    bad "//hello/world"
    bad "hello\\world"
    bad "hello/./world"
    bad "hello/../world"
    good "שלום/world"
    bad "/שלום/world/"
    bad "foo/bar/"

    prop "to . from" $ \fp ->
      case toSafeFilePath fp of
        Nothing -> return ()
        Just sfp -> fromSafeFilePath sfp `shouldBe` fp

  describe "tree encoding" $ do
    prop "idempotent" $ \tree -> decodeTree (encodeTree tree) `shouldBe` Just tree

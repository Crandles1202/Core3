/*
 * FbTreTest.cpp — Final Boss: the custom data archive (finalboss.tre, built by tools/tre from tre-src/)
 * is listed first in the server's TRE search order, loads, and its string tables parse the way the
 * server expects. Needs the archive installed in TrePath (tools/swg tre install; swg start does it).
 */

#include "gtest/gtest.h"
#include "conf/ConfigManager.h"
#include "templates/manager/DataArchiveStore.h"
#include "templates/manager/TemplateManager.h"
#include "templates/string/StringFile.h"

class FbTreTest : public ::testing::Test {
protected:
	void SetUp() override {
		ConfigManager::instance()->loadConfigData();
		DataArchiveStore::instance()->loadTres(ConfigManager::instance()->getTrePath(), ConfigManager::instance()->getTreFiles());
	}
};

TEST_F(FbTreTest, FinalBossArchiveIsSearchedFirst) {
	const Vector<String>& files = ConfigManager::instance()->getTreFiles();
	ASSERT_GT(files.size(), 0);
	EXPECT_EQ(String("finalboss.tre"), files.get(0)) << "config.lua TreFiles must start with finalboss.tre: the first archive that has a path wins";
}

TEST_F(FbTreTest, LabStringTableLoadsThroughTheServer) {
	UniqueReference<ObjectInputStream*> stream(TemplateManager::instance()->openTreFile("string/en/fb_lab.stf"));
	ASSERT_TRUE(stream != nullptr) << "string/en/fb_lab.stf not found: is " << ConfigManager::instance()->getTrePath().toCharArray() << "/finalboss.tre installed? (tools/swg tre install)";
	ASSERT_GT(stream->size(), 4);

	StringFile stringFile;
	ASSERT_TRUE(stringFile.load(stream)) << "the server's StringFile loader rejected the table tools/tre built";

	const auto& strings = stringFile.getStringMap();
	EXPECT_EQ(3, strings.size());
	EXPECT_EQ(String("Final Boss TRE probe: first"), strings.get("probe_first").toString());
	EXPECT_EQ(String("Final Boss TRE probe: middle, with a\nline break and a %TT token"), strings.get("probe_middle").toString());
	EXPECT_EQ(String("Final Boss TRE probe: last"), strings.get("probe_last").toString()) << "last entry of a string table lost";
}

TEST_F(FbTreTest, StockStringTableStillResolves) {
	// A sanity check that our archive being first does not shadow stock tables we never meant to touch.
	UniqueReference<ObjectInputStream*> stream(TemplateManager::instance()->openTreFile("string/en/jedi_spam.stf"));
	ASSERT_TRUE(stream != nullptr);

	StringFile stringFile;
	ASSERT_TRUE(stringFile.load(stream));
	EXPECT_GT(stringFile.getStringMap().size(), 100);
}

/*
 * AuctionAction.cpp
 *
 * Bazaar / vendor actions. Each sends one client packet and waits for the server's status reply
 * (decoded by ZonePacketHandler::handleAuctionStatusMessage into Auction/<kind>/<oid>/status).
 *
 *   --sell <itemOid> <vendorOid> <price> [--sell-desc <text>] [--auction-timeout <sec>]
 *       CreateImmediateAuctionMessage (0x1E9CE308): instant sale, 7-day duration requested
 *       reply ItemSoldMessage: 0 ok, 13 TOOMANYITEMS, 9 NOTENOUGHCREDITS, 4 INVALIDSALEPRICE ...
 *   --buy <itemOid> <price>                   BidAuctionMessage (0x91125453); instant sale => buy
 *       reply BidAuctionResponseMessage: 0 ok, 9 NOTENOUGHCREDITS, 10 PURCHASEFAILED ...
 *   --retrieve <itemOid> <vendorOid>          RetrieveAuctionItemMessage (0x12B0D449)
 *       reply RetrieveAuctionItemResponseMessage: 0 ok, 12 FULLINVENTORY, 0x100 TOOFAR ...
 *   JSON: {"action":"sell","item":1,"vendor":2,"price":10}, {"action":"buy",...}, {"action":"retrieve",...}
 */

#include "client/ActionBase.h"
#include "client/ActionResult.h"
#include "client/ActionManager.h"
#include "client/ClientCore.h"
#include "client/zone/Zone.h"
#include "client/zone/ZoneClient.h"
#include "engine/service/proto/BaseMessage.h"

class ClientCreateImmediateAuction : public BaseMessage {
public:
	ClientCreateImmediateAuction(uint64 itemOid, uint64 vendorOid, int price, int duration, const UnicodeString& description) {
		insertShort(0x07);
		insertInt(0x1E9CE308);   // CreateImmediateAuctionMessage
		insertLong(itemOid);
		insertLong(vendorOid);
		insertInt(price);
		insertInt(duration);
		insertUnicode(description);
		insertByte(0);           // premium flag
	}
};

class ClientBidAuction : public BaseMessage {
public:
	ClientBidAuction(uint64 itemOid, int price1, int price2) {
		insertShort(0x04);
		insertInt(0x91125453);   // BidAuctionMessage
		insertLong(itemOid);
		insertInt(price1);
		insertInt(price2);
	}
};

class ClientRetrieveAuctionItem : public BaseMessage {
public:
	ClientRetrieveAuctionItem(uint64 itemOid, uint64 vendorOid) {
		insertShort(0x03);
		insertInt(0x12B0D449);   // RetrieveAuctionItemMessage
		insertLong(itemOid);
		insertLong(vendorOid);
	}
};

// Common skeleton: one packet, one status reply keyed by item oid.
class AuctionActionBase : public ActionBase {
protected:
	String itemSpec;
	String vendorSpec;
	int price;
	String description;
	int timeoutSeconds;

	ActionResult result;
	bool skipped;
	uint32 status;

	AuctionActionBase() : price(0), timeoutSeconds(10), skipped(false), status(0xFFFFFFFF) {
		setLogLevel(Logger::INFO);
	}

	virtual const char* kind() const = 0;                 // "sold" | "bid" | "retrieve"
	virtual BaseMessage* buildPacket(uint64 item, uint64 vendor) = 0;
	virtual bool needsVendor() const { return true; }

	bool waitForStatus(ClientCore& core, uint64 item) {
		String key = String("Auction/") + kind() + "/o" + String::valueOf(item) + "/status";
		int waited = 0;
		while (!core.hasVar(key) && waited < timeoutSeconds * 1000) {
			Thread::sleep(50);
			waited += 50;
		}
		if (!core.hasVar(key))
			return false;
		status = core.getVar<uint32>(key, 0xFFFFFFFF);
		return true;
	}

public:
	bool needsZone() const override { return true; }
	bool needsTarget() const override { return true; }
	bool needsCharacter() const override { return true; }

	void run(ClientCore& core) override {
		if (core.zone == nullptr || !core.zone->isConnected() || !core.zone->isSceneReady()) {
			result.setError("Not in the zone", 1);
			return;
		}
		uint64 item = UnsignedLong::valueOf(itemSpec);
		uint64 vendor = needsVendor() ? UnsignedLong::valueOf(vendorSpec) : 0;
		if (item == 0 || (needsVendor() && vendor == 0)) {
			result.setError(String("--") + getName() + " needs object ids", 2);
			return;
		}

		info() << getName() << " item=" << item << " vendor=" << vendor << " price=" << price;
		core.zone->getZoneClient()->sendMessage(buildPacket(item, vendor));

		if (!waitForStatus(core, item)) {
			result.setError(String("No auction reply for ") + getName() + " within " + String::valueOf(timeoutSeconds) + "s", 3);
			return;
		}
		if (status != 0) {
			result.setError(String(getName()) + " rejected: status=" + String::valueOf(status), 4);
			return;
		}
		result.setSuccess();
	}

	bool isOK() const override { return !skipped && result.isOK(); }
	String getError() const override { return result.getError(); }
	uint16 getErrorCode() const override { return result.getErrorCode(); }
	void setSkipped() override { skipped = true; }

	JSONSerializationType toJSON() const override {
		JSONSerializationType json;
		json["action"] = getName();
		json["item"] = itemSpec.toCharArray();
		if (needsVendor()) json["vendor"] = vendorSpec.toCharArray();
		if (price) json["price"] = price;
		if (status != 0xFFFFFFFF) json["auctionStatus"] = status;
		if (skipped) {
			json["status"] = "skipped";
		} else if (result.isOK()) {
			json["status"] = "ok";
		} else {
			json["status"] = "failed";
			json["error"] = result.getError().toCharArray();
			json["errorCode"] = result.getErrorCode();
		}
		return json;
	}

	// shared option parsing for the trailing flags
	bool parseCommonFlag(const Vector<String>& args, int& i, int& consumed) {
		if (args.get(i) == "--auction-timeout" && i + 1 < args.size()) {
			timeoutSeconds = Integer::valueOf(args.get(i + 1));
			consumed += 2; i += 2; return true;
		}
		return false;
	}
};

// ---- sell ------------------------------------------------------------------------------------

class SellAction : public AuctionActionBase {
public:
	SellAction() { setLoggingName("Sell"); }
	const char* getName() const override { return "sell"; }
	const char* kind() const override { return "sold"; }
	BaseMessage* buildPacket(uint64 item, uint64 vendor) override {
		return new ClientCreateImmediateAuction(item, vendor, price, 7 * 24 * 3600, UnicodeString(description));
	}

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		SellAction* me = nullptr;
		int i = startIndex;
		while (i < args.size()) {
			int last = consumed;
			if (args.get(i) == "--sell" && i + 3 < args.size()) {
				if (me != nullptr) break;
				me = new SellAction();
				me->itemSpec = args.get(i + 1);
				me->vendorSpec = args.get(i + 2);
				me->price = Integer::valueOf(args.get(i + 3));
				consumed += 4; i += 4;
			} else if (me != nullptr && args.get(i) == "--sell-desc" && i + 1 < args.size()) {
				me->description = args.get(i + 1);
				consumed += 2; i += 2;
			} else if (me != nullptr && me->parseCommonFlag(args, i, consumed)) {
			}
			if (consumed == last) break;
		}
		if (me != nullptr) result.add(me);
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		SellAction* me = new SellAction();
		if (config.contains("item")) me->itemSpec = String::valueOf(config["item"].get<uint64>());
		if (config.contains("vendor")) me->vendorSpec = String::valueOf(config["vendor"].get<uint64>());
		if (config.contains("price")) me->price = config["price"].get<int>();
		if (config.contains("description")) me->description = String(config["description"].get<std::string>().c_str());
		if (config.contains("timeout")) me->timeoutSeconds = config["timeout"].get<int>();
		return me;
	}

	String getHelpText() const override {
		return "--sell <itemOid> <vendorOid> <price> [--sell-desc <text>] [--auction-timeout <sec>]  List an item for instant sale on a bazaar/vendor";
	}
	static ActionBase* factory() { return new SellAction(); }
};

// ---- buy -------------------------------------------------------------------------------------

class BuyAction : public AuctionActionBase {
public:
	BuyAction() { setLoggingName("Buy"); }
	const char* getName() const override { return "buy"; }
	const char* kind() const override { return "bid"; }
	bool needsVendor() const override { return false; }
	BaseMessage* buildPacket(uint64 item, uint64) override {
		return new ClientBidAuction(item, price, price);
	}

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		BuyAction* me = nullptr;
		int i = startIndex;
		while (i < args.size()) {
			int last = consumed;
			if (args.get(i) == "--buy" && i + 2 < args.size()) {
				if (me != nullptr) break;
				me = new BuyAction();
				me->itemSpec = args.get(i + 1);
				me->price = Integer::valueOf(args.get(i + 2));
				consumed += 3; i += 3;
			} else if (me != nullptr && me->parseCommonFlag(args, i, consumed)) {
			}
			if (consumed == last) break;
		}
		if (me != nullptr) result.add(me);
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		BuyAction* me = new BuyAction();
		if (config.contains("item")) me->itemSpec = String::valueOf(config["item"].get<uint64>());
		if (config.contains("price")) me->price = config["price"].get<int>();
		if (config.contains("timeout")) me->timeoutSeconds = config["timeout"].get<int>();
		return me;
	}

	String getHelpText() const override {
		return "--buy <itemOid> <price> [--auction-timeout <sec>]  Buy an instant-sale item (then --retrieve it)";
	}
	static ActionBase* factory() { return new BuyAction(); }
};

// ---- retrieve --------------------------------------------------------------------------------

class RetrieveAction : public AuctionActionBase {
public:
	RetrieveAction() { setLoggingName("Retrieve"); }
	const char* getName() const override { return "retrieve"; }
	const char* kind() const override { return "retrieve"; }
	BaseMessage* buildPacket(uint64 item, uint64 vendor) override {
		return new ClientRetrieveAuctionItem(item, vendor);
	}

	static Vector<ActionBase*> fromArgs(const Vector<String>& args, int startIndex, int& consumed) {
		Vector<ActionBase*> result;
		consumed = 0;
		RetrieveAction* me = nullptr;
		int i = startIndex;
		while (i < args.size()) {
			int last = consumed;
			if (args.get(i) == "--retrieve" && i + 2 < args.size()) {
				if (me != nullptr) break;
				me = new RetrieveAction();
				me->itemSpec = args.get(i + 1);
				me->vendorSpec = args.get(i + 2);
				consumed += 3; i += 3;
			} else if (me != nullptr && me->parseCommonFlag(args, i, consumed)) {
			}
			if (consumed == last) break;
		}
		if (me != nullptr) result.add(me);
		return result;
	}

	static ActionBase* fromJSON(const JSONSerializationType& config) {
		RetrieveAction* me = new RetrieveAction();
		if (config.contains("item")) me->itemSpec = String::valueOf(config["item"].get<uint64>());
		if (config.contains("vendor")) me->vendorSpec = String::valueOf(config["vendor"].get<uint64>());
		if (config.contains("timeout")) me->timeoutSeconds = config["timeout"].get<int>();
		return me;
	}

	String getHelpText() const override {
		return "--retrieve <itemOid> <vendorOid> [--auction-timeout <sec>]  Pick up a bought/unsold item from a bazaar/vendor";
	}
	static ActionBase* factory() { return new RetrieveAction(); }
};

static bool _registered_auction =
	(ActionManager::registerAction("sell", SellAction::factory, SellAction::fromArgs, SellAction::fromJSON),
	 ActionManager::registerAction("buy", BuyAction::factory, BuyAction::fromArgs, BuyAction::fromJSON),
	 ActionManager::registerAction("retrieve", RetrieveAction::factory, RetrieveAction::fromArgs, RetrieveAction::fromJSON),
	 true);

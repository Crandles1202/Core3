#include "Zone.h"
#include "ZonePacketHandler.h"
#include "ClientCore.h"
#include "client/zone/objects/scene/SceneObject.h"
#include "server/zone/packets/zone/SelectCharacter.h"
#include "server/zone/packets/zone/CmdSceneReady.h"
#include "client/zone/managers/object/ObjectManager.h"
#include "client/zone/managers/objectcontroller/ObjectController.h"
#include "server/zone/packets/charcreation/ClientCreateCharacter.h"

ZonePacketHandler::ZonePacketHandler(const String& s, Zone* z, ClientCore* clientCore) : Logger(s) {
	zone = z;
	core = clientCore;

	setLogging(true);
	setGlobalLogging(true);
	setLogLevel(static_cast<Logger::LogLevel>(ClientCore::getLogLevel()));
}

#define CASE_OPCODE(str) case STRING_HASHCODE(str): what = str

void ZonePacketHandler::handleMessage(Message* pack) {
	Locker lock(this);

	sys::uint16 opcount = pack->parseShort();
	sys::uint32 opcode = pack->parseInt();

	String what;

	switch (opcount) {
	case 1:
		switch (opcode) {
		CASE_OPCODE("CmdSceneReady");
			handleCmdSceneReady(pack);
			break;
		}
	case 2:
		switch (opcode) {
		CASE_OPCODE("ClientCreateCharacterSuccess");
			handleClientCreateCharacterSuccess(pack);
			break;
		CASE_OPCODE("SceneEndBaselines");
			break;
		CASE_OPCODE("ChatPersistentMessageToClient");
			break;
		CASE_OPCODE("ChatServerStatus");
			break;
		CASE_OPCODE("ParametersMessage");
			break;
		CASE_OPCODE("ServerTimeMessage");
			break;
		CASE_OPCODE("ChatRoomList");
			break;
		}
		break;
	case 3:
		switch (opcode) {
		CASE_OPCODE("ErrorMessage");
			handleErrorMessage(pack);
			break;
		CASE_OPCODE("ClientCreateCharacterFailed");
			handleClientCreateCharacterFailed(pack);
			break;
		CASE_OPCODE("UpdateCellPermissionMessage");
			break;
		CASE_OPCODE("ServerWeatherMessage");
			break;
		CASE_OPCODE("ChatOnGetFriendsList");
			break;
		CASE_OPCODE("ChatOnGetIgnoreList");
			break;
		CASE_OPCODE("ChatOnLeaveRoom");
			break;
		CASE_OPCODE("SceneDestroyObject");
			break;
		case 0x0E61CC92: what = "ItemSoldMessage";              // reply to CreateImmediateAuction
			handleAuctionStatusMessage(pack, "sold");
			break;
		case 0x8FCBEF4A: what = "BidAuctionResponseMessage";    // reply to BidAuction
			handleAuctionStatusMessage(pack, "bid");
			break;
		case 0x9499EF8C: what = "RetrieveAuctionItemResponseMessage"; // reply to RetrieveAuctionItem
			handleAuctionStatusMessage(pack, "retrieve");
			break;
		}
		break;

	case 4:
		switch (opcode) {
		CASE_OPCODE("ClientPermissionsMessage");
			handleClientPermissionsMessage(pack);
			break;

		CASE_OPCODE("ClientRandomNameResponse");
			handleClientRandomNameResponse(pack);
			break;

		CASE_OPCODE("UpdateContainmentMessage");
			handleUpdateContainmentMessage(pack);
			break;

		CASE_OPCODE("ChatSystemMessage");
			handleChatSystemMessage(pack);
			break;

		CASE_OPCODE("UpdatePvpStatusMessage");
			break;
		}
		break;
	case 5:
		switch (opcode) {
		CASE_OPCODE("SceneCreateObjectByCrc");
			handleSceneObjectCreateMessage(pack);
			break;

		CASE_OPCODE("BaselinesMessage");
			handleBaselineMessage(pack);
			break;

		CASE_OPCODE("ChatInstantMessageToClient");
			handleChatInstantMessageToClient(pack);
			break;

		CASE_OPCODE("ObjControllerMessage");
			handleObjectControllerMessage(pack);
			break;

		CASE_OPCODE("DeltasMessage");
			break;

		CASE_OPCODE("ChatOnDestroyRoom");
			break;

		CASE_OPCODE("ChatOnEnteredRoom");
			break;
		}
		break;
	case 9:
		switch (opcode) {
		CASE_OPCODE("CmdStartScene");
			handleCmdStartScene(pack);
			break;
		}
		break;
	}

	if (what.isEmpty()) {
		uint32 count = unknownOpcodes.contains(opcode) ? unknownOpcodes.get(opcode) : 0;
		unknownOpcodes.put(opcode, count + 1);
		what = "unknown";
	}

	debug() << __FUNCTION__ << ": " << what << "(opcount=" << opcount << ", opcode=0x" << uppercase << hex << opcode << ")";

	// Auto-signal for all recognized packets (signal() ignores if no waiter)
	if (!what.isEmpty() && what != "unknown") {
		zone->signal(opcode);
	}
}

void ZonePacketHandler::handleClientPermissionsMessage(Message* pack) {
	info(true) << __FUNCTION__;

	bool canLogin = pack->parseByte();
	bool canCreateRegularCharacter = pack->parseByte();
	bool canCreateJediCharacter = pack->parseByte();
	bool canSkipTutorial = pack->parseByte();

	// Store permissions on zone for actions to check
	zone->setPermissions(canLogin, canCreateRegularCharacter, canCreateJediCharacter, canSkipTutorial);

	info(true) << "Client permissions received:";
	info(true) << "    canLogin = " << canLogin;
	info(true) << "    canCreateCharacter = " << canCreateRegularCharacter;
	info(true) << "    canCreateJedi = " << canCreateJediCharacter;
	info(true) << "    canSkipTutorial = " << canSkipTutorial;
}

void ZonePacketHandler::handleCmdStartScene(Message* pack) {
	info(true) << __FUNCTION__;

	BaseClient* client = (BaseClient*) pack->getClient();

	uint8 unknown = pack->parseByte();
	uint64 selfPlayerObjectID = pack->parseLong();
	String terrain;
	pack->parseAscii(terrain);

	float x = pack->parseFloat();
	float z = pack->parseFloat();
	float y = pack->parseFloat();

	String race;
	pack->parseAscii(race);

	uint64 galacticTime = pack->parseLong();

	// Server confirms our character OID
	if (core->selectedCharacterOid != selfPlayerObjectID) {
		error() << "Scene starting for wrong OID: " << selfPlayerObjectID
			<< "; expected OID: " << core->selectedCharacterOid
			<< "; aborting Scene.";
		return;
	}

	info(true) << "Scene Starting for character OID: " << selfPlayerObjectID;

	BaseMessage* msg = new CmdSceneReady();
	client->sendPacket(msg);

	zone->setSceneStarted();
}

void ZonePacketHandler::handleSceneObjectCreateMessage(Message* pack) {
	BaseClient* client = (BaseClient*) pack->getClient();
	uint64 objectID = pack->parseLong();
	pack->shiftOffset(16);

	float x = pack->parseFloat();
	float z = pack->parseFloat();
	float y = pack->parseFloat();

	uint32 crc = pack->parseInt();

	ObjectManager* objectManager = zone->getObjectManager();
	if (objectManager == nullptr) {
		error("object manager was nullptr");
		return;
	}

	SceneObject* object = objectManager->createObject(crc, objectID);

	if (object == nullptr) {
		client->debug() << "unknown crc 0x" << hex << crc << " received in SceneObjectCreateMessage";
		return;
	}

	object->setClient(zone->getZoneClient());
}

void ZonePacketHandler::handleBaselineMessage(Message* pack) {
	BaseClient* client = (BaseClient*) pack->getClient();

	uint64 oid = pack->parseLong();
	uint32 nametype = pack->parseInt();
	uint8 type = pack->parseByte();

	uint32 size = pack->parseInt();

	uint16 opcount = pack->parseShort();

	SceneObject* object = zone->getObject(oid);

	if (object == nullptr) {
		client->debug("received baseline for null object");
		return;
	}

	Locker objectLocker(object);

	switch (type) {
	case 3:
		object->parseBaseline3(pack);
		break;
	case 6:
		object->parseBaseline6(pack);
		break;
	default:
		break;
	}
}

void ZonePacketHandler::handleChatInstantMessageToClient(Message* pack) {
	BaseClient* client = (BaseClient*) pack->getClient();

	String game, galaxy, name;
	UnicodeString message;

	pack->parseAscii(game);
	pack->parseAscii(galaxy);
	pack->parseAscii(name);
	pack->parseUnicode(message);

	StringBuffer infoMsg;
	infoMsg << "instant message from [" << name << "] : " << message.toString();
	client->info(infoMsg.toString());
}

void ZonePacketHandler::handleChatSystemMessage(Message* pack) {
	info(true) << __FUNCTION__;

	BaseClient* client = (BaseClient*) pack->getClient();

	uint8 type = pack->parseByte();

	UnicodeString message;
	pack->parseUnicode(message);

	// StringId form (ChatSystemMessage(StringIdChatParameter&)): empty unicode, then a sized
	// block holding @file:id plus TU/TT/TO parameters and DI/DF. Render it roughly the way the
	// real client would: "@file:id TO=... DI=n".
	try {
		int paramSize = pack->parseInt();
		if (message.isEmpty() && paramSize > 0) {
			pack->parseByte();
			String file, id;
			pack->parseAscii(file);
			pack->parseInt();
			pack->parseAscii(id);
			StringBuffer text;
			text << "@" << file << ":" << id;

			const char* names[3] = { "TU", "TT", "TO" };
			for (int k = 0; k < 3; ++k) {
				uint64 oid = pack->parseLong();
				String pfile, pid;
				pack->parseAscii(pfile);
				pack->parseInt();
				pack->parseAscii(pid);
				UnicodeString custom;
				pack->parseUnicode(custom);
				if (oid != 0) text << " " << names[k] << "=#" << oid;
				else if (!custom.isEmpty()) text << " " << names[k] << "=" << custom.toString();
				else if (!pid.isEmpty()) text << " " << names[k] << "=@" << pfile << ":" << pid;
			}
			int di = pack->parseInt();
			float df = pack->parseFloat();
			if (di != 0) text << " DI=" << di;
			if (df != 0) text << " DF=" << df;
			message = UnicodeString(text.toString());
		}
	} catch (const Exception& e) {
		// unexpected layout: keep whatever plain text we already have
	}

	info(true) << "type=" << type << "; len=" << message.length();

	StringTokenizer lines(message.toString());
	lines.setDelimeter("\n");

	while (lines.hasMoreTokens()) {
		String line;
		lines.getStringToken(line);
		info(true) << "> " << line;

		// keep the last 200 lines so a scenario can look for "You heal ..." etc.
		auto& kept = core->vars[JSONSerializationType::json_pointer("/SystemMessages")];
		if (!kept.is_array())
			kept = JSONSerializationType::array();
		if (kept.size() >= 200)
			kept.erase(kept.begin());
		kept.push_back(line.toCharArray());
	}
}

void ZonePacketHandler::handleObjectControllerMessage(Message* pack) {
	uint32 header1 = pack->parseInt();
	uint32 header2 = pack->parseInt();
	uint64 objectID = pack->parseLong();
	pack->parseInt();

	// The sub-messages the bot cares about are decoded into core->vars so actions can poll
	// for them; everything else is ignored. Each one also signals a synthetic opcode.
	try {
		switch (header2) {
		case 0x117: { // CommandQueueRemove: the server's verdict on a queued command
			uint32 actionCount = pack->parseInt();
			float timer = pack->parseFloat();
			uint32 error = pack->parseInt();
			uint32 state = pack->parseInt();

			String key = "CommandQueueRemove/c" + String::valueOf(actionCount);
			core->setVar(key + "/error", error);
			core->setVar(key + "/state", state);
			core->setVar(key + "/timer", timer);

			info(true) << "CommandQueueRemove count=" << actionCount << " error=" << error << " state=" << state;
			zone->signal(STRING_HASHCODE("CommandQueueRemove"));
			break;
		}
		case 0xDD: { // StartNpcConversation
			uint64 npcID = pack->parseLong();
			uint8 starter = pack->parseByte();

			core->setVar("Conversation/npc", npcID);
			core->setVar("Conversation/active", true);
			core->setVar("Conversation/optionCount", 0);
			core->vars[JSONSerializationType::json_pointer("/Conversation/options")] = JSONSerializationType::array();

			info(true) << "StartNpcConversation npc=" << npcID << " starter=" << (int) starter;
			zone->signal(STRING_HASHCODE("StartNpcConversation"));
			break;
		}
		case 0xDF: { // NpcConversationMessage: plain unicode, or a StringId (size, short, byte, ascii file, int, ascii id)
			String text;
			int start = pack->getOffset();
			int32 len = pack->parseInt();

			if (len >= 0 && pack->getOffset() + len * 2 <= pack->size() && len < 8192) {
				pack->setOffset(start);
				UnicodeString uni;
				pack->parseUnicode(uni);
				text = uni.toString();
			} else {
				pack->parseShort();
				pack->parseByte();
				String file, id;
				pack->parseAscii(file);
				pack->parseInt();
				pack->parseAscii(id);
				text = "@" + file + ":" + id;
			}

			core->setVar("Conversation/message", text);
			core->vars[JSONSerializationType::json_pointer("/Conversation/transcript")].push_back(std::string("NPC: ") + text.toCharArray());

			info(true) << "NpcConversationMessage: " << text;
			zone->signal(STRING_HASHCODE("NpcConversationMessage"));
			break;
		}
		case 0xE0: { // StringList: the conversation options
			uint8 count = pack->parseByte();
			JSONSerializationType options = JSONSerializationType::array();

			for (int i = 0; i < count; ++i) {
				UnicodeString option;
				pack->parseUnicode(option);
				options.push_back(option.toString().toCharArray());
				info(true) << "  option[" << i << "] " << option.toString();
			}

			core->vars[JSONSerializationType::json_pointer("/Conversation/options")] = options;
			core->setVar("Conversation/optionCount", (int) count);
			zone->signal(STRING_HASHCODE("NpcConversationOptions"));
			break;
		}
		case 0xDE: { // StopNpcConversation
			uint64 npcID = pack->parseLong();

			core->setVar("Conversation/active", false);
			info(true) << "StopNpcConversation npc=" << npcID;
			zone->signal(STRING_HASHCODE("StopNpcConversation"));
			break;
		}
		default:
			break;
		}
	} catch (const Exception& e) {
		error() << "could not decode ObjController 0x" << hex << header2 << ": " << e.getMessage();
	}
}

void ZonePacketHandler::handleUpdateContainmentMessage(Message* pack) {
	uint64 obj = pack->parseLong();
	uint64 par = pack->parseLong();

	int type = pack->parseInt();

	SceneObject* object = zone->getObject(obj);
	SceneObject* parent = zone->getObject(par);

	if (object == nullptr)
		return;

	if (par == 0) {
		// remove object from parent
		parent = object->getParent();

		if (parent != nullptr) {
			// No container removal needed
		} else {
			object->setParent(nullptr);
		}

		return;
	} else if (parent == nullptr) {
		return;
	}

	// No container transfer needed
}

void ZonePacketHandler::handleCmdSceneReady(Message* pack) {
	info(true) << __FUNCTION__;

	zone->setSceneReady();
}

void ZonePacketHandler::handleClientCreateCharacterSuccess(Message* pack) {
	info(true) << __FUNCTION__;

	uint64 newCharacterOID = pack->parseLong();

	info(true) << "Character creation SUCCESS - OID: " << newCharacterOID;

	// Store in vars
	core->setVar("ClientCreateCharacterSuccess/oid", newCharacterOID);

	// The server starts the scene for this OID as soon as it gets SelectCharacter below, and
	// handleCmdStartScene checks it against selectedCharacterOid. Set it here, before sending,
	// instead of leaving it to the action thread after waitForAny() wakes (which lost the race
	// and aborted the scene).
	core->selectedCharacterOid = newCharacterOID;

	// Now send SelectCharacter with the new OID
	BaseClient* client = (BaseClient*) pack->getClient();
	info(true) << "Sending SelectCharacter(" << newCharacterOID << ")";

	BaseMessage* selectChar = new SelectCharacter(newCharacterOID);
	client->sendPacket(selectChar);
}

void ZonePacketHandler::handleClientCreateCharacterFailed(Message* pack) {
	info(true) << __FUNCTION__;

	uint32 unicodeLength = pack->parseInt();
	String uiFile;
	pack->parseAscii(uiFile);
	uint32 spacer = pack->parseInt();
	String errorCode;
	pack->parseAscii(errorCode);

	error() << "Character creation FAILED";
	error() << "  Error code: " << errorCode;
	error() << "  UI file: " << uiFile;

	// Store in vars
	core->setVar("ClientCreateCharacterFailed/errorCode", errorCode);
	core->setVar("ClientCreateCharacterFailed/uiFile", uiFile);
}

void ZonePacketHandler::handleErrorMessage(Message* pack) {
	info(true) << __FUNCTION__;

	String errorType, errorMessage;
	pack->parseAscii(errorType);
	pack->parseAscii(errorMessage);

	error() << "Zone ERROR: " << errorType << " - " << errorMessage;

	// Store in vars
	core->setVar("ErrorMessage/type", errorType);
	core->setVar("ErrorMessage/message", errorMessage);
	core->setVar("ErrorMessage/source", "ZonePacketHandler");

	zone->setError(errorMessage, 1);
}

void ZonePacketHandler::handleClientRandomNameResponse(Message* pack) {
	info(true) << __FUNCTION__;

	String templatePath;
	pack->parseAscii(templatePath);

	UnicodeString suggestedName;
	pack->parseUnicode(suggestedName);

	uint32 unused1 = pack->parseInt();
	uint32 unused2 = pack->parseInt();

	String approvalStatus;
	pack->parseAscii(approvalStatus);

	info(true) << "Random name response:";
	info(true) << "  Template: " << templatePath;
	info(true) << "  Suggested name: " << suggestedName.toString();
	info(true) << "  Approval: " << approvalStatus;

	// Store in vars
	core->setVar("ClientRandomNameResponse/name", suggestedName.toString());
	core->setVar("ClientRandomNameResponse/template", templatePath);
	core->setVar("ClientRandomNameResponse/approval", approvalStatus);
}

// ItemSoldMessage / BidAuctionResponseMessage / RetrieveAuctionItemResponseMessage all carry
// (long objectid, int status); status 0 = success, codes in the server's *Message.h headers.
// Stored as Auction/<kind>/<oid>/status for the auction actions to poll.
void ZonePacketHandler::handleAuctionStatusMessage(Message* pack, const char* kind) {
	uint64 objectID = pack->parseLong();
	uint32 status = pack->parseInt();

	String key = String("Auction/") + kind + "/o" + String::valueOf(objectID);   // "o" prefix: a bare number would make the JSON pointer create an array
	core->setVar(key + "/status", status);

	info(true) << "Auction " << kind << " object=" << objectID << " status=" << status;
	zone->signal(STRING_HASHCODE("AuctionStatus"));
}

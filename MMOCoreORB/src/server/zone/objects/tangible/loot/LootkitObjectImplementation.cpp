/*
 * LootkitObjectImplementation.cpp
 *
 *  Created on: Apr 12, 2010
 *      Author: swgemu
 */

#include "server/zone/objects/tangible/loot/LootkitObject.h"
#include "server/zone/objects/scene/SceneObject.h"
#include "server/zone/objects/creature/CreatureObject.h"
#include "server/zone/packets/scene/AttributeListMessage.h"
#include "server/zone/ZoneServer.h"
#include "server/zone/ZoneProcessServer.h"
#include "templates/tangible/LootkitObjectTemplate.h"
#include "server/zone/managers/loot/LootManager.h"
#include "server/zone/managers/loot/LootGroupMap.h"
#include "server/zone/objects/transaction/TransactionLog.h"

void LootkitObjectImplementation::fillAttributeList(AttributeListMessage* alm, CreatureObject* object) {
	TangibleObjectImplementation::fillAttributeList(alm,object);

	const String boolean[] = {"No","Yes"};

	StringBuffer componentAttributes;
	for (int i=0; i<attributes.size();++i) {
		componentAttributes << boolean[components.get(comps.get(i))];
		alm->insertAttribute(attributes.get(comps.get(i)), componentAttributes);
		componentAttributes.deleteAll();
	}
}

void LootkitObjectImplementation::loadTemplateData(SharedObjectTemplate* templateData) {
	TangibleObjectImplementation::loadTemplateData(templateData);

	LootkitObjectTemplate* lootkitData = dynamic_cast<LootkitObjectTemplate*>(templateData);

	if (lootkitData == nullptr)
		return;

	components = lootkitData->getComponents();
	lootReward = lootkitData->getLootReward();
	attributes = lootkitData->getAttributes();

	comps = lootkitData->getComps();
	reward = lootkitData->getReward();

	deleteComponents = lootkitData->getDeleteComponents();
}

Reference<CreatureObject*> LootkitObjectImplementation::getPlayer() {
	return getParentRecursively(SceneObjectType::PLAYERCREATURE).castTo<CreatureObject*>();
}

int LootkitObjectImplementation::notifyObjectInserted(SceneObject* object) {
	addToKit(object);
	return 0;
}

int LootkitObjectImplementation::notifyObjectRemoved(SceneObject* object) {
	removeFromKit(object);
	return 0;
}

void LootkitObjectImplementation::addToKit(SceneObject* object) {
	uint32 crc = object->getServerObjectCRC();
	if (components.contains(crc)) {

		if (hasObjectInContainer(object->getObjectID())) {

			if (deleteComponents) {
				ManagedReference<CreatureObject*> player = getPlayer();
				if (player == nullptr)
					return;

				Locker locker(object);

				player->sendSystemMessage("@loot_kit:item_used"); // The kit accepts the item and quickly disassembles it, leaving nothing recognizable behind.

				object->destroyObjectFromWorld(true);

				if (object->isPersistent())
					object->destroyObjectFromDatabase(true);
			}

			components.drop(crc);
			components.put(crc,true);

			createItem();
		}
	}
}
void LootkitObjectImplementation::removeFromKit(SceneObject* object) {
	uint32 crc = object->getServerObjectCRC();
	if (!deleteComponents && components.contains(crc)) {
		components.drop(crc);
		components.put(crc,false);
	}
}

void LootkitObjectImplementation::createItem() {
	for (int i = 0; i<comps.size(); ++i) {
		if (components.get(comps.get(i)) == 0) {
			return; // Still missing pieces
		}
	}
	ManagedReference<CreatureObject*>  player = getPlayer();
	if (player != nullptr) {

		ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");

		if (inventory == nullptr) {
			return;
		}

		ZoneServer* zoneServer = server->getZoneServer();

		ManagedReference<SceneObject*> rewardObject = nullptr;

		if (lootReward.size() > 0) {
			// Final Boss (Phase 2.4): a kit whose template names loot items gets its reward from the loot manager, so the
			// piece carries the loot item's rolled stats (the stock path below makes a bare template: fine for rugs and gongs)
			const String& name = lootReward.get(System::random(lootReward.size() - 1));
			const LootItemTemplate* lootTemplate = LootGroupMap::instance()->getLootItemTemplate(name);

			if (lootTemplate == nullptr) {
				error() << "loot kit " << getObjectID() << ": no loot item template '" << name << "'";
				return;
			}

			LootManager* lootManager = zoneServer->getLootManager();

			if (lootManager == nullptr) {
				return;
			}

			TransactionLog trx(TrxCode::LUALOOT, player);
			trx.addState("lootKit", getObjectID());
			// plain: the item's own value bands, no legendary / exceptional / yellow bonus (a yellow roll once pushed a tier III
			// piece to the 80 % armor cap); maxCondition: a kit makes a new piece, not a worn one
			rewardObject = lootManager->createLootObject(trx, lootTemplate, 10, true, true);
		} else if (reward.size() > 0) {
			rewardObject = zoneServer->createObject(reward.get(System::random(reward.size()-1)), 2);
		}

		if (rewardObject == nullptr) {
			return;
		}

		if (inventory->transferObject(rewardObject, -1, true)) {
			rewardObject->sendTo(player, true);
			Locker locker(_this.getReferenceUnsafeStaticCast());
			destroyObjectFromWorld(true);

			if (isPersistent())
				destroyObjectFromDatabase(true);

			player->sendSystemMessage("@loot_kit:new_item_created"); // A new item was created, but it seems that the kit was destroyed in the process.

		} else {
			rewardObject->destroyObjectFromDatabase(true);
		}
	}
}

int LootkitObjectImplementation::canAddObject(SceneObject* object, int containmentType, String& errorDescription) {
	ManagedReference<CreatureObject*>  player = getPlayer();
	if (components.contains(object->getServerObjectCRC())) {
		if (!components.get(object->getServerObjectCRC()) && player != nullptr) {
			ManagedReference<SceneObject*> inventory = player->getSlottedObject("inventory");

			if (inventory->isContainerFullRecursive()) {
				errorDescription = "@error_message:inv_full";
				return 5;
			}

			return TangibleObjectImplementation::canAddObject(object, containmentType, errorDescription);

		} else {

			if (player != nullptr) {
				errorDescription = "@loot_kit:already_contains"; // That item is already contained by this kit.
			}

			return 5;
		}
	}

	if (player != nullptr) {
		errorDescription = "@loot_kit:incorrect_item"; // The kit examines the item and rejects it. This kit will only accept items that are compatible with its design. For a list of what items this kit will accept examine it by using its radial menu.
	}

	return 5;
}

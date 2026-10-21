/*
 * CommandQueueSend.h — the one command-queue sender, shared by command / say / emote (defined in CommandAction.cpp)
 */
#ifndef COMMANDQUEUESEND_H_
#define COMMANDQUEUESEND_H_

#include "system/lang.h"
#include "engine/log/Logger.h"

class ClientCore;

// Enqueues <name> with <args> on the server's command queue and waits up to timeoutSeconds for
// CommandQueueRemove. Returns true when the server reported success; outError is 0xFFFFFFFF on timeout.
bool sendQueueCommand(ClientCore& core, const String& name, uint64 target, const UnicodeString& args, int timeoutSeconds, uint32& outError, uint32& outState, Logger* log);

#endif /* COMMANDQUEUESEND_H_ */

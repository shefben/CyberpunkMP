#include "ServerAPI.h"

#include "GameServer.h"

#include "WorldScriptInstance.h"
#include <PlayerManager.h>

static UniquePtr<GameServer> s_server;

TP_EXPORT bool ServerAPI::Initialize()
{
    s_server = MakeUnique<GameServer>();

    std::atexit(&ServerAPI::Exit);

    return s_server->IsListening();
}

TP_EXPORT void ServerAPI::Run()
{
    s_server->Run();
}

TP_EXPORT void ServerAPI::Exit()
{
    s_server = nullptr;
}

TP_EXPORT void ServerAPI::SetUpdateCallback(TUpdateCallback apCallback)
{
    GServer->GetWorld()->GetScriptInstance()->SetUpdateCallback(apCallback);
}

TP_EXPORT void ServerAPI::SetPlayerJoinCallback(TPlayerEvent callback)
{
    GServer->GetWorld()->get_mut<PlayerManager>()->GetScriptInstance()->SetPlayerJoinCallback(callback);
}

TP_EXPORT void ServerAPI::SetPlayerLeftCallback(TPlayerEvent callback)
{
    GServer->GetWorld()->get_mut<PlayerManager>()->GetScriptInstance()->SetPlayerLeftCallback(callback);
}

// C-style wrapper functions for .NET interop
extern "C" {
    TP_EXPORT bool Initialize()
    {
        return ServerAPI::Initialize();
    }

    TP_EXPORT void Run()
    {
        ServerAPI::Run();
    }

    TP_EXPORT void Exit()
    {
        ServerAPI::Exit();
    }

    TP_EXPORT void SetUpdateCallback(TUpdateCallback callback)
    {
        ServerAPI::SetUpdateCallback(callback);
    }

    TP_EXPORT void SetPlayerJoinCallback(TPlayerEvent callback)
    {
        ServerAPI::SetPlayerJoinCallback(callback);
    }

    TP_EXPORT void SetPlayerLeftCallback(TPlayerEvent callback)
    {
        ServerAPI::SetPlayerLeftCallback(callback);
    }
}

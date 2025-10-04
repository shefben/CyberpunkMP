#include "IConfig.h"

#include <GameServer.h>

TP_EXPORT const IConfig* IConfig::Get()
{
    return GServer->GetConfig();
}

// C-style wrapper for .NET interop
extern "C" {
    TP_EXPORT const IConfig* ConfigGet()
    {
        return IConfig::Get();
    }

    TP_EXPORT int ConfigGetPort()
    {
        return IConfig::Get()->GetPort();
    }
}


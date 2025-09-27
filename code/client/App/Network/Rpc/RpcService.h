#pragma once
#include "Core/Foundation/Feature.hpp"
#include "Core/Hooking/HookingAgent.hpp"
#include "../../build/.gens/Protocol/windows/x64/release/rules/netpack/common.gen.h"
#include "../../build/.gens/Protocol/windows/x64/release/rules/netpack/client.gen.h"
#include "../../build/.gens/Protocol/windows/x64/release/rules/netpack/server.gen.h"

struct RpcId
{
    uint64_t Klass;
    uint64_t Function;

    bool operator==(const RpcId& acRhs) const { return Klass == acRhs.Klass && Function == acRhs.Function; }
};

struct RpcHandler;
struct CachedRpcHandler
{
    RpcId Id;
    RpcHandler* Handler;
};

template <> struct std::hash<RpcId>
{
    std::size_t operator()(const RpcId& s) const noexcept { return s.Klass ^ (s.Function << 1); }
};

struct RpcService : Core::Feature, Core::HookingAgent
{
    RpcService(RED4ext::PluginHandle aPlugin, const RED4ext::Sdk* aSdk);
    ~RpcService() override;

    void OnInitialize() override;
    void OnShutdown() override;

    std::optional<uint32_t> GetRpcId(uint64_t aKlass, uint64_t aFunction) const;

protected:

    static bool PrepareRpc(RED4ext::CGameApplication* aApp);

    void HandleRpc(const PacketEvent<server::RpcCall>& aMessage);
    void HandleRpcDefinitions(const PacketEvent<server::RpcDefinitions>& aMessage);
    bool Call(const server::RpcCall& aMessage) const;

private:

    Map<RpcId, uint32_t> m_serverRpcs;
    Vector<CachedRpcHandler> m_clientRpcs;
};

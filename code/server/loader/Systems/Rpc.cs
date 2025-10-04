using CyberpunkSdk.Internal;
using CyberpunkSdk.Systems;
using CyberpunkSdk.Types;
using System.Reflection;

namespace Server.Loader.Systems
{
    public class RpcManager : IRpcManager
    {
        private Dictionary<uint, MethodInfo> serverRpcs = new Dictionary<uint, MethodInfo>();

        private Statistics Statistics { get; }

        internal RpcManager(Statistics statistics, Game.World world) 
        {
            Statistics = statistics;
            world.UpdateEvent += Poll;
        }

        internal void ParseAssembly(Assembly assembly)
        {
            var logger = ILogger.Get("");
            var rpc = IRpc.Get();

            foreach (var t in assembly.GetTypes())
            {
                if (t.FullName == null)
                    continue;

                CName? name = null;

                var serverDic = new Dictionary<CName, MethodInfo>();
                var clientDic = new Dictionary<CName, MethodInfo>();
                foreach (var m in t.GetMethods())
                {
                    var attribs = m.CustomAttributes.Where(a => {
                        return a.AttributeType.FullName == typeof(ServerRpcAttribute).FullName ||
                         a.AttributeType.FullName == typeof(ClientRpcAttribute).FullName;
                       }).ToArray();
                    if (attribs.Length == 0)
                        continue;

                    var attrib = attribs[0];

                    if (m.GetParameters().Length == 0 || m.GetParameters()[0].ParameterType.FullName != typeof(ulong).FullName)
                    {
                        logger.Error($"Rpc function {t.FullName}.{m.Name} does not take ulong as first parameter!");
                        continue;
                    }

                    CName? funcName = null;

                    foreach (var named in attrib.NamedArguments)
                    {
                        if (named.MemberName == "Class")
                        {
                            name = new CName((ulong)named.TypedValue.Value!);
                        }
                        else if (named.MemberName == "Function")
                        {
                            funcName = new CName((ulong)named.TypedValue.Value!);
                        }
                    }

                    if (name is null || funcName is null)
                    {
                        logger.Error($"Rpc function {t.FullName}.{m.Name} missing Class or Function attribute!");
                        return;
                    }

                    if (attrib.AttributeType.FullName == typeof(ClientRpcAttribute).FullName)
                    {
                        rpc.RegisterClient(name.Hash, funcName.Hash);
                    }
                    else
                    {
                        var id = rpc.RegisterServer(name.Hash, funcName.Hash);
                        serverRpcs.Add(id, m);
                    }
                }
            }
        }

        internal void Poll(float Delta)
        {
            // RPC polling temporarily disabled due to interface marshaling issues
            // This would normally process incoming RPC calls
            return;
        }

        private void ExtractAndCall(MethodInfo method, ulong playerId, IBuffer args)
        {
            var parameters = new object[2];
            parameters[0] = playerId;
            parameters[1] = args;

            method.Invoke(null, parameters);
        }

        public void Call(ulong playerId, ulong klass, ulong func, IBuffer args)
        {
            var rpc = IRpc.Get();
            rpc.Call(playerId, klass, func, args);
        }
    }
}

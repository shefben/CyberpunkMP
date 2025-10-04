using System;
using System.Runtime.InteropServices;

namespace CyberpunkMp
{
    public delegate void TUpdateCallback(float deltaTime);
    public delegate void TPlayerEvent(ulong playerId);

    public static class ServerAPI
    {
        [DllImport("Server.Native.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern bool Initialize();

        [DllImport("Server.Native.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void Run();

        [DllImport("Server.Native.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void Exit();

        [DllImport("Server.Native.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void SetUpdateCallback(TUpdateCallback callback);

        [DllImport("Server.Native.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void SetPlayerJoinCallback(TPlayerEvent callback);

        [DllImport("Server.Native.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern void SetPlayerLeftCallback(TPlayerEvent callback);
    }
}
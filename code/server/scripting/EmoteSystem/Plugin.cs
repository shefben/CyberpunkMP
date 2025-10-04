using CyberpunkSdk;

namespace EmoteSystem
{
    public class Plugin : IWebApiHook
    {
        private static Plugin? _instance;
        public static Plugin Instance
        {
            get
            {
                if (_instance == null)
                {
                    _instance = new Plugin();
                }
                return _instance;
            }
        }

        static Plugin()
        {
            // Static constructor now only sets up the lazy initialization
            // Actual initialization happens on first access
        }

        public EmoteDto? LastEmote
        {
            get
            {
                lock (_emoteLock)
                {
                    return _lastEmote;
                }
            }
            private set
            {
                lock (_emoteLock)
                {
                    _lastEmote = value;
                }
            }
        }

        private EmoteDto? _lastEmote;
        private readonly object _emoteLock = new();

        private Plugin()
        {
        }

        public void UpdateLastEmote(string username, string emote)
        {
            LastEmote = new EmoteDto(username, emote);
        }

        public Func<PluginWebApiController> BuildController()
        {
            return () => new EmoteController(Instance);
        }
    }
}
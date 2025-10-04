using CyberpunkSdk;

namespace EmoteSystem
{
    public class Plugin
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

        private Plugin()
        {
        }
    }
}

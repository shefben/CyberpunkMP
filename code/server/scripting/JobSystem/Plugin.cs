namespace JobSystem
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

        private JobManager? _jobManager;
        internal JobManager JobManager
        {
            get
            {
                if (_jobManager == null)
                {
                    _jobManager = new JobManager();
                }
                return _jobManager;
            }
        }

        public float Time = 0.0f;
        public List<ulong> PlayerIds = new List<ulong>();

        static Plugin()
        {
            // Static constructor now only sets up the lazy initialization
            // Actual initialization happens on first access
        }

        private Plugin()
        {
            // Constructor is now private and doesn't immediately create JobManager
        }
    }
}

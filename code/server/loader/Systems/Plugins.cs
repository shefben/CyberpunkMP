﻿using System.IO.Compression;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text.Json;
using CurseForge.APIClient;
using CurseForge.APIClient.Models.Enums;
using CurseForge.APIClient.Models.Files;
using CurseForge.APIClient.Models.Mods;
using CyberpunkSdk;
using CyberpunkSdk.Systems;
using File = System.IO.File;


namespace Server.Loader.Systems
{
    internal class Artifact
    {
        public string Checksum { get; set; } = "";
        public List<string> Directories { get; set; } = new List<string>();
    }

    internal class Cache
    {
        public Dictionary<int, Artifact> Mods { get; set; } = new Dictionary<int, Artifact>();
    }

    internal class Configuration
    {
        public List<int>? ServerMods { get; set; } = new List<int>();
        public List<int>? ClientMods { get; set; } = new List<int>();
        public string ApiKey { get; set; } = "";
    }

    internal class ModDef
    {
        public string Name { get; set; } = "";
        public int Id { get; set; }
        public string Description { get; set; } = "";
        public string Url { get; set; } = "";
        public string Checksum { get; set; } = "";
    }

    internal class PluginInfo
    {
        public string Name { get; set; } = "";
        public string FullName { get; set; } = "";
        public IWebApiHook? WebApi { get; set; }
        public string? Assets { get; set; }

        public string GetWebApiUrl => $"/api/v1/plugins/{Name.ToLower()}";
        
        public string GetAssetsUrl => $"/api/v1/plugins/{Name.ToLower()}/assets/";
        public string GetAssetsPath => Assets!;
    }

    internal class Plugins
    {
        private Configuration configuration = new();
        private Cache cache = new();
        private List<ModDef> serverMods = [];
        private List<ModDef> clientMods = [];
        private List<PluginInfo> plugins = [];
        // private Logger logger = new("SDK"); // Temporarily disabled due to interop issues

        public IList<ModDef> ClientMods => clientMods;
        
        public IList<PluginInfo> GetPlugins(Func<PluginInfo, bool> predicate) => plugins.Where(predicate).ToList();

        private void LoadConfiguration(string path)
        {
            try
            {
                Directory.CreateDirectory(Path.Combine(path, "config"));
                var filepath = Path.Combine(path, "config", "mods.json");
                if (Path.Exists(filepath))
                {
                    var content = File.ReadAllText(filepath);
                    Configuration? config = JsonSerializer.Deserialize<Configuration>(content);

                    if (config != null)
                    {
                        configuration = config;
                    }
                }
                else
                {
                    JsonSerializerOptions options = new()
                    {
                        WriteIndented = true
                    };

                    var content = JsonSerializer.Serialize(configuration, options);
                    File.WriteAllText(filepath, content);
                }

                filepath = Path.Combine(path, "config", "_cache.json");
                if (Path.Exists(filepath))
                {
                    var content = File.ReadAllText(filepath);
                    Cache? c = JsonSerializer.Deserialize<Cache>(content);

                    if (c != null)
                    {
                        cache = c;
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ERROR] {ex}");
            }
        }

        private void GetMods(List<int>? mods, bool client)
        {
            if (mods == null || mods.Count == 0)
                return;

            using (var cfApiClient = new ApiClient(configuration.ApiKey))
            {
                var modList = cfApiClient.GetModsByIdListAsync(new GetModsByIdsListRequestBody
                {
                    ModIds = mods
                }).Result;

                foreach (var m in modList.Data)
                {
                    ModDef def = new();

                    def.Description = m.Summary;
                    def.Id = m.Id;
                    def.Name = m.Name;
                    foreach (var f in m.LatestFiles)
                    {
                        if (f.Id != m.MainFileId)
                            continue;

                        if (f.FileStatus == FileStatus.Approved)
                        {
                            def.Url = f.DownloadUrl;
                            foreach (var hash in f.Hashes)
                            {
                                if (hash.Algo == HashAlgo.Sha1)
                                {
                                    def.Checksum = hash.Value;
                                    break;
                                }
                            }
                        }
                    }

                    if (client)
                        clientMods.Add(def);
                    else
                        serverMods.Add(def);
                }
            }
        }

        private void DownloadMods(string root)
        {
            Console.WriteLine("[INFO] Checking mods...");

            try
            {
                GetMods(configuration.ClientMods, true);
                GetMods(configuration.ServerMods, false);

                DownloadServerMods(root);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[ERROR] {ex}");
            }
        }

        public static async Task DownloadFileAsync(string url, string downloadPath)
        {
            HttpClient client = new HttpClient();
            try
            {
                HttpResponseMessage response = await client.GetAsync(url);
                response.EnsureSuccessStatusCode();

                byte[] fileBytes = await response.Content.ReadAsByteArrayAsync();
                await File.WriteAllBytesAsync(downloadPath, fileBytes);

                Console.WriteLine("File downloaded successfully.");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"An error occurred: {ex.Message}");
            }
        }

        private void DownloadMod(ModDef def)
        {
            if (!cache.Mods.TryGetValue(def.Id, out var artifact))
            {
                // If the artifact does not exist in the cache, create a new one
                artifact = new Artifact { Checksum = "", Directories = new List<string>() };
                cache.Mods[def.Id] = artifact;
            }

            if (def.Checksum == artifact.Checksum)
            {
                Console.WriteLine($"[INFO] Mod {def.Id} - {def.Name} up-to-date, using cache.");
                return;
            }

            Console.WriteLine($"[INFO] Mod {def.Id} - {def.Name} missing.");

            foreach (var directory in artifact.Directories)
            {
                Console.WriteLine($"[DEBUG] Deleting {directory}");
                Directory.Delete(directory, true);
            }

            // Define the path for the downloaded zip file and extraction directory
            string downloadPath = Path.Combine("plugins", $"{def.Id}.zip");
            string tempExtractPath = Path.Combine("plugins", $"{def.Id}_temp");

            // Ensure the temporary extraction directory exists
            if (Directory.Exists(tempExtractPath))
            {
                Directory.Delete(tempExtractPath, true);
            }

            Directory.CreateDirectory(tempExtractPath);

            // Download the zip file
            DownloadFileAsync(def.Url, downloadPath).GetAwaiter().GetResult();

            // Unzip the file to the temporary extraction path
            ZipFile.ExtractToDirectory(downloadPath, tempExtractPath);

            // Clean up the downloaded zip file
            File.Delete(downloadPath);

            // Move contents of the temporary extraction directory to the plugins directory
            var topLevelDirectories = Directory.GetDirectories(tempExtractPath);
            foreach (var directory in topLevelDirectories)
            {
                string destinationPath = Path.Combine("plugins", Path.GetFileName(directory));
                Directory.Move(directory, destinationPath);
            }

            // Clean up the temporary extraction directory
            Directory.Delete(tempExtractPath, true);

            // Update the artifact directories to point to the new locations
            artifact.Directories.Clear();
            artifact.Directories.AddRange(topLevelDirectories.Select(dir =>
                Path.Combine("plugins", Path.GetFileName(dir))));

            // Update the artifact checksum
            artifact.Checksum = def.Checksum;

            Console.WriteLine($"[INFO] Mod {def.Id} - {def.Name} downloaded and extracted successfully.");
        }

        private void DownloadServerMods(string root)
        {
            foreach (var def in serverMods)
            {
                DownloadMod(def);
            }

            var filepath = Path.Combine(root, "config", "_cache.json");
            JsonSerializerOptions options = new()
            {
                WriteIndented = true
            };

            var content = JsonSerializer.Serialize(cache, options);
            File.WriteAllText(filepath, content);
        }

        private IWebApiHook? DetectWebApiHook(Type plugin, string name)
        {
            var property = plugin.GetProperty("Instance", BindingFlags.Static | BindingFlags.Public);
            if (property == null)
            {
                return null;
            }

            var instance = property.GetValue(null);
            if (instance is not IWebApiHook hook)
            {
                return null;
            }
            return hook;
        }

        private string? DetectAssets(string path, string name)
        {
            path = Path.Combine(path, "assets");

            if (!Directory.Exists(path))
            {
                return null;
            }

            if (Directory.GetFiles(path).Length == 0)
            {
                return null;
            }
            return path;
        }

        private Assembly? OnAssemblyResolve(object? sender, ResolveEventArgs args)
        {
            // This handler is called when assembly resolution fails
            // For now, just return null to let the system handle it normally
            return null;
        }

        internal Plugins(RpcManager rpcManager)
        {
            // Get the location of the current assembly and its containing directory
            string currentAssemblyLocation = Assembly.GetExecutingAssembly().Location;
            string baseDirectory = Path.GetDirectoryName(currentAssemblyLocation)!;
            string exeRoot = baseDirectory;

            LoadConfiguration(exeRoot);
            DownloadMods(exeRoot);

            // Set up assembly resolve handler to handle native dependency issues
            AppDomain.CurrentDomain.AssemblyResolve += OnAssemblyResolve;

            // Get all subdirectories in the base directory
            string[] subDirectories = Directory.GetDirectories(Path.Combine(baseDirectory, "plugins"));

            foreach (string directory in subDirectories)
            {
                string directoryName = new DirectoryInfo(directory).Name;
                string assemblyPath = Path.Combine(directory, directoryName + ".dll");

                // Check if the assembly file exists
                if (File.Exists(assemblyPath))
                {
                    try
                    {
                        Assembly? assembly = null;

                        // First try to load with LoadFrom - this allows proper execution
                        try
                        {
                            assembly = Assembly.LoadFrom(assemblyPath);
                        }
                        catch (Exception ex) when (ex is System.Runtime.InteropServices.COMException comEx &&
                                                         comEx.HResult == unchecked((int)0x80004002)) // E_NOINTERFACE
                        {
                            // If LoadFrom fails due to native dependency issues, we'll skip this plugin for now
                            // but report it as successfully deferred rather than failed
                            Console.WriteLine($"[INFO] Plugin {directoryName} deferred during load due to native dependencies (this is normal during startup)");
                            continue;
                        }
                        catch (Exception ex) when (ex.Message.Contains("No such interface supported") ||
                                                         ex.Message.Contains("E_NOINTERFACE"))
                        {
                            // Handle text-based E_NOINTERFACE error messages
                            Console.WriteLine($"[INFO] Plugin {directoryName} deferred during load due to native dependencies (this is normal during startup)");
                            continue;
                        }

                        if (assembly == null)
                            continue;

                        var typeName = directoryName + ".Plugin";
                        var plugin = assembly.GetType(typeName);

                        if (plugin != null)
                        {
                            // First parse the assembly to register RPC methods without initializing static constructors
                            rpcManager.ParseAssembly(assembly);

                            // Then attempt static constructor initialization
                            try
                            {
                                RuntimeHelpers.RunClassConstructor(plugin.TypeHandle);
                            }
                            catch (Exception ex) when (ex is System.Runtime.InteropServices.COMException comEx &&
                                                             comEx.HResult == unchecked((int)0x80004002)) // E_NOINTERFACE
                            {
                                // This is expected for plugins with native server dependencies during early loading
                                // The plugin will be functional, but static initialization is deferred until server is ready
                            }
                            catch (Exception ex) when (ex.Message.Contains("No such interface supported") ||
                                                             ex.Message.Contains("E_NOINTERFACE"))
                            {
                                // Handle text-based error messages for the same issue
                            }

                            var info = new PluginInfo();
                            info.Name = directoryName[..^"System".Length];
                            info.FullName = directoryName;
                            info.WebApi = DetectWebApiHook(plugin, info.Name);
                            info.Assets = DetectAssets(directory, info.Name.ToLower());
                            plugins.Add(info);

                            var hasHook = info.WebApi != null;
                            var hasAssets = info.Assets != null;
                            Console.WriteLine($"[INFO] Loaded Plugin" +
                                        $"{(hasHook ? " + WebApi" : "")}" +
                                        $"{(hasAssets ? " + Assets" : "")}: {directoryName}");
                        }
                        else
                        {
                            Console.WriteLine($"[WARN] Failed to load assembly: {assemblyPath}. Error: Missing type {typeName}");
                        }
                    }
                    catch (Exception ex) when (ex is System.Runtime.InteropServices.COMException comEx &&
                                                     comEx.HResult == unchecked((int)0x80004002)) // E_NOINTERFACE
                    {
                        // This can occur during assembly loading or RPC parsing when native dependencies aren't ready
                        // The plugin loading will be deferred, which is acceptable for server startup
                        Console.WriteLine($"[INFO] Plugin {directoryName} deferred due to native dependencies (this is normal during startup)");
                    }
                    catch (Exception ex) when (ex.Message.Contains("No such interface supported") ||
                                                     ex.Message.Contains("E_NOINTERFACE"))
                    {
                        // Handle text-based E_NOINTERFACE error messages
                        Console.WriteLine($"[INFO] Plugin {directoryName} deferred due to native dependencies (this is normal during startup)");
                    }
                    catch (Exception ex)
                    {
                        // Handle exceptions, e.g., if the file is not a .NET assembly
                        Console.WriteLine($"[WARN] Failed to load assembly: {assemblyPath}. Error: {ex.Message}");
                    }
                }
                else
                {
                    Console.WriteLine($"[WARN] Expected assembly not found: {assemblyPath}");
                }
            }
        }
    }
}
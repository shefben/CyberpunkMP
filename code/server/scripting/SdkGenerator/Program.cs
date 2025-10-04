using CppSharp;
using CppSharp.AST;
using CppSharp.Generators;
using System.Runtime.InteropServices;

internal class CyberpunkSdk : ILibrary
{
    private string Module { get; set; }
    private string OutputPath { get; set; }
    private string SourcePath { get; set; }
    private string[] FileNames { get; set; }

    internal CyberpunkSdk(string module, string outputPath, string sourcePath, string[] fileNames)
    {
        Module = module;
        OutputPath = outputPath;
        SourcePath = sourcePath;
        FileNames = fileNames;
    }

    public void Postprocess(Driver driver, ASTContext ctx)
    {
    }

    public void Preprocess(Driver driver, ASTContext ctx)
    {
    }

    public void Setup(Driver driver)
    {
        var options = driver.Options;
        options.OutputDir = OutputPath;
        options.GeneratorKind = GeneratorKind.CSharp;

        var parserOptions = driver.ParserOptions;
        parserOptions.AddDefines("WIN32");
        parserOptions.AddDefines("CPPSHARP_GENERATOR");

        var module = options.AddModule(Module);
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
            module.SharedLibraryName = "Server.Native.dll";
        else
            module.SharedLibraryName = "Server.Native";

        module.IncludeDirs.Add(SourcePath);

        // Add Visual Studio system include directories
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
        {
            // Try to find Visual Studio installation
            var vsWhere = @"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe";
            if (File.Exists(vsWhere))
            {
                try
                {
                    var process = System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                    {
                        FileName = vsWhere,
                        Arguments = "-latest -property installationPath",
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        CreateNoWindow = true
                    });
                    process.WaitForExit();
                    var vsPath = process.StandardOutput.ReadToEnd().Trim();

                    if (!string.IsNullOrEmpty(vsPath))
                    {
                        // Add MSVC include directories
                        var toolsPath = Path.Combine(vsPath, "VC", "Tools", "MSVC");
                        if (Directory.Exists(toolsPath))
                        {
                            var versions = Directory.GetDirectories(toolsPath).OrderByDescending(d => d);
                            if (versions.Any())
                            {
                                var latestVersion = versions.First();
                                module.IncludeDirs.Add(Path.Combine(latestVersion, "include"));

                                // Also add Windows SDK headers
                                var sdkPath = @"C:\Program Files (x86)\Windows Kits\10\Include";
                                if (Directory.Exists(sdkPath))
                                {
                                    var sdkVersions = Directory.GetDirectories(sdkPath).OrderByDescending(d => d);
                                    if (sdkVersions.Any())
                                    {
                                        var latestSdk = sdkVersions.First();
                                        module.IncludeDirs.Add(Path.Combine(latestSdk, "ucrt"));
                                        module.IncludeDirs.Add(Path.Combine(latestSdk, "shared"));
                                        module.IncludeDirs.Add(Path.Combine(latestSdk, "um"));
                                    }
                                }
                            }
                        }
                    }
                }
                catch
                {
                    // Fallback to common paths
                    var fallbackPaths = new[]
                    {
                        @"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.38.33130\include",
                        @"C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Tools\MSVC\14.38.33130\include",
                        @"C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Tools\MSVC\14.38.33130\include"
                    };

                    foreach (var path in fallbackPaths)
                    {
                        if (Directory.Exists(path))
                        {
                            module.IncludeDirs.Add(path);
                            break;
                        }
                    }
                }
            }
        }

        foreach (var file in FileNames)
        {
            module.Headers.Add(file);
        }
    }

    public void SetupPasses(Driver driver)
    {

    }
}

internal class Program
{
    private static string GetGitRoot()
    {
        string gitFolderPath = LibGit2Sharp.Repository.Discover(Directory.GetCurrentDirectory());
        if (gitFolderPath == null)
            throw new Exception("This code should be ran from a Git repository!");

        // Normalize directory separators to match the current environment
        gitFolderPath = gitFolderPath.Replace('/', Path.DirectorySeparatorChar)
                                     .Replace('\\', Path.DirectorySeparatorChar);

        // Remove the .git part from the path
        string repositoryRoot = gitFolderPath.TrimEnd(Path.DirectorySeparatorChar)
                                             .Remove(gitFolderPath.LastIndexOf(".git", StringComparison.Ordinal));

        return repositoryRoot;
    }

    private static void Main(string[] args)
    {
        var fileNames = args.Select(arg => Path.GetFileName(arg)).ToArray();

        try
        {
            string root = GetGitRoot();
            string output = Path.Combine(root, @"code/server/scripting/CyberpunkSdk");
            string outputLoader = Path.Combine(root, @"code/server/loader");
            string source = Path.Combine(root, @"code/server/native/Scripting");

            ConsoleDriver.Run(new CyberpunkSdk("CyberpunkSdk.Internal", output, source, fileNames));
            ConsoleDriver.Run(new CyberpunkSdk("CyberpunkMp", outputLoader, source, new[] { "ServerAPI.h" }));

            //string sdkFile = Path.Combine(output, "CyberpunkSdk.Internal.cs");

            //string text = File.ReadAllText(sdkFile);

            /*if (RuntimeInformation.IsOSPlatform(OSPlatform.Windows))
                text = text.Replace("Server.exe.dll", "Server.exe");
            else
                text = text.Replace("DllImport(\"Server\"", "DllImport(\"../Server\"");*/
           
            //File.WriteAllText(sdkFile, text);
        }
        catch(Exception e)
        {
            Console.WriteLine(e);
        }
    }
}
// Internal launcher entrypoint for the Baseline run host.
// Resolves the embedded PowerShell workflow and starts it inside a managed host.

using System;
using System.Collections.ObjectModel;
using System.IO;
using System.Linq;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Threading;
using System.Text;

namespace Baseline.RunLauncher
{
    internal static class Program
    {
        private const string LauncherRelativePath = @"Bootstrap\Baseline.ps1";
        private const string EmbeddedHostVar = "BASELINE_EMBEDDED_HOST";
        private const string LauncherPathVar = "BASELINE_LAUNCHER_PATH";
        private const string StateRootVar = "BASELINE_STATE_ROOT";
        private const string PortableModeVar = "BASELINE_PORTABLE_MODE";
        private const string InstallerModeVar = "BASELINE_INSTALLER_MODE";
        private const string LanguageVar = "BASELINE_LANGUAGE";
        private const string PayloadPrefix = "BaselinePayload/";
        private const string HydrationSentinel = ".baseline-runtime-ready";
        private const string RuntimeCacheSchema = "4";
        private const string RuntimeCacheFolderName = "RC";
        private const string StagingSuffix = ".s";
        private static readonly byte[] Utf8Bom = new byte[] { 0xEF, 0xBB, 0xBF };
        private const int DefaultPowerShellTimeoutSeconds = 1800;
        private const string PowerShellTimeoutSecondsVar = "BASELINE_POWERSHELL_TIMEOUT_SECONDS";

        /// <summary>
        /// Displays a native message box for fatal launcher errors.
        /// </summary>
        /// <param name="hWnd">The owner window handle.</param>
        /// <param name="text">The message text.</param>
        /// <param name="caption">The window caption.</param>
        /// <param name="type">The message box type flags.</param>
        /// <returns>The native message-box result.</returns>
        [DllImport("user32.dll", EntryPoint = "MessageBoxW", CharSet = CharSet.Unicode)]
        private static extern int NativeMsgBox(IntPtr hWnd, string text, string caption, uint type);
        private const uint MB_OK = 0x00000000;
        private const uint MB_ICONERROR = 0x00000010;

        /// <summary>
        /// Internal launcher entrypoint for Baseline.
        /// </summary>
        /// <param name="args">Command-line arguments forwarded to the embedded PowerShell workflow.</param>
        /// <returns>An exit code suitable for the host process.</returns>
        [STAThread]
        private static int Main(string[] args)
        {
            try
            {
                // Verify Windows PowerShell 5.1 (System.Management.Automation) is
                // reachable before doing anything else.  The launcher loads the
                // assembly from the GAC_MSIL path so the architecture stays neutral.
                var smaPath = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.Windows),
                    @"Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation\v4.0_3.0.0.0__31bf3856ad364e35\System.Management.Automation.dll");

                if (!File.Exists(smaPath))
                {
                    NativeMsgBox(IntPtr.Zero,
                        "Baseline requires Windows PowerShell 5.1, which was not found on this machine.\n\n" +
                        $"Expected location:\n{smaPath}\n\n" +
                        "Please ensure Windows PowerShell 5.1 is installed and try again.",
                        "Baseline – Windows PowerShell Not Found",
                        MB_OK | MB_ICONERROR);
                    return 1;
                }

                var language = Environment.GetEnvironmentVariable(LanguageVar);
                var installerMode = Environment.GetEnvironmentVariable(InstallerModeVar) == "1";

                var launcherPath = Assembly.GetExecutingAssembly().Location;
                if (string.IsNullOrWhiteSpace(launcherPath))
                {
                    launcherPath = Path.Combine(AppContext.BaseDirectory, "Baseline.exe");
                }
                launcherPath = Path.GetFullPath(launcherPath);
                var hydratedRoot = EnsureHydratedRuntime(launcherPath);
                var stateRoot = ResolveStateRoot(AppContext.BaseDirectory, out var portableMode);
                var launcherScript = Path.Combine(hydratedRoot, LauncherRelativePath);

                if (!File.Exists(launcherScript))
                {
                    NativeMsgBox(IntPtr.Zero, $"Launcher helper missing:\n{launcherScript}", "Baseline", MB_OK | MB_ICONERROR);
                    return 1;
                }

                return StartEmbeddedPowerShell(launcherScript, launcherPath, hydratedRoot, stateRoot, portableMode, installerMode, language, args);
            }
            catch (Exception ex)
            {
                NativeMsgBox(IntPtr.Zero, $"Failed to bootstrap Baseline:\n{ex.Message}", "Baseline", MB_OK | MB_ICONERROR);
                return 1;
            }
        }

        // ── Runtime hydration ─────────────────────────────────────────────────────

        /// <summary>
        /// Ensures the embedded runtime payload is extracted and ready to execute.
        /// </summary>
        /// <returns>The hydrated runtime root directory.</returns>
        private static string EnsureHydratedRuntime(string launcherPath)
        {
            var asm = Assembly.GetExecutingAssembly();
            var payloadResources = GetEmbeddedPayloadResourceNames(asm);
            if (payloadResources.Length == 0)
            {
                throw new InvalidOperationException("Embedded runtime payload is missing.");
            }

            var launcherFingerprint = GetLauncherCacheFingerprint(launcherPath);
            var scriptRoot = AppContext.BaseDirectory;
            if (IsRuntimeReady(scriptRoot, payloadResources, launcherFingerprint)) return scriptRoot;

            var version = GetBundleVersion(asm);
            var buildId = GetBundleBuildId(asm);
            var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            if (string.IsNullOrWhiteSpace(localAppData))
            {
                localAppData = Path.Combine(Path.GetTempPath(), "Baseline_LocalAppData");
            }

            var cacheRoot = Path.Combine(localAppData, "Baseline", RuntimeCacheFolderName);
            var runtimeRoot = Path.Combine(cacheRoot, version, RuntimeCacheSchema, buildId, launcherFingerprint);
            if (IsRuntimeReady(runtimeRoot, payloadResources, launcherFingerprint)) return runtimeRoot;

            Directory.CreateDirectory(cacheRoot);
            using (var hydrationLock = new FileStream(Path.Combine(cacheRoot, ".hydrate.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None))
            {
                if (IsRuntimeReady(runtimeRoot, payloadResources, launcherFingerprint)) return runtimeRoot;

                var runtimeParent = Path.GetDirectoryName(runtimeRoot);
                if (!string.IsNullOrWhiteSpace(runtimeParent))
                {
                    Directory.CreateDirectory(runtimeParent);
                }

                if (Directory.Exists(runtimeRoot)) Directory.Delete(runtimeRoot, true);
                var staging = runtimeRoot + StagingSuffix;
                if (Directory.Exists(staging)) Directory.Delete(staging, true);
                Directory.CreateDirectory(staging);

                foreach (var res in payloadResources)
                {
                    var rel = GetPayloadRelativePath(res);
                    var target = Path.Combine(staging, rel);
                    using (var rs = asm.GetManifestResourceStream(res))
                    {
                        if (rs == null)
                        {
                            throw new InvalidOperationException("Embedded runtime payload stream could not be opened: " + res);
                        }

                        WriteHydratedResource(target, rs);
                    }
                }

                File.WriteAllText(
                    Path.Combine(staging, HydrationSentinel),
                    RuntimeCacheSchema + Environment.NewLine +
                    version + Environment.NewLine +
                    buildId + Environment.NewLine +
                    launcherFingerprint + Environment.NewLine);
                Directory.Move(staging, runtimeRoot);
            }

            return runtimeRoot;
        }

        /// <summary>
        /// Gets the manifest resource names that belong to the embedded runtime payload.
        /// </summary>
        /// <param name="asm">The launcher assembly.</param>
        /// <returns>The sorted runtime payload resource names.</returns>
        private static string[] GetEmbeddedPayloadResourceNames(Assembly asm)
        {
            return asm.GetManifestResourceNames()
                .Where(n => n.StartsWith(PayloadPrefix, StringComparison.Ordinal))
                .OrderBy(n => n, StringComparer.Ordinal)
                .ToArray();
        }

        /// <summary>
        /// Maps an embedded payload resource name to its relative runtime file path.
        /// </summary>
        /// <param name="resourceName">The manifest resource name.</param>
        /// <returns>The relative path inside the hydrated runtime root.</returns>
        private static string GetPayloadRelativePath(string resourceName)
        {
            return resourceName.Substring(PayloadPrefix.Length).Replace('/', Path.DirectorySeparatorChar);
        }

        /// <summary>
        /// Writes an embedded resource stream to the hydrated runtime.
        /// </summary>
        /// <param name="target">The destination file path.</param>
        /// <param name="resourceStream">The embedded resource stream.</param>
        private static void WriteHydratedResource(string target, Stream resourceStream)
        {
            var dir = Path.GetDirectoryName(target);
            if (!string.IsNullOrEmpty(dir))
            {
                Directory.CreateDirectory(dir);
            }

            using (var fs = new FileStream(target, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                if (ShouldPrependUtf8Bom(target, resourceStream) && !ResourceStartsWithUtf8Bom(resourceStream))
                {
                    fs.Write(Utf8Bom, 0, Utf8Bom.Length);
                }

                resourceStream.CopyTo(fs);
            }
        }

        /// <summary>
        /// Determines whether a hydrated resource should be written with a UTF-8 BOM.
        /// </summary>
        /// <param name="target">The destination file path.</param>
        /// <param name="resourceStream">The embedded resource stream.</param>
        /// <returns>True when the file should be prefixed with a BOM.</returns>
        private static bool ShouldPrependUtf8Bom(string target, Stream resourceStream)
        {
            if (!RequiresPowerShellUtf8Bom(target) || !resourceStream.CanSeek || resourceStream.Length == 0)
            {
                return false;
            }

            var originalPosition = resourceStream.Position;
            try
            {
                resourceStream.Position = 0;
                var sampleLength = checked((int)resourceStream.Length);
                var sample = new byte[sampleLength];
                var bytesRead = resourceStream.Read(sample, 0, sample.Length);
                if (bytesRead <= Utf8Bom.Length)
                {
                    return false;
                }

                var hasNonAsciiByte = false;
                for (var i = 0; i < bytesRead; i++)
                {
                    if (sample[i] == 0)
                    {
                        return false;
                    }

                    if (sample[i] > 127)
                    {
                        hasNonAsciiByte = true;
                    }
                }

                // ASCII-only scripts are safe without a BOM. Only preserve UTF-8 BOMs
                // for PowerShell script resources that actually contain non-ASCII bytes.
                if (!hasNonAsciiByte)
                {
                    return false;
                }

                try
                {
                    _ = new UTF8Encoding(false, true).GetString(sample, 0, bytesRead);
                    return bytesRead > 0;
                }
                catch (DecoderFallbackException)
                {
                    return false;
                }
            }
            finally
            {
                resourceStream.Position = originalPosition;
            }
        }

        /// <summary>
        /// Determines whether a resource type relies on a UTF-8 BOM when hydrated.
        /// </summary>
        /// <param name="target">The destination file path.</param>
        /// <returns>True when the resource is a PowerShell script/module file.</returns>
        private static bool RequiresPowerShellUtf8Bom(string target)
        {
            if (string.IsNullOrWhiteSpace(target))
            {
                return false;
            }

            var extension = Path.GetExtension(target);
            return extension.Equals(".ps1", StringComparison.OrdinalIgnoreCase)
                || extension.Equals(".psm1", StringComparison.OrdinalIgnoreCase)
                || extension.Equals(".psd1", StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>
        /// Checks whether an embedded resource already starts with a UTF-8 BOM.
        /// </summary>
        /// <param name="resourceStream">The embedded resource stream.</param>
        /// <returns>True when the stream starts with a UTF-8 BOM.</returns>
        private static bool ResourceStartsWithUtf8Bom(Stream resourceStream)
        {
            if (!resourceStream.CanSeek || resourceStream.Length < Utf8Bom.Length)
            {
                return false;
            }

            var originalPosition = resourceStream.Position;
            try
            {
                resourceStream.Position = 0;
                var prefix = new byte[Utf8Bom.Length];
                var bytesRead = resourceStream.Read(prefix, 0, prefix.Length);
                return bytesRead == Utf8Bom.Length
                    && prefix[0] == Utf8Bom[0]
                    && prefix[1] == Utf8Bom[1]
                    && prefix[2] == Utf8Bom[2];
            }
            finally
            {
                resourceStream.Position = originalPosition;
            }
        }

        /// <summary>
        /// Tests whether the hydrated runtime root has already been prepared.
        /// </summary>
        /// <param name="root">The runtime root path.</param>
        /// <param name="payloadResources">The embedded runtime payload resource names.</param>
        /// <returns>True when the runtime sentinel is present.</returns>
        private static bool IsRuntimeReady(string root, string[] payloadResources, string launcherFingerprint)
        {
            if (!Directory.Exists(root) || payloadResources.Length == 0)
            {
                return false;
            }

            var sentinelPath = Path.Combine(root, HydrationSentinel);
            if (!File.Exists(sentinelPath))
            {
                return false;
            }

            var sentinelLines = File.ReadAllLines(sentinelPath);
            if (sentinelLines.Length != 4)
            {
                return false;
            }

            if (!string.Equals(sentinelLines[0], RuntimeCacheSchema, StringComparison.Ordinal) ||
                string.IsNullOrWhiteSpace(sentinelLines[1]) ||
                string.IsNullOrWhiteSpace(sentinelLines[2]) ||
                !string.Equals(sentinelLines[3], launcherFingerprint, StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            return payloadResources
                .Select(GetPayloadRelativePath)
                .Select(relativePath => Path.Combine(root, relativePath))
                .All(File.Exists);
        }

        /// <summary>
        /// Computes a cache fingerprint for the launcher executable contents.
        /// </summary>
        /// <param name="launcherPath">The launcher executable path.</param>
        /// <returns>The executable fingerprint used to invalidate stale caches.</returns>
        private static string GetLauncherCacheFingerprint(string launcherPath)
        {
            if (string.IsNullOrWhiteSpace(launcherPath))
            {
                throw new ArgumentException("Launcher path is required.", nameof(launcherPath));
            }

            using (var stream = new FileStream(launcherPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            using (var sha256 = SHA256.Create())
            {
                var hash = sha256.ComputeHash(stream);
                var fingerprint = BitConverter.ToString(hash).Replace("-", string.Empty);
                return fingerprint.Substring(0, 12);
            }
        }

        /// <summary>
        /// Reads the bundle version from assembly metadata.
        /// </summary>
        /// <param name="asm">The assembly to inspect.</param>
        /// <returns>The bundle version string.</returns>
        private static string GetBundleVersion(Assembly asm)
        {
            var v = asm.GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
                 ?? asm.GetName().Version?.ToString()
                 ?? "0.0.0";

            // Strip build metadata so the cache path only reflects the public bundle version.
            var plusIndex = v.IndexOf('+');
            if (plusIndex > 0)
            {
                v = v.Substring(0, plusIndex);
            }

            var bad = Path.GetInvalidFileNameChars();
            return new string(v.Select(c => bad.Contains(c) ? '_' : c).ToArray());
        }

        /// <summary>
        /// Reads the bundle build identifier from assembly metadata.
        /// </summary>
        /// <param name="asm">The assembly to inspect.</param>
        /// <returns>The bundle build identifier.</returns>
        private static string GetBundleBuildId(Assembly asm)
        {
            var buildId = asm.ManifestModule.ModuleVersionId.ToString("N");
            return buildId;
        }

        // ── State root ────────────────────────────────────────────────────────────

        /// <summary>
        /// Resolves the Baseline state root and portability mode.
        /// </summary>
        /// <param name="appBase">The application base directory.</param>
        /// <param name="portable">Outputs whether portable mode is active.</param>
        /// <returns>The resolved state root path.</returns>
        private static string ResolveStateRoot(string appBase, out bool portable)
        {
            var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            if (string.IsNullOrWhiteSpace(localAppData))
            {
                localAppData = Path.Combine(Path.GetTempPath(), "Baseline_LocalAppData");
            }

            var isPortableLocation = appBase.StartsWith(localAppData, StringComparison.OrdinalIgnoreCase);

            if (isPortableLocation)
            {
                var p = Path.Combine(appBase, "Data");
                if (CanWrite(p))
                {
                    portable = true;
                    return p;
                }
            }

            if (!string.IsNullOrWhiteSpace(localAppData))
            {
                var s = Path.Combine(localAppData, "Baseline", "UserState");
                if (CanWrite(s))
                {
                    portable = false;
                    return s;
                }
            }

            var tmp = Path.Combine(Path.GetTempPath(), "Baseline", "UserState");
            if (!CanWrite(tmp))
            {
                throw new InvalidOperationException("No writable state directory available.");
            }

            portable = false;
            return tmp;
        }

        /// <summary>
        /// Determines whether a path can be written to.
        /// </summary>
        /// <param name="path">The path to test.</param>
        /// <returns>True when write access is available.</returns>
        private static bool CanWrite(string path)
        {
            try
            {
                Directory.CreateDirectory(path);
                var probe = Path.Combine(path, ".write-probe");
                File.WriteAllText(probe, "ok");
                File.Delete(probe);
                return true;
            }
            catch (UnauthorizedAccessException)
            {
                return false;
            }
            catch (IOException)
            {
                return false;
            }
            catch (System.Security.SecurityException)
            {
                return false;
            }
            catch (Exception)
            {
                return false;
            }
        }

        // ── PowerShell invocation ─────────────────────────────────────────────────

        /// <summary>
        /// Starts the embedded PowerShell runtime with the hydrated launcher script.
        /// </summary>
        /// <param name="launcherScript">The PowerShell entry script path.</param>
        /// <param name="launcherPath">The launcher executable path.</param>
        /// <param name="hydratedRoot">The hydrated runtime root.</param>
        /// <param name="stateRoot">The Baseline state root.</param>
        /// <param name="portableMode">Whether portable mode is enabled.</param>
        /// <param name="installerMode">Whether installer mode is enabled.</param>
        /// <param name="language">The selected language code.</param>
        /// <param name="args">The original command-line arguments.</param>
        /// <returns>The launcher exit code.</returns>
        private static int StartEmbeddedPowerShell(
            string launcherScript,
            string launcherPath,
            string hydratedRoot,
            string stateRoot,
            bool portable,
            bool installer,
            string lang,
            string[] args)
        {
            var normalizedArgs = NormalizePowerShellArguments(args);
            Environment.SetEnvironmentVariable(StateRootVar, stateRoot, EnvironmentVariableTarget.Process);
            Environment.SetEnvironmentVariable(EmbeddedHostVar, "1", EnvironmentVariableTarget.Process);
            Environment.SetEnvironmentVariable(LauncherPathVar, launcherPath, EnvironmentVariableTarget.Process);
            Environment.SetEnvironmentVariable(PortableModeVar, portable ? "1" : "0", EnvironmentVariableTarget.Process);
            Environment.SetEnvironmentVariable(InstallerModeVar, installer ? "1" : "0", EnvironmentVariableTarget.Process);
            if (!string.IsNullOrWhiteSpace(lang))
            {
                Environment.SetEnvironmentVariable(LanguageVar, lang, EnvironmentVariableTarget.Process);
            }
            Environment.CurrentDirectory = hydratedRoot;

            using (var host = new BaselinePowerShellHost())
            using (var runspace = RunspaceFactory.CreateRunspace(host))
            {
                runspace.ApartmentState = ApartmentState.STA;
                runspace.ThreadOptions = PSThreadOptions.ReuseThread;
                runspace.Open();
                runspace.SessionStateProxy.SetVariable("BaselineLauncherScript", launcherScript);
                runspace.SessionStateProxy.SetVariable("BaselineLauncherArguments", normalizedArgs);

                using (var powershell = PowerShell.Create())
                {
                    powershell.Runspace = runspace;
                    powershell.AddScript("& $BaselineLauncherScript @BaselineLauncherArguments");

                    var timeout = GetPowerShellInvokeTimeout();
                    var asyncResult = powershell.BeginInvoke();
                    if (!asyncResult.AsyncWaitHandle.WaitOne(timeout))
                    {
                        try
                        {
                            powershell.Stop();
                        }
                        catch
                        {
                            // Stop is best effort only.
                        }

                        NativeMsgBox(
                            IntPtr.Zero,
                            $"Baseline timed out while running the PowerShell workflow after {timeout.TotalMinutes:0} minute(s).",
                            "Baseline",
                            MB_OK | MB_ICONERROR);
                        return 1;
                    }

                    PSDataCollection<PSObject> output;
                    try
                    {
                        output = powershell.EndInvoke(asyncResult);
                    }
                    catch (PipelineStoppedException)
                    {
                        return 1;
                    }

                    if (host.ShouldExit)
                    {
                        return host.ExitCode;
                    }

                    if (powershell.HadErrors)
                    {
                        return 1;
                    }

                    for (var i = output.Count - 1; i >= 0; i--)
                    {
                        var value = output[i] != null ? output[i].BaseObject : null;
                        if (value is int exitCode)
                        {
                            return exitCode;
                        }

                        if (value is long exitCodeLong)
                        {
                            return unchecked((int)exitCodeLong);
                        }
                    }
                }
            }

            return 0;
        }

        /// <summary>
        /// Normalizes GNU-style long switches to the PowerShell parameter names
        /// consumed by the embedded launcher script.
        /// </summary>
        /// <param name="args">The original command-line arguments.</param>
        /// <returns>The normalized argument list.</returns>
        private static string[] NormalizePowerShellArguments(string[] args)
        {
            if (args == null || args.Length == 0)
            {
                return Array.Empty<string>();
            }

            var normalized = new string[args.Length];
            for (var i = 0; i < args.Length; i++)
            {
                normalized[i] = NormalizePowerShellArgument(args[i]);
            }

            return normalized;
        }

        /// <summary>
        /// Normalizes a single command-line argument for PowerShell parameter binding.
        /// </summary>
        /// <param name="argument">The argument to normalize.</param>
        /// <returns>The normalized argument.</returns>
        private static string NormalizePowerShellArgument(string argument)
        {
            if (string.IsNullOrWhiteSpace(argument))
            {
                return argument;
            }

            if (argument == "--" || argument == "--%")
            {
                return argument;
            }

            if (!argument.StartsWith("--", StringComparison.Ordinal))
            {
                return argument;
            }

            var normalizedText = argument.Substring(2);
            if (string.IsNullOrWhiteSpace(normalizedText))
            {
                return argument;
            }

            var valueSeparatorIndex = normalizedText.IndexOf('=');
            var valueSuffix = string.Empty;
            if (valueSeparatorIndex >= 0)
            {
                valueSuffix = normalizedText.Substring(valueSeparatorIndex);
                normalizedText = normalizedText.Substring(0, valueSeparatorIndex);
            }

            var segments = normalizedText.Split(new[] { '-' }, StringSplitOptions.RemoveEmptyEntries);
            if (segments.Length == 0)
            {
                return "-" + normalizedText + valueSuffix;
            }

            var builder = new StringBuilder();
            foreach (var segment in segments)
            {
                if (string.IsNullOrWhiteSpace(segment))
                {
                    continue;
                }

                builder.Append(char.ToUpperInvariant(segment[0]));
                if (segment.Length > 1)
                {
                    builder.Append(segment.Substring(1));
                }
            }

            if (builder.Length == 0)
            {
                return "-" + normalizedText + valueSuffix;
            }

            return "-" + builder.ToString() + valueSuffix;
        }

        /// <summary>
        /// Resolves the PowerShell invocation timeout for the embedded workflow.
        /// </summary>
        /// <returns>The timeout to apply before stopping the pipeline.</returns>
        private static TimeSpan GetPowerShellInvokeTimeout()
        {
            var raw = Environment.GetEnvironmentVariable(PowerShellTimeoutSecondsVar);
            if (int.TryParse(raw, out var timeoutSeconds) && timeoutSeconds > 0)
            {
                return TimeSpan.FromSeconds(timeoutSeconds);
            }

            return TimeSpan.FromSeconds(DefaultPowerShellTimeoutSeconds);
        }
    }
}

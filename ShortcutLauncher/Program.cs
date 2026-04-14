// Internal shortcut launcher that locates Baseline.exe and relays execution.
// Used by the installer and desktop shortcut flow.

using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;

namespace Baseline.ShortcutLauncher
{
    internal static class Program
    {
        /// <summary>
        /// Displays a native message box for launcher errors.
        /// </summary>
        /// <param name="hWnd">The owner window handle.</param>
        /// <param name="text">The message text.</param>
        /// <param name="caption">The window caption.</param>
        /// <param name="type">The message box type flags.</param>
        /// <returns>The native message-box result.</returns>
        [DllImport("user32.dll", EntryPoint = "MessageBoxW", CharSet = CharSet.Unicode)]
        private static extern int NativeMsgBox(IntPtr hWnd, string text, string caption, uint type);
        private const uint MB_OK        = 0x00000000;
        private const uint MB_ICONERROR = 0x00000010;

        /// <summary>
        /// Internal shortcut launcher entrypoint for Baseline.
        /// </summary>
        /// <returns>An exit code suitable for the host process.</returns>
        [STAThread]
        private static int Main()
        {
            try
            {
                var exeDir = Path.GetDirectoryName(
                    System.Reflection.Assembly.GetExecutingAssembly().Location) ?? string.Empty;
                var script = Path.Combine(exeDir, "Bootstrap", "Baseline.ps1");

                if (!File.Exists(script))
                {
                    NativeMsgBox(IntPtr.Zero,
                        "Could not find launcher script:\n" + script,
                        "Baseline", MB_OK | MB_ICONERROR);
                    return 1;
                }

                var shell = FindShell();
                if (shell == null)
                {
                    NativeMsgBox(IntPtr.Zero,
                        "PowerShell was not found. Install PowerShell 7+ and try again.",
                        "Baseline", MB_OK | MB_ICONERROR);
                    return 1;
                }

                // UseShellExecute=true so Windows honours the requireAdministrator manifest
                // embedded in this exe — PowerShell inherits the elevated token.
                var psi = new ProcessStartInfo
                {
                    FileName         = shell,
                    Arguments        = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + script + "\"",
                    UseShellExecute  = true,
                    WorkingDirectory = exeDir
                };

                using (var proc = Process.Start(psi))
                {
                    if (proc == null) return 1;
                    proc.WaitForExit();
                    return proc.ExitCode;
                }
            }
            catch (Exception ex)
            {
                NativeMsgBox(IntPtr.Zero,
                    "Baseline failed to start:\n" + ex.Message,
                    "Baseline", MB_OK | MB_ICONERROR);
                return 1;
            }
        }

        /// <summary>
        /// Locates a usable PowerShell executable.
        /// </summary>
        /// <returns>The resolved shell path, or null if none is available.</returns>
        private static string FindShell()
        {
            foreach (var candidate in new[] { "pwsh.exe", "powershell.exe" })
            {
                var found = FindOnPath(candidate);
                if (found != null) return found;
            }
            return null;
        }

        /// <summary>
        /// Searches the current PATH for an executable.
        /// </summary>
        /// <param name="exe">The executable file name.</param>
        /// <returns>The resolved executable path, or null if it is not found.</returns>
        private static string FindOnPath(string exe)
        {
            var pathEnv = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
            foreach (var dir in pathEnv.Split(Path.PathSeparator))
            {
                var trimmed = dir.Trim();
                if (string.IsNullOrEmpty(trimmed)) continue;
                var full = Path.Combine(trimmed, exe);
                if (File.Exists(full)) return full;
            }

            var pf = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
            var extras = new[]
            {
                Path.Combine(pf, "PowerShell", "7", exe),
                Path.Combine(pf, "PowerShell", "7-preview", exe),
            };
            foreach (var path in extras)
                if (File.Exists(path)) return path;

            return null;
        }
    }
}

using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

internal static class Launcher
{
    [STAThread]
    static void Main()
    {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        try
        {
            string script = Path.Combine(root, "Nexo.ps1");
            if (!File.Exists(script)) throw new FileNotFoundException("Extrae la carpeta completa antes de abrir Nexo Assistant.");
            string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), @"System32\WindowsPowerShell\v1.0\powershell.exe");
            var info = new ProcessStartInfo(powershell, "-NoProfile -STA -ExecutionPolicy Bypass -File \"" + script + "\"");
            info.WorkingDirectory = root;
            info.UseShellExecute = false;
            info.CreateNoWindow = true;
            info.RedirectStandardError = true;
            using (var process = Process.Start(info))
            {
                string error = process.StandardError.ReadToEnd();
                process.WaitForExit();
                if (process.ExitCode != 0)
                {
                    string log = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "NexoAssistant", "inicio-error.txt");
                    Directory.CreateDirectory(Path.GetDirectoryName(log));
                    File.WriteAllText(log, error);
                    MessageBox.Show("No se pudo abrir Nexo Assistant. Consulta:\n" + log, "Nexo Assistant", MessageBoxButtons.OK, MessageBoxIcon.Error);
                }
            }
        }
        catch (Exception error) { MessageBox.Show(error.Message, "Nexo Assistant", MessageBoxButtons.OK, MessageBoxIcon.Error); }
    }
}

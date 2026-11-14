using System;
using System.IO;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace Nightfall.EditorTools
{
    /// <summary>
    /// Points d'entrée -executeMethod pour la CI :
    ///   Nightfall.EditorTools.BuildScript.BuildArm32  -> nightfall-arm32.apk (ARMv7, IL2CPP)
    ///   Nightfall.EditorTools.BuildScript.BuildArm64  -> nightfall-arm64.apk (ARM64, IL2CPP)
    /// Option : -customBuildPath <dossier> (fourni par game-ci/unity-builder).
    /// </summary>
    public static class BuildScript
    {
        public static void BuildArm32() { Run(AndroidArchitecture.ARMv7, "nightfall-arm32.apk"); }
        public static void BuildArm64() { Run(AndroidArchitecture.ARM64, "nightfall-arm64.apk"); }

        static string Arg(string name)
        {
            string[] a = Environment.GetCommandLineArgs();
            for (int i = 0; i < a.Length - 1; i++) if (a[i] == name) return a[i + 1];
            return null;
        }

        static void Run(AndroidArchitecture arch, string fileName)
        {
            int code = 1;
            try
            {
                ProjectConfigurator.Configure(arch);
                string scene = SceneFactory.CreateBootScene();

                string dir = Arg("-customBuildPath");
                if (string.IsNullOrEmpty(dir)) dir = "build/Android";
                if (dir.EndsWith(".apk", StringComparison.OrdinalIgnoreCase)) dir = Path.GetDirectoryName(dir);
                Directory.CreateDirectory(dir);
                string output = Path.Combine(dir, fileName);

                var opts = new BuildPlayerOptions
                {
                    scenes = new[] { scene },
                    locationPathName = output,
                    target = BuildTarget.Android,
                    options = BuildOptions.None
                };
                BuildReport report = BuildPipeline.BuildPlayer(opts);
                BuildSummary s = report.summary;
                Debug.Log("[Nightfall] Résultat build " + arch + " : " + s.result + ", taille " + s.totalSize + " octets, erreurs " + s.totalErrors);
                if (s.result == BuildResult.Succeeded && File.Exists(output)) code = 0;
                else Debug.LogError("[Nightfall] Build échoué ou APK absent : " + output);
            }
            catch (Exception e)
            {
                Debug.LogError("[Nightfall] Exception pendant le build : " + e);
            }
            EditorApplication.Exit(code);
        }
    }
}

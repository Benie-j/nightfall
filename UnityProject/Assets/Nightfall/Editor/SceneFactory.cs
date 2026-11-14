using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using Nightfall.Core;

namespace Nightfall.EditorTools
{
    /// <summary>Crée la scène Boot (un seul objet GameBootstrap) et l'inscrit dans les Build Settings.</summary>
    public static class SceneFactory
    {
        public const string BootScenePath = "Assets/Nightfall/Scenes/Boot.unity";

        public static string CreateBootScene()
        {
            Directory.CreateDirectory("Assets/Nightfall/Scenes");
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var go = new GameObject("Bootstrap");
            go.AddComponent<GameBootstrap>();

            // Le brouillard est configuré à l'exécution ; on l'active aussi ici pour que les variantes soient conservées.
            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.ExponentialSquared;

            EditorSceneManager.SaveScene(scene, BootScenePath);
            EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(BootScenePath, true) };
            AssetDatabase.Refresh();
            return BootScenePath;
        }
    }
}

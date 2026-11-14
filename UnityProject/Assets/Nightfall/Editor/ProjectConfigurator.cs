using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Nightfall.EditorTools
{
    /// <summary>
    /// Configure par code tout ce qui doit être fixé pour Android : architecture, IL2CPP, API graphiques,
    /// URP, matériaux modèles (anti-stripping des variantes), shaders inclus. Exécuté avant chaque build CI.
    /// </summary>
    public static class BuildInfo
    {
        public const string VersionName = "0.2.0";
        public const int VersionCode = 2;
    }

    public static class ProjectConfigurator
    {
        const string SettingsDir = "Assets/Nightfall/Settings";
        const string ResDir = "Assets/Nightfall/Resources/Nightfall";

        public static void Configure(AndroidArchitecture arch)
        {
            if (arch != AndroidArchitecture.ARMv7 && arch != AndroidArchitecture.ARM64)
                throw new System.ArgumentException("Une seule architecture par APK : ARMv7 ou ARM64.");

            bool arm32 = arch == AndroidArchitecture.ARMv7;
            NamedBuildTarget android = NamedBuildTarget.Android;

            PlayerSettings.companyName = "Nightfall";
            PlayerSettings.productName = "Nightfall";
            PlayerSettings.SetApplicationIdentifier(android, "com.nightfall.unity");
            // Les deux variantes partagent versionName ET versionCode (pas de code distinct par architecture).
            PlayerSettings.bundleVersion = BuildInfo.VersionName;
            PlayerSettings.Android.bundleVersionCode = BuildInfo.VersionCode;

            PlayerSettings.SetScriptingBackend(android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures = arch;
            PlayerSettings.SetIl2CppCompilerConfiguration(android, Il2CppCompilerConfiguration.Release);
            PlayerSettings.SetIl2CppCodeGeneration(android, Il2CppCodeGeneration.OptimizeSize);
            PlayerSettings.SetManagedStrippingLevel(android, ManagedStrippingLevel.Medium);

            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel23;
            PlayerSettings.Android.targetSdkVersion = AndroidSdkVersions.AndroidApiLevelAuto;
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.LandscapeLeft;
            PlayerSettings.colorSpace = ColorSpace.Linear;
            PlayerSettings.gcIncremental = true;

            PlayerSettings.SetUseDefaultGraphicsAPIs(BuildTarget.Android, false);
            PlayerSettings.SetGraphicsAPIs(BuildTarget.Android, arm32
                ? new[] { GraphicsDeviceType.OpenGLES3 }
                : new[] { GraphicsDeviceType.Vulkan, GraphicsDeviceType.OpenGLES3 });

            EditorUserBuildSettings.androidBuildSubtarget = MobileTextureSubtarget.ASTC;
            EditorUserBuildSettings.buildAppBundle = false;

            EnsureFolders();
            CreateUrp(arm32);
            CreateTemplateMaterials();
            AddAlwaysIncludedShaders("Universal Render Pipeline/Lit", "Universal Render Pipeline/Unlit",
                                     "Universal Render Pipeline/Particles/Unlit", "Sprites/Default");
            KeepFogVariants();
            CheckInputHandler();
            AssetDatabase.SaveAssets();

            if (PlayerSettings.Android.targetArchitectures != arch)
                throw new System.Exception("L'architecture demandée n'a pas été appliquée : " + PlayerSettings.Android.targetArchitectures +
                                           " (cette version d'Unity ne la prend peut-être pas en charge).");
            Debug.Log("[Nightfall] Configuration Android OK : " + arch + ", IL2CPP, applicationId com.nightfall.unity");
        }

        static void EnsureFolders()
        {
            Directory.CreateDirectory(SettingsDir);
            Directory.CreateDirectory(ResDir);
            Directory.CreateDirectory("Assets/Nightfall/Scenes");
            AssetDatabase.Refresh();
        }

        static void CreateUrp(bool low)
        {
            string name = low ? "Nightfall_URP_Arm32" : "Nightfall_URP_Arm64";
            string path = SettingsDir + "/" + name + ".asset";
            var asset = AssetDatabase.LoadAssetAtPath<UniversalRenderPipelineAsset>(path);
            if (asset == null)
            {
                var rd = ScriptableObject.CreateInstance<UniversalRendererData>();
                AssetDatabase.CreateAsset(rd, SettingsDir + "/" + name + "_Renderer.asset");
                asset = UniversalRenderPipelineAsset.Create(rd);
                AssetDatabase.CreateAsset(asset, path);
            }
            asset.renderScale = low ? 0.75f : 1f;
            asset.shadowDistance = low ? 25f : 60f;
            asset.shadowCascadeCount = low ? 1 : 2;
            asset.msaaSampleCount = low ? 1 : 2;
            asset.maxAdditionalLightsCount = low ? 2 : 4;
            asset.supportsHDR = !low;
            EditorUtility.SetDirty(asset);

            GraphicsSettings.defaultRenderPipeline = asset;
            int old = QualitySettings.GetQualityLevel();
            for (int i = 0; i < QualitySettings.names.Length; i++)
            {
                QualitySettings.SetQualityLevel(i, false);
                QualitySettings.renderPipeline = asset;
            }
            QualitySettings.SetQualityLevel(old, false);
        }

        static void CreateTemplateMaterials()
        {
            MakeMat("LitBase", "Universal Render Pipeline/Lit", false);
            MakeMat("LitEmissive", "Universal Render Pipeline/Lit", true);
            MakeMat("Unlit", "Universal Render Pipeline/Unlit", false);
            MakeMat("Particle", "Universal Render Pipeline/Particles/Unlit", false);
        }

        static void MakeMat(string name, string shaderName, bool emissive)
        {
            string path = ResDir + "/" + name + ".mat";
            Shader sh = Shader.Find(shaderName);
            if (sh == null) throw new System.Exception("Shader introuvable : " + shaderName);
            var m = AssetDatabase.LoadAssetAtPath<Material>(path);
            if (m == null) { m = new Material(sh); AssetDatabase.CreateAsset(m, path); }
            m.shader = sh;
            if (emissive)
            {
                m.EnableKeyword("_EMISSION");
                m.SetColor("_EmissionColor", Color.white);
            }
            EditorUtility.SetDirty(m);
        }

        static Object LoadSettingsAsset(string path)
        {
            Object[] all = AssetDatabase.LoadAllAssetsAtPath(path);
            return (all != null && all.Length > 0) ? all[0] : null;
        }

        static void AddAlwaysIncludedShaders(params string[] names)
        {
            Object gs = LoadSettingsAsset("ProjectSettings/GraphicsSettings.asset");
            if (gs == null) { Debug.LogWarning("[Nightfall] GraphicsSettings.asset introuvable : shaders non ajoutés."); return; }
            var so = new SerializedObject(gs);
            SerializedProperty arr = so.FindProperty("m_AlwaysIncludedShaders");
            foreach (string n in names)
            {
                Shader s = Shader.Find(n);
                if (s == null) continue;
                bool has = false;
                for (int i = 0; i < arr.arraySize; i++)
                    if (arr.GetArrayElementAtIndex(i).objectReferenceValue == s) { has = true; break; }
                if (has) continue;
                arr.InsertArrayElementAtIndex(arr.arraySize);
                arr.GetArrayElementAtIndex(arr.arraySize - 1).objectReferenceValue = s;
            }
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        /// <summary>Le brouillard est activé à l'exécution : on empêche l'élimination des variantes de brouillard.</summary>
        static void KeepFogVariants()
        {
            Object gs = LoadSettingsAsset("ProjectSettings/GraphicsSettings.asset");
            if (gs == null) return;
            var so = new SerializedObject(gs);
            SerializedProperty mode = so.FindProperty("m_FogStripping");
            SerializedProperty exp2 = so.FindProperty("m_FogKeepExp2");
            if (mode != null) mode.intValue = 1;
            if (exp2 != null) exp2.boolValue = true;
            so.ApplyModifiedPropertiesWithoutUndo();
        }

        /// <summary>Le jeu utilise l'ancien Input Manager (Input.touches). Échec explicite si seul le nouveau est actif.</summary>
        static void CheckInputHandler()
        {
            Object ps = LoadSettingsAsset("ProjectSettings/ProjectSettings.asset");
            if (ps == null) return;
            var so = new SerializedObject(ps);
            SerializedProperty p = so.FindProperty("activeInputHandler");
            if (p != null && p.intValue == 1)
            {
                p.intValue = 0;
                so.ApplyModifiedPropertiesWithoutUndo();
                AssetDatabase.SaveAssets();
                throw new System.Exception("activeInputHandler valait 1 (Input System seul). Corrigé en 0 dans ProjectSettings.asset : " +
                                           "committez ce fichier puis relancez le build (un redémarrage de l'éditeur est requis).");
            }
        }
    }
}

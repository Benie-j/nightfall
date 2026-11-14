using UnityEngine;
using UnityEngine.Rendering.Universal;
using Nightfall.SaveSystem;

namespace Nightfall.Core
{
    /// <summary>
    /// Profils ARM32 / ARM64 appliqués à l'exécution (URP + QualitySettings).
    /// Auto : IntPtr.Size == 4 -> processus 32 bits (APK ARMv7), sinon 64 bits.
    /// </summary>
    public static class QualityProfile
    {
        public static bool IsArm32Process { get { return System.IntPtr.Size == 4; } }

        public static bool UseLowProfile
        {
            get
            {
                int o = SaveData.QualityOverride;
                if (o == 1) return true;
                if (o == 2) return false;
                return IsArm32Process;
            }
        }

        public static int TargetFps { get { return UseLowProfile ? 30 : 60; } }
        public static bool PostProcessing { get { return !UseLowProfile; } }
        public static float EnemySightRange { get { return UseLowProfile ? 35f : 45f; } }
        public static int SectorWindow { get { return UseLowProfile ? 1 : 2; } }

        public static void Apply()
        {
            bool low = UseLowProfile;
            Application.targetFrameRate = TargetFps;
            QualitySettings.vSyncCount = 0;
            QualitySettings.lodBias = low ? 0.6f : 1.2f;
            QualitySettings.globalTextureMipmapLimit = low ? 1 : 0;
            QualitySettings.anisotropicFiltering = low ? AnisotropicFiltering.Disable : AnisotropicFiltering.Enable;

            var urp = UniversalRenderPipeline.asset;
            if (urp == null)
            {
                Debug.LogWarning("[Nightfall] Aucun URP asset actif : profil qualité non appliqué.");
                return;
            }
            urp.renderScale = low ? 0.75f : 1.0f;
            urp.shadowDistance = low ? 25f : 60f;
            urp.shadowCascadeCount = low ? 1 : 2;
            urp.msaaSampleCount = low ? 1 : 2;
            urp.maxAdditionalLightsCount = low ? 2 : 4;
            urp.supportsHDR = !low;
        }
    }
}

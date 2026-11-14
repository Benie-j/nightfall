using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using Nightfall.Audio;

namespace Nightfall.Core
{
    /// <summary>Ambiance nocturne : lune, brouillard, ambiance, post-traitement URP (profil haut uniquement).</summary>
    public static class NightEnvironment
    {
        public static readonly Color FogColor = new Color(0.04f, 0.06f, 0.10f);

        public static void Apply(Transform root, Camera cam)
        {
            bool low = QualityProfile.UseLowProfile;

            RenderSettings.fog = true;
            RenderSettings.fogMode = FogMode.ExponentialSquared;
            RenderSettings.fogDensity = low ? 0.018f : 0.012f;
            RenderSettings.fogColor = FogColor;
            RenderSettings.ambientMode = AmbientMode.Flat;
            RenderSettings.ambientLight = new Color(0.07f, 0.09f, 0.15f);

            var moonGo = new GameObject("Lune");
            moonGo.transform.SetParent(root, false);
            moonGo.transform.rotation = Quaternion.Euler(48f, -32f, 0f);
            var moon = moonGo.AddComponent<Light>();
            moon.type = LightType.Directional;
            moon.color = new Color(0.55f, 0.65f, 0.95f);
            moon.intensity = 0.55f;
            moon.shadows = LightShadows.Soft;

            cam.clearFlags = CameraClearFlags.SolidColor;
            cam.backgroundColor = FogColor;
            cam.farClipPlane = low ? 140f : 220f;

            var data = cam.GetUniversalAdditionalCameraData();
            data.renderPostProcessing = QualityProfile.PostProcessing;
            data.antialiasing = low ? AntialiasingMode.None : AntialiasingMode.FastApproximateAntialiasing;

            if (QualityProfile.PostProcessing)
            {
                var vgo = new GameObject("Volume");
                vgo.transform.SetParent(root, false);
                var vol = vgo.AddComponent<Volume>();
                vol.isGlobal = true;
                var prof = ScriptableObject.CreateInstance<VolumeProfile>();
                var bloom = prof.Add<Bloom>(true);
                bloom.intensity.value = 0.7f; bloom.threshold.value = 0.95f;
                var vig = prof.Add<Vignette>(true);
                vig.intensity.value = 0.35f;
                var tm = prof.Add<Tonemapping>(true);
                tm.mode.value = TonemappingMode.ACES;
                var ca = prof.Add<ColorAdjustments>(true);
                ca.contrast.value = 12f; ca.saturation.value = -8f;
                vol.sharedProfile = prof;
            }

            var amb = new GameObject("Ambiance");
            amb.transform.SetParent(root, false);
            var src = amb.AddComponent<AudioSource>();
            src.clip = ProcAudio.Ambience; src.loop = true; src.volume = 0.5f; src.spatialBlend = 0f;
            src.Play();
        }
    }
}

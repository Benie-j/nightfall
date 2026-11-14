using UnityEngine;

namespace Nightfall.Audio
{
    /// <summary>Sons procéduraux provisoires (aucun fichier audio dans l'archive d'origine).</summary>
    public static class ProcAudio
    {
        static readonly System.Random rnd = new System.Random(77);
        static AudioClip rifle, pistol, shotgun, reload, hit, empty, ambience;

        static float Rn() { return (float)(rnd.NextDouble() * 2.0 - 1.0); }

        static AudioClip Make(string name, float dur, System.Func<float, float> f)
        {
            const int sr = 22050;
            int len = (int)(dur * sr);
            var d = new float[len];
            for (int i = 0; i < len; i++) d[i] = Mathf.Clamp(f(i / (float)sr), -1f, 1f);
            var c = AudioClip.Create(name, len, 1, sr, false);
            c.SetData(d, 0);
            return c;
        }

        public static AudioClip Rifle { get { return rifle != null ? rifle : (rifle = Make("rifle", 0.28f, t => (Rn() * Mathf.Exp(-t * 28f) + Mathf.Sin(t * 2f * Mathf.PI * 95f) * Mathf.Exp(-t * 18f)) * 0.8f)); } }
        public static AudioClip Pistol { get { return pistol != null ? pistol : (pistol = Make("pistol", 0.22f, t => (Rn() * Mathf.Exp(-t * 38f) + Mathf.Sin(t * 2f * Mathf.PI * 130f) * Mathf.Exp(-t * 26f)) * 0.7f)); } }
        public static AudioClip Shotgun { get { return shotgun != null ? shotgun : (shotgun = Make("shotgun", 0.45f, t => (Rn() * Mathf.Exp(-t * 14f) + Mathf.Sin(t * 2f * Mathf.PI * 70f) * Mathf.Exp(-t * 10f)) * 0.9f)); } }
        public static AudioClip Reload { get { return reload != null ? reload : (reload = Make("reload", 0.18f, t => Rn() * Mathf.Exp(-t * 45f) * 0.5f + Mathf.Sin(t * 2f * Mathf.PI * 900f) * Mathf.Exp(-t * 60f) * 0.3f)); } }
        public static AudioClip Hit { get { return hit != null ? hit : (hit = Make("hit", 0.08f, t => Mathf.Sin(t * 2f * Mathf.PI * 1400f) * Mathf.Exp(-t * 50f) * 0.5f)); } }
        public static AudioClip Empty { get { return empty != null ? empty : (empty = Make("empty", 0.06f, t => Rn() * Mathf.Exp(-t * 80f) * 0.4f)); } }
        public static AudioClip Ambience { get { return ambience != null ? ambience : (ambience = Make("ambience", 4f, t => (Mathf.Sin(t * 2f * Mathf.PI * 50f) * 0.05f + Mathf.Sin(t * 2f * Mathf.PI * 0.5f) * 0.02f))); } }

        public static void Play(AudioClip c, Vector3 pos, float vol = 1f, float pitch = 1f)
        {
            if (c == null) return;
            var go = new GameObject("sfx");
            go.transform.position = pos;
            var a = go.AddComponent<AudioSource>();
            a.clip = c; a.volume = vol; a.pitch = pitch; a.spatialBlend = 1f;
            a.minDistance = 4f; a.maxDistance = 120f; a.rolloffMode = AudioRolloffMode.Linear;
            a.Play();
            Object.Destroy(go, c.length / Mathf.Max(0.1f, pitch) + 0.1f);
        }

        public static void Play2D(AudioClip c, float vol = 1f)
        {
            if (c == null) return;
            var go = new GameObject("sfx2d");
            var a = go.AddComponent<AudioSource>();
            a.clip = c; a.volume = vol; a.spatialBlend = 0f;
            a.Play();
            Object.Destroy(go, c.length + 0.1f);
        }
    }
}

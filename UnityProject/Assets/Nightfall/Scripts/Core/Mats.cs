using System.Collections.Generic;
using UnityEngine;

namespace Nightfall.Core
{
    /// <summary>
    /// Fabrique de matériaux URP. Les matériaux modèles (Resources/Nightfall/*) sont créés par
    /// l'éditeur avant le build pour que les variantes de shader (emission...) ne soient pas éliminées.
    /// </summary>
    public static class Mats
    {
        static readonly Dictionary<string, Material> cache = new Dictionary<string, Material>();

        static Material Template(string resName, string shaderName)
        {
            Material t = Resources.Load<Material>("Nightfall/" + resName);
            if (t != null) return new Material(t);
            Shader s = Shader.Find(shaderName);
            if (s == null) s = Shader.Find("Sprites/Default");
            return new Material(s);
        }

        public static Material Lit(Color c, float metallic = 0f, float smooth = 0.35f, Color emission = default(Color))
        {
            bool em = emission.maxColorComponent > 0f;
            string key = "L" + c + metallic + smooth + emission;
            Material m;
            if (cache.TryGetValue(key, out m) && m != null) return m;
            m = Template(em ? "LitEmissive" : "LitBase", "Universal Render Pipeline/Lit");
            m.SetColor("_BaseColor", c);
            m.SetFloat("_Metallic", metallic);
            m.SetFloat("_Smoothness", smooth);
            if (em) { m.EnableKeyword("_EMISSION"); m.SetColor("_EmissionColor", emission); }
            cache[key] = m;
            return m;
        }

        public static Material Textured(Texture2D albedo, Texture2D emission, Vector2 tiling, float smooth = 0.2f)
        {
            Material m = Template(emission != null ? "LitEmissive" : "LitBase", "Universal Render Pipeline/Lit");
            m.SetColor("_BaseColor", Color.white);
            m.SetTexture("_BaseMap", albedo);
            m.SetTextureScale("_BaseMap", tiling);
            m.SetFloat("_Smoothness", smooth);
            if (emission != null)
            {
                m.EnableKeyword("_EMISSION");
                m.SetTexture("_EmissionMap", emission);
                m.SetColor("_EmissionColor", Color.white);
            }
            return m;
        }

        public static Material Unlit(Color c)
        {
            string key = "U" + c;
            Material m;
            if (cache.TryGetValue(key, out m) && m != null) return m;
            m = Template("Unlit", "Universal Render Pipeline/Unlit");
            m.SetColor("_BaseColor", c);
            cache[key] = m;
            return m;
        }

        public static Material Particle()
        {
            Material m;
            if (cache.TryGetValue("P", out m) && m != null) return m;
            m = Template("Particle", "Universal Render Pipeline/Particles/Unlit");
            cache["P"] = m;
            return m;
        }
    }
}

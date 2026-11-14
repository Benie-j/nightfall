using System.Collections.Generic;
using UnityEngine;

namespace Nightfall.Core
{
    /// <summary>Textures procédurales (aucune ressource externe, donc aucune licence à gérer).</summary>
    public static class ProcTex
    {
        static readonly Dictionary<int, Texture2D> alb = new Dictionary<int, Texture2D>();
        static readonly Dictionary<int, Texture2D> emi = new Dictionary<int, Texture2D>();
        static Texture2D asphalt;

        public static void Facade(int variant, out Texture2D albedo, out Texture2D emission)
        {
            variant = Mathf.Abs(variant) % 3;
            if (!alb.ContainsKey(variant))
            {
                const int N = 128;
                var a = new Color32[N * N];
                var e = new Color32[N * N];
                var rnd = new System.Random(variant * 7919 + 13);
                Color baseC = variant == 0 ? new Color(0.55f, 0.52f, 0.46f)
                            : variant == 1 ? new Color(0.62f, 0.45f, 0.36f)
                                           : new Color(0.45f, 0.50f, 0.52f);
                const int cells = 4;
                int cs = N / cells;
                var lit = new bool[cells, cells];
                for (int i = 0; i < cells; i++)
                    for (int j = 0; j < cells; j++) lit[i, j] = rnd.NextDouble() < 0.28;
                for (int y = 0; y < N; y++)
                {
                    for (int x = 0; x < N; x++)
                    {
                        int cx = x / cs, cy = y / cs, lx = x % cs, ly = y % cs;
                        bool win = lx >= 6 && lx < cs - 6 && ly >= 8 && ly < cs - 6;
                        float n = (float)rnd.NextDouble() * 0.12f - 0.06f;
                        Color c = win ? new Color(0.06f, 0.08f, 0.11f) : new Color(baseC.r + n, baseC.g + n, baseC.b + n);
                        c.a = 1f;
                        a[y * N + x] = c;
                        e[y * N + x] = (win && lit[cx, cy]) ? new Color32(255, 190, 110, 255) : new Color32(0, 0, 0, 255);
                    }
                }
                alb[variant] = Make(N, a);
                emi[variant] = Make(N, e);
            }
            albedo = alb[variant];
            emission = emi[variant];
        }

        public static Texture2D Asphalt()
        {
            if (asphalt != null) return asphalt;
            const int N = 64;
            var p = new Color32[N * N];
            var rnd = new System.Random(4242);
            for (int i = 0; i < p.Length; i++)
            {
                byte v = (byte)(34 + rnd.Next(0, 22));
                p[i] = new Color32(v, v, (byte)(v + 3), 255);
            }
            asphalt = Make(N, p);
            return asphalt;
        }

        static Texture2D Make(int n, Color32[] px)
        {
            var t = new Texture2D(n, n, TextureFormat.RGBA32, true, false);
            t.wrapMode = TextureWrapMode.Repeat;
            t.filterMode = FilterMode.Bilinear;
            t.SetPixels32(px);
            t.Apply(true);
            return t;
        }
    }
}

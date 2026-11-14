using System;
using System.Collections.Generic;
using UnityEngine;
using Nightfall.Core;

namespace Nightfall.World
{
    // Formats produits par tools/osm_to_unity.py (JSON plat compatible JsonUtility).
    [Serializable] public class OsmBuildingJson { public long osm_id; public string kind; public string name; public int levels; public float height_m; public bool height_estimated; public float[] pts; }
    [Serializable] public class OsmRoadJson { public long osm_id; public string highway; public string name; public float width; public float[] pts; }
    [Serializable] public class OsmPlaceJson { public long osm_id; public string name; public string kind; public float x; public float z; }
    [Serializable] public class OsmMapJson
    {
        public int schema_version; public string source; public string attribution; public string license;
        public float siporex_x, siporex_z, ficgayo_x, ficgayo_z;
        public OsmBuildingJson[] buildings; public OsmRoadJson[] roads; public OsmPlaceJson[] places;
    }

    /// <summary>
    /// Monde construit à partir de données OpenStreetMap réelles (Siporex - Ficgayo, Yopougon), si le fichier
    /// Resources/Data/yopougon_unity.json est présent. Sinon <see cref="Available"/> vaut false et la mission 1
    /// utilise le décor procédural. Aucune donnée OSM n'était fournie dans l'archive source : ce code n'a donc
    /// JAMAIS été exécuté sur des données réelles. Les hauteurs absentes d'OSM sont estimées (non mesurées).
    /// </summary>
    public class OsmWorld : MonoBehaviour
    {
        public const string ResourceName = "Data/yopougon_unity";
        public static bool Available { get { return Resources.Load<TextAsset>(ResourceName) != null; } }

        public float MinX, MaxX, MinZ, MaxZ;
        public Vector3 PlayerStart, Siporex, Ficgayo;
        public string Attribution = "";
        public int BuildingCount, RoadCount;
        public readonly List<Vector3> SpawnPoints = new List<Vector3>();
        public readonly List<Collider> CoverColliders = new List<Collider>();
        public Transform Target;

        class Chunk { public GameObject Go; public Vector3 Center; }
        readonly List<Chunk> chunks = new List<Chunk>();
        float timer;

        public static OsmWorld Create(Transform parent)
        {
            var ta = Resources.Load<TextAsset>(ResourceName);
            if (ta == null) return null;
            var map = JsonUtility.FromJson<OsmMapJson>(ta.text);
            if (map == null || map.buildings == null) return null;
            var go = new GameObject("MondeOSM");
            go.transform.SetParent(parent, false);
            var w = go.AddComponent<OsmWorld>();
            w.Build(map);
            return w;
        }

        // ---------------------------------------------------------------- Construction
        void Build(OsmMapJson map)
        {
            Attribution = string.IsNullOrEmpty(map.attribution) ? "© OpenStreetMap contributors" : map.attribution;
            Siporex = new Vector3(map.siporex_x, 0.2f, map.siporex_z);
            Ficgayo = new Vector3(map.ficgayo_x, 0.2f, map.ficgayo_z);
            const float pad = 200f;
            MinX = Mathf.Min(Siporex.x, Ficgayo.x) - pad; MaxX = Mathf.Max(Siporex.x, Ficgayo.x) + pad;
            MinZ = Mathf.Min(Siporex.z, Ficgayo.z) - pad; MaxZ = Mathf.Max(Siporex.z, Ficgayo.z) + pad;
            PlayerStart = Siporex;

            bool low = QualityProfile.UseLowProfile;

            // Sol et murs invisibles aux limites de la zone jouable.
            var ground = GameObject.CreatePrimitive(PrimitiveType.Cube);
            ground.name = "Sol";
            ground.transform.SetParent(transform, false);
            ground.transform.position = new Vector3((MinX + MaxX) * 0.5f, -0.3f, (MinZ + MaxZ) * 0.5f);
            ground.transform.localScale = new Vector3(MaxX - MinX, 0.6f, MaxZ - MinZ);
            ground.GetComponent<Renderer>().sharedMaterial = Mats.Lit(new Color(0.07f, 0.065f, 0.055f), 0f, 0.05f);
            AddWall(new Vector3(MinX - 1f, 10f, (MinZ + MaxZ) * 0.5f), new Vector3(2f, 20f, MaxZ - MinZ + 4f));
            AddWall(new Vector3(MaxX + 1f, 10f, (MinZ + MaxZ) * 0.5f), new Vector3(2f, 20f, MaxZ - MinZ + 4f));
            AddWall(new Vector3((MinX + MaxX) * 0.5f, 10f, MinZ - 1f), new Vector3(MaxX - MinX + 4f, 20f, 2f));
            AddWall(new Vector3((MinX + MaxX) * 0.5f, 10f, MaxZ + 1f), new Vector3(MaxX - MinX + 4f, 20f, 2f));

            BuildRoads(map.roads);
            BuildBuildings(map.buildings);
        }

        void AddWall(Vector3 pos, Vector3 size)
        {
            var go = new GameObject("Limite");
            go.transform.SetParent(transform, false);
            go.transform.position = pos;
            go.AddComponent<BoxCollider>().size = size;
        }

        bool Inside(float x, float z) { return x >= MinX && x <= MaxX && z >= MinZ && z <= MaxZ; }

        // ---------------------------------------------------------------- Routes
        void BuildRoads(OsmRoadJson[] roads)
        {
            if (roads == null) return;
            var verts = new List<Vector3>();
            var tris = new List<int>();
            float sinceSpawn = 0f;
            for (int r = 0; r < roads.Length; r++)
            {
                var rd = roads[r];
                if (rd.pts == null || rd.pts.Length < 4) continue;
                int n = rd.pts.Length / 2;
                bool any = false;
                for (int i = 0; i < n; i++) if (Inside(rd.pts[2 * i], rd.pts[2 * i + 1])) { any = true; break; }
                if (!any) continue;
                RoadCount++;
                float half = Mathf.Max(1f, rd.width) * 0.5f;
                for (int i = 0; i < n - 1; i++)
                {
                    Vector3 a = new Vector3(rd.pts[2 * i], 0.03f, rd.pts[2 * i + 1]);
                    Vector3 b = new Vector3(rd.pts[2 * i + 2], 0.03f, rd.pts[2 * i + 3]);
                    Vector3 d = b - a; d.y = 0f;
                    float len = d.magnitude;
                    if (len < 0.05f) continue;
                    d /= len;
                    Vector3 side = new Vector3(-d.z, 0f, d.x) * half;
                    int v = verts.Count;
                    verts.Add(a - side); verts.Add(a + side); verts.Add(b + side); verts.Add(b - side);
                    // Vue du dessus, sens horaire (face visible vers le haut).
                    tris.Add(v); tris.Add(v + 1); tris.Add(v + 2);
                    tris.Add(v); tris.Add(v + 2); tris.Add(v + 3);

                    sinceSpawn += len;
                    if (sinceSpawn > 45f && Inside(b.x, b.z) && (b - Siporex).sqrMagnitude > 60f * 60f)
                    {
                        SpawnPoints.Add(new Vector3(b.x, 0.2f, b.z));
                        sinceSpawn = 0f;
                    }
                }
            }
            if (verts.Count == 0) return;
            var mesh = new Mesh { name = "Routes", indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 };
            mesh.SetVertices(verts); mesh.SetTriangles(tris, 0);
            mesh.RecalculateNormals(); mesh.RecalculateBounds();
            var go = new GameObject("Routes");
            go.transform.SetParent(transform, false);
            go.AddComponent<MeshFilter>().sharedMesh = mesh;
            var mr = go.AddComponent<MeshRenderer>();
            var m = Mats.Lit(new Color(0.045f, 0.045f, 0.05f), 0f, 0.3f);
            TryDoubleSided(m);
            mr.sharedMaterial = m;
            mr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
        }

        static void TryDoubleSided(Material m) { if (m != null && m.HasProperty("_Cull")) m.SetFloat("_Cull", 0f); }

        // ---------------------------------------------------------------- Bâtiments
        public class MeshAcc { public List<Vector3> V = new List<Vector3>(); public List<int> T = new List<int>(); public Vector3 Sum; public int N; }

        void BuildBuildings(OsmBuildingJson[] buildings)
        {
            if (buildings == null) return;
            Color[] palette =
            {
                new Color(0.16f, 0.15f, 0.13f), new Color(0.2f, 0.17f, 0.12f),
                new Color(0.12f, 0.13f, 0.15f), new Color(0.18f, 0.12f, 0.1f)
            };
            var accs = new Dictionary<long, MeshAcc>();
            const float cellSize = 120f;
            for (int i = 0; i < buildings.Length; i++)
            {
                var b = buildings[i];
                if (b.pts == null || b.pts.Length < 6) continue;
                int n = b.pts.Length / 2;
                bool any = false;
                float cx = 0f, cz = 0f;
                var poly = new List<Vector2>(n);
                for (int k = 0; k < n; k++)
                {
                    float x = b.pts[2 * k], z = b.pts[2 * k + 1];
                    if (Inside(x, z)) any = true;
                    poly.Add(new Vector2(x, z)); cx += x; cz += z;
                }
                if (!any) continue;
                cx /= n; cz /= n;

                // Hauteur : height_m > levels > estimation déterministe (non mesurée).
                float h = b.height_m > 0f ? b.height_m : (b.levels > 0 ? b.levels * 3.2f + 0.8f : 5f + (float)(Math.Abs(b.osm_id) % 5L));
                int color = (int)(Math.Abs(b.osm_id) % palette.Length);
                long key = ((long)(Mathf.FloorToInt((cx - MinX) / cellSize) + 100) * 1000L + (long)(Mathf.FloorToInt((cz - MinZ) / cellSize) + 100)) * 10L + color;
                MeshAcc acc;
                if (!accs.TryGetValue(key, out acc)) { acc = new MeshAcc(); accs[key] = acc; }
                if (AddBuilding(acc, poly, h)) { acc.Sum += new Vector3(cx, 0f, cz); acc.N++; BuildingCount++; }
            }

            foreach (var kv in accs)
            {
                MeshAcc acc = kv.Value;
                if (acc.V.Count == 0) continue;
                int color = (int)(kv.Key % 10L);
                var mesh = new Mesh { name = "Batiments", indexFormat = UnityEngine.Rendering.IndexFormat.UInt32 };
                mesh.SetVertices(acc.V); mesh.SetTriangles(acc.T, 0);
                mesh.RecalculateNormals(); mesh.RecalculateBounds();
                var go = new GameObject("Batiments_" + kv.Key);
                go.transform.SetParent(transform, false);
                go.AddComponent<MeshFilter>().sharedMesh = mesh;
                var mr = go.AddComponent<MeshRenderer>();
                var mat = Mats.Lit(palette[color], 0f, 0.12f);
                TryDoubleSided(mat);   // sécurité contre une erreur d'orientation des faces (non vérifiée sur appareil)
                mr.sharedMaterial = mat;
                go.AddComponent<MeshCollider>().sharedMesh = mesh;
                chunks.Add(new Chunk { Go = go, Center = acc.Sum / Mathf.Max(1, acc.N) });
            }
        }

        static float SignedArea(List<Vector2> p)
        {
            float a = 0f;
            for (int i = 0; i < p.Count; i++) { Vector2 u = p[i], v = p[(i + 1) % p.Count]; a += u.x * v.y - v.x * u.y; }
            return a * 0.5f;
        }

        /// <summary>Extrude l'empreinte : murs + toit (triangulation par oreilles). Retourne false si l'empreinte est dégénérée.</summary>
        public static bool AddBuilding(MeshAcc acc, List<Vector2> poly, float height)
        {
            if (poly.Count < 3 || height <= 0f) return false;
            // Retire un éventuel sommet de fermeture dupliqué.
            if ((poly[0] - poly[poly.Count - 1]).sqrMagnitude < 1e-6f) poly.RemoveAt(poly.Count - 1);
            if (poly.Count < 3) return false;
            float area = SignedArea(poly);
            if (Mathf.Abs(area) < 1f) return false;
            if (area > 0f) poly.Reverse();   // on travaille en sens horaire (z vers le haut de l'écran)

            int n = poly.Count;
            int baseIdx = acc.V.Count;
            // Murs : pour chaque arête a->b d'un polygone horaire, quad (aB, bB, bT) + (aB, bT, aT) visible de l'extérieur.
            for (int i = 0; i < n; i++)
            {
                Vector2 a = poly[i], b = poly[(i + 1) % n];
                int v = acc.V.Count;
                acc.V.Add(new Vector3(a.x, 0f, a.y)); acc.V.Add(new Vector3(b.x, 0f, b.y));
                acc.V.Add(new Vector3(b.x, height, b.y)); acc.V.Add(new Vector3(a.x, height, a.y));
                acc.T.Add(v); acc.T.Add(v + 1); acc.T.Add(v + 2);
                acc.T.Add(v); acc.T.Add(v + 2); acc.T.Add(v + 3);
            }
            // Toit.
            int roofBase = acc.V.Count;
            for (int i = 0; i < n; i++) acc.V.Add(new Vector3(poly[i].x, height, poly[i].y));
            var tris = new List<int>();
            Triangulate(poly, tris);
            if (tris.Count == 0) { acc.V.RemoveRange(baseIdx, acc.V.Count - baseIdx); acc.T.RemoveRange(acc.T.Count - n * 6, n * 6); return false; }
            for (int i = 0; i < tris.Count; i++) acc.T.Add(roofBase + tris[i]);
            return true;
        }

        /// <summary>Triangulation par oreilles d'un polygone simple en sens horaire. Les triangles gardent le sens horaire.</summary>
        public static void Triangulate(List<Vector2> poly, List<int> tris)
        {
            var idx = new List<int>();
            for (int i = 0; i < poly.Count; i++) idx.Add(i);
            int guard = poly.Count * poly.Count + 10;
            while (idx.Count > 3 && guard-- > 0)
            {
                bool clipped = false;
                for (int i = 0; i < idx.Count; i++)
                {
                    int i0 = idx[(i + idx.Count - 1) % idx.Count], i1 = idx[i], i2 = idx[(i + 1) % idx.Count];
                    Vector2 a = poly[i0], b = poly[i1], c = poly[i2];
                    float cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
                    if (cross >= 0f) continue;            // sommet réflexe ou colinéaire (polygone horaire)
                    bool blocked = false;
                    for (int j = 0; j < idx.Count; j++)
                    {
                        int k = idx[j];
                        if (k == i0 || k == i1 || k == i2) continue;
                        if (PointInTriangle(poly[k], a, b, c)) { blocked = true; break; }
                    }
                    if (blocked) continue;
                    tris.Add(i0); tris.Add(i1); tris.Add(i2);
                    idx.RemoveAt(i);
                    clipped = true;
                    break;
                }
                if (!clipped) { tris.Clear(); return; }  // empreinte auto-intersectante : on abandonne ce bâtiment
            }
            if (idx.Count == 3) { tris.Add(idx[0]); tris.Add(idx[1]); tris.Add(idx[2]); }
        }

        static bool PointInTriangle(Vector2 p, Vector2 a, Vector2 b, Vector2 c)
        {
            float d1 = Sign(p, a, b), d2 = Sign(p, b, c), d3 = Sign(p, c, a);
            bool neg = d1 < 0f || d2 < 0f || d3 < 0f;
            bool pos = d1 > 0f || d2 > 0f || d3 > 0f;
            return !(neg && pos);
        }

        static float Sign(Vector2 p1, Vector2 p2, Vector2 p3) { return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y); }

        // ---------------------------------------------------------------- Chargement par zones
        void Update()
        {
            if (Target == null) return;
            timer -= Time.unscaledDeltaTime;
            if (timer > 0f) return;
            timer = 0.5f;
            float r = QualityProfile.UseLowProfile ? 170f : 260f;
            Vector3 p = Target.position;
            for (int i = 0; i < chunks.Count; i++)
            {
                Vector3 d = chunks[i].Center - p; d.y = 0f;
                bool on = d.sqrMagnitude < (r + 90f) * (r + 90f);
                if (chunks[i].Go.activeSelf != on) chunks[i].Go.SetActive(on);
            }
        }
    }
}

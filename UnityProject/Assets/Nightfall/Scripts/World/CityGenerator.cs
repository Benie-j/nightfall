using System.Collections.Generic;
using UnityEngine;
using Nightfall.Core;

namespace Nightfall.World
{
    /// <summary>
    /// Génération procédurale d'une rue de quartier populaire d'Abidjan (inspirée de Yopougon) :
    /// chaussée, trottoirs, bâtiments R+1 à R+4 avec fenêtres éclairées, ruelles, kiosques à toit de tôle,
    /// taxis et véhicules garés, lampadaires, caisses/barrières servant de couverture.
    /// AUCUNE donnée OpenStreetMap n'est exploitée : l'archive d'origine n'en contient pas (voir AUDIT.md).
    /// Les sections sont des "secteurs" activés/désactivés selon la position du joueur.
    /// </summary>
    public class CityGenerator : MonoBehaviour
    {
        public const float SectorLength = 100f;
        public const float RoadWidth = 14f;
        const float Sidewalk = 3f;
        const float Depth = 18f;

        public readonly List<GameObject> Sectors = new List<GameObject>();
        public readonly List<Collider> CoverColliders = new List<Collider>();
        public readonly List<List<Vector3>> SpawnPoints = new List<List<Vector3>>();
        public float TotalLength { get { return Sectors.Count * SectorLength; } }
        public Vector3 PlayerStart { get { return new Vector3(0f, 0.2f, 6f); } }

        System.Random rnd;
        readonly List<Vector3> occupied = new List<Vector3>(); // x,z,rayon

        float R(float a, float b) { return a + (float)rnd.NextDouble() * (b - a); }

        GameObject Box(Transform parent, string name, Vector3 pos, Vector3 scale, Material m, bool collider, Vector3 euler = default(Vector3), bool shadows = true)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.name = name;
            if (!collider) Destroy(go.GetComponent<Collider>());
            go.transform.SetParent(parent, false);
            go.transform.localPosition = pos;
            go.transform.localEulerAngles = euler;
            go.transform.localScale = scale;
            var r = go.GetComponent<Renderer>();
            r.sharedMaterial = m;
            if (!shadows) r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            return go;
        }

        GameObject Cyl(Transform parent, string name, Vector3 pos, Vector3 scale, Material m, bool collider, Vector3 euler = default(Vector3))
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            go.name = name;
            if (!collider) Destroy(go.GetComponent<Collider>());
            go.transform.SetParent(parent, false);
            go.transform.localPosition = pos;
            go.transform.localEulerAngles = euler;
            go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = m;
            return go;
        }

        public void Build(int seed, int sectorCount)
        {
            rnd = new System.Random(seed);
            bool low = QualityProfile.UseLowProfile;

            float total = sectorCount * SectorLength;
            Material ground = Mats.Lit(new Color(0.05f, 0.05f, 0.06f), 0f, 0.1f);
            Box(transform, "Sol", new Vector3(0, -0.3f, total * 0.5f), new Vector3(140f, 0.6f, total + 80f), ground, true);

            Material wallDark = Mats.Lit(new Color(0.07f, 0.075f, 0.08f), 0f, 0.1f);
            Box(transform, "MurFond-G", new Vector3(-Depth - 14f, 15f, total * 0.5f), new Vector3(1f, 30f, total + 40f), wallDark, true, default(Vector3), false);
            Box(transform, "MurFond-D", new Vector3(Depth + 14f, 15f, total * 0.5f), new Vector3(1f, 30f, total + 40f), wallDark, true, default(Vector3), false);
            Box(transform, "MurDebut", new Vector3(0, 15f, -8f), new Vector3(60f, 30f, 1f), wallDark, true, default(Vector3), false);
            Box(transform, "MurFin", new Vector3(0, 15f, total + 8f), new Vector3(60f, 30f, 1f), wallDark, true, default(Vector3), false);

            for (int i = 0; i < sectorCount; i++) BuildSector(i, low);
        }

        void BuildSector(int index, bool low)
        {
            var root = new GameObject("Sector_" + index);
            root.transform.SetParent(transform, false);
            Sectors.Add(root);
            var spawns = new List<Vector3>();
            SpawnPoints.Add(spawns);
            Transform t = root.transform;
            float z0 = index * SectorLength, zc = z0 + SectorLength * 0.5f;

            // Chaussée texturée + trottoirs + ligne médiane.
            Material road = Mats.Textured(ProcTex.Asphalt(), null, new Vector2(RoadWidth / 4f, SectorLength / 4f), 0.35f);
            Box(t, "Chaussee", new Vector3(0, 0.02f, zc), new Vector3(RoadWidth, 0.05f, SectorLength), road, true);
            Material curb = Mats.Lit(new Color(0.3f, 0.3f, 0.28f), 0f, 0.15f);
            float sx = RoadWidth * 0.5f + Sidewalk * 0.5f;
            Box(t, "Trottoir-G", new Vector3(-sx, 0.08f, zc), new Vector3(Sidewalk, 0.16f, SectorLength), curb, true);
            Box(t, "Trottoir-D", new Vector3(sx, 0.08f, zc), new Vector3(Sidewalk, 0.16f, SectorLength), curb, true);
            Material paint = Mats.Lit(new Color(0.75f, 0.72f, 0.6f), 0f, 0.2f);
            for (float z = z0 + 4f; z < z0 + SectorLength; z += 9f)
                Box(t, "Ligne", new Vector3(0, 0.06f, z), new Vector3(0.15f, 0.01f, 3.5f), paint, false, default(Vector3), false);

            // Bâtiments et ruelles.
            for (int side = -1; side <= 1; side += 2)
            {
                float z = z0;
                while (z < z0 + SectorLength - 6f)
                {
                    if (rnd.NextDouble() < 0.22) { z += R(4f, 6f); continue; } // ruelle
                    float w = R(16f, 28f);
                    if (z + w > z0 + SectorLength) w = z0 + SectorLength - z;
                    if (w < 8f) break;
                    int floors = rnd.NextDouble() < 0.12 ? rnd.Next(5, 8) : rnd.Next(2, 5);
                    BuildBuilding(t, side, z, w, floors, low);
                    z += w;
                }
            }

            // Lampadaires.
            int lampStep = low ? 3 : 2;
            int li = 0;
            for (float z = z0 + 10f; z < z0 + SectorLength; z += 25f)
            {
                for (int side = -1; side <= 1; side += 2)
                {
                    BuildLamp(t, side * (RoadWidth * 0.5f + 0.7f), z, side, li % lampStep == 0);
                    li++;
                }
            }

            // Véhicules garés (taxis, voitures).
            int cars = rnd.Next(3, 6);
            for (int c = 0; c < cars; c++)
            {
                int side = rnd.NextDouble() < 0.5 ? -1 : 1;
                float z = R(z0 + 6f, z0 + SectorLength - 6f);
                BuildCar(t, new Vector3(side * 5.2f, 0f, z), side > 0 ? 0f : 180f);
                occupied.Add(new Vector3(side * 5.2f, z, 3.2f));
            }

            // Kiosques à toit de tôle sur les trottoirs.
            int kiosks = rnd.Next(1, 3);
            for (int k = 0; k < kiosks; k++)
            {
                int side = rnd.NextDouble() < 0.5 ? -1 : 1;
                float z = R(z0 + 8f, z0 + SectorLength - 8f);
                BuildKiosk(t, new Vector3(side * 8.7f, 0f, z));
                occupied.Add(new Vector3(side * 8.7f, z, 2.2f));
            }

            // Couvertures : caisses, barrières, fûts.
            int covers = low ? 5 : 8;
            for (int c = 0; c < covers; c++)
            {
                float x = R(-5.5f, 5.5f), z = R(z0 + 5f, z0 + SectorLength - 5f);
                BuildCover(t, new Vector3(x, 0f, z), rnd.Next(0, 3));
                occupied.Add(new Vector3(x, z, 1.6f));
            }

            // Points d'apparition ennemis.
            for (int s = 0; s < 14 && spawns.Count < 8; s++)
            {
                float x = R(-6f, 6f), z = R(z0 + 4f, z0 + SectorLength - 4f);
                bool ok = true;
                for (int o = 0; o < occupied.Count; o++)
                {
                    Vector3 oc = occupied[o];
                    if ((new Vector2(oc.x, oc.y) - new Vector2(x, z)).sqrMagnitude < (oc.z + 1.2f) * (oc.z + 1.2f)) { ok = false; break; }
                }
                if (ok) spawns.Add(new Vector3(x, 0.2f, z));
            }
        }

        void BuildBuilding(Transform parent, int side, float z, float width, int floors, bool low)
        {
            float h = floors * 3.2f;
            Texture2D alb, emi;
            ProcTex.Facade(rnd.Next(0, 3), out alb, out emi);
            Material m = Mats.Textured(alb, low && rnd.NextDouble() < 0.5 ? null : emi, new Vector2(width / 16f, h / 12.8f), 0.2f);
            float cx = side * (RoadWidth * 0.5f + Sidewalk + Depth * 0.5f);
            var b = Box(parent, "Immeuble", new Vector3(cx, h * 0.5f, z + width * 0.5f), new Vector3(Depth, h, width), m, true);
            b.GetComponent<Renderer>().receiveShadows = true;

            Material roof = Mats.Lit(new Color(0.12f, 0.12f, 0.12f), 0f, 0.1f);
            Box(parent, "Acrotere", new Vector3(cx, h + 0.3f, z + width * 0.5f), new Vector3(Depth + 0.2f, 0.6f, width + 0.2f), roof, false, default(Vector3), false);
            if (rnd.NextDouble() < 0.4)
            {
                Material tank = Mats.Lit(new Color(0.1f, 0.14f, 0.2f), 0.3f, 0.4f);
                Cyl(parent, "ChateauEau", new Vector3(cx + R(-4f, 4f), h + 1.8f, z + width * 0.5f + R(-3f, 3f)), new Vector3(1.8f, 1.2f, 1.8f), tank, false);
            }
            Material door = Mats.Lit(new Color(0.18f, 0.1f, 0.06f), 0f, 0.2f);
            float roadFace = side * (RoadWidth * 0.5f + Sidewalk);
            Box(parent, "Porte", new Vector3(roadFace - side * 0.06f, 1.1f, z + width * 0.5f), new Vector3(0.2f, 2.2f, 1.3f), door, false, default(Vector3), false);
        }

        void BuildLamp(Transform parent, float x, float z, int side, bool withLight)
        {
            Material pole = Mats.Lit(new Color(0.08f, 0.08f, 0.08f), 0.6f, 0.4f);
            Material bulb = Mats.Lit(new Color(1f, 0.9f, 0.7f), 0f, 0.1f, new Color(2.2f, 1.7f, 0.9f));
            Box(parent, "Poteau", new Vector3(x, 3.1f, z), new Vector3(0.18f, 6.2f, 0.18f), pole, true);
            Box(parent, "Bras", new Vector3(x - side * 0.6f, 6.1f, z), new Vector3(1.3f, 0.12f, 0.12f), pole, false, default(Vector3), false);
            var lamp = Box(parent, "Ampoule", new Vector3(x - side * 1.2f, 5.98f, z), new Vector3(0.5f, 0.15f, 0.3f), bulb, false, default(Vector3), false);
            if (withLight)
            {
                var l = lamp.AddComponent<Light>();
                l.type = LightType.Point; l.range = 17f; l.intensity = 2.6f;
                l.color = new Color(1f, 0.82f, 0.55f); l.shadows = LightShadows.None;
            }
        }

        void BuildCar(Transform parent, Vector3 pos, float yaw)
        {
            Color[] palette = { new Color(0.85f, 0.4f, 0.05f), new Color(0.8f, 0.8f, 0.78f), new Color(0.2f, 0.22f, 0.25f), new Color(0.5f, 0.07f, 0.07f), new Color(0.1f, 0.2f, 0.4f) };
            Material body = Mats.Lit(palette[rnd.Next(palette.Length)], 0.6f, 0.6f);
            Material glass = Mats.Lit(new Color(0.03f, 0.05f, 0.07f), 0.2f, 0.9f);
            Material tire = Mats.Lit(new Color(0.03f, 0.03f, 0.03f), 0f, 0.2f);
            var car = new GameObject("Voiture");
            car.transform.SetParent(parent, false);
            car.transform.localPosition = pos;
            car.transform.localEulerAngles = new Vector3(0, yaw, 0);
            Box(car.transform, "Caisse", new Vector3(0, 0.65f, 0), new Vector3(1.8f, 0.7f, 4.2f), body, false);
            Box(car.transform, "Habitacle", new Vector3(0, 1.2f, -0.2f), new Vector3(1.6f, 0.55f, 2.3f), glass, false);
            for (int sx = -1; sx <= 1; sx += 2)
                for (int sz = -1; sz <= 1; sz += 2)
                    Cyl(car.transform, "Roue", new Vector3(sx * 0.92f, 0.35f, sz * 1.35f), new Vector3(0.7f, 0.12f, 0.7f), tire, false, new Vector3(0, 0, 90));
            var bc = car.AddComponent<BoxCollider>();
            bc.center = new Vector3(0, 0.75f, 0); bc.size = new Vector3(1.9f, 1.5f, 4.3f);
            CoverColliders.Add(bc);
        }

        void BuildKiosk(Transform parent, Vector3 pos)
        {
            Color[] palette = { new Color(0.1f, 0.35f, 0.6f), new Color(0.15f, 0.5f, 0.25f), new Color(0.6f, 0.2f, 0.12f) };
            Material wall = Mats.Lit(palette[rnd.Next(palette.Length)], 0f, 0.25f);
            Material sheet = Mats.Lit(new Color(0.35f, 0.33f, 0.3f), 0.8f, 0.35f);
            var k = new GameObject("Kiosque");
            k.transform.SetParent(parent, false);
            k.transform.localPosition = pos;
            Box(k.transform, "Murs", new Vector3(0, 1.1f, 0), new Vector3(2.4f, 2.2f, 2.4f), wall, false);
            Box(k.transform, "ToitTole", new Vector3(0, 2.35f, 0), new Vector3(3f, 0.08f, 3f), sheet, false, new Vector3(6, 0, 0));
            var bc = k.AddComponent<BoxCollider>();
            bc.center = new Vector3(0, 1.2f, 0); bc.size = new Vector3(2.5f, 2.4f, 2.5f);
            CoverColliders.Add(bc);
        }

        void BuildCover(Transform parent, Vector3 pos, int kind)
        {
            Material wood = Mats.Lit(new Color(0.35f, 0.24f, 0.12f), 0f, 0.2f);
            Material concrete = Mats.Lit(new Color(0.38f, 0.38f, 0.36f), 0f, 0.15f);
            Material drum = Mats.Lit(new Color(0.15f, 0.25f, 0.4f), 0.5f, 0.4f);
            GameObject go;
            if (kind == 0) go = Box(parent, "Caisse", pos + Vector3.up * 0.5f, new Vector3(1.1f, 1f, 1.1f), wood, true, new Vector3(0, R(0, 90), 0));
            else if (kind == 1) go = Box(parent, "Barriere", pos + Vector3.up * 0.45f, new Vector3(0.6f, 0.9f, 2.4f), concrete, true, new Vector3(0, R(-30, 30), 0));
            else go = Cyl(parent, "Fut", pos + Vector3.up * 0.45f, new Vector3(0.6f, 0.45f, 0.6f), drum, true);
            CoverColliders.Add(go.GetComponent<Collider>());
        }

        /// <summary>Active les secteurs index-window..index+window (+1 devant), désactive les autres.</summary>
        public void ShowWindow(int index, int window)
        {
            for (int i = 0; i < Sectors.Count; i++)
            {
                bool on = i >= index - window && i <= index + window + 1;
                if (Sectors[i].activeSelf != on) Sectors[i].SetActive(on);
            }
        }

        public int SectorIndexAt(float z) { return Mathf.Clamp(Mathf.FloorToInt(z / SectorLength), 0, Mathf.Max(0, Sectors.Count - 1)); }
    }
}

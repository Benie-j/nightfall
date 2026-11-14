using UnityEngine;
using Nightfall.Core;

namespace Nightfall.Weapons
{
    /// <summary>
    /// Modèles d'armes procéduraux (primitives). PROVISOIRE : aucun modèle d'arme n'existe dans l'archive.
    /// À remplacer par de vrais modèles sous licence claire (voir MIGRATION_REPORT.md).
    /// </summary>
    public static class WeaponModelBuilder
    {
        static GameObject Part(Transform parent, string name, PrimitiveType t, Vector3 pos, Vector3 scale, Material m, Vector3 euler = default(Vector3))
        {
            var go = GameObject.CreatePrimitive(t);
            go.name = name;
            Object.Destroy(go.GetComponent<Collider>());
            go.transform.SetParent(parent, false);
            go.transform.localPosition = pos;
            go.transform.localEulerAngles = euler;
            go.transform.localScale = scale;
            var r = go.GetComponent<Renderer>();
            r.sharedMaterial = m;
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            return go;
        }

        public static Transform Build(WeaponKind kind, Transform parent)
        {
            Material metal = Mats.Lit(new Color(0.12f, 0.12f, 0.13f), 0.85f, 0.55f);
            Material poly = Mats.Lit(new Color(0.07f, 0.07f, 0.08f), 0.1f, 0.3f);
            Material wood = Mats.Lit(new Color(0.34f, 0.2f, 0.1f), 0f, 0.4f);
            Material skin = Mats.Lit(new Color(0.26f, 0.17f, 0.13f), 0f, 0.45f);
            Material sleeve = Mats.Lit(new Color(0.2f, 0.24f, 0.14f), 0f, 0.2f);

            Transform muzzle;
            if (kind == WeaponKind.Pistol)
            {
                Part(parent, "slide", PrimitiveType.Cube, new Vector3(0, 0.02f, 0.07f), new Vector3(0.035f, 0.04f, 0.2f), metal);
                Part(parent, "frame", PrimitiveType.Cube, new Vector3(0, -0.012f, 0.05f), new Vector3(0.032f, 0.03f, 0.16f), poly);
                Part(parent, "grip", PrimitiveType.Cube, new Vector3(0, -0.07f, -0.02f), new Vector3(0.032f, 0.1f, 0.045f), poly, new Vector3(-12, 0, 0));
                Part(parent, "sightF", PrimitiveType.Cube, new Vector3(0, 0.045f, 0.16f), new Vector3(0.006f, 0.012f, 0.008f), metal);
                Part(parent, "sightR", PrimitiveType.Cube, new Vector3(0, 0.045f, -0.02f), new Vector3(0.02f, 0.012f, 0.008f), metal);
                Part(parent, "handR", PrimitiveType.Cube, new Vector3(0.0f, -0.075f, -0.025f), new Vector3(0.05f, 0.08f, 0.06f), skin, new Vector3(-12, 0, 0));
                Part(parent, "handL", PrimitiveType.Cube, new Vector3(-0.03f, -0.07f, 0.0f), new Vector3(0.04f, 0.06f, 0.07f), skin);
                Part(parent, "armR", PrimitiveType.Cube, new Vector3(0.05f, -0.15f, -0.2f), new Vector3(0.06f, 0.06f, 0.3f), sleeve, new Vector3(-8, -6, 0));
                muzzle = new GameObject("muzzle").transform;
                muzzle.SetParent(parent, false); muzzle.localPosition = new Vector3(0, 0.02f, 0.18f);
                return muzzle;
            }

            bool shot = kind == WeaponKind.Shotgun;
            Part(parent, "body", PrimitiveType.Cube, new Vector3(0, 0, 0), new Vector3(0.05f, 0.07f, 0.38f), metal);
            Part(parent, "barrel", PrimitiveType.Cylinder, new Vector3(0, 0.012f, shot ? 0.5f : 0.45f), new Vector3(shot ? 0.03f : 0.018f, shot ? 0.3f : 0.25f, shot ? 0.03f : 0.018f), metal, new Vector3(90, 0, 0));
            Part(parent, "handguard", PrimitiveType.Cube, new Vector3(0, -0.005f, 0.24f), new Vector3(0.056f, 0.05f, 0.22f), wood);
            Part(parent, "stock", PrimitiveType.Cube, new Vector3(0, -0.015f, -0.3f), new Vector3(0.04f, 0.08f, 0.24f), shot ? poly : wood, new Vector3(4, 0, 0));
            Part(parent, "grip", PrimitiveType.Cube, new Vector3(0, -0.085f, -0.085f), new Vector3(0.035f, 0.1f, 0.045f), poly, new Vector3(-15, 0, 0));
            if (!shot)
            {
                Part(parent, "mag", PrimitiveType.Cube, new Vector3(0, -0.115f, 0.04f), new Vector3(0.03f, 0.15f, 0.06f), metal, new Vector3(14, 0, 0));
                Part(parent, "sightF", PrimitiveType.Cube, new Vector3(0, 0.05f, 0.66f), new Vector3(0.008f, 0.04f, 0.008f), metal);
            }
            else
            {
                Part(parent, "tube", PrimitiveType.Cylinder, new Vector3(0, -0.03f, 0.42f), new Vector3(0.026f, 0.22f, 0.026f), metal, new Vector3(90, 0, 0));
            }
            Part(parent, "sightR", PrimitiveType.Cube, new Vector3(0, 0.05f, -0.02f), new Vector3(0.025f, 0.03f, 0.01f), metal);
            Part(parent, "handR", PrimitiveType.Cube, new Vector3(0, -0.095f, -0.09f), new Vector3(0.05f, 0.07f, 0.065f), skin, new Vector3(-15, 0, 0));
            Part(parent, "handL", PrimitiveType.Cube, new Vector3(0, -0.04f, 0.27f), new Vector3(0.055f, 0.05f, 0.09f), skin);
            Part(parent, "armR", PrimitiveType.Cube, new Vector3(0.06f, -0.17f, -0.28f), new Vector3(0.065f, 0.065f, 0.34f), sleeve, new Vector3(-10, -8, 0));
            Part(parent, "armL", PrimitiveType.Cube, new Vector3(-0.08f, -0.1f, 0.05f), new Vector3(0.06f, 0.06f, 0.4f), sleeve, new Vector3(-4, 16, 0));
            muzzle = new GameObject("muzzle").transform;
            muzzle.SetParent(parent, false);
            muzzle.localPosition = new Vector3(0, 0.012f, shot ? 0.78f : 0.72f);
            return muzzle;
        }
    }
}

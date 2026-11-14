using UnityEngine;
using Nightfall.Combat;
using Nightfall.Core;

namespace Nightfall.AI
{
    /// <summary>
    /// Soldat humanoïde procédural (primitives articulées). PROVISOIRE : hero.glb (EXT_meshopt_compression,
    /// EXT_texture_webp, KHR_mesh_quantization) n'est pas importable tel quel dans Unity, voir MIGRATION_REPORT.md.
    /// </summary>
    public static class EnemyBuilder
    {
        static GameObject Part(Transform parent, string name, PrimitiveType t, Vector3 pos, Vector3 scale, Material m)
        {
            var go = GameObject.CreatePrimitive(t);
            go.name = name;
            Object.Destroy(go.GetComponent<Collider>());
            go.transform.SetParent(parent, false);
            go.transform.localPosition = pos;
            go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = m;
            return go;
        }

        static Transform Pivot(Transform parent, string name, Vector3 pos)
        {
            var g = new GameObject(name);
            g.transform.SetParent(parent, false);
            g.transform.localPosition = pos;
            return g.transform;
        }

        public static EnemyAI Build(Vector3 pos, int seed, Transform target, Health targetHealth, CityGeneratorRef city)
        {
            var rnd = new System.Random(seed);
            Color[] uniforms = { new Color(0.22f, 0.26f, 0.16f), new Color(0.3f, 0.28f, 0.2f), new Color(0.16f, 0.2f, 0.24f) };
            Color uni = uniforms[rnd.Next(uniforms.Length)];
            Material mUni = Mats.Lit(uni, 0f, 0.15f);
            Material mVest = Mats.Lit(new Color(0.08f, 0.09f, 0.08f), 0f, 0.2f);
            Material mSkin = Mats.Lit(new Color(0.2f + (float)rnd.NextDouble() * 0.1f, 0.13f, 0.1f), 0f, 0.45f);
            Material mGun = Mats.Lit(new Color(0.07f, 0.07f, 0.07f), 0.7f, 0.45f);
            Material mHelm = Mats.Lit(new Color(0.12f, 0.14f, 0.1f), 0f, 0.25f);

            var root = new GameObject("Soldat");
            root.transform.position = pos;
            var cc = root.AddComponent<CharacterController>();
            cc.height = 1.8f; cc.radius = 0.3f; cc.center = new Vector3(0, 0.9f, 0); cc.stepOffset = 0.3f;

            var body = Pivot(root.transform, "Body", Vector3.zero);
            Part(body, "pelvis", PrimitiveType.Cube, new Vector3(0, 0.95f, 0), new Vector3(0.36f, 0.2f, 0.22f), mUni);
            Part(body, "torso", PrimitiveType.Cube, new Vector3(0, 1.28f, 0), new Vector3(0.4f, 0.48f, 0.22f), mUni);
            Part(body, "vest", PrimitiveType.Cube, new Vector3(0, 1.3f, 0.005f), new Vector3(0.44f, 0.34f, 0.27f), mVest);
            var head = Part(body, "head", PrimitiveType.Sphere, new Vector3(0, 1.66f, 0), new Vector3(0.2f, 0.24f, 0.22f), mSkin);
            Part(body, "helmet", PrimitiveType.Sphere, new Vector3(0, 1.72f, 0), new Vector3(0.25f, 0.2f, 0.27f), mHelm);

            // Hit zone tête (le collider de la sphère est recréé).
            var hc = head.AddComponent<SphereCollider>();
            hc.radius = 0.55f;
            var hz = head.AddComponent<HitZone>();
            hz.IsHead = true; hz.Multiplier = 2.5f;

            Transform legL = Pivot(body, "LegL", new Vector3(-0.1f, 0.9f, 0));
            Transform legR = Pivot(body, "LegR", new Vector3(0.1f, 0.9f, 0));
            foreach (var l in new[] { legL, legR })
            {
                Part(l, "leg", PrimitiveType.Cube, new Vector3(0, -0.42f, 0), new Vector3(0.14f, 0.84f, 0.16f), mUni);
                Part(l, "boot", PrimitiveType.Cube, new Vector3(0, -0.86f, 0.03f), new Vector3(0.15f, 0.1f, 0.26f), mVest);
            }
            Transform armL = Pivot(body, "ArmL", new Vector3(-0.27f, 1.5f, 0));
            Transform armR = Pivot(body, "ArmR", new Vector3(0.27f, 1.5f, 0));
            foreach (var a in new[] { armL, armR })
            {
                Part(a, "arm", PrimitiveType.Cube, new Vector3(0, -0.27f, 0), new Vector3(0.1f, 0.54f, 0.11f), mUni);
                Part(a, "hand", PrimitiveType.Sphere, new Vector3(0, -0.57f, 0), new Vector3(0.09f, 0.09f, 0.09f), mSkin);
            }

            // Arme tenue en avant, solidaire du bras droit.
            var gun = Pivot(armR, "Gun", new Vector3(-0.05f, -0.55f, 0.05f));
            gun.localRotation = Quaternion.Euler(85f, 0, 0);
            Part(gun, "gunBody", PrimitiveType.Cube, new Vector3(0, 0.12f, 0), new Vector3(0.06f, 0.5f, 0.09f), mGun);
            var muz = Pivot(gun, "Muzzle", new Vector3(0, 0.4f, 0));
            var light = muz.gameObject.AddComponent<Light>();
            light.type = LightType.Point; light.range = 5f; light.intensity = 0f;
            light.color = new Color(1f, 0.7f, 0.3f); light.shadows = LightShadows.None;

            var health = root.AddComponent<Health>();
            health.Init(70f);
            var anim = root.AddComponent<EnemyAnimator>();
            anim.LegL = legL; anim.LegR = legR; anim.ArmL = armL; anim.ArmR = armR; anim.Body = body; anim.MuzzleLight = light;

            var ai = root.AddComponent<EnemyAI>();
            ai.Init(target, targetHealth, city, muz, anim, rnd);
            return ai;
        }
    }
}

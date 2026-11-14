using System.Collections.Generic;
using UnityEngine;
using Nightfall.AI;
using Nightfall.Combat;
using Nightfall.Core;

namespace Nightfall.Missions
{
    /// <summary>Balise lumineuse pulsante marquant un objectif dans le monde.</summary>
    public class MissionMarker : MonoBehaviour
    {
        float t;
        Vector3 baseScale;

        public static MissionMarker Create(Transform parent, Vector3 pos, Color color, string name)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            go.name = name;
            Object.Destroy(go.GetComponent<Collider>());
            go.transform.SetParent(parent, false);
            go.transform.position = pos + Vector3.up * 3f;
            go.transform.localScale = new Vector3(0.7f, 3f, 0.7f);
            var r = go.GetComponent<Renderer>();
            r.sharedMaterial = Mats.Unlit(color);
            r.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            var m = go.AddComponent<MissionMarker>();
            m.baseScale = go.transform.localScale;
            return m;
        }

        void Update()
        {
            t += Time.deltaTime * 2f;
            float k = 1f + Mathf.Sin(t) * 0.12f;
            transform.localScale = new Vector3(baseScale.x * k, baseScale.y, baseScale.z * k);
        }
    }

    /// <summary>Objet à ramasser (preuve numérique / téléphone) : boîte émissive qui tourne.</summary>
    public class Pickup : MonoBehaviour
    {
        public static Pickup Create(Transform parent, Vector3 pos, string name)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cube);
            go.name = name;
            Object.Destroy(go.GetComponent<Collider>());
            go.transform.SetParent(parent, false);
            go.transform.position = pos + Vector3.up * 0.9f;
            go.transform.localScale = new Vector3(0.18f, 0.32f, 0.04f);
            go.GetComponent<Renderer>().sharedMaterial = Mats.Lit(new Color(0.05f, 0.1f, 0.12f), 0.3f, 0.7f, new Color(0.2f, 1.2f, 1.6f));
            return go.AddComponent<Pickup>();
        }

        void Update() { transform.Rotate(0f, 120f * Time.deltaTime, 0f, Space.World); }
    }

    /// <summary>Civil à escorter : suit le joueur par chemin A*, peut être blessé (tirs du joueur).</summary>
    public class Civilian : MonoBehaviour
    {
        public Transform Leader;
        public bool Following;
        public Health Health;
        CharacterController cc;
        readonly List<Vector3> path = new List<Vector3>();
        int idx;
        float timer;
        Vector3 goal = new Vector3(1e6f, 0f, 1e6f);
        public bool Alive { get { return Health != null && !Health.IsDead; } }

        void Awake() { cc = GetComponent<CharacterController>(); }

        void OnDied()
        {
            if (cc != null) cc.enabled = false;
            transform.rotation = Quaternion.Euler(90f, transform.eulerAngles.y, 0f);
            transform.position += Vector3.up * 0.2f;
        }

        public void Hook() { Health.Died += OnDied; }

        void Update()
        {
            if (!Alive || !Following || Leader == null || Time.timeScale == 0f) return;
            Vector3 to = Leader.position - transform.position; to.y = 0f;
            float d = to.magnitude;
            if (d < 3.5f) return;

            NavGrid grid = NavGrid.Current;
            Vector3 steer = Leader.position;
            if (grid != null)
            {
                timer -= Time.deltaTime;
                Vector3 gv = Leader.position - goal; gv.y = 0f;
                if ((gv.sqrMagnitude > 9f || idx >= path.Count) && timer <= 0f)
                {
                    timer = 0.5f; goal = Leader.position;
                    grid.FindPath(transform.position, Leader.position, path);
                    idx = 0;
                }
                while (idx < path.Count)
                {
                    Vector3 pd = path[idx] - transform.position; pd.y = 0f;
                    if (pd.sqrMagnitude < 0.64f) idx++; else break;
                }
                if (idx < path.Count) steer = path[idx];
            }
            Vector3 dir = steer - transform.position; dir.y = 0f;
            if (dir.sqrMagnitude < 0.01f) return;
            dir.Normalize();
            transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(dir), 8f * Time.deltaTime);
            cc.SimpleMove(dir * (d > 10f ? 5.6f : 3.4f));
        }
    }

    public static class ActorFactory
    {
        static GameObject Part(Transform parent, PrimitiveType t, Vector3 pos, Vector3 scale, Material m)
        {
            var go = GameObject.CreatePrimitive(t);
            Object.Destroy(go.GetComponent<Collider>());
            go.transform.SetParent(parent, false);
            go.transform.localPosition = pos; go.transform.localScale = scale;
            go.GetComponent<Renderer>().sharedMaterial = m;
            return go;
        }

        /// <summary>Personnage civil procédural (PROVISOIRE : pas un modèle 3D final).</summary>
        public static GameObject Person(Transform parent, Vector3 pos, Color shirt, string name, float hp, bool civilian)
        {
            var root = new GameObject(name);
            root.transform.SetParent(parent, false);
            root.transform.position = pos;
            var cc = root.AddComponent<CharacterController>();
            cc.height = 1.75f; cc.radius = 0.3f; cc.center = new Vector3(0f, 0.9f, 0f); cc.stepOffset = 0.3f;
            var hl = root.AddComponent<Health>();
            hl.Init(hp);
            Material mShirt = Mats.Lit(shirt, 0f, 0.2f);
            Material mPants = Mats.Lit(new Color(0.08f, 0.1f, 0.16f), 0f, 0.2f);
            Material mSkin = Mats.Lit(new Color(0.22f, 0.14f, 0.1f), 0f, 0.4f);
            Part(root.transform, PrimitiveType.Cube, new Vector3(0f, 0.5f, 0f), new Vector3(0.34f, 0.8f, 0.2f), mPants);
            Part(root.transform, PrimitiveType.Cube, new Vector3(0f, 1.2f, 0f), new Vector3(0.42f, 0.55f, 0.24f), mShirt);
            Part(root.transform, PrimitiveType.Sphere, new Vector3(0f, 1.62f, 0f), new Vector3(0.22f, 0.26f, 0.24f), mSkin);
            if (civilian)
            {
                var c = root.AddComponent<Civilian>();
                c.Health = hl; c.Hook();
            }
            return root;
        }
    }
}

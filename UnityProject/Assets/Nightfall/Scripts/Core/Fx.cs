using UnityEngine;
using Nightfall.Audio;

namespace Nightfall.Core
{
    /// <summary>Effets visuels instanciés à la volée (impacts, sang, traceurs, douilles).</summary>
    public static class Fx
    {
        static void Burst(Vector3 pos, Vector3 normal, Color col, int count, float speed, float life, float size, float gravity)
        {
            var go = new GameObject("fx");
            go.transform.position = pos;
            go.transform.rotation = Quaternion.LookRotation(normal.sqrMagnitude < 0.001f ? Vector3.up : normal);
            var ps = go.AddComponent<ParticleSystem>();
            ps.Stop(true, ParticleSystemStopBehavior.StopEmittingAndClear);
            var main = ps.main;
            main.duration = 0.3f; main.loop = false; main.playOnAwake = false;
            main.startLifetime = life; main.startSpeed = speed; main.startSize = size;
            main.startColor = col; main.gravityModifier = gravity;
            main.simulationSpace = ParticleSystemSimulationSpace.World;
            main.maxParticles = count + 4;
            var em = ps.emission;
            em.rateOverTime = 0f;
            em.SetBursts(new[] { new ParticleSystem.Burst(0f, (short)count) });
            var sh = ps.shape;
            sh.shapeType = ParticleSystemShapeType.Cone; sh.angle = 35f; sh.radius = 0.02f;
            var r = go.GetComponent<ParticleSystemRenderer>();
            r.sharedMaterial = Mats.Particle();
            ps.Play();
            Object.Destroy(go, life + 0.6f);
        }

        public static void Impact(Vector3 p, Vector3 n)
        {
            Burst(p + n * 0.02f, n, new Color(0.75f, 0.7f, 0.6f, 1f), 7, 3f, 0.45f, 0.05f, 0.8f);
            Burst(p + n * 0.02f, n, new Color(1f, 0.8f, 0.4f, 1f), 3, 6f, 0.15f, 0.03f, 0f);
        }

        public static void Blood(Vector3 p, Vector3 n)
        {
            Burst(p, n, new Color(0.55f, 0.02f, 0.02f, 1f), 9, 2.5f, 0.5f, 0.06f, 1.2f);
        }

        public static void Tracer(Vector3 a, Vector3 b, Color c)
        {
            var go = new GameObject("tracer");
            var lr = go.AddComponent<LineRenderer>();
            lr.positionCount = 2;
            lr.SetPosition(0, a); lr.SetPosition(1, b);
            lr.startWidth = 0.025f; lr.endWidth = 0.008f;
            lr.sharedMaterial = Mats.Unlit(c);
            lr.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            lr.receiveShadows = false;
            Object.Destroy(go, 0.06f);
        }

        public static void Casing(Vector3 pos, Vector3 right)
        {
            var go = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
            go.name = "casing";
            go.transform.position = pos;
            go.transform.localScale = new Vector3(0.012f, 0.02f, 0.012f);
            go.GetComponent<Renderer>().sharedMaterial = Mats.Lit(new Color(0.8f, 0.6f, 0.2f), 0.9f, 0.6f);
            var rb = go.AddComponent<Rigidbody>();
            rb.AddForce((right + Vector3.up * 0.6f) * 1.5f, ForceMode.Impulse);
            rb.AddTorque(Random.insideUnitSphere * 0.02f, ForceMode.Impulse);
            Object.Destroy(go, 2.5f);
        }
    }
}

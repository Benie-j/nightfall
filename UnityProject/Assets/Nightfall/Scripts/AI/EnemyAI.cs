using UnityEngine;
using Nightfall.Audio;
using Nightfall.Combat;
using Nightfall.Core;
using Nightfall.World;

namespace Nightfall.AI
{
    public delegate System.Collections.Generic.IReadOnlyList<Collider> CityGeneratorRef();

    public enum EnemyState { Patrol, Alert, Chase, Attack, Cover, Retreat, Dead }

    /// <summary>
    /// IA par machine à états : patrouille, alerte (bruit / tir subi), poursuite, attaque, couverture,
    /// repli, mort. Déplacement par CharacterController, chemins A* sur NavGrid (pas de NavMesh : package indisponible hors ligne) + évitement local par raycasts.
    /// </summary>
    [RequireComponent(typeof(CharacterController))]
    public class EnemyAI : MonoBehaviour
    {
        public EnemyState State { get; private set; }

        Transform target;
        Health targetHealth, health;
        CityGeneratorRef coverSource;
        Transform muzzle;
        EnemyAnimator anim;
        CharacterController cc;

        Vector3 home, waypoint, lastKnown, coverPos;
        float stateTime, timeSinceSeen = 99f, fireTimer, waitTimer, lastHitTime = -99f, accuracy, damage, fireInterval;
        bool usedCover;

        public void Init(Transform t, Health th, CityGeneratorRef cover, Transform muzzleT, EnemyAnimator a, System.Random rnd)
        {
            target = t; targetHealth = th; coverSource = cover; muzzle = muzzleT; anim = a;
            cc = GetComponent<CharacterController>();
            health = GetComponent<Health>();
            home = transform.position;
            waypoint = home;
            accuracy = 0.35f + (float)rnd.NextDouble() * 0.25f;
            damage = 5f + (float)rnd.NextDouble() * 3f;
            fireInterval = 0.35f + (float)rnd.NextDouble() * 0.3f;
            fireTimer = 1f;
            health.Damaged += OnDamaged;
            health.Died += OnDied;
            Noise.Emitted += OnNoise;
            Enter(EnemyState.Patrol);
        }

        void OnDestroy() { Noise.Emitted -= OnNoise; }

        void OnNoise(Vector3 pos, float radius)
        {
            if (State == EnemyState.Dead || State == EnemyState.Attack || State == EnemyState.Chase) return;
            if ((pos - transform.position).sqrMagnitude < radius * radius)
            {
                lastKnown = pos;
                Enter(EnemyState.Alert);
            }
        }

        void OnDamaged(float amount, Vector3 from)
        {
            lastHitTime = Time.time;
            if (State == EnemyState.Patrol || State == EnemyState.Alert)
            {
                lastKnown = from;
                Enter(EnemyState.Chase);
            }
        }

        void OnDied()
        {
            Enter(EnemyState.Dead);
            Noise.Emitted -= OnNoise;
            cc.enabled = false;
            anim.Die();
            var col = GetComponentInChildren<SphereCollider>();
            if (col != null) col.enabled = false;
            Destroy(gameObject, 12f);
        }

        void Enter(EnemyState s)
        {
            State = s; stateTime = 0f;
            anim.Aiming = (s == EnemyState.Attack || s == EnemyState.Chase);
            anim.Crouched = (s == EnemyState.Cover);
            if (s == EnemyState.Cover) { coverPos = FindCover(); waitTimer = 0f; usedCover = true; }
            if (s == EnemyState.Patrol) PickWaypoint();
        }

        void PickWaypoint()
        {
            Vector2 r = Random.insideUnitCircle * 12f;
            waypoint = home + new Vector3(r.x, 0f, r.y);
        }

        Vector3 Eye { get { return transform.position + Vector3.up * 1.6f; } }
        Vector3 TargetChest { get { return target.position + Vector3.up * 1.2f; } }

        bool CanSee()
        {
            if (targetHealth == null || targetHealth.IsDead) return false;
            Vector3 to = TargetChest - Eye;
            float dist = to.magnitude;
            if (dist > QualityProfile.EnemySightRange) return false;
            if (dist > 8f && Vector3.Angle(transform.forward, to) > 55f) return false;
            RaycastHit hit;
            if (Physics.Raycast(Eye, to.normalized, out hit, dist + 0.5f, ~0, QueryTriggerInteraction.Ignore))
                return hit.transform == target || hit.transform.IsChildOf(target);
            return true;
        }

        void Update()
        {
            if (State == EnemyState.Dead || Time.timeScale == 0f) return;
            float dt = Time.deltaTime;
            stateTime += dt;
            timeSinceSeen += dt;
            fireTimer -= dt;

            bool see = CanSee();
            if (see) { timeSinceSeen = 0f; lastKnown = target.position; }
            float dist = Vector3.Distance(transform.position, target.position);
            bool hurt = health.Fraction < 0.5f;
            bool critical = health.Fraction < 0.25f;
            anim.Speed = 0f;

            switch (State)
            {
                case EnemyState.Patrol:
                    MoveTo(waypoint, 1.6f);
                    if (Flat(waypoint - transform.position).magnitude < 1.5f || stateTime > 8f) PickWaypoint();
                    if (see) Enter(EnemyState.Chase);
                    break;

                case EnemyState.Alert:
                    MoveTo(lastKnown, 2.6f);
                    if (see) Enter(EnemyState.Chase);
                    else if (Flat(lastKnown - transform.position).magnitude < 2f && stateTime > 4f) Enter(EnemyState.Patrol);
                    else if (stateTime > 12f) Enter(EnemyState.Patrol);
                    break;

                case EnemyState.Chase:
                    MoveTo(lastKnown, 3.4f);
                    if (see && dist < 26f) Enter(EnemyState.Attack);
                    else if (timeSinceSeen > 6f) Enter(EnemyState.Alert);
                    break;

                case EnemyState.Attack:
                    Face(see ? target.position : lastKnown);
                    if (see && fireTimer <= 0f) Shoot();
                    if (critical) Enter(EnemyState.Retreat);
                    else if ((hurt || Time.time - lastHitTime < 0.6f && Random.value < 0.01f) && !usedCover) Enter(EnemyState.Cover);
                    else if (!see && timeSinceSeen > 1.5f) Enter(EnemyState.Chase);
                    else if (dist > 30f) Enter(EnemyState.Chase);
                    else if (dist < 6f) MoveTo(transform.position - Flat(target.position - transform.position).normalized * 3f, 2.4f);
                    break;

                case EnemyState.Cover:
                    if (Flat(coverPos - transform.position).magnitude > 0.8f && stateTime < 5f) MoveTo(coverPos, 3.8f);
                    else
                    {
                        waitTimer += dt;
                        Face(target.position);
                        if (critical) Enter(EnemyState.Retreat);
                        else if (waitTimer > 3f) { usedCover = false; Enter(EnemyState.Attack); }
                    }
                    break;

                case EnemyState.Retreat:
                    MoveTo(transform.position + Flat(transform.position - target.position).normalized * 6f, 3.6f);
                    if (stateTime > 6f) Enter(EnemyState.Alert);
                    break;
            }
        }

        static Vector3 Flat(Vector3 v) { v.y = 0f; return v; }

        void Face(Vector3 p)
        {
            Vector3 d = Flat(p - transform.position);
            if (d.sqrMagnitude < 0.01f) return;
            transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(d), 8f * Time.deltaTime);
        }

        readonly System.Collections.Generic.List<Vector3> path = new System.Collections.Generic.List<Vector3>();
        int pathIdx;
        Vector3 pathGoal = new Vector3(1e6f, 0f, 1e6f);
        float repathTimer;

        void MoveTo(Vector3 dest, float speed)
        {
            Vector3 steer = dest;
            NavGrid grid = NavGrid.Current;
            if (grid != null)
            {
                repathTimer -= Time.deltaTime;
                bool goalMoved = Flat(dest - pathGoal).sqrMagnitude > 4f;
                if ((goalMoved || pathIdx >= path.Count) && repathTimer <= 0f)
                {
                    repathTimer = 0.4f + Random.value * 0.3f;
                    pathGoal = dest;
                    grid.FindPath(transform.position, dest, path);
                    pathIdx = 0;
                }
                while (pathIdx < path.Count && Flat(path[pathIdx] - transform.position).sqrMagnitude < 0.64f) pathIdx++;
                if (pathIdx < path.Count) steer = path[pathIdx];
            }

            Vector3 d = Flat(steer - transform.position);
            if (d.magnitude < 0.4f) return;
            d.Normalize();
            d = Avoid(d);
            transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(d), 7f * Time.deltaTime);
            cc.SimpleMove(d * speed);
            anim.Speed = speed;
        }

        Vector3 Avoid(Vector3 dir)
        {
            Vector3 o = transform.position + Vector3.up * 0.7f;
            if (!Physics.Raycast(o, dir, 1.6f, ~0, QueryTriggerInteraction.Ignore)) return dir;
            float[] angles = { 45f, -45f, 90f, -90f, 135f };
            foreach (float a in angles)
            {
                Vector3 d = Quaternion.Euler(0, a, 0) * dir;
                if (!Physics.Raycast(o, d, 1.6f, ~0, QueryTriggerInteraction.Ignore)) return d;
            }
            return -dir;
        }

        Vector3 FindCover()
        {
            Vector3 best = transform.position;
            float bestD = 9999f;
            var list = coverSource != null ? coverSource() : null;
            if (list == null) return best;
            for (int i = 0; i < list.Count; i++)
            {
                Collider c = list[i];
                if (c == null) continue;
                Vector3 cp = c.bounds.center;
                float d = Flat(cp - transform.position).magnitude;
                if (d > 25f || d >= bestD) continue;
                Vector3 away = Flat(cp - target.position).normalized;
                Vector3 cand = cp + away * (Mathf.Max(c.bounds.extents.x, c.bounds.extents.z) + 1f);
                cand.y = transform.position.y;
                RaycastHit hit;
                Vector3 from = cand + Vector3.up * 1.2f;
                if (Physics.Linecast(from, TargetChest, out hit, ~0, QueryTriggerInteraction.Ignore) && hit.collider == c)
                { best = cand; bestD = d; }
            }
            return best;
        }

        void Shoot()
        {
            fireTimer = fireInterval;
            anim.Fire();
            float dist = Vector3.Distance(transform.position, target.position);
            float p = accuracy * Mathf.Clamp01(1.25f - dist / 55f);
            Vector3 aim = TargetChest;
            bool hit = Random.value < p;
            if (!hit) aim += Random.insideUnitSphere * 1.2f;
            Fx.Tracer(muzzle.position, aim, new Color(1f, 0.6f, 0.3f));
            ProcAudio.Play(ProcAudio.Rifle, muzzle.position, 0.9f, Random.Range(0.85f, 0.95f));
            if (hit && targetHealth != null) targetHealth.TakeDamage(damage, transform.position);
        }
    }
}

using System.Collections.Generic;
using UnityEngine;
using Nightfall.AI;
using Nightfall.Audio;
using Nightfall.Combat;
using Nightfall.Core;
using Nightfall.Player;
using Nightfall.SaveSystem;
using Nightfall.UI;
using Nightfall.Weapons;
using Nightfall.World;

namespace Nightfall.Missions
{
    /// <summary>
    /// Assemble et pilote une mission : ville, navigation, joueur, armes, ennemis, HUD, objectifs
    /// (atteindre / interagir / récupérer / escorter / éliminer) et conditions de victoire / échec.
    /// </summary>
    public class MissionController : MonoBehaviour
    {
        public MissionDef Def { get; private set; }
        CityGenerator city;
        OsmWorld osm;                        // carte OpenStreetMap (si les données sont présentes)
        Vector3[] osmObjPos;
        Vector3 osmSafe;
        public bool UsesOsmMap { get { return osm != null; } }
        PlayerController player;
        WeaponHolder weapons;
        HudView hud;
        int total, killed;
        float elapsed, endTimer = -1f;
        bool finished;
        string failReason;
        System.Action<MissionController, bool, float, int> onEnd;

        // Objectifs
        int objIndex = -1;
        int completedObjectives;
        ObjectiveDef objective;
        Vector3 objPos;
        GameObject objActor;                 // contact, preuve ou balise
        MissionMarker objMarker, safeMarker;
        Vector3 safePos;
        readonly List<Civilian> civilians = new List<Civilian>();

        public int CompletedObjectives { get { return completedObjectives; } }

        public static MissionController Create(MissionDef def, System.Action onPause, System.Action<MissionController, bool, float, int> onEnd)
        {
            var root = new GameObject("MissionRoot");
            var mc = root.AddComponent<MissionController>();
            mc.Begin(def, onPause, onEnd);
            return mc;
        }

        void Begin(MissionDef def, System.Action onPause, System.Action<MissionController, bool, float, int> end)
        {
            Def = def; onEnd = end;
            TouchInput.ResetAll();

            bool low = QualityProfile.UseLowProfile;
            Vector3 startPos;
            float startYaw = 0f;
            if (def.Number == 1 && OsmWorld.Available)
            {
                osm = OsmWorld.Create(transform);
            }
            if (osm != null)
            {
                NavGrid.Current = NavGrid.BuildFromPhysics(osm.MinX, osm.MaxX, osm.MinZ, osm.MaxZ, 3f, 0.4f);
                startPos = NavGrid.Current.Snap(osm.PlayerStart);
                Vector3 dir = osm.Ficgayo - osm.Siporex;
                startYaw = Mathf.Atan2(dir.x, dir.z) * Mathf.Rad2Deg;
                ComputeOsmObjectives(def);
            }
            else
            {
                var cityGo = new GameObject("Ville");
                cityGo.transform.SetParent(transform, false);
                city = cityGo.AddComponent<CityGenerator>();
                city.Build(def.Seed, def.SectorCount);

                // Navigation : grille échantillonnée sur les colliders réels, avant l'apparition des personnages.
                float len = def.SectorCount * CityGenerator.SectorLength;
                NavGrid.Current = NavGrid.BuildFromPhysics(-32f, 32f, -6f, len + 6f, low ? 2f : 1.5f, 0.35f);
                startPos = city.PlayerStart;
            }

            // Joueur
            var pgo = new GameObject("Joueur");
            pgo.transform.SetParent(transform, false);
            pgo.transform.position = startPos;
            var cc = pgo.AddComponent<CharacterController>();
            cc.height = 1.8f; cc.radius = 0.3f; cc.center = new Vector3(0, 0.9f, 0); cc.stepOffset = 0.3f;
            var health = pgo.AddComponent<Health>();
            health.Init(100f);
            player = pgo.AddComponent<PlayerController>();
            player.Health = health;
            player.SetYaw(startYaw);

            var camGo = new GameObject("Camera");
            camGo.tag = "MainCamera";
            camGo.transform.SetParent(pgo.transform, false);
            camGo.transform.localPosition = new Vector3(0, 1.65f, 0);
            var cam = camGo.AddComponent<Camera>();
            cam.nearClipPlane = 0.03f;
            cam.fieldOfView = 72f;
            camGo.AddComponent<AudioListener>();
            player.Cam = cam;
            NightEnvironment.Apply(transform, cam);

            var holderGo = new GameObject("Armes");
            holderGo.transform.SetParent(camGo.transform, false);
            weapons = holderGo.AddComponent<WeaponHolder>();
            weapons.Init(player);

            hud = HudView.Create(transform, onPause);
            health.Damaged += OnPlayerDamaged;
            health.Died += OnPlayerDied;

            if (osm != null) osm.Target = pgo.transform;
            else
            {
                var streamer = gameObject.AddComponent<SectorStreamer>();
                streamer.City = city; streamer.Target = pgo.transform;
                city.ShowWindow(0, QualityProfile.SectorWindow);
            }

            SpawnEnemies(def, pgo.transform, health);
            NextObjective();
        }

        void SpawnEnemies(MissionDef def, Transform target, Health targetHealth)
        {
            if (osm != null)
            {
                var none = new List<Collider>();
                CityGeneratorRef osmCover = () => none;
                int step = Mathf.Max(1, osm.SpawnPoints.Count / Mathf.Max(1, def.EnemyCount));
                for (int i = 0; i < def.EnemyCount && i * step < osm.SpawnPoints.Count; i++)
                {
                    Vector3 p = NavGrid.Current.Snap(osm.SpawnPoints[i * step]);
                    EnemyAI ai = EnemyBuilder.Build(p, def.Seed * 31 + i, target, targetHealth, osmCover);
                    ai.transform.SetParent(transform, true);
                    ai.GetComponent<Health>().Died += OnEnemyDied;
                    total++;
                }
                return;
            }

            int sectors = city.Sectors.Count;
            CityGeneratorRef cover = () => city.CoverColliders;
            for (int i = 0; i < def.EnemyCount; i++)
            {
                int s = 1 + (i % Mathf.Max(1, sectors - 1));
                var pts = city.SpawnPoints[s];
                if (pts.Count == 0) continue;
                Vector3 p = pts[(i / Mathf.Max(1, sectors - 1)) % pts.Count];
                EnemyAI ai = EnemyBuilder.Build(p, def.Seed * 31 + i, target, targetHealth, cover);
                ai.transform.SetParent(city.Sectors[s].transform, true);
                ai.GetComponent<Health>().Died += OnEnemyDied;
                total++;
            }
        }

        /// <summary>Positions des objectifs sur la carte OSM, déduites des deux repères documentés (Siporex, Ficgayo).</summary>
        void ComputeOsmObjectives(MissionDef def)
        {
            Vector3 s = osm.Siporex, f = osm.Ficgayo;
            Vector3 dir = (f - s); dir.y = 0f;
            Vector3 n = dir.normalized;
            Vector3 perp = new Vector3(-n.z, 0f, n.x);
            osmObjPos = new Vector3[def.Objectives.Count];
            for (int i = 0; i < osmObjPos.Length; i++)
            {
                float t = osmObjPos.Length == 1 ? 1f : i / (float)(osmObjPos.Length - 1);
                Vector3 p = Vector3.Lerp(s, f, t);
                switch (def.Objectives[i].Id)
                {
                    case "reach_siporex": p = s; break;
                    case "find_contact": p = s + n * 35f + perp * 8f; break;
                    case "reach_figayo": p = f; break;
                    case "recover_evidence": p = f + perp * 40f; break;
                    case "escort_civilians": p = f + n * 20f; break;
                }
                osmObjPos[i] = NavGrid.Current.Snap(p);
            }
            osmSafe = NavGrid.Current.Snap(f + n * 150f);
        }

        void OnEnemyDied() { killed++; }
        void OnPlayerDamaged(float amount, Vector3 from) { hud.DamageFlash(); }
        void OnPlayerDied() { failReason = "Tu es tombé au combat."; Finish(false); }

        // ------------------------------------------------------------------ Objectifs
        Vector3 PlaceOnStreet(float z, float x)
        {
            Vector3 p = new Vector3(x, 0.2f, z);
            return NavGrid.Current != null ? NavGrid.Current.Snap(p) : p;
        }

        void ClearObjectiveVisuals()
        {
            if (objActor != null) Destroy(objActor);
            if (objMarker != null) Destroy(objMarker.gameObject);
            if (safeMarker != null) Destroy(safeMarker.gameObject);
            objActor = null; objMarker = null; safeMarker = null;
        }

        void NextObjective()
        {
            ClearObjectiveVisuals();
            objIndex++;
            if (objIndex >= Def.Objectives.Count) { objective = null; endTimer = 1.5f; return; }
            objective = Def.Objectives[objIndex];
            objPos = osm != null ? osmObjPos[objIndex] : PlaceOnStreet(objective.Z, (objIndex % 2 == 0 ? -2.5f : 2.5f));

            Color beacon = new Color(1f, 0.75f, 0.2f);
            switch (objective.Type)
            {
                case ObjectiveType.Reach:
                    objMarker = MissionMarker.Create(transform, objPos, beacon, "Balise_" + objective.Id);
                    break;
                case ObjectiveType.Interact:
                    objActor = ActorFactory.Person(transform, objPos, new Color(0.45f, 0.4f, 0.12f), "Contact_" + objective.Id, 100f, false);
                    objMarker = MissionMarker.Create(transform, objPos + Vector3.right * 0.01f, new Color(0.3f, 0.9f, 1f), "Balise_" + objective.Id);
                    break;
                case ObjectiveType.Collect:
                    objActor = Pickup.Create(transform, objPos, "Preuve_" + objective.Id).gameObject;
                    objMarker = MissionMarker.Create(transform, objPos, new Color(0.3f, 0.9f, 1f), "Balise_" + objective.Id);
                    break;
                case ObjectiveType.Escort:
                    StartEscort();
                    break;
                case ObjectiveType.Eliminate:
                    break;
            }
        }

        void StartEscort()
        {
            civilians.Clear();
            Color[] shirts = { new Color(0.55f, 0.2f, 0.12f), new Color(0.2f, 0.35f, 0.5f), new Color(0.5f, 0.45f, 0.15f) };
            for (int i = 0; i < 3; i++)
            {
                Vector3 p = osm != null ? NavGrid.Current.Snap(objPos + new Vector3(-2f + i * 2f, 0f, 0f)) : PlaceOnStreet(objective.Z + i * 1.5f, -3f + i * 2f);
                var go = ActorFactory.Person(transform, p, shirts[i], "Civil_" + i, 40f, true);
                var c = go.GetComponent<Civilian>();
                c.Leader = player.transform; c.Following = true;
                civilians.Add(c);
            }
            float len = Def.SectorCount * CityGenerator.SectorLength;
            safePos = osm != null ? osmSafe : PlaceOnStreet(len - 20f, 0f);
            safeMarker = MissionMarker.Create(transform, safePos, new Color(0.3f, 1f, 0.4f), "ZoneSure");
        }

        static float Flat(Vector3 a, Vector3 b) { a.y = 0f; b.y = 0f; return Vector3.Distance(a, b); }

        void CompleteObjective()
        {
            completedObjectives++;
            ProcAudio.Play2D(ProcAudio.Hit, 0.8f);
            NextObjective();
        }

        void UpdateObjective()
        {
            if (objective == null) { hud.SetObjective("Mission accomplie"); return; }
            Vector3 pp = player.transform.position;
            string text = (objIndex + 1) + "/" + Def.Objectives.Count + "  " + objective.Title;
            switch (objective.Type)
            {
                case ObjectiveType.Reach:
                {
                    float d = Flat(pp, objPos);
                    text += "  —  " + Mathf.RoundToInt(d) + " m";
                    if (d < 3.5f) CompleteObjective();
                    break;
                }
                case ObjectiveType.Interact:
                {
                    float d = Flat(pp, objPos);
                    text += d < 3f ? "  —  appuie sur ACTION" : "  —  " + Mathf.RoundToInt(d) + " m";
                    if (d < 3f && TouchInput.InteractPressed) { TouchInput.InteractPressed = false; CompleteObjective(); }
                    break;
                }
                case ObjectiveType.Collect:
                {
                    float d = Flat(pp, objPos);
                    text += "  —  " + Mathf.RoundToInt(d) + " m";
                    if (d < 2f) CompleteObjective();
                    break;
                }
                case ObjectiveType.Escort:
                {
                    int alive = 0, safe = 0;
                    for (int i = 0; i < civilians.Count; i++)
                    {
                        if (!civilians[i].Alive) continue;
                        alive++;
                        if (Flat(civilians[i].transform.position, safePos) < 7f) safe++;
                    }
                    text += "  —  civils : " + safe + "/" + alive + " en sécurité, zone à " + Mathf.RoundToInt(Flat(pp, safePos)) + " m";
                    if (alive == 0) { failReason = "Tous les civils ont été tués."; Finish(false); }
                    else if (safe == alive && Flat(pp, safePos) < 12f) CompleteObjective();
                    break;
                }
                case ObjectiveType.Eliminate:
                {
                    text += "  —  " + killed + " / " + total;
                    if (killed >= total) CompleteObjective();
                    break;
                }
            }
            hud.SetObjective(text);
        }

        // ------------------------------------------------------------------ Fin
        void Finish(bool win)
        {
            if (finished) return;
            finished = true;
            TouchInput.ResetAll();
            if (win)
            {
                SaveData.UnlockUpTo(Def.Number + 1);
                SaveData.SubmitTime(Def.Number, elapsed);
            }
            if (NavGrid.Current != null) NavGrid.Current = null;
            if (onEnd != null) onEnd(this, win, elapsed, killed);
        }

        public string FailReason { get { return failReason; } }

        void OnDestroy() { NavGrid.Current = null; }

        void Update()
        {
            if (finished || Time.timeScale == 0f) return;
            elapsed += Time.deltaTime;
            hud.SetHealth(player.Health.Fraction);
            Weapon w = weapons.Current;
            if (w != null) hud.SetWeapon(w.Config.DisplayName, w.Ammo, w.Config.MagSize, w.Reloading);

            if (endTimer >= 0f)
            {
                hud.SetObjective("Mission accomplie");
                endTimer -= Time.deltaTime;
                if (endTimer <= 0f) Finish(true);
                return;
            }
            UpdateObjective();
        }

        void LateUpdate() { TouchInput.EndFrame(); }
    }
}

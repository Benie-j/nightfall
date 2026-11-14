using System;
using System.Collections.Generic;
using UnityEngine;

namespace Nightfall.Missions
{
    public enum ObjectiveType { Reach, Interact, Collect, Escort, Eliminate }

    public class ObjectiveDef
    {
        public string Id;
        public string Title;
        public ObjectiveType Type;
        /// <summary>Position le long de la rue, en mètres (génération procédurale). Absent des données d'origine : placement ajouté par la migration.</summary>
        public float Z;
        public bool FromSourceData;
    }

    public class MissionDef
    {
        public int Number;
        public string Title;
        public string Subtitle;
        public string Location;
        public string Briefing;
        public string Ending;
        public int EnemyCount;
        public int SectorCount;
        public int Seed;
        public bool HasSourceObjectives;
        public List<ObjectiveDef> Objectives = new List<ObjectiveDef>();
    }

    // ---- Formats JSON d'origine (data/story/campaign.json, data/missions/mission_01.json) ----
    [Serializable] public class CampaignMissionJson { public int id; public string title; public string description; }
    [Serializable] public class CampaignJson
    {
        public string title; public int year; public string genre;
        public string[] synopsis; public CampaignMissionJson[] missions;
    }
    [Serializable] public class ObjectiveJson { public string id; public string title; public string type; }
    [Serializable] public class MissionFileJson
    {
        public string id; public string title; public string subtitle; public string location;
        public string city; public string country; public int year;
        public ObjectiveJson[] objectives; public string ending;
    }
    [Serializable] public class IntroJson { public string title; public string[] pages; }

    /// <summary>
    /// Campagne chargée depuis Resources/Data (JSON repris du dépôt Godot).
    /// Seule la mission 1 possède un fichier d'objectifs dans la source : les missions 2 à 6 reçoivent des
    /// objectifs GÉNÉRIQUES (atteindre un point, éliminer les hostiles, rejoindre la sortie), marqués provisoires.
    /// </summary>
    public static class MissionDatabase
    {
        static List<MissionDef> all;
        static CampaignJson campaign;
        static IntroJson intro;

        public static List<MissionDef> All { get { if (all == null) Load(); return all; } }
        public static CampaignJson Campaign { get { if (all == null) Load(); return campaign; } }
        public static IntroJson Intro { get { if (intro == null) LoadIntro(); return intro; } }

        public static void Reload() { all = null; intro = null; }

        static readonly int[] Enemies = { 6, 9, 12, 15, 19, 24 };
        static readonly int[] Sectors = { 5, 5, 6, 6, 7, 8 };

        static void LoadIntro()
        {
            var ta = Resources.Load<TextAsset>("Data/intro");
            intro = ta != null ? JsonUtility.FromJson<IntroJson>(ta.text) : null;
            if (intro == null || intro.pages == null) intro = new IntroJson { title = "NIGHTFALL", pages = new string[0] };
        }

        public static void Load()
        {
            all = new List<MissionDef>();
            var ta = Resources.Load<TextAsset>("Data/campaign");
            campaign = ta != null ? JsonUtility.FromJson<CampaignJson>(ta.text) : null;
            if (campaign == null || campaign.missions == null || campaign.missions.Length == 0)
            {
                Debug.LogError("[Nightfall] Resources/Data/campaign.json introuvable ou invalide.");
                campaign = new CampaignJson { title = "NIGHTFALL", missions = new CampaignMissionJson[0] };
                return;
            }

            for (int i = 0; i < campaign.missions.Length; i++)
            {
                var cm = campaign.missions[i];
                var def = new MissionDef
                {
                    Number = cm.id,
                    Title = cm.title,
                    Briefing = cm.description,
                    EnemyCount = Enemies[Mathf.Clamp(i, 0, Enemies.Length - 1)],
                    SectorCount = Sectors[Mathf.Clamp(i, 0, Sectors.Length - 1)],
                    Seed = (i + 1) * 101
                };

                var file = Resources.Load<TextAsset>("Data/mission_" + cm.id.ToString("00"));
                MissionFileJson mf = file != null ? JsonUtility.FromJson<MissionFileJson>(file.text) : null;
                if (mf != null && mf.objectives != null && mf.objectives.Length > 0)
                {
                    def.HasSourceObjectives = true;
                    def.Subtitle = mf.subtitle; def.Location = mf.location; def.Ending = mf.ending;
                    float[] z = Placement(mf.objectives.Length, def.SectorCount);
                    for (int k = 0; k < mf.objectives.Length; k++)
                        def.Objectives.Add(new ObjectiveDef { Id = mf.objectives[k].id, Title = mf.objectives[k].title, Type = ParseType(mf.objectives[k].type), Z = z[k], FromSourceData = true });
                }
                else
                {
                    float len = def.SectorCount * 100f;
                    def.Objectives.Add(new ObjectiveDef { Id = "generic_reach", Title = "Atteindre le point de rendez-vous", Type = ObjectiveType.Reach, Z = len * 0.45f });
                    def.Objectives.Add(new ObjectiveDef { Id = "generic_eliminate", Title = "Neutraliser les hostiles", Type = ObjectiveType.Eliminate, Z = len * 0.7f });
                    def.Objectives.Add(new ObjectiveDef { Id = "generic_exit", Title = "Rejoindre la zone d'extraction", Type = ObjectiveType.Reach, Z = len - 25f });
                }
                all.Add(def);
            }
        }

        /// <summary>Répartit les objectifs le long de la rue (premier à ~12 % de la longueur, dernier à 100 m de la fin pour laisser une zone sûre derrière un objectif d'escorte).</summary>
        public static float[] Placement(int count, int sectors)
        {
            float len = sectors * 100f;
            var z = new float[count];
            for (int i = 0; i < count; i++)
                z[i] = Mathf.Lerp(len * 0.12f, len - 100f, count == 1 ? 1f : i / (float)(count - 1));
            return z;
        }

        public static ObjectiveType ParseType(string t)
        {
            switch ((t ?? "").ToLowerInvariant())
            {
                case "reach": return ObjectiveType.Reach;
                case "interact": return ObjectiveType.Interact;
                case "collect": return ObjectiveType.Collect;
                case "escort": return ObjectiveType.Escort;
                case "eliminate": return ObjectiveType.Eliminate;
                default: return ObjectiveType.Reach;
            }
        }
    }
}

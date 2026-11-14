using UnityEngine;
using UnityEngine.UI;
using Nightfall.Audio;
using Nightfall.Missions;
using Nightfall.Player;
using Nightfall.SaveSystem;
using Nightfall.UI;
using Nightfall.World;

namespace Nightfall.Core
{
    /// <summary>
    /// Enchaînement du jeu : menu principal -> campagne -> mission -> fin / pause.
    /// Une seule scène (Boot) ; le menu et chaque mission sont composés à l'exécution.
    /// </summary>
    public class GameFlow : MonoBehaviour
    {
        Transform screenHost;
        GameObject menuWorld, missionRoot;
        int selected = 1;
        MissionDef current;

        static readonly Color Panel = new Color(0.03f, 0.04f, 0.06f, 0.82f);
        static readonly Color Accent = new Color(0.55f, 0.12f, 0.1f, 0.95f);
        static readonly Color Neutral = new Color(0.12f, 0.15f, 0.2f, 0.95f);
        static readonly Color Disabled = new Color(0.1f, 0.1f, 0.1f, 0.6f);

        void Awake()
        {
            UIFactory.EnsureEventSystem();
            gameObject.AddComponent<TouchInput>();
            var canvas = UIFactory.NewCanvas("Screens", 20, transform);
            screenHost = canvas.transform;
            BuildMenuWorld();
            ShowMain();
        }

        // ------------------------------------------------------------ Monde du menu
        void BuildMenuWorld()
        {
            menuWorld = new GameObject("MenuWorld");
            var cityGo = new GameObject("Ville");
            cityGo.transform.SetParent(menuWorld.transform, false);
            var city = cityGo.AddComponent<CityGenerator>();
            city.Build(77, 2);
            city.ShowWindow(0, 2);
            var camGo = new GameObject("MenuCamera");
            camGo.tag = "MainCamera";
            camGo.transform.SetParent(menuWorld.transform, false);
            var cam = camGo.AddComponent<Camera>();
            cam.fieldOfView = 65f;
            camGo.AddComponent<AudioListener>();
            camGo.AddComponent<CameraOrbit>();
            NightEnvironment.Apply(menuWorld.transform, cam);
        }

        void ClearScreen() { for (int i = screenHost.childCount - 1; i >= 0; i--) Destroy(screenHost.GetChild(i).gameObject); }

        // ------------------------------------------------------------ Écrans
        void ShowMain()
        {
            ClearScreen();
            var h = screenHost;
            UIFactory.Panel(h, "shade", new Color(0, 0, 0, 0.35f), Vector2.zero, Vector2.one);
            UIFactory.Label(h, "NIGHTFALL", 96, new Color(0.9f, 0.9f, 0.9f), TextAnchor.MiddleCenter, new Vector2(0.1f, 0.68f), new Vector2(0.9f, 0.9f));
            UIFactory.Label(h, "LES OMBRES DE YOPOUGON  —  2031", 30, new Color(0.85f, 0.35f, 0.25f), TextAnchor.MiddleCenter, new Vector2(0.1f, 0.6f), new Vector2(0.9f, 0.7f));
            UIFactory.Btn(h, "CAMPAGNE", new Vector2(0.35f, 0.46f), new Vector2(0.65f, 0.58f), Accent, OnCampaign, 34);
            UIFactory.Btn(h, "INTRODUCTION", new Vector2(0.35f, 0.33f), new Vector2(0.65f, 0.43f), Neutral, () => ShowIntro(0), 26);
            UIFactory.Btn(h, "PARAMÈTRES", new Vector2(0.35f, 0.2f), new Vector2(0.65f, 0.3f), Neutral, ShowSettings, 26);
            UIFactory.Btn(h, "QUITTER", new Vector2(0.35f, 0.07f), new Vector2(0.65f, 0.17f), Neutral, Application.Quit, 26);
            UIFactory.Label(h, "Œuvre de fiction. Unity 6 / URP — décors et personnages procéduraux provisoires.", 16, new Color(0.6f, 0.6f, 0.6f), TextAnchor.LowerCenter, new Vector2(0.1f, 0f), new Vector2(0.9f, 0.06f));
        }

        void OnCampaign()
        {
            if (!SaveData.IntroSeen) ShowIntro(0); else ShowCampaign();
        }

        // Introduction : texte canonique repris de story.gd (Resources/Data/intro.json).
        void ShowIntro(int page)
        {
            ClearScreen();
            var h = screenHost;
            var intro = MissionDatabase.Intro;
            UIFactory.Panel(h, "shade", new Color(0f, 0f, 0f, 0.88f), Vector2.zero, Vector2.one);
            UIFactory.Label(h, intro.title, 30, new Color(0.85f, 0.35f, 0.25f), TextAnchor.MiddleCenter, new Vector2(0.1f, 0.84f), new Vector2(0.9f, 0.96f));
            int n = intro.pages.Length;
            if (n == 0) { SaveData.IntroSeen = true; ShowCampaign(); return; }
            page = Mathf.Clamp(page, 0, n - 1);
            UIFactory.Label(h, intro.pages[page], 32, new Color(0.92f, 0.92f, 0.92f), TextAnchor.MiddleCenter, new Vector2(0.12f, 0.25f), new Vector2(0.88f, 0.82f));
            bool last = page >= n - 1;
            int next = page + 1;
            UIFactory.Btn(h, last ? "COMMENCER" : "SUIVANT", new Vector2(0.62f, 0.07f), new Vector2(0.9f, 0.19f), Accent, () => { if (last) { SaveData.IntroSeen = true; ShowCampaign(); } else ShowIntro(next); }, 28);
            UIFactory.Btn(h, "PASSER", new Vector2(0.3f, 0.07f), new Vector2(0.55f, 0.19f), Neutral, () => { SaveData.IntroSeen = true; ShowCampaign(); }, 24);
            UIFactory.Label(h, (page + 1) + " / " + n, 18, new Color(0.6f, 0.6f, 0.6f), TextAnchor.MiddleLeft, new Vector2(0.1f, 0.07f), new Vector2(0.25f, 0.19f));
        }

        void ShowCampaign()
        {
            ClearScreen();
            var h = screenHost;
            UIFactory.Panel(h, "shade", Panel, Vector2.zero, Vector2.one);
            UIFactory.Label(h, "CAMPAGNE", 52, Color.white, TextAnchor.MiddleLeft, new Vector2(0.05f, 0.86f), new Vector2(0.6f, 0.98f));
            int unlocked = SaveData.Unlocked;
            for (int i = 0; i < MissionDatabase.All.Count; i++)
            {
                MissionDef m = MissionDatabase.All[i];
                int col = i % 2, row = i / 2;
                float x0 = 0.05f + col * 0.31f, y1 = 0.84f - row * 0.15f;
                bool open = m.Number <= unlocked;
                int n = m.Number;
                string label = m.Number + ". " + m.Title + (open ? "" : "  (verrouillée)");
                var b = UIFactory.Btn(h, label, new Vector2(x0, y1 - 0.12f), new Vector2(x0 + 0.29f, y1),
                    open ? (n == selected ? Accent : Neutral) : Disabled, () => { selected = n; ShowCampaign(); }, 22);
                b.interactable = open;
            }
            if (MissionDatabase.All.Count == 0)
            {
                UIFactory.Label(h, "Données de campagne introuvables (Resources/Data/campaign.json).", 24, Color.white, TextAnchor.UpperLeft, new Vector2(0.05f, 0.3f), new Vector2(0.9f, 0.5f));
                UIFactory.Btn(h, "RETOUR", new Vector2(0.7f, 0.02f), new Vector2(0.95f, 0.11f), Neutral, ShowMain, 24);
                return;
            }
            MissionDef sel = MissionDatabase.All[Mathf.Clamp(selected, 1, MissionDatabase.All.Count) - 1];
            float best = SaveData.BestTime(sel.Number);
            string info = sel.Title + (string.IsNullOrEmpty(sel.Location) ? "" : "  (" + sel.Location + ")") + "\n\n" + sel.Briefing + "\n\nObjectifs" +
                          (sel.HasSourceObjectives ? " :" : " (génériques, provisoires) :");
            for (int k = 0; k < sel.Objectives.Count; k++) info += "\n- " + sel.Objectives[k].Title;
            info += "\nHostiles : " + sel.EnemyCount +
                    (best > 0f ? "\nMeilleur temps : " + Mathf.FloorToInt(best / 60f) + " min " + Mathf.FloorToInt(best % 60f) + " s" : "");
            UIFactory.Label(h, info, 20, new Color(0.9f, 0.9f, 0.9f), TextAnchor.UpperLeft, new Vector2(0.05f, 0.04f), new Vector2(0.65f, 0.5f));
            UIFactory.Btn(h, "LANCER", new Vector2(0.7f, 0.14f), new Vector2(0.95f, 0.26f), Accent, () => StartMission(sel), 32);
            UIFactory.Btn(h, "RETOUR", new Vector2(0.7f, 0.02f), new Vector2(0.95f, 0.11f), Neutral, ShowMain, 24);
        }

        void ShowSettings()
        {
            ClearScreen();
            var h = screenHost;
            UIFactory.Panel(h, "shade", Panel, Vector2.zero, Vector2.one);
            UIFactory.Label(h, "PARAMÈTRES", 52, Color.white, TextAnchor.MiddleLeft, new Vector2(0.05f, 0.86f), new Vector2(0.6f, 0.98f));

            string[] q = { "Auto (" + (QualityProfile.IsArm32Process ? "ARM32" : "ARM64") + ")", "Basse (ARM32)", "Haute (ARM64)" };
            UIFactory.Label(h, "Qualité graphique", 28, Color.white, TextAnchor.MiddleLeft, new Vector2(0.08f, 0.62f), new Vector2(0.4f, 0.74f));
            UIFactory.Btn(h, q[SaveData.QualityOverride], new Vector2(0.45f, 0.63f), new Vector2(0.8f, 0.74f), Neutral, () =>
            {
                SaveData.QualityOverride = (SaveData.QualityOverride + 1) % 3;
                QualityProfile.Apply();
                ShowSettings();
            }, 26);

            UIFactory.Label(h, "Sensibilité : " + SaveData.Sensitivity.ToString("0.0"), 28, Color.white, TextAnchor.MiddleLeft, new Vector2(0.08f, 0.46f), new Vector2(0.4f, 0.58f));
            UIFactory.Btn(h, "−", new Vector2(0.45f, 0.47f), new Vector2(0.55f, 0.58f), Neutral, () => { SaveData.Sensitivity -= 0.1f; ShowSettings(); }, 36);
            UIFactory.Btn(h, "+", new Vector2(0.58f, 0.47f), new Vector2(0.68f, 0.58f), Neutral, () => { SaveData.Sensitivity += 0.1f; ShowSettings(); }, 36);

            UIFactory.Label(h, "Le profil Basse réduit la résolution de rendu, les ombres et supprime le post-traitement.", 18, new Color(0.7f, 0.7f, 0.7f), TextAnchor.UpperLeft, new Vector2(0.08f, 0.3f), new Vector2(0.8f, 0.42f));
            UIFactory.Btn(h, "RETOUR", new Vector2(0.7f, 0.04f), new Vector2(0.95f, 0.14f), Neutral, ShowMain, 26);
        }

        public void ShowPause()
        {
            if (missionRoot == null || Time.timeScale == 0f) return;
            Time.timeScale = 0f;
            TouchInput.ResetAll();
            ClearScreen();
            var h = screenHost;
            UIFactory.Panel(h, "shade", new Color(0, 0, 0, 0.6f), Vector2.zero, Vector2.one);
            UIFactory.Label(h, "PAUSE", 64, Color.white, TextAnchor.MiddleCenter, new Vector2(0.2f, 0.72f), new Vector2(0.8f, 0.9f));
            UIFactory.Btn(h, "REPRENDRE", new Vector2(0.35f, 0.5f), new Vector2(0.65f, 0.62f), Accent, Resume, 30);
            UIFactory.Btn(h, "RECOMMENCER", new Vector2(0.35f, 0.35f), new Vector2(0.65f, 0.47f), Neutral, () => StartMission(current), 28);
            UIFactory.Btn(h, "MENU PRINCIPAL", new Vector2(0.35f, 0.2f), new Vector2(0.65f, 0.32f), Neutral, QuitToMenu, 28);
        }

        void Resume()
        {
            ClearScreen();
            Time.timeScale = 1f;
        }

        void ShowEnd(MissionController mc, bool win, float time, int kills)
        {
            Time.timeScale = 0f;
            ClearScreen();
            var h = screenHost;
            UIFactory.Panel(h, "shade", new Color(0, 0, 0, 0.7f), Vector2.zero, Vector2.one);
            UIFactory.Label(h, win ? "MISSION ACCOMPLIE" : "MISSION ÉCHOUÉE", 60, win ? new Color(0.5f, 0.9f, 0.5f) : new Color(0.9f, 0.3f, 0.25f), TextAnchor.MiddleCenter, new Vector2(0.1f, 0.7f), new Vector2(0.9f, 0.88f));
            string detail = mc.Def.Title + "\nTemps : " + Mathf.FloorToInt(time / 60f) + " min " + Mathf.FloorToInt(time % 60f) + " s\nObjectifs : " + mc.CompletedObjectives + " / " + mc.Def.Objectives.Count + "   Hostiles éliminés : " + kills;
            if (!win && !string.IsNullOrEmpty(mc.FailReason)) detail += "\n" + mc.FailReason;
            if (win && !string.IsNullOrEmpty(mc.Def.Ending)) detail += "\n\n" + mc.Def.Ending;
            UIFactory.Label(h, detail, 24, Color.white, TextAnchor.UpperCenter, new Vector2(0.12f, 0.36f), new Vector2(0.88f, 0.68f));
            MissionDef cur = mc.Def;
            UIFactory.Btn(h, "REJOUER", new Vector2(0.15f, 0.18f), new Vector2(0.4f, 0.3f), Neutral, () => StartMission(cur), 28);
            if (win && cur.Number < MissionDatabase.All.Count)
                UIFactory.Btn(h, "SUIVANTE", new Vector2(0.42f, 0.18f), new Vector2(0.58f, 0.3f), Accent, () => StartMission(MissionDatabase.All[cur.Number]), 28);
            UIFactory.Btn(h, "MENU", new Vector2(0.6f, 0.18f), new Vector2(0.85f, 0.3f), Neutral, QuitToMenu, 28);
        }

        // ------------------------------------------------------------ Transitions
        void StartMission(MissionDef def)
        {
            Time.timeScale = 1f;
            ClearScreen();
            if (missionRoot != null) { missionRoot.SetActive(false); Destroy(missionRoot); }
            if (menuWorld != null) { menuWorld.SetActive(false); Destroy(menuWorld); menuWorld = null; }
            current = def;
            selected = def.Number;
            var mc = MissionController.Create(def, ShowPause, ShowEnd);
            missionRoot = mc.gameObject;
        }

        void QuitToMenu()
        {
            Time.timeScale = 1f;
            TouchInput.ResetAll();
            if (missionRoot != null) { missionRoot.SetActive(false); Destroy(missionRoot); missionRoot = null; }
            if (menuWorld == null) BuildMenuWorld();
            ShowMain();
        }
    }
}

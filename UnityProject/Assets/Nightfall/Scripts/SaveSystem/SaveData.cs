using UnityEngine;

namespace Nightfall.SaveSystem
{
    /// <summary>Progression et réglages (PlayerPrefs, local à l'appareil).</summary>
    public static class SaveData
    {
        const string KUnlocked = "nf_unlocked";
        const string KSens = "nf_sens";
        const string KQuality = "nf_quality";
        const string KBest = "nf_best_";
        const string KIntro = "nf_intro_seen";

        public static bool IntroSeen
        {
            get { return PlayerPrefs.GetInt(KIntro, 0) == 1; }
            set { PlayerPrefs.SetInt(KIntro, value ? 1 : 0); PlayerPrefs.Save(); }
        }

        public static int Unlocked { get { return Mathf.Max(1, PlayerPrefs.GetInt(KUnlocked, 1)); } }
        public static void UnlockUpTo(int missionNumber)
        {
            if (missionNumber > Unlocked) { PlayerPrefs.SetInt(KUnlocked, missionNumber); PlayerPrefs.Save(); }
        }

        public static float Sensitivity
        {
            get { return PlayerPrefs.GetFloat(KSens, 1f); }
            set { PlayerPrefs.SetFloat(KSens, Mathf.Clamp(value, 0.3f, 2.5f)); PlayerPrefs.Save(); }
        }

        /// <summary>0 = auto (selon ARM32/ARM64), 1 = basse, 2 = haute.</summary>
        public static int QualityOverride
        {
            get { return PlayerPrefs.GetInt(KQuality, 0); }
            set { PlayerPrefs.SetInt(KQuality, Mathf.Clamp(value, 0, 2)); PlayerPrefs.Save(); }
        }

        public static float BestTime(int mission) { return PlayerPrefs.GetFloat(KBest + mission, 0f); }
        public static void SubmitTime(int mission, float seconds)
        {
            float b = BestTime(mission);
            if (b <= 0f || seconds < b) { PlayerPrefs.SetFloat(KBest + mission, seconds); PlayerPrefs.Save(); }
        }

        public static void ResetAll() { PlayerPrefs.DeleteAll(); PlayerPrefs.Save(); }
    }
}

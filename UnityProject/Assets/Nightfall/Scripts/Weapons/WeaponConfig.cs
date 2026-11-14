using UnityEngine;

namespace Nightfall.Weapons
{
    public enum WeaponKind { Rifle, Pistol, Shotgun }

    /// <summary>Configuration d'arme (ScriptableObject). Les préréglages sont créés par code.</summary>
    [CreateAssetMenu(menuName = "Nightfall/Weapon Config", fileName = "WeaponConfig")]
    public class WeaponConfig : ScriptableObject
    {
        public string DisplayName = "Arme";
        public WeaponKind Kind = WeaponKind.Rifle;
        public float Damage = 24f;
        public float Rpm = 600f;
        public int MagSize = 30;
        public float ReloadTime = 2.0f;
        public float SpreadHip = 2.2f;
        public float SpreadAds = 0.4f;
        public int Pellets = 1;
        public bool Auto = true;
        public float Range = 120f;
        public float RecoilUp = 0.9f;
        public float RecoilSide = 0.25f;
        public float KickBack = 0.04f;
        public float AdsFov = 52f;
        public float NoiseRadius = 50f;
        public Vector3 HipPos = new Vector3(0.2f, -0.2f, 0.42f);
        public Vector3 AdsPos = new Vector3(0f, -0.115f, 0.33f);

        public static WeaponConfig Rifle()
        {
            var c = CreateInstance<WeaponConfig>();
            c.DisplayName = "Fusil d'assaut";
            return c;
        }

        public static WeaponConfig Pistol()
        {
            var c = CreateInstance<WeaponConfig>();
            c.DisplayName = "Pistolet"; c.Kind = WeaponKind.Pistol;
            c.Damage = 20f; c.Rpm = 380f; c.MagSize = 12; c.ReloadTime = 1.4f;
            c.SpreadHip = 1.8f; c.SpreadAds = 0.35f; c.Auto = false; c.Range = 70f;
            c.RecoilUp = 1.2f; c.RecoilSide = 0.2f; c.KickBack = 0.05f; c.AdsFov = 60f; c.NoiseRadius = 40f;
            c.HipPos = new Vector3(0.17f, -0.17f, 0.36f);
            c.AdsPos = new Vector3(0f, -0.095f, 0.3f);
            return c;
        }

        public static WeaponConfig Shotgun()
        {
            var c = CreateInstance<WeaponConfig>();
            c.DisplayName = "Fusil à pompe"; c.Kind = WeaponKind.Shotgun;
            c.Damage = 11f; c.Pellets = 8; c.Rpm = 70f; c.MagSize = 6; c.ReloadTime = 2.8f;
            c.SpreadHip = 5.5f; c.SpreadAds = 3.5f; c.Auto = false; c.Range = 35f;
            c.RecoilUp = 4.5f; c.RecoilSide = 0.8f; c.KickBack = 0.1f; c.AdsFov = 62f; c.NoiseRadius = 70f;
            return c;
        }
    }
}

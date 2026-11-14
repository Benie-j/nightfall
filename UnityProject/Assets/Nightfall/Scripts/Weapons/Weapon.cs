using System;
using UnityEngine;
using Nightfall.Audio;
using Nightfall.Combat;
using Nightfall.Core;
using Nightfall.Player;

namespace Nightfall.Weapons
{
    /// <summary>Logique d'une arme en vue subjective : tir hitscan, dispersion, recul, rechargement, ADS.</summary>
    public class Weapon : MonoBehaviour
    {
        public static event Action<bool, bool> HitConfirmed; // (mort, tête)
        public static event Action Fired;

        public WeaponConfig Config;
        public PlayerController Player;
        public int Ammo;
        public bool Reloading { get; private set; }

        Transform muzzle;
        Light flash;
        float flashT, cooldown, reloadT, adsAmount;
        Vector3 kick, sway;
        bool prevFire;

        public void Setup(WeaponConfig cfg, PlayerController p)
        {
            Config = cfg; Player = p; Ammo = cfg.MagSize;
            muzzle = WeaponModelBuilder.Build(cfg.Kind, transform);
            var fl = new GameObject("flash");
            fl.transform.SetParent(muzzle, false);
            flash = fl.AddComponent<Light>();
            flash.type = LightType.Point; flash.range = 7f; flash.intensity = 0f;
            flash.color = new Color(1f, 0.7f, 0.35f); flash.shadows = LightShadows.None;
            var quad = GameObject.CreatePrimitive(PrimitiveType.Sphere);
            quad.name = "flashMesh";
            Destroy(quad.GetComponent<Collider>());
            quad.transform.SetParent(muzzle, false);
            quad.transform.localScale = new Vector3(0.06f, 0.06f, 0.1f);
            quad.GetComponent<Renderer>().sharedMaterial = Mats.Unlit(new Color(1f, 0.8f, 0.4f));
            quad.GetComponent<Renderer>().shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.Off;
            quad.SetActive(false);
            flashMesh = quad;
            transform.localPosition = cfg.HipPos;
        }

        GameObject flashMesh;

        void OnEnable() { Reloading = false; reloadT = 0f; prevFire = true; }

        public void RequestReload()
        {
            if (Reloading || Ammo >= Config.MagSize) return;
            Reloading = true; reloadT = Config.ReloadTime;
            ProcAudio.Play(ProcAudio.Reload, transform.position, 0.8f);
        }

        void Update()
        {
            if (Time.timeScale == 0f || Player == null) return;
            float dt = Time.deltaTime;
            cooldown -= dt;

            if (flashT > 0f)
            {
                flashT -= dt;
                if (flashT <= 0f) { flash.intensity = 0f; flashMesh.SetActive(false); }
            }

            adsAmount = Player.AdsAmount;
            if (adsAmount > 0.5f) Player.AdsFov = Config.AdsFov;

            if (TouchInput.ReloadPressed) { TouchInput.ReloadPressed = false; RequestReload(); }

            bool fireNow = TouchInput.FireHeld;
            bool pressed = fireNow && !prevFire;
            prevFire = fireNow;

            if (Reloading)
            {
                reloadT -= dt;
                if (reloadT <= 0f) { Reloading = false; Ammo = Config.MagSize; }
            }
            else if (fireNow && cooldown <= 0f && (Config.Auto || pressed))
            {
                if (Ammo > 0) Fire();
                else { cooldown = 0.25f; ProcAudio.Play(ProcAudio.Empty, transform.position, 0.6f); RequestReload(); }
            }

            // Pose de l'arme : hanche <-> ADS, recul, balancement, animation de rechargement.
            Vector3 basePos = Vector3.Lerp(Config.HipPos, Config.AdsPos, adsAmount);
            kick = Vector3.Lerp(kick, Vector3.zero, 12f * dt);
            Vector2 look = TouchInput.Look;
            sway = Vector3.Lerp(sway, new Vector3(-look.x, -look.y, 0f) * 0.0006f, 8f * dt);
            Vector3 reloadOffset = Vector3.zero;
            float tilt = 0f;
            if (Reloading)
            {
                float p = 1f - Mathf.Clamp01(reloadT / Mathf.Max(0.01f, Config.ReloadTime));
                float s = Mathf.Sin(p * Mathf.PI);
                reloadOffset = new Vector3(0f, -0.12f * s, -0.03f * s);
                tilt = 35f * s;
            }
            transform.localPosition = basePos + kick + sway + reloadOffset;
            transform.localRotation = Quaternion.Euler(tilt - kick.z * 40f, 0f, 0f);
        }

        void Fire()
        {
            cooldown = 60f / Config.Rpm;
            Ammo--;
            Camera cam = Player.Cam;
            float spread = Mathf.Lerp(Config.SpreadHip, Config.SpreadAds, adsAmount);
            if (Player.Moving) spread *= 1.5f;
            if (Player.Crouching) spread *= 0.7f;

            bool anyHit = false, anyKill = false, anyHead = false;
            for (int i = 0; i < Config.Pellets; i++)
            {
                Vector2 r = UnityEngine.Random.insideUnitCircle * Mathf.Tan(spread * Mathf.Deg2Rad);
                Vector3 dir = (cam.transform.forward + cam.transform.right * r.x + cam.transform.up * r.y).normalized;
                Vector3 end = cam.transform.position + dir * Mathf.Min(Config.Range, 90f);
                RaycastHit hit;
                if (Physics.Raycast(cam.transform.position, dir, out hit, Config.Range, ~0, QueryTriggerInteraction.Ignore))
                {
                    end = hit.point;
                    Health h = hit.collider.GetComponentInParent<Health>();
                    if (h != null && h != Player.Health)
                    {
                        HitZone z = hit.collider.GetComponent<HitZone>();
                        float mult = z != null ? z.Multiplier : 1f;
                        float falloff = Mathf.Lerp(1f, 0.55f, Mathf.Clamp01(hit.distance / Config.Range));
                        bool wasDead = h.IsDead;
                        h.TakeDamage(Config.Damage * mult * falloff, cam.transform.position);
                        anyHit = true;
                        if (!wasDead && h.IsDead) anyKill = true;
                        if (z != null && z.IsHead) anyHead = true;
                        Fx.Blood(hit.point, hit.normal);
                    }
                    else Fx.Impact(hit.point, hit.normal);
                }
                Fx.Tracer(muzzle.position, end, new Color(1f, 0.85f, 0.4f));
            }

            kick += new Vector3(UnityEngine.Random.Range(-0.004f, 0.004f), 0.004f, -Config.KickBack);
            Player.AddRecoil(Config.RecoilUp * Mathf.Lerp(1f, 0.7f, adsAmount),
                             UnityEngine.Random.Range(-Config.RecoilSide, Config.RecoilSide));

            flash.intensity = 4f; flashMesh.SetActive(true); flashT = 0.045f;
            flashMesh.transform.localEulerAngles = new Vector3(0, 0, UnityEngine.Random.Range(0f, 360f));

            AudioClip clip = Config.Kind == WeaponKind.Pistol ? ProcAudio.Pistol : (Config.Kind == WeaponKind.Shotgun ? ProcAudio.Shotgun : ProcAudio.Rifle);
            ProcAudio.Play(clip, muzzle.position, 1f, UnityEngine.Random.Range(0.95f, 1.05f));
            Noise.Emit(Player.transform.position, Config.NoiseRadius);
            Fx.Casing(transform.position + transform.right * 0.05f, cam.transform.right);

            if (Fired != null) Fired();
            if (anyHit)
            {
                ProcAudio.Play2D(ProcAudio.Hit, 0.5f);
                if (HitConfirmed != null) HitConfirmed(anyKill, anyHead);
            }
        }
    }
}

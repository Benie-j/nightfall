using UnityEngine;
using UnityEngine.UI;
using Nightfall.Player;
using Nightfall.Weapons;

namespace Nightfall.UI
{
    /// <summary>HUD : santé, munitions, objectif, réticule, marqueur de touche, boutons tactiles.</summary>
    public class HudView : MonoBehaviour
    {
        Image healthFill, damageFlash, hitmarker;
        Text ammo, weaponName, objective;
        float flashA, hitT;
        int lastAmmo = -1;
        bool lastReload;
        Color hitColor = Color.white;

        public static HudView Create(Transform parent, System.Action onPause)
        {
            var canvas = UIFactory.NewCanvas("HUD", 5, parent);
            var hud = canvas.gameObject.AddComponent<HudView>();
            hud.Build(canvas.transform, onPause);
            return hud;
        }

        void Build(Transform root, System.Action onPause)
        {
            Color btn = new Color(0.1f, 0.12f, 0.15f, 0.55f);
            damageFlash = UIFactory.Panel(root, "DamageFlash", new Color(0.7f, 0f, 0f, 0f), Vector2.zero, Vector2.one);

            // Réticule + marqueur de touche
            UIFactory.Panel(root, "CH-h", new Color(1, 1, 1, 0.85f), new Vector2(0.495f, 0.4985f), new Vector2(0.505f, 0.5015f));
            UIFactory.Panel(root, "CH-v", new Color(1, 1, 1, 0.85f), new Vector2(0.4985f, 0.49f), new Vector2(0.5015f, 0.51f));
            hitmarker = UIFactory.Panel(root, "Hit", new Color(1, 1, 1, 0), new Vector2(0.485f, 0.47f), new Vector2(0.515f, 0.53f));

            // Santé
            UIFactory.Panel(root, "HP-bg", new Color(0, 0, 0, 0.5f), new Vector2(0.02f, 0.92f), new Vector2(0.28f, 0.96f));
            healthFill = UIFactory.Panel(root, "HP", new Color(0.75f, 0.12f, 0.1f, 0.95f), new Vector2(0.02f, 0.92f), new Vector2(0.28f, 0.96f));
            UIFactory.Label(root, "SANTÉ", 18, Color.white, TextAnchor.MiddleLeft, new Vector2(0.03f, 0.955f), new Vector2(0.15f, 0.99f));

            objective = UIFactory.Label(root, "", 22, new Color(0.95f, 0.85f, 0.5f), TextAnchor.UpperCenter, new Vector2(0.3f, 0.9f), new Vector2(0.92f, 1f));
            ammo = UIFactory.Label(root, "", 40, Color.white, TextAnchor.LowerRight, new Vector2(0.6f, 0.02f), new Vector2(0.76f, 0.14f));
            weaponName = UIFactory.Label(root, "", 20, new Color(0.8f, 0.8f, 0.8f), TextAnchor.LowerRight, new Vector2(0.6f, 0.13f), new Vector2(0.76f, 0.18f));

            // Boutons tactiles (zone droite)
            UIFactory.Hold(root, "TIR", new Vector2(0.84f, 0.12f), new Vector2(0.97f, 0.3f), new Color(0.6f, 0.1f, 0.08f, 0.6f), v => TouchInput.FireHeld = v, 30);
            UIFactory.Hold(root, "VISER", new Vector2(0.84f, 0.34f), new Vector2(0.95f, 0.46f), btn, v => TouchInput.AdsHeld = v);
            UIFactory.Btn(root, "RECH.", new Vector2(0.71f, 0.2f), new Vector2(0.81f, 0.3f), btn, () => TouchInput.ReloadPressed = true, 20);
            UIFactory.Btn(root, "SAUT", new Vector2(0.71f, 0.32f), new Vector2(0.81f, 0.42f), btn, () => TouchInput.JumpPressed = true, 20);
            UIFactory.Btn(root, "BAISSER", new Vector2(0.58f, 0.2f), new Vector2(0.69f, 0.3f), btn, () => TouchInput.CrouchPressed = true, 18);
            UIFactory.Btn(root, "ACTION", new Vector2(0.58f, 0.44f), new Vector2(0.69f, 0.54f), new Color(0.15f, 0.3f, 0.35f, 0.65f), () => TouchInput.InteractPressed = true, 18);
            UIFactory.Btn(root, "ARME", new Vector2(0.58f, 0.32f), new Vector2(0.69f, 0.42f), btn, () => TouchInput.SwitchPressed = true, 20);
            UIFactory.Hold(root, "COURIR", new Vector2(0.02f, 0.45f), new Vector2(0.13f, 0.56f), btn, v => TouchInput.SprintHeld = v, 18);
            UIFactory.Btn(root, "II", new Vector2(0.94f, 0.9f), new Vector2(0.99f, 0.98f), btn, () => { if (onPause != null) onPause(); }, 24);
        }

        public void SetHealth(float fraction)
        {
            healthFill.rectTransform.anchorMax = new Vector2(Mathf.Lerp(0.02f, 0.28f, Mathf.Clamp01(fraction)), 0.96f);
        }

        public void SetObjective(string s) { if (objective.text != s) objective.text = s; }
        public void SetWeapon(string name, int ammoNow, int mag, bool reloading)
        {
            if (ammoNow == lastAmmo && reloading == lastReload && name == weaponName.text) return;
            lastAmmo = ammoNow; lastReload = reloading;
            weaponName.text = name;
            ammo.text = reloading ? "RECHARGE…" : ammoNow + " / " + mag;
        }

        public void DamageFlash() { flashA = 0.55f; }
        public void Hit(bool kill, bool head)
        {
            hitT = 0.18f;
            hitColor = kill ? new Color(1f, 0.2f, 0.2f) : (head ? new Color(1f, 0.85f, 0.2f) : Color.white);
        }

        void OnEnable() { Weapon.HitConfirmed += Hit; }
        void OnDisable() { Weapon.HitConfirmed -= Hit; }

        void Update()
        {
            flashA = Mathf.MoveTowards(flashA, 0f, Time.unscaledDeltaTime * 1.4f);
            damageFlash.color = new Color(0.7f, 0f, 0f, flashA);
            hitT -= Time.unscaledDeltaTime;
            hitmarker.color = new Color(hitColor.r, hitColor.g, hitColor.b, Mathf.Clamp01(hitT / 0.18f));
        }
    }
}

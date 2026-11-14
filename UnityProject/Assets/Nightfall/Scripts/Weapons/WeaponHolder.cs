using System.Collections.Generic;
using UnityEngine;
using Nightfall.Player;

namespace Nightfall.Weapons
{
    /// <summary>Porte les armes sous la caméra et gère le changement d'arme.</summary>
    public class WeaponHolder : MonoBehaviour
    {
        public readonly List<Weapon> Weapons = new List<Weapon>();
        public int Index { get; private set; }
        public Weapon Current { get { return Weapons.Count > 0 ? Weapons[Index] : null; } }

        public void Init(PlayerController player)
        {
            var cfgs = new[] { WeaponConfig.Rifle(), WeaponConfig.Pistol(), WeaponConfig.Shotgun() };
            foreach (var c in cfgs)
            {
                var go = new GameObject("Weapon_" + c.DisplayName);
                go.transform.SetParent(transform, false);
                var w = go.AddComponent<Weapon>();
                w.Setup(c, player);
                go.SetActive(false);
                Weapons.Add(w);
            }
            Index = 0;
            Weapons[0].gameObject.SetActive(true);
        }

        void Update()
        {
            if (!TouchInput.SwitchPressed || Weapons.Count == 0) return;
            TouchInput.SwitchPressed = false;
            Weapons[Index].gameObject.SetActive(false);
            Index = (Index + 1) % Weapons.Count;
            Weapons[Index].gameObject.SetActive(true);
        }
    }
}

using UnityEngine;
using Nightfall.Core;

namespace Nightfall.World
{
    /// <summary>Chargement par secteurs : (dés)active les tronçons de ville autour du joueur.</summary>
    public class SectorStreamer : MonoBehaviour
    {
        public CityGenerator City;
        public Transform Target;
        float timer;
        int last = -999;

        void Update()
        {
            timer -= Time.unscaledDeltaTime;
            if (timer > 0f || City == null || Target == null) return;
            timer = 0.4f;
            int idx = City.SectorIndexAt(Target.position.z);
            if (idx == last) return;
            last = idx;
            City.ShowWindow(idx, QualityProfile.SectorWindow);
        }
    }
}

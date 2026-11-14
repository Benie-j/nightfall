using System;
using UnityEngine;

namespace Nightfall.Core
{
    /// <summary>Bruit de jeu (tirs) que les ennemis peuvent entendre.</summary>
    public static class Noise
    {
        public static event Action<Vector3, float> Emitted;
        public static void Emit(Vector3 pos, float radius) { if (Emitted != null) Emitted(pos, radius); }
    }
}

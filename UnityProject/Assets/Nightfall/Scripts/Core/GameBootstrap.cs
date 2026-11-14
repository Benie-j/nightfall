using UnityEngine;

namespace Nightfall.Core
{
    /// <summary>Point d'entrée unique : placé dans la scène Boot (créée par l'éditeur au build).</summary>
    public class GameBootstrap : MonoBehaviour
    {
        void Awake()
        {
            QualityProfile.Apply();
            Screen.sleepTimeout = SleepTimeout.NeverSleep;
            Screen.orientation = ScreenOrientation.LandscapeLeft;
            var go = new GameObject("GameFlow");
            go.AddComponent<GameFlow>();
        }
    }
}

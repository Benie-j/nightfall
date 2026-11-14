using UnityEngine;

namespace Nightfall.World
{
    /// <summary>Caméra d'arrière-plan du menu : lent survol de la rue.</summary>
    public class CameraOrbit : MonoBehaviour
    {
        float t;
        void Update()
        {
            t += Time.unscaledDeltaTime * 0.06f;
            float z = 12f + Mathf.PingPong(t * 60f, 80f);
            transform.position = new Vector3(Mathf.Sin(t * 3f) * 3f, 2.2f + Mathf.Sin(t * 2f) * 0.4f, z);
            transform.rotation = Quaternion.Euler(4f, Mathf.Sin(t * 2.2f) * 12f, 0f);
        }
    }
}

using System.Collections;
using UnityEngine;

namespace Nightfall.AI
{
    /// <summary>Animation procédurale (marche, visée, mort) d'un soldat construit en primitives.</summary>
    public class EnemyAnimator : MonoBehaviour
    {
        public Transform LegL, LegR, ArmL, ArmR, Body;
        public Light MuzzleLight;
        public float Speed;
        public bool Aiming;
        public bool Crouched;
        float phase, flashT;

        public void Fire() { if (MuzzleLight != null) { MuzzleLight.intensity = 3f; flashT = 0.05f; } }

        void Update()
        {
            if (Time.timeScale == 0f) return;
            phase += Time.deltaTime * Mathf.Lerp(0f, 9f, Mathf.Clamp01(Speed / 3.5f));
            float s = Mathf.Sin(phase) * 35f * Mathf.Clamp01(Speed / 2.5f);
            if (LegL != null) LegL.localRotation = Quaternion.Euler(s, 0, 0);
            if (LegR != null) LegR.localRotation = Quaternion.Euler(-s, 0, 0);
            if (Aiming)
            {
                if (ArmL != null) ArmL.localRotation = Quaternion.Euler(-80f, 12f, 0);
                if (ArmR != null) ArmR.localRotation = Quaternion.Euler(-85f, -10f, 0);
            }
            else
            {
                if (ArmL != null) ArmL.localRotation = Quaternion.Euler(-s * 0.6f - 25f, 0, 0);
                if (ArmR != null) ArmR.localRotation = Quaternion.Euler(s * 0.6f - 35f, 0, 0);
            }
            if (Body != null)
            {
                float y = Crouched ? 0.6f : 1f;
                Body.localScale = Vector3.Lerp(Body.localScale, new Vector3(1f, y, 1f), 8f * Time.deltaTime);
            }
            if (flashT > 0f) { flashT -= Time.deltaTime; if (flashT <= 0f && MuzzleLight != null) MuzzleLight.intensity = 0f; }
        }

        public void Die() { StartCoroutine(Fall()); }

        IEnumerator Fall()
        {
            Aiming = false; Speed = 0f;
            Quaternion from = transform.rotation;
            Quaternion to = from * Quaternion.Euler(-88f, 0f, 0f);
            float t = 0f;
            while (t < 1f)
            {
                t += Time.deltaTime / 0.55f;
                transform.rotation = Quaternion.Slerp(from, to, Mathf.SmoothStep(0f, 1f, t));
                yield return null;
            }
            enabled = false;
        }
    }
}

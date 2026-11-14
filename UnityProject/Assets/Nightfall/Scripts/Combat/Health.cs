using System;
using UnityEngine;

namespace Nightfall.Combat
{
    public interface IDamageable
    {
        bool IsDead { get; }
        void TakeDamage(float amount, Vector3 origin);
    }

    public class Health : MonoBehaviour, IDamageable
    {
        public float Max = 100f;
        public float Current = 100f;
        public event Action<float, Vector3> Damaged;
        public event Action Died;

        public bool IsDead { get { return Current <= 0f; } }
        public float Fraction { get { return Max <= 0f ? 0f : Mathf.Clamp01(Current / Max); } }

        public void Init(float max) { Max = max; Current = max; }

        public void TakeDamage(float amount, Vector3 origin)
        {
            if (IsDead || amount <= 0f) return;
            Current = Mathf.Max(0f, Current - amount);
            if (Damaged != null) Damaged(amount, origin);
            if (Current <= 0f && Died != null) Died();
        }

        public void Heal(float amount) { if (!IsDead) Current = Mathf.Min(Max, Current + amount); }
    }

    /// <summary>Zone de touche (tête, etc.) portée par un collider enfant.</summary>
    public class HitZone : MonoBehaviour
    {
        public float Multiplier = 1f;
        public bool IsHead;
    }
}

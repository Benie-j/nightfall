using UnityEngine;
using Nightfall.Combat;
using Nightfall.SaveSystem;

namespace Nightfall.Player
{
    [RequireComponent(typeof(CharacterController))]
    public class PlayerController : MonoBehaviour
    {
        public Camera Cam;
        public Health Health;
        public bool Aiming { get; private set; }
        public bool Crouching { get; private set; }
        public bool Moving { get; private set; }
        public float AdsFov = 50f;
        public float AdsAmount { get; private set; }

        const float HipFov = 72f;
        const float WalkSpeed = 4.2f, SprintSpeed = 6.8f, CrouchSpeed = 2.0f, Gravity = -20f, JumpSpeed = 6.2f;

        CharacterController cc;
        float yaw, pitch, recoilPitch, recoilYaw, vy, bob, camY = 1.65f;

        void Awake() { cc = GetComponent<CharacterController>(); }

        public void SetYaw(float degrees) { yaw = degrees; }

        public void AddRecoil(float up, float side) { recoilPitch += up; recoilYaw += side; }

        public Vector3 Eye { get { return Cam.transform.position; } }

        void Update()
        {
            if (Time.timeScale == 0f || Health == null || Health.IsDead) return;
            float dt = Time.deltaTime;

            Aiming = TouchInput.AdsHeld;
            AdsAmount = Mathf.MoveTowards(AdsAmount, Aiming ? 1f : 0f, dt * 8f);
            float sens = SaveData.Sensitivity * Mathf.Lerp(1f, 0.55f, AdsAmount) * 0.12f;

            yaw += TouchInput.Look.x * sens;
            pitch = Mathf.Clamp(pitch - TouchInput.Look.y * sens, -85f, 85f);
            recoilPitch = Mathf.MoveTowards(recoilPitch, 0f, (4f + recoilPitch * 6f) * dt);
            recoilYaw = Mathf.MoveTowards(recoilYaw, 0f, 3f * dt);

            transform.rotation = Quaternion.Euler(0f, yaw + recoilYaw, 0f);

            if (TouchInput.CrouchPressed) Crouching = !Crouching;
            float targetH = Crouching ? 1.1f : 1.8f;
            cc.height = Mathf.MoveTowards(cc.height, targetH, 6f * dt);
            cc.center = new Vector3(0f, cc.height * 0.5f, 0f);
            camY = Mathf.MoveTowards(camY, Crouching ? 0.95f : 1.65f, 5f * dt);

            Vector2 mv = TouchInput.Move;
            Moving = mv.sqrMagnitude > 0.01f;
            bool sprint = TouchInput.SprintHeld && !Crouching && !Aiming && mv.y > 0.3f;
            float speed = Crouching ? CrouchSpeed : (sprint ? SprintSpeed : WalkSpeed);
            if (Aiming) speed *= 0.65f;

            Vector3 wish = (transform.right * mv.x + transform.forward * mv.y);
            if (wish.sqrMagnitude > 1f) wish.Normalize();

            if (cc.isGrounded)
            {
                vy = -1f;
                if (TouchInput.JumpPressed && !Crouching) vy = JumpSpeed;
            }
            vy += Gravity * dt;

            cc.Move((wish * speed + Vector3.up * vy) * dt);

            if (Moving && cc.isGrounded) bob += dt * speed * 2.2f;
            float bobY = Moving ? Mathf.Sin(bob) * 0.035f : 0f;
            Cam.transform.localPosition = new Vector3(0f, camY + bobY, 0f);
            Cam.transform.localRotation = Quaternion.Euler(pitch - recoilPitch, 0f, 0f);
            Cam.fieldOfView = Mathf.Lerp(HipFov, AdsFov, AdsAmount);

            TouchInput.JumpPressed = false;
            TouchInput.CrouchPressed = false;
        }
    }
}

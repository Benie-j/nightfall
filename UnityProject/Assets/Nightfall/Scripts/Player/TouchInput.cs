using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;

namespace Nightfall.Player
{
    /// <summary>
    /// Entrées tactiles : stick virtuel (moitié gauche), caméra (moitié droite), boutons UI via flags statiques.
    /// Clavier/souris de secours en éditeur et desktop.
    /// </summary>
    public class TouchInput : MonoBehaviour
    {
        public static Vector2 Move;
        public static Vector2 Look;
        // Les boutons UI écrivent via les propriétés (setter) ; clavier/souris de l'éditeur sont dans des champs
        // séparés recalculés CHAQUE frame : plus aucune commande ne peut rester bloquée après un relâchement.
        static bool uiFire, uiAds, uiSprint, kbFire, kbAds, kbSprint;
        public static bool FireHeld { get { return uiFire || kbFire; } set { uiFire = value; } }
        public static bool AdsHeld { get { return uiAds || kbAds; } set { uiAds = value; } }
        public static bool SprintHeld { get { return uiSprint || kbSprint; } set { uiSprint = value; } }
        public static bool ReloadPressed, JumpPressed, CrouchPressed, SwitchPressed, InteractPressed;

        int moveId = -1, lookId = -1;
        Vector2 moveOrigin;
        readonly HashSet<int> uiFingers = new HashSet<int>();

        static bool pendingClear;

        /// <summary>Un appui non consommé survit une frame de plus (ordre d'exécution EventSystem / scripts non garanti), puis est effacé.</summary>
        public static void EndFrame()
        {
            bool any = ReloadPressed || JumpPressed || CrouchPressed || SwitchPressed || InteractPressed;
            if (!any) { pendingClear = false; return; }
            if (pendingClear) { ClearFrameFlags(); pendingClear = false; }
            else pendingClear = true;
        }

        public static void ClearFrameFlags() { ReloadPressed = JumpPressed = CrouchPressed = SwitchPressed = InteractPressed = false; }

        public static void ResetAll()
        {
            Move = Look = Vector2.zero;
            uiFire = uiAds = uiSprint = kbFire = kbAds = kbSprint = false;
            ClearFrameFlags();
        }

        void OnApplicationPause(bool paused) { if (paused) ResetFingers(); }
        void OnApplicationFocus(bool focus) { if (!focus) ResetFingers(); }
        void OnDisable() { ResetFingers(); }

        void ResetFingers()
        {
            moveId = lookId = -1;
            uiFingers.Clear();
            ResetAll();
        }

        void Update()
        {
            Look = Vector2.zero;
            float pxPerUnit = Screen.dpi > 0f ? Screen.dpi * 0.35f : 140f;

            for (int i = 0; i < Input.touchCount; i++)
            {
                Touch t = Input.GetTouch(i);
                if (t.phase == TouchPhase.Began)
                {
                    bool overUi = EventSystem.current != null && EventSystem.current.IsPointerOverGameObject(t.fingerId);
                    if (overUi) { uiFingers.Add(t.fingerId); continue; }
                    if (t.position.x < Screen.width * 0.4f && moveId < 0) { moveId = t.fingerId; moveOrigin = t.position; }
                    else if (t.position.x >= Screen.width * 0.4f && lookId < 0) { lookId = t.fingerId; }
                }
                else if (t.phase == TouchPhase.Moved || t.phase == TouchPhase.Stationary)
                {
                    if (t.fingerId == moveId)
                    {
                        Vector2 d = (t.position - moveOrigin) / pxPerUnit;
                        Move = Vector2.ClampMagnitude(d, 1f);
                        if (Move.magnitude < 0.12f) Move = Vector2.zero;
                    }
                    else if (t.fingerId == lookId && t.phase == TouchPhase.Moved)
                    {
                        Look += t.deltaPosition;
                    }
                }
                else
                {
                    if (t.fingerId == moveId) { moveId = -1; Move = Vector2.zero; }
                    if (t.fingerId == lookId) { lookId = -1; }
                    uiFingers.Remove(t.fingerId);
                }
            }

#if UNITY_EDITOR || UNITY_STANDALONE
            if (Input.touchCount == 0)
            {
                Move = new Vector2(Input.GetAxisRaw("Horizontal"), Input.GetAxisRaw("Vertical"));
                Look = new Vector2(Input.GetAxis("Mouse X"), Input.GetAxis("Mouse Y")) * 6f;
                kbFire = Input.GetMouseButton(0);
                kbAds = Input.GetMouseButton(1);
                kbSprint = Input.GetKey(KeyCode.LeftShift);
                if (Input.GetKeyDown(KeyCode.E)) InteractPressed = true;
                if (Input.GetKeyDown(KeyCode.R)) ReloadPressed = true;
                if (Input.GetKeyDown(KeyCode.Space)) JumpPressed = true;
                if (Input.GetKeyDown(KeyCode.C)) CrouchPressed = true;
                if (Input.GetKeyDown(KeyCode.Q)) SwitchPressed = true;
            }
            else { kbFire = kbAds = kbSprint = false; }
#endif
        }
    }
}

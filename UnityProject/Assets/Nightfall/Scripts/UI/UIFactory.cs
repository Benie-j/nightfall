using UnityEngine;
using UnityEngine.Events;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace Nightfall.UI
{
    /// <summary>Construction d'interface uGUI en code (aucune scène/prefab UI à maintenir).</summary>
    public static class UIFactory
    {
        static Font font;
        public static Font GetFont()
        {
            if (font == null) font = Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            return font;
        }

        public static void EnsureEventSystem()
        {
            if (Object.FindFirstObjectByType<EventSystem>() != null) return;
            var go = new GameObject("EventSystem");
            go.AddComponent<EventSystem>();
            go.AddComponent<StandaloneInputModule>();
        }

        public static Canvas NewCanvas(string name, int order, Transform parent)
        {
            var go = new GameObject(name);
            if (parent != null) go.transform.SetParent(parent, false);
            var c = go.AddComponent<Canvas>();
            c.renderMode = RenderMode.ScreenSpaceOverlay;
            c.sortingOrder = order;
            var s = go.AddComponent<CanvasScaler>();
            s.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            s.referenceResolution = new Vector2(1280f, 720f);
            s.matchWidthOrHeight = 0.5f;
            go.AddComponent<GraphicRaycaster>();
            return c;
        }

        public static RectTransform Rect(Transform parent, string name, Vector2 aMin, Vector2 aMax)
        {
            var go = new GameObject(name, typeof(RectTransform));
            var rt = go.GetComponent<RectTransform>();
            rt.SetParent(parent, false);
            rt.anchorMin = aMin; rt.anchorMax = aMax;
            rt.offsetMin = Vector2.zero; rt.offsetMax = Vector2.zero;
            return rt;
        }

        public static Image Panel(Transform parent, string name, Color c, Vector2 aMin, Vector2 aMax)
        {
            var rt = Rect(parent, name, aMin, aMax);
            var img = rt.gameObject.AddComponent<Image>();
            img.color = c;
            img.raycastTarget = false;
            return img;
        }

        public static Text Label(Transform parent, string text, int size, Color col, TextAnchor anchor, Vector2 aMin, Vector2 aMax)
        {
            var rt = Rect(parent, "Label", aMin, aMax);
            var t = rt.gameObject.AddComponent<Text>();
            t.font = GetFont(); t.text = text; t.fontSize = size; t.color = col; t.alignment = anchor;
            t.horizontalOverflow = HorizontalWrapMode.Wrap; t.verticalOverflow = VerticalWrapMode.Overflow;
            t.raycastTarget = false;
            return t;
        }

        public static Button Btn(Transform parent, string text, Vector2 aMin, Vector2 aMax, Color bg, UnityAction onClick, int size = 28)
        {
            var rt = Rect(parent, "Btn_" + text, aMin, aMax);
            var img = rt.gameObject.AddComponent<Image>();
            img.color = bg;
            var b = rt.gameObject.AddComponent<Button>();
            b.targetGraphic = img;
            if (onClick != null) b.onClick.AddListener(onClick);
            Label(rt, text, size, Color.white, TextAnchor.MiddleCenter, Vector2.zero, Vector2.one);
            return b;
        }

        public static HoldButton Hold(Transform parent, string text, Vector2 aMin, Vector2 aMax, Color bg, System.Action<bool> cb, int size = 22)
        {
            var rt = Rect(parent, "Hold_" + text, aMin, aMax);
            var img = rt.gameObject.AddComponent<Image>();
            img.color = bg;
            var h = rt.gameObject.AddComponent<HoldButton>();
            h.Callback = cb; h.Graphic = img; h.Normal = bg;
            Label(rt, text, size, Color.white, TextAnchor.MiddleCenter, Vector2.zero, Vector2.one);
            return h;
        }
    }

    public class HoldButton : MonoBehaviour, IPointerDownHandler, IPointerUpHandler
    {
        public System.Action<bool> Callback;
        public Image Graphic;
        public Color Normal;

        public void OnPointerDown(PointerEventData e)
        {
            if (Callback != null) Callback(true);
            if (Graphic != null) Graphic.color = Normal * 1.6f;
        }

        public void OnPointerUp(PointerEventData e)
        {
            if (Callback != null) Callback(false);
            if (Graphic != null) Graphic.color = Normal;
        }

        void OnDisable() { if (Callback != null) Callback(false); }
    }
}

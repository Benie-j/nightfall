using System.Collections.Generic;
using UnityEngine;

namespace Nightfall.Audio
{
    /// <summary>
    /// Architecture voix off / dialogues : lit des AudioClip dans Resources/VO/{id}.
    /// Aucune voix n'est fournie ; l'ajout futur se fait en déposant des clips nommés par identifiant.
    /// </summary>
    public class VoiceOverManager : MonoBehaviour
    {
        readonly Queue<string> queue = new Queue<string>();
        AudioSource src;

        void Awake() { src = gameObject.AddComponent<AudioSource>(); src.spatialBlend = 0f; }

        public void Say(string lineId) { queue.Enqueue(lineId); }

        void Update()
        {
            if (src.isPlaying || queue.Count == 0) return;
            var clip = Resources.Load<AudioClip>("VO/" + queue.Dequeue());
            if (clip != null) { src.clip = clip; src.Play(); }
        }
    }
}

using System.Collections;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;
using Nightfall.AI;
using Nightfall.Combat;
using Nightfall.Missions;
using Nightfall.Player;

namespace Nightfall.Tests
{
    /// <summary>Parcours de jeu réel : mission 1 chargée par le contrôleur, ville + navigation + joueur + ennemis + objectifs.</summary>
    public class PlayFlowTests
    {
        MissionController mc;
        bool ended, won;

        [UnityTest]
        public IEnumerator MissionOneLoadsWithPlayerEnemiesAndNavigation()
        {
            MissionDatabase.Reload();
            ended = false;
            mc = MissionController.Create(MissionDatabase.All[0], null, (m, w, t, k) => { ended = true; won = w; });
            yield return null; yield return null;

            Assert.IsNotNull(mc);
            Assert.IsNotNull(NavGrid.Current, "la grille de navigation doit exister");
            Assert.IsNotNull(Object.FindFirstObjectByType<PlayerController>());
            Assert.Greater(Object.FindObjectsByType<EnemyAI>(FindObjectsSortMode.None).Length, 0);
            Assert.IsFalse(ended);
            yield return null;
            Object.Destroy(mc.gameObject);
            yield return null;
        }

        [UnityTest]
        public IEnumerator PlayerDeathEndsMissionAsFailure()
        {
            MissionDatabase.Reload();
            ended = false;
            mc = MissionController.Create(MissionDatabase.All[0], null, (m, w, t, k) => { ended = true; won = w; });
            yield return null;
            var player = Object.FindFirstObjectByType<PlayerController>();
            player.Health.TakeDamage(1000f, Vector3.zero);
            yield return null;
            Assert.IsTrue(ended);
            Assert.IsFalse(won);
            Object.Destroy(mc.gameObject);
            yield return null;
        }
    }
}

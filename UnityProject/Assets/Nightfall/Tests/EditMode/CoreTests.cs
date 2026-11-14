using System.Collections.Generic;
using NUnit.Framework;
using UnityEngine;
using Nightfall.AI;
using Nightfall.Combat;
using Nightfall.Missions;
using Nightfall.Player;
using Nightfall.Weapons;
using Nightfall.World;

namespace Nightfall.Tests
{
    public class CoreTests
    {
        [SetUp] public void Reload() { MissionDatabase.Reload(); }

        [Test]
        public void CampaignHasSixMissionsInOrder()
        {
            Assert.AreEqual(6, MissionDatabase.All.Count);
            for (int i = 0; i < 6; i++) Assert.AreEqual(i + 1, MissionDatabase.All[i].Number);
            Assert.AreEqual("Nuit noire à Siporex", MissionDatabase.All[0].Title);
            Assert.AreEqual("Nightfall", MissionDatabase.All[5].Title);
        }

        [Test]
        public void BriefingsComeFromSourceData()
        {
            foreach (var m in MissionDatabase.All)
            {
                Assert.IsFalse(string.IsNullOrEmpty(m.Briefing));
                StringAssert.DoesNotContain("[Texte provisoire]", m.Briefing);
            }
            StringAssert.Contains("explosion", MissionDatabase.All[0].Briefing);
        }

        [Test]
        public void MissionOneKeepsFiveSourceObjectives()
        {
            var m = MissionDatabase.All[0];
            Assert.IsTrue(m.HasSourceObjectives);
            Assert.AreEqual(5, m.Objectives.Count);
            Assert.AreEqual("reach_siporex", m.Objectives[0].Id);
            Assert.AreEqual(ObjectiveType.Interact, m.Objectives[1].Type);
            Assert.AreEqual(ObjectiveType.Collect, m.Objectives[3].Type);
            Assert.AreEqual(ObjectiveType.Escort, m.Objectives[4].Type);
            Assert.IsFalse(string.IsNullOrEmpty(m.Ending));
        }

        [Test]
        public void IntroIsLoadedFromSourceStory()
        {
            Assert.AreEqual(8, MissionDatabase.Intro.pages.Length);
            StringAssert.Contains("YOPOUGON", MissionDatabase.Intro.title);
        }

        [Test]
        public void MissionDifficultyIncreases()
        {
            for (int i = 1; i < MissionDatabase.All.Count; i++)
                Assert.Greater(MissionDatabase.All[i].EnemyCount, MissionDatabase.All[i - 1].EnemyCount);
        }

        [Test]
        public void ObjectivesArePlacedInIncreasingOrder()
        {
            var z = MissionDatabase.Placement(5, 5);
            for (int i = 1; i < z.Length; i++) Assert.Greater(z[i], z[i - 1]);
            Assert.LessOrEqual(z[4], 5 * 100f - 100f + 0.01f);
        }

        [Test]
        public void WeaponPresetsAreValid()
        {
            foreach (var c in new[] { WeaponConfig.Rifle(), WeaponConfig.Pistol(), WeaponConfig.Shotgun() })
            {
                Assert.Greater(c.Damage, 0f);
                Assert.Greater(c.MagSize, 0);
                Assert.Greater(c.Rpm, 0f);
                Assert.Less(c.SpreadAds, c.SpreadHip);
                Object.DestroyImmediate(c);
            }
        }

        [Test]
        public void HealthDiesAtZeroAndFiresEventOnce()
        {
            var go = new GameObject("t");
            var h = go.AddComponent<Health>();
            h.Init(50f);
            int died = 0;
            h.Died += () => died++;
            h.TakeDamage(30f, Vector3.zero);
            Assert.IsFalse(h.IsDead);
            h.TakeDamage(30f, Vector3.zero);
            h.TakeDamage(30f, Vector3.zero);
            Assert.IsTrue(h.IsDead);
            Assert.AreEqual(1, died);
            Object.DestroyImmediate(go);
        }

        [Test]
        public void ReleasedFireButtonDoesNotStayHeld()
        {
            TouchInput.FireHeld = true;
            Assert.IsTrue(TouchInput.FireHeld);
            TouchInput.FireHeld = false;
            Assert.IsFalse(TouchInput.FireHeld);
            TouchInput.AdsHeld = true; TouchInput.SprintHeld = true;
            TouchInput.ResetAll();
            Assert.IsFalse(TouchInput.AdsHeld);
            Assert.IsFalse(TouchInput.SprintHeld);
        }

        [Test]
        public void UnconsumedPressSurvivesOneFrameThenClears()
        {
            TouchInput.ResetAll();
            TouchInput.InteractPressed = true;
            TouchInput.EndFrame();
            Assert.IsTrue(TouchInput.InteractPressed);
            TouchInput.EndFrame();
            Assert.IsFalse(TouchInput.InteractPressed);
        }

        // ---- NavGrid (A*) : logique pure, sans physique ----
        static NavGrid Open(int w, int h) { return new NavGrid(0f, 0f, w, h, 1f, new bool[w * h]); }

        [Test]
        public void PathExistsOnOpenGrid()
        {
            var g = Open(20, 20);
            var path = new List<Vector3>();
            Assert.IsTrue(g.FindPath(new Vector3(1.5f, 0f, 1.5f), new Vector3(18.5f, 0f, 18.5f), path));
            Assert.Greater(path.Count, 0);
            Assert.AreEqual(18.5f, path[path.Count - 1].x, 0.01f);
        }

        [Test]
        public void PathGoesAroundWall()
        {
            var g = Open(20, 20);
            for (int z = 0; z < 18; z++) g.SetBlocked(10, z, true);   // mur avec un passage en haut
            var path = new List<Vector3>();
            Assert.IsTrue(g.FindPath(new Vector3(2.5f, 0f, 2.5f), new Vector3(17.5f, 0f, 2.5f), path));
            bool wentAround = false;
            foreach (var p in path) if (p.z >= 17f) wentAround = true;
            Assert.IsTrue(wentAround, "le chemin doit contourner le mur");
        }

        [Test]
        public void NoPathWhenFullyEnclosed()
        {
            var g = Open(20, 20);
            for (int z = 0; z < 20; z++) g.SetBlocked(10, z, true);
            var path = new List<Vector3>();
            Assert.IsFalse(g.FindPath(new Vector3(2.5f, 0f, 2.5f), new Vector3(17.5f, 0f, 2.5f), path));
        }

        [Test]
        public void SnapMovesPointOutOfObstacle()
        {
            var g = Open(10, 10);
            g.SetBlocked(5, 5, true);
            Vector3 p = g.Snap(new Vector3(5.5f, 0f, 5.5f));
            int x, z; g.ToCell(p, out x, out z);
            Assert.IsFalse(g.IsBlocked(x, z));
        }

        // ---- OSM : triangulation des empreintes ----
        [Test]
        public void ConcaveFootprintIsTriangulated()
        {
            var poly = new List<Vector2> { new Vector2(0, 0), new Vector2(0, 10), new Vector2(4, 10), new Vector2(4, 4), new Vector2(10, 4), new Vector2(10, 0) }; // L, sens horaire
            var tris = new List<int>();
            OsmWorld.Triangulate(poly, tris);
            Assert.AreEqual(4 * 3, tris.Count);
        }

        [Test]
        public void BuildingExtrusionProducesWallsAndRoof()
        {
            var acc = new OsmWorld.MeshAcc();
            var square = new List<Vector2> { new Vector2(0, 0), new Vector2(10, 0), new Vector2(10, 10), new Vector2(0, 10) };
            Assert.IsTrue(OsmWorld.AddBuilding(acc, square, 6f));
            Assert.AreEqual(4 * 4 + 4, acc.V.Count);        // 4 murs x 4 sommets + 4 sommets de toit
            Assert.AreEqual(4 * 6 + 2 * 3, acc.T.Count);    // 8 triangles de murs + 2 de toit
        }
    }
}

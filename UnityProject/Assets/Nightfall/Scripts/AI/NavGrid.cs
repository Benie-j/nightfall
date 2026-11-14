using System.Collections.Generic;
using UnityEngine;

namespace Nightfall.AI
{
    /// <summary>
    /// Navigation maison (le package AI Navigation / NavMeshSurface n'est pas disponible hors ligne) :
    /// grille d'occupation 2D + A* à 8 voisins + lissage par ligne de vue. La grille est échantillonnée
    /// avec Physics.CheckBox sur les colliders réels de la ville, avant l'apparition des personnages.
    /// Toute la logique de recherche de chemin est indépendante de la physique (testable en EditMode).
    /// </summary>
    public class NavGrid
    {
        public static NavGrid Current;

        public readonly int Width, Height;
        public readonly float Cell, MinX, MinZ;
        readonly bool[] blocked;

        // A*
        readonly float[] g;
        readonly int[] parent;
        readonly int[] stamp;
        readonly int[] closedStamp;
        int curStamp;

        public NavGrid(float minX, float minZ, int width, int height, float cell, bool[] blockedCells)
        {
            MinX = minX; MinZ = minZ; Width = width; Height = height; Cell = cell;
            blocked = blockedCells ?? new bool[width * height];
            g = new float[width * height];
            parent = new int[width * height];
            stamp = new int[width * height];
            closedStamp = new int[width * height];
        }

        /// <summary>Échantillonne les colliders de la scène. À appeler quand tous les secteurs sont actifs.</summary>
        public static NavGrid BuildFromPhysics(float minX, float maxX, float minZ, float maxZ, float cell, float agentRadius)
        {
            Physics.SyncTransforms();
            int w = Mathf.Max(1, Mathf.CeilToInt((maxX - minX) / cell));
            int h = Mathf.Max(1, Mathf.CeilToInt((maxZ - minZ) / cell));
            var b = new bool[w * h];
            Vector3 half = new Vector3(cell * 0.5f + agentRadius, 0.55f, cell * 0.5f + agentRadius);
            for (int z = 0; z < h; z++)
                for (int x = 0; x < w; x++)
                {
                    Vector3 c = new Vector3(minX + (x + 0.5f) * cell, 1.0f, minZ + (z + 0.5f) * cell);
                    b[z * w + x] = Physics.CheckBox(c, half, Quaternion.identity, ~0, QueryTriggerInteraction.Ignore);
                }
            return new NavGrid(minX, minZ, w, h, cell, b);
        }

        public bool IsBlocked(int x, int z) { return x < 0 || z < 0 || x >= Width || z >= Height || blocked[z * Width + x]; }
        public void SetBlocked(int x, int z, bool v) { if (x >= 0 && z >= 0 && x < Width && z < Height) blocked[z * Width + x] = v; }

        public int BlockedCount { get { int n = 0; for (int i = 0; i < blocked.Length; i++) if (blocked[i]) n++; return n; } }

        public void ToCell(Vector3 p, out int x, out int z)
        {
            x = Mathf.Clamp(Mathf.FloorToInt((p.x - MinX) / Cell), 0, Width - 1);
            z = Mathf.Clamp(Mathf.FloorToInt((p.z - MinZ) / Cell), 0, Height - 1);
        }

        public Vector3 ToWorld(int x, int z, float y)
        {
            return new Vector3(MinX + (x + 0.5f) * Cell, y, MinZ + (z + 0.5f) * Cell);
        }

        bool NearestFree(ref int cx, ref int cz, int maxRadius)
        {
            if (!IsBlocked(cx, cz)) return true;
            for (int r = 1; r <= maxRadius; r++)
                for (int dz = -r; dz <= r; dz++)
                    for (int dx = -r; dx <= r; dx++)
                    {
                        if (Mathf.Abs(dx) != r && Mathf.Abs(dz) != r) continue;
                        if (!IsBlocked(cx + dx, cz + dz)) { cx += dx; cz += dz; return true; }
                    }
            return false;
        }

        /// <summary>Centre de la cellule libre la plus proche de p (p inchangé si la grille est entièrement bloquée).</summary>
        public Vector3 Snap(Vector3 p)
        {
            int x, z;
            ToCell(p, out x, out z);
            if (!NearestFree(ref x, ref z, 8)) return p;
            return ToWorld(x, z, p.y);
        }

        static readonly int[] Dx = { 1, -1, 0, 0, 1, 1, -1, -1 };
        static readonly int[] Dz = { 0, 0, 1, -1, 1, -1, 1, -1 };

        /// <summary>Remplit 'result' avec les points de passage (monde). Renvoie false si aucun chemin n'existe.</summary>
        public bool FindPath(Vector3 from, Vector3 to, List<Vector3> result, int maxExpansions = 6000)
        {
            result.Clear();
            int sx, sz, ex, ez;
            ToCell(from, out sx, out sz);
            ToCell(to, out ex, out ez);
            bool goalWasBlocked = IsBlocked(ex, ez);
            if (!NearestFree(ref sx, ref sz, 3) || !NearestFree(ref ex, ref ez, 6)) return false;
            int start = sz * Width + sx, goal = ez * Width + ex;
            if (start == goal) { result.Add(new Vector3(to.x, from.y, to.z)); return true; }

            curStamp++;
            var open = new Heap();
            g[start] = 0f; parent[start] = -1; stamp[start] = curStamp;
            open.Push(start, Heuristic(sx, sz, ex, ez));
            int expansions = 0;
            bool found = false;

            while (open.Count > 0 && expansions++ < maxExpansions)
            {
                int cur = open.Pop();
                if (closedStamp[cur] == curStamp) continue;
                closedStamp[cur] = curStamp;
                if (cur == goal) { found = true; break; }
                int cx = cur % Width, cz = cur / Width;
                for (int k = 0; k < 8; k++)
                {
                    int nx = cx + Dx[k], nz = cz + Dz[k];
                    if (IsBlocked(nx, nz)) continue;
                    if (k >= 4 && (IsBlocked(cx + Dx[k], cz) || IsBlocked(cx, cz + Dz[k]))) continue; // pas de coupe de coin
                    int ni = nz * Width + nx;
                    if (closedStamp[ni] == curStamp) continue;
                    float ng = g[cur] + (k < 4 ? 1f : 1.4142f);
                    if (stamp[ni] != curStamp || ng < g[ni])
                    {
                        stamp[ni] = curStamp; g[ni] = ng; parent[ni] = cur;
                        open.Push(ni, ng + Heuristic(nx, nz, ex, ez));
                    }
                }
            }
            if (!found) return false;

            var cells = new List<int>();
            for (int n = goal; n != -1; n = parent[n]) cells.Add(n);
            cells.Reverse();

            // Lissage : on saute les cellules intermédiaires tant que la ligne de vue reste libre.
            int anchor = 0;
            result.Clear();
            for (int i = 1; i < cells.Count; i++)
            {
                int ax = cells[anchor] % Width, az = cells[anchor] / Width;
                int bx = cells[i] % Width, bz = cells[i] / Width;
                if (!LineClear(ax, az, bx, bz))
                {
                    int p = cells[i - 1];
                    result.Add(ToWorld(p % Width, p / Width, from.y));
                    anchor = i - 1;
                }
            }
            result.Add(goalWasBlocked ? ToWorld(ex, ez, from.y) : new Vector3(to.x, from.y, to.z));
            return true;
        }

        static float Heuristic(int ax, int az, int bx, int bz)
        {
            int dx = Mathf.Abs(ax - bx), dz = Mathf.Abs(az - bz);
            return (dx + dz) + (1.4142f - 2f) * Mathf.Min(dx, dz);
        }

        /// <summary>Ligne de vue sur la grille (Bresenham, avec épaisseur d'une cellule).</summary>
        public bool LineClear(int x0, int z0, int x1, int z1)
        {
            int dx = Mathf.Abs(x1 - x0), dz = Mathf.Abs(z1 - z0);
            int sx = x0 < x1 ? 1 : -1, sz = z0 < z1 ? 1 : -1;
            int err = dx - dz;
            int x = x0, z = z0;
            while (true)
            {
                if (IsBlocked(x, z)) return false;
                if (x == x1 && z == z1) return true;
                int e2 = 2 * err;
                bool movedX = false, movedZ = false;
                if (e2 > -dz) { err -= dz; x += sx; movedX = true; }
                if (e2 < dx) { err += dx; z += sz; movedZ = true; }
                if (movedX && movedZ && (IsBlocked(x - sx, z) || IsBlocked(x, z - sz))) return false;
            }
        }

        // Tas binaire min (priorité = coût estimé).
        sealed class Heap
        {
            readonly List<int> items = new List<int>();
            readonly List<float> keys = new List<float>();
            public int Count { get { return items.Count; } }

            public void Push(int item, float key)
            {
                items.Add(item); keys.Add(key);
                int i = items.Count - 1;
                while (i > 0)
                {
                    int p = (i - 1) / 2;
                    if (keys[p] <= keys[i]) break;
                    Swap(p, i); i = p;
                }
            }

            public int Pop()
            {
                int top = items[0];
                int last = items.Count - 1;
                items[0] = items[last]; keys[0] = keys[last];
                items.RemoveAt(last); keys.RemoveAt(last);
                int i = 0;
                while (true)
                {
                    int l = 2 * i + 1, r = l + 1, s = i;
                    if (l < items.Count && keys[l] < keys[s]) s = l;
                    if (r < items.Count && keys[r] < keys[s]) s = r;
                    if (s == i) break;
                    Swap(s, i); i = s;
                }
                return top;
            }

            void Swap(int a, int b)
            {
                int ti = items[a]; items[a] = items[b]; items[b] = ti;
                float tk = keys[a]; keys[a] = keys[b]; keys[b] = tk;
            }
        }
    }
}

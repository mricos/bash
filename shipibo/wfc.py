import numpy as np
import random
from collections import defaultdict, Counter

def rotate(pattern):
    return np.rot90(pattern)

def pattern_to_hash(pattern):
    return hash(pattern.tobytes())

# Step 2: Extract Unique Patterns from Input Sample

def extract_patterns(sample, N):
    """
    Extract all N×N overlapping patterns from input sample.
    """
    patterns = []
    H, W = sample.shape

    for y in range(H - N + 1):
        for x in range(W - N + 1):
            pattern = sample[y:y+N, x:x+N]
            patterns.append(pattern.copy())

    return patterns

# Step 3: Build Pattern Dictionary and Adjacency Rules

def build_pattern_rules(patterns):
    """
    Count frequency and determine adjacency rules.
    """
    pattern_hash_map = {}
    hash_to_pattern = {}
    adjacency = defaultdict(lambda: defaultdict(set))
    freq_counter = Counter()

    for p in patterns:
        for k in range(4):  # Consider 4 rotations
            rotated = np.rot90(p, k)
            h = pattern_to_hash(rotated)
            pattern_hash_map[h] = rotated
            hash_to_pattern[h] = rotated
            freq_counter[h] += 1

    pattern_ids = list(hash_to_pattern.keys())

    # Create adjacency rules
    for id1 in pattern_ids:
        for id2 in pattern_ids:
            p1 = hash_to_pattern[id1]
            p2 = hash_to_pattern[id2]

            # Check horizontal compatibility (right of p1, left of p2)
            if np.array_equal(p1[:, 1:], p2[:, :-1]):
                adjacency[id1]['right'].add(id2)
                adjacency[id2]['left'].add(id1)

            # Check vertical compatibility (below p1, above p2)
            if np.array_equal(p1[1:, :], p2[:-1, :]):
                adjacency[id1]['down'].add(id2)
                adjacency[id2]['up'].add(id1)

    return freq_counter, adjacency, hash_to_pattern

# Step 4: Initialize Output Grid and Constraints

class WFCCell:
    def __init__(self, possible):
        self.possible = set(possible)  # Set of pattern ids

    def is_collapsed(self):
        return len(self.possible) == 1

    def entropy(self):
        return len(self.possible)

# Step 5: Main WFC Solver

def wave_function_collapse(sample, N=2, out_width=10, out_height=10):
    patterns = extract_patterns(sample, N)
    freq_counter, adjacency, id_to_pattern = build_pattern_rules(patterns)

    pattern_ids = list(id_to_pattern.keys())
    grid = [[WFCCell(pattern_ids) for _ in range(out_width)] for _ in range(out_height)]

    def get_neighbors(x, y):
        dirs = {'up': (0, -1), 'down': (0, 1), 'left': (-1, 0), 'right': (1, 0)}
        result = {}
        for dir, (dx, dy) in dirs.items():
            nx, ny = x + dx, y + dy
            if 0 <= nx < out_width and 0 <= ny < out_height:
                result[dir] = (nx, ny)
        return result

    def propagate():
        changed = True
        while changed:
            changed = False
            for y in range(out_height):
                for x in range(out_width):
                    cell = grid[y][x]
                    if cell.is_collapsed():
                        continue
                    neighbors = get_neighbors(x, y)
                    for direction, (nx, ny) in neighbors.items():
                        neighbor_cell = grid[ny][nx]
                        compatible = set()
                        for pid in cell.possible:
                            compatible |= adjacency[pid][direction]
                        before = neighbor_cell.possible.copy()
                        neighbor_cell.possible &= compatible
                        if before != neighbor_cell.possible:
                            changed = True
                        if not neighbor_cell.possible:
                            raise Exception("Contradiction: no valid patterns!")

    def find_lowest_entropy_cell():
        min_entropy = float('inf')
        best_cells = []
        for y in range(out_height):
            for x in range(out_width):
                cell = grid[y][x]
                if not cell.is_collapsed():
                    e = cell.entropy()
                    if e < min_entropy:
                        best_cells = [(x, y)]
                        min_entropy = e
                    elif e == min_entropy:
                        best_cells.append((x, y))
        return random.choice(best_cells) if best_cells else None

    try:
        while True:
            next_cell = find_lowest_entropy_cell()
            if not next_cell:
                break  # Done

            x, y = next_cell
            cell = grid[y][x]
            # Weighted random choice
            weighted = [(pid, freq_counter[pid]) for pid in cell.possible]
            total = sum(w for pid, w in weighted)
            r = random.uniform(0, total)
            acc = 0
            for pid, w in weighted:
                acc += w
                if r <= acc:
                    chosen = pid
                    break
            cell.possible = {chosen}
            propagate()

        # Build final output image
        result = np.zeros((out_height + N - 1, out_width + N - 1), dtype=sample.dtype)
        for y in range(out_height):
            for x in range(out_width):
                pid = next(iter(grid[y][x].possible))
                pattern = id_to_pattern[pid]
                result[y:y+N, x:x+N] = pattern  # Simple overwrite

        return result
    except Exception as e:
        print("Failed with contradiction, try again:", str(e))
        return None


if __name__ == "__main__":
    # Sample input: a tiny 5x5 tile map / texture
    sample = np.array([
        [1, 1, 0, 0, 1],
        [1, 0, 0, 1, 1],
        [0, 0, 1, 1, 0],
        [0, 1, 1, 0, 0],
        [1, 1, 0, 0, 1]
    ])

    output = wave_function_collapse(sample, N=2, out_width=10, out_height=10)
    if output is not None:
        print("Generated output:")
        print(output)


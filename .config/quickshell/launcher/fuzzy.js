.pragma library

// Fuzzy matching for the launcher panels' search: how well what you typed matches a name (its letters in order,
// scoring more for runs and word starts), and which letters matched, so they can be highlighted

function match(query, target) {
    const q = query.toLowerCase(), t = target.toLowerCase();
    if (q === "")
        return { score: -t.length * 0.01, indices: [] };
    let best = null;
    for (let start = t.indexOf(q[0]); start !== -1; start = t.indexOf(q[0], start + 1)) {
        const indices = [start];
        for (let ti = start + 1; ti < t.length && indices.length < q.length; ti++)
            if (t[ti] === q[indices.length])
                indices.push(ti);
        if (indices.length < q.length)
            break;
        let score = 0, run = 1;
        for (let i = 0; i < indices.length; i++) {
            score++;
            if (i > 0 && indices[i] === indices[i - 1] + 1)
                score += ++run * 3;
            else
                run = 1;
            if (indices[i] === 0)
                score += 8;
            else if (" -._/".includes(t[indices[i] - 1]))
                score += 6;
        }
        if (!best || score > best.score)
            best = { score: score, indices: indices };
    }
    if (!best)
        return null;
    best.score -= t.length * 0.01;
    return best;
}

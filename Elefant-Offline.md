# Elefant-Offline

Local cache of memories to replay into Elefant once it's back. When Elefant's
embedder is unreachable (e.g. `403 Forbidden` for search/list/capture calls),
write each new memory here as a dated entry, tagged with project
`xash3d-continuum` (aka legacy `xash-streaming`). When Elefant returns, replay
the entries into the durable tier, then delete the replayed entries from this
file.

Status: **empty** — all entries replayed into Elefant on 2026-06-16 (durable
tier, project tags `xash3d-continuum` + `xash-streaming`). The transient
embedder-outage note was intentionally not replayed (not a durable fact).

---

<!-- Add new offline-cache entries below this line when Elefant is down. -->

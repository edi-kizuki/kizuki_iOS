---
id: 005
title: "Local container runtime for Supabase"
labels: [wayfinder:task]
status: closed
blocked_by: []
assignee:
created: 2026-10-25
---

# Local container runtime for Supabase

Map: [[2026-10-25-wayfinder-map]]

## Question

HITL: install and start Docker Desktop, OrbStack or Colima so 'supabase start' and local DB tests run. Done when 'supabase start' succeeds in the repo.

## Resolution (2026-10-25)

OrbStack installed; Docker engine 29.8.2. `scripts/supabase-local.sh start` succeeded (db, auth, rest, realtime, kong, inbucket healthy). `scripts/supabase-local.sh test`: pgTAP 10/10 PASS plus local API check exit 0. Disk free after images: 6.3 GiB.

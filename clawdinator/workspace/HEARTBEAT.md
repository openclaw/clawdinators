# HEARTBEAT.md

Hourly SITREP checklist:

1. Read AGENTS.md comms rules (terse chat, details to files)
2. Read `/memory/index.md` and `/memory/sitrep-latest.md` for context
3. Persist any relevant channel updates to today's daily memory file
4. Run triage skill (`skills/triage/SKILL.md`):
   - Read `/memory/github/prs.md` and `/memory/github/issues.md`
   - Compare against previous sitrep for changes
5. Write SITREP to `/memory/sitrep-latest.md` (overwrite):
   ```markdown
   # SITREP YYYY-MM-DDTHH:MMZ

   ## 🔥 Fires
   - Active issues needing immediate attention

   ## ⚡ NOW
   - Single most important action to take

   ## 📊 Dashboard
   - PRs: X open (Y approved waiting)
   - Issues: X open (Y bugs, Z features)

   ## 🔄 Changes since last SITREP
   - NEW/CLOSED/UPDATED items
   ```
6. Append summary to today's daily file (`/memory/daily/YYYY-MM-DD.md`)
7. Post terse summary to chat (3-5 lines, link to sitrep-latest.md)
8. If nothing needs attention, reply HEARTBEAT_OK

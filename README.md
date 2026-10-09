# Frontier render image

The tools a Frontier cloud render machine needs (ffmpeg, Deno, Node, Python packages, Chromium, the
subtitle model), installed once so a rented machine starts rendering in about a minute.
No Frontier code, keys or channels are in here: those arrive from your own bucket when a machine boots.

Rebuild: push a change to Dockerfile or requirements.txt, or Actions → build render image → Run workflow.
Use it: `FARM_IMAGE=ghcr.io/<owner>/frontier-render:latest` in Frontier's .env.

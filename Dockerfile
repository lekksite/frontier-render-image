# Frontier render pod — optional.
#
# You do not need this. By default a pod starts from a stock Python image and
# installs what it needs in four to eight minutes, which costs under two cents.
# Build this instead once that wait annoys you: it is the same software, already
# installed, so a pod is rendering about a minute after you rent it.
#
#   docker build --platform linux/amd64 -t <you>/frontier-render:1 -f farm/Dockerfile .
#   docker push  <you>/frontier-render:1
#   FARM_IMAGE=<you>/frontier-render:1      # in your .env
#
# --platform linux/amd64 is not optional on an Apple Silicon Mac: RunPod machines
# are x86, and an arm64 image starts and then fails on the first binary it runs.
# Building it under emulation is slow — once, in the background, is the idea.
#
# The code is NOT baked in. Frontier still arrives from your bucket at boot, so
# editing a style file does not mean rebuilding and pushing a gigabyte.

FROM python:3.11-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PLAYWRIGHT_BROWSERS_PATH=/opt/pw

# ffmpeg renders; node is what YouTube demands before it hands yt-dlp anything
# better than 360p; the fonts are Chromium's fallback, Frontier's own type being
# bundled and embedded.
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends \
      ffmpeg curl unzip xz-utils ca-certificates nodejs fonts-liberation fonts-dejavu-core \
 && rm -rf /var/lib/apt/lists/*

# The same modern ffmpeg (7.x, BtbN's builds) and Deno that provision.sh installs on a bare pod: Debian's ffmpeg 5.1
# left dots on flat graphics, and with Node 18 alone yt-dlp cannot unlock YouTube's HD formats (9 Oct 2026).
RUN FF_URL=$(curl -fsSL --retry 3 https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/tags/latest | python -c 'import json,re,sys; a=[x["browser_download_url"] for x in json.load(sys.stdin).get("assets",[])]; r=sorted((tuple(int(v) for v in m.group(1).split(".")),u) for u in a for m in [re.search(r"ffmpeg-n([0-9.]+)-latest-linux64-gpl-[0-9.]+\.tar\.xz$",u)] if m); print(r[-1][1])') \
 && curl -fsSL --retry 3 -o /tmp/ff.tar.xz "$FF_URL" \
 && mkdir -p /opt/ffmpeg && tar -xJf /tmp/ff.tar.xz -C /opt/ffmpeg --strip-components=1 && rm /tmp/ff.tar.xz \
 && /opt/ffmpeg/bin/ffmpeg -hide_banner -encoders | grep -q libx264 \
 && ln -sf /opt/ffmpeg/bin/ffmpeg /usr/local/bin/ffmpeg && ln -sf /opt/ffmpeg/bin/ffprobe /usr/local/bin/ffprobe \
 && curl -fsSL --retry 3 -o /tmp/deno.zip https://github.com/denoland/deno/releases/latest/download/deno-x86_64-unknown-linux-gnu.zip \
 && unzip -oq /tmp/deno.zip -d /usr/local/bin && chmod +x /usr/local/bin/deno && rm /tmp/deno.zip && deno --version

COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt \
 && python -m playwright install --with-deps chromium

# The subtitle model, downloaded now so no render pays for it.
ENV WHISPER_MODEL=base
RUN python -c "from faster_whisper import WhisperModel; \
WhisperModel('base', device='cpu', compute_type='int8')"

WORKDIR /frontier
CMD ["python", "-u", "-m", "farm.runner"]

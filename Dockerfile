# The data tools (tools/stage.py) in a container: makes and updates the game
# data folder from a PC install, on any system with Docker or Podman.
#
# The image holds only the programs the packers need. The tools themselves
# are run from the repository mounted at /repo, so a `git pull` takes effect
# without rebuilding the image.
#
# Build (from the repository's top folder):
#   podman build -t nfsu2-tools .
#
# Set up / update the game data folder (only what is missing or out of date
# is redone, so run the same command again after updating the repository):
#   podman run --rm \
#     -v "$PWD:/repo:z" \
#     -v "<PC install, the folder SPEED2.EXE is in>:/pc:ro,z" \
#     -v "<SD card>/nfsu2:/gamedir:z" \
#     nfsu2-tools
#
# Anything after the image name goes to stage.py: --list (show what is out of
# date), --force, --only cars,tracks, --mod /mod (with the mod folder mounted
# at /mod), --help. With Docker instead of Podman, add
# --user "$(id -u):$(id -g)" so the files it writes are yours, and leave out
# the ":z" (an SELinux label Podman needs on Fedora and the like).

FROM docker.io/library/python:3.14-slim-trixie

# ffmpeg with libx264: the .wav tracks, the .mvd movies, the audio resampling.
RUN apt-get update \
 && apt-get install -y --no-install-recommends ffmpeg gcc libc6-dev curl unzip ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    numpy==2.5.4 pillow==13.0.0 lz4==4.4.5 pefile==2024.8.26 unicorn==2.1.4 capstone==5.0.9

# dspenc, the DSP-ADPCM encoder, from the repository's own source.
COPY tools/src/dspenc.c /tmp/dspenc.c
RUN cc -O2 -o /usr/local/bin/dspenc /tmp/dspenc.c -lm && rm /tmp/dspenc.c

# tex3ds, devkitPro's texture converter (etc1_tex.py, for the tracks' ETC1
# textures), from devkitPro's own image: it needs only libstdc++.
COPY --from=docker.io/devkitpro/devkitarm:20260610 /opt/devkitpro/tools/bin/tex3ds /usr/local/bin/tex3ds

# vgmstream-cli, the EA audio decoder.
ARG VGMSTREAM=r2168
RUN mkdir /opt/vgmstream && cd /opt/vgmstream \
 && curl -fsSLo v.zip "https://github.com/vgmstream/vgmstream/releases/download/${VGMSTREAM}/vgmstream-linux.zip" \
 && unzip -q v.zip && rm v.zip && chmod +x vgmstream-cli \
 && ln -s /opt/vgmstream/vgmstream-cli /usr/local/bin/vgmstream-cli \
 && apt-get purge -y gcc libc6-dev curl unzip && apt-get autoremove -y

# HOME for a non-root --user; no .pyc files written into the mounted repo.
ENV HOME=/tmp PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /repo
ENTRYPOINT ["python", "/repo/tools/stage.py", "--pc", "/pc", "--gamedir", "/gamedir"]

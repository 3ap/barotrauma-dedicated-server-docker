###########################################################
# Dockerfile that builds a Barotrauma server
###########################################################
FROM steamcmd/steamcmd:ubuntu-26

LABEL maintainer="leon.pelech@gmail.com"

ENV STEAMAPPID 1026340
ENV STEAMAPPDIR /home/steam/barotrauma-dedicated

# Create steam user
RUN useradd --create-home --shell /bin/bash steam

# The base image hardcodes HOME=/root for everything, which breaks the
# steam user once we switch to it further down (e.g. Steam API looks for
# steamclient.so under $HOME)
ENV HOME=/home/steam
ENV USER=steam

# steamcmd/steamcmd already ships steamcmd and the required runtime, so we
# just need to install the game. steamcmd occasionally fails with
# "Missing configuration" for no clear reason, so retry a few times when
# that specific error happens.
RUN set -euxo pipefail; \
    attempt=0; \
    max_attempts=50; \
    while true; do \
        attempt=$((attempt+1)); \
        if steamcmd \
            @ShutdownOnFailedCommand \
            @NoPromptForPassword \
            +force_install_dir ${STEAMAPPDIR} \
            +login anonymous \
            +app_update ${STEAMAPPID} validate \
            +quit 2>&1 | tee /tmp/steamcmd.log; then \
            break; \
        fi; \
        if ! grep -q "Failed to install app '1026340' (Missing configuration)" /tmp/steamcmd.log; then \
            echo "steamcmd failed with an unexpected error (attempt $attempt), aborting"; \
            exit 1; \
        fi; \
        if [ "$attempt" -ge "$max_attempts" ]; then \
            echo "steamcmd failed with 'Missing configuration' after $max_attempts attempts, aborting"; \
            exit 1; \
        fi; \
        echo "steamcmd failed with 'Missing configuration' (attempt $attempt/$max_attempts), retrying..."; \
        sleep 2; \
    done

# steamcmd ran as root, so the game files it installed are root-owned; hand
# them over to steam, which is what actually runs the server
RUN chown -R steam:steam ${STEAMAPPDIR}

# Create directory to hold steamclient.so symlink
RUN set -x \
  && mkdir -p /home/steam/.steam/sdk64 \
	&& chown -R steam:steam /home/steam/.steam \
	&& ln -s ${STEAMAPPDIR}/steamclient.so /home/steam/.steam/sdk64/steamclient.so

# Create Multiplayer save directory for volume mount
ENV BAR_MULTIPLAYER_SAVE_DIR "/home/steam/.local/share/Daedalic Entertainment GmbH/Barotrauma/Multiplayer"
RUN set -x \
  && mkdir -p "$BAR_MULTIPLAYER_SAVE_DIR" \
  && chown -R steam:steam "$BAR_MULTIPLAYER_SAVE_DIR/../.."

# Copy custom files for server
COPY --chown=steam:steam entry.sh ${STEAMAPPDIR}/entry.sh
RUN chmod 755 ${STEAMAPPDIR}/entry.sh

# Update these ENV values...
ENV BAR_PASSWORD=changeme! \
  BAR_NAME=UnnamedServer \
  BAR_SERVERMESSAGE="" \
  BAR_START_WHEN_CLIENTS_READY=True \
  BAR_START_WHEN_CLIENTS_READY_RATIO=1.0

USER steam

WORKDIR $STEAMAPPDIR

VOLUME $STEAMAPPDIR
VOLUME $BAR_MULTIPLAYER_SAVE_DIR

ENTRYPOINT ${STEAMAPPDIR}/entry.sh

# Expose ports
EXPOSE 27015/tcp 27015/udp
EXPOSE 27016/tcp 27016/udp

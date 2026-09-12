###########################################################
# Dockerfile that builds a Barotrauma server
###########################################################
FROM steamcmd/steamcmd:ubuntu-26

LABEL maintainer="leon.pelech@gmail.com"

ENV STEAMAPPID 1026340
ENV STEAMAPPDIR /home/steam/barotrauma-dedicated

# Create steam user
RUN useradd --create-home --shell /bin/bash steam

# steamcmd/steamcmd already ships steamcmd and the required runtime, so we
# just need to install the game
RUN steamcmd \
    @ShutdownOnFailedCommand \
    @NoPromptForPassword \
    +force_install_dir ${STEAMAPPDIR} \
    +login anonymous \
    +app_update ${STEAMAPPID} validate \
    +quit

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

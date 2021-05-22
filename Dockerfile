FROM golang

# install dependencies etc.
RUN dpkg --add-architecture i386 \
  && apt-get update \
  && apt-get install -y \
  bash \
  sudo \
  binutils \
  curl \
  dnsutils \
  gdb \
  libc?-i386 \
  libcurl4-gnutls-dev:i386 \
  lib32stdc++? \
  libstdc++? \
  libstdc++?:i386 \
  lib32gcc1 \
  lib32ncurses? \
  lib32z1 \
  libsdl2-2.0-0:i386 \
  lib32stdc++6 \
  expect \
  net-tools \
  unzip \
  && apt-get clean

ENV USER=admin
ENV UID=10001

RUN groupadd -f -g ${UID} ${USER} \
  && useradd -o --shell /bin/bash -u ${UID} -g ${UID} -m ${USER} \
  && echo "${USER} ALL=(ALL)NOPASSWD: ALL" >> /etc/sudoers

# Docker directories
ENV APPDIR="/app"
ENV HOME="/home/admin"
ENV INSTALL_DIR="/home/admin/csgo-base/"

# SQL Settings
ENV db_Host=""
ENV db_Name=""
ENV db_User=""
ENV db_Password=""
ENV db_Port="3306"

# Server settings
ENV GSLTS=""
ENV AUTHKEY=""
ENV WS_COLLECTION="1809672996"
ENV admins=""

WORKDIR ${APPDIR}
ADD src ${APPDIR}
RUN cd ${APPDIR} && chmod +x setup.sh && chown ${USER} -R ${APPDIR}
CMD [ "setup.sh" ]

USER ${USER}
ENTRYPOINT [ "/bin/bash" ]
EXPOSE 27015 27005 27020 8080
# Todo: Cron for autoupdate
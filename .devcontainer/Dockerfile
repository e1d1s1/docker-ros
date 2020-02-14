ARG FROM
FROM $FROM

ARG USER=dev
ARG UID=1000
ARG GID=1000

ENV HOME /home/$USER

RUN getent group $GID || $(groupadd --gid $GID $USER)
RUN getent passwd $UID || $(useradd --uid $UID --gid $GID -m -d $HOME -s /bin/bash $USER && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER && \
    chmod 0440 /etc/sudoers.d/$USER)

RUN sudo apt-get update && sudo apt-get install --force-yes sudo

USER $USER

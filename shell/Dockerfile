ARG FROM
FROM $FROM

ARG USER=dev
ARG UID=1000
ARG GID=1000

ENV HOME /home/$USER

RUN groupadd --gid $GID $USER && \
    useradd --uid $UID --gid $GID -m -d $HOME -s /bin/bash $USER && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USER && \
    chmod 0440 /etc/sudoers.d/$USER

#RUN apt-get update -y && \
#    apt-get dist-upgrade -y && \
#    rm -r /var/lib/apt/lists/*

RUN apt-get update && apt-get install -y --force-yes --fix-missing --no-install-recommends \
    net-tools \
    mesa-utils \
    rsync

USER $USER

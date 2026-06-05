# Use an official Ubuntu as a parent image
FROM docker.io/library/ubuntu:jammy
ENV PYTHONUNBUFFERED 1

ARG GIT_REPO=https://github.com/jackie1218/textgen.git
ARG DO_PULL=true
ENV DO_PULL $DO_PULL

# Set the working directory in the container
WORKDIR /workspace/text-generation-webui

# Add deadsnakes ppa, Install additional software, remove any SSH host keys
RUN DEBIAN_FRONTEND=noninteractive apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common tzdata && add-apt-repository ppa:deadsnakes/ppa && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    ca-certificates \
    dumb-init \
    python3.13 \
#    python3.13-pip \
    git \
    ssh \
    7zip \
    htop \
    iputils-ping \
    git-lfs \
    less \
    nano \
    neovim \
    net-tools \
    nvi \
    nvtop \
    rsync \
    tldr \
    tmux \
    unzip \
    vim \
    wget \
    zip \
    zsh \
    && rm -rf /etc/ssh/ssh_host_*

# Set locale
# RUN apt-get install -y locales && \
#    localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
# ENV LANG en_US.utf8

# Upgrade all installed packages
RUN apt-get upgrade -y

# Change global Python settings for convenience
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 1 \
    && apt-get install -y --no-install-recommends python-is-python3 \
    && rm -rf /var/lib/apt/lists/* 

# Upgrade pip
RUN curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
	&& python3 ./get-pip.py \
	&& python3 -m pip install --no-cache-dir --upgrade pip

# Set up git to support LFS, and to cache credentials
RUN git config --global credential.helper cache && \
    git lfs install

# Clone oobabooga/text-generation-webui repo
RUN if [ ${DO_PULL} ]; then \
    git config --global init.defaultBranch master && \
    git init && \
    git remote add origin $GIT_REPO && \
    git fetch origin && \
    git pull origin main && \
    git branch --set-upstream-to=origin/main master && \
    echo "Pull finished"; fi

# Run oobabooga installation procedure
RUN sed -i 's|^        launch_webui()|        #launch_webui()|g' one_click.py
RUN GPU_CHOICE=A LAUNCH_AFTER_INSTALL=FALSE INSTALL_EXTENSIONS=FALSE ./start_linux.sh
RUN sed -i 's|^        #launch_webui()|        launch_webui()|g' one_click.py

# Make port 7860, 5000 and 22 available on the network
EXPOSE 7860 5000 22

# Install Huggingface tools
RUN python3 -m pip install --no-cache-dir hf_transfer huggingface-hub[cli]

# Install custom supplemental scripts and configurations
WORKDIR /
COPY --chmod=755 runpod.sh /runpod.sh
COPY --chmod=755 restart.sh /root/bin/restart.sh
COPY --chmod=644 ooba-options.sh /workspace/ooba-options.sh
COPY --chmod=755 run-text-generation-webui.sh /root/bin/run-text-generation-webui.sh

# Copy build code to the container
RUN mkdir -p /workspace/text-generation-webui/docker/RunPod
COPY Dockerfile docker-compose.yaml /workspace/text-generation-webui/docker/RunPod

# Configure tldr
RUN mkdir -p /root/.local/share/tldr && tldr -u

# Set the entry point
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Run when the container launches
CMD ["bash", "-c", "/runpod.sh"]

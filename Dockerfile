FROM ubuntu:focal
LABEL maintainer="JongsLee<jongseo12345@gmail.com>"
# Use Ubuntu 20.04 (Focal Fossa) as the base image


SHELL ["/bin/bash", "-c"]

# Upgrade OS
RUN apt-get update -q --fix-missing && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# Install Ubuntu Mate desktop
RUN apt-get update -q --fix-missing && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ubuntu-mate-desktop && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# Add Package
RUN apt-get update --fix-missing && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    tigervnc-standalone-server tigervnc-common \
    supervisor wget curl gosu git sudo python3-pip tini \
    build-essential vim sudo lsb-release locales \
    bash-completion tzdata terminator && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# noVNC and Websockify
RUN git clone https://github.com/AtsushiSaito/noVNC.git -b add_clipboard_support /usr/lib/novnc
RUN pip install git+https://github.com/novnc/websockify.git@v0.10.0
RUN ln -s /usr/lib/novnc/vnc.html /usr/lib/novnc/index.html

# Set remote resize function enabled by default
RUN sed -i "s/UI.initSetting('resize', 'off');/UI.initSetting('resize', 'remote');/g" /usr/lib/novnc/app/ui.js

# Disable auto update and crash report
RUN sed -i 's/Prompt=.*/Prompt=never/' /etc/update-manager/release-upgrades
RUN sed -i 's/enabled=1/enabled=0/g' /etc/default/apport

# Enable apt-get completion
RUN rm /etc/apt/apt.conf.d/docker-clean

# Install Firefox
RUN DEBIAN_FRONTEND=noninteractive add-apt-repository ppa:mozillateam/ppa -y && \
    echo 'Package: *' > /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox && \
    apt-get update -q && \
    apt-get install -y --allow-downgrades firefox && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# Install VSCodium
RUN wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
    | gpg --dearmor \
    | dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg && \
    echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' \
    | tee /etc/apt/sources.list.d/vscodium.list && \
    apt-get update -q && \
    apt-get install -y codium && \
    apt-get autoclean && \
    apt-get autoremove && \
    rm -rf /var/lib/apt/lists/*

# Install ROS Noetic
ENV ROS_DISTRO=noetic
# desktop-full, desktop, or ros-base
ARG INSTALL_PACKAGE=desktop-full

# Install ROS Noetic and catkin_tools
RUN apt-get update -q && \
    apt-get install -y curl gnupg2 lsb-release && \
    curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add - && \
    echo "deb [arch=$(dpkg --print-architecture)] http://packages.ros.org/ros/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros1.list > /dev/null && \
    apt-get update -q && \
    apt-get install -y ros-${ROS_DISTRO}-${INSTALL_PACKAGE} \
    python3-rosdep python3-rosinstall python3-rosinstall-generator python3-wstool build-essential && \
    apt-get install -y python3-catkin-tools && \ 
    rosdep init && \
    rm -rf /var/lib/apt/lists/*

# Use a single RUN command to source and build to ensure environment variables are correctly used
RUN apt-get update -q && \
    /bin/bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash && \
    mkdir -p /home/ubuntu/catkin_ws/src && \
    cd /home/ubuntu/catkin_ws && \
    catkin_make && \
    source devel/setup.bash && \
    catkin init && \
    cd src && \
    git clone -b ${ROS_DISTRO}-devel https://github.com/ROBOTIS-GIT/turtlebot3_msgs.git && \
    git clone -b ${ROS_DISTRO}-devel https://github.com/ROBOTIS-GIT/turtlebot3.git && \
    cd .. && \
    rosdep update && \
    rosdep install --from-paths src --ignore-src -r -y && \
    catkin_make"

# Environment setup
RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> /home/ubuntu/.bashrc && \
    echo "source /home/ubuntu/catkin_ws/devel/setup.bash" >> /home/ubuntu/.bashrc && \
    echo "export ROS_MASTER_URI=http://localhost:11311" >> /home/ubuntu/.bashrc && \
    echo "export ROS_HOSTNAME=localhost" >> /home/ubuntu/.bashrc


COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/bin/bash", "-c", "/entrypoint.sh"]


ENV USER ubuntu
ENV PASSWD ubuntu

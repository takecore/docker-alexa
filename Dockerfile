FROM ubuntu:xenial
MAINTAINER Michael Ruettgers <michael@ruettgers.eu>

# Let the conatiner know that there is no tty
ENV DEBIAN_FRONTEND noninteractive

# Define packages to be installed
ENV PACKAGES \
  openssl \
  libasound2 \
  libatlas3-base \
  vlc \
  vlc-nox \
  vlc-data \
  gettext \
  maven

# Define build packages to be installed temporarily
ENV BUILD_PACKAGES \
  git \
  sudo \
  curl \
  libasound2-dev \
  libatlas-base-dev \ 
  build-essential

# Install packages && cleanup
RUN apt-get update && \
  apt-get upgrade -y && \
  apt-get -y install $PACKAGES $BUILD_PACKAGES

# Install Java & Node
RUN apt-get install -y software-properties-common && \
  LC_ALL=C.UTF-8 add-apt-repository ppa:webupd8team/java && \
  (curl -sL https://deb.nodesource.com/setup_7.x | sudo -E bash -) && \
  apt-get update && \
  echo "oracle-java8-installer shared/accepted-oracle-license-v1-1 select true" | sudo debconf-set-selections && \
  apt-get -y install nodejs oracle-java8-installer && \
  apt-get -y purge software-properties-common 

# Checkout sources
RUN cd /usr/local/src && \
  git clone https://github.com/alexa/alexa-avs-sample-app -b master && \
  git clone https://github.com/Kitt-AI/snowboy.git

# Prepare certs, client, companion service and wake-word-agent
# Certs will be generated in /docker/docker-entrypoint.sh
RUN mkdir -p /opt/alexa && \
  mkdir /opt/alexa/certs && cp /usr/local/src/alexa-avs-sample-app/samples/javaclient/ssl.cnf /opt/alexa/certs/ && \
  cp -a /usr/local/src/alexa-avs-sample-app/samples/javaclient /opt/alexa/ && \
  cp -a /usr/local/src/alexa-avs-sample-app/samples/companionService /opt/alexa/ && \
  cp -a /usr/local/src/alexa-avs-sample-app/samples/wakeWordAgent /opt/alexa/ && \
  cd /opt/alexa/companionService && npm install

# Cleanup packages, build packages and sources
#RUN apt-get -y purge $BUILD_PACKAGES && \
#  apt-get autoremove -y && \
#  rm -rf /usr/share/doc/* && \
#  rm -rf /usr/share/man/* && \
#  rm -rf /usr/share/locale/* && \
#  rm -rf /usr/local/src/*

VOLUME /opt/alexa/certs

EXPOSE 3000

COPY ./docker /docker
ENTRYPOINT ["/docker/docker-entrypoint.sh"]
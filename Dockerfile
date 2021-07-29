FROM ubuntu:20.04
ENV DEBIAN_FRONTEND="noninteractive" TZ="Europe/London"

RUN chsh -s /bin/bash
RUN apt-get update ; apt-get install -y apt-transport-https ; apt -y upgrade
RUN apt install -y curl \
        wget \
        git \
        vim \
        gnupg \
        python \
        apt-utils \
        libvips \
        software-properties-common \
        debconf-utils \
        apt-transport-https \
        lsb-release \
        make \
        ca-certificates \
        fonts-liberation \
        libappindicator3-1 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libc6 \
        libcups2 \
        libexpat1 \
        libgbm1 \
        libgcc1 \
        libglib2.0-0 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libpango-1.0-0 \
        libpangocairo-1.0-0 \
        libstdc++6 \
        libx11-6 \
        libx11-xcb1 \
        libxcb1 \
        libxcomposite1 \
        libxcursor1 \
        libxdamage1 \
        libxext6 \
        libxfixes3 \
        libxi6 \
        libxrandr2 \
        libxss1 \
        xdg-utils \
        gconf-service \
        libasound2 \
        libcairo2 \
        libdbus-1-3 \
        libfontconfig1 \
        libgconf-2-4 \
        libgdk-pixbuf2.0-0 \
        libxrender1 \
        libxtst6 \
        libappindicator1

# Install OAE supporting software
RUN apt install -y redis-server
RUN apt install -y nginx
RUN apt install -y openjdk-8-jre-headless
RUN apt install -y libreoffice
RUN wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.9.0-amd64.deb && dpkg -i elasticsearch-7.9.0-amd64.deb
RUN printf "\nnetwork.host: 127.0.0.1" >> /etc/elasticsearch/elasticsearch.yml

# Install and set up Cassandra
RUN wget https://downloads.apache.org/cassandra/2.1.22/apache-cassandra-2.1.22-bin.tar.gz
RUN tar -xzvf apache-cassandra-2.1.22-bin.tar.gz
RUN mv apache-cassandra-2.1.22 /usr/local/cassandra
RUN adduser --group cassandra ; adduser --shell /bin/bash --gecos "" --ingroup cassandra --disabled-password cassandra
RUN usermod -aG cassandra cassandra
RUN chown root:cassandra -R /usr/local/cassandra/
RUN chmod g+w -R /usr/local/cassandra/
RUN echo "cassandra_parms=\"$cassandra_parms -Dcassandra.logdir=$CASSANDRA_HOME/logs\"" >> /usr/local/cassandra/bin/cassandra
RUN adduser --group node ; adduser --shell /bin/bash --gecos "" --ingroup node --disabled-password node

# Install chromium (unsafe PPA)
RUN add-apt-repository ppa:saiarcot895/chromium-beta
RUN apt-get update && apt install -y chromium-browser

# Tell Puppeteer to skip installing Chrome. We'll be using the installed package.
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Install and setup node and pm2
RUN curl -fsSL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
RUN curl -fsSL https://deb.nodesource.com/setup_15.x | bash -
RUN apt install -y nodejs
RUN npm install -g npm@7.0.8
RUN npm install -g pm2

# Change user from now on
USER node

# Set the Hilary directory
ENV CODE_DIR /home/node
WORKDIR ${CODE_DIR}

# Clone and set up Hilary
RUN git clone https://github.com/oaeproject/Hilary.git
ENV HILARY_DIR ${CODE_DIR}/Hilary
ENV UI_DIR ${HILARY_DIR}/3akai-ux
WORKDIR ${HILARY_DIR}
RUN git submodule sync ; git submodule update --init

# Costumise Hilary configuration
RUN printf "\nconfig.cassandra.hosts = ['localhost'];" >> config.js ;\
    printf "\nconfig.cassandra.timeout = 9000;" >> config.js ;\
    printf "\nconfig.redis.host = 'localhost';" >> config.js ;\
    printf "\nconfig.search.nodes = ['http://localhost:9200'];" >> config.js ;\
    printf "\nconfig.mq.host = 'localhost';" >> config.js ;\
    printf "\nconfig.previews.enabled = true;" >> config.js ;\
    printf "\nconfig.email.debug = false;" >> config.js ;\
    printf "\nconfig.email.transport = 'sendmail';" >> config.js ;\
    printf "\nconfig.previews.office.binary = '/usr/bin/soffice';" >> config.js ;\
    printf "\nconfig.previews.screenShotting.binary = '/usr/bin/chromium-browser';" >> config.js ;\
    printf "\nconfig.previews.screenShotting.sandbox = '--no-sandbox';" >> config.js

# Set up Etherpad
RUN sed -i 's/oae-cassandra/localhost/g'    ep-settings.json
RUN sed -i 's/oae-redis/localhost/g'        ep-settings.json
RUN cp ep-settings.json                     etherpad/settings.json
RUN cp ep-package.json                      etherpad/src/package.json

# Set up Ethercalc
RUN cp ec-package.json                      ethercalc/package.json

# Create the temp directory for Hilary
ENV TMP_DIR ${HILARY_DIR}/tmp
RUN mkdir -p ${TMP_DIR}
RUN mkdir -p ${TMP_DIR}/previews
RUN mkdir -p ${TMP_DIR}/uploads
RUN mkdir -p ${TMP_DIR}/files
RUN chown -R node:node ${TMP_DIR} && chmod -R 777 ${TMP_DIR} && export TMP=${TMP_DIR}
RUN chown -R node:node ${CODE_DIR} && chmod -R 777 ${CODE_DIR}

# Install Hilary dependencies
RUN cd ethercalc && npm install
RUN ./prepare-etherpad.sh
RUN cd 3akai-ux && npm install
RUN npm install

# Setup PM2
RUN sed -i 's/\/opt\/current/\/home\/node\/Hilary/g' process.json

# Install cqlsh for testing
RUN curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
RUN python get-pip.py
RUN ~/.local/bin/pip install cqlsh
RUN echo "CREATE KEYSPACE IF NOT EXISTS \"etherpad\" WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1 };" >> init.cql

USER root

# Set up nginx
RUN cd ${HILARY_DIR} && \
        openssl req \
        -x509 \
        -nodes \
        -days 3650 \
        -subj "/C=PE/ST=Lima/L=Lima/O=Acme Inc. /OU=IT Department/CN=acme.com" \
        -newkey rsa:2048 \
        -keyout ${UI_DIR}/nginx/nginx-selfsigned.key \
        -out ${UI_DIR}/nginx/nginx-selfsigned.crt
RUN cd ${HILARY_DIR} && \
        openssl dhparam \
        -out ${UI_DIR}/nginx/dhparam.pem 2048
RUN sed -i 's/192\.168\.3\.148/localhost/g'                                 ${UI_DIR}/nginx/nginx.docker.conf
RUN sed -i 's/oae-etherpad/localhost/g'                                     ${UI_DIR}/nginx/nginx.docker.conf
RUN sed -i 's/oae-ethercalc/localhost/g'                                    ${UI_DIR}/nginx/nginx.docker.conf
RUN sed -i 's/\/usr\/src\//\/home\/node\//g'                                ${UI_DIR}/nginx/nginx.docker.conf
RUN sed -i 's/\/usr\/share\/files/\/home\/node\/Hilary\/tmp\/files/g'   ${UI_DIR}/nginx/nginx.docker.conf
RUN cp ${UI_DIR}/nginx/nginx.docker.conf                                    ${UI_DIR}/nginx/nginx.conf
RUN cp ${UI_DIR}/nginx/nginx.conf               /etc/nginx/
RUN cp ${UI_DIR}/nginx/mime.conf                /etc/nginx/
RUN cp ${UI_DIR}/nginx/self-signed.conf         /etc/nginx/
RUN cp ${UI_DIR}/nginx/ssl-params.conf          /etc/nginx/
RUN cp ${UI_DIR}/nginx/dhparam.pem              /etc/nginx/
RUN cp ${UI_DIR}/nginx/nginx-selfsigned.key     /etc/nginx/
RUN cp ${UI_DIR}/nginx/nginx-selfsigned.crt     /etc/nginx/
RUN cp ${UI_DIR}/nginx/dhparam.pem              /etc/nginx/

# Set up environment variables Hilary needs to start
RUN echo "export RECAPTCHA_KEY=yada yada" >> /home/node/.profile
RUN echo "export TWITTER_KEY=yada yada" >> /home/node/.profile
RUN echo "export TWITTER_SECRET=yada yada" >> /home/node/.profile
RUN echo "export FACEBOOK_APP_ID=yada yada" >> /home/node/.profile
RUN echo "export FACEBOOK_APP_SECRET=yada yada" >> /home/node/.profile
RUN echo "export GOOGLE_CLIENT_ID=yada yada" >> /home/node/.profile
RUN echo "export GOOGLE_CLIENT_SECRET=yada yada" >> /home/node/.profile
RUN echo "export ETHEREAL_USER=yada yada" >> /home/node/.profile
RUN echo "export ETHEREAL_PASS=yada yada" >> /home/node/.profile
RUN echo "export TMP=/home/node/Hilary/tmp" >> /home/node/.profile

# 80:   Nginx HTTP
# 443:  Nginx HTTPS
# 2000: Hilary admin worker
# 2001: Hilary worker
# 6379: Redis service
# 7000: intra-node communication
# 7001: TLS intra-node communication
# 7199: JMX
# 8000: Ethercalc service
# 9001: Etherpad service
# 9042: CQL
# 9160: thrift service
EXPOSE 80 443 2000 2001 6379 7000 7001 7199 8000 9001 9042 9160

# Run the app - you may override CMD via docker run command line instruction
ENTRYPOINT ["/bin/bash", "-c"]
CMD ["JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 /usr/local/cassandra/bin/cassandra > /usr/local/cassandra/cassandra.log ; service elasticsearch start ; service redis-server start ; service nginx start ; runuser -l node -c 'cd Hilary ; npm run migrate ; ~/.local/bin/cqlsh -f init.cql ; pm2 startOrReload process.json ; pm2 logs'"]


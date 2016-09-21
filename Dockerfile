FROM phusion/baseimage
MAINTAINER Jose Luis Ruiz <jose@wazuh.com>


RUN apt-get update && apt-get install -y python-software-properties nodejs debconf-utils daemontools wget vim npm gcc make libssl-dev unzip
RUN cd root && mkdir ossec_tmp && cd ossec_tmp

# Copy the unattended installation config file from the build context
# and put it where the OSSEC install script can find it. Then copy the
# process. Then run the install script, which will turn on just about
# everything except e-mail notifications


RUN wget https://github.com/wazuh/ossec-wazuh/archive/v1.1.1.tar.gz &&\
    tar xvfz v1.1.1.tar.gz &&\
    mv ossec-wazuh-1.1.1 /root/ossec_tmp/ossec-wazuh &&\
    rm v1.1.1.tar.gz
#ADD ossec-wazuh /root/ossec_tmp/ossec-wazuh
COPY preloaded-vars.conf /root/ossec_tmp/ossec-wazuh/etc/preloaded-vars.conf

RUN /root/ossec_tmp/ossec-wazuh/install.sh

RUN wget https://github.com/wazuh/wazuh-API/archive/v1.2.tar.gz &&\
    tar xvfz v1.2.tar.gz &&\
    mkdir -p /var/ossec/api && cp -r wazuh-API-1.2/* /var/ossec/api &&\
    cd /var/ossec/api && npm install

RUN apt-get remove --purge -y gcc make && apt-get clean

# Set persistent volumes for the /etc and /log folders so that the logs
# and agent keys survive a start/stop and expose ports for the
# server/client ommunication (1514) and the syslog transport (514)

#
# Add a default agent due to this bug
# https://groups.google.com/forum/#!topic/ossec-list/qeC_h3EZCxQ
#
ADD default_agent /var/ossec/default_agent
RUN service ossec restart &&\
  /var/ossec/bin/manage_agents -f /default_agent &&\
  rm /var/ossec/default_agent &&\
  service ossec stop &&\
  echo -n "" /var/ossec/logs/ossec.log

#
# Initialize the data volume configuration
#
ADD data_dirs.env /data_dirs.env
ADD init.bash /init.bash
# Sync calls are due to https://github.com/docker/docker/issues/9547
RUN chmod 755 /init.bash &&\
  sync && /init.bash &&\
  sync && rm /init.bash

#
# Add the bootstrap script
#
ADD run.bash /run.bash
RUN chmod 755 /run.bash

#
# Specify the data volume 
#
VOLUME ["/var/ossec/data"]

# Expose ports for sharing
EXPOSE 55000/tcp 1514/udp 1515/tcp 5601/tcp 515/udp

#
# Define default command.
#
ENTRYPOINT ["/run.bash"]

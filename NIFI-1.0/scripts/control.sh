#!/bin/sh
#
#    Licensed to the Apache Software Foundation (ASF) under one or more
#    contributor license agreements.  See the NOTICE file distributed with
#    this work for additional information regarding copyright ownership.
#    The ASF licenses this file to You under the Apache License, Version 2.0
#    (the "License"); you may not use this file except in compliance with
#    the License.  You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
# chkconfig: 2345 20 80
# description: Apache NiFi is a dataflow system based on the principles of Flow-Based Programming.
#

# Script structure inspired from Apache Karaf and other Apache projects with similar startup approaches

export NIFI_DEFAULT_HOME=/opt/app/cloudera/parcels/NIFI
NIFI_HOME=${NIFI_HOME:-$CDH_NIFI_HOME}
export NIFI_HOME=${NIFI_HOME:-$NIFI_DEFAULT_HOME}

PROGNAME=`basename "$0"`

warn() {
    echo "${PROGNAME}: $*"
}

die() {
    warn "$*"
    exit 1
}

unlimitFD() {
    # Use the maximum available, or set MAX_FD != -1 to use that
    if [ "x$MAX_FD" = "x" ]; then
        MAX_FD="maximum"
    fi

    # Increase the maximum file descriptors if we can
    if [ "$os400" = "false" ] && [ "$cygwin" = "false" ]; then
        MAX_FD_LIMIT=`ulimit -H -n`
        if [ "$MAX_FD_LIMIT" != 'unlimited' ]; then
            if [ $? -eq 0 ]; then
                if [ "$MAX_FD" = "maximum" -o "$MAX_FD" = "max" ]; then
                    # use the system max
                    MAX_FD="$MAX_FD_LIMIT"
                fi

                ulimit -n $MAX_FD > /dev/null
                # echo "ulimit -n" `ulimit -n`
                if [ $? -ne 0 ]; then
                    warn "Could not set maximum file descriptor limit: $MAX_FD"
                fi
            else
                warn "Could not query system maximum file descriptor limit: $MAX_FD_LIMIT"
            fi
        fi
    fi
}



locateJava() {
    if [ "x$JAVA" = "x" ] && [ -r /etc/gentoo-release ] ; then
        JAVA_HOME=`java-config --jre-home`
    fi
    if [ "x$JAVA" = "x" ]; then
        if [ "x$JAVA_HOME" != "x" ]; then
            if [ ! -d "$JAVA_HOME" ]; then
                die "JAVA_HOME is not valid: $JAVA_HOME"
            fi
            JAVA="$JAVA_HOME/bin/java"
        else
            warn "JAVA_HOME not set; results may vary"
            JAVA=`type java`
            JAVA=`expr "$JAVA" : '.* \(/.*\)$'`
            if [ "x$JAVA" = "x" ]; then
                die "java command not found"
            fi
        fi
    fi
}

init() {
    # Unlimit the number of file descriptors if possible
    unlimitFD

    # Locate the Java VM to execute
    locateJava
}
NIFI_PROPS="$NIFI_HOME/conf/zookeeper.properties"
#echo "$ZK_QUORUM this is zk quorum" >> $NIFI_HOME/conf/zookeeper.properties
#echo $HOST this is host >> $NIFI_HOME/conf/zookeeper.properties
#echo $host this is hst >> $NIFI_HOME/conf/zookeeper.properties
run() {
    BOOTSTRAP_CONF="$NIFI_HOME/conf/bootstrap.conf";
HOST=`hostname -f`
perl -pi -e "s/nifi.zookeeper.connect.string=/nifi.zookeeper.connect.string=$ZK_QUORUM/" $NIFI_HOME/conf/nifi.properties
perl -pi -e 's/nifi.cluster.is.node=false/nifi.cluster.is.node=true/' $NIFI_HOME/conf/nifi.properties
perl -pi -e "s/nifi.cluster.node.address=/nifi.cluster.node.address=$HOST/" $NIFI_HOME/conf/nifi.properties
perl -pi -e 's/nifi.cluster.node.protocol.port=/nifi.cluster.node.protocol.port=9090/' $NIFI_HOME/conf/nifi.properties
perl -pi -e "s/nifi.remote.input.host=/nifi.remote.input.host=$HOST/" $NIFI_HOME/conf/nifi.properties
perl -pi -e 's/nifi.remote.input.socket.port=/nifi.remote.input.socket.port=9097/' $NIFI_HOME/conf/nifi.properties
perl -pi -e "s/nifi.web.http.host=/nifi.web.http.host=$HOST/" $NIFI_HOME/conf/nifi.properties
perl -pi -e 's|nifi.zookeeper.root.node=/nifi|nifi.zookeeper.root.node=/opt/app/data/zookeeper|' $NIFI_HOME/conf/nifi.properties
    echo
    echo "Java home: $JAVA_HOME"
    echo "NiFi home: $NIFI_HOME"
    echo
    echo "Bootstrap Config File: $BOOTSTRAP_CONF"
    echo

    exec "$JAVA" -cp "$NIFI_HOME"/conf/:"$NIFI_HOME"/lib/bootstrap/* -Xms12m -Xmx24m -Dorg.apache.nifi.bootstrap.config.file="$BOOTSTRAP_CONF" org.apache.nifi.bootstrap.RunNiFi $@
}

main() {
    init
    run "$@"
}


case "$1" in
    start|stop|run|status|dump)
        main "$@"
        ;;
    restart)
        init
	run "stop"
	run "start"
	;;
    *)
        echo "Usage nifi {start|stop|run|restart|status|dump}"
        ;;
esac

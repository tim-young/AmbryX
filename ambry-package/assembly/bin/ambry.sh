#!/bin/bash
# Author : Hash Zhang

# Constants definition:
BIN_DIR=$(cd `dirname $0`;pwd)
DEPLOY_DIR=$(cd $BIN_DIR;cd ..;pwd)
CONF_DIR=$DEPLOY_DIR/conf
LIB_DIR=$DEPLOY_DIR/lib
LIB_JARS=`ls $LIB_DIR|grep .jar|awk '{print "'$LIB_DIR'/"$0}'|tr "\n" ":"`
LOG_DIR=$DEPLOY_DIR/logs
JVM_PARAS=" -Dlog4j.configuration=file:${CONF_DIR}/log4j.properties "
JVM_DEBUG_OPTS=""
JVM_JMX_OPTS=""
JVM_MEM_OPTS=" -server -Xmx2g -Xms1g -Xmn64m -XX:PermSize=64m -Xss256k -XX:+DisableExplicitGC -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:+UseCMSCompactAtFullCollection -XX:LargePageSizeInBytes=128m -XX:+UseFastAccessorMethods -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=70 "
SYS_PROPERTIES=""
SYS_CLUSTER_PARA=""

for arg in $*
do
    if [ "debug"x = "$arg"x ]
    then
        echo "In debug mode!"
        JVM_DEBUG_OPTS=" -Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_socket,address=8000,server=y,suspend=n "
    elif [ "jmx"x = "$arg"x ]
    then
        echo "Enable JMX!"
        JVM_JMX_OPTS=" -Dcom.sun.management.jmxremote.port=1099 -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false "
    elif [ "minMem"x = "$arg"x ]
    then
        echo "In min memory mode!"
        JVM_MEM_OPTS=" -server -Xmx256m -Xms128m "
    fi
done

watchBootstrap () {
    ret=0;
    while [ $ret -eq 0 ]
    do
        output=`cat ${LOG_DIR}/stdout.out|grep "Server start"`
        if [[ $output != "" ]]
        then
            ret=1
        else
            output=`cat ${LOG_DIR}/stdout.out|grep "Server shutdown"`
            if [[ $output != "" ]]
            then
                 ret=2
            fi
        fi
        sleep 1
        echo -ne "."
    done
    if [ $ret -eq 2 ]
    then
        echo -e "\n************************Failed to start $1!************************\n"
        cat ${LOG_DIR}/stdout.out
    else
        echo -e "\n************************$1 started!************************\n"
    fi
}

getConfiguration(){
    configurations=`ls ${CONF_DIR}`
    count=1
    for var in $configurations
    do
        echo "${count}. ${var}"
        count=`expr $count + 1`
    done
    echo -n "Please input the sequence number of the Configuration for server properties: "
    read number
    count=1
    for var in $configurations
    do
        if [ $count -eq $number ]
        then
            SYS_PROPERTIES="--serverPropsFilePath ${CONF_DIR}/${var}"
        fi
        count=`expr $count + 1`
    done
    count=1
    for var in $configurations
    do
        echo "${count}. ${var}"
        count=`expr $count + 1`
    done
    echo -n "Please input the sequence number of the Configuration for hardwareLayout: "
    read number
    count=1
    for var in $configurations
    do
        if [ $count -eq $number ]
        then
            SYS_CLUSTER_PARA="--hardwareLayoutFilePath ${CONF_DIR}/${var}"
        fi
        count=`expr $count + 1`
    done
    count=1
    for var in $configurations
    do
        echo "${count}. ${var}"
        count=`expr $count + 1`
    done
    echo -n "Please input the sequence number of the Configuration for partitionLayout: "
    read number
    count=1
    for var in $configurations
    do
        if [ $count -eq $number ]
        then
            SYS_CLUSTER_PARA="${SYS_CLUSTER_PARA} --partitionLayoutFilePath ${CONF_DIR}/${var}"
        fi
        count=`expr $count + 1`
    done
}
specifyConfiguration(){
    echo "which is the server properties(please put your configuration files in the configuration folder:${CONF_DIR})?"
    getConfiguration
}

bootServer () {
    echo -e "\n************************Please specify the module you want to start:************************\n"
    echo "1. Ambry-Server"
    echo "2. Ambry-Frontend"
    echo "3. Ambry-Admin"
    echo -n "Your selection is(input 1,2 or 3):"

    read MODULE
    echo ""
    case $MODULE in
    1)
        specifyConfiguration
        echo "Starting Ambry-Server"
        java $JVM_DEBUG_OPTS $JVM_JMX_OPTS $JVM_MEM_OPTS $JVM_PARAS -classpath $CONF_DIR:$LIB_JARS com.github.ambry.server.AmbryMain ${SYS_PROPERTIES} ${SYS_CLUSTER_PARA} > ${LOG_DIR}/stdout.out 2>&1 &
        watchBootstrap "Ambry-Server"
        echo -e "\n************************************************************************\n"
        ;;
    2)
        specifyConfiguration
        echo "Starting Ambry-Frontend"
        java $JVM_DEBUG_OPTS $JVM_JMX_OPTS $JVM_MEM_OPTS $JVM_PARAS -classpath $CONF_DIR:$LIB_JARS  com.github.ambry.frontend.AmbryFrontendMain ${SYS_PROPERTIES} ${SYS_CLUSTER_PARA} > ${LOG_DIR}/stdout.out 2>&1 &
        watchBootstrap "Ambry-Frontend"
        echo -e "\n************************************************************************\n"
        ;;
    3)
        specifyConfiguration
        echo "Starting Ambry-Admin"
        java $JVM_DEBUG_OPTS $JVM_JMX_OPTS $JVM_MEM_OPTS $JVM_PARAS -classpath $CONF_DIR:$LIB_JARS  com.github.ambry.admin.AdminMain ${SYS_PROPERTIES} ${SYS_CLUSTER_PARA} > ${LOG_DIR}/stdout.out 2>&1 &
        watchBootstrap "Ambry-Admin"
        echo -e "\n************************************************************************\n"
        ;;
    esac
}

stopServer (){
    count=1
    pids=$1
    for var in $pids
    do
        echo "${count}. ${var}"
        count=`expr $count + 1`
    done
    if [ -n "$2" -a $count -gt 1 ]
    then
        echo -n "Please input the sequence number of the PID you want to stop: "
        read pid
        count=1
        for var in $pids
        do
            if [ $count -eq $pid ]
            then
                ret=`kill -9 "${var}"`
                echo $ret
            fi
            count=`expr $count + 1`
        done
    elif [ $count -lt 2 ]
    then
        echo "No Alive Ambry-Server exists!"
    fi
}

showServer () {
    echo ""
    echo "1. Ambry-Server"
    echo "2. Ambry-Frontend"
    echo "3. Ambry-Admin"
    echo -n "Your selection is(input 1,2 or 3):"
    read MODULE
    echo ""
    case $MODULE in
    1)
        pids=`ps -ef|grep ambry|grep "${DEPLOY_DIR}"|grep com.github.ambry.server.AmbryMain|awk '{print $2}'`
        echo -e "\n************************Current Ambry-Server Pids:************************\n"
        stopServer $pids $1
        echo -e "\n************************************************************************\n"
        ;;
    2)
        pids=`ps -ef|grep ambry|grep "${DEPLOY_DIR}"|grep com.github.ambry.frontend.AmbryFrontendMain|awk '{print $2}'`
        echo -e "\n************************Current Ambry-Frontend Pids:************************\n"
        stopServer $pids $1
        echo -e "\n************************************************************************\n"
        ;;
    3)
        pids=`ps -ef|grep ambry|grep "${DEPLOY_DIR}"|grep com.github.ambry.admin.AdminMain|awk '{print $2}'`
        echo -e "\n************************Current Ambry-Admin Pids:************************\n"
        stopServer $pids $1
        echo -e "\n************************************************************************\n"
        ;;
    esac
}


while [ 1 = 1 ]
do
    echo -e "\n************************Welcome to ambry!************************\n"
    echo "1. Boot a server"
    echo "2. Watch the server list in current host"
    echo "3. Stop a server"
    echo -n "Your selection is(input 1,2 or 3):"
    read SELECTION
    echo ""
    case $SELECTION in
    1)
        bootServer
        ;;
    2)
        showServer
        ;;
    3)
        showServer true
        ;;
    esac
done


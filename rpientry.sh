#!/bin/bash
# description:Node deamon script
#


# Set this to your Node installation
NODE_HOME=/usr/bin

scriptFile=$(readlink -fn $(type -p $0))                   # the absolute, dereferenced path of this script file
scriptDir=$(dirname $scriptFile)                           # absolute path of the script directory
serviceNameLo="raspberrypi-entryphone"                                  # service name with the first letter in lowercase
serviceName="RaspberryPi Entryphone"                                    # service name
serviceUser="root"                                      # OS user name for the service
serviceGroup="root"                                    # OS group name for the service
applDir="/home/user/$serviceNameLo"                          # home directory of the service application
serviceLogFile="/var/log/$serviceNameLo.log"               # log file for StdOut/StdErr
maxShutdownTime=60                                         # maximum number of seconds to wait for the daemon to terminate normally
pidFile="/var/run/$serviceNameLo.pid"                      # name of PID file (PID = process ID number)
nodeCommand="nodejs"                                         # name of the Node launcher without the path
nodeExe="$NODE_HOME/$nodeCommand"                      # file name of the Node application launcher executable
nodeArgs="server.js"                     # arguments for Node launcher
nodeCommandLine="$nodeExe $nodeArgs"                       # command line to start the Node service application
nodeCommandLineKeyword="server.js"                     # a keyword that occurs on the commandline, used to detect an already running service process and to distinguish it from others

# Makes the file $1 writable by the group $serviceGroup.
function makeFileWritable {
   local filename="$1"
   touch $filename || return 1
   chgrp $serviceGroup $filename || return 1
   chmod g+w $filename || return 1
   return 0; }

# Returns 0 if the process with PID $1 is running.
function checkProcessIsRunning {
   local pid="$1"
   if [ -z "$pid" -o "$pid" == " " ]; then return 1; fi
   if [ ! -e /proc/$pid ]; then return 1; fi
   return 0; }

# Returns 0 if the process with PID $1 is our Node service process.
function checkProcessIsOurService {
   local pid="$1"
   if [ "$(ps -p $pid --no-headers -o comm)" != "$nodeCommand" ]; then return 1; fi
   grep -q --binary -F "$nodeCommandLineKeyword" /proc/$pid/cmdline
   if [ $? -ne 0 ]; then return 1; fi
   return 0; }

# Returns 0 when the service is running and sets the variable $pid to the PID.
function getServicePID {
   if [ ! -f $pidFile ]; then return 1; fi
   pid="$(<$pidFile)"
   checkProcessIsRunning $pid || return 1
   checkProcessIsOurService $pid || return 1
   return 0; }

function startServiceProcess {
   cd $applDir || return 1
   rm -f $pidFile
   makeFileWritable $pidFile || return 1
   makeFileWritable $serviceLogFile || return 1
   cmd="nohup $nodeCommandLine >>$serviceLogFile 2>&1 & echo \$! >$pidFile"
   # Don't forget to add -H so the HOME environment variable will be set correctly.
   sudo -u $serviceUser -H $SHELL -c "$cmd" || return 1
   sleep 0.1
   pid="$(<$pidFile)"
   if checkProcessIsRunning $pid; then :; else
      echo -ne "\n$serviceName start failed, see logfile."
      return 1
   fi
   return 0; }

function stopServiceProcess {
   kill $pid || return 1
   for ((i=0; i<maxShutdownTime*10; i++)); do
      checkProcessIsRunning $pid
      if [ $? -ne 0 ]; then
         rm -f $pidFile
         return 0
         fi
      sleep 0.1
      done
   echo -e "\n$serviceName did not terminate within $maxShutdownTime seconds, sending SIGKILL..."
   kill -s KILL $pid || return 1
   local killWaitTime=15
   for ((i=0; i<killWaitTime*10; i++)); do
      checkProcessIsRunning $pid
      if [ $? -ne 0 ]; then
         rm -f $pidFile
         return 0
         fi
      sleep 0.1
      done
   echo "Error: $serviceName could not be stopped within $maxShutdownTime+$killWaitTime seconds!"
   return 1; }

function startService {
   getServicePID
   if [ $? -eq 0 ]; then echo -n "$serviceName is already running"; RETVAL=0; return 0; fi
   echo -n "Starting $serviceName   "
   startServiceProcess
   if [ $? -ne 0 ]; then RETVAL=1; echo "failed"; return 1; fi
   echo "started PID=$pid"
   RETVAL=0
   return 0; }

function stopService {
   getServicePID
   if [ $? -ne 0 ]; then echo -n "$serviceName is not running"; RETVAL=0; echo ""; return 0; fi
   echo -n "Stopping $serviceName   "
   stopServiceProcess
   if [ $? -ne 0 ]; then RETVAL=1; echo "failed"; return 1; fi
   echo "stopped PID=$pid"
   RETVAL=0
   return 0; }

function checkServiceStatus {
   echo -n "Checking for $serviceName:   "
   if getServicePID; then
	echo "running PID=$pid"
	RETVAL=0
   else
	echo "stopped"
	RETVAL=3
   fi
   return 0; }

function main {
   RETVAL=0
   case "$1" in
      start)                                               # starts the Node program as a Linux service
         startService
         ;;
      stop)                                                # stops the Node program service
         stopService
         ;;
      restart)                                             # stops and restarts the service
         stopService && startService
         ;;
      status)                                              # displays the service status
         checkServiceStatus
         ;;
      *)
         echo "Usage: $0 {start|stop|restart|status}"
         exit 1
         ;;
      esac
   exit $RETVAL
}

main $1


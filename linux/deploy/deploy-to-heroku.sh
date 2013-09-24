#!/bin/bash

#=====================================================================
# _ubeg_
#
# USAGE :
#   %facility% command
#
# DESCRIPTION :
#   Updating the heroku repository with newest version from git
#
# OPTIONS :
#       dir : to override default working_dir
#
# RETURN CODES :
#   <Return code> <meaning>
#   0 everything was allright
#   1 bad options
#   2 unknown issue
#
# WARNINGS :
#   None
#
# EXAMPLES :
#   %facility% [~home/mydir]
#
# _uend_
#=====================================================================

current_dir=`pwd`

# Description de l'utilisation du script.
Facility=$0
facility=`basename ${Facility}`

# Chargement de la configuration
. ${facility%%.sh}.conf

exec 2>>${error_file}

#============= DISPLAYING FUNCTIONS ==================================
function display_step {
    echo -e "$1 ........... \c"
}

function display_step_status {
    if [ $1 = 0 ] ; then
        display_OK
        return 0
    else
        display_KO
        return 1
    fi	
}

function display_OK {
    echo -e '[\c'
#    tput setaf 2
    echo -e "OK\c"
#    tput setaf 0
    echo -e ']'
}

function display_KO {
    echo -e '[\c'
#    tput setaf 1
    echo -e "KO\c"
#    tput setaf 0
    echo -e ']'
}
#=====================================================================

#============= ERROR HANDLING FUNCTIONS ==============================
function halt_on_error {
    display_KO
    if [[ "$send_mail_on_error" -eq "yes" ]]
    then
        send_mail_alert "$2" $warning_email
    fi
    exit $1
}

function send_mail_alert {
    mail -s "$facility failed" $2 << eof
    `date`
    $facility Failed : $1
eof
}
#=====================================================================

#============= COMMON FUNCTIONS ======================================
# Description of the script
function usage {
    echo "Error in options"
    sed "/^# _ubeg_/,/^# _uend_/!d;/_ubeg_/d;/_uend_/d;s/^#//g;s/%faci[^%]*%/$facility/g" $Facility
}

# Logging to STDOUT or log file
function log {
    echo `date '+%d/%m/%Y %H:%M:%S'` - $1 | tee -a ${log_file}
}

function function_exists {
    FUNCTION_NAME=$1

    [ -z "$FUNCTION_NAME" ] && return 1

    declare -F "$FUNCTION_NAME" > /dev/null 2>&1

    return $?
}
#=====================================================================
# Initialising
#  - Checking if the same script is running (checking if temp_dir exists)
#  - Creating dirs
function init {
    display_step initing
    echo `date '+%d/%m/%Y %H:%M:%S'` - Starting >> ${error_file}
    if [[ -d ${temp_dir} ]]
    then
        message="${temp_dir} exists, the script is already running or have previously failed"
        echo $message | tee -a ${error_file}
        halt_on_error 2 "$message"
    fi
    su $force_user -c "mkdir -p ${temp_dir}"
    chown $force_user:$force_group ${temp_dir}
    display_OK
    log "Starting : $@"
}

#  Ending :
#  - Removing temp dir
function uninit {
    display_step uniniting
    su $force_user -c "cd ${root_dir};rm -rf ${temp_dir}"
    display_OK
    echo `date '+%d/%m/%Y %H:%M:%S'` - End >> ${error_file}
}

# Stopping on erro
function is_ok {
    return_code=$1
    if [[ $return_code -ne 0 ]]
    then
        halt_on_error 3 "$2 failed with return code $return_code"
    fi
    display_OK
}

#============= MAIN FUNCTIONS ======================================
# Pulling from origin
function pull {
    log "about to pull"
    su $force_user -c "$git_bin $git_pull_origin"
    is_ok $? "pull"
}

# Pushing to heroku
function push {
    log "about to push"
    su $force_user -c "$git_bin $git_push_to_heroku"
    is_ok $? "push"
}

function main {
    pull
    push
}

#=====================================================================
#---------------------------------------------------------------------
# Reading options
#---------------------------------------------------------------------
args="$@"

if [[ $# -gt 2 ]]
then
    usage
    display_step "reading arguments"
    halt_on_error 1 "Too many args : $args"
fi

if [[ $# -eq 1 ]]
then
    working_dir=$1
else
    working_dir=${default_working_dir:-`pwd`}
fi

init "$args"
main
uninit
log "The End" 


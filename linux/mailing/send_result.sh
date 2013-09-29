#!/bin/bash

#=====================================================================
# _ubeg_
#
# USAGE :
#   %facility% command
#
# DESCRIPTION :
#   Getting the return mail and sending
#
# OPTIONS :
#       none
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
#   %facility%
#
# _uend_
#=====================================================================

current_dir=`pwd`

Facility=$0
facility=`basename ${Facility}`
facility_dir=`dirname ${Facility}`

# Loading conf
. ${Facility%%.sh}.conf

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
#    mail -s "$facility failed" $2 << eof
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
    mkdir -p ${temp_dir}
    display_OK
    log "Starting : $@"
}

#  Ending :
#  - Removing temp dir
function uninit {
    display_step uniniting
    cd ${root_dir};rm -rf ${temp_dir}
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
function send {
    log "Prepared to send"
    echo "Send $1 ,[O/n]"
    read answer
    if [ "$answer" == "n" ]; then
       echo "Mail not sent"
       rm ${file}
       exit 3
    elif [ "$answer" == "" ]||[ "$answer" == "O" ]; then
       sendmail -i -t < $1
       touch sent_`basename $1`
    fi
}

function ask_for_infos {
    log "Reading params from input"
    echo "Prospect id ?"
    read prospect
    echo "Expression (URL encoded) ?"
    read expression
}

function get_mail {
    log "Getting mail"
    cd $working_dir
    new_dir=${new_dir}_`date '+%Y-%m-%d-%H-%M-%S'`
    mkdir ${new_dir}
    $wget_bin -O ${new_dir}/temp "${wget_starting_uri}?${PARAM_1}=$1&${PARAM_2}=$2"
    grep "To" ${new_dir}/temp
    grep "search" ${new_dir}/temp
}

function main {
    #mark_sent
    ask_for_infos
    get_mail $prospect $expression
    send ${new_dir}/temp
}

#=====================================================================
#---------------------------------------------------------------------
# Reading options
#---------------------------------------------------------------------
args="$@"

if [[ $# -ne 0 ]]
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


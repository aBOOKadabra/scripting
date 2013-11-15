#!/bin/bash

#=====================================================================
# _ubeg_
#
# USAGE :
#   %facility% command
#
# DESCRIPTION :
#   Parsing a csv file containing authors to yml equivalent via awk
#
# OPTIONS :
#       source file
#       type of file to parse [author, category]
#       output file
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

    declare -f -F "$FUNCTION_NAME" > /dev/null 2>&1

    return_code=$?

    return $return_code
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
# Create a file for each mail already there before doing anything
function parse_author {
cat $file_to_parse | $awk_bin 'BEGIN { print "authors:";
              FS=";"}
      $1 ~ /Head 1/ {  split($0, cat, ";") }
      $1 ~ /Auteur/ { print "    - &"$1" !!models.Author" }
      $1 ~ /Auteur/ { print "         fullname:"}
      $1 ~ /Auteur/ { print "               name:               "$3}
      $1 ~ /Auteur/ { print "               firstname:          "$2}
      $1 ~ /Auteur/ { print "         score:"}
      $1 ~ /Auteur/ { print "               bestseller:    "$40}
      $1 ~ /Auteur/ { print "               classical:     "$41}
      $1 ~ /Auteur/ { print "               hard:          "$42}
      $1 ~ /Auteur/ { print "               ico:           "$43}
      $1 ~ /Auteur/ { print "               author:        *"$1}
      $1 ~ /Auteur/ && $4 != "" { print "         alias:              ["$4"]"}
      $1 ~ /Auteur/ && $45 != "" { print "         tags:              "$45}
      $1 ~ /Auteur/ { print "         categories:"}
      $1 ~ /Auteur/ { for (i=7;i<=39;i++) {
                            if ($i != "") {
                                {print "            - {category: *"cat[i]", percentage: "$i" }" }
                            }
                        }
                      }
      $1 ~ /Auteur/ { print ""}
      END   { print "#Fin" }
' > $output_file

}

function parse_category {
cat $file_to_parse | $awk_bin 'BEGIN { print "bookCategories:";
              FS=";"}
      $1 ~ /Category/ { print "    - &"$3" !!models.BookCategory" }
      $1 ~ /Category/ { print "         name:                 "$4}
      $1 ~ /Category/ { print "         type:                 "$5}
      $1 ~ /Category/ { print "         description:          "$7}
      $1 ~ /Category/ && $2 != "" { print "         parent:              *"$2}
      $1 ~ /Category/ && $6 != "" { print "         tags:                 "$6}
      $1 ~ /Category/ && $8 != "" { print "         claim:                "$8}
      $1 ~ /Category/ { print ""}
      END   { print "#Fin" }
' > $output_file
}


function main {
    function_exists parse_$action
    return_code=$?

    if [[ $? -eq 0 ]]; then 
        parse_$action
    else
        usage
    fi
}

#=====================================================================
#---------------------------------------------------------------------
# Reading options
#---------------------------------------------------------------------
args="$@"

if [ $# -eq 0 ]||[ $# -gt 3 ]; then
    usage
    display_step "reading arguments"
    halt_on_error 1 "Too many args : $args"
fi


if [[ $# -ge 1 ]]; then
    file_to_parse=$1
    action=author
    output_file=$1_result.yml
fi
if [[ $# -ge 2 ]]; then
    action=$2
    output_file=$1_result.yml
fi
if [[ $# -eq 3 ]]; then
    output_file=$3
fi

init "$args"
main
uninit
log "The End" 


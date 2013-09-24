#!/bin/bash

#=====================================================================
# _ubeg_
#
# USAGE :
#   %facility%
#
# DESCRIPTION :
#   Ce script permet de sauvegarder des repertoires sur un syteme de fichiers local.
#
# OPTIONS ET PARAMETRES :
#   Pas de parametre.
#
# CODES RETOURS :
#   <Code retour> <signification>
#   0 si tout s'est bien passe.
#   1 erreur dans le passage des parametres.
#   2 probleme inconnu.
#
# AVERTISSEMENTS :
#   Aucun
#
# EXEMPLES D'UTILISATION
#   %facility%
#
# _uend_
#=====================================================================

current_dir=`pwd`

# Description de l'utilisation du script.
Facility=$0
facility=`basename ${Facility}`

# Chargement de la configuration
. /etc/backup-tools/backup.multimedia.conf

exec 2>>${bckup_error_file}

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
    tput setaf 2
    echo -e "OK\c"
    tput setaf 0
    echo -e ']'
}

function display_KO {
    echo -e '[\c'
    tput setaf 1
    echo -e "KO\c"
    tput setaf 0
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
# Description de l'utilisation du script.
function usage {
    echo "Erreur dans les arguments"
    sed "/^# _ubeg_/,/^# _uend_/!d;/_ubeg_/d;/_uend_/d;s/^#//g;s/%faci[^%]*%/$facility/g" $Facility
}

# Log sur la sortie standard et dans le fichier de log
function log {
    echo `date '+%d/%m/%Y %H:%M:%S'` - $1 | tee -a ${bckup_log_file}
}

function function_exists {
    FUNCTION_NAME=$1

    [ -z "$FUNCTION_NAME" ] && return 1

    declare -F "$FUNCTION_NAME" > /dev/null 2>&1

    return $?
}
#=====================================================================

# Initialise le traitement :
function init {
    display_step initing
    echo `date '+%d/%m/%Y %H:%M:%S'` >> ${bckup_error_file}
    display_OK
    log "Demarrage du backup local"
}

# Finalise le traitement :
function uninit {
    display_step uniniting
    display_OK
}

# Synchronise les repertoires
function sync {
    display_step syncing
    echo `date '+%d/%m/%Y %H:%M:%S'` >> ${sync_log_file}
    source_path_to_sync=$1
    destination_path_to_sync=$2
    ${rsync_bin} ${rsync_options} ${source_path_to_sync} ${destination_path_to_sync} | tee -a ${sync_log_file}
    retour=$?
    if [[ $retour -ne 0 ]]
    then
        halt_on_error 3 "rsync failed with return code $retour"
    fi
    display_OK
}

#============= BACKUP FUNCTIONS ======================================
# Archivage des donnees
function backup {
    log "about to backup : $active_backups"
    for backup in $active_backups
    do
        generic_backup $backup
    done
    chown -R $user:$group ${bckup_temp_dir}
}

function backup_standard_fs {
    source=$1
    destination=$2
    name=$3
    log "backing up ${name}..."
    sync ${source}/ ${destination}/
}

function generic_backup {
    if function_exists backup_$1
    then
        backup_$1
    else
        source_dir_var_name=$1_source_dir
        dest_dir_var_name=$1_dest_dir
        backup_standard_fs ${!source_dir_var_name} ${!dest_dir_var_name} $1
    fi
}


#function backup_mp3s {
#    backup_standard_fs ${mp3s_source_dir}/ ${destination_bckup_root_dir}/musique/ mp3s
#}
#
#function backup_www {
#    backup_standard_fs ${www_source_dir}/ ${destination_bckup_root_dir}/www/ www
#}
#
#function backup_cvs {
#    backup_standard_fs ${cvs_root_dir}/ ${destination_bckup_root_dir}/CVS/ cvs
#}
#
#function backup_photos {
#    backup_standard_fs ${photos_source_dir}/ ${destination_bckup_root_dir}/photos/ photos
#}
#
#function backup_mails {
#    backup_standard_fs ${mails_source_dir}/ ${destination_bckup_root_dir}/mails/ mails
#}
#
#function backup_homes {
#    backup_standard_fs /home ${destination_bckup_root_dir}/homes homes
#}
#
#=====================================================================


#---------------------------------------------------------------------
# Lecture des options
#---------------------------------------------------------------------
args="$@"

if [[ $# -ne 0 ]]
then
    usage
    display_step "reading arguments"
    halt_on_error 1 "Usage incorrect : $args"
fi

init "$args"
backup
uninit
log "Fin du backup" 


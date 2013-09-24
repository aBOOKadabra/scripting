#!/bin/bash

#=====================================================================
# _ubeg_
#
# USAGE :
#   %facility% commande
#
# DESCRIPTION :
#   Ce script permet de sauvegarder des repertoires de les copier sur un site distant.
#
# OPTIONS ET PARAMETRES :
#       commande est la commande a lancer :
#           - daily :   lancement d'une sauvegarde journaliere.
#           - weekly :  lancement d'une sauvegarde hebdomadaire.
#           - monthly : lancement d'une sauvegarde mensuelle.
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
#   %facility% daily
#
# _uend_
#=====================================================================

current_dir=`pwd`

# Description de l'utilisation du script.
Facility=$0
facility=`basename ${Facility}`

# Chargement de la configuration
. /etc/backup-tools/backup.local-data.conf

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
#  - Verification de l'existence d'un traitement en cours (verification de l'existence du repertoire temporaire)
#  - Creation des repertoires necessaires
function init {
    display_step initing
    echo `date '+%d/%m/%Y %H:%M:%S'` - Demarrage >> ${bckup_error_file}
    if [[ -d ${bckup_temp_dir} ]]
    then
        message="${bckup_temp_dir} existe, un autre processus de backup est en cours ou s'est mal termine"
        echo $message | tee -a ${bckup_error_file}
        halt_on_error 2 "$message"
    fi
    su $user -c "mkdir -p ${bckup_temp_dir} ${daily_bckup_dir} ${weekly_bckup_dir} ${monthly_bckup_dir}"
    chown $user:$group ${bckup_temp_dir} ${daily_bckup_dir} ${weekly_bckup_dir} ${monthly_bckup_dir}
    display_OK
    log "Demarrage du backup avec les parametres suivants : $@"
}

# Finalise le traitement :
#  - Suppression du repertoire temporaire
function uninit {
    display_step uniniting
    # On se positionne d'abord dans bckup_root_dir pour que le repertoire courant soit accessible a l'utilisateur backup (sinon pb rm)
    su $user -c "cd ${bckup_root_dir};rm -rf ${bckup_temp_dir}"
    display_OK
    echo `date '+%d/%m/%Y %H:%M:%S'` - Fin >> ${bckup_error_file}
}

# Synchronise les repertoires sur le serveur distant
function sync {
    display_step syncing
    echo `date '+%d/%m/%Y %H:%M:%S'` >> ${sync_log_file}
    local_path_to_sync=$1
    remote_path_to_sync=$2
    ${rsync_bin} -e "ssh -p ${remote_bckup_port}" ${rsync_options} ${local_path_to_sync} ${remote_bckup_user}@${remote_bckup_host}:${remote_path_to_sync} | tee -a ${sync_log_file}
    retour=$?
    if [[ $retour -ne 0 ]]
    then
        halt_on_error 3 "rsync failed with return code $retour"
    fi
    display_OK
}

#============= BACKUP POLICY FUNCTIONS ===============================
# Sauvegarde quotidienne
#  - Suppression du repertoire daily
#  - Copie des fichiers du repertoire temporaire dans le repertoire daily
function daily {
    backup
    su $user -c "rm -f ${daily_bckup_dir}/*"
    su $user -c "cp -al ${bckup_temp_dir}/*.tgz ${daily_bckup_dir}/"
}

# Sauvegarde hebdomadaire
#  - Suppression du repertoire weekly
#  - Copie des fichiers du repertoire daily dans le repertoire weekly
#    (la sauvegarde daily se fait plus tard que la weekly => daily contient la sauvegarde de la veille)
#  - Copie des fichiers du repertoire temporaire dans le repertoire daily
function weekly {
    #backup
    su $user -c "rm -f ${weekly_bckup_dir}/*"
    su $user -c "cp -al ${daily_bckup_dir}/* ${weekly_bckup_dir}/"
    #su $user -c "cp -al ${bckup_temp_dir}/*.tgz ${daily_bckup_dir}/"
}

# Sauvegarde mensuelle
#  - Suppression du repertoire monthly
#  - Copie des fichiers du repertoire weekly dans le repertoire monthly
#    (la sauvegarde weekly se fait plus tard que la monthly => weekly contient la sauvegarde de la semaine passee)
#  - Copie des fichiers du repertoire daily dans le repertoire weekly
#    (la sauvegarde daily se fait plus tard que la weekly => daily contient la sauvegarde de la veille)
#  - Copie des fichiers du repertoire temporaire dans le repertoire daily
function monthly {
    #backup
    su $user -c "rm -f ${monthly_bckup_dir}/*"
    su $user -c "cp -al ${weekly_bckup_dir}/* ${monthly_bckup_dir}/"
    su $user -c "cp -al ${daily_bckup_dir}/* ${weekly_bckup_dir}/"
    #su $user -c "cp -al ${bckup_temp_dir}/*.tgz ${daily_bckup_dir}/"
}
#=====================================================================


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
    fs_to_save=$1
    archive_name=$2
    (tar czf ${bckup_temp_dir}/${archive_name}.tgz ${tar_options} ${fs_to_save} && log "backup ${archive_name} : OK (`du -h ${bckup_temp_dir}/${archive_name}.tgz`)" || log "backup ${archive_name} : KO")
}

function generic_backup {
    if function_exists backup_$1
    then
        backup_$1
    else
        source_dir_var_name=$1_source_dir
        backup_standard_fs ${!source_dir_var_name} $1
    fi
}

function backup_databases {
    log "backing up databases..."
    for i in `${mysql_bin} -e "SHOW DATABASES;" | egrep -v "(-|Database)" | sed "s/\|//"`
    do
        ${mysqldump_bin} --opt $i > ${bckup_temp_dir}/db_$i.sql && log "backup db $i : OK" || log "backup db $i : KO"
    done
    cd ${bckup_temp_dir}
    (tar czf ${bckup_temp_dir}/databases.tgz ${tar_options} db_*.sql && (log "backup databases : OK (`du -h ${bckup_temp_dir}/databases.tgz`)" && rm -f ${bckup_temp_dir}/db_*.sql) || log "backup databases : KO")
    cd ${current_dir}
}

function backup_www {
    (tar czf ${bckup_temp_dir}/www.tgz ${tar_options} --exclude *.jpg --exclude *.JPG var/www && log "backup /var/www : OK (`du -h ${bckup_temp_dir}/www.tgz`)" || log "backup /var/www : KO")
}



#=====================================================================
#---------------------------------------------------------------------
# Lecture des options
#---------------------------------------------------------------------
args="$@"

if [[ $# -ne 1 ]]
then
    usage
    display_step "reading arguments"
    halt_on_error 1 "Usage incorrect : $args"
fi

if [[ "$1" == "daily" ]]
then
    todo=daily
elif [[ "$1" == "weekly" ]]
then
    todo=weekly
elif [[ "$1" == "monthly" ]]
then
    todo=monthly
else
    usage
    display_step "reading arguments"
    halt_on_error 1 "Usage incorrect : $args"
fi


init "$args"
${todo}
uninit
#sync ${bckup_root_dir}/ ${remote_bckup_root_dir}/
log "Fin du backup" 


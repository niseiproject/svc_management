#!/bin/bash 

### CONSTANTS

#Num  Colour    #define         R G B

#0    black     COLOR_BLACK     0,0,0
#1    red       COLOR_RED       1,0,0
#2    green     COLOR_GREEN     0,1,0
#3    yellow    COLOR_YELLOW    1,1,0
#4    blue      COLOR_BLUE      0,0,1
#5    magenta   COLOR_MAGENTA   1,0,1
#6    cyan      COLOR_CYAN      0,1,1
#7    white     COLOR_WHITE     1,1,1

WHITE=7
GREEN=2
RED=1
CYAN=6
MAGENTA=5
YELLOW=3
MON_USR='x101513'
KEY='/home/nasadmin/Jesus/scripts/id_rsa'


### FUNCTIONS

get_usage_example (){

    echo
    echo "Example usage:"
    echo "$(tput setaf $YELLOW) $0 -svc $(tput setaf $MAGENTA)<SVC_IP_ADDR>$(tput setaf $YELLOW) -id $(tput setaf $MAGENTA)<vdisk_ID> $(tput setaf $YELLOW) -name $(tput setaf $MAGENTA)<vdisk_name>$(tput setaf $YELLOW) -copy $(tput setaf $MAGENTA)<vdisk_copy_id>$(tput setaf $YELLOW) -mdiskgrp $(tput setaf $MAGENTA)<mdiskgrp>$(tput setaf $YELLOW) -compress $(tput setaf $MAGENTA)<1->yes,0->no>$(tput setaf $YELLOW) -speed $(tput setaf $MAGENTA)<0-100>$(tput setaf $WHITE)"
    return 0
}

check_parameters (){
# launch_sync.sh -svc $svc_ip -id $vdisk_id -name $vdisk_name -copy $vdisk_copy -mdiskgrp $vdisk_pool -compress $compression -speed $speed

    if `test $# -ne 16`
    then
        echo "$(tput setaf $RED) Error: Invalid number of parameters. Please check.$(tput setaf $WHITE)"        
        get_usage_example
        return 0
    fi

    if ! `echo ${2}| grep -i -q -E "([0-9]{1,3}.){3}[0-9]{1,3}"`
    then
        echo "$(tput setaf $RED) Error: Invalid IP address. Please check: $2. $(tput setaf $WHITE)"
        get_usage_example
        return 0
    fi

    if ! `echo ${4} | grep -i -q -E "[0-9]{1,5}"`
    then
        echo "$(tput setaf $RED) Error: Invalid vdisk ID. Please check: $4. $(tput setaf $WHITE)"
        get_usage_example
        return 0
    fi

    if ! `echo ${6} | grep -i -q -E "[0-9a-zA-Z_]{1,40}"`
    then
        echo "$(tput setaf $RED) Error: Invalid vdisk name. Please check: $6. $(tput setaf $WHITE)"
        get_usage_example
        return 0
    fi

    if ! `echo ${8} | grep -i -q -E "[01]"`
    then
        echo "$(tput setaf $RED) Error: Invalid copy ID. Please check: $8. $(tput setaf $WHITE)"
        get_usage_example
        return 0
    fi

    if ! `echo "${10}" | grep -i -q -E "[0-9a-zA-Z_]{1,40}"`
    then
        echo "$(tput setaf $RED) Error: Invalid mdiskgrp name. Please check: "${10}". $(tput setaf $WHITE)"
        get_usage_example
        return 0
    fi

    if ! `echo "${12}" | grep -i -q -E "[01]"`
    then
        echo "$(tput setaf $RED) Error: Invalid compression value. Please check: "${12}". $(tput setaf $WHITE)"
        get_usage_example
        return 0
    fi

    if ! `(test "${14}" -gt 0) && (test "${14}" -le 100)`
    then
        echo "$(tput setaf $RED) Error: Invalid speed value. Please check: "${14}". $(tput setaf $WHITE)"
        get_usage_example
        return 0
    fi
    return 1
}

worthless (){
# Checks if we want to perform a new copy with the same characteristics we already have. 
    pool=${1}
    compression='no'
    source_pool=${3}
    is_compressed=${4}

    if `test ${2} -eq 1`
    then
        compression='yes'
    fi

    if `(test "${pool}" = "${source_pool}") && (test "${compression}" = "${is_compressed}")`
    then
        #The order is a non sense :O
        return 0
    fi
    
    return 1    
}

copy_launcher (){
# Checks whether the specified vdisk exists and has the right characteristics to be compressed/migrated without any risk.
# 1. It has 2 copies.
# 2. It's not a member of a flash copy relationship.
# 3. We won't compress or migrate any copy that is already compressed in the same mdiskgrp.
# 4. 
# check_vdisk $ip $vdisk_id $vdisk_name $copy_id $mdiskgrp $compress
    vdisk_info_f=`mktemp /tmp/vdiskinfo.XXXX`
    ip=${1}
    vdisk_id=${2}
    vdisk_name=${3}
    copy=${4}
    mdiskgrp=${5}
    comp=${6}
    speed=${7}
    ending_f=${8}

    > ${vdisk_info_f}
    ssh -i ${KEY} ${MON_USR}@${ip} "lsvdisk ${vdisk_name}" > ${vdisk_info_f}
    #sleep 1
    length=`cat ${vdisk_info_f} | wc -l`

    if `test $length -gt 0`
    then
        real_id=`cat ${vdisk_info_f} | grep -i -E "^id" | awk '{print $2}'`
        copy_count=`cat ${vdisk_info_f} | grep -i -E "^copy_count" | awk '{print $2}'`
        has_fc=`cat ${vdisk_info_f} | grep -i -E "^fc_map_count" | awk '{print $2}'`
        copy0_pool=`cat ${vdisk_info_f} | grep -i -E "^copy_id 0" -A31 | grep -i -E "^mdisk_grp_name" | awk '{print $2}'`
        is_copy0_primary=`cat ${vdisk_info_f} | grep -i -E "^copy_id 0" -A31 | grep -i -E "^primary" | awk '{print $2}'`
        is_copy0_compressed=`cat ${vdisk_info_f} | grep -i -E "^copy_id 0" -A31 | grep -i -E "^compressed_copy" | awk '{print $2}'`
        copy1_pool=`cat ${vdisk_info_f} | grep -i -E "^copy_id 1" -A31 | grep -i -E "^mdisk_grp_name" | awk '{print $2}'`
        is_copy1_primary=`cat ${vdisk_info_f} | grep -i -E "^copy_id 1" -A31 | grep -i -E "^primary" | awk '{print $2}'`
        is_copy1_compressed=`cat ${vdisk_info_f} | grep -i -E "^copy_id 1" -A31 | grep -i -E "^compressed_copy" | awk '{print $2}'`

        if `(test ${real_id} -eq ${vdisk_id}) && (test ${copy_count} -eq 2)` # && (test $has_fc -eq 0)`
        then
            if `test ${copy} -eq 0`
                then
                if `! worthless ${mdiskgrp} ${comp} ${copy0_pool} ${is_copy0_compressed}`
                then
                    if `test ${is_copy0_primary} = 'yes'`
                    then
                        # Set new primary if needed.
                        echo "$(tput setaf $YELLOW) ssh -i ${KEY} ${MON_USR}@${ip} \"chvdisk -primary 1 ${vdisk_name}\" $(tput setaf $WHITE)"
                        ssh -i ${KEY} ${MON_USR}@${ip} "chvdisk -primary 1 ${vdisk_name}"
                        #sleep 1
                        # Record the rollback command to previous primary copy.
                        echo "ssh -i ${KEY} ${MON_USR}@${ip} \"chvdisk -primary 0 ${vdisk_name}\"" >> ${ending_f}
                    fi

                    if `test ${comp} -eq 1`
                    then
                        # We remove the specified copy.
                        echo "$(tput setaf $YELLOW) ssh $MON_USR@$ip \"rmvdiskcopy -copy $copy $vdisk_name\" $(tput setaf $WHITE)"
                        ssh -i ${KEY} ${MON_USR}@${ip} "rmvdiskcopy -copy ${copy} ${vdisk_name}"
                        sleep 1
                        echo "$(tput setaf $YELLOW) ssh $MON_USR@$ip \"addvdiskcopy -mdiskgrp $mdiskgrp -vtype striped -rsize 2% -warning 80 -autoexpand -compressed -syncrate $speed -easytier on $vdisk_name\" $(tput setaf $WHITE)"
                        ssh -i ${KEY} ${MON_USR}@${ip} "addvdiskcopy -mdiskgrp ${mdiskgrp} -vtype striped -rsize 2% -warning 80 -autoexpand -compressed -syncrate ${speed} -easytier on ${vdisk_name}"
                    else
                        if `test ${has_fc} -eq 1`
                        then
                            # We remove the specified copy.
                            echo "$(tput setaf $YELLOW) ssh $MON_USR@$ip \"rmvdiskcopy -copy $copy $vdisk_name\" $(tput setaf $WHITE)"
                            ssh -i ${KEY} ${MON_USR}@${ip} "rmvdiskcopy -copy ${copy} ${vdisk_name}"
                            sleep 1
                            echo "$(tput setaf $YELLOW) ssh $MON_USR@$ip \"addvdiskcopy -mdiskgrp $mdiskgrp -vtype striped -rsize 2% -warning 80 -autoexpand -grainsize 64 -syncrate $speed -easytier on $vdisk_name\" $(tput setaf $WHITE)"
                            ssh -i ${KEY} ${MON_USR}@${ip} "addvdiskcopy -mdiskgrp ${mdiskgrp} -vtype striped -rsize 2% -warning 80 -autoexpand -grainsize 64 -syncrate ${speed} -easytier on ${vdisk_name}"
                        else
                            # We remove the specified copy.
                            echo "$(tput setaf $YELLOW) ssh $MON_USR@$ip \"rmvdiskcopy -copy $copy $vdisk_name\" $(tput setaf $WHITE)"
                            ssh -i ${KEY} ${MON_USR}@${ip} "rmvdiskcopy -copy ${copy} ${vdisk_name}"
                            sleep 1
                            echo "$(tput setaf $YELLOW) ssh $MON_USR@$ip \"addvdiskcopy -mdiskgrp $mdiskgrp -vtype striped -rsize 2% -warning 80 -autoexpand -syncrate $speed -easytier on $vdisk_name\" $(tput setaf $WHITE)"
                            ssh -i ${KEY} ${MON_USR}@${ip} "addvdiskcopy -mdiskgrp ${mdiskgrp} -vtype striped -rsize 2% -warning 80 -autoexpand -syncrate ${speed} -easytier on ${vdisk_name}"
                        fi
                    fi
                    sleep 1
                    # Record the sync speed this vdisk should have once the synchronization has ended.
                    echo "ssh $MON_USR@$ip \"chvdisk -syncrate 50 $vdisk_name\"" >> $ending_f
                fi 
            fi

            if `test ${copy} -eq 1`
            then
                if `! worthless ${mdiskgrp} ${comp} ${copy1_pool} ${is_copy1_compressed}`
                then
                    if `test ${is_copy1_primary} = 'yes'`
                    then
                        # Set new primary if needed.
                        echo "$(tput setaf $YELLOW) ssh $MON_USR@$ip \"chvdisk -primary 0 $vdisk_name\" $(tput setaf $WHITE)"
                        ssh -i ${KEY} ${MON_USR}@${ip} "chvdisk -primary 0 ${vdisk_name}"
                        #sleep 1
                        # Record the rollback command to previous primary copy.
                        echo "ssh -i ${KEY} ${MON_USR}@${ip} \"chvdisk -primary 1 ${vdisk_name}\"" >> ${ending_f}
                    fi
    
                    if `test ${comp} -eq 1`
                    then
                        # We remove the specified copy.
                        echo "$(tput setaf $YELLOW) ssh $MON_USR@$ip \"rmvdiskcopy -copy $copy $vdisk_name\" $(tput setaf $WHITE)"
                        ssh -i ${KEY} ${MON_USR}@${ip} "rmvdiskcopy -copy ${copy} ${vdisk_name}"
                        sleep 1
                        echo "$(tput setaf $YELLOW) ssh $MON_USR@$ip \"addvdiskcopy -mdiskgrp $mdiskgrp -vtype striped -rsize 2% -warning 80 -autoexpand -compressed -syncrate $speed -easytier on $vdisk_name\" $(tput setaf $WHITE)"
                        ssh -i ${KEY} ${MON_USR}@${ip} "addvdiskcopy -mdiskgrp ${mdiskgrp} -vtype striped -rsize 2% -warning 80 -autoexpand -compressed -syncrate ${speed} -easytier on ${vdisk_name}"
                    else
                        if `test ${has_fc} -eq 1`
                        then
                            # We remove the specified copy.
                            echo "$(tput setaf $YELLOW) ssh $MON_USR@$ip \"rmvdiskcopy -copy $copy $vdisk_name\" $(tput setaf $WHITE)"
                            ssh -i ${KEY} ${MON_USR}@${ip} "rmvdiskcopy -copy ${copy} ${vdisk_name}"
                            sleep 1
                            echo "$(tput setaf $YELLOW) ssh $MON_USR@$ip \"addvdiskcopy -mdiskgrp $mdiskgrp -vtype striped -rsize 2% -warning 80 -autoexpand -grainsize 64 -syncrate $speed -easytier on $vdisk_name\" $(tput setaf $WHITE)"
                            ssh -i ${KEY} ${MON_USR}@${ip} "addvdiskcopy -mdiskgrp ${mdiskgrp} -vtype striped -rsize 2% -warning 80 -autoexpand -grainsize 64 -syncrate ${speed} -easytier on ${vdisk_name}"
                        else
                            # We remove the specified copy.
                            echo "$(tput setaf $YELLOW) ssh $MON_USR@$ip \"rmvdiskcopy -copy $copy $vdisk_name\" $(tput setaf $WHITE)"
                            ssh -i ${KEY} ${MON_USR}@${ip} "rmvdiskcopy -copy ${copy} ${vdisk_name}"
                            sleep 1
                            echo "$(tput setaf $YELLOW) ssh $MON_USR@$ip \"addvdiskcopy -mdiskgrp $mdiskgrp -vtype striped -rsize 2% -warning 80 -autoexpand -syncrate $speed -easytier on $vdisk_name\" $(tput setaf $WHITE)"
                            ssh -i ${KEY} ${MON_USR}@${ip} "addvdiskcopy -mdiskgrp ${mdiskgrp} -vtype striped -rsize 2% -warning 80 -autoexpand -syncrate ${speed} -easytier on ${vdisk_name}"
                        fi
                    fi
                    sleep 1
                    # Record the sync speed this vdisk should have once the synchronization has ended.
                    echo "ssh -i ${KEY} ${MON_USR}@${ip} \"chvdisk -syncrate 50 ${vdisk_name}\"" >> ${ending_f}
                fi
            fi
        fi
       
    fi
    rm ${vdisk_info_f}
    return 0
}



### MAIN
tput setaf [1-7]

if ! `check_parameters "${@}"`
then
 #launch_sync.sh -svc $svc_ip -id $vdisk_id -name $vdisk_name -copy $vdisk_copy -mdiskgrp $vdisk_pool -compress $compression -speed $speed
    copy_launcher ${2} ${4} ${6} ${8} ${10} ${12} ${14} ${16}
fi



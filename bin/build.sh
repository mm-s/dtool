#!/bin/bash

only_dotool_ss=""

if [[ "_$1" == "_--only-dotool" ]]; then
    only_dotool_ss="$2"
    shift 2
fi

prefix=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
libdir=${prefix}/lib/dtool
. ${libdir}/libdeploy.env

libb__poke() { ## 1:class_instance 2:identifier 3:value
    liboop__poke__ "libb" "$1" "$2" "$3"   #g=static
}

libb__peek() { ## 1:class_instance 2:identifier
    liboop__peek__ "libb" "$1" "$2"
}

libb__static__poke() { ## 1:variable 2:value
    liboop__poke__ "libb" "g" "$1" "$2"   #g=static
}

libb__static__peek() { ## 1:variable
    liboop__peek__ "libb" "g" "$1"
}

do__system_test() {
    cat ../../lib/target_test.sh
}

## for installer.
## disabled snippet. TODO: integrate in installer?
#function is_package_installed {
#    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
#}
#if is_package_installed "yarn"; then
#    echo "Package yarn is already installed."
#else
#    echo "Package yarn is not installed. Installing now..."
#    sudo apt update
#    sudo apt install -y yarn
#    yarn add react-app-rewired --dev
#fi

do__user_install() {
    cat << EOF
#!/bin/bash
#############################################################################################################################
## User installer (debian)
#############################################################################################################################
#  Args: [--flags]
#        flags
#           -batch ................................ Batch mode (non-interactive).
#           --node_key <hex> ...................... 256 bit Secret key. hex encoding. 64 character string.
#           -no-start ............................. install but don't start the system
#           -only-download ........................ only download and uncompress
#           -no-download .......................... use already downloaded and uncompressed dir
#           -print_env ............................ print env vars and exit
#           -no_cleanup ........................... don't delete tar file and uncompressed dir after use
#           -no-keys .............................. don't install gov and wallet keys
#           -no-snapshot .......................... don't overwrite snapshot file
#           -no-wait-sync ......................... Skip waiting for L1 sync at the end before exiting.
#############################################################################################################################
let batch=0
let no_start=0
let only_download=0
let no_download=0
let print_env=0
let no_cleanup=0
let no_keys=0
let no_snapshot=0
let no_wait_sync=0
node_key=""

while [[ true ]]; do
    opt=\$1
    shift
    if [[ "_\$opt" == "_-batch" ]]; then
        let batch=1
        continue
    elif [[ "_\$opt" == "_-no-start" ]]; then
        let no_start=1
        continue
    elif [[ "_\$opt" == "_-only-download" ]]; then
        let only_download=1
        continue
    elif [[ "_\$opt" == "_-no-download" ]]; then
        let no_download=1
        continue
    elif [[ "_\$opt" == "_-print_env" ]]; then
        let print_env=1
        continue
    elif [[ "_\$opt" == "_-no_cleanup" ]]; then
        let no_cleanup=1
        continue
    elif [[ "_\$opt" == "_-no-keys" ]]; then
        let no_keys=1
        continue
    elif [[ "_\$opt" == "_-no-snapshot" ]]; then
        let no_snapshot=1
        continue
    elif [[ "_\$opt" == "_-no-wait-sync" ]]; then
        let no_wait_sync=1
        continue
    elif [[ "_\$opt" == "_--node_key" ]]; then
        node_key="\$1"
        shift
        continue
    else
        break
    fi
done

method=\$opt

EOF
    cat ../../lib/target_run/libfn_user.env | grep -v "^#.*"
    cat << EOF

if [[ \${print_env} -eq 1 ]]; then
    libfn_user__print_env
fi

if [[ \${only_download} -eq 1 ]]; then
    libfn_user__only_download
else
EOF
    snippet_apt | sed 's/^/    /'
    cat << EOF
    libfn_user__main "\${batch}" "\${no_start}" "\${node_key}" "\${no_download}" "\${no_cleanup}" "\${no_keys}" "\${no_snapshot}" "\${no_wait_sync}"
fi

ts=\$(date +%s)
tsiso=\$(date --date="@\${ts}" --iso-8601=seconds)
mkdir -p /var/log
echo "\$ts \$tsiso user_install no_start=\${no_start}" >> /var/log/updates__script_tv

EOF
}

do__node_update() {
    cat << EOF
#!/bin/bash
echo "node_update"

system_unix_name="${system_unix_name}"
runuser="${runuser}"

jail="\$(dirname \$(realpath \$0))/jail"

updates__log() {
    local line=\$1
    local ts=\$(date +%s)
    local tsiso=\$(date --date="@\${ts}" --iso-8601=seconds)
    mkdir -p /var/log
    touch /var/log/updates__script_tv
    chown \${runuser}:\${runuser} /var/log/updates__script_tv
    echo "\$ts \$tsiso update \$line" >> /var/log/updates__script_tv
}

statedir="/root/\${system_unix_name}__updates__state"
rm -rf \${statedir}

echo
echo "saving node state in \${statedir}"
\${system_unix_name}__ctl.sh move_node_state \${statedir}

echo
echo "Uninstalling..."
\${system_unix_name}__uninstall.sh

echo
cd /root > /dev/null
installer="./install.sh -batch -no-start -no-download -no-keys -no-snapshot"
echo "Installing new package. Invoking \${installer}"
eval "\$installer"

echo "restoring node state from \${statedir}"
\${system_unix_name}__ctl.sh restore_node_state \${statedir}

echo "starting node"
\${system_unix_name}__ctl.sh start

. /etc/\${system_unix_name}/system.env
msg="current monotonic_version \$monotonic_version"
echo "node updated. \$msg"
updates__log "end OK \$msg"
>&2 echo \$msg
rm -f /tmp/update_entry_point.pid
echo "System successfully updated."
exit 0

EOF
}

rewrite_apt_packages() {
    local pkgs="$1"
    if [[ "${build__target_OS}" == "debian_12_stable" || "${build__target_OS}" == "ubuntu_24" ]]; then
        echo "$pkgs" | sed 's~libsecp256k1-2~libsecp256k1-1~'
    else
        echo "$pkgs"
    fi
}

snippet_apt() {
    local apt=$(cat apt | xargs -n1 | sort | uniq | xargs)
    apt=$(rewrite_apt_packages "${apt}")
    cat << EOF
echo "installing apt packages: $apt"
apt update
bash -c "yes | apt install --yes $apt" || {
    >&2 echo "KO 66978 apt failed."
    exit 1
}
echo "apt packages installed: $apt"

EOF
}

do__system_installer() {
    local urls=$1
    local m=$2
#------------------------------------------------------------
    cat << EOF
#!/bin/bash
#############################################################################################################################
## System installer (debian)
#############################################################################################################################
#  Args: [--flags] <method> <arg>        pass the method used to upload the filesystem
#        flags
#           --no-start                  ........... Don't start services.
#
#        method  arg
#        ------  ---
#        rsync                          ........... Assume / the fs has been already updated before execution of this program.
#        ssh     <path/to/file.tgz>     ........... tgz file (previously scp'd) to uncompress at /.
#        local   <path/to/jail dir>     ........... dir containing files to write at local machine at /.
#############################################################################################################################

let nostart=0

while [[ true ]]; do
    opt=\$1
    shift
    if [[ "_\$opt" == "_--no-start" ]]; then
        let nostart=1
        continue
    else
        break
    fi
done

method=\$opt
logargs=""

if [[ "_\${method}" == "_" ]]; then
    >&2 echo "KO 66857 Invalid arg"
    exit 1
fi
if [[ "_\${method}" != "_rsync" ]]; then
    if [[ "_\${method}" != "_ssh" ]]; then
        if [[ "_\${method}" != "_local" ]]; then
            >&2 echo "KO 66858 Invalid method \"\${method}\""
            exit 1
        fi
    fi
    logargs=""
fi
if [[ "_\${method}" == "_ssh" ]]; then
    tarfile=\$1
    if [[ "_\${tarfile}" == "_" ]]; then
        >&2 echo "KO 66859 Invalid file \"\${tarfile}\" for method \"\${method}\""
        exit 1
    fi
    if [[ ! -f \${tarfile} ]]; then
        >&2 echo "KO 66861 File \"\${tarfile}\" does not exist."
        exit 1
    fi
    logargs="tarfile=\${tarfile}"
elif [[ "_\${method}" == "_local" ]]; then
    jail=\$1
    if [[ "_\${jail}" == "_" ]]; then
        >&2 echo "KO 66860 Invalid input jail \"\${jail}\" for method \"\${method}\""
        exit 1
    fi
    if [[ ! -d \${jail} ]]; then
        >&2 echo "KO 66862 Dir \"\${jail}\" does not exist."
        exit 1
    fi
    logargs="jail=\${jail}"
fi

EOF
#------------------------------------------------------------
    if [[ "_${system_allow_reinstall}" != "_yes" ]]; then
#------------------------------------------------------------
        cat << EOF
if [[ "_\${method}" != "_rsync" ]]; then    #except if method is rsync, here the uninstaller is called before transferring the payload because the new payload is already there when this executes
    # the following file will exist at thispoint when the method is rsync, but the existing one is the right one as files are transferred before calling this script.
    if [[ -f /var/${system_unix_name}/system__uninstall_info ]]; then
        ## hot install is not allowed. Uninstall first.
        >&2 echo "KO 30291 re-installing is not allowed to prevent a mess. Uninstall first executing /usr/local/bin/${system_unix_name}__uninstall.sh"
        exit 1
    fi
fi

EOF
#------------------------------------------------------------
    fi
#------------------------------------------------------------
    cat << EOF
cat << IEOF
EOF
#------------------------------------------------------------
    banner__hello | sed 's#\\#\\\\#g' | sed 's#`#\\`#g'
#------------------------------------------------------------
    cat << EOF
IEOF
EOF
#------------------------------------------------------------
#------------------------------------------------------------
    cat << EOF
uid=\$(id -u)
if [[ uid -ne 0 ]]; then
    >&2 echo "KO 79532 Run as root."
    exit 1
fi

# check glibc
glibc_required_version="${glibc_version}"
glibc_installed_version=\$(ldd --version | head -n1 | awk '{print \$NF}')

if printf "%s\n%s" "\$glibc_required_version" "\$glibc_installed_version" | sort -V -C; then
    echo "glibc version is \$glibc_installed_version (>= \$glibc_required_version)"
else
    echo "KO 33098 glibc version is \$glibc_installed_version (< \$glibc_required_version)"
    exit 1
fi

ts=\$(date +%s)
tsiso=\$(date --date="@\${ts}" --iso-8601=seconds)
mkdir -p /var/log
echo "\$ts \$tsiso system_install method=\${method} \${logargs} nostart=\${nostart}" >> /var/log/updates__script_tv

export DEBIAN_FRONTEND=noninteractive

if [[ -f /var/${system_unix_name}/system__uninstall_info ]]; then
    echo "re-installing"
else
    echo "installing 1st time"
fi

#
# RUNUSER
#
setup_runuser() {
    cat /etc/passwd | grep "^${runuser}:x" >/dev/null
    if [[ \$? -ne 0 ]]; then
        echo "Generating ${runuser} password."
        runuser_passwd=\$(< /dev/urandom tr -dc A-Za-z0-9 | head -c10)
        echo "adding user ${runuser}."
        adduser --disabled-password --gecos "" ${runuser}
        echo "${runuser}:\${runuser_passwd}" | chpasswd
    else
        echo "user ${runuser} already exists."
    fi
}

pre_apt() {
    echo "override, default." > /dev/null
}

EOF
#------------------------------------------------------------
    echo "#libfn - System"
    system__libfn | grep -v "^#.*"
    echo ""

    echo "#libfn - Subsystems"
    cat libfn
    echo ""

    rm libfn
#------------------------------------------------------------
    cat << EOF
echo "pre-apt:"
pre_apt

EOF
    snippet_apt
    cat << EOF

setup_runuser

echo "#############"
echo "#pre-install#"
echo "#############"
EOF
#------------------------------------------------------------
    cat pre_install__steps
    rm pre_install__steps
#------------------------------------------------------------
    cat << EOF

echo "#########"
echo "#install#"
echo "#########"
EOF
#------------------------------------------------------------
#------------------------------------------------------------
    cat << EOF
if [[ "_\${method}" == "_ssh" ]]; then
    echo "writting files"
    echo "installing from given dir \${system_fs}"
    pushd / > /dev/null
        tar xzf \${tarfile} --strip-components=1 #--skip-old-files
        echo "Installed files:"
        tar -ztvf \${system_fs} | awk '{ print \$NF }' | sed "s/^system//" | grep -v "/\$"
        rm \${tarfile}
    popd > /dev/null
elif [[ "_\${method}" == "_local" ]]; then
    echo "installing from local jaildir \${jail}"
    #find \${jail} -type f
    cp \${jail}/* / -R
fi
EOF
#------------------------------------------------------------
#------------------------------------------------------------
    cat << EOF

echo "##############"
echo "#post-install#"
echo "##############"
EOF
#------------------------------------------------------------
    cat post_install__steps
    rm post_install__steps

    #file permissions
#------------------------------------------------------------
    cat << EOF

echo ""
echo "Sudochowning files"
echo "------------------"
chown ${runuser}:${runuser} /home/${runuser} -R
chown ${runuser}:${runuser} /var/${system_unix_name} -R
mkdir -p /var/log/${system_unix_name}
chown ${runuser}:${runuser} /var/log/${system_unix_name} -R
EOF
#------------------------------------------------------------

    #services
#------------------------------------------------------------
    cat << EOF

systemctl daemon-reload

if [[ \$nostart -eq 0 ]]; then
    echo "Starting ${system_unix_name} services"
    echo "-----------------------------"
    script_tv__ctl.sh start
else
    echo "invoked with flag --no-start: Not starting services."
fi

EOF
    datasheettgt=/var/${system_unix_name}
    datasheetdir=${jail}${datasheettgt}
    datasheet=${datasheetdir}/data_sheet
    if [[ -f ${datasheet} ]]; then
#------------------------------------------------------------
        cat << EOF
cat ${datasheettgt}/data_sheet
EOF
#------------------------------------------------------------
    fi
#------------------------------------------------------------
    cat << EOF
echo "==DONE=="
exit 0
EOF
#------------------------------------------------------------
}

do__system_uninstaller() {
#------------------------------------------------------------
#-- target \/
    cat << EOF
#!/bin/bash
#System uninstaller:
#  1-stop services
#  2-delete files listed in /var/${system_unix_name}/system__uninstall_info
#additional info: It doesn't delete data in /home/${runuser} nor log files
#howto: just run as root
cat << IEOF
EOF
#-- target /\
#------------------------------------------------------------

    banner__bye | sed 's#\\#\\\\#g' | sed 's#`#\\`#g'

#------------------------------------------------------------
#-- target \/
    cat << EOF
IEOF
EOF
#-- target /\
#------------------------------------------------------------

#------------------------------------------------------------
#-- target \/
    cat << EOF

# User root?
uid=\$(id -u)
if [[ uid -ne 0 ]]; then
    >&2 echo "KO 71532 Run as root."
    exit 1
fi

# system__uninstall_info exists?
if [[ ! -f /var/${system_unix_name}/system__uninstall_info ]]; then
    >&2 echo "KO 71533 /var/${system_unix_name}/system__uninstall_info not found."
    exit 1
fi

. /etc/${system_unix_name}/system.env

ts=\$(date +%s)
tsiso=\$(date --date="@\${ts}" --iso-8601=seconds)
mkdir -p /var/log
echo "\$ts \$tsiso uninstall \${monotonic_version}" >> /var/log/updates__script_tv

if [[ -x /usr/local/bin/${system_unix_name}__uninstall_crontab.sh ]]; then
    /usr/local/bin/${system_unix_name}__uninstall_crontab.sh
fi


EOF
#-- target /\
#------------------------------------------------------------
    #services
#------------------------------------------------------------
#-- target \/
    cat << EOF
# special services
echo "Stopping ${system_unix_name} services"
EOF
#-- target /\
#------------------------------------------------------------
    for svc in $(cat /tmp/svcs | xargs | awk '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1; }'); do
        cat << EOF
#------------------------------------------------- ${svc}
echo "stop+disable ${svc}"
systemctl stop ${svc}
systemctl disable ${svc}
EOF
    done
    for svc in $(cat /tmp/svcs__shared | xargs | awk '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1; }'); do
        cat << EOF
#-------------------------------------------------- ${svc}
echo "restart ${svc}"
timeout 10 systemctl stop ${svc}
EOF
    done

#------------------------------------------------------------
#-- target \/
    cat << EOF

echo "###############"
echo "#pre-uninstall#"
echo "###############"
EOF
#-- target /\
#------------------------------------------------------------
    #Append subsystems pre-uninstall__steps
    cat pre_uninstall__steps
    rm pre_uninstall__steps


#------------------------------------------------------------
#-- target \/
    cat << EOF

echo "###########"
echo "#uninstall#"
echo "###########"
EOF
#-- target /\
#------------------------------------------------------------

#------------------------------------------------------------
#-- target \/
    cat << EOF

echo "Deleting files..."
pushd / > /dev/null
    while read -r file
    do
        #echo "  deleting file \${file}"
        rm -f "\${file}"
    done < /var/${system_unix_name}/system__uninstall_info
popd > /dev/null
EOF
#-- target /\
#------------------------------------------------------------

#------------------------------------------------------------
#-- target \/
    cat << EOF

echo "################"
echo "#post-uninstall#"
echo "################"
EOF
#-- target /\
#------------------------------------------------------------
    #Append subsystems post-uninstall__steps
    cat post_uninstall__steps
    rm post_uninstall__steps

#------------------------------------------------------------
#-- target \/
    cat << EOF
rm /var/${system_unix_name} -r
systemctl daemon-reload

echo "deleting /home/${runuser}/*"
rm -rf /home/${runuser}/*

echo "deleting /var/log/${system_unix_name}*"
rm -rf /var/log/${system_unix_name}
rm -rf /var/log/${system_unix_name}*

echo "deleting /var/${system_unix_name}"
rm -rf /var/${system_unix_name}

echo "deleting /etc/${system_unix_name}"
rm -rf /etc/${system_unix_name}

echo "deleting /svr/${system_unix_name}"
rm -rf /svr/${system_unix_name}

echo "==DONE=="
exit 0
EOF
#-- target /\
#------------------------------------------------------------
}

do__user_update() {
    cat << EOF
#!/bin/bash

let silent__on__no_updates=0
if [[ "_\$1" == "_-s" ]]; then
    let silent__on__no_updates=1
fi

uid=\$(id -u)
if [[ uid -ne 0 ]]; then
    >&2 echo "KO 70531 Run as root."
    exit 1
fi

system_unix_name="${system_unix_name}"
runuser="${runuser}"

EOF
    cat ../../lib/target_run/libfn_update.env | grep -v "^#.*"
    cat << EOF

update_entry_point "\${silent__on__no_updates}"

EOF
}

do__systemctl() {
#------------------------------------------------------------
    cat << EOF
#!/bin/bash

verb=\$1
shift

help() {
    cat << FEOF
    stop ............................................. Stop all script_tv services
    start ............................................ Start all script_tv services
    restart .......................................... Stop all then Start all script_tv services

    save_blockchain_state ............................ Stop + save L1 state + start (script4/gov and db/explorer data)
    restore_blockchain_state ......................... Stop + restore L1 state + start

    node_state__info ................................. prints list of files and directories constituting node_state
    move_node_state .................................. Move node state to a safe buffer during verion upgrades. Stop the node before.
    restore_node_state ............................... restore node state. Do this with the node stopped

    stop_save_state .................................. Stop + save node state (move)
    restore_state_start .............................. restore node state (move) + Start

    wait_sync ........................................ Wait node is ready.

    patch_domain xx.yy.zz wan_ip4_address
FEOF
}

system_unix_name="${system_unix_name}"
runuser="${runuser}"

uid=\$(id -u)
if [[ uid -ne 0 ]]; then
    >&2 echo "KO 76931 Run as root."
    exit 1
fi

system__stop() {
EOF
    for svc in $(cat /tmp/svcs | xargs | awk '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1; }'); do
        cat << EOF
    # --shared daemon------------------------------ ${svc}
    if [[ -f /var/${system_unix_name}/svc/disabled/${svc} ]]; then
        cat /var/${system_unix_name}/svc/disabled/${svc}
    else
        systemctl stop ${svc}
        echo "${svc} stopped"
    fi
EOF
    done
    for svc in $(cat /tmp/svcs__shared | xargs | awk '{ for (i=NF; i>1; i--) printf("%s ",$i); print $1; }'); do
        echo "#-------------------------------------------------- ${svc}"
        echo "systemctl \${verb} ${svc}"
        cat << EOF
    # --custom daemon------------------------------ ${svc}
    if [[ -f /var/${system_unix_name}/svc/disabled/${svc} ]]; then
        cat /var/${system_unix_name}/svc/disabled/${svc}
    else
        systemctl stop ${svc}
        echo "${svc} stopped"
    fi
EOF
    done
    cat << EOF
}

system__start() {
EOF
    for svc in $(cat /tmp/svcs__shared | xargs); do
        cat << EOF
    # --shared daemon------------------------------ ${svc}
    if [[ -f /var/${system_unix_name}/svc/disabled/${svc} ]]; then
        cat /var/${system_unix_name}/svc/disabled/${svc}
    else
        systemctl enable ${svc}
        systemctl stop ${svc}
        systemctl start ${svc}
        echo "${svc} started"
    fi
EOF
    done
    for svc in $(cat /tmp/svcs | xargs); do
        cat << EOF
    # --custom daemon-------------------------------${svc}
    if [[ -f /var/${system_unix_name}/svc/disabled/${svc} ]]; then
        cat /var/${system_unix_name}/svc/disabled/${svc}
    else
        systemctl enable ${svc}
        systemctl stop ${svc}
        systemctl start ${svc}
        echo "${svc} started"
    fi
EOF
    done
    cat << EOF
}

if [[ "_\${verb}" == "_stop" ]]; then
    system__stop
    exit 0
fi

if [[ "_\${verb}" == "_start" ]]; then
    system__start
    exit 0
fi

if [[ "_\${verb}" == "_restart" ]]; then
    system__stop && system__start
    exit 0
fi

EOF

    cat ../../lib/target_run/libfn_update.env | grep -v "^#.*"
    cat << EOF

if [[ "_\${verb}" == "_wait_sync" ]]; then
    libfn_update__waitsync_loop "\$1"
    exit $?
fi

if [[ "_\${verb}" == "_node_state__info" ]]; then
    libfn_update__node_state__info
    exit 0
fi
if [[ "_\${verb}" == "_move_node_state" ]]; then
    statedir=\$1
    libfn_update__move_node_state \${statedir}
    exit 0
fi
if [[ "_\${verb}" == "_restore_node_state" ]]; then
    statedir=\$1
    libfn_update__restore_node_state \${statedir}
    exit 0
fi

if [[ "_\${verb}" == "_save_blockchain_state" ]]; then
    statedir=\$1
    libfn_update__save_blockchain_state \${statedir}
    exit 0
fi
if [[ "_\${verb}" == "_restore_blockchain_state" ]]; then
    statedir=\$1
    libfn_update__restore_blockchain_state \${statedir}
    exit 0
fi

if [[ "_\${verb}" == "_stop_save_state" ]]; then
    statedir=\$1
    libfn_update__stop_save_state \${statedir}
    exit 0
fi
if [[ "_\${verb}" == "_restore_state_start" ]]; then
    statedir=\$1
    libfn_update__restore_state_start \${statedir}
    exit 0
fi

>&2 help
>&2 echo "KO 50961 Invalid command"
exit 1

EOF
}

mk_target__vars__echo__header() {
    parent_fn=${FUNCNAME[1]}
    caption="# ${parent_fn:23} =# ${ssn}"
    echo "${caption}"
}

build_vars__echo() {
    cat << EOF
# bin/build.sh
git_url="${git_url}"
git_branch="${git_branch}"
git_version="${git_version}"
monotonic_version="${monotonic_version}"
build_date="${build_date}"
build_mode="${build_mode}"
build_arch="${build_arch}"
build_platform="${build_platform}"
build_uname="${build_uname}"
libbuild__ts="${libbuild__ts}"
libbuild__logdir="${libbuild__logdir}"

EOF
}

rewrite_on_deploy() {
    local file=$1
    mkdir -p $(dirname $mdir/rewrite${file})
    cp $mdir/jail${file} $mdir/rewrite${file}
}

mk_svcs() {
    rm -f /tmp/svcs
    touch /tmp/svcs
    if [[ ! -f _systemctl_services ]]; then
        return
    fi
    local svcs=$(cat _systemctl_services | awk '{ print $2 }' | xargs)
    for svc in ${svcs}; do
        cat /tmp/svcs | grep "$svc" > /dev/null
        if [[ $? -ne 0 ]]; then
            echo "$svc" >> /tmp/svcs
        fi
    done
}

mk_svcs__shared() {
    rm -f /tmp/svcs__shared
    touch /tmp/svcs__shared
    if [[ ! -f _systemctl_services__shared ]]; then
        return
    fi
    local svcs=$(cat _systemctl_services__shared | awk '{ print $2 }' | xargs)
    for svc in ${svcs}; do
        cat /tmp/svcs__shared | grep "$svc" > /dev/null
        if [[ $? -ne 0 ]]; then
            echo "$svc" >> /tmp/svcs__shared
        fi
    done
}

m_files__vars__deploy() {
    mk_target__vars__deploy >> ${mdir}/vars__deploy
}

m_files__apt() {
    mk_target__deps_runtime__apt >> ${mdir}/apt
}

m_files__libfn() {
    cat << EOF >> ${mdir}/libfn

#------------------------------------------------------------------------------------------ libfn subsystem ${ssn}
EOF
    mk_target__libfn | grep -v "^#.*" >> ${mdir}/libfn
}

m_files__steps__pre_install() {
    cat << EOF >> ${mdir}/pre_install__steps

#------------------------------------------------------------------------------------------ pre-install steps subsystem ${ssn}
EOF
    mk_target__steps__pre_install $jail $m | grep -v "^#.*" >> ${mdir}/pre_install__steps
}

m_files__steps__post_install() {
    cat << EOF >> ${mdir}/post_install__steps

#------------------------------------------------------------------------------------------ post-install steps subsystem ${ssn}
EOF
    mk_target__steps__post_install $jail $m | grep -v "^#.*" >> ${mdir}/post_install__steps
}

m_files__steps__pre_uninstall() {
    cat << EOF >> ${mdir}/pre_uninstall__steps

#------------------------------------------------------------------------------------------ pre-uninstall steps subsystem ${ssn}
EOF
    mk_target__steps__pre_uninstall $jail $m | grep -v "^#.*" >> ${mdir}/pre_uninstall__steps
}

m_files__steps__post_uninstall() {
    cat << EOF >> ${mdir}/post_uninstall__steps

#------------------------------------------------------------------------------------------ post-uninstall steps subsystem ${ss}
EOF
    mk_target__steps__post_uninstall $jail $m | grep -v "^#.*" >> ${mdir}/post_uninstall__steps
}

m_files__systemctl_services__shared() {
    mk_target__systemctl_services__shared | grep -v "^#.*" | sed "s#^\(.*\)#${ss} \1#" >> ${mdir}/_systemctl_services__shared
}

m_files__distributor_files() {
    for f in $(mk_target__distributor_files | grep -v '^$' | xargs); do
        mkdir -p ${mdir}/distributor
        cp $f ${mdir}/distributor/
    done
}

m_files() {
    m_files__apt
    m_files__libfn
    m_files__steps__pre_install
    m_files__steps__post_install
    m_files__steps__pre_uninstall
    m_files__steps__post_uninstall
    m_files__systemctl_services__shared
    m_files__vars__deploy
    m_files__distributor_files
}

m_files_ssn__systemctl_services() {
    mk_target__systemctl_services | grep -v "^#.*" | sed "s#^\(.*\)#${ssn} \1#" >> ${mdir}/_systemctl_services
}

m_files_ssn__libweb() {
    mk_target__libweb_info | grep -v "^#.*" | grep -v '^$' > ${mdir}/libweb_
    let n=$(cat ${mdir}/libweb_ | wc -l | tr -d ' ')
    if [[ $n -gt 0 ]]; then
        cat ${mdir}/libweb_ | sort | uniq >> ${mdir}/libweb
        cat ${mdir}/libweb_ | sed "s#^\(.*\) \(.*\).*#${ssn} \1#" | sort | uniq >> ${mdir}/hosts
        cat ${mdir}/libweb_ | sed "s#^\(.*\) \(.*\).*#${ssn} \2#" | sort | uniq >> ${mdir}/urls
    fi
    rm -f ${mdir}/libweb_
}

m_files_ssn__declare_listening_tcp_ports() {
    ss_port_ordinal=1
    mk_target__declare_listening_tcp_ports | grep -v '^$' | tee /tmp/xxcx4 | while read -r line; do
        local n=$(echo $line | xargs -n1 | wc -l | tr -d ' ')
        if [[ "_$n" != "_4" ]]; then
            if [[ "_$n" != "_1" ]]; then
                >&2 echo "$line"
                >&2 echo "KO 33029 Invalid numer of args $n. check function mk_target__declare_listening_tcp_ports at ${ss}"
                exit 1
            fi
        fi
    done
    if [[ $? -ne 0 ]]; then
        >&2 echo "KO 68599 Invalid mk_target__declare_listening_tcp_ports for $ss"
        exit 1
    fi
    cat /tmp/xxcx4 | sed "s#^\(.*\)#${ssn} \1#" >> ${mdir}/open_ports
    rm /tmp/xxcx4
}

m_files_ssn__hot_upgrade__info() {
    mk_target__hot_upgrade__info | grep -v '^$'  >> ${mdir}/hot_upgrade__info
}

m_files_ssn__etc_env() {
    local d="${mdir}/env/${ssn}"
    local name="env"
    mkdir -p $d
    mk_target__vars__echo | grep -v "^build_date=" | grep -v "^libbuild__ts=" >> "$d/${name}"
}

m_files_ssn__misc() {
    echo ${ss_test__delay} >> ${mdir}/test_delay
}

m_files_ssn() {
    m_files_ssn__systemctl_services
    m_files_ssn__libweb
    m_files_ssn__declare_listening_tcp_ports
    m_files_ssn__hot_upgrade__info
    m_files_ssn__etc_env
    m_files_ssn__misc
}

some_checks() {
    if [[ "_${secrets_root}" == "_" ]]; then
        >&2 echo "KO 78694 secrets_root is not set."
        exit 1
    fi
}

info_header__ss0() {
    echo "# subsystem network instance machine(mnemonic)"
    echo "== ========= ======= ======== ================="
    cat /tmp/ssi | ${nl} | xargs -n5
}

print_machines() {
    echo "# machine network subsystem instance"
    echo "== ======= ======= ========= ========"
    cat /tmp/ssi | awk '{ print $4" "$2" "$1" "$3 }' | sort | ${nl} | xargs -n5
}

info_header() {
    cat << EOF
==========================================================================
             bin/build.sh
             build_mode: ${build_mode}
             target: ${build__target_OS}
==========================================================================
EOF
    echo "################################################################"
    echo "## Deployment. Machines (mnemonics)."
    echo "################################################################"
    print_machines | column -t -s ' ' | sed 's~\(.*\)~## \1~'
    echo "################################################################"
    echo
    echo "################################################################"
    echo "## Subsystems build order."
    echo "################################################################"
    info_header__ss0 | column -t -s ' ' | sed 's~\(.*\)~## \1~'
    echo "################################################################"
    echo
}

init_ss_cache() {
    ss_cache_dir=${cachedir}/${build_mode}/${ssn}
    mkdir -p ${ss_cache_dir}
    touch ${ss_cache_dir}/cache_root
}

init_target() {
    init_ss_cache
    mdir=${output_dir}/${m}
    if [[ ! -d ${mdir} ]]; then
        mkdir -p ${mdir}/jail
        touch ${mdir}/apt
        system__deps_runtime__apt > ${mdir}/apt
        libconfigure__deps_runtime__apt >> ${mdir}/apt
        libdeploy__deps_runtime__apt >> ${mdir}/apt
        local envfile="${mdir}/env/system.env"
        mkdir -p $(dirname ${envfile})
        build_vars__echo > ${envfile}
        system_vars__echo >> ${envfile}
        echo ${m} >> ${output_dir}/mnemonics
        if [[ "_${deployment_home}" != "_" ]]; then
            if [[ -d  ${deployment_home}/${m} ]]; then
                echo "copying files from ${deployment_home}/${m} to ${mdir}/"
                cp ${deployment_home}/${m}/* ${mdir}/
            fi
        fi
    fi
    mdir=$(realpath ${output_dir}/${m})
    jail=${mdir}/jail
}

on_ss__push() {
    init_target
}

mk_target__vars__echo__gen() {
    ss=$1
    for f in $(find ${ss}/lib -type f -name "mk_target__set_vars.env"); do
        local g="${ss}/lib/mk_target__vars__echo.env"
        mk_target__vars__echo__gen__file ${f} ${g} "mk_target__"
    done
}

ss_info_header() {
    echo "###########################################################################################"
    echo "#**                                                                                     **#"
    echo "#****  subsystem: ${ss} network: ${ss_network} instance: ${ss_instance}"
    echo "#****  build_mode: ${build_mode}"
    echo "#**                                                                                     **#"
    echo "###########################################################################################"
    echo
}

mk_target__invoke() {
    mk_target__entry_point ${jail} ${m}
    if [[ $? -ne 0 ]]; then
        >&2 echo "KO 76853 ss ${ssn} didn't build."
        exit 1
    fi
    if [[ -f /tmp/stop_compilation ]]; then
        >&2 echo "## ####################################################################"
        >&2 echo "## "
        >&2 echo "## "
        >&2 echo "## "
        >&2 cat /tmp/stop_compilation
        >&2 echo "## "
        >&2 echo "## "
        >&2 echo "## "
        >&2 echo "## ####################################################################"
        rm /tmp/stop_compilation
        exit 1
    fi
    echo
    m_files_ssn
    touch /tmp/outputvars
    mk_target__output_vars__echo | sed 's~^$~=~' | sed 's#=#~#' | column -t -s'~' | ${nl} > /tmp/outputvars
}

mk_targets_ssn() {
    ss_info_header
    echo "#**************************************************************************************#"
    echo "#***                                                                                  ***#"
    echo "#**                                                                                      **#"
    echo "#*                                                                                          *#"
    echo "#* Input vars:"
    mk_target__vars__echo  | sed "s~\(.*\)~#* ${ssn}> \1~"
    echo "#* Secrets:"
    mk_target__secrets__print  | sed "s~\(.*\)~#* ${ssn}> \1~"
    echo "#*"
    echo "#* mk_target__invoke:"
    mk_target__invoke | sed "s~\(.*\)~#* ${ssn} mk> \1~"
    if [[ $? -ne 0 ]];then
        >&2 echo "KO 82934 SS didn't build."
        exit 1
    fi
    echo "#*"
    if [[ -f /tmp/outputvars ]]; then
        echo "#* Output vars:"
        cat /tmp/outputvars | sed "s~\(.*\)~#* ${ssn}> \1~"
        rm /tmp/outputvars
    fi
    echo "#*                                                                                          *#"
    echo "#**                                                                                      **#"
    echo "#***                                                                                  ***#"
    echo "#**************************************************************************************#"
    echo
}

generate_files() {
    for ss in ${subsystems}; do
        mk_target__vars__echo__gen ${ss}
    done
}

mk_targets_sss_i_0() {
    ss__push ${ss} ${ss_network} ${ss_instance} $m
        if [[ -z $ss_cache_dir ]]; then
            >&2 print_stack
            >&2 echo "KO 69586 cache dir!."
            exit 1
        fi
        mk_targets_ssn
    ss__pop
}

mk_targets_sss() {
    while read -r line; do
        ss=$(echo "$line" | awk '{ print $1 }')
        if [[ "_${only_dotool_ss}" != "_" ]]; then
            if [[ "_${ss}" != "_${only_dotool_ss}" ]]; then
                echo "TR 29102 Skipping build SS ${ss}"
                continue
            fi
        fi
        ss_network=$(echo "$line" | awk '{ print $2 }')
        ss_instance=$(echo "$line" | awk '{ print $3 }')
        m=$(echo "$line" | awk '{ print $4 }')
        local x1="${libbuild__logdir}/$(tovar ${ss})__${ss_network}__${ss_instance}"
        buildlog_stdout="${x1}.stdout.log"
        buildlog_stderr="${x1}.stderr.log"
        echo "Writting logs at "
        echo "  * $buildlog_stdout"
        echo "  * $buildlog_stderr"
        echo
        2>${buildlog_stderr} mk_targets_sss_i_0 | tee ${buildlog_stdout}
        let errlines=$(cat ${buildlog_stderr} | wc -l)
        if [[ $errlines -ne 0 ]]; then
            verbose_build=1
            >&2 echo
            >&2 echo '!!!!!!!!==============================================================================================================================='
            cat ${buildlog_stderr} | sed "s~\(.*\)~\!\! KO \!\! \1~" >&2
            >&2 echo '!!!!!!!!==============================================================================================================================='
            >&2 echo "There are $errlines errors. SS ${ss}. Logs at files:"
            >&2 echo "${buildlog_stderr}"
            >&2 echo "${buildlog_stdout}"
            >&2 echo
            exit 1
        fi
        if [[ "_${only_dotool_ss}" != "_" ]]; then
            break
        fi
    done < /tmp/ssi
    if [[ "_${only_dotool_ss}" != "_" ]]; then
        if [[ "_${ss}" != "_${only_dotool_ss}" ]]; then
            echo "TR 29142 Skipping cleanup call"
            continue
        fi
    fi
    # once all calls to SS are done, one last call so SS write static info (all instances)
    awk '!seen[$1,$4]++' /tmp/ssi | sort | while read -r line; do
        ss=$(echo "$line" | awk '{ print $1 }')
        if [[ "_${only_dotool_ss}" != "_" ]]; then
            if [[ "_${ss}" != "_${only_dotool_ss}" ]]; then
                continue
            fi
        fi
        ss_network=$(echo "$line" | awk '{ print $2 }')
        ss_instance=$(echo "$line" | awk '{ print $3 }')
        m=$(echo "$line" | awk '{ print $4 }')
        ss__push ${ss} ${ss_network} ${ss_instance} $m
            . ${libdir}/mk_target.env
            echo "$ss: calling mk_target__cleanup ${jail}"
            mk_target__cleanup ${jail}
        ss__pop
        if [[ "_${only_dotool_ss}" != "_" ]]; then
            break
        fi
    done
}

mk_targets_m() {
    while read -r line; do
        ss=$(echo "$line" | awk '{ print $1 }')
        ss_network=$(echo "$line" | awk '{ print $2 }')
        ss_instance=$(echo "$line" | awk '{ print $3 }')
        m=$(echo "$line" | awk '{ print $4 }')
        ss__push ${ss} ${ss_network} ${ss_instance} $m
            m_files
        ss__pop
    done < /tmp/ssi
}

mk_targets_mnemonic__instances() {
    echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
    echo "## Subsystems Networks Instances                             " | sed "s/\(.*\)/    \1/" >> ${datasheet}
    echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
    cat /tmp/ssi | grep " $m\$" | column -t | sed "s~\(.*\)~    ## \1~" >> ${datasheet}
}

mk_targets_mnemonic__systemctl_services__shared() {
    if [[ ! -f _systemctl_services__shared ]]; then
        return
    fi
    if [[ $(cat _systemctl_services__shared | wc -l | tr -d ' ') -eq 0 ]]; then
        echo "system doesn't use any systemd shared daemon"
    else
        echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
        echo "## systemd shared daemons. (Used)                            " | sed "s/\(.*\)/    \1/" >> ${datasheet}
        echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
        cat _systemctl_services__shared | sort | uniq >> ${datasheet}__shared_daemons
        format_svcs  _systemctl_services__shared | sed "s~\(.*\)~    ## \1~" >> ${datasheet}
        echo >> ${datasheet}
    fi
}

mk_targets_mnemonic__systemctl_services() {
    if [[ ! -f _systemctl_services ]]; then
        return
    fi
    if [[ $(cat _systemctl_services | wc -l | tr -d ' ') -eq 0 ]]; then
        echo "system doesn't run any systemd custom daemon"
    else
        echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
        echo "## Systemd daemons                                           " | sed "s/\(.*\)/    \1/" >> ${datasheet}
        echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
        cat _systemctl_services | sort | uniq >> ${datasheet}__daemons
        format_svcs _systemctl_services | sed "s~\(.*\)~    ## \1~" >> ${datasheet}
        echo >> ${datasheet}
    fi
}

mk_targets_mnemonic__open_ports() {
    if [[ ! -f open_ports ]]; then
        return
    fi
    if [[ $(cat open_ports | wc -l | tr -d ' ') -eq 0 ]]; then
        echo "system doesn't open any port"
    else
        echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
        echo "## Open TCP Ports                                            " | sed "s/\(.*\)/    \1/" >> ${datasheet}
        echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
        cat open_ports >> ${datasheet}__open_ports
        check_ports_file open_ports
        format_ports open_ports |  sed "s~\(.*\)~    ## \1~" >> ${datasheet}
        echo >> ${datasheet}
    fi
    rm -f open_ports
}

mk_targets_mnemonic__hot_upgrade__info() {
    if [[ ! -f hot_upgrade__info ]]; then
        touch hot_upgrade__info
    fi
    if [[ $(cat hot_upgrade__info | wc -l | tr -d ' ') -eq 0 ]]; then
        echo "system doesn't publish hot_upgrade__info"
    else
        echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
        echo "## state files and dirs                                      " | sed "s/\(.*\)/    \1/" >> ${datasheet}
        echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
        mv hot_upgrade__info hot_upgrade__info0
        cat hot_upgrade__info0 | sort | uniq > hot_upgrade__info
        rm hot_upgrade__info0
        cat hot_upgrade__info | sed "s~\(.*\)~    ## \1~" >> ${datasheet}
    fi
}

mk_targets_mnemonic__urls() {
    if [[ ! -f urls ]]; then
        return
    fi
    local n=$(cat urls | wc -l | tr -d ' ')
    if [[ $n -eq 0 ]]; then
        echo "system doesn't publish any URL"
    else
        echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
        echo "## URLs"                                                       | sed "s/\(.*\)/    \1/" >> ${datasheet}
        echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
        if [[ -f hosts ]]; then
            cat hosts >> ${datasheet}__hosts
        else
            touch ${datasheet}__hosts
        fi
        format_urls urls | sed "s~\(.*\)~    ## \1~" >> ${datasheet}
        echo >> ${datasheet}
    fi
    rm -f urls
}

mk_targets_mnemonic__env() {
    if [[ ! -d env ]]; then
        return
    fi
    local d="/etc/${system_unix_name}"

    echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
    echo "## ${system_unix_name}: env master files per subsystem."       | sed "s/\(.*\)/    \1/" >> ${datasheet}
    echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}

    mkdir -p jail/etc/${system_unix_name}
    cp -R env/* jail/etc/${system_unix_name}/
    rm -r env
    find jail/etc/${system_unix_name} -type f -name "env" | sed "s~^jail\(.*\)~\1~" | ${nl} | column -t | sed "s~^\(.*\)~    ## \1~" >> ${datasheet}
    echo >> ${datasheet}
}

mk_targets_mnemonic__distributor() {
    if [[ ! -d distributor ]]; then
        return
    fi
    echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
    echo "## ${system_unix_name}: system user installer distributor    " | sed "s/\(.*\)/    \1/" >> ${datasheet}
    echo "#############################################################" | sed "s/\(.*\)/    \1/" >> ${datasheet}
    find distributor -type f | sed 's~distributor/distributor__\(.*\).env~\1~' | sed "s~^\(.*\)~    ## \1~" >> ${datasheet}
    echo >> ${datasheet}
}

mk_datasheet() {
    datasheetdir=jail/var/${system_unix_name}
    mkdir -p ${datasheetdir}
    datasheet=${datasheetdir}/data_sheet
    echo >> ${datasheet}
    mk_targets_mnemonic__instances
    mk_targets_mnemonic__systemctl_services__shared
    mk_targets_mnemonic__systemctl_services
    mk_targets_mnemonic__open_ports
    mk_targets_mnemonic__hot_upgrade__info
    mk_targets_mnemonic__urls
    mk_targets_mnemonic__env
    mk_targets_mnemonic__distributor
}

compute_test_delay() {
    test_delay=0
    if [[ -f test_delay ]]; then
        test_delay=$(cat test_delay | sort -n | tail -1)
        rm -f test_delay
    fi
    cat << EOF >> build.env
test_delay=${test_delay}
EOF
}

system__uninstall_info() {
    mkdir -p jail/usr/local/bin
    mkdir -p jail/var/${system_unix_name}
    touch jail/usr/local/bin/${system_unix_name}__uninstall.sh
    touch jail/usr/local/bin/${system_unix_name}__test.sh
    touch jail/usr/local/bin/${system_unix_name}__ctl.sh
    touch jail/var/${system_unix_name}/system__uninstall_info
    pushd jail > /dev/null
        find . -type f | sed "s~^\.\(.*\)~\1~" | grep -v "^/tmp/" > var/${system_unix_name}/system__uninstall_info
    popd > /dev/null
}

mk_bin() {
    mkdir -p ${jail}/usr/local/bin
    system__uninstall_info
    mk_svcs
    mk_svcs__shared

    local ofile=system__install.sh
    do__system_installer ${jail} urls $m  > ${ofile}
    chmod +x ${ofile}

    local ofile=${jail}/usr/local/bin/${system_unix_name}__test.sh
    do__system_test > ${ofile}
    chmod +x ${ofile}

    local ofile=${jail}/usr/local/bin/${system_unix_name}__uninstall.sh
    do__system_uninstaller > ${ofile}
    chmod +x ${ofile}

    local ofile=${jail}/usr/local/bin/${system_unix_name}__ctl.sh
    do__systemctl > ${ofile}
    chmod +x ${ofile}

    local ofile=user_update.sh  #only for distr modes
    do__user_update > ${ofile}
    chmod +x ${ofile}

    local ofile=user_install.sh #only for distr modes
    do__user_install > ${ofile}
    chmod +x ${ofile}

    local ofile=node_update.sh  #only for distr modes
    do__node_update > ${ofile}
    chmod +x ${ofile}

    rm -f apt
    rm -f /tmp/svcs
    rm -f /tmp/svcs__shared
    rm -f _systemctl_services
    rm -f _systemctl_services__shared
}

mk_tmpdir() {
    mkdir -p jail/tmp
    chmod 1777 jail/tmp
}

mk_targets_mnemonics() {
    cat << EOF > ${output_dir}/env
#########################################
## Generated by bin/build.sh
#########################################

EOF
    local mdirs=$(cat ${output_dir}/mnemonics)
    local files=""
    for md in $mdirs; do
        m=$(basename ${md})

        #---------------------
        mkdir -p ${output_dir}/${m}/jail/var/${system_unix_name}
        cp doc/release_notes.md ${output_dir}/${m}/jail/var/${system_unix_name}/
        if [[ $? -ne 0 ]]; then
            >&2 pwd
            >&2 echo "KO 66059 doc/release_notes.md"
            exit 1
        fi
        #---------------------
        if [[ -f ${output_dir}/${m}/jail/etc/script_tv/fe/download/central/lon/env ]]; then
            . ${output_dir}/${m}/jail/etc/script_tv/fe/download/central/lon/env
            files=${output_dir}/${m}/jail${files_dir}
            cp doc/release_notes.md ${files}/release_notes.md.txt
        fi
        #---------------------
        # for safeguarding the node state - backup/restore
        cp ${output_dir}/${m}/hot_upgrade__info ${output_dir}/${m}/jail/var/${system_unix_name}/
        if [[ $? -ne 0 ]]; then
            >&2 pwd
            >&2 echo "KO 66061 ${output_dir}/${m}/hot_upgrade__info"
            exit 1
        fi
        #---------------------

        pushd ${output_dir}/${m} > /dev/null
            jail=jail
            mk_datasheet
            compute_test_delay
            cat << EOF >> build.env
monotonic_version=${monotonic_version}
arch=$(uname -m)   #TODO: get from SS (arch or any)
os__id="debian"
os__version_id="11"

EOF
            cat vars__deploy >> ../env
            rm vars__deploy

            mk_bin
            mk_tmpdir
        popd > /dev/null
    done
    if [[ -n "$files" ]]; then
        for md in $mdirs; do
            m=$(basename ${md})
            for f in $(find  ${output_dir}/${m}/jail/home/stv/doc -name "script_tv__stvtool_manual__v*.pdf"); do
                cp $f ${files}/
                pushd ${files}/ > /dev/null
                    ln -s $(basename $f) script_tv__stvtool_manual.pdf
                popd > /dev/null
                break
            done
        done
    fi

    conf_hash > ${output_dir}/conf_hash_
    if [[ "_${system__DNS__subdomain}" != "_" ]]; then
        liburl__domain=${system__DNS__subdomain}.${system__DNS__domain}
    else
        liburl__domain=${system__DNS__domain}
    fi
    cat << EOF >> ${output_dir}/env
system_unix_name="${system_unix_name}"
system__DNS__domain="${system__DNS__domain}"
system__DNS__subdomain="${system__DNS__subdomain}"
liburl__domain="${liburl__domain}"
deployment_home="${deployment_home}"
wget="$wget"
glibc_version="${glibc_version}"

EOF
}

mk_target__amend__dont_uninstall_files_in() {
    if [[ "_$jail" != "_$1" ]]; then
        >&2 print_stack
        >&2 echo "KO 88979 jail mismatch"
        exit 1
    fi
    local jail=$1
    local savedir=$2
    if [[ ! -d ${jail}${savedir} ]]; then
        >&2 print_stack
        >&2 echo "KO 44388. Invalid dir ${jail}${savedir}. pwd $(pwd) "
        exit 1
    fi
    cp ${jail}/var/${system_unix_name}/system__uninstall_info /tmp/tmp827
    cat /tmp/tmp827 | grep -v "${savedir}" > ${jail}/var/${system_unix_name}/system__uninstall_info
    rm /tmp/tmp827
}

mk_target__amend__dont_uninstall_file() {
    local jail=$1
    local savefile=$2
    if [[ ! -f "${jail}${savefile}" ]]; then
        >&2 print_stack
        >&2 echo "KO 44358. Invalid file ${jail}${savefile}. pwd $(pwd) "
        exit 1
    fi
    cp ${jail}/var/${system_unix_name}/system__uninstall_info /tmp/tmp827
    cat /tmp/tmp827 | grep -v "${savefile}" > ${jail}/var/${system_unix_name}/system__uninstall_info
    rm /tmp/tmp827
}

mk_targets_amend() { #called when mdir is in final state.
    >&2 echo "WA 20198 Calling Amend improves rsync times but leaves uninstalled files in target."
    while read -r line; do
        ss=$(echo "$line" | awk '{ print $1 }')
        ss_network=$(echo "$line" | awk '{ print $2 }')
        ss_instance=$(echo "$line" | awk '{ print $3 }')
        if [[ "_${ss_instance}" == "_user" ]]; then
            continue  #distr packages uninstall all installed files
        fi
        m=$(echo "$line" | awk '{ print $4 }')
        ss__push ${ss} ${ss_network} ${ss_instance} $m
            mk_target__amend ${jail} ${m}
        ss__pop
    done < /tmp/ssi
}

produce_system_data_sheet_0() {
    for m in $(cat mnemonics); do
        echo "# Machine mnemonic $m:"
        cat ${m}/jail/var/${system_unix_name}/data_sheet
        echo
    done
}

produce_system_data_sheet_1() {
    for m in $(cat mnemonics); do
        echo "# Machine mnemonic $m:"
        if [[ -f ${m}/jail/var/${system_unix_name}/data_sheet__open_ports ]]; then
            cat ${m}/jail/var/${system_unix_name}/data_sheet__open_ports
        fi
        echo
    done
}

produce_system_data_sheet_2() {
    for m in $(cat mnemonics); do
        echo "# Machine mnemonic $m:"
        if [[ -f ${m}/jail/var/${system_unix_name}/data_sheet__daemons ]]; then
            cat ${m}/jail/var/${system_unix_name}/data_sheet__daemons
        fi
        echo
    done
}

produce_system_data_sheet_3() {
    for m in $(cat mnemonics); do
        echo "# Machine mnemonic $m:"
        if [[ -f ${m}/jail/var/${system_unix_name}/data_sheet__shared_daemons ]]; then
            cat ${m}/jail/var/${system_unix_name}/data_sheet__shared_daemons
        fi
        echo
    done
}

produce_data_sheets() {
    pushd ${output_dir} > /dev/null
        produce_system_data_sheet_0 > system_data_sheet
        produce_system_data_sheet_1 > system_data_sheet__open_ports
        produce_system_data_sheet_2 > system_data_sheet__daemons
        produce_system_data_sheet_3 > system_data_sheet__shared_daemons
    popd > /dev/null
}

print_stats() {
    local nf=$(find ${output_dir} -type f | wc -l | tr -d ' ')
    echo "Directory ${output_dir} contains $nf files"
    echo
}

print_logs() {
    echo "#####################################################################################################################"
    echo "## build log files"
    echo "#####################################################################################################################"
    find ${libbuild__logdir} -type f -name "*.stdout.log" | ${nl} | sed 's~\(.*\)~## \1~'
    echo "#####################################################################################################################"
    echo
    echo "#####################################################################################################################"
    echo "## build_mode: ${build_mode}"
    echo "## System data sheet: ${output_dir}/system_data_sheet"
    echo "#####################################################################################################################"
    echo
}

tsort_resolve3_0() {
    local all=$(cat /tmp/resolve3_ | cut -d ' ' -f1)
    cat /tmp/resolve3_ | while read -r line; do
        local ss=$(echo "$line" | awk '{ print $1 }')
        echo "__EMPTY__ ${ss}"
        . ${libdir}/mk_target.env
        pushd ${ss} > /dev/null
            . ${libdir}/mk_target.env
            local ss_depends=$(mk_target__build_order__depends)
            if [[ "${ss_depends}" == "all" ]]; then
                ss_depends=$all
            fi
            for dep in $ss_depends; do
                echo "$dep $ss"
            done
        popd > /dev/null
    done
}

tsort_resolve3_2() {
    tsort_resolve3_0 | tsort | grep -v "__EMPTY__"
}

tsort_resolve3() {
    mv /tmp/resolve3 /tmp/resolve3_
    cp /tmp/resolve3_ /tmp/resolve3_left
    tsort_resolve3_2 | while read -r line; do
        local ss=$(echo "$line" | awk '{ print $1 }')
        cat /tmp/resolve3_left | grep "^$ss " >> /tmp/resolve3
        cat /tmp/resolve3_left | grep -v "^$ss " > /tmp/resolve3_left_t
        mv /tmp/resolve3_left_t /tmp/resolve3_left
    done
    cat /tmp/resolve3_left >> /tmp/resolve3
    rm /tmp/resolve3_left
    rm /tmp/resolve3_
}

#       dest_variable               SS                  instance    network         var
check_resolve_calls() {
    cat /tmp/ssi | grep "^${ss__ans} " > /dev/null
    if [[ $? -eq 0 ]]; then #if SS included
        cat /tmp/ssi | grep "^${ss__ans} ${ss_network__ans} ${ss_instance__ans} " > /dev/null
        if [[ $? -ne 0 ]]; then #make sure
            >&2 print_stack
            >&2 echo "SS ${ss__ask}: variable: ${destvar}"
            >&2 echo "KO 60111 ${ss__ans} ${ss_instance__ans} ${ss_network__ans} ${var} cannot be resolved"
            exit 1
        fi
    fi
}

resolve() {
    local destvar=$1
    local ss__ans=$2
    local ss_network__ans=$4
    local ss_instance__ans=$3
    local ss__ask=${ss}
    local ss_network__ask=${ss_network}
    local ss_instance__ask=${ss_instance}
    local var=$5
    echo "ASK ${ss__ask} ${ss_network__ask} ${ss_instance__ask} ANS ${ss__ans} ${ss_network__ans} ${ss_instance__ans} ${var} ${destvar}" >> /tmp/resolve
    echo "${ss__ans} ${ss_network__ans} ${ss_instance__ans} " >> /tmp/resolve2
}

resolve_vars() {
    rm -f /tmp/resolve
    rm -f /tmp/resolve2
    rm -f ${resolv_file__prefix}*
    cat /tmp/ssi | awk '{ print $1" "$2" "$3 }' | sort | uniq | while read -r line; do
        ss=$(echo $line | awk '{ print $1 }')
        ss_network=$(echo $line | awk '{ print $2 }')
        ss_instance=$(echo $line | awk '{ print $3 }')
        local fn=$(resolv_file ${ss} ${ss_network} ${ss_instance})
        touch $fn
        pushd ${ss} > /dev/null
            . ${libdir}/mk_target.env
            mk_target__resolve_variables
        popd > /dev/null
    done
    if [[ -f /tmp/resolve2 ]]; then
        cat /tmp/resolve2 | sort | uniq > /tmp/resolve3
        rm -f /tmp/resolve2
    else
        rm -f /tmp/resolve3
        touch /tmp/resolve3
    fi
    tsort_resolve3
    cat /tmp/resolve3 | while read -r line; do
        ss__ans=$(echo "$line" | awk '{ print $1 }')
        ss_network__ans=$(echo "$line" | awk '{ print $2 }')
        ss_instance__ans=$(echo "$line" | awk '{ print $3 }')
        m=$(cat /tmp/ssi | grep "${ss__ans} ${ss_network__ans} ${ss_instance__ans} " | awk '{ print $4 }')
        ss__push ${ss__ans} ${ss_network__ans} ${ss_instance__ans} $m
            cat /tmp/resolve | grep " ANS ${ss__ans} ${ss_network__ans} ${ss_instance__ans} " | while read -r line2; do
                ss__ask=$(echo "$line2" | awk '{ print $2 }')
                ss_network__ask=$(echo "$line2" | awk '{ print $3 }')
                ss_instance__ask=$(echo "$line2" | awk '{ print $4 }')
                var=$(echo "$line2" | awk '{ print $9 }')
                destvar=$(echo "$line2" | awk '{ print $10 }')
                local fn=$(resolv_file ${ss__ask} ${ss_network__ask} ${ss_instance__ask})
                cat << EOF >> ${fn}
${destvar}="${!var}" #~src: ${ss__ans} ${ss_network__ans} ${ss_instance__ans}
EOF
            done
        ss__pop
    done
    rm -f /tmp/resolve3
    rm -f /tmp/resolve
}

sort_subsystems0() {
    local all=$(cat /tmp/ssi_ | cut -d ' ' -f1)
    cat /tmp/ssi_ | while read -r line; do
        ss=$(echo "$line" | awk '{ print $1 }')
        echo "__EMPTY__ ${ss}"
        . ${libdir}/mk_target.env
        pushd ${ss} > /dev/null
            . ${libdir}/mk_target.env
            ss_depends=$(mk_target__build_order__depends)
            if [[ "${ss_depends}" == "all" ]]; then
                ss_depends=$all
            fi
            for dep in $ss_depends; do
                echo "$dep $ss"
            done
        popd > /dev/null
    done
}

sort_subsystems() {
    sort_subsystems0 | tsort | grep -v "__EMPTY__"
}

sort_ssi() {
    mv /tmp/ssi /tmp/ssi_
    cp /tmp/ssi_ /tmp/ssi_left
    sort_subsystems | while read -r line; do
        ss=$(echo "$line" | awk '{ print $1 }')
        cat /tmp/ssi_left | grep "^$ss " >> /tmp/ssi
        cat /tmp/ssi_left | grep -v "^$ss " > /tmp/ssi_left_t
        mv /tmp/ssi_left_t /tmp/ssi_left
    done
    cat /tmp/ssi_left >> /tmp/ssi
    rm /tmp/ssi_left
    rm /tmp/ssi_
}

print_xss0() {
    echo "# file"
    echo "== ===="
    ls -1 /tmp/resolve__* | ${nl} | xargs -n2
}

print_xss() {
    echo "################################################################"
    echo "## X-SS resolution. Files produced"
    echo "################################################################"
    print_xss0 | column -t -s ' ' | sed 's~\(.*\)~## \1~'
    echo "################################################################"
    echo
}

mk_targets() {
    sort_ssi
    info_header
    echo "resolving x-ss variables..."
    resolve_vars
    print_xss
    echo "building subsystems..."
    mk_targets_sss | dottify
    if [[ "_${only_dotool_ss}" != "_" ]]; then
        libconfigure__cleanup
        exit 0
    fi
    mk_targets_m
    mk_targets_mnemonics
    mk_targets_amend
    produce_data_sheets
}

build_main() {
    source_env
    #############################
    ##verbose_build=1     ## DELETE
    #############################
    showonce=0
    git_url="$(git remote -v | awk '{ print $2 }' | uniq)"
    git_branch="$(git branch | grep "^* " | awk '{ print $2}')"
    git_version="$(git describe --always --tags --long --abbrev=10 --dirty --broken)"
    monotonic_version=$(date +%s)
    build_date="$(date --date="@${monotonic_version}" -u)"
    build_arch="$(uname -m)"
    build_platform="${platform}"
    build_uname="$(uname -a)"
    libbuild__ts="$(date --date="@${monotonic_version}" +%Y%m%d%H%M%S)"
    libbuild__logdir="${output_dir}/log/build"
    glibc_version="$(ldd --version | head -n1 | awk '{ print $NF }')"
    if [[ -f ${output_dir}/conf_hash ]]; then
        print_stats
        print_logs
        exit 0
    fi
    rm -rf ${output_dir}
    mkdir -p ${libbuild__logdir}
    touch ${output_dir}/mnemonics
    mk_targets
}

rm -f /tmp/stop_compilation

build_main
if [[ $? -eq 0 ]]; then
    mv ${output_dir}/conf_hash_ ${output_dir}/conf_hash   #broken builds would not contain file conf_hash
fi
print_stats
print_logs
libconfigure__cleanup
echo "Output: ${output_dir}"
echo "==DONE=="
exit 0


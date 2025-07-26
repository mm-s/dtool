#!/bin/bash

set -o pipefail

prefix=$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")
libdir=${prefix}/lib/dtool
. ${libdir}/libdeploy.env

let dryrun_ns=0
let dryrun_test=0
let omit_test=0
let only_preprocess=0

while [[ true ]]; do
    opt=$1
    shift
    if [[ "_$opt" == "_--dryrun" ]]; then
        let dryrun_deploy=1
        let dryrun_ns=1
        let dryrun_test=1
        continue
    elif [[ "_$opt" == "_--omit-test" ]]; then
        let omit_test=1
        continue
    elif [[ "_$opt" == "_-only_preprocess" ]]; then
        let only_preprocess=1
        continue
    else
        break
    fi
done

targets=$opt

load_env_targets ${targets}

echo "${targets}/env:"
cat ${targets}/env
echo

fetch_home="${deployment_home}"

set_m_log() {
    local m=$1
    logfile=${logdir}/${m}/main
    mkdir -p $(dirname ${logfile})
}

rewrite_file() {
    local f=$1
    local dest=$(echo $f | sed "s~${targets}/${m}/rewrite~~")
    cp $f ${targets}/${m}/jail${dest}
    echo "    rewrite ${dest}: "
    # token example: ##DEPLOY__IP_ADDR__m1##
    cat $f | grep "##DEPLOY__IP_ADDR__" | sed "s~[^#]*##DEPLOY__IP_ADDR__\([^#]*\)##[^#]*~\1 ~g" | xargs -n1 | sort | uniq | while read -r mne; do
        if [[ "_$mne" == "_" ]]; then
            continue
        fi
        echo "        resolve IP address for mnemonic $mne"
        local var="${mne}__vm"
        local vm=${!var}
        libvmpool__vm_as "${vm}" m0 
        if [[ $? -ne 0 ]]; then
            echo "KO 33922 "
            exit 1
        fi
        echo "        Replacing token ##DEPLOY__IP_ADDR__${mne}## with ${m0__ip}"
        sedi "s~##DEPLOY__IP_ADDR__${mne}##~${m0__ip}~g" ${targets}/${m}/jail${dest}
    done
    if [[ "$dest" == *"gov/config.yaml" ]]; then
        var="${m}__seeds"
        local seeds=${!var}
        if [[ ! -z "$seeds" ]]; then
            sedi "s~seeds: \"\(.*\)\"~seeds: \"\1,${seeds}\"~" ${targets}/${m}/jail${dest}
        fi
    fi
}

rewrite_files() {
    if [[ ! -d ${targets}/${m}/rewrite ]]; then
        echo "  No files to rewrite. ${m}"
        return
    fi
    for f in $(find ${targets}/${m}/rewrite -type f); do
        echo "  rewrite file ${f}"
        rewrite_file $f
    done
    echo
}

patch_file() {
    file="$1"
    token="$2"
    value="$3"
    sed -i "s~${token}~${value}~g" $file
}

patch_user_installer() {
    local file="$1"
    local fullname="$2"
    local tar_checksum="$3"
    local title="$4"
    local download_url="$5"
    local wget="$6"
    local tar_size="$7"
    local b2c_url="$8"
    local monotonic_version="$9"

    patch_file $file "##title##" "${title}"
    patch_file $file "##tar_size__expected##" "${tar_size}"
    patch_file $file "##tar_checksum__expected##" "${tar_checksum}"
    patch_file $file "##dir##" "${fullname}"
    patch_file $file "##filesurl##" "${download_url}"
    patch_file $file "##orig_domain##" "${liburl__domain}"
    patch_file $file "##wget##" "${wget}"
    patch_file $file "##b2c_url##" "${b2c_url}"
    patch_file $file "##monotonic_version##" "${monotonic_version}"
}

aws_download_file_info() {
    cat << EOF
    $1
        src file: $(realpath aws_s3/${fullname}.tgz)
        file URL: ${aws_s3__download__URL}/${fullname}.tgz
        file size: ${tar_size}
        src hash: ${tar_checksum}
        user command: ${oneliner}

EOF
}

default_distributor() {
    local src_m=$1
    cat << EOF
distributor__os__id=""
distributor__os__version_id=""
distributor__arch=""
distributor__path="/root/distr_${src_m}"
distributor__URL=""
distributor__fullname="${system_unix_name}-default_distributor_$src_m"
distributor__installer_file=""
distributor__installer_absfile=""
distributor__installer_file__URL=""
distributor__wget=""
distributor__wget_installer=""
distributor__oneliner_installer=""
EOF
}

lookup_distributor_file() {
    local src_m=$1
    local file_id=$2
    local m
    for m in $machines; do
        if [[ ! -f ${targets}/${m}/distributor/distributor__${file_id}.env ]]; then
            continue
        fi
        echo "${m} distributor/distributor__${file_id}.env"
        return 0
    done
    for m in $machines; do #look for any real machine
        if [[ "$m" == "$src_m" ]]; then  #skip distr 'machine'
            continue
        fi
        >&2 echo "WA 76031 Distributor for ${file_id} not found. Producing default in machine ${m}."
        mkdir -p ${targets}/${m}/distributor
        default_distributor ${src_m} > ${targets}/${m}/distributor/distributor__${file_id}.env
        echo "${m} distributor/distributor__${file_id}.env"
        return 0
    done
    >&2 echo "KO 39936 Could not find a machine to place the default distributor."
    exit 1
}

install_automatic_updates() {
    local jail=$1
    mkdir -p ${jail}/var/${system_unix_name}
    # for automatic updates, a program that uninstalls + installs
    echo "      * ${system_unix_name}__update.sh"
    cp user_update.sh ${jail}/usr/local/bin/${system_unix_name}__update.sh
    echo "/usr/local/bin/${system_unix_name}__update.sh" >> ${jail}/var/${system_unix_name}/system__uninstall_info
    # for updater to reach the 1liner installer
    echo "      * /etc/${system_unix_name}/distributor.env"
    cp distributor.env ${jail}/etc/${system_unix_name}/
    echo "/etc/${system_unix_name}/distributor.env" >> ${jail}/var/${system_unix_name}/system__uninstall_info
}

build_distrs_and_distribute() {
    for m in $machines; do
        check_m_files $m
        set_m_log ${m}
        local var="${m}__method";
        local method=${!var}
        if [[ "_${method}" != "_distr" ]]; then
            echo "    $m - skipped non-distr mnemonic"
            continue
        fi
        check_method__${method} "${m}"   #sets m0
        echo "    ${m} - method is 'distr'"

        local var=${m}__distributor__fileid
        local distributor__fileid=${!var}
        local var=${m}__title
        local title=${!var}
        if [[ -z "$title" ]]; then
            >&2 echo "KO 50493 ${m}__title not defined"
            exit 1
        fi
        local var=${m}__name
        local name=${!var}
        if [[ -z "$name" ]]; then
            >&2 echo "KO 50494 ${m}__name not defined"
            exit 1
        fi
        local distributor__m=""
        local distributor__file=""
        while read -r line; do
            distributor__m=$(awk '{ print $1 }' <<< "$line")
            distributor__file=$(awk '{ print $2 }' <<< "$line")
            break  #for the moment the algorithm supports only 1 distributor
        done < <(lookup_distributor_file $m ${distributor__fileid})
        echo "    Using distributor file in ${distributor__m}: ${distributor__file}"
        cp ${targets}/${distributor__m}/${distributor__file} ${targets}/${m}/distributor.env
        cat ${targets}/${m}/distributor.env | grep -v '^$' | sed 's~^~        ~'
        . ${targets}/${m}/distributor.env
        pushd ${targets}/${m} > /dev/null
            . build.env
            echo "    Values from cfg_hosts.env:"
            echo "        title: ${title}"
            echo "        name:  ${name}"
            local onliner="${distributor__oneliner_installer}"
            local fullname="${distributor__fullname}"
            if [[ ! -d distr ]]; then
                local var="${m}__aws_s3__download__URL"
                local aws_s3__download__URL=${!var}
                echo "    Installing feature: automatic updates"
                install_automatic_updates jail 
                echo "    packaging ${fullname}"
                mkdir -p distr/${fullname}
                cp -R jail distr/${fullname}/
                echo "    Installing feature: installer"
                cp system__install.sh distr/${fullname}/
                echo "    Installing feature: automatic updates (entry point)"
                cp node_update.sh distr/${fullname}/
                pushd distr > /dev/null
                    #delete ssl cert
                    rm -f ${fullname}/jail/etc/nginx/ssl/private/*.key
                    rm -f ${fullname}/jail/etc/nginx/ssl/cert/*.crt
                    tar -czf ${fullname}.tgz ${fullname}
                    rm ${fullname} -r
                    tar_checksum=$(sha256sum ${fullname}.tgz | awk '{ print $1 }')
                    tar_size=$(stat --format=%s ${fullname}.tgz)
                popd > /dev/null
                echo "    adding ${fullname}__install.sh" #The asset for distributor
                cp user_install.sh distr/${fullname}__install.sh
                b2c_mne=$(cat ../system_data_sheet | grep "# Machine mnemonic" -A1000 | grep "be/b2c " -B1000 | grep "# Machine mnemonic" | awk '{ print $4 }' | tr ':' ' ' | xargs)
                b2c_url=""
                if [[ "_${b2c_mne}" != "_" ]]; then
                    b2c_url=$(echo "$(cat ../${b2c_mne}/jail/var/script_tv/data_sheet__hosts | grep "^be/b2c" | awk '{ print $2 }')${liburl__domain}" | xargs)
                fi
                local packageURL
                if [[ -z "${aws_s3__download__URL}" ]]; then
                    echo "      aws_s3__download__URL is not defined: storing the package in distributor at:"
                    echo "      ${distributor__m}/jail${distributor__path}"
                    mkdir -p ../${distributor__m}/jail${distributor__path}
                    cp distr/${fullname}.tgz ../${distributor__m}/jail${distributor__path}/
                    packageURL="${distributor__URL}"
                else
                    mkdir -p aws_s3
                    mv distr/${fullname}.tgz aws_s3/
                    local var="${m}__aws_s3__bucket"
                    local aws_s3__bucket=${!var}
                    if [[ -z "${aws_s3__bucket}" ]]; then
                        aws_download_file_info "TODO: Update AWS S3 bucket for ${aws_s3__download__URL}:" | tee -a /tmp/deploy_wa
                        >&2 echo "KO 50503 aws_s3__bucket not defined" 
                        exit 1
                    else
                        aws_download_file_info "Updating AWS S3 bucket ${aws_s3__bucket}:"
                        aws s3 ls | grep  " ${aws_s3__bucket}" > /dev/null
                        if [[ $? -ne 0 ]]; then
                            >&2 echo "KO 55049 bucket does not exist or aws cli is not configured"
                            exit 1
                        fi
                        pushd aws_s3 > /dev/null
                            aws_dryrun s3 sync . s3://${aws_s3__bucket}/
                        popd > /dev/null
                    fi
                    packageURL="${aws_s3__download__URL}"
                fi
                patch_user_installer distr/${fullname}__install.sh "${fullname}" "${tar_checksum}" "${title}" "${packageURL}" "${wget} -q" "${tar_size}" "${b2c_url}" "${monotonic_version}"
                echo "    Copying ${fullname}__install.sh to distributor at ${distributor__m}/jail${distributor__path}/" #The asset for distributor
                cp distr/${fullname}__install.sh ../${distributor__m}/jail${distributor__path}/
                echo "    file monotonic_version.txt, contains ${monotonic_version}"
                echo ${monotonic_version} > ../${distributor__m}/jail${distributor__path}/monotonic_version.txt
            else
                echo "      package ${fullname} found already built."
            fi
        popd > /dev/null
        echo "      ${targets}/${m}/distr is ready"
        echo
    done
    echo
}

deploy_main() {
    rm -f /tmp/deploy_wa
    ts=$(date +%Y%m%d_%s)
    logdir=${targets}/log/deploy/${ts}
    mkdir -p ${logdir}
    touch ${logdir}/hosts
    machines=$(find ${targets} -maxdepth 2 -type f -name "system__install.sh" | tr '/' ' ' | awk '{ print $2 }' | sort | uniq | xargs)
    echo "targets to deploy: ${machines}"
    echo "Rewrite files: ${machines}"
    for m in $machines; do
        check_m_files $m
        set_m_log ${m}
        rewrite_files
    done
    echo "Distributions:"
    build_distrs_and_distribute
    if [[ $only_preprocess -eq 1 ]]; then
        echo "only preprocessed"
        exit 0
    fi
    echo
    echo "Check OS"
    for m in $machines; do
        check_m_files $m
        set_m_log ${m}
        local var="${m}__method";
        local method=${!var}
        echo "${m}__method=${method}"
        if [[ "_${method}" == "_distr" ]]; then
            echo "    Skipping mnemonic ${m} with method 'distr'"
            continue
        fi
        check_method__${method} "${m}"
        if [[ "_${method}" == "_local" ]]; then
            continue
        fi
        local var=${m}__vm
        local vma=${!var}
        test_os $vma
    done
    echo
    echo "Deployment:"
    for m in $machines; do
        check_m_files $m
        set_m_log ${m}
        local var="${m}__method";
        local method=${!var}
        echo "${m}__method=${method}"
        if [[ "_${method}" == "_distr" ]]; then
            echo "    Skipping mnemonic ${m} with method 'distr'"
            continue
        fi
        check_method__${method} "${m}"
        if [[ "_${method}" == "_local" ]]; then
            deploy__local ${targets}/${m} | tee -a ${logfile}
            continue
        fi
        local var=${m}__vm
        local vma=${!var}
        local vm=$(vm_root_name ${vma})
        cat ${targets}/${m}/hosts | while read -r line; do
            local host=$(echo $line | awk '{ print $2 }')
            #echo "$host ${m0__vm}" >> ${logdir}/hosts
            echo "$host ${vm}" >> ${logdir}/hosts
        done
        echo "    Deploying mnemonic ${m} using method '${method}'"
        deploy__${method} ${vma} ${targets}/${m} | tee -a ${logfile}
        if [[ $? -ne 0 ]]; then
            >&2 echo "KO 10908 Failed to deploy on machine $m=${vma} (${vm})"
            exit 1
        fi
        echo "Successfully updated machine $m=${vma} (${vm})"
        echo
    done
    echo "---------------------"
    cat ${targets}/env | grep -v '^#.*' | grep -v '^$' | grep "^system__DNS"
    echo "---------------------"
    echo
    if [[ $dryrun_ns -eq 0 ]]; then
        update_nameservers__$(system__DNS__method) ${logdir}/hosts "${system__DNS__subdomain}" "${system__DNS__domain}" | tee ${logdir}/DNS
    fi
}

deploy_main

if [[ -f /tmp/deploy_wa ]]; then
    echo "## Warnings ###########################################################################################"
    cat /tmp/deploy_wa
    echo "#######################################################################################################"
    echo
    rm -f /tmp/deploy_wa
fi

if [[ $omit_test -ne 1 ]]; then
    echo "Invoking test:  bin/test_deployment"
    if [[ $dryrun_test -eq 0 ]]; then
        bin/test_deployment ${targets} 1
        exit $?
    fi
fi

exit 0


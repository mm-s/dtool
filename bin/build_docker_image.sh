#!/usr/bin/env bash

# define directories
TARGETS_DIR="_targets"
DOCKERFILES_DIR="_dockerfiles"
IMAGES_DIR="_images"

mkdir -p ${DOCKERFILES_DIR}
mkdir -p ${IMAGES_DIR}

# for each mnemonic 

mnemonics_file="${TARGETS_DIR}/mnemonics"
if [[ ! -f ${mnemonics_file} ]]; then
    echo "KO 75246 Mnemonics file not found at ${mnemonics_file}"
    exit 1
fi

while read -r mnemonic; do
    if [[ -z "${mnemonic}" ]]; then
        continue
    fi

    target_dir="${TARGETS_DIR}/${mnemonic}"
    if [[ ! -d ${target_dir} ]]; then
        echo "KO 97520 Target directory not found for mnemonic: ${mnemonic}"
        continue
    fi

    dockerfile="${DOCKERFILES_DIR}/Dockerfile.${mnemonic}"
    image_name="image_${mnemonic}"

    cp lib/Dockerfile.template ${dockerfile}
    sed -i "s|_targets/mnemonic/jail/|${target_dir}/jail/|" ${dockerfile}
    sed -i "s|_targets/mnemonic/system__install.sh|${target_dir}/system__install.sh|" ${dockerfile}

    docker build -t ${image_name} -f ${dockerfile} .

    docker save -o ${IMAGES_DIR}/${image_name}.tar ${image_name}
done < ${mnemonics_file}
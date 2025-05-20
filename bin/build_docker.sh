#!/usr/bin/env bash

######################################
## transformation _targets --> _docker
## The only input for this file is the _targets directory
######################################



## snippets:

#################
let macos=0
unm=$(uname)
if [[ "_$unm" == "_Darwin" ]]; then
    let macos=1
fi
## TODO: use .lib/shenv
#################

##########################
## moved from L1/script4/
##########################

## makefiles:


docker_build_debug:
	docker rm script-bridge-out || true
	docker build . -t script-bridge --progress plain  --build-arg="BUILD_FLAGS=-race" --build-arg="LD_FLAGS="
	docker container create  --name script-bridge-out script-bridge
	docker cp script-bridge-out:/app/bin/script-eth-rpc-adaptor _output/
	docker rm script-bridge-out

docker_build_release:
	docker rm script-bridge-out || true
	docker build . -t script-bridge --progress plain
	docker container create  --name script-bridge-out script-bridge
	docker cp script-bridge-out:/app/bin/script-eth-rpc-adaptor _output/
	docker rm script-bridge-out


clean:
	docker volume prune -f
	docker image prune -f

.PHONY: all debug release clean docker_build_debug docker_build_release

##########################
## moved from L1/script4/
##########################

    if [[ $macos -eq 1 ]]; then
        2>/tmp/stderr  docker run --rm -v ${jail}/home/${runuser}/${runtime_subdir}/${network}:/gen  -v ${data}:/data  script4 /app/bin/generate_genesis  -chainID=${network} -erc20snapshot /data/genesis_script_erc20_snapshot.json -stake_deposit /data/genesis_stake_deposit.json -genesis /gen/genesis | tee /tmp/output
    else
        2>/tmp/stderr  $bin/generate_genesis -chainID=${network} -erc20snapshot ${data}/genesis_script_erc20_snapshot.json -stake_deposit ${data}/genesis_stake_deposit.json -genesis ${jail}/home/${runuser}/${runtime_subdir}/${network}/genesis | tee /tmp/output
    fi

    echo "wallet keys dir is ${cfgdir}"
    if [[ $macos -eq 1 ]]; then
        local output=$(docker run --rm  -v ${cfgdir}:/var/key  script4 /app/bin/scriptcli --config /var/key key new)
    else
        local output=$(${jail}/usr/local/bin/${bin_wallet} --config ${cfgdir} key new) 
    fi
    if [[ $macos -eq 1 ]]; then
        local output=$(docker run --rm  -v ${cfgdir}:/var/key  script4 /app/bin/scriptcli --config /var/key key new)
    else
        local output=$(${jail}/usr/local/bin/${bin_wallet} --config ${cfgdir} key new) 
    fi

    ### makefile

docker_build_debug:
	docker rm script4-out || true
	docker build . -t script4 --progress plain  --build-arg="BUILD_FLAGS=-race" --build-arg="LD_FLAGS="
	docker container create  --name script4-out script4
	docker cp script4-out:/app/bin/script _output/
	docker cp script4-out:/app/bin/scriptcli _output/
	docker cp script4-out:/app/bin/dump_storeview _output/
	docker cp script4-out:/app/bin/encrypt_sk _output/
	docker cp script4-out:/app/bin/generate_genesis _output/
	docker cp script4-out:/app/bin/hex_obj_parser _output/
	docker cp script4-out:/app/bin/import_chain _output/
	docker cp script4-out:/app/bin/inspect_data _output/
	docker cp script4-out:/app/bin/query_db _output/
	docker cp script4-out:/app/bin/sign_hex_msg _output/
	docker rm script4-out

docker_build_release:
	docker rm script-bridge-out || true
	docker build . -t script4 --progress plain
	docker container create  --name script4-out script4
	docker cp script4-out:/app/bin/script _output/
	docker cp script4-out:/app/bin/scriptcli _output/
	docker cp script4-out:/app/bin/dump_storeview _output/
	docker cp script4-out:/app/bin/encrypt_sk _output/
	docker cp script4-out:/app/bin/generate_genesis _output/
	docker cp script4-out:/app/bin/hex_obj_parser _output/
	docker cp script4-out:/app/bin/import_chain _output/
	docker cp script4-out:/app/bin/inspect_data _output/
	docker cp script4-out:/app/bin/query_db _output/
	docker cp script4-out:/app/bin/sign_hex_msg _output/
	docker rm script4-out

clean:
	docker volume prune -f
	docker image prune -f -a

.PHONY: all clean build docker_build_debug docker_build_release










## moved from L1/bridge_eth/


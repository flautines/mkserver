#!/usr/bin/bash

VERSION="v0.1.1"

###########
## TITLE ##
###########

TITLE_COLOR="\e[0;37m"
VERSION_COLOR="\e[1;36m"
API_COLOR="\e[0m\e[3;37m"

INFO_COLOR="\e[33m"
ERR_COLOR="\e[31m"
OK_COLOR="\e[32m"

END_ATTR="\e[0m"

# UNICODE SYMBOLS
SPARKLES="\xE2\x9C\xA8"
OKUNI=$'\e[32m\xe2\x9c\x93\e[0m'
KOUNI=$'\e[31m\xe2\x9c\x95\e[0m'
ARUNI=$'\e[33m\xe2\x9e\xa4\e[0m'

echo -e ""
echo -e "$SPARKLES ${TITLE_COLOR}Make Server $VERSION_COLOR${VERSION}$APICOLOR for api.clouding.io$END_ATTR $SPARKLES"
echo -e ""

INPUT="$2"
API_KEYFILE=$HOME/clouding.key
API_URL="https://api.clouding.io/v1"

############
## CHECKS ##
############

echo -en "${INFO_COLOR}Checking API connection...$END_ATTR"
CHECKAPI=$(curl -o /dev/null -sI -X GET ${API_URL}/servers -m 1 -w '%{http_code}\n')
if [ "401" != $CHECKAPI ]; then
	echo -e "${KOUNI}$ERR_COLOR"
	echo -e "No API response, check network connection or name resolution.$END_ATTR"
	echo ""
	exit 1
fi
echo -e "$OK_COLOR OK $OKUNI"
echo -en "${INFO_COLOR}Validating API key...$END_ATTR"
##
## TODO: Check installed dependencies 
##

if [ -f $API_KEYFILE ]; then
	API_KEY=$(cat $API_KEYFILE)
	KEYCHECK=$(curl -sIX GET -H "Content-Type: application/json" -H "X-API-KEY: $API_KEY" "${API_URL}/servers?page=1&pageSize=1" | grep HTTP)
	while [[ ! $KEYCHECK = *200* ]]; do
		echo -e "${KOUNI}${ERR_COLOR} Invalid API Key.$END_ATTR"
		echo -n "${ARUNI} Enter valid API KEY: "
		read API_KEY
		KEYCHECK=$(curl -sIX GET -H "Content-Type: application/json" -H "X-API-KEY: $API_KEY" "${API_URL}/servers?page=1&pagesize=1" | grep HTTP)
	
		echo $API_KEY > $API_KEYFILE
		chmod 600 $API_KEYFILE
		echo -e "${OKUNI}${OK_COLOR} Added API KEY.$END_ATTR"
	done
else
	KEYCHECK=$(echo "null")
	echo -e "${KOUNI}${ERR_COLOR}"
	echo -e "API Key $API_KEYFILE not found.$END_ATTR"
	exit 2
fi
echo -e $OK_COLOR OK $OKUNI

##############
## DEFAULTS ##
##############

DEFAULTFW=$(curl -sX GET -H "Content-Type: application/json" -H "X-API-KEY: $API_KEY" "${API_URL}/firewalls" | jq -r '.values[] | select( .name == "default") | .id')
DEFAULTKEY=$(curl -sX GET -H "Content-Type: application/json" -H "X-API-KEY: $API_KEY" "${API_URL}/keypairs" | jq -r '.values[] | select( .name == "default") | .id')

####################
## AUX. FUNCTIONS ##
####################
get_random() {
	local size=16
	if [[ $# -eq 1 ]]; then 
		local size=$1
	fi

	random_number=$(head -c 16 /dev/urandom | base64)
	random_number=${random_number:0:${size}}
	echo $random_number	
}

list_images() {
	curl -sX GET "${API_URL}/images?pagesize=200" -H "Content-Type: application/json" -H "X-API-KEY: $API_KEY" | jq -c '.images |= sort_by(.name)' | jq -r '["ID","Image","Min.GB","SSH Key","Password"],(.images[] |[.id,.name,.minimumSizeGb,.accessMethods.sshKey,.accessMethods.password]) | @tsv' | csvlook
}

###################
## CREATE SERVER ##
###################
server_create() {
	HOSTNAME=server_$(get_random)
	echo "Server name: $HOSTNAME"

	FLAVOR="1x2"

	##
	## TODO: Refactor
	##
	echo -ne "$ARUNI Enter source image ID (Enter ${INFO_COLOR}list${END_ATTR} to show available images): "
	read IMAGE
	CHECKIMAGE=$(curl -sX GET "${API_URL}/images/$IMAGE" -H "Content-Type: application/json" -H "X-API-KEY: $API_KEY" | jq -r .id)
	
	while [ "$CHECKIMAGE" != "$IMAGE" ]; do
		while [ "$IMAGE" = "list" ]; do
			echo "Getting available images"
			list_images
			echo ""
			echo -n "$ARUNI Enter source image ID: "
			read IMAGE
			CHECKIMAGE=$(curl -sX GET "${API_URL}/images/$IMAGE" -H "Content-Type: application/json" -H "X-API-KEY: $API_KEY" | jq -r .id)
		done
		if [ "$IMAGE" != "$CHECKIMAGE" ]; then
			echo -e "$KOUNI ${ERR_COLOR}Invalid image ID. Please try again.$END_ATTR"
			echo -e "Enter a valid image ID."
			echo -ne "$ARUNI Enter source image ID (Enter ${INFO_COLOR}list${END_ATTR} to show available images): "
			read IMAGE
			CHECKIMAGE=$(curl -sX GET "${API_URL}/images/$IMAGE" -H "Content-Type: application/json" -H "X-API-KEY: $API_KEY" | jq -r .id)
		fi
	done

	VOLUME=$(curl -sX GET "{$API_URL}/images/$IMAGE" -H "Content-Type: application/json" -H "X-API-KEY: $API_KEY" | jq -r .minimumSizeGb)
	
	PASSWORD=""
	CHECKPASS=$(curl -sX GET "{$API_URL}/images/$IMAGE" -H "Content-Type: application/json" -H "X-API-KEY: $API_KEY" | jq -r .accessMethods.password)
	if [ "$CHECKPASS" != "not-supported" ]; then
		PASSWORD=$(get_random)
	fi
	
	STATUS=$(curl -sX POST "{$API_URL}/servers" -H "Content-Type: application/json" -H "X-API-KEY: $API_KEY" -d '{"name":"'$HOSTNAME'","hostname":"'$HOSTNAME'","flavorId":"'$FLAVOR'","firewallId":"'$DEFAULTFW'",}')
}

server_create
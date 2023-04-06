#!/bin/bash

check_os() {
    unameOut="$(uname -s)"
    case "${unameOut}" in
        Linux*)     machine=Linux;;
        Darwin*)    machine=Mac;;
        *)          machine="UNKNOWN:${unameOut}"
    esac
}

get_thumbprint() {
    if [ "${machine}" == "Linux" ]; then
        THUMBPRINT=$(echo | openssl s_client -servername oidc.eks.$1.amazonaws.com -showcerts -connect oidc.eks.$1.amazonaws.com:443 2>&- | tac | sed -n '/-----END CERTIFICATE-----/,/-----BEGIN CERTIFICATE-----/p; /-----BEGIN CERTIFICATE-----/q' | tac | openssl x509 -sha1 -fingerprint -noout | sed 's/://g' | awk -F= '{print tolower($2)}')
        THUMBPRINT_JSON="{\"thumbprint\": \"${THUMBPRINT}\"}"
        echo $THUMBPRINT_JSON
    else
        THUMBPRINT=$(echo | openssl s_client -servername oidc.eks.$1.amazonaws.com -showcerts -connect oidc.eks.$1.amazonaws.com:443 2>&- | tail -r | sed -n '/-----END CERTIFICATE-----/,/-----BEGIN CERTIFICATE-----/p; /-----BEGIN CERTIFICATE-----/q' | tail -r | openssl x509 -sha1 -fingerprint -noout | sed 's/://g' | awk -F= '{print tolower($2)}')
        THUMBPRINT_JSON="{\"thumbprint\": \"${THUMBPRINT}\"}"
        echo $THUMBPRINT_JSON
    fi
}

check_os
get_thumbprint $1

#!/bin/bash

if [[ $# = 0 ]]
then
        echo "usage: $0 [ip]"
else
        ssh -oStrictHostKeyChecking=no -i ./data/crypto/private.key.pem ubuntu@$1
fi

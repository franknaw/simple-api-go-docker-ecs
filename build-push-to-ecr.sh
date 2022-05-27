#!/usr/bin/env bash

# test
acct="123456"

ver="0.0.1"
image="test-api-go"

podman build -t $image:$ver .

podman tag $image:$ver $acct.dkr.ecr.us-gov-west-1.amazonaws.com/$image:$ver
podman tag $image:$ver $acct.dkr.ecr.us-gov-west-1.amazonaws.com/$image:latest

aws ecr get-login-password --region us-gov-west-1 | podman login --username AWS --password-stdin $acct.dkr.ecr.us-gov-west-1.amazonaws.com

podman push $acct.dkr.ecr.us-gov-west-1.amazonaws.com/$image:$ver
podman push $acct.dkr.ecr.us-gov-west-1.amazonaws.com/$image:latest



#!/bin/bash
IMAGE_NAME=ericogr/mongos

echo "====================="

docker build -t $IMAGE_NAME .

echo ""
echo "Docker image $IMAGE_NAME ready."

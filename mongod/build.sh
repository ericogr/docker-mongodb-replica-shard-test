#!/bin/bash
IMAGE_NAME=ericogr/mongodb

echo "====================="

docker build -t $IMAGE_NAME .

echo ""
echo "Docker image $IMAGE_NAME ready."

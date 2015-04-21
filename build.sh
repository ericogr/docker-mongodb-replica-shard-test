#!/bin/bash
cd mongo-db
./build.sh

cd ..

cd mongo-shard
./build.sh

cd ..

#!/bin/bash
set -e

LAYER_NAME=python
BUILD_DIR=.layer-build

rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR/python

pip install dummy_test -t $BUILD_DIR/python

cd $BUILD_DIR
zip -r ../layer.zip python
cd ..
#!/usr/bin/env bash

tar cCv ./shop . --transform='s,^\./,,' >|update.tar

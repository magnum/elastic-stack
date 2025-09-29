#!/bin/bash

FTP_HOST="100.100.100.101"
FTP_USER="username"
FTP_PASS="password"
FTP_PATH="logs"
LOCAL_PATH="/data/elastic-stack/logs/project1"

mkdir -p "$LOCAL_PATH"

ncftpget -R -v -u "$FTP_USER" -p "$FTP_PASS" "$FTP_HOST" "$LOCAL_PATH" "$FTP_PATH/*"

#!/bin/bash

trap 'echo "Дождались";exit 0' SIGUSR1 

echo "Ждем SIGUSR1"
sleep 1000d

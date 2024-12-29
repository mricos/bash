#!/bin/bash

websocat -t -u ws-l:127.0.0.1:8080 tcp:127.0.0.1:8081


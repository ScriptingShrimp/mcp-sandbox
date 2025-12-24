#!/bin/bash

if [[ "$(uname -s)" == "Darwin" ]]; then
    BINARY="./mcphostDarwin"
else
    BINARY="./mcphostX86"
fi

$BINARY \
--config ./mcp.json \
--model ollama:devstral-small-2:latest

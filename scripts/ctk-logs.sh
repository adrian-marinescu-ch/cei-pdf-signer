#!/bin/bash
# View macOS CryptoTokenKit debug logs
# Useful for debugging smart card/token operations

log stream --predicate 'subsystem == "com.apple.CryptoTokenKit"' --debug

#!/usr/bin/env bash

  set -e

  rm -rf erc777-test-kompiled
  kompile --backend java erc777-imp.k --syntax-module ERC777-IMP

  krun --smt none tests/old/name.erc777 -o none
  krun --smt none tests/old/symbol.erc777 -o none
  krun --smt none tests/old/granularity.erc777 -o none
  krun --smt none tests/old/defaultOperators.erc777 -o none

  krun --smt none tests/old/totalSupply.erc777 -o none
  krun --smt none tests/old/balanceOf.erc777 -o none

  krun --smt none tests/old/isOperatorFor.erc777 -o none
  krun --smt none tests/old/authorizeOperator.erc777 -o none
  krun --smt none tests/old/revokeOperator.erc777 -o none

  krun --smt none tests/old/send.erc777 -o none
  krun --smt none tests/old/operatorSend.erc777 -o none
  krun --smt none tests/old/operatorSend2.erc777 -o none

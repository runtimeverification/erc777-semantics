#!/usr/bin/env bash

  set -e

  rm -rf erc777-test-kompiled
  kompile --backend java erc777-imp.k --syntax-module ERC777-IMP

  krun --smt none tests/name.erc777 -o none
  krun --smt none tests/symbol.erc777 -o none
  krun --smt none tests/granularity.erc777 -o none
  krun --smt none tests/defaultOperators.erc777 -o none

  krun --smt none tests/totalSupply.erc777 -o none
  krun --smt none tests/balanceOf.erc777 -o none

  krun --smt none tests/isOperatorFor.erc777 -o none
  krun --smt none tests/authorizeOperator.erc777 -o none
  krun --smt none tests/revokeOperator.erc777 -o none

  krun --smt none tests/send.erc777 -o none
  krun --smt none tests/operatorSend.erc777 -o none
  krun --smt none tests/operatorSend2.erc777 -o none

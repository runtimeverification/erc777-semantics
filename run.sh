  set -e

  rm -rf erc777-test-kompiled
  kompile --backend java erc777-test.k --syntax-module ERC777-TEST-SYNTAX

  krun --smt none tests/name.erc777 -o none
  krun --smt none tests/symbol.erc777 -o none
  krun --smt none tests/granularity.erc777 -o none
  krun --smt none tests/defaultOperators.erc777 # -o none

  krun --smt none tests/totalSupply.erc777 -o none
  krun --smt none tests/balanceOf.erc777 -o none

  krun --smt none tests/isOperatorFor.erc777 -o none
  krun --smt none tests/authorizeOperator.erc777 # -o none
  krun --smt none tests/revokeOperator.erc777 # -o none

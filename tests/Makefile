DEF=erc777-imp
EXT=imp
TESTDIR=*
KOMPILE_FLAGS=--backend java --syntax-module ERC777-IMP
KRUN_FLAGS+=--output none --smt none

TESTS=$(shell find ./ -type f -name '*.imp')

include ktest-hacked.mak

echo:
	@echo
	@echo $(TESTS)

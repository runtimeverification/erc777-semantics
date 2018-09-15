DEF=erc777-imp
EXT=imp
TESTDIR=tests/**
KOMPILE_FLAGS=--backend java --syntax-module ERC777-IMP
KRUN_FLAGS+=--output none --smt none

include $(K_HOME)/k-distribution/include/ktest.mak

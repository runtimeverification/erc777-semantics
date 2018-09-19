# need relative path for `pandoc` on MacOS
PANDOC_TANGLE_SUBMODULE:=.build/pandoc-tangle
TANGLER:=$(PANDOC_TANGLE_SUBMODULE)/tangle.lua
LUA_PATH:=$(PANDOC_TANGLE_SUBMODULE)/?.lua;;
export TANGLER
export LUA_PATH

$(TANGLER):
	git submodule update --init -- $(PANDOC_TANGLE_SUBMODULE)

.PHONY: media defn

defn: erc777.k

%.k: %.md $(TANGLER)
	@echo "==  tangle: $@"
	pandoc --from markdown --to "$(TANGLER)" --metadata=code:'.k' $< \
	    | cat --squeeze-blank > $@

media: erc777.pdf

%.pdf: %.md
	@echo "==  pdf: $@"
	pandoc --from markdown --to latex --output $@ $<

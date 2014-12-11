.PHONY: install refreeze ghci clean prefixed

install:
	@bash etc/build/install.sh

refreeze:
	( rm -rf cabal.sandbox.config cabal.config dist .cabal-sandbox && BUILD_TESTS=yes RUN_TESTS=yes make && cabal freeze )

ghci:
	@cabal exec ghci -- -isrc -isrc/test           \
	    -XOverloadedStrings -XNoImplicitPrelude    \
	    -fwarn-incomplete-patterns                 \
	    -fwarn-incomplete-uni-patterns             \
	    -fwarn-missing-signatures                  \
	    -fwarn-name-shadowing                      \
	    -fwarn-orphans                             \
	    -fwarn-overlapping-patterns                \
	    -fwarn-tabs                                \
	    -fwarn-unused-do-bind                      \
	    -fwarn-unused-matches                      \
	    -Wall                                      \
	    src/Conjure/*.hs src/Conjure/*/*.hs src/test/*.hs src/test/*/*.hs

clean:
	@bash etc/build/clean.sh

prefixed:
	BIN_DIR="dist/conjure-new" make install && \
	mv "dist/conjure-new/conjure" "${HOME}/.cabal/bin/conjureNew"
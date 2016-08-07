.DEFAULT_GOAL := all
TEMPDIR := $(shell mktemp -d)
LABLTKLIBREP?=$(CAML_LD_LIBRARY_PATH)/../labltk

MANREP= man/
MANSCRIPTREP = $(MANREP)scripts/
MANKAPPAMODELSREP = $(MANREP)models/
MANIMGREP = $(MANREP)img/
GENIMG = generated_img
MANGENREP = $(MANREP)$(GENIMG)/

KASAREP = KaSa_rep/
RANDOM_NUMBER = $(shell bash -c 'echo $$RANDOM')
TERM = $(shell echo $$TERM)

OCAMLBUILDFLAGS = $(EXTRAFLAGS)

USE_TK?=0

ifeq ($(USE_TK),1)
OCAMLINCLUDES = -pkg labltk -I KaSa_rep/lib/full -cflags -I,$(LABLTKLIBREP),-I,+labltk -lflags -I,$(LABLTKLIBREP),-I,+labltk -libs labltk,jpflib
else
OCAMLINCLUDES = -I KaSa_rep/lib/light
endif

SCRIPTSSOURCE = $(wildcard $(MANSCRIPTREP)*.sh)
SCRIPTSWITNESS = $(SCRIPTSSOURCE:.sh=.witness)
MODELS = $(wildcard $(MANKAPPAMODELSREP)*.ka)

.PHONY: all clean temp-clean-for-ignorant-that-clean-must-be-done-before-fetch
.PHONY: check build-tests doc clean_doc fetch_version on_linux_for_windows debug

.PRECIOUS: $(SCRIPTSWITNESS)

$(MANGENREP): $(SCRIPTSSOURCE) $(MODELS)
	rm -rf $@
	mkdir $@
VERSION=generated/version.ml
RESOURCE=generated/resource_strings.ml
GENERATED=$(VERSION) \
	  $(RESOURCE) \
	  generated/ApiTypes_t.ml generated/ApiTypes_j.ml \
	  generated/api_types_t.ml generated/api_types_j.ml \
	  generated/mpi_message_t.ml generated/mpi_message_j.ml

RESOURCES_HTML=$(wildcard js/*.js) \
               $(wildcard shared/*.js) \
               $(wildcard js/*.css) js/favicon.ico

ifeq ($(NO_CDN),1)
SITE_EXTRAS= site/external site/external/bootstrap-3.3.5-dist site/external/codemirror-5.14.2 site/external/d3 site/external/jquery
INDEX_HTML=js/no-cdn.html
else
SITE_EXTRAS=
INDEX_HTML=js/use-cdn.html
endif

generated:
	mkdir -p generated

generated/ApiTypes_t.ml: api/ApiTypes.atd generated
	atdgen -t -o generated/ApiTypes api/ApiTypes.atd

generated/ApiTypes_j.ml: api/ApiTypes.atd generated
	atdgen -j -j-std -o generated/ApiTypes api/ApiTypes.atd

generated/api_types_t.ml: api/api_types.atd generated
	atdgen -t -o generated/api_types api/api_types.atd

generated/api_types_j.ml: api/api_types.atd generated
	atdgen -j -j-std -o generated/api_types api/api_types.atd

generated/mpi_message_t.ml: api/mpi_message.atd generated
	atdgen -t -o generated/mpi_message api/mpi_message.atd

generated/mpi_message_j.ml: api/mpi_message.atd generated
	atdgen -j -j-std -o generated/mpi_message api/mpi_message.atd

$(RESOURCE): shared/flux.js shared/plot.js shared/common.js js/JsSim.css api/test_message.json
	./dev/generate-string.sh $^  > $@

$(VERSION): main/version.ml.skel $(wildcard .git/refs/heads/*) generated
	sed -e s/'\(.*\)\".*tag: \([^,\"]*\)[,\"].*/\1\"\2\"'/g $< | \
	sed -e 's/\$$Format:%D\$$'/"$$(git describe --always --dirty || echo unkown)"/ > $@

%.cma %.native %.byte %.docdir/index.html: $(filter-out _build/,$(wildcard */*.ml*)) $(wildcard $(KASAREP)*/*.ml*) $(wildcard $(KASAREP)*/*/*.ml*) $(VERSION) $(RESOURCE)
	"$(OCAMLBINPATH)ocamlbuild" $(OCAMLBUILDFLAGS) $(OCAMLINCLUDES) $@

site: site/JsSim.js site/WebWorker.js $(RESOURCES_HTML)
	mkdir -p site ;\
	cp shared/*.js site
	cp -f js/*.js js/*.css js/favicon.ico js/package.json site

site/external:
	mkdir -p $@

site/external/bootstrap-3.3.5-dist:
	curl -LsS -o $(TEMPDIR)/bootstrap.zip   https://github.com/twbs/bootstrap/releases/download/v3.3.5/bootstrap-3.3.5-dist.zip ;\
	unzip -d site/external $(TEMPDIR)/bootstrap.zip
 
site/external/codemirror-5.14.2:
	curl -LsS -o $(TEMPDIR)/codemirror.zip  http://codemirror.net/codemirror-5.14.2.zip ;\
	unzip -d site/external $(TEMPDIR)/codemirror.zip
	
site/external/d3:
	mkdir -p $@ ;\
	curl -LsS -o $@/d3.v3.min.js http://d3js.org/d3.v3.min.js

site/external/jquery:
	mkdir -p $@ ;\
	curl -LsS -o site/external/jquery/jquery.js https://cdnjs.cloudflare.com/ajax/libs/jquery/2.2.1/jquery.js

site/JsSim.js: JsSim.byte
	js_of_ocaml --debuginfo --pretty "+weak.js" "+nat.js" _build/js/$< -o $@ ;\

site/WebWorker.js: WebWorker.byte
	js_of_ocaml --debuginfo --pretty "+nat.js" _build/js/$< -o $@

ounit: TestJsSim TestWebSim

TestJsSim: TestJsSim.byte
	./TestJsSim.byte
TestWebSim: TestWebSim.byte
	./TestWebSim.byte -runner sequential

site/index.html: site $(INDEX_HTML) $(SITE_EXTRAS)
	cat $(INDEX_HTML) | ./dev/embed-file.sh | sed "s/RANDOM_NUMBER/$(RANDOM_NUMBER)/g" > site/index.html

JsSim.byte: $(filter-out _build/,$(wildcard */*.ml*)) $(GENERATED)
	"$(OCAMLBINPATH)ocamlbuild" $(OCAMLBUILDFLAGS) $(OCAMLINCLUDES) \
	-tag debug -I js -I api \
	-tag-line "<generated/*> : package(atdgen)" \
	-tag-line "<api/*> : package(lwt),package(atdgen)" \
	-tag-line "<js/*> : thread, package(atdgen), package(js_of_ocaml.tyxml), package(lwt)" \
	-tag-line "<js/*.ml*> : package(js_of_ocaml.ppx), package(tyxml.ppx)" \
	$@

TestJsSim.byte: $(filter-out webapp/,$(filter-out _build/,$(wildcard */*.ml*))) $(GENERATED)
	"$(OCAMLBINPATH)ocamlbuild" $(OCAMLBUILDFLAGS) $(OCAMLINCLUDES) \
	-tag debug -I js -I api \
	-tag-line "<generated/*> : package(atdgen)" \
	-tag-line "<api/*> : package(lwt),package(atdgen), package(qcheck.ounit)" \
	-tag-line "<js/*> : thread, package(qcheck.ounit), package(atdgen), package(js_of_ocaml.ppx), package(lwt)" \
	$@

TestWebSim.byte: $(filter-out webapp/,$(filter-out _build/,$(wildcard */*.ml*))) $(GENERATED)
	"$(OCAMLBINPATH)ocamlbuild" $(OCAMLBUILDFLAGS) $(OCAMLINCLUDES) \
	-tag debug -I webapp -I api \
	-tag-line "<generated/*> : package(atdgen)" \
	-tag-line "<api/*> : package(lwt),package(atdgen), package(qcheck.ounit)" \
	-tag-line "<webapp/*> : thread, package(atdgen), package(qcheck.ounit), package(cohttp.lwt), package(re), package(re.perl)" \
	$@


WebWorker.byte: $(filter-out webapp/,$(filter-out _build/,$(wildcard */*.ml*))) $(GENERATED)
	"$(OCAMLBINPATH)ocamlbuild" $(OCAMLBUILDFLAGS) $(OCAMLINCLUDES) \
	-tag debug -I js -I api \
	-tag-line "<generated/*> : package(atdgen)" \
	-tag-line "<api/*> : package(lwt),package(atdgen)" \
	-tag-line "<js/*> : thread, package(atdgen), package(js_of_ocaml), package(lwt)" \
	$@

WebSim.native: $(filter-out js/,$(filter-out _build/,$(wildcard */*.ml*))) $(GENERATED)
	"$(OCAMLBINPATH)ocamlbuild" $(OCAMLBUILDFLAGS) $(OCAMLINCLUDES) \
	-I webapp -I api \
	-tag-line "<generated/*> : package(atdgen)" \
	-tag-line "<api/*> : package(lwt),package(atdgen)" \
	-tag-line "<webapp/*> : thread, package(atdgen), package(cohttp.lwt), package(re), package(re.perl)" \
	$@

WebSim.byte: $(filter-out js/,$(filter-out _build/,$(wildcard */*.ml*))) $(GENERATED)
	"$(OCAMLBINPATH)ocamlbuild" $(OCAMLBUILDFLAGS) $(OCAMLINCLUDES) \
	-tag debug -I webapp -I api \
	-tag-line "<generated/*> : package(atdgen)" \
	-tag-line "<api/*> : package(lwt),package(atdgen)" \
	-tag-line "<webapp/*> : thread, package(atdgen), package(cohttp.lwt), package(re), package(re.perl)" \
	$@

StdSim.native: $(filter-out js/,$(filter-out _build/,$(wildcard */*.ml*))) $(GENERATED)
	"$(OCAMLBINPATH)ocamlbuild" $(OCAMLBUILDFLAGS) $(OCAMLINCLUDES) \
	-I webapp -I api \
	-tag-line "<generated/*> : package(atdgen)" \
	-tag-line "<api/*> : package(lwt),package(atdgen)" \
	-tag-line "<webapp/*> : thread, package(lwt),package(lwt.unix),package(atdgen)" \
	$@

bin/%: %.native Makefile
	[ -d bin ] || mkdir bin && strip -o $@ $<
	rm -f $(notdir $@) && ln -s $@ $(notdir $@)


%.pdf: %.tex $(SCRIPTSWITNESS)
	cd $(dir $<) && LOG=$$(mktemp -t pdflatexlogXXXX); rm -f *.aux && \
	pdflatex -halt-on-error $(notdir $<) > $${LOG} 2>&1 && \
	bibtex $(basename $(notdir $<)) >> $${LOG} 2>&1 && \
	makeindex $(basename $(notdir $<)).idx >> $${LOG} 2>&1 && \
	pdflatex -halt-on-error $(notdir $<) >> $${LOG} 2>&1 && \
	pdflatex -halt-on-error $(notdir $<) >> $${LOG} 2>&1 && \
	rm $${LOG} || { cat $${LOG}; rm $${LOG}; exit 2; }

%.htm: %.tex %.pdf
	cd $(dir $<) && LOG=$$(mktemp -t htlatexlogXXXX); \
	htlatex $(notdir $<)  "nma.cfg,htm,charset=utf-8,p-width" \
	" -cunihtf -utf8" "" "-halt-on-error"> $${LOG} 2>&1 && \
	rm $${LOG} || { cat $${LOG}; rm $${LOG}; exit 2; }

%.witness: %.sh $(MANGENREP) bin/KaSim bin/KaSa $(MODELS) %.gplot
	cd $(dir $@) && KAPPABIN="$(CURDIR)/bin/" sh $(notdir $<) > $(notdir $@) 2>&1 \
	|| { cat $(notdir $@); rm $(notdir $@); exit 2; }

%.witness: %.sh $(MANGENREP) bin/KaSim bin/KaSa $(MODELS)
	cd $(dir $@) && KAPPABIN="$(CURDIR)/bin/" sh $(notdir $<) > $(notdir $@) 2>&1 \
	|| { cat $(notdir $@); rm $(notdir $@); exit 2; }

doc: man/KaSim_manual.pdf
doc_html: dev/KaSim.docdir/index.html man/KaSim_manual.htm

debug:
	@+$(MAKE) EXTRAFLAGS="-tag debug" KaSim.byte dev/db_printers.cma

all: bin/KaSim bin/KaSa bin/KaStor bin/KaDE

clean_doc:
	find man \( -not -name \*.tex -and -name KaSim_manual.\* \) -delete
	find man \( -name \*.htm \) -delete
	find man/scripts \( -name \*.witness \) -delete
	rm -rf $(MANGENREP)

clean: temp-clean-for-ignorant-that-clean-must-be-done-before-fetch clean_doc
	"$(OCAMLBINPATH)ocamlbuild" -clean
	rm -f $(VERSION) $(RESOURCE)
	rm -f sanity_test bin/sanity_test
	rm -f KaSim bin/KaSim KaSa bin/KaSa WebSim bin/WebSim KaStor bin/KaStor
	rm -f KaDE bin/KaDE
	rm -rf KappaBin
	rm -rf site generated
	find . -name \*~ -delete
	+$(MAKE) KAPPABIN="$(CURDIR)/bin/" -C models/test_suite clean

check: bin/sanity_test
	@+$(MAKE) KAPPABIN="$(CURDIR)/bin/" -C models/test_suite clean
	@+$(MAKE) KAPPABIN="$(CURDIR)/bin/" -C models/test_suite all

build-tests: bin/sanity_test
	@+$(MAKE) KAPPABIN="$(CURDIR)/bin/" -C models/test_suite build

temp-clean-for-ignorant-that-clean-must-be-done-before-fetch:
	find . \( -name \*.cm\* -or -name \*.o -or -name \*.annot \) -delete
	rm -f grammar/kappaLexer.ml grammar/kappaParser.ml grammar/kappaParser.mli

KappaBin.zip:
	+$(MAKE) clean
	+$(MAKE) OCAMLFIND_TOOLCHAIN=windows KaSim.native KaSa.native KaStor.native KaDE.native
	mkdir KappaBin
	mv _build/main/KaSim.native KappaBin/KaSim.exe
	mv _build/KaSa_rep/main/KaSa.native KappaBin/KaSa.exe
	mv _build/cflow/KaStor.native KappaBin/KaStor.exe
	mv _build/odes/KaDE.native KappaBin/KaDE.exe
	zip $@ KappaBin/*.exe
	rm -r KappaBin

full:
	$(MAKE) clean
	$(MAKE) USE_TK=1 || echo 0

light:
	$(MAKE) clean
	$(MAKE) USE_TK=0 || echo 0

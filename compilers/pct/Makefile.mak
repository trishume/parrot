## XXX does not cover .includes of core .pasm files

## XXX compilers.dummy in this section is a stopgap.

PCT_LIB_PBCS := \
    $(LIBRARY_DIR)/PCT.pbc \
    $(LIBRARY_DIR)/PCT/PAST.pbc \
    $(LIBRARY_DIR)/PCT/Grammar.pbc \
    $(LIBRARY_DIR)/PCT/HLLCompiler.pbc \
    $(LIBRARY_DIR)/PCT/Dumper.pbc 

$(LIBRARY_DIR)/PCT.pbc : $(PARROT) compilers/pct/PCT.pir \
    $(LIBRARY_DIR)/PCT/Grammar.pbc $(LIBRARY_DIR)/PCT/PAST.pbc
	$(PARROT) -o $@ compilers/pct/PCT.pir

$(LIBRARY_DIR)/PCT/PAST.pbc : compilers/pct/src/PAST.pir $(PARROT) \
    $(LIBRARY_DIR)/PCT/HLLCompiler.pbc \
    compilers/pct/src/PCT/Node.pir \
    compilers/pct/src/PAST/Node.pir \
    compilers/pct/src/PAST/Compiler.pir \
    compilers/pct/src/POST/Node.pir \
    compilers/pct/src/POST/Compiler.pir
	$(PARROT) -o $@ compilers/pct/src/PAST.pir

## depends on $(LIBRARY_DIR)/PGE.pbc $(LIBRARY_DIR)/PGE/Util.pbc
$(LIBRARY_DIR)/PCT/Grammar.pbc : compilers/pct/src/PCT/Grammar.pir $(PARROT) \
    compilers.dummy
	$(PARROT) -o $@ compilers/pct/src/PCT/Grammar.pir

## depends on $(LIBRARY_DIR)/PGE/Dumper.pbc
$(LIBRARY_DIR)/PCT/HLLCompiler.pbc : compilers/pct/src/PCT/HLLCompiler.pir \
    $(PARROT) \
    $(LIBRARY_DIR)/P6object.pbc \
    $(LIBRARY_DIR)/Parrot/Exception.pbc \
    $(LIBRARY_DIR)/config.pir \
    $(LIBRARY_DIR)/Getopt/Obj.pbc \
    $(LIBRARY_DIR)/dumper.pbc \
    $(LIBRARY_DIR)/PCT/Dumper.pbc
	$(PARROT) -o $@ compilers/pct/src/PCT/HLLCompiler.pir

$(LIBRARY_DIR)/PCT/Dumper.pbc : compilers/pct/src/PCT/Dumper.pir $(PARROT)
	$(PARROT) -o $@ compilers/pct/src/PCT/Dumper.pir

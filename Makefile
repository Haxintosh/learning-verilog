BOARD=tangnano9k
FAMILY=GW1N-9C
DEVICE=GW1NR-LV9QN88PC6/I5

FILE=xyz
TOP=xyz

MODULE_DIR = $(patsubst %/,%,$(dir $(FILE)))

BASENAME = $(notdir $(FILE))

ROOT = $(shell pwd)/$(MODULE_DIR)

GENERATED = $(ROOT)/generated/


ifneq ($(filter %_top,$(BASENAME)),)
   SRC = $(filter-out %_tb.v, $(wildcard $(ROOT)/*.v))
else
    SRC = $(ROOT)/$(BASENAME).v
endif

all: $(GENERATED)$(BASENAME).fs

# Synthesis
$(GENERATED)$(BASENAME).json: $(SRC)
	mkdir -p $(GENERATED)
	yosys -p "read_verilog $(SRC); synth_gowin -top $(TOP) -json $(GENERATED)$(BASENAME).json"

# Place and Route
$(GENERATED)$(BASENAME)_pnr.json: $(GENERATED)$(BASENAME).json
	nextpnr-himbaechel --json $(GENERATED)$(BASENAME).json --freq 27 --write $(GENERATED)$(BASENAME)_pnr.json --device ${DEVICE} --vopt cst=$(ROOT)/$(BASENAME).cst --vopt family=$(FAMILY)

# Generate Bitstream
$(GENERATED)$(BASENAME).fs: $(GENERATED)$(BASENAME)_pnr.json
	gowin_pack -d ${FAMILY} -o $(GENERATED)$(BASENAME).fs $(GENERATED)$(BASENAME)_pnr.json

# Program Board
load: $(GENERATED)$(BASENAME).fs
	openFPGALoader -b ${BOARD} $(GENERATED)$(BASENAME).fs -f

# Simulation Object
$(GENERATED)$(BASENAME)_test.o: $(SRC) $(ROOT)/$(BASENAME)_tb.v
	mkdir -p $(GENERATED)
	iverilog -o $(GENERATED)$(BASENAME)_test.o -s test $(SRC) $(ROOT)/$(BASENAME)_tb.v

# Run Test
test: $(GENERATED)$(BASENAME)_test.o
	vvp $(GENERATED)$(BASENAME)_test.o

# Wipe
clean:
	rm -f $(GENERATED)$(BASENAME).vcd $(GENERATED)$(BASENAME).fs $(GENERATED)$(BASENAME)_test.o $(GENERATED)$(BASENAME).json $(GENERATED)$(BASENAME)_pnr.json

.PHONY: load clean test all
.INTERMEDIATE: $(GENERATED)$(BASENAME)_pnr.json $(GENERATED)$(BASENAME).json $(GENERATED)$(BASENAME)_test.o

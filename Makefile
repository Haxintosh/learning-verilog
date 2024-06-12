BOARD=tangnano9k
FAMILY=GW1N-9C
DEVICE=GW1NR-LV9QN88PC6/I5
FILE=xyz 
TOP=xyz 
ROOT = $(shell pwd)
GENERATED = $(ROOT)/generated/
SRC=$(ROOT)/$(FILE).v

all: $(GENERATED)$(FILE).fs
# Synthesis
$(GENERATED)$(FILE).json: $(SRC)
	yosys -p "read_verilog $(SRC); synth_gowin -top $(TOP) -json $(GENERATED)$(FILE).json"

# Place and Route
$(GENERATED)$(FILE)_pnr.json: $(GENERATED)$(FILE).json
	nextpnr-himbaechel --json $(GENERATED)$(FILE).json --freq 27 --write $(GENERATED)$(FILE)_pnr.json --device ${DEVICE} --vopt cst=$(ROOT)/${FILE}.cst --vopt family=${FAMILY}

# Generate Bitstream
$(GENERATED)$(FILE).fs: $(GENERATED)$(FILE)_pnr.json
	gowin_pack -d ${FAMILY} -o $(GENERATED)$(FILE).fs $(GENERATED)$(FILE)_pnr.json

# Program Board
load: $(GENERATED)$(FILE).fs
	openFPGALoader -b ${BOARD} $(GENERATED)$(FILE).fs -f

$(GENERATED)$(FILE)_test.o: $(SRC) $(ROOT)/$(FILE)_tb.v
	iverilog -o $(GENERATED)$(FILE)_test.o -s test $(SRC) $(ROOT)/$(FILE)_tb.v

test: $(GENERATED)$(FILE)_test.o
	vvp $(GENERATED)$(FILE)_test.o

# Wipe
clean:
	rm -f $(GENERATED)$(FILE).vcd $(GENERATED)$(FILE).fs $(GENERATED)$(FILE)_test.o $(GENERATED)$(FILE).json $(GENERATED)$(FILE)_pnr.json

.PHONY: load clean test
.INTERMEDIATE: $(GENERATED)$(FILE)_pnr.json $(GENERATED)$(FILE).json $(GENERATED)$(FILE)_test.o
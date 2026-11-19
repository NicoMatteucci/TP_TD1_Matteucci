TB ?= tb_verificador_legajo

IVERILOG = iverilog
VVP      = vvp
GTKWAVE  = gtkwave

SRC_DIR   = ../src
SIM_DIR   = .
BUILD_DIR = work

# Toma todos los módulos de ../src y los testbenches de simulaciones/
SOURCES = $(wildcard $(SRC_DIR)/*.v) $(wildcard $(SIM_DIR)/*.v)

SIM = $(BUILD_DIR)/$(TB).vvp
VCD = $(TB).vcd

.PHONY: all compile run view clean

all: run

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

compile: $(BUILD_DIR)
	$(IVERILOG) -g2012 -o $(SIM) -s $(TB) $(SOURCES)

run: compile
	$(VVP) $(SIM)

view: run
	$(GTKWAVE) $(VCD) &

clean:
	rm -rf $(BUILD_DIR)
	rm -f *.vcd
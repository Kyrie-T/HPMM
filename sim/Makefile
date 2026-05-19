# Makefile for Verilator simulation of HPMM security test
VERILATOR = verilator
VERILATOR_FLAGS = -Wall -Wno-WIDTH -Wno-EOFNEWLINE -Wno-PINCONNECTEMPTY \
                  -Wno-IMPLICIT -Wno-fatal --cc --exe --build -j

# Source directories
SIM_DIR  = sim
SRC_PE1  = src/lightweight-multiplier

# Top module
TOP = KyberHPM1PE_top

# Output directory
OBJ_DIR = obj_dir

# Test data directory
TEST_DATA_DIR = test-data/pe1

.PHONY: all run clean security_test

all: security_test

# Full security test
security_test: $(SIM_DIR)/hpmm_security_test.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) \
		-CFLAGS "-O2" \
		-y $(SIM_DIR) \
		-y $(SRC_PE1) \
		$(SRC_PE1)/$(TOP).v \
		--top-module $(TOP) \
		--trace \
		--exe $(SIM_DIR)/hpmm_security_test.cpp \
		-o hpmm_security_test
	./$(OBJ_DIR)/hpmm_security_test

# Clean
clean:
	rm -rf $(OBJ_DIR) simx.vcd hpmm_security_test

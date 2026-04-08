CEXT          := c
CPPEXT        := cpp
AEXT          := s
SEXT          := S
SRCEXT        := \([$(CEXT)$(AEXT)$(SEXT)]\|$(CPPEXT)\)
OBJEXT        := o
DEPEXT        := d
SRCDIR        := .
BUILDDIR      := OBJ
TARGETDIR     := bin

# 1. Require romCode only for specific targets (e.g., all, Arty, Arty_imc)
CHECK_TARGETS := all Arty Arty_imc $(TARGETDIR)/boot.memfile
ifneq ($(filter $(CHECK_TARGETS),$(MAKECMDGOALS)),)
    ifndef romCode
        $(error romCode is not set. Usage: make romCode=your_value (romCode should be a folder located in ../loadable_programs/))
    endif
endif

LOADABLE_DIR  := ../loadable_programs/$(romCode)

# 2. Search for sources in both directories
SOURCES       := $(shell find $(SRCDIR) -type f -regex ".*\.$(SRCEXT)" | sort)
ifdef romCode
    SOURCES   += $(shell find $(LOADABLE_DIR) -type f -regex ".*\.$(SRCEXT)" | sort 2>/dev/null)
endif

# 3. Object mapping (Flattening into BUILDDIR)
OBJECTS       := $(SOURCES:.$(CEXT)=.$(OBJEXT))
OBJECTS       := $(OBJECTS:.$(AEXT)=.$(OBJEXT))
OBJECTS       := $(OBJECTS:.$(SEXT)=.$(OBJEXT))
OBJECTS       := $(OBJECTS:.$(CPPEXT)=.$(OBJEXT))
OBJECTS       := $(addprefix $(BUILDDIR)/, $(notdir $(OBJECTS)))

# 4. VPATH allows Make to find the raw source files regardless of which directory they are in
vpath %.$(CEXT)   $(SRCDIR) $(LOADABLE_DIR)
vpath %.$(CPPEXT) $(SRCDIR) $(LOADABLE_DIR)
vpath %.$(AEXT)   $(SRCDIR) $(LOADABLE_DIR)
vpath %.$(SEXT)   $(SRCDIR) $(LOADABLE_DIR)

# --- Standard Variables ---
TARGET        := $(TARGETDIR)/boot
MARCH         := -march=rv32imc_zicsr
MABI          := -mabi=ilp32
LINK_FLAGS    := $(MARCH) $(MABI) -nostartfiles
LIBS          := -lm
LINKER        := linker1000.x

SYSTEMCLOCK   ?= 20000000
MAXSDCCLOCK   ?= 5000000
EXT_MEM_BASE  ?= 0x80000000
EXT_MEM_RANGE ?= 0x10000000

override CFLAGS += $(MARCH) $(MABI) -mcmodel=medany -O2 -g \
                   -DSYSTEMCLOCK=${SYSTEMCLOCK} -DMAXSDCCLOCK=${MAXSDCCLOCK} \
                   -DEXT_MEM_BASE=${EXT_MEM_BASE} -DEXT_MEM_RANGE=${EXT_MEM_RANGE}

CC := riscv64-unknown-elf-gcc

# --- Targets ---

all: directories $(TARGET).memfile

Arty_imc: XILINX_PART := xc7a100tcsg324-1
Arty_imc: all
	@echo "Built for Part: $(XILINX_PART)"

directories:
	@mkdir -p $(TARGETDIR)
	@mkdir -p $(BUILDDIR)

clean:
	rm -rf $(BUILDDIR) $(TARGETDIR)

# --- Compiler Rules (Using vpath) ---

$(BUILDDIR)/%.$(OBJEXT): %.$(CEXT)
	$(CC) $(CFLAGS) $(INC) -c -o $@ $<
	@$(CC) $(CFLAGS) $(INC) -MM $< > $(BUILDDIR)/$*.$(DEPEXT)

$(BUILDDIR)/%.$(OBJEXT): %.$(AEXT)
	$(CC) $(CFLAGS) -c -o $@ $<
	@echo $@: $< > $(BUILDDIR)/$*.$(DEPEXT)

$(BUILDDIR)/%.$(OBJEXT): %.$(SEXT)
	$(CC) $(CFLAGS) $(INC) -c -o $@ $<
	@echo $@: $< > $(BUILDDIR)/$*.$(DEPEXT)

# --- Linker and Post-Processing ---

$(TARGET): $(OBJECTS)
	$(CC) $(LINK_FLAGS) -g -o $(TARGET) $(OBJECTS) $(LIBS) -T ${LINKER}

$(TARGET).memfile: $(TARGET)
	riscv64-unknown-elf-objdump -d $< > $<.objdump
	riscv64-unknown-elf-elf2hex --bit-width 32 --input $< --output $@
	./splitfile.sh $@
	mv boot.mem ../src/boot.mem
	mv data.mem ../src/data.mem

.PHONY: all clean directories Arty_imc

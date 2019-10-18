DEBUG = NONE
VERSION = CYCLONE_V

DFLAGS = -fPIC -w -O3 -lowmem -release -boundscheck=off -g # -version=UVM_NO_DEPRECATED  -version=UVM_NO_WAIT_FOR_NBA

##########################################################################
#
# DUT Sources
#
##########################################################################

DUT_SRC_DIR=../rtl
_TARGETS_=	$(DUT_SRC_DIR)/fifo4.v			\
		$(DUT_SRC_DIR)/simple_spi_top.v

##########################################################################
#
# Test Bench Sources
#
##########################################################################
_TOP_=tst_bench_top
TB_SRC_DIR=../bench
_TB_=		$(TB_SRC_DIR)/tst_bench_top.v

all: spi.vvp spi.vpi

spi.vvp: $(_TARGETS_) $(_TB_)
	iverilog -I $(DUT_SRC_DIR) -I $(TB_SRC_DIR) -D WAVES -o $@ $^

clean:
	rm -f spi.vvp spi.vpi spi.o tr_db.log *.vcd

run: spi.vvp spi.vpi
	vvp -M. -mspi spi.vvp +UVM_VERBOSITY=DEBUG +UVM_TESTNAME=spi_tb.random_test  +UVM_OBJECTION_TRACE # 

# run: a.out
# 	./a.out

# clean:
# 	rm a.out
##########################################################################
#
# Misc Variables
#
##########################################################################

# a.out:
# 	iverilog -I $(DUT_SRC_DIR) -I $(TB_SRC_DIR) -D WAVES	\
# 	$(_TARGETS_) $(_TB_)

spi.vpi: $(TB_SRC_DIR)/spi_tb.d
	ldmd2 $(DFLAGS) -shared -of$@ -L-luvm-ldc-shared -L-lesdl-ldc-shared \
		-L-lphobos2-ldc-shared -L-ldl $^

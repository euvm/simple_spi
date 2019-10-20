import esdl;
import uvm;
import std.stdio;
import std.string: format;

enum kind_e {READ, WRITE};

class apb_rw: uvm_sequence_item
{
  @UVM_DEFAULT {
    @rand ubyte addr;
    @rand ubyte data;
    @rand kind_e kind;

    bool error;
  }
 
  mixin uvm_object_utils;
   
  this(string name = "apb_rw") {
    super(name);
  }

  Constraint! q{
    addr < 4;
  } addr_range;


  override void do_vpi_put(uvm_vpi_iter iter) {
    iter.put_values(addr, data, kind);
  }

  override void do_vpi_get(uvm_vpi_iter iter) {
    iter.get_values(addr, data, kind, error);
  }
}

class apb_monitor: uvm_monitor
{
  spi_seq_item spi_item;
  
  @UVM_BUILD {
    uvm_analysis_imp!(write) apb_analysis;
    // uvm_analysis_port!spi_seq_item spi_port;
  }

  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  void write(apb_rw item) {
    uvm_info("APB MONITOR", format("\n%s", item.sprint()), UVM_DEBUG);
  }
}


class apb_mosi_seq: apb_seq
{
  mixin uvm_object_utils;

  this(string name="") {
    super(name);
  }

  Constraint!q{
    _kind == 0x01;
    _addr == 0x02;
  } random_write;
}



class apb_seq: uvm_sequence!apb_rw
{
  mixin uvm_object_utils;

  apb_rw req;
  apb_rw rsp;
  spi_seq_item spi_rw;
  apb_sequencer sequencer;

  @rand {
    ubyte _data;
    ubyte _addr;

    kind_e _kind;
  }

  void set_read(ubyte addr) {
    _kind = kind_e.READ;
    _addr = addr;
  }

  void set_write(ubyte addr, ubyte data) {
    _kind = kind_e.WRITE;
    _addr = addr;
    _data = data;
  }
  
  this(string name="") {
    super(name);
  }

  // task
  override void body() {
    import std.stdio;

    // uvm_info("apb_seq", "Starting sequence", UVM_MEDIUM);
    req = apb_rw.type_id.create("req_" ~ get_name);
    // atomic sequence
    // uvm_create(req);

    req.kind = _kind;
    req.addr = _addr;
    req.data = _data;

    // apb_rw cloned = cast(apb_rw) req.clone;
    start_item(req);
    finish_item(req);

    // uvm_info("apb_rw", "Finishing sequence", UVM_MEDIUM);
  } // body

}

class spi_bit_seq_item: uvm_sequence_item
{
  mixin uvm_object_utils;

  @UVM_DEFAULT {
    @rand bool cedge;
    @rand bool dbit;
  }
 
  this(string name = "spi_bit_seq_item") {
    super(name);
  }

  override void do_vpi_put(uvm_vpi_iter iter) {
    iter.put_values(cedge, dbit);
  }

  override void do_vpi_get(uvm_vpi_iter iter) {
    iter.get_values(cedge, dbit);
  }
}


class spi_seq_item: uvm_sequence_item
{
  mixin uvm_object_utils;
   
  @UVM_DEFAULT {
    @rand ubyte  data;
  }
 
  this(string name = "spi_seq_item") {
    super(name);
  }

  // override public string convert2string() {
  //   if(kind == kind_e.WRITE)
  //     return format("kind=%s addr=%x data=%x",
  // 		    kind, addr, data);
  //   else
  //     return format("kind=%s addr=%x data=%x",
  // 		    kind, addr, data);
  // }

  void postRandomize() {
    // writeln("post_randomize: ", this.convert2string);
  }
}

class spi_seq: uvm_sequence!spi_seq_item
{
  mixin uvm_object_utils;

  spi_seq_item req;
  spi_seq_item rsp;
  spi_sequencer sequencer;

  this(string name="") {
    super(name);
  }

  // task
  override void body() {
      // uvm_info("spi_seq", "Starting sequence", UVM_MEDIUM);
      req = spi_seq_item.type_id.create("req_" ~ get_name);

      // atomic sequence
      // uvm_create(req);

      for (size_t i=0; i!=1000; ++i) {
	import std.stdio;

	req.randomize();
	spi_seq_item cloned = cast(spi_seq_item) req.clone;
	uvm_send(cloned);
	// get_response(rsp);
      }
    
      // uvm_info("apb_rw", "Finishing sequence", UVM_MEDIUM);
    } // body

}

class spi_sequencer: uvm_sequencer!spi_seq_item
{
  mixin uvm_component_utils;
  
  this(string name, uvm_component parent=null) {
    super(name, parent);
  }
}

class apb_driver(string vpi_func):
  uvm_vpi_driver!(apb_rw, vpi_func)
{
  alias REQ=apb_rw;
  
  mixin uvm_component_utils;
  
  REQ tr;

  this(string name, uvm_component parent) {
    super(name,parent);
  }
  
  override void run_phase(uvm_phase phase) {
    uvm_info ("INFO" , "Called my_driver::run_phase", UVM_DEBUG);
    super.run_phase(phase);
    get_and_drive(phase);
  }
	    
  void get_and_drive(uvm_phase phase) {
    while(true) {
      seq_item_port.get_next_item(req);
      drive_vpi_port.put(req);
      item_done_event.wait();
      seq_item_port.item_done();
    }
  }
}

class apb_agent(string VPI): uvm_agent
{
  mixin uvm_component_utils;

  @UVM_BUILD {
    apb_driver!(VPI)     driver;
    apb_sequencer       sequencer;
    apb_snooper!(VPI)    monitor;
  }

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  override void connect_phase(uvm_phase phase) {
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) {
      driver.seq_item_port.connect(sequencer.seq_item_export);
    }
  }
}

class spi_env: uvm_env
{
  mixin uvm_component_utils;
  @UVM_BUILD {
    spi_agent serial_agent;
    apb_agent!("apb") parallel_agent;
    spi_bit_snooper!"mosi" mosi_snooper;
    spi_bit_snooper!"miso" miso_snooper;
    // apb_monitor u_apb_monitor;
    spi_monitor mosi_monitor;
    spi_scoreboard u_spi_scoreboard;
  }

  this(string name, uvm_component parent) {
    super(name, parent);
  }
  // task
  override void connect_phase(uvm_phase phase) {
    super.connect_phase(phase);
    parallel_agent.sequencer.spi_get_port.connect( serial_agent.sequencer.seq_item_export);
    // parallel_agent.monitor.rsp_port.connect(u_apb_monitor.apb_analysis);
    mosi_snooper.rsp_port.connect(mosi_monitor.analysis_port);
    parallel_agent.monitor.rsp_port.connect(mosi_monitor.apb_analysis);
    mosi_monitor.spi_port.connect(u_spi_scoreboard.spi_analysis);
    parallel_agent.monitor.rsp_port.connect(u_spi_scoreboard.apb_analysis);
  }
}

class spi_agent: uvm_agent
{
  @UVM_BUILD {
    spi_sequencer sequencer;
  }

  mixin uvm_component_utils;

  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  //override void connect_phase(uvm_phase phase) {
  //  driver.seq_item_port.connect(sequencer.seq_item_export);
}

class apb_snooper(string vpi_func): uvm_vpi_monitor!(apb_rw, vpi_func)
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent = null) {
    super(name, parent);
  }
}

class spi_bit_snooper(string vpi_func):
  uvm_vpi_monitor!(spi_bit_seq_item, vpi_func)
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent = null) {
    super(name, parent);
  }
}

class spi_scoreboard: uvm_scoreboard
{
  mixin uvm_component_utils;

  apb_rw       apb_item;
  spi_seq_item spi_item;

  @UVM_BUILD {
    uvm_analysis_imp!(write_spi) spi_analysis;
    uvm_analysis_imp!(write_apb) apb_analysis;
  }

  void write_spi(spi_seq_item item) {
    uvm_info("SPI TRANSMIT", format("%x", item.data), UVM_DEBUG);
    spi_item = item;
    compare_spi_to_apb();
  }

  void write_apb(apb_rw item) {
    if (item.kind == kind_e.WRITE && item.addr == 0x02) {
      uvm_info("APB TRANSMIT", format("%x", item.data), UVM_DEBUG);
      apb_item = item;
    }
  }

  void compare_spi_to_apb() {
    if (spi_item.data == apb_item.data) {
      uvm_info("SPI MATCHED", format("%x", spi_item.data), UVM_DEBUG);
    } else {
      uvm_info("SPI", format("%x", spi_item.data), UVM_DEBUG);
      uvm_info("APB", format("%x", apb_item.data), UVM_DEBUG);
      uvm_error("SPI MISMATCHED", "Scoreboard received unmatched response between SPI & APB");
    }
  }
  
  this(string name, uvm_component parent = null) {
    super(name, parent);
  }
}

class spi_monitor: uvm_monitor
{
  // spi_seq_item spi_item;
  
  @UVM_BUILD {
    uvm_analysis_imp!(write) analysis_port;
    uvm_analysis_imp!(write_apb) apb_analysis;
    uvm_analysis_port!spi_seq_item spi_port;
  }

  mixin uvm_component_utils;

  bool cpol;
  bool cpha;

  ubyte word;
  uint count;

  spi_seq_item u_spi_seq_item;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  void write(spi_bit_seq_item item) {
    import std.stdio;

    if (cpha is false && item.cedge is true) {
      if (count == 0) {
	u_spi_seq_item = new spi_seq_item("u_spi_seq_item");
      }
      word <<= 1;
      word |= item.dbit;
      writeln("Word is: ", word, " at count: ", count);
      if (count < 7) count += 1;
      else {
	u_spi_seq_item.data = word;
	spi_port.write(u_spi_seq_item);
	count = 0;
      }
    }
    uvm_info("SPI MONITOR", format("\n%s", item.sprint()), UVM_DEBUG);
  }

  void write_apb(apb_rw item) {
    if (item !is null) {
      if (item.addr == 0x00) {
	if ((item.data >> 3) & 0x01) cpol = true;
	else cpol = false;
	if ((item.data >> 2) & 0x01) cpha = true;
	else cpha = false;
      }
      uvm_info("APB MONITOR", format("\n%s", item.sprint()), UVM_DEBUG);
    }
  }
}



class apb_sequencer: uvm_sequencer!apb_rw
{
  mixin uvm_component_utils;
  @UVM_BUILD  {
    uvm_seq_item_pull_port!spi_seq_item  spi_get_port;
  }

  this(string name, uvm_component parent=null) {
    super(name, parent);
  }
}

class random_test: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  @UVM_BUILD {
    spi_env env;
  }

  override void run_phase(uvm_phase  phase) {
    apb_rw item;
    apb_seq confiq_seq;
    apb_mosi_seq wr_seq;
    phase.raise_objection(this, "avl_test");
    // phase.get_objection.set_drain_time(this, 1.usec);
    confiq_seq = apb_seq.type_id.create("apb_seq");
    confiq_seq.set_write(0, 0b01010000);
    confiq_seq.sequencer = env.parallel_agent.sequencer;
    // confiq_seq.randomize();
    confiq_seq.start(env.parallel_agent.sequencer);
    for (size_t i=0; i != 10; ++i) {
      wr_seq = apb_mosi_seq.type_id.create("apb_seq");
      wr_seq.randomize();
      wr_seq.sequencer = env.parallel_agent.sequencer;
      // wr_seq.randomize();
      wr_seq.start(env.parallel_agent.sequencer);
      wait(200.nsec);
    }
    phase.drop_objection(this, "avl_test");
  }
}


void initializeESDL() {
  Vpi.initialize();

  auto test = new uvm_tb;
  test.multicore(0, 4, 0);

  test.elaborate("test");
  test.set_seed(1);
  test.setVpiMode();

  test.start_bg();
}

alias funcType = void function();
shared extern(C) funcType[2] vlog_startup_routines = [&initializeESDL, null];

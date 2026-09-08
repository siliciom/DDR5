# ==========================================
# Default Compile/Run Switches
# ==========================================

set comp_opts ""
set run_opts ""
# ==========================================
# Test Specific Switches
# ==========================================

if {$testname == "ddr5_test"} {

 # set comp_opts "+define+INJECTING_TIMING_ERROR"
 # set run_opts "+ERR_TO_WARN"

} elseif {$testname == "ddr5_test_x8"} {

    set comp_opts "+define+DDR_X8"

}
# ==========================================
# Valid Tests
# ==========================================
transcript quietly
set valid_tests {
    ddr5_test
    ddr5_test_x8
    }
# ==========================================
# Check whether test is valid
# ==========================================

if {[lsearch $valid_tests $testname] == -1} {
 

    puts "\033\[31m"

 

    puts ""
    puts "================================="
    puts "ERROR : INVALID TESTNAME"
    puts "================================="
    puts ""

 

    puts "Given Test : $testname"
    puts ""

 

    puts "\033\[0m"

 

    quit -f
}
# ==========================================
# Print Switches
# ==========================================

puts ""
puts "================================="
puts "Running Test      : $testname"
puts "Compile Switches : $comp_opts"
puts "Run Switches     : $run_opts"
puts "================================="

# ==========================================
# Log/Wave files
# ==========================================
file mkdir results/$testname
set logfile "./results/$testname/${testname}.log"
set wavefile "./results/$testname/${testname}.wlf"
set qwavefile "./results/$testname/qwave.db"
set complog "./results/$testname/comp.log"

# ==========================================
# Library
# ==========================================

vlib work
vmap work work

# ==========================================
# Compile and checks whether compile is passed or not
# ==========================================

   set comp_status [catch {
       vlog -work work -sv \
        ../sequences/ddr5_seq_pkg.sv \
        ../agents/ddr5_agent_pkg.sv \
        ../env/ddr5_env_pkg.sv \
        ../tests/ddr5_test_pkg.sv \
        ../config/ddr5_pkg.sv \
        ../top/ddr5_interface.sv \
        ../top/ddr5_top.sv \
        $comp_opts \
        -l $complog
} comp_result]

if {$comp_status != 0} {

    puts ""
    puts "================================="
    puts "     COMPILATION FAILED"
    puts "================================="
    puts "Compile Log : [file normalize $complog]"
    puts "================================="

    quit -f
}

set fp [open $complog a]

puts $fp ""
puts $fp "================================="
puts $fp "COMPILE PASSED"
puts $fp "Time : [clock format [clock seconds]]"
puts $fp "================================="

close $fp
# ==========================================
# Simulation
# ==========================================

eval vsim -debugDB -voptargs=+acc work.ddr5_top +UVM_TESTNAME=$testname +UVM_VERBOSITY=UVM_LOW $run_opts -l $logfile -qwavedb=+wavefile=$qwavefile
# ==========================================
# Logging
# ==========================================

add log -r /ddr5_top/*
add wave -r /ddr5_top/*

# ==========================================
# Prevent auto exit
# ==========================================

onfinish stop

# ==========================================
# Run Simulation
# ==========================================

run -all

after 1000

# ==========================================
# Read logfile
# ==========================================

set fp [open $logfile r]
set log_data [read $fp]
close $fp

# ==========================================
# PASS / FAIL
# ==========================================

if {[regexp {UVM_ERROR :\s+[1-9]} $log_data] || \
    [regexp {UVM_FATAL :\s+[1-9]} $log_data]} {

    puts "\033\[31m"
    puts "================================="
    puts "         TEST FAILED"
    puts "================================="
    puts "\033\[0m"

    puts ""
    puts "Log File  : [file normalize $logfile]"
    puts "Wave File : [file normalize $qwavefile]"
    puts ""

} else {

    puts ""
    puts "Log File  : [file normalize $logfile]"
    puts "Wave File : [file normalize $qwavefile]"
    puts ""
    
    puts "\033\[32m"
    puts "================================="
    puts "         TEST PASSED"
    puts "================================="
    puts "\033\[0m"

} 
quit -f




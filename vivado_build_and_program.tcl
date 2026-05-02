set project_path [lindex $argv 0]
set jobs [lindex $argv 1]
set mode [lindex $argv 2]

if {$project_path eq ""} {
    error "Missing project path argument."
}

if {$jobs eq ""} {
    set jobs 8
}

if {$mode eq ""} {
    set mode "build"
}

open_project $project_path
reset_run synth_1
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1

if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "Synthesis did not complete successfully."
}

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs $jobs
wait_on_run impl_1

if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "Implementation/bitstream did not complete successfully."
}

set bitstream_path [get_property DIRECTORY [get_runs impl_1]]/[get_property top [current_fileset]].bit
puts "Bitstream: $bitstream_path"

if {$mode eq "program"} {
    open_hw_manager
    connect_hw_server
    open_hw_target

    set hw_device [lindex [get_hw_devices] 0]
    if {$hw_device eq ""} {
        error "No hardware device found. Is the board connected and powered on?"
    }

    current_hw_device $hw_device
    refresh_hw_device $hw_device
    set_property PROGRAM.FILE $bitstream_path $hw_device
    program_hw_devices $hw_device
    puts "Programmed device: $hw_device"
}

close_project

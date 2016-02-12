###############################################################################
##
## (c) Copyright 2012 Xilinx, Inc. All rights reserved.
##
## This file contains confidential and proprietary information
## of Xilinx, Inc. and is protected under U.S. and 
## international copyright and other intellectual property
## laws.
##
## DISCLAIMER
## This disclaimer is not a license and does not grant any
## rights to the materials distributed herewith. Except as
## otherwise provided in a valid license issued to you by
## Xilinx, and to the maximum extent permitted by applicable
## law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
## WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
## AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
## BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
## INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
## (2) Xilinx shall not be liable (whether in contract or tort,
## including negligence, or under any other theory of
## liability) for any loss or damage of any kind or nature
## related to, arising under or in connection with these
## materials, including for any direct, or any indirect,
## special, incidental, or consequential loss or damage
## (including loss of data, profits, goodwill, or any type of
## loss or damage suffered as a result of any action brought
## by a third party) even if such damage or loss was
## reasonably foreseeable or Xilinx had been advised of the
## possibility of the same.
##
## CRITICAL APPLICATIONS
## Xilinx products are not designed or intended to be fail-
## safe, or for use in any application requiring fail-safe
## performance, such as life-support or safety devices or
## systems, Class III medical devices, nuclear facilities,
## applications related to the deployment of airbags, or any
## other applications that could lead to death, personal
## injury, or severe property or environmental damage
## (individually and collectively, "Critical
## Applications"). Customer assumes the sole risk and
## liability of any use of Xilinx products in Critical
## Applications, subject only to applicable laws and
## regulations governing limitations on product liability.
##
## THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
## PART OF THIS FILE AT ALL TIMES.
##
###############################################################################
##
## microblaze_mcs_setup.tcl
##
###############################################################################
#
# This script should be sourced after CORE Generator has been used to generate
# a MicroBlaze MCS instance, either when creating a new or changing an existing
# instance.
#
# Run the script in the PlanAhead Tcl Console by typically using:
#
#  source -notrace \
#    project_1.srcs/sources_1/ip/microblaze_mcs_v1_3_0/microblaze_mcs_setup.tcl
#
# Run the script in the Project Navigator Tcl Console by typically using:
#
#  Command> source ipcore_dir/microblaze_mcs_setup.tcl
#
# Use the menu command "View -> Panels -> Tcl Console" to show the Tcl Console
# in the Project Navigator, if it is not visible.
#
###############################################################################
#
# This script contains two exported Tcl procedures:
#
# o The first, "microblaze_mcs_setup", is used to create a merged BMM file,
#   which defines the local memory of all MicroBlaze MCS instances in the
#   project (if more than one instance), and set Translate process properties
#   to add the "-bm" option indicating the used BMM file.
#
#   The procedure is automatically invoked when sourcing this script, but
#   can also subsequently be invoked with "microblaze_mcs_setup".
#
#   The procedure should be invoked before running implementation, but after
#   the MicroBlaze MCS instance has been generated.
#
# o The second, "microblaze_mcs_data2mem", is used to update the bit stream
#   with one or more ELF files (software programs) given as arguments, generate
#   corresponding MEM files for simulation, and set Bitgen process properties
#   to add the "-bd" option indicating the ELF files.
#
#   If no argument is given, the bit stream is updated with the microblaze
#   boot loop ELF file, which ensures that the processor executes an infinite
#   loop.
#
#   The procedure should be invoked after the system has been implemented. It 
#   must also be invoked again when an ELF file name is changed, or when the
#   content of an ELF file is changed. If the system is reimplemented without
#   changing the software, the procedure need not be invoked again, due to the
#   Bitgen "-bd" option.
#
###############################################################################

namespace eval microblaze_mcs {

  # Determine if using planAhead or Project Navigator
  proc mcs_using_planahead {} {
    return [expr [string first "planAhead" [info nameofexecutable]] != -1]
  }

  # Find all MicroBlaze MCS instances in the project
  # Return a list of lists with instance name and file name
  proc mcs_find_instances {} {
    set mcs_instances {}
    set xco_filenames {}
    if {[mcs_using_planahead]} {
      set found [get_files -quiet -filter {IS_ENABLED==1} "*.xci"]
      if {$found == ""} {
        set found [get_files -quiet -filter {IS_ENABLED==1} "*.xco"]
        if {[string first ".xco" $found] + 4 == [string length $found]} {
          lappend xco_filenames "$found"
        } else {
          set xco_filenames $found
        }
      } elseif {[string first ".xci" $found] + 4 == [string length $found]} {
        lappend xco_filenames [string map {.xci .xco} $found]
      } else {
        foreach item $found {
          lappend xco_filenames [string map {.xci .xco} $item]
        }
      }
    } else {
      set found [search "*.xco"]
      collection foreach item $found {
        lappend xco_filenames [object name $item]
      }
    }

    for {set index 0} {$index < [llength $xco_filenames]} {incr index} {
      set xco_filename [lindex $xco_filenames $index]

      # Check if the xco file is a MicroBlaze MCS IP Core
      set xco_file [open $xco_filename "r"]
      set xco_data [read $xco_file]
      close $xco_file
      if {[regexp {microblaze_mcs} $xco_data]} {
        regexp {CSET component_name=([A-Za-z0-9_]*)} $xco_data match inst
        lappend mcs_instances [list $xco_filename $inst]
      }
    }
    return $mcs_instances
  }

  # Get current options
  proc mcs_get_options {step} {
    if {[mcs_using_planahead]} {
      set dir  [get_property directory [current_project]]
      set name [get_property name [current_project]]
      set run  [current_run -quiet]
      set psg_filename "[file join ${dir} ${name}.data runs ${run}.psg]"
      if {[file exist $psg_filename]} {
        set psg_file [open $psg_filename "r"]
        set psg_data [read $psg_file]
        close $psg_file

        set search "<Step Id=\"[string tolower $step]\">"
        append search {[\n\t ]*<Option Id="MoreOptsStr"><\!\[CDATA\[([^[]*)\]\]>}
        if {[regexp $search $psg_data match option]} {
          return $option
        }
      }
      return ""
    } else {
      return [project get "Other $step Command Line Options"]
    }
  }

  # Handle MicroBlaze BMM files: Create merged file and set ngdbuild options
  proc microblaze_mcs_setup {} {
    set procname "microblaze_mcs_setup"

    # Find all MicroBlaze MCS instances in the project
    set mcs_instances [mcs_find_instances]
    set mcs_instances_length [llength $mcs_instances]
    set cores "cores"
    if {$mcs_instances_length == 1} { set cores "core" }
    puts "$procname: Found $mcs_instances_length MicroBlaze MCS ${cores}."

    if {$mcs_instances_length == 0} {
      return
    }

    # Determine project directory
    if {[mcs_using_planahead]} {
      set projdir [get_property "directory" [current_project]]
    } else {
      set projdir [pwd]
    }

    # Handle BMM files: create merged file if more than one instance
    if {$mcs_instances_length > 1} {

      # Read all MicroBlaze MCS BMM files and merge the data
      # Assign unique IDs (last number on ADDRESS_MAP line)
      set bmm_data ""
      set bmm_missing ""
      set index 0
      set bmm_id 100
      foreach mcs_instance $mcs_instances {
        set mcs_xco_filename  [lindex $mcs_instance 0]
        set mcs_instance_name [lindex $mcs_instance 1]
        set dir               "[file dirname $mcs_xco_filename]"
        set bmm_filename      "[file join $dir "${mcs_instance_name}.bmm"]"
        if {[file exist $bmm_filename]} {
          set bmm_file [open $bmm_filename "r"]
          set bmm_file_data [read $bmm_file]
          append bmm_data \
            [regsub {MICROBLAZE-LE 100} $bmm_file_data "MICROBLAZE-LE $bmm_id"]
          set bmm_id [expr $bmm_id + 100]
          close $bmm_file
        } else {
          append bmm_missing "${mcs_instance_name}, "
        }
        incr index
      }

      if {[string length $bmm_missing] != 0} {
        set bmm_missing [string trimright $bmm_missing ", "]
        puts "$procname: ERROR: Could not find a BMM file for ${bmm_missing}. Please regenerate the MicroBlaze MCS instances."
        return
      }

      # Determine merged BMM file name
      set mcs_bmm_basename "microblaze_mcs_merged"
      set mcs_bmm_filepath "[file join $projdir ${mcs_bmm_basename}.bmm]"

      # Check if merged BMM file already exists
      set bmm_file_data ""
      if {[file exist $mcs_bmm_filepath]} {
        set bmm_file [open $mcs_bmm_filepath "r"]
        gets $bmm_file
        set bmm_file_data [read $bmm_file]
        close $bmm_file
      }

      # Output merged data on project directory level, if not found or changed
      if {$bmm_file_data != $bmm_data} {
        set bmm_file [open $mcs_bmm_filepath "w"]
        set date [clock format [clock seconds]]
        puts $bmm_file "// Automatically generated by \"microblaze_mcs_setup.tcl\" on $date"
        puts -nonewline $bmm_file $bmm_data
        close $bmm_file
        if {[file exist $mcs_bmm_filepath]} {
          puts "$procname: Modified \"${mcs_bmm_basename}.bmm\"."
        } else {
          puts "$procname: Created \"${mcs_bmm_basename}.bmm\"."
        }
      } else {
        puts "$procname: Existing \"${mcs_bmm_basename}.bmm\" unchanged."
      }
    } else {

      # Determine BMM file name for single instance
      set mcs_xco_filename [lindex [lindex $mcs_instances 0] 0]
      set mcs_bmm_basename [lindex [lindex $mcs_instances 0] 1]
      set dir              "[file dirname $mcs_xco_filename]"
      set mcs_bmm_filepath "[file join $dir "${mcs_bmm_basename}.bmm"]"
      if {! [file exist $mcs_bmm_filepath]} {
        puts "$procname: ERROR: Could not find a BMM file for ${mcs_bmm_basename}. Please regenerate the MicroBlaze MCS instance."
        return
      }
    }

    # Determine new ngdbuild "-bm" option
    if {[mcs_using_planahead]} {
      set new_option "-bm \"$mcs_bmm_filepath\""
    } else {
      set mcs_bmm_relpath [regsub "${projdir}\[\\\/\]" "$mcs_bmm_filepath" {}]
      set new_option "-bm \"$mcs_bmm_relpath\""
    }

    # Get current ngdbuild options
    set options [mcs_get_options "Ngdbuild"]

    # Strip and extract current ngdbuild "-bm" option
    regsub {\-bm[^-]*} $options {} stripped_options
    regsub {.*?(-bm[^-]).*} $options {\1} bm_option

    # Set the ngdbuild "-bm" option if it has been modified
    if {$new_option != $bm_option} {
      set options [string trim "$stripped_options $new_option"]
      if {[mcs_using_planahead]} {
        set run [current_run -quiet]
        config_run $run \
          -quiet -program ngdbuild -option {More Options} -value $options
      } else {
        project set {Other Ngdbuild Command Line Options} $options
      }
      puts "$procname: Added \"-bm\" option for \"${mcs_bmm_basename}.bmm\" to ngdbuild command line options."
    } else {
      puts "$procname: Existing ngdbuild \"-bm\" option unchanged."
    }

    puts "$procname: Done."
  }

  # Handle MicroBlaze MCS ELF files: Run data2mem and set bitgen options
  proc microblaze_mcs_data2mem {args} {
    set procname "microblaze_mcs_data2mem"

    # Find all MicroBlaze MCS instances in the project
    set mcs_instances [mcs_find_instances]
    set mcs_instances_length [llength $mcs_instances]
    set cores "cores"
    if {$mcs_instances_length == 1} { set cores "core" }
    puts "$procname: Found $mcs_instances_length MicroBlaze MCS ${cores}."

    if {$mcs_instances_length == 0} {
      return
    }

    # Check arguments
    if {[llength $args] > $mcs_instances_length} {
      puts "$procname: ERROR: Too many arguments. At most $mcs_instances_length ELF files should be given."
      return
    }

    # Determine device name
    if {[mcs_using_planahead]} {
      set device_name [get_property "part" [current_project]]
    } else {
      set device [project get "Device"]
      set pack   [project get "Package"]
      set speed  [project get "Speed"]
      set device_name "${device}${pack}${speed}"
    }

    # Determine project directory
    if {[mcs_using_planahead]} {
      set projdir [get_property "directory" [current_project]]
    } else {
      set projdir [pwd]
    }

    # Find BMM file
    if {$mcs_instances_length > 1} {
      set mcs_bmm_basename    "microblaze_mcs_merged"
      set mcs_bmm_filepath    "[file join $projdir ${mcs_bmm_basename}.bmm]"
      set mcs_bd_bmm_filepath "[file join $projdir ${mcs_bmm_basename}_bd.bmm]"
      if {! [file exist $mcs_bmm_filepath]} {
        puts "$procname: ERROR: Could not find $mcs_bmm_basename.bmm. Please invoke \"microblaze_mcs_setup\" and implement the design."
        return
      }
    } else {
      set mcs_xco_filename    [lindex [lindex $mcs_instances 0] 0]
      set mcs_bmm_basename    [lindex [lindex $mcs_instances 0] 1]
      set dir                 "[file dirname $mcs_xco_filename]"
      set mcs_bmm_filepath    "[file join $dir "${mcs_bmm_basename}.bmm"]"
      set mcs_bd_bmm_filepath "[file join $dir ${mcs_bmm_basename}_bd.bmm]"
      if {! [file exist $mcs_bmm_filepath]} {
        puts "$procname: ERROR: Could not find $mcs_bmm_basename.bmm. Please regenerate the MicroBlaze MCS instance."
        return
      }
    }

    # Create data2mem commands and bitgen "-bd" options
    set bootloop_elf "mb_bootloop_le.elf"
    set data2mem_cmd "-p $device_name"
    set data2mem_bit "$data2mem_cmd -bm \"${mcs_bd_bmm_filepath}\""
    set data2mem_sim "$data2mem_cmd -bm \"${mcs_bmm_filepath}\""
    set msg_list     {}
    set new_options   ""

    foreach mcs_instance $mcs_instances arg $args {
      set mcs_xco_filename  [lindex $mcs_instance 0]
      set mcs_instance_name [lindex $mcs_instance 1]
      set mcs_xco_dir       "[file dirname $mcs_xco_filename]"
      set bmm_filename      "[file join $mcs_xco_dir "${mcs_instance_name}.bmm"]"

      # Use boot loop if no ELF file argument given
      if {$arg == ""} {
        set arg "[file join $mcs_xco_dir $bootloop_elf]"
      }

      # Check if ELF file exists
      if {! [file exists $arg]} {
        puts "$procname: ERROR: Could not find \"$arg\". Please make sure the file exists."
        return
      }

      # Check if file is an ELF file (only allow .elf extension)
      if {[file extension $arg] != ".elf"} {
        puts "$procname: ERROR: \"$arg\" is not an ELF file."
        return
      }

      # Must use absolute paths
      if {[mcs_using_planahead] && [file pathtype $arg] == "relative"} {
        set arg "[file join $projdir $arg]"
      }

      # Add message
      set tail [file tail $arg]
      if {$tail == $bootloop_elf} {
        lappend msg_list "$procname: Using bootloop for ${mcs_instance_name}"
      } else {
        lappend msg_list "$procname: Using \"$tail\" for ${mcs_instance_name}"
      }

      append new_options " -bd \"$arg\" tag $mcs_instance_name"
    }
    append data2mem_bit $new_options
    append data2mem_sim $new_options
    set new_options [string trimleft $new_options]

    foreach msg $msg_list {
      puts $msg
    }

    if {[mcs_using_planahead]} {
      set run    [current_run -quiet]
      set rundir [get_property directory $run]
      set top    [get_property top [current_fileset] -quiet]
      set bit_basename "[file join $rundir ${top}]"

      # Create default project_1.sim/sim_1 simulation directory
      set name [get_property name [current_project]]
      set simdir "[file join ${projdir} ${name}.sim sim_1]"
      file mkdir $simdir

      append data2mem_sim " -bx \"$simdir\""
    } else {
      set bit_basename "[project get {Output File Name}]"
      append data2mem_sim " -bx ."
    }
    set bit_filename "${bit_basename}.bit"
    set bitout_filename "${bit_basename}_out.bit"
    append data2mem_bit " -bt \"$bit_filename\" -o b \"$bitout_filename\""
    append data2mem_sim " -u"

    # Get current bitgen options
    set options [mcs_get_options "Bitgen"]

    # Strip and extract current bitgen "-bd" options
    regsub -all {\-bd[^-]*} $options {} stripped_options
    regsub {.*?(-bd[^-])} $options {\1} bd_options

    # Set the bitgen "-bd" options if they have changed
    set bitfile_exists [file exists $bit_filename]
    if {$new_options != $bd_options} {
      set options [string trim "$stripped_options $new_options"]
      if {[mcs_using_planahead]} {
        if {! $bitfile_exists} {
          set_property -quiet add_step Bitgen $run
        }
        config_run $run \
          -quiet -program bitgen -option {More Options} -value $options
      } else {
        project set {Other Bitgen Command Line Options} $options
      }
      puts "$procname: Added \"-bd\" options to bitgen command line."
    } else {
      puts "$procname: Existing bitgen \"-bd\" options unchanged."
    }

    # Run data2mem to generate simulation files
    set data2mem_exe [auto_execok "data2mem"]
    puts "$procname: Running \"data2mem\" to create simulation files."
    eval exec $data2mem_exe $data2mem_sim

    # Run data2mem if bitstream and updated BMM exist
    if {! $bitfile_exists} {
      puts "$procname: Bitstream does not exist. Not running \"data2mem\" to update bitstream."
    } elseif {! [file exist $mcs_bd_bmm_filepath]} {
      puts "$procname: The file \"${mcs_bmm_basename}_bd.bmm\" does not exist. Not running \"data2mem\" to update bitstream."
    } else {
      puts "$procname: Running \"data2mem\" to update bitstream with software."
      eval exec $data2mem_exe $data2mem_bit

      # Replace original bitstream with data2mem output bitstream
      if {[file exists ${bitout_filename}]} {
        file copy -force "${bitout_filename}" "${bit_filename}"
        file delete -force "${bitout_filename}"
      }
    }

    puts "$procname: Done."
  }

  # Add help for Project Navigator
  if {! [mcs_using_planahead]} {
    if {[array names ::xilinx::short_help microblaze_mcs] == ""} {
      set ::xilinx::short_help(microblaze_mcs) {Information about MicroBlaze MCS IP specific commands}
      set ::xilinx::task_lib(microblaze_mcs) libTclTaskObject

      proc ::xilinx::microblaze_mcs {args} {
        set hlp ""
        if {[llength $args] == 1 && [lindex $args 0] == "-help"} {
          set hlp "
Tcl command: microblaze_mcs_setup \(perform MicroBlaze MCS specific setup\):

  The microblaze_mcs_setup command is used to create a merged BMM file,
  which defines the local memory of all MicroBlaze MCS instances in the
  project \(if more than one instance), and set Translate process properties
  to add the \"-bm\" option indicating the used BMM file.

  The command should be invoked before running implementation, but after
  the MicroBlaze MCS instance has been generated. It is automatically
  invoked when sourcing the \"microblaze_mcs_setup.tcl\" script.

Tcl command: microblaze_mcs_data2mem \(update bit stream with software\):

  The microblaze_mcs_data2mem command is used to update the bit stream
  with one or more ELF files \(software programs\) given as arguments,
  generate corresponding MEM files for simulation, and set Bitgen process
  properties to add the \"-bd\" option indicating the ELF files.

  If no argument is given, the bit stream is updated with the microblaze
  boot loop ELF file, which ensures that the processor executes an infinite
  loop.

  The procedure should be invoked after the system has been implemented. It
  must also be invoked again when an ELF file name is changed, or when the
  content of an ELF file is changed. If the system is reimplemented without
  changing the software, the procedure need not be invoked again, due to the
  Bitgen \"-bd\" option.
"
        }
        set hlp
      }
    }
  }

  namespace export microblaze_mcs_setup microblaze_mcs_data2mem
}

namespace import microblaze_mcs::microblaze_mcs_setup microblaze_mcs::microblaze_mcs_data2mem

# Call the microblaze_mcs_setup procedure
microblaze_mcs_setup

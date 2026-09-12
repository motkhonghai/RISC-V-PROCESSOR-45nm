# pragma protect
# pragma protect begin
file delete coeGenusHelpers.tcl
### Helper procs
namespace eval coeGenus {
  set verboseSlackDiffReportDiscrepancyThreshold 80
  set genusSkipRedundantLibEstablishEnabled 0
  set genusMMMCEnabled 0
  set genusMMMCPowerDomain 1
  set genusPhysicalSetupEnabled 0
  set genusForceInterconnectMode 3
  set genusFloorplanWidth 200.0
  set genusFloorplanHeight 201.4
  set genusFloorplanSite CoreSite
  set genusNumOfRoutingLayer 11
  set genusFullStructuringMask 4
  set genusNoSeqTilingPenaltyMask 4
  set genusPreferComplexSeqMask 0
  set genusOptimizeNetAreaMask 0
  set genusUseWeightedPower 0
  set genusForceWriteDb 0
  set genusRemapAlways 0
  set genusPowerRestructRemapAlways 0
  set genusPowerModeZeroSlackMask 2
  set prePlaceWireLengthSlope 1.9
  set prePlaceWireLengthY0 2
  set prePlaceResScaleFactor 1
  set prePlaceCapScaleFactor 1
  set prePlaceFanoutPenalty 0
  set prePlaceFanoutThreshold 10
  set prePlaceSiteSize 1.91
  set genusEnableGTAMask 0
  set enableGateCompInPowerCRR 0
  set genusDesignTechNode unspecified
  set genusDesignProcessNode 45
  set genusAdvancedCRR 0
  set genusAdvancedCRRTat 0
  set genusAdvancedCRRGenusTat 0
  set genusAdvancedStructuring 0
  set genusSetRootPin 0

  set totalTime 0
  set localTime 0
  set workerId 0
  set batchId "-"
  set batchCount 0
  set ppid 0
  set minMajorVersion "<set on-the-fly>"
  set usableCells {}
  set dontUseCells {}
  set saveWorkersCmd 0
  set profileWorkers 0
  set profileCommandsPeriod 0; # 0 means only at the end
  set initCmdOutput "<undefined>"
  set readLefOutput "<undefined>"
  set moveImproved 1
  set resultValid 1
  set otherProfileCommands {}
  array set profileCommands {}
  array set eff_use_groups {}
  array set eff_dont_use_groups {}
  set mainPipe -1
  set inPipe -1
  set outPipe -1
  set libsRead 0
  set gcompDynFix 0
  set powerModeSpeedup 0
  set WDR_RunLog ""
  set WDR_GateLocFile ""
  set WDR_NetWLFile ""
  set WDR_Verb 0
  set WDR_WinRatio 1
  set congReclaimSessionId 0
  set netLenBefore 0
  set netLenAfter 0
  array set modifiedAttributes {}
  proc showMsg {msg} {
    variable outPipe
    if {$outPipe > 0} {
      puts $outPipe $msg
      flush $outPipe
    }
    puts $msg
    flush stdout
  }
  proc tentative_set_attr {attr value object} {
    set saved_errorInfo $::errorInfo
    if {[catch {legacy::set_attribute $attr $value $object} msg]} {
      puts "Info: tentative 'set_attr $attr $value $object' handled."
      puts "(ignored) $msg $::errorInfo"
      set ::errorInfo $saved_errorInfo
      return 0
    }
    variable modifiedAttributes
    set modifiedAttributes($attr) $value
    return 1
  }
  proc tentative_reset_attr {attr object} {
    set saved_errorInfo $::errorInfo
    if {[catch {legacy::reset_attribute $attr $object} msg]} {
      puts "Info: tentative 'reset_attr $attr $object' handled."
      puts "(ignored) $msg $::errorInfo"
      set ::errorInfo $saved_errorInfo
      return 0
    }
    return 1
  }
  proc dumpAttributes {} {
    set saved_errorInfo $::errorInfo
    variable modifiedAttributes
    puts "Modified attributes current value:"
    foreach attr [array names modifiedAttributes] {
      if {[catch {set value [::legacy::get_attribute $attr /]} msg]} {
        puts "(ignored) $msg $::errorInfo"
        set ::errorInfo $saved_errorInfo
        continue
      }
      puts "  $attr = $value"
    }
  }
  variable runtime_offset 0
  proc setRuntimeOffset {last} {
    variable runtime_offset [expr {$last - [::legacy::get_attribute runtime]}]
    puts "DEBUG: runtime_offset = $runtime_offset (last=$last)"
  }
  proc getRuntime {} {
    variable runtime_offset
    return [expr {[::legacy::get_attribute runtime] + $runtime_offset}]
  }
  proc beginBatch {id} {
    #reserve_ST_cpu: no need
    variable batchId $id
    variable batchCount
    variable totalTime [getRuntime]
    variable localTime $totalTime
    variable genusMMMCEnabled
    incr batchCount
    if {$genusMMMCEnabled} {
      if {[catch {reset_only_design} msg]} {
        puts "(ignored) $msg $::errorInfo"
     } 
    } else {
      get_read_files -quiet -clear read_netlist
      get_read_files -quiet -clear read_sdc
      if {[catch {delete_obj design:top} msg]} {
        puts "(ignored) $msg $::errorInfo"
      }
    }
    set ::errorInfo ""
    variable moveImproved 1
    variable resultValid 1
  }
  proc endBatch {what} {
    variable batchId
    variable totalTime [getRuntime]
    variable localTime
    variable profileCommandsPeriod
    set delta [expr {$totalTime - $localTime}]
    showMsg "$what $batchId elapse: $delta seconds, total: $totalTime seconds (status [getBatchStatus])"
    if {$profileCommandsPeriod > 1} {
      variable batchCount
      if {[expr {($batchCount % $profileCommandsPeriod) == 0}]} {
        reportProfiledCommands
      }
    }
    #release_ST_cpu: no need
  }
  proc beginProfile {id} {
    variable profileWorkers
    if {$profileWorkers > 0} {
      variable saveWorkersCmd 1
      ::legacy::set_attribute profile_output_filename "genusWorker_${id}_prof.html" / 
      ::legacy::set_attribute dump_stack_trace $profileWorkers / 
    }
  }
  proc endProfile {} {
    variable profileWorkers
    if {$profileWorkers > 0} {
      ::legacy::set_attribute dump_stack_trace 0 / 
      ::legacy::set_attribute profile_output_filename "" /
    }
  }
  proc reportCurrentLibrary {fileName {what ""}} {
    if {$fileName != ""} {
      set fp [open $fileName w]
      foreach msg $what {
        puts $fp $msg
      }
      foreach f [get_db / .library] {
        puts $fp $f
      }
      close $fp
    } else {
      foreach msg $what {
        puts $msg
      }
      puts [get_db / .library]
    }
  }

  proc enableGCompDynFix {level} {
    if {$level > 0} {
      if {$level != 1 || ![tentative_set_attr iopt_gcomp_dyn_pwr_configs true /]} {
        puts "Info: disabling gcomp_dyn trick."
        tentative_set_attr iopt_gcomp_dyn 0 /
      }
    }
  }
  set workerMode "delay"
  set flowMode "logical"
  array set workerDelayModeBackup {
    crr_del_weight_mult ""
    exp_opt_generic_timing_area_aware ""   
    ignore_dynamic_power ""
    incremental_power_engine ""
    iopt_gcomp_dyn ""
    iopt_gcomp_dyn_pwr_configs ""
    iopt_gcomp_use_default_configs ""
    leakage_power_effort ""
    map_crr_full_structuring ""
    map_delay_weight ""
    map_eliminate_oupin_pos_slack ""    
    map_std_gate_power_area_factor ""
    map_use_path_adjust_for_crr_for_pos_paths ""
    map_use_worst_path_model_for_crr ""
    max_crit_del_weight_mult ""
    optimize_net_area ""
    pdr_max_tree_height ""
    pdr_skip_feedthru_buffering ""
    pdr_skip_single_load_drivers ""
    pdr_use_area_budget ""
    reject_power_degradation_in_fl_area ""
    skip_crr_area_structuring ""
    skip_crr_area_struturing ""
    use_signal_activity_for_dynamic_power_opto ""
    use_signal_activity_for_dynamic_power_opto_in_crr ""
    use_tiling_delay_penalty ""
  }
  proc initAreaMode {weight skip_struct} {
    variable workerMode
    variable genusFullStructuringMask
    variable genusNoSeqTilingPenaltyMask 
    variable genusPreferComplexSeqMask
    variable genusOptimizeNetAreaMask
    variable genusEnableGTAMask
    variable genusPhysicalSetupEnabled
    variable flowMode

    saveOrRestoreDelayMode
    puts "Info: worker mode '$workerMode' --> 'area (weight=$weight, skip_struct=$skip_struct)'"
    set workerMode "area"
    if {$flowMode eq "physical" && $genusPhysicalSetupEnabled} {
      reset_db crr_del_weight_mult
    }
    # A mapper control for timing/area tradeoff is map_delay_weight Value 10 can be used for experiments to push mapper hard for area
    legacy::set_attribute map_delay_weight $weight /
    legacy::set_attribute max_crit_del_weight_mult 2 /
    if {![tentative_set_attr map_use_worst_path_model_for_crr false /]} {
      puts "Info: no slack adjustment for worst path model"
    }
    if {![tentative_set_attr map_use_path_adjust_for_crr_for_pos_paths true /]} {
      puts "Info: no slack adjustment for positive paths"
    }
    if {![tentative_set_attr skip_crr_area_structuring $skip_struct /]} {
      puts "Info: using old attribute name with typo 'skip_crr_area_struturing'"
      legacy::set_attribute skip_crr_area_struturing $skip_struct /
    }
    if {[expr {$genusFullStructuringMask & 0x1}]} {
      if {![tentative_set_attr map_crr_full_structuring 1 /]} {
        puts "Info: no full structuring"
      }
    } else {
      tentative_set_attr map_crr_full_structuring 0 /
    }
    if {[expr {$genusNoSeqTilingPenaltyMask & 0x1}]} {
      if {![tentative_set_attr use_tiling_delay_penalty 3 /]} {
        puts "Info: no tiling penalty attribute"
      }
    } else {
      tentative_set_attr use_tiling_delay_penalty 1 /
    }
    if {[expr {$genusPreferComplexSeqMask & 0x1}]} {
      if {![tentative_set_attr map_prefer_complex_seqs true /]} {
        puts "Info: no prefer complex seq attribute"
      }
    } else {
      tentative_set_attr map_prefer_complex_seqs false /
    }
    if {[expr {$genusOptimizeNetAreaMask & 0x1}]} {
      set_db / .optimize_net_area true
    } else {
      set_db / .optimize_net_area false
    }

    if {[expr {$genusEnableGTAMask & 0x1}]} {
      tentative_set_attr exp_opt_generic_timing_area_aware true /
    } else {
      tentative_set_attr exp_opt_generic_timing_area_aware false /
    }
  }
  proc initDpPowerMode {lkg_effort adm weight skip_struct power_gain} {
    variable workerMode
    variable min_power_gain $power_gain
    set $min_power_gain $power_gain
    initPowerMode $lkg_effort $adm $weight $skip_struct
    
    puts "Info: worker mode '$workerMode' --> 'datapath-power (lkg_effort=$lkg_effort, adm=$adm, weight=$weight, skip_struct=$skip_struct)'"
    set workerMode "datapath power"
    
    set_db dp_resynthesis 1
    set_db dp_analytical_opt extreme
  }
  proc initDpAreaMode {weight skip_struct} {
    variable workerMode
    initAreaMode $weight $skip_struct
    
    puts "Info: worker mode '$workerMode' --> 'datapath-area (weight=$weight, skip_struct=$skip_struct)'"
    set workerMode "datapath area"
    
    set_db dp_resynthesis 1
    set_db dp_analytical_opt extreme
  }
  proc initDpDelayMode {} {
    variable workerMode
    restoreDelayMode
    
    puts "Info: worker mode '$workerMode' --> 'datapath-delay'"
    set workerMode "datapath delay"

    set_db dp_resynthesis 1
    set_db dp_analytical_opt extreme
  }
  proc initPowerMode {lkg_effort adm weight skip_struct} {
    variable workerMode
    variable genusFullStructuringMask
    variable genusNoSeqTilingPenaltyMask
    variable genusPreferComplexSeqMask
    variable genusOptimizeNetAreaMask
    variable gcompDynFix
    variable powerModeSpeedup
    variable genusEnableGTAMask
    variable genusPhysicalSetupEnabled
    variable flowMode

    saveOrRestoreDelayMode
    puts "Info: worker mode '$workerMode' --> 'power (lkg_effort=$lkg_effort, adm=$adm, weight=$weight, skip_struct=$skip_struct)'"
    # Leakage Opto:        set_attr leakage_power_effort none/low/medium/high /
    # Dynamic Power Opto:  set_attr max_dynamic_power 0  /designs/*
    # ADM enable           set_attr use_signal_activity_for_dynamic_power_opto 1 /
    # ADM in CRR           set_attr use_signal_activity_for_dynamic_power_opto_in_crr true /
    # If both leakage and dynamic power opto are enabled together, lp_power_optimization_weight must be set to define ratio of dynamic/leakage contribution for total power.
    set workerMode "power"
    if {$flowMode eq "physical" && $genusPhysicalSetupEnabled} {
      reset_db crr_del_weight_mult
    }
    legacy::set_attribute leakage_power_effort $lkg_effort /
    legacy::set_attribute use_signal_activity_for_dynamic_power_opto $adm /
    if {[catch {legacy::set_attribute use_signal_activity_for_dynamic_power_opto_in_crr $adm /} msg]} {
      puts "(ignored) $msg $::errorInfo"
      set ::errorInfo ""
    }
    legacy::set_attribute map_delay_weight $weight /
    legacy::set_attribute max_crit_del_weight_mult 2 /
    if {![tentative_set_attr map_use_worst_path_model_for_crr false /]} {
      puts "Info: no slack adjustment for worst path model"
    }
    if {![tentative_set_attr map_use_path_adjust_for_crr_for_pos_paths true /]} {
      puts "Info: no slack adjustment for positive paths"
    }
    if {![tentative_set_attr skip_crr_area_structuring $skip_struct /]} {
      puts "Info: using old attribute name with typo 'skip_crr_area_struturing'"
      legacy::set_attribute skip_crr_area_struturing $skip_struct /
    }
    if {[expr {$genusFullStructuringMask & 0x2}]} {
      if {![tentative_set_attr map_crr_full_structuring 1 /]} {
        puts "Info: no full structuring"
      }
    } else {
      tentative_set_attr map_crr_full_structuring 0 /
    }
    if {[expr {$genusNoSeqTilingPenaltyMask & 0x2}]} {
      if {![tentative_set_attr use_tiling_delay_penalty 3 /]} {
        puts "Info: no tiling penalty attribute"
      }
    } else {
      tentative_set_attr use_tiling_delay_penalty 1 /
    }
    if {[expr {$genusPreferComplexSeqMask & 0x2}]} {
      if {![tentative_set_attr map_prefer_complex_seqs true /]} {
        puts "Info: no prefer complex seq attribute"
      }
    } else {
      tentative_set_attr map_prefer_complex_seqs false /
    }
    if {[expr {$genusOptimizeNetAreaMask & 0x2}]} {
      set_db / .optimize_net_area true
    } else {
      set_db / .optimize_net_area false
    }
    if {![tentative_set_attr ignore_dynamic_power false /]} {
      puts "Info: no ignore_dynamic_power attribute"
    }
    if {![tentative_set_attr incremental_power_engine joules /]} {
      puts "Info: no incremental_power_engine attribute"
    }
    if {$powerModeSpeedup > 0} {
      if {![tentative_set_attr iopt_gcomp_use_default_configs true /]} {
        puts "Info: no iopt_gcomp_use_default_configs attribute"
      }
      if {$powerModeSpeedup > 1} {
        if {![tentative_set_attr reject_power_degradation_in_fl_area true /]} {
          puts "Info: no reject_power_degradation_in_fl_area attribute"
        }
      }
    }

    if {[expr {$genusEnableGTAMask & 0x2}]} {
      tentative_set_attr exp_opt_generic_timing_area_aware true /
    } else {
      tentative_set_attr exp_opt_generic_timing_area_aware false /
    }

    enableGCompDynFix $gcompDynFix
  }
  proc initPowerADRMode {lkg_effort adm weight skip_struct} {
    initPowerMode $lkg_effort $adm $weight $skip_struct
    variable genusPowerModeZeroSlackMask
    if {![tentative_set_attr pdr_max_tree_height 4 /]} {
      puts "Info: no pdr_max_tree_height attribue"
    }
    if {![tentative_set_attr pdr_use_area_budget true /]} {
      puts "Info: no pdr_use_area_budget attribute"
    }    
    if {![tentative_set_attr pdr_skip_single_load_drivers true /]} {
      puts "Info: no pdr_skip_single_load_drivers attribute"
    }    
    if {![tentative_set_attr pdr_skip_feedthru_buffering true /]} {
      puts "Info: no pdr_skip_feedthru_buffering attribute"
    }    
    if {[expr {$genusPowerModeZeroSlackMask & 0x2}]} {
      if {![tentative_set_attr map_eliminate_oupin_pos_slack true /]} {
        puts "Info: no map_eliminate_oupin_pos_slack attribute"
      }
    }
  }
  proc initUltraPowerMode {lkg_effort adm weight skip_struct} {
    initPowerMode $lkg_effort $adm $weight $skip_struct
    if {![tentative_set_attr map_eliminate_oupin_pos_slack false /]} {
      puts "Info: no map_eliminate_oupin_pos_slack attribute"
    }
  }
  proc initUltraPowerADRMode {lkg_effort adm weight skip_struct} {
    initPowerADRMode $lkg_effort $adm $weight $skip_struct
    if {![tentative_set_attr map_eliminate_oupin_pos_slack false /]} {
      puts "Info: no map_eliminate_oupin_pos_slack attribute"
    }
  }
  proc initLogicalMode {} {
    variable flowMode
    puts "Info: flow mode '$flowMode' --> 'logical'"
    set flowMode "logical"
    # change ple_mode in worker would cause large memory jump for some customers/libraries
    # avoid unnecessary switch
    if { [::legacy::get_attribute ple_mode / ] ne "global" } {
       puts "Info: set ple_mode global"
       legacy::set_attribute ple_mode global /
    }
    variable genusForceInterconnectMode
    if {[expr $genusForceInterconnectMode & 0x11] == 0x11} {
      set_db interconnect_mode wireload
    }
  }
  proc initPhysicalMode {} {
    variable flowMode
    puts "Info: flow mode '$flowMode' --> 'physical'"
    set flowMode "physical"
    if { [::legacy::get_attribute ple_mode / ] ne "cluster" } {
      puts "Info: set ple_mode cluster"
      legacy::set_attribute ple_mode cluster /
    }
    variable genusForceInterconnectMode
    if {[expr $genusForceInterconnectMode & 0x12] == 0x12} {
      set_db interconnect_mode ple
    }
  }
  proc setDesignPowerMode {max_dyn_pwr lkg_to_dyn_ratio} {
    set design [vfind / -design top]
    legacy::set_attribute lp_power_optimization_weight $lkg_to_dyn_ratio $design
    legacy::set_attribute max_dynamic_power $max_dyn_pwr $design
  }
  proc saveOrRestoreDelayMode {} {
    variable workerMode
    if {$workerMode eq "delay"} {
      variable workerDelayModeBackup
      foreach i [array names workerDelayModeBackup] {
        if {[catch {set workerDelayModeBackup($i) [legacy::get_attribute $i /]} msg]} {
          puts "(ignored) $msg $::errorInfo"
          set ::errorInfo ""
          unset workerDelayModeBackup($i)
        }
      }
    } else {
      restoreDelayMode
    }
  }
  proc restoreDelayMode {} {
    variable workerMode
    puts "Info: worker mode '$workerMode' --> 'delay'"
    if {$workerMode ne "delay"} {
      variable workerDelayModeBackup
      set saved_errorInfo $::errorInfo
      foreach i [array names workerDelayModeBackup] {
        if {[catch {legacy::set_attribute $i $workerDelayModeBackup($i) /} msg]} {
          puts "(ignored) $msg $::errorInfo"
          set ::errorInfo $saved_errorInfo
          unset workerDelayModeBackup($i)
        }
      }
      set workerMode "delay"
    }
  }
  proc saveDelayModeByVariable {attr} {
    variable workerDelayModeBackup
    if {[info exists workerDelayModeBackup($attr)]} {
      set oldValue $workerDelayModeBackup($attr)
      set newValue [legacy::get_attribute $attr /]
      if {$oldValue ne $newValue} {
        puts "Info: saving delay mode attribute $attr: '$oldValue' --> '$newValue'"
        set workerDelayModeBackup($attr) $newValue
      }
    }
  }

  array set port2masterSlack {}
  set port2masterSlackRoot ""
  set verboseSlackDiffReportLevel 0
  set allInitialSlackDiscrepancies {}
  proc showInitialSlackDiffReport {portMasterSlack root level} {
    variable port2masterSlack
    variable port2masterSlackRoot $root
    variable verboseSlackDiffReportLevel $level
    variable allInitialSlackDiscrepancies
    array unset port2masterSlack
    array set port2masterSlack {}
    puts "Info: cone of size [get_db [vfind / -design top] .num_insts]"
    foreach {port slack} $portMasterSlack {
      lappend port2masterSlack($port) $slack
    }
    showSlackDiffReport
  }
  proc showSlackDiffReport {} {
    variable port2masterSlack
    variable port2masterSlackRoot
    variable verboseSlackDiffReportLevel
    set total_master 0.0
    set total_diff 0.0
    foreach port [lsort -dictionary [array names port2masterSlack]] {
      if {[catch {set workerSlack [get_db [get_port $port] .net.drivers.slack]} msg]} {
        set workerSlack $msg
      }
      lappend port2masterSlack($port) $workerSlack
    }
    puts "Info: master vs. worker slack report (root=$port2masterSlackRoot) \{"
    foreach port [lsort -dictionary [array names port2masterSlack]] {
      lassign $port2masterSlack($port) master worker
      if {[llength $port2masterSlack($port)] > 2} {
        set last [lindex $port2masterSlack($port) end]
        puts "  $port: $master ==> $worker --> $last"
      } else {
        puts "  $port: $master ==> $worker"
        set total_master [expr {$total_master + abs($master)}]
        set total_diff [expr {$total_diff + abs($master -$worker)}]
      }
    }
    if {$total_master > 0.0} {
      variable verboseSlackDiffReportDiscrepancyThreshold
      set discrepancy [expr {$total_diff * 100.0 / $total_master}]
      puts "  (slack discrepancy: [format "%.2f%%" $discrepancy])"
      if {$discrepancy > $verboseSlackDiffReportDiscrepancyThreshold} {
        set design [vbasename [vfind / -design top]]
        puts "DEBUG: A huge mismatch in slack between innovus and genus"
        catch {debugCatFile "DEBUG: Verilog netlist from innovus" [glob -nocomplain "*/${design}_*.v"]}
        catch {debugCatFile "DEBUG: SDC file from innovus" [glob -nocomplain "*/${design}_*.sdc"]}
      }
    }
    puts "\}"
    if {$verboseSlackDiffReportLevel > 2} {
      catch {report_timing -through $port2masterSlackRoot}
      if {$verboseSlackDiffReportLevel > 4} {
        catch {report_timing -lint}
      }
    }
  }

  proc reportPowerInfo {step powerInfo} {
    set totLeakage 0.0
    set totInternal 0.0
    set totSwitching 0.0
    puts "Info: master power report ($step) \{"
    puts "-------------------------------------------------------"
    puts "            (power report as seen in master)"
    puts "  Leakage    Internal   Switching        Total Instance"
    puts "-------------------------------------------------------"
    set readLeakage -9999.9999
    set readInternal -9999.9999
    set readSwitching -9999.9999
    set readDynamic -9999.9999
    set readTotal -9999.9999
    array set activities {}
    foreach {what value} $powerInfo {
      switch -- $what {
        leakage { set readLeakage $value }
        internal { set readInternal $value }
        switching { set readSwitching $value }
        dynamic { set readDynamic $value }
        total { set readTotal $value }
        default {
          set leakage 0.0
          set internal 0.0
          set switching 0.0
          foreach {pType pVal} $value {
            switch -- $pType {
              lkg { set leakage $pVal }
              int { set internal $pVal }
              swt { set switching $pVal }
              default {
                set pin "$what/$pType"
                foreach {toggleRate prob} $pVal {
                  lappend activities($pin) [format "%.0f" $toggleRate] [format "%.5f" $prob]
                }
              }
            }
          }
          set total [expr {$leakage + $internal + $switching}]
          puts [format "%9.4f %11.4f %11.4f %12.4f %8s" $leakage $internal $switching $total $what]
          set totLeakage [expr {$totLeakage + $leakage}]
          set totInternal [expr {$totInternal + $internal}]
          set totSwitching [expr {$totSwitching + $switching}]
        }
      }
    }
    set total [expr {$totLeakage + $totInternal + $totSwitching}]
    puts "-------------------------------------------------------"
    puts [format "%9.4f %11.4f %11.4f %12.4f Total calc" $totLeakage $totInternal $totSwitching $total]
    puts [format "%9.4f %11.4f %11.4f %12.4f Total read" $readLeakage $readInternal $readSwitching $readTotal]
    puts "-------------------------------------------------------"
    if {[array size activities]} {
      puts "  Toggle rate and probability (as seen in master):"
      foreach pin [lsort -dict [array names activities]] {
        puts "    $pin: $activities($pin)"
      }
    }
    puts "\}"
  }

  array set masterPowerInfo {}
  proc setMasterPowerInfo {step powerInfo} {
    variable masterPowerInfo
    array unset masterPowerInfo
    array set masterPowerInfo {}
    foreach {what value} $powerInfo {
      set masterPowerInfo($what) $value
    }
    if {[catch {reportPowerInfo $step $powerInfo}]} {
      puts "DEBUG: reportPowerInfo failed '$::errorInfo'"
      set ::errorInfo ""
    }
  }
  set verbosePowerDiffReportLevel 0
  set initial_total_power -99999
  set initial_total_power_slack -99999
  proc showInitialPowerDiffReport {powerInfo level} {
    variable verbosePowerDiffReportLevel $level
    variable last_lpwr
    variable last_ipwr
    variable last_npwr
    setMasterPowerInfo "initial" $powerInfo
    showPowerDiffReport "initial"
    variable initial_total_power [expr {$last_lpwr + $last_ipwr + $last_npwr}]
    variable initial_total_power_slack [get_db [vfind / -design top] .slack]
  }
  set last_lpwr -99999
  set last_ipwr -99999
  set last_npwr -99999
  proc showFinalPowerDiffReport {step powerInfo} {
    variable last_lpwr
    variable last_ipwr
    variable last_npwr
    setMasterPowerInfo $step $powerInfo
    showPowerDiffReportInt $step 0 $last_lpwr $last_ipwr $last_npwr
  }
  proc showPowerDiffReport {{step ""}} {
    variable verbosePowerDiffReportLevel
    if {$verbosePowerDiffReportLevel < 4} {
      # workaround to avoid propagating blah-blah messages in report below
      redirect /dev/null {report power}
      puts ""
    }
    set design [vfind / -design top]
    variable last_lpwr [legacy::get_attribute lp_leakage_power $design]
    variable last_ipwr [legacy::get_attribute lp_internal_power $design]
    variable last_npwr [legacy::get_attribute lp_net_power $design]
    showPowerDiffReportInt $step [expr {$verbosePowerDiffReportLevel > 2}] $last_lpwr $last_ipwr $last_npwr
  }
  proc showPowerDiffReportInt {step by_leaf lpwr ipwr npwr} {
    variable masterPowerInfo
    puts "Info: master vs. worker power report ($step) \{"
    if {$by_leaf} {
      #report power -help
      if {[catch {report power -by_leaf_instance}]} {
        puts "DEBUG: report power failed '$::errorInfo'"
        set ::errorInfo ""
      }
      puts "  Computed toggle rate and probability:"
      foreach i [vfind / -pin *] {
        if {![catch {set toggle [legacy::get_attribute lp_computed_toggle_rate $i]; set prob [legacy::get_attribute lp_computed_probability $i]}]} {
          puts "    [vname $i]: [format {%.0f} $toggle] $prob"
        }
      }
    }
    set dpwr [expr {$ipwr + $npwr}]
    set tpwr [expr {$dpwr + $lpwr}]
    lappend masterPowerInfo(leakage) $lpwr
    lappend masterPowerInfo(internal) $ipwr
    lappend masterPowerInfo(switching) $npwr
    lappend masterPowerInfo(dynamic) $dpwr
    lappend masterPowerInfo(total) $tpwr
    foreach what {leakage internal switching total} {
      lassign $masterPowerInfo($what) master worker
      if {[llength $masterPowerInfo($what)] > 2} {
        set last [lindex $masterPowerInfo($what) end]
        puts "  $what: $master ==> $worker --> $last"
      } else {
        puts "  $what: $master ==> $worker"
      }
    }
    set total_master [lindex $masterPowerInfo(total) 0]
    set total_worker [lindex $masterPowerInfo(total) 1]
    if {$step ne "" && $total_master > 0.0} {
      variable verboseSlackDiffReportDiscrepancyThreshold
      set total_diff [expr {$total_worker - $total_master}]
      set discrepancy [expr {$total_diff * 100.0 / $total_master}]
      puts "  (${step} power discrepancy: [format "%.2f%%" $discrepancy])"
      if {[expr {abs($discrepancy)}] > $verboseSlackDiffReportDiscrepancyThreshold} {
        puts "DEBUG: A huge mismatch in power between innovus and genus"
      }
    }
    puts "\}"
  }
  proc getTotalPower {design} {
    set lpwr [legacy::get_attribute lp_leakage_power $design]
    set ipwr [legacy::get_attribute lp_internal_power $design]
    set npwr [legacy::get_attribute lp_net_power $design]
    return [expr {$lpwr + $ipwr + $npwr}]
  }
  proc getTotalDesignPower {} {
    return [getTotalPower [vfind / -design top]]
  }
  proc getTotalWeightedPower {design} {
    set ratio [legacy::get_attribute lp_power_optimization_weight $design]
    set lpwr [legacy::get_attribute lp_leakage_power $design]
    set ipwr [legacy::get_attribute lp_internal_power $design]
    set npwr [legacy::get_attribute lp_net_power $design]
    return [expr {$lpwr * $ratio + (1.0 - $ratio) * ($ipwr + $npwr)}]
  }
  proc getTotalWeightedDesignPower {} {
    return [getTotalWeightedPower [vfind / -design top]]
  }
  proc showPowerCSV {fromMaster} {
    variable initial_total_power
    variable initial_total_power_slack
    set final_total_power [getTotalDesignPower]
    set finitial [format "%.0f" $initial_total_power]
    set ffinal [format "%.0f" $final_total_power]
    set final_total_slack [get_db [vfind / -design top] .slack]
    puts "$fromMaster,genus,$finitial,$ffinal,slack,$initial_total_power_slack,$final_total_slack"
  }

  proc debugCatFile {what fname} {
    puts "$what '$fname' \{"
    if {[file exists $fname]} {
      set f [open $fname "r"]
      puts [read $f]
      close $f
    } else {
      puts "Error: file does not exist."
    }
    puts "\}"
  }

  set origSlack 0
  set rootForSlack "" ; # can be design or port object
  proc getOrigSlack {{outPort {}}} {
    variable rootForSlack
    variable genusSetRootPin
    if {[llength $outPort]} {
      set ph [find_peephole]
      if {[llength $ph]} {
        set rootForSlack [vfind / -hpin $outPort]
      } else {
        set rootForSlack [get_port $outPort]
      }
      if {[get_db $rootForSlack .slack] == inf} {
        set rootForSlack [vfind / -design top]
        tentative_reset_attr sandbox_root_pin_from_innovus /
      } elseif {$genusSetRootPin} {
        tentative_set_attr sandbox_root_pin_from_innovus $outPort /
      }
    } else {
      set rootForSlack [vfind / -design top]
      tentative_reset_attr sandbox_root_pin_from_innovus /
    }
    variable origSlack [get_db $rootForSlack .slack]
  }
  proc writeDbIfMoveImproved {fname} {
    variable moveImproved
    variable genusForceWriteDb
    if {$moveImproved || $genusForceWriteDb } {
      writeDb $fname
    } else {
      # echo "module not_improved();\nendmodule" > $fname
    }    
  }
  proc writeDbIfMuxImproved {fname} {
    variable moveImproved [get_db [vfind / -design top] .revisit_improved]
    writeDbIfMoveImproved $fname
  }
  proc writeDbIfSlackImproved {fname minGain} {
    variable resultValid
    variable genusForceWriteDb
    if {!$resultValid && !$genusForceWriteDb} {
      return
    }
    variable origSlack
    variable rootForSlack
    set newSlack [get_db $rootForSlack .slack]
    variable moveImproved [expr {$newSlack == inf || ($origSlack != inf && ($newSlack - $origSlack) >= $minGain)}]
    variable genusPhysicalSetupEnabled
    variable flowMode
    if {$flowMode eq "physical" && $genusPhysicalSetupEnabled} {
      variable moveImproved true
    }
    puts "DEBUG: slack $origSlack --> $newSlack (improved = $moveImproved)"
    writeDbIfMoveImproved $fname
  }
  set origPower 0
  proc getOrigPower {} {
    variable genusUseWeightedPower
    if {$genusUseWeightedPower} {
      variable origPower [getTotalWeightedDesignPower]
    } else {
      variable origPower [getTotalDesignPower]
    }
  }
  proc writeDbIfPowerImproved {fname minGain} {
    variable resultValid
    variable genusForceWriteDb
    if {!$resultValid && !$genusForceWriteDb } {
      return
    }
    variable origPower
    variable genusUseWeightedPower
    if {$genusUseWeightedPower} {
      set newPower [getTotalWeightedDesignPower]
    } else {
      set newPower [getTotalDesignPower]
    }
    variable moveImproved [expr {($origPower - $newPower) >= $minGain}]
    puts "DEBUG: power $origPower --> $newPower (improved = $moveImproved)"
    writeDbIfMoveImproved $fname
  }
  set origArea 0
  proc getOrigArea {} {
    variable origArea [get_db [vfind / -design top] .insts_area]
  }
  proc writeDbIfAreaImproved {fname minGain checkPower} {
    variable resultValid
    variable genusForceWriteDb
    if {!$resultValid && !$genusForceWriteDb } {
      return
    }
    set pwrMaintained 1
    if {$checkPower} {
      variable origPower
      set newPower [getTotalWeightedDesignPower]
      set pwrMaintained [expr {($origPower - $newPower) >= 0}]
      puts "DEBUG: power $origPower --> $newPower (maintained = $pwrMaintained)"
    }
    variable origArea
    set newArea [get_db [vfind / -design top] .insts_area]
    variable moveImproved [expr {(($origArea - $newArea) >= $minGain) && $pwrMaintained}]
    puts "DEBUG: area $origArea --> $newArea (improved = $moveImproved)"
    writeDbIfMoveImproved $fname
  }
  proc writeDbIfHasMOG {fname} {
    variable resultValid
    variable genusForceWriteDb
    if {!$resultValid && !$genusForceWriteDb } {
      return
    }
    variable moveImproved [hasMOG]
    puts "DEBUG: hasMOG = $moveImproved"
    writeDbIfMoveImproved $fname
  }
  proc find_peephole {} {
    set ph [vfind / -module *]
    if {[llength $ph]} {
      set ph [lsearch -inline -all -not  $ph *state_point*]
      if {[llength $ph] > 1} {
        set hi [vfind / -maxdepth 4 -hinst *]
        set ph [get_db $hi .module]
      }
    }
    return $ph
  }
  proc writeDb {fname} {
    variable resultValid
    if {$resultValid} {
      set ph [find_peephole]
      if {[llength $ph]} {
        write_hdl -depth 0 $ph > $fname
      } else {
        write_hdl -depth 0 > $fname
      }
    }
  }
  proc writeDef {fname} {
    file delete -force $fname
    set rst [open $fname w]
    set ph [vfind / -module *]
    if {[llength $ph]} {
      foreach inst [vfind inst:top/ph/*] {
        set name [get_db $inst .base_name]
        set x [get_db $inst .location_x]
        set y [get_db $inst .location_y]
        puts $rst "$name $x $y"
      }
    } else {
      foreach inst [vfind inst:top/*] {
        set name [get_db $inst .name]
        set x [get_db $inst .location_x]
        set y [get_db $inst .location_y]
        puts $rst "$name $x $y"
      }
    }
    close $rst
  }
  proc getNetLengthFromRpt {} {
    ## report_qor > rpt
    ## Total Net Length                   856.41 um
    ## {Total Net Length\s+(.*)\s+um.*}
    ## np_report_qor -to_file rpt
    ## Wirelen: 8.5573e+02(um) Overlap: 0.238
    ## {Wirelen:\s+(.*)\(um\) .*}
    variable WDR_NetWLFile
    if {$WDR_NetWLFile == ""} {
      return
    }
    set rptFile "${WDR_NetWLFile}_tmpNL_"
    file delete -force ${rptFile}
    ##report_qor > ${rptFile}
    np_report_qor -to_file ${rptFile}
    set netLen ""
    set rdFile [open "${rptFile}" r]
    while {![eof $rdFile]} {
      set line [gets $rdFile]
      if {[regexp {Wirelen:\s+(.*)\(um\).*} $line fstr len_num]} {
        set netLen $len_num
        break
      }
    }
    close $rdFile
    file delete -force $rptFile
    if {$netLen == ""} {
      puts "No valid WL number in report file"
      set netLen 0.0
    }
    return $netLen
  }
  proc writeDbIfWDRWLImproved {fname forceAccept} {
    variable moveImproved 0
    variable WDR_RunLog
    variable WDR_GateLocFile
    variable WDR_NetWLFile
    variable netLenBefore
    variable netLenAfter
    if {$WDR_GateLocFile != "" && [file exists $WDR_GateLocFile]} {
      set instNum 0
      puts "WDR: Find gate change file $WDR_GateLocFile"
      set rst [open $WDR_GateLocFile r]
      set line [gets $rst]
      if {[regexp {^## module top changed list total (\d+) instances.*} $line fstr instNum]} {
        if {$instNum > 0} {
          puts "WDR: Total $instNum new gates."
          set moveImproved 1
        } else {
          puts "WDR: No new gate."
        }
      }
      close $rst
      if {$forceAccept} {
        set moveImproved 1
      }
      if {!$moveImproved} {
        file delete -force $WDR_GateLocFile
      }
    } 
    if {$moveImproved} {
      ## WDR run log extraction
      set totalNum 0
      set optNum 0
      set origLen 0
      set optLen 0
      if {$WDR_RunLog != "" && [file exists $WDR_RunLog]} {
        set rdFile [open "${WDR_RunLog}" r]
        while {![eof $rdFile]} {
          set line [gets $rdFile]
          if {[regexp {^LogicTree: identified (\d+) (tree|trees) \((\d+) optimized, .*} $line fstr Num1 treeWord Num2]} {
            Puts "WDR: Total trees $Num1 optimized $Num2"
            set totalNum $Num1
            set optNum $Num2
            continue
          }
          if {[regexp {^LogicTree: achieved\s+(.*)% wire length reduction on (this tree|these trees) from (\d+) um to (\d+) um\..*} $line fstr impPercent treeWord Len1 Len2]} {
            Puts "WDR: WL Imp all: ${impPercent}% $Len1 -> $Len2"
            continue
          }
          if {[regexp {^\s+achieved\s+(.*)% wire length reduction on \d+ optimized (tree|trees) from (\d+) um to (\d+) um\..*} $line fstr impPercent treeWord Len1 Len2]} {
            Puts "WDR: WL Imp opt: ${impPercent}% $Len1 -> $Len2"
            set origLen $Len1
            set optLen $Len2
            break
          }
        }
        close $rdFile
      } else {
        puts "WDR: No run log: $WDR_RunLog"
      }
      puts "Total net length before $netLenBefore after $netLenAfter"
      if {$WDR_NetWLFile != ""} {
        file delete -force $WDR_NetWLFile
        set nwl [open $WDR_NetWLFile w]
        puts $nwl "# Tree improvement summary from WDR run"
        puts $nwl "WDR run summary: total $totalNum optimized $optNum OrigLen $origLen OptLen $optLen"
        puts $nwl "# Net wire length from report_qor"
        puts $nwl "Total net length before $netLenBefore after $netLenAfter"
        close $nwl
      }
      writeDb $fname
    } else {
      puts "WDR: No WL Improvement."
      # echo "module not_improved();\nendmodule" > $fname
    }
  }
  proc preserve_feed_thru_nets {} {
    if {![llength [vfind / -module *]]} {
      set fports [vfind / -port f*]
      if {[llength $fports]} {
        puts "Info: preserving the nets of [llength $fports] feed-thru ports."
        ::legacy::set_attribute preserve true [get_db $fports .net]
      }
    }
  }
  proc preserve_nested_hierachies {} {
    if {[llength [vfind / -module *]] > 1} {
      set_db [vfind / -mindepth 5 -hinst *] .preserve true
    }
  }
  proc preserve_outer_shell {} {
    if {[llength [vfind / -module *]]} {
      set_db [vfind /top -maxdepth 2 -hnet *] .preserve true
    }
  }
  proc preserveAllInsts {flavor} {
    set insts [vfind / -inst *]
    if {[llength $insts]} {
      ::legacy::set_attribute preserve $flavor $insts
    }
  }
  proc crr_or_map_def_cmd {args} {
    variable genusRemapAlways
    if { $genusRemapAlways } {
       append args " -remap_always"
    }
    variable genusPhysicalSetupEnabled
    variable flowMode
    if {$flowMode eq "physical" && $genusPhysicalSetupEnabled} {
      append args " -spatial"
    }
    variable skip_map_def
    set ok 0
    if {!$skip_map_def && [llength [vfind / -module *]]} {
      set ok [eval crr_map_def $args]
      if {!$ok && !$skip_map_def} {
        puts "Warning: 'crr_map $args' returned 0; trying map..."
        lappend reduced_args
        foreach i $args {
          if {![regexp -- {-(spatial|remap_always|use_crr_gst|use_crr_shell)} $i]} {
            lappend reduced_args $i
          }
        }
        set ok [eval map_def $reduced_args]
      }
    } else {
      set ok [eval crr_map_def $args]
    }
    puts "Info: crr_or_map_def_cmd returns [list $ok]"
    return $ok
  }
  proc crr_map {} {
    set design [vfind / -design top]
    variable resultValid [crr_or_map_def_cmd $design]
  }
  proc crr_map_use_crr_gst {} {
    set design [vfind / -design top]
    if {[get_attribute_status glo_crr_gst -type root]} {
      variable resultValid [crr_or_map_def_cmd -use_crr_gst $design]
    } else {
      variable resultValid [crr_or_map_def_cmd $design]
    }
  }
  proc crr_retime_map {} {
    set design [vfind / -design top]
    set old_val [get_db $design .retime]
    set_db $design .retime true
    set_db [get_db insts * -if {.is_flop} ] .trace_retime true
    set_db [get_db insts * -if {.is_combinational}] .preserve size_ok
    check_dft_rules
    _synthesize_private -to_generic -effort medium
    preserve_feed_thru_nets
    _synthesize_private -to_mapped -no_incr -effort high
    set_db $design .retime $old_val
  }
  proc crr_retime {} {
    set_db [get_db insts * -if {.is_flop} ] .trace_retime true
    set_db [get_db insts * -if {.is_combinational}] .preserve size_ok
    set soList [vfind / -hport so*]
    if {[llength $soList]} {
      puts "disconnect $soList"
      disconnect $soList
    }
    set soList [vfind / -hpin so*]
    if {[llength $soList]} {
      puts "disconnect $soList"
      set_db [get_nets -of_objects $soList] .preserve false
      disconnect $soList
      preserve_outer_shell
    }
    check_dft_rules
    set ph [vfind / -module *]
    if {[llength $ph]} {
      foreach m $ph {
        retime -prepare -min_delay $m
      }
    } else {
      preserve_feed_thru_nets
      retime -prepare -min_delay
    }
  }
  proc crr_map_use_crr_shell {} {
    set design [vfind / -design top]
    variable genusPhysicalSetupEnabled
    variable flowMode
    if {$flowMode eq "physical" && $genusPhysicalSetupEnabled} {
      variable resultValid [crr_map_def -use_crr_shell -spatial $design]
    } else {
      variable resultValid [crr_map_def -use_crr_shell $design]
    }
  }
  proc crr_map_and_worse_tns_polish {} {
    # TODO: remove fluff (puts, unnecessary get_db) if ever made a recipe
    set design [vfind / -design top]
    set slk_before [get_db $design .slack]
    set tns_before [get_db $design .tns]
    variable resultValid [crr_or_map_def_cmd $design]
    set slk_after [get_db $design .slack]
    set tns_after [get_db $design .tns]
    if {($slk_before > $slk_after && $slk_after < 0) || $tns_before < $tns_after} {
      puts "Info: Slack/TNS $slk_before/$tns_before --> $slk_after/$tns_after triggers TNS polish."
      preserve_feed_thru_nets
      FL_TnsOptimize
      set slk_after [get_db $design .slack]
      set tns_after [get_db $design .tns]
    }
    puts "Info: Summary Slack/TNS $slk_before/$tns_before --> $slk_after/$tns_after"
  }
  proc crr_map_and_worse_power_polish {} {
    # TODO: remove fluff (puts, unnecessary get_db) if ever made a recipe
    set design [vfind / -design top]
    set power_before [getTotalWeightedPower $design]
    variable resultValid [crr_or_map_def_cmd $design]
    set power_after [getTotalWeightedPower $design]
    if {$power_before < $power_after} {
      puts "Info: Power $power_before --> $power_after triggers power polish."
      FL_AreaPowerOptimize
      set power_after [getTotalWeightedPower $design]
    }
    puts "Info: Summary Power $power_before --> $power_after"
  }
  proc crr_map_and_worse_power_tns_polish {} {
    # TODO: remove fluff (puts, unnecessary get_db) if ever made a recipe
    set design [vfind / -design top]
    set power_before [getTotalWeightedPower $design]
    set slk_before [get_db $design .slack]
    set tns_before [get_db $design .tns]
    variable resultValid [crr_or_map_def_cmd $design]
    set slk_after [get_db $design .slack]
    set tns_after [get_db $design .tns]
    if {($slk_before > $slk_after && $slk_after < 0) || $tns_before < $tns_after} {
      puts "Info: Slack/TNS $slk_before/$tns_before --> $slk_after/$tns_after triggers TNS polish."
      preserve_feed_thru_nets
      FL_TnsOptimize
      set slk_after [get_db $design .slack]
      set tns_after [get_db $design .tns]
    }
    set power_after [getTotalWeightedPower $design]
    if {$power_before < $power_after} {
      if {($slk_before <= $slk_after || $slk_after > 0) || $tns_before >= $tns_after} {
        puts "Info: Power $power_before --> $power_after triggers power polish."
        FL_AreaPowerOptimize
        set power_after [getTotalWeightedPower $design]
        set slk_after [get_db $design .slack]
        set tns_after [get_db $design .tns]
      } else {
        puts "Info: Power $power_before --> $power_after, but power polish skipped because timing is already also worse."
      }
    }
    puts "Info: Summary Power/Slack/TNS $power_before/$slk_before/$tns_before --> $power_after/$slk_after/$tns_after"
  }
  proc crr_map_and_worse_power_tns_polish_lean {} {
    set design [vfind / -design top]
    set power_before [getTotalWeightedPower $design]
    set slk_before [get_db $design .slack]
    set tns_before [get_db $design .tns]
    variable resultValid [crr_or_map_def_cmd $design]
    set slk_after [get_db $design .slack]
    set tns_after [get_db $design .tns]
    if {($slk_before > $slk_after && $slk_after < 0) || $tns_before < $tns_after} {
      preserve_feed_thru_nets
      FL_TnsOptimize
    }
    set power_after [getTotalWeightedPower $design]
    if {$power_before < $power_after} {
      if {($slk_before <= $slk_after || $slk_after > 0) || $tns_before >= $tns_after} {
        FL_AreaPowerOptimize
      }
    }
  }
  proc crr_map_shell_and_worse_power_tns_polish_lean { do_remap_always } {
    set design [vfind / -design top]
    tentative_set_attr map_crr_full_structuring 1 /
    tentative_set_attr power_weight_pct_in_medium_effort_mode 40 /

    set power_before [getTotalWeightedPower $design]
    set slk_before [get_db $design .slack]
    set tns_before [get_db $design .tns]

    tentative_set_attr align_envx_next_id 1 /
    tentative_set_attr glo_power_restructure 1 /
    set crr_refine_mapping_reject_sandbox_if_no_refining_before 1
    if {[catch {::legacy::get_attribute crr_refine_mapping_reject_sandbox_if_no_refining /} msg]} {
    } else {
      set crr_refine_mapping_reject_sandbox_if_no_refining_before [legacy::get_attribute crr_refine_mapping_reject_sandbox_if_no_refining /]
    }
    tentative_set_attr crr_refine_mapping_reject_sandbox_if_no_refining 0 /
    if { $do_remap_always } {
      variable resultValid [crr_or_map_def_cmd -remap_always -use_crr_shell $design]
    } else {
      variable resultValid [crr_or_map_def_cmd -use_crr_shell $design]
    }
    tentative_reset_attr align_envx_next_id /
    tentative_reset_attr glo_power_restructure /
    tentative_set_attr crr_refine_mapping_reject_sandbox_if_no_refining $crr_refine_mapping_reject_sandbox_if_no_refining_before /
    #tentative_reset_attr crr_refine_mapping_reject_sandbox_if_no_refining /

    set slk_after [get_db $design .slack]
    set tns_after [get_db $design .tns]
    set power_after [getTotalPower $design]
    if {$power_before < $power_after} {
      FL_AreaPowerOptimize $design
      FL_EndOptimize $design
    }

    variable enableGateCompInPowerCRR
    if {$enableGateCompInPowerCRR} {
      tentative_set_attr reject_power_degradation true /
      tentative_set_attr pinswap_allow_sizing 1 /

      iopt_dynamic_power $design

      tentative_reset_attr pinswap_allow_sizing /
      tentative_reset_attr reject_power_degradation /
    }

    tentative_reset_attr power_weight_pct_in_medium_effort_mode /
    tentative_reset_attr map_crr_full_structuring /

  }
  proc crr_map_shell_and_worse_power_tns_polish_lean_comb {} { 
    variable genusPowerRestructRemapAlways
    set do_remap_always [expr {$genusPowerRestructRemapAlways & 0x2}]
    crr_map_shell_and_worse_power_tns_polish_lean $do_remap_always
  } 
  proc crr_map_shell_and_worse_power_tns_polish_lean_seq {} { 
    variable genusPowerRestructRemapAlways
    set do_remap_always [expr {$genusPowerRestructRemapAlways & 0x1}]
    crr_map_shell_and_worse_power_tns_polish_lean $do_remap_always
  } 
  proc crr_decongest {polish} {
    # TODO: remove fluff (puts, unnecessary get_db)
    set design [vfind / -design top]
    set slk_before [get_db $design .slack]
    set tns_before [get_db $design .tns]
    set area_before [get_db $design .insts_area]
    _synthesize_private -to_generic -effort medium
    preserve_feed_thru_nets
    _synthesize_private -to_mapped -no_incr -effort high
    set slk_after [get_db $design .slack]
    set tns_after [get_db $design .tns]
    set area_after [get_db $design .insts_area]
    if {$polish} {
      if {($slk_before > $slk_after && $slk_after < 0) || $tns_before < $tns_after} {
        puts "Info: Slack/TNS $slk_before/$tns_before --> $slk_after/$tns_after triggers TNS polish."
        FL_TnsOptimize
        set slk_after [get_db $design .slack]
        set tns_after [get_db $design .tns]
      }
      set area_after [get_db $design .insts_area]
      if {$area_before < $area_after} {
        if {($slk_before <= $slk_after || $slk_after > 0) || $tns_before >= $tns_after} {
          puts "Info: Area $area_before --> $area_after triggers area polish."
          FL_AreaPowerOptimize
          set area_after [get_db $design .insts_area]
          set slk_after [get_db $design .slack]
          set tns_after [get_db $design .tns]
        } else {
          puts "Info: Area $area_before --> $area_after, but area polish skipped because timing is already also worse."
        }
      }
    }
    puts "Info: Summary Area/Slack/TNS $area_before/$slk_before/$tns_before --> $area_after/$slk_after/$tns_after"
  }
  proc print_WDR__log { run_log_file } {
    set rdFile [open "${run_log_file}" r]
    while {![eof $rdFile]} {
      set line [gets $rdFile]
      puts "+ $line"
    }
    close $rdFile
  }
  proc crr_WDR {minLeaves} {
    variable genusAdvancedCRR
    if {$genusAdvancedCRR} {
      resetAdvancedCRR
      tentative_set_attr map_logical_structuring_for_pam false /
    }

    variable wdrStartTime [::legacy::get_attribute runtime]
    variable congReclaimSessionId
    puts "# WDR session $congReclaimSessionId #"

    variable netLenCurrent 0
    variable netLenBefore 0
    variable netLenAfter 0

    set netLenBefore [getNetLengthFromRpt]
    puts "Net Length Before WDR $netLenBefore"

    variable WDR_RunLog
    variable WDR_GateLocFile
    variable WDR_Verb
    variable WDR_WinRatio
    puts "WDR run (log: $WDR_RunLog  gateLoc: $WDR_GateLocFile)"
    if { $WDR_GateLocFile != ""} {
      redirect $WDR_RunLog {
        puts "___Begin___"
        phys::tree_minimization $minLeaves run $WDR_GateLocFile $WDR_Verb $WDR_WinRatio
        puts "___End___"
      }
      ## workaround to avoid hang when using -tee for both standard output and target file output
      print_WDR__log $WDR_RunLog
    }
    set netLenAfter [getNetLengthFromRpt]
    puts "Net Length After WDR $netLenAfter"
    variable wdrEndTime [::legacy::get_attribute runtime]
    set delta [expr {$wdrEndTime - $wdrStartTime}]
    puts "WDR runtime $delta seconds"
 
    if {$genusAdvancedCRR} {
      initAdvancedCRR
    }
  }
  proc crr_hinst_synth_write_misc_file {fname} {
    set fo [open $fname w]
    set pins [get_db [get_db hinsts ph] .hpins]
    foreach pin $pins {
      set pin_name [get_db $pin .base_name]
      set boundary_change [get_db $pin .boundary_change]
      set pushedThroughCase [regexp {pushed equal signal through} $boundary_change]
      if {($boundary_change != "none") && !$pushedThroughCase} {
        puts $fo "PA $pin_name boundary_change $boundary_change"
      }    
    }    
    set attrlist ""     
    lappend attrlist "gb_gdef_type"
    lappend attrlist "comp_builder_info"
    lappend attrlist "super_thread_speed_grade"
    lappend attrlist "cas_mux"
    lappend attrlist "gdef_startpoint"
    lappend attrlist "revisit_mux_cluster"
    foreach i $attrlist {
      set attr_val [get_db [get_db hinsts ph] .module.$i]
      if {$attr_val != ""} {
        puts $fo "MA $i $attr_val"
      }
    }

    variable slk_before
    variable slk_after
    variable power_before
    variable power_after
    variable changed_architecture
    puts $fo "genus_data $slk_before $slk_after $power_before $power_after $changed_architecture"

    variable non_rebuildable
    puts $fo "non_rebuildable $non_rebuildable"

    close $fo
  }
  set slk_before 0
  set slk_after 0
  set tns_before 0
  set tns_after 0
  set power_before 0
  set power_after 0
  set area_before 0
  set area_after 0
  set non_rebuildable 0
  set changed_architecture 0
  set min_power_gain -0.1
  proc crr_dp_synth_delay {} {
    set polish 1
    set design [vfind / -design top]
    variable slk_before [get_db $design .slack]
    variable tns_before [get_db $design .tns]
    variable power_before 0
    variable area_before [get_db $design .insts_area]
    
    if {[get_attribute_status can_rebuild -type module]} {
      set rebuildable_before [get_db hinst:ph .module.can_rebuild]
    }

    preserve_feed_thru_nets
    _synthesize_private -to_mapped -second_condense -no_incremental -effort high
    
    if {[get_attribute_status can_rebuild -type module]} {
      set rebuildable_after [get_db hinst:ph .module.can_rebuild]
      if {$rebuildable_before != $rebuildable_after} {
        puts "ERROR: Rebuildable status changed!"
        variable non_rebuildable 1
        variable resultValid 0
        return
      }
    }
    
    variable slk_after [get_db $design .slack]
    variable tns_after [get_db $design .tns]
    variable power_after 0
    variable area_after [get_db $design .insts_area]
    if {$polish} {
      if {($slk_before > $slk_after && $slk_after < 0) || $tns_before < $tns_after} {
        puts "Info: Slack/TNS $slk_before/$tns_before --> $slk_after/$tns_after triggers TNS polish."
        FL_WnsOptimize
        FL_TnsOptimize
        variable slk_after [get_db $design .slack]
        variable tns_after [get_db $design .tns]
        variable area_after [get_db $design .insts_area]
      }
    }
  }
  proc crr_dp_synth_power {} {
    set polish 1
    set design [vfind / -design top]
    variable slk_before [get_db $design .slack]
    variable tns_before [get_db $design .tns]
    variable area_before [get_db $design .insts_area]
    variable power_before [getTotalWeightedPower $design]

    set speed_grade_before [get_db hinst:top/ph .module.speed_grade]
    set sub_arch_before [get_db hinst:top/ph .module.sub_arch]

    set_db map_rebld_huffman_encode 1
    set_db map_rebld_opportunity_cost 1
    set_db design_power_effort high

    if {[get_attribute_status can_rebuild -type module]} {
      set rebuildable_before [get_db hinst:top/ph .module.can_rebuild]
    }

    preserve_feed_thru_nets
    _synthesize_private -to_mapped -second_condense -no_incremental -effort high -phys_resynthesis
    
    if {[get_attribute_status can_rebuild -type module]} {
      set rebuildable_after [get_db hinst:top/ph .module.can_rebuild]
      if {$rebuildable_before != $rebuildable_after} {
        puts "ERROR: Rebuildable status changed!"
        variable non_rebuildable 1
        variable resultValid 0
        return
      }
    }
    
    set speed_grade_after [get_db hinst:top/ph .module.speed_grade]
    set sub_arch_after [get_db hinst:top/ph .module.sub_arch]
    if {$speed_grade_before != $speed_grade_after || $sub_arch_before != $sub_arch_after} {
      variable changed_architecture 1
    } else {
      variable changed_architecture 0
    }

    variable slk_after [get_db $design .slack]
    variable tns_after [get_db $design .tns]
    variable area_after [get_db $design .insts_area]
    variable power_after [getTotalWeightedPower $design]
    if {$polish} {
      if {($slk_before > $slk_after && $slk_after < 0) || $tns_before < $tns_after} {
        puts "Info: Slack/TNS $slk_before/$tns_before --> $slk_after/$tns_after triggers TNS polish."
        FL_WnsOptimize
        FL_TnsOptimize
        variable slk_after [get_db $design .slack]
        variable tns_after [get_db $design .tns]
        variable area_after [get_db $design .insts_area]
        variable power_after [getTotalWeightedPower $design]
      }
      if {$area_before < $area_after || $power_before < $power_after} {
        if {($slk_before <= $slk_after || $slk_after > 0) || $tns_before >= $tns_after} {
          puts "Info: Area $area_before --> $area_after triggers area polish."
          FL_AreaPowerOptimize
          variable slk_after [get_db $design .slack]
          variable tns_after [get_db $design .tns]
          variable area_after [get_db $design .insts_area]
          variable power_after [getTotalWeightedPower $design]
        } else {
          puts "Info: Area $area_before --> $area_after, but area polish skipped because timing is already also worse."
        }
      }
    }
    
    puts "Info: Summary Area/Slack/TNS $area_before/$slk_before/$tns_before --> $area_after/$slk_after/$tns_after"

    set power_delta [expr {$power_after - $power_before}]
    set power_gain $power_delta
    if {$power_before > 0} {
      set power_gain [expr {$power_delta / $power_before}]
    }
    variable min_power_gain
    if {$power_delta > $min_power_gain} {
      variable moveImproved 0
    } else {
      variable moveImproved 1
    }
  }

  proc crr_mux_synth {} { 
    set design [vfind / -design top] 
    set slk_before [get_db $design .slack]
    set tns_before [get_db $design .tns]
    set area_before [get_db $design .insts_area]
    set mux_revisit [get_db [get_db hinsts ph] .module.revisit_mux_cluster]
    #_mux revisit
    if { $mux_revisit } {
      mux_resynth
    } else {
      cas_revisit_map  
    }
    set slk_after [get_db $design .slack]
    set tns_after [get_db $design .tns]
    set area_after [get_db $design .insts_area]
    
    puts "Info: Summary Area/Slack/TNS $area_before/$slk_before/$tns_before --> $area_after/$slk_after/$tns_after"
  }

  proc crr_use_fopt_buffering {} {
    set design [vfind / -design top]

    foreach att {iopt_crit_upsz iopt_crit_dnsz iopt_drc_buftimb iopt_drc_buftims iopt_dup iopt_setup_dn iopt_buf2inv iopt_mb_split iopt_exp iopt_gate_deco iopt_gcomp_tim iopt_inv_pair_2_buf} {
	lappend restore $att [legacy::get_attribute $att /]
	legacy::set_attribute $att 0 /
    }

    preserve_feed_thru_nets

    FL_WnsOptimize $design
    FL_EndOptimize $design 

    foreach {att val} $restore {
	legacy::set_attribute $att $val /
    }
  }
  proc map_def_track_dft {} {
    if {$::errorInfo ne ""} {
      variable resultValid 0
      return
    }
    if {[catch {map_def -track_dft}]} {
      puts "Error: map_def -track_dft"
      variable resultValid 0
      set ::errorInfo ""
      return
    }
    variable resultValid 1
  }
  proc dumpErrorInfo {} {
    variable workerId
    variable batchId
    set vfile [lindex [get_read_files -quiet -command read_netlist] end]
    set f [open ${vfile}.errorInfo "a"]
    puts $f "<<<<<<<<<< Begin CRR worker #$workerId error (batch $batchId)"
    puts $f $::errorInfo
    puts $f ">>>>>>>>>> End CRR worker error"
    puts $f ""
    close $f
  }
  proc checkDftTrackingResult {} {
    variable resultValid
    if {$resultValid} {
      if {[get_db [vfind / -design top] .dft_tracking_failed]} {
        set ::errorInfo "dft tracking failed"
      }
    }
  }
  proc getBatchStatus {} {
    variable resultValid
    variable moveImproved
    variable simulateErrors
    if {[llength $simulateErrors] && $::errorInfo eq ""} {
      variable batchId
      if {[lsearch -exact $simulateErrors $batchId] >= 0} {
        set ::errorInfo "Simulating an error for batch #${batchId}"
      }
    }
    set status 0
    if {$::errorInfo ne ""} {
      set status 1
      puts "***Error in batch: \{$::errorInfo\}"
      if {[catch {dumpErrorInfo} msg]} {
        puts "Error in dumpErrorInfo: $msg"
      }
    } elseif {!$resultValid} {
      set status -2 ; # mapper failed.
    } elseif {!$moveImproved} {
      set status -1 ; # means ok, but not improved
    }
    return $status
  }

  proc getPhaseInvertedPins {flop} {
    lappend pins
    if {[catch {
         foreach pin [vfind $flop -pin *] {
           set value [get_db $pin .is_phase_inverted]
           puts "DEBUG: @getPhaseInvertedPins $pin = '$value'"
           if {$value ne "" && $value} {
             lappend pins [basename $pin]
           }
         }
       } msg]} {
      puts "(ignored) $msg $::errorInfo"
    }
    return $pins
  }
  proc reportPhaseInverted {flop_id} {
    set ph [vfind / -module *]
    if {[llength $ph]} {
      if {[catch {set flop [vfind inst:top/ph/g$flop_id]} msg]} {
        if {[catch {set flop [vfind inst:top/ph/crr_shelli_g$flop_id]} msg]} {
          puts "$msg"
          return
        }
      }
    } else {
      if {[catch {set flop [vfind inst:top/g$flop_id]} msg]} {
        if {[catch {set flop [vfind inst:top/crr_shelli_g$flop_id]} msg]} {
          puts "$msg"
          return
        }
      }
    }
    showMsg "PHASE-INVERSION-for-innovus [getPhaseInvertedPins $flop]"
  }

  proc microsec2sec {microsec} {
    set sec [expr {$microsec / 1000000.0}]
    return [format "%.3f" $sec]
  }
  proc calcOneProfiledCommand {microsecs} {
    set n [llength $microsecs]
    set total ""
    if {$n} {
      set microsecs [lsort -real $microsecs]
      set min [lindex $microsecs 0]
      set max [lindex $microsecs end]
      set total 0
      foreach x $microsecs {
        set total [expr {$total + $x}]
      }
      set avg [expr {$total / $n}]
      lappend total $avg $min $max $n
    }
    return $total
  }
  proc cellInputs {cell} {
    set n 0
    foreach i [get_db [vfind $cell -lib_pin *] .direction] {
      if {$i == "in"} { incr n }
    }
    return $n
  }
  proc reportUsableCells {} {
    variable usableCells
    set combo 0
    set unusable 0
    set mapper_unusable 0
    set sequential 0
    array set by_inputs {}
    foreach cell [vfind / -lib_cell *] {
      set name [vbasename $cell]
      if {[lsearch -exact $usableCells $name] >= 0} {
        if {![get_db $cell .mapper_usable]} {
          incr mapper_unusable
        } elseif {[get_db $cell .combinational]} {
          incr combo
          lappend by_inputs([cellInputs $cell]) $name
        } else {
          incr sequential
        }
      } else {
        incr unusable
      }
    }
    incr unusable $mapper_unusable
    lappend result "combo:$combo"
    foreach n [lsort -integer -increasing [array names by_inputs]] {
      #puts "$n-in: $by_inputs($n)"
      lappend result "$n-in:[llength $by_inputs($n)]"
    }
    lappend result "seq:$sequential"
    lappend result "unusable:$unusable"
    if {$mapper_unusable} {
      lappend result "(mapper_unusable:$mapper_unusable)"
    }
    return $result
  }
  proc reportProfiledPerCellCount {subtotal2summary_ref} {
    upvar $subtotal2summary_ref subtotal2summary
    variable usableCells
    set cmds "*crr_map*"
    set n [expr {[llength $usableCells] * 1.0}]
    set count 0
    puts "======================================================================"
    foreach subtotal [lsort -real -decreasing [array names subtotal2summary]] {
      foreach {summary key} $subtotal2summary($subtotal) {
        if {[string match $cmds $key]} {
          if {$count == 0} {
            puts "There are [llength $usableCells] usable cells: [reportUsableCells]."
            puts "Average runtime per cellcount for '$cmds' commands (in microseconds):"
          }
          incr count
          lassign $summary avg min max calls
          puts "  $key: [format "%.3f" [expr {$avg/$n}]] us"
        }
      }
    }
  }
  proc reportProfiledCommandsInt {} {
    variable otherProfileCommands
    variable profileCommands
    if {[array size profileCommands]} {
      array set subtotal2summary {}
      set total 0
      foreach key [lsort -dictionary [array names profileCommands]] {
        set summary [calcOneProfiledCommand $profileCommands($key)]
        if {[llength $summary]} {
          set subtotal [lindex $summary 0]
          set total [expr {$total + $subtotal}]
          lappend subtotal2summary($subtotal) [lrange $summary 1 end] $key
        }
      }
      puts ""
      puts "======================================================================"
      puts "Profiled commands report (in seconds):"
      if {$total > 0} {
        foreach subtotal [lsort -real -decreasing [array names subtotal2summary]] {
          set percent [expr {100.0 * $subtotal / $total}]
          foreach {summary key} $subtotal2summary($subtotal) {
            lassign $summary avg min max calls
            puts "  $key: [format "%.2f%%" $percent] / total=[microsec2sec $subtotal] / avg=[microsec2sec $avg] / min=[microsec2sec $min] / max=[microsec2sec $max] ($calls calls)"
          }
        }
        reportProfiledPerCellCount subtotal2summary
      } else {
        puts "  <no profiled command found>"
      }
      puts "======================================================================"
      if {[llength $otherProfileCommands]} {
        puts "(<other> is one of [list [lsort -dictionary -unique $otherProfileCommands]])"
      }
      puts ""
    }
  }
  proc reportProfiledCommands {} {
    if {[catch {reportProfiledCommandsInt} msg]} {
      puts "INTERNAL ERROR (benign): $msg"
    }
  }
  proc syncOnFile {fname period} {
    puts -nonewline "Info: waiting for $fname"
    while {![file exists $fname]} {
      after $period
      puts -nonewline "."
    }
    puts "."
  }
  proc complementaryCells {cells} {
    array set table {}
    foreach i $cells {
      set table($i) ""
    }
    lappend complementary
    foreach cell [vfind / -lib_cell *] {
      set name [vbasename $cell]
      if {![info exists table($name)]} {
        lappend complementary $name
      }
    }
    return $complementary
  }
  proc markLibCellsPreserve {usable_cells dont_use_cells} {
    array set usable {}
    array set dont_use {}
    foreach i $usable_cells {
      set usable($i) ""
    }
    foreach i $dont_use_cells {
      set dont_use($i) ""
    }
    set count 0
    lappend toPreserve
    lappend toUnPreserve
    lappend toDontUse
    lappend toUsable
    foreach cell [vfind / -lib_cell *] {
      set name [vbasename $cell]
      incr count
      set value_preserve [::legacy::get_attr preserve $cell]
      set value_dont_use [::legacy::get_attr dont_use $cell]
      if {!$value_preserve} {
        if {![info exists usable($name)] && ![info exists dont_use($name)]} {
          # cell marked unusable in innovus or not found there
          ::legacy::set_attribute preserve true $cell
          lappend toPreserve $name
        }
      } elseif {[info exists usable($name)]} {
        # cell marked usable by user in innovus
        ::legacy::set_attribute preserve false $cell
        lappend toUnPreserve $name
      }
      if {!$value_dont_use} {
        if {![info exists usable($name)]} {
          # cell marked dont_use in innovus or not found there
          ::legacy::set_attribute dont_use true $cell
          lappend toDontUse $name
        }
      } elseif {[info exists usable($name)]} {
        # cell marked usable by user in innovus
        ::legacy::set_attribute dont_use false $cell
        lappend toUsable $name
      }
    }
    puts "Info: [llength $toPreserve]/$count cells changed from unpreserve to preserve [list $toPreserve]"
    puts "Info: [llength $toUnPreserve]/$count cells changed from preserve to unpreserve [list $toUnPreserve]"
    puts "Info: [llength $toDontUse]/$count cells changed from usable to dont_use [list $toDontUse]"
    puts "Info: [llength $toUsable]/$count cells changed from dont_use to usable [list $toUsable]"
  }
  proc markLibCellsHiddenAvoid {usable_cells} {
    array set usable {}
    foreach i $usable_cells {
      set usable($i) ""
    }
    set count 0
    lappend toHiddenAvoid
    foreach cell [vfind / -lib_cell *] {
      set name [vbasename $cell]
      incr count
      set value_preserve [::legacy::get_attr preserve $cell]
      if {!$value_preserve} {
        if {![info exists usable($name)]} {
          # cell marked unusable in innovus hinst or not found there
          lappend toHiddenAvoid $name
        }
      } elseif {[info exists usable($name)]} {
        puts "Warning: cannot make hi_avoid false for cell $name."
      }
    }
    if {[llength $toHiddenAvoid]} {
      ::legacy::set_attribute hidden_avoid true [lsort -unique $toHiddenAvoid]
    }
    puts "Info: [llength $toHiddenAvoid]/$count cells changed from usable to hi_avoid [list $toHiddenAvoid]"
  }
  set dontUseGroupType ""
  proc setDontUseGroup {group} {
    variable dontUseGroupType
    if {$dontUseGroupType eq "no_type"} {
      set_lib_context -id $group
    } elseif {$dontUseGroupType ne ""} {
      set_lib_context -type $dontUseGroupType -idx $group
    } else {
      puts "Warning: set_lib_context disabled."
    }
  }
  proc initDontUseGroupType {} {
    variable dontUseGroupType ""
    if {[catch {set dontUseGroupType [create_lib_context_type]} msg]} {
      puts "Warning: $msg"
      if {[catch {create_lib_context -help} msg]} {
        puts "Warning: $msg"
        puts "Warning: set_lib_context disabled."
      } else {
        set dontUseGroupType "no_type"
      }
    }
    return $dontUseGroupType
  }
  proc createDontUseGroup {} {
    variable dontUseGroupType
    if {$dontUseGroupType eq "no_type"} {
      return [create_lib_context]
    } elseif {$dontUseGroupType ne ""} {
      return [create_lib_context -type $dontUseGroupType]
    }
    puts "Warning: set_lib_context disabled."
    return -code error "set_lib_context disabled"
  }
  proc subtractList {x y} {
    # return elements of x not in y
    lappend z
    foreach i $x {
      if {[lsearch -exact $y $i] < 0} {
        lappend z $i
      }
    }
    return $z
  }
  proc intersectList {x y} {
    # return elements both in x and y
    lappend z
    foreach i $x {
      if {[lsearch -exact $y $i] >= 0} {
        lappend z $i
      }
    }
    return $z
  }
  proc initDontUseGroups {} {
    variable eff_use_groups
    variable eff_dont_use_groups
    variable usableCells
    variable dontUseCells
    variable genusSkipRedundantLibEstablishEnabled
    if {$genusSkipRedundantLibEstablishEnabled} {
      tentative_set_attr skip_library_estb true /
    }
    delete_lib_contexts
    puts "Info: creating specific use/dont_use cells per HInst groups..."
    set usableCellsAnyWhere $usableCells
    lappend allGroups
    if {![file exists hinst_dont_use.tcl]} {
      puts "Warning: hinst_dont_use.tcl not found."
    } elseif {[initDontUseGroupType] ne ""} {
      setDontUseGroup 0
      array unset eff_use_groups
      array unset eff_dont_use_groups
      array set eff_use_groups {}
      array set eff_dont_use_groups {}
      tcl_source hinst_dont_use.tcl
      set allGroups [array names eff_use_groups]
      foreach i [array names eff_dont_use_groups] { lappend allGroups $i }
      set allGroups [lsort -integer -unique $allGroups]
      if {[llength $allGroups]} {
        foreach i [lsort -integer [array names eff_use_groups]] {
          foreach cell $eff_use_groups($i) {
            lappend usableCellsAnyWhere $cell
          }
        }
        set usableCellsAnyWhere [lsort -unique $usableCellsAnyWhere]
        if {[llength $usableCellsAnyWhere] != [llength $usableCells]} {
          puts "Info: expanding usable cells for lib_context 0..."
          markLibCellsPreserve $usableCellsAnyWhere $dontUseCells
          markLibCellsHiddenAvoid $usableCells
        }
        foreach i $allGroups {
          setDontUseGroup 0
          set idx [createDontUseGroup]
          setDontUseGroup $idx
          puts "      Info: marking usable cells for lib_context $idx."

          if {[info exists eff_use_groups($i)]} {
            set ctxUsable $usableCells
            foreach cell $eff_use_groups($i) {
              lappend ctxUsable $cell
            }
          } else {
            set ctxUsable $usableCellsAnyWhere
          }
          if {[info exists eff_dont_use_groups($i)]} {
            set ctxUsable [subtractList $ctxUsable $eff_dont_use_groups($i)]
          }
          markLibCellsHiddenAvoid $ctxUsable
          puts "      (DontUseGroup $i --> lib_context $idx)"
        }
        setDontUseGroup 0
      }
    }
    puts "Info: specific use/dont_use cells per HInst group {"
    foreach i $allGroups {
      if {[info exists eff_use_groups($i)]} {
        puts "  $i +use: [list [lsort -dictionary [subtractList $eff_use_groups($i) $usableCells]]]"
      }
      if {[info exists eff_dont_use_groups($i)]} {
        puts "  $i +dont_use: [list [lsort -dictionary [intersectList $eff_dont_use_groups($i) $usableCells]]]"
      }
    }
    puts "}"

    if {$genusSkipRedundantLibEstablishEnabled} {
      tentative_set_attr skip_library_estb false /
      setDontUseGroup 0
    }
  }
  proc initAdvancedCRRTat {} {
    variable genusAdvancedCRRGenusTat
    tentative_set_attr map_enable_crr_data_cache true /
    tentative_set_attr reuse_steiner_tree true /
    if {$genusAdvancedCRRGenusTat} {
      tentative_set_attr lcr_runtime_improvement 1 /
      tentative_set_attr crr_lcr_runtime_improvement 2 /
    }
  }
  array set advancedCRRBackup {
    map_logical_structuring_for_pam "false"
    fopt_add_physical_wire_loads "true"
    map_phys_add_pn_wirecap "true"
    map_force_extra_buf_for_preserve "false"
    map_always_annotate_ext_load_info_in_sandbox "true"
    crr_slack_adjust_for_restructuring "true"
    exp_map_use_adjusted_curve_for_sandbox_indel "true"
    disable_plc_buf_tricks "1"
    crr_del_weight_mult "1"
    mapper_load_use_hpwl "true"
    crr_refine_mapping_reject_sandbox_if_no_refining "false"
    use_gint_locations_as_placement_bounds "true"
    cluster_dpul_include_total_pincap "true"
  }
  proc initAdvancedCRR {} {
    variable genusAdvancedCRRTat
    variable advancedCRRBackup
    foreach i [array names advancedCRRBackup] {
      tentative_set_attr $i $advancedCRRBackup($i) /
      saveDelayModeByVariable $i
    }
    tentative_set_attr pam_final_slack_fix true /
    tentative_set_attr map_wirecap_location_fix true /
    tentative_set_attr map_phys_add_pn_wirecap_mode 1 /
    tentative_set_attr dpul_bug_fix true /
    tentative_set_attr map_hpwl_driver_loc_fix 1 /
    tentative_set_attr map_xy_fix_connect_delay_on_sandbox_ports true /
    tentative_set_attr loc_adjust_after_crr true /
    tentative_set_attr map_enable_crr_data_cache false /
    tentative_set_attr crr_reset_phys_cache true /
    if {$genusAdvancedCRRTat} {
      initAdvancedCRRTat
    }
  }
  proc resetAdvancedCRR {} {
    variable advancedCRRBackup
    foreach i [array names advancedCRRBackup] {
      # crr_del_weight_mult changed in both advanced CRR and delay/power/area mode
      tentative_reset_attr $i /
      saveDelayModeByVariable $i
    }
  }
  proc initAdvancedStructuring {} {
    variable genusAdvancedStructuring
    if {!$genusAdvancedStructuring} {
      return
    }
    tentative_set_attr advanced_structuring true / 
    tentative_set_attr advstr_enable_in_crr true / 
    tentative_set_attr nx_opt_effort nodes_then_levels / 
    tentative_set_attr advstr_node_gain_threshold -100 / 
  }
  proc initPhysical {} {
    variable genusPhysicalSetupEnabled
    variable forceDisabledFeatures
    variable genusSkipRedundantLibEstablishEnabled
    if {!$genusPhysicalSetupEnabled} {
      return
    }
    if {[catch {crr_set_port_location -help} msg] || [lsearch -exact $forceDisabledFeatures crr_set_port_location] >= 0} {
      set genusPhysicalSetupEnabled 0
      return
    }
    tentative_set_attr map_logical_structuring_for_pam false /

    variable genusFloorplanWidth
    variable genusFloorplanHeight
    variable genusFloorplanSite
    variable genusNumOfRoutingLayer
    set_db placement_aware_mapping 2
    set_db map_placement_aware_timing true
    variable genusMMMCEnabled
    if {$genusMMMCEnabled} {
      set_db enable_mmmc_spec_linking false
      edit_netlist_new_design -name dummy
      set_db design:dummy .is_dummy_for_mmmc true
      vcd dummy
    } else {
      edit_netlist_new_design -name dummy
    }
    create_floorplan -no_rows -width $genusFloorplanWidth -height $genusFloorplanHeight
    create_row -site $genusFloorplanSite
    set_db st_floorplan_nl dummy

    ::legacy::set_attribute ple_mode cluster /
    tentative_set_attr use_virtual_ndr_for_dpul 2 /
    tentative_set_attr use_real_pin_cap_for_dpul true /
    tentative_set_attr use_dpul_for_wire_cap true /
    tentative_set_attr dpul_characterize_init_length_factor 0.01 /
    tentative_set_attr dpul_characterize_num_lengths 27 /
    tentative_set_attr use_vipo_glo_ple_wire_cap 3 /
    tentative_set_attr map_force_physical_wire_cap true /
    if {$genusNumOfRoutingLayer > 8} {
      if {[catch {::phys::create_routing_bins 2 5} msg]} {
        puts "(ignored) $msg $::errorInfo"
      }
    }
    set ::errorInfo ""
    tentative_set_attr buffer_deduplicate_driver_sink true /
    if {!$genusSkipRedundantLibEstablishEnabled} {
      placement_buf -characterize_buffer
    }
    ::legacy::set_attribute use_virtual_ipo 1 /
    ::legacy::set_attribute use_vipo_delay_per_unit_length 1

    tentative_set_attr use_piecewise_dpul 1 /
    tentative_set_attr use_piecewise_dpul_via_model 1 /
    tentative_set_attr fix_cdd 1 /

    if {$genusNumOfRoutingLayer > 8} {
      ::phys::create_routing_bins 5 0 "promotion"
    }

    if {$genusMMMCEnabled} {
      vcd
      set_db enable_mmmc_spec_linking true
    }

    initPhysicalMode
  }

  proc killParent {reason} {
    variable ppid
    puts $reason
    if {$ppid} {
      puts "DEBUG: sending kill signal to parent innovus process with pid = $ppid..."
      exec kill -9 $ppid
      quit
    }
  }
  proc logError {reason} {
    puts $reason
    catch {
      set f [open "genus.errorInfo" "a"]
      puts $f ""
      puts $f $reason
      close $f
    }
  }
  proc sanityCheck {} {
    variable minMajorVersion
    puts "Info: checking genus version has required version/features..."
    set version [get_db / .program_major_version]
    if {$version < $minMajorVersion} {
      set msg "sanity check failed; expected version >= $minMajorVersion, got $version"
      logError $msg
      return -code error $msg
    }
    if {[catch {crr_map_def -help} msg]} {
      logError "sanity check failed; $msg"
      return -code error "sanity check failed; $msg"
    }
    variable genusMMMCEnabled
    if {!$genusMMMCEnabled} {
      edit_netlist_new_design -name top
    }
    puts "Info: sanity check passed!"
  }
  proc readLef {fileNames} {
    if {[catch "redirect -msg -variable coeGenus::readLefOutput \{read_physical -lef \{$fileNames\}\}" msg]} {
      set ::errorInfo ""
      if {[regexp {:[^\n]+(LEFPARS-1703)[^\n]+} $coeGenus::readLefOutput matched]} {
        puts "Current genus version does not support Lef Version 6.0.\n    $matched"
      } else {
        puts $coeGenus::readLefOutput
      }
    } 
  }
  proc test_min_gates {} {
    # build a simple design with just one and and see if there are at least
    # min number of boolean gates for mapping
    variable genusMMMCEnabled
    variable genusEnableGTAMask

    edit_netlist_new_design -name test
    edit_netlist_new_primitive -function and -inputs 2 -name my_and -inside test
    edit_netlist_new_port_bus -name A -input test
    edit_netlist_new_port_bus -name B -input test
    edit_netlist_new_port_bus -name Y -output test
    edit_netlist_connect my_and/in_0 A
    edit_netlist_connect my_and/in_1 B
    edit_netlist_connect my_and/z Y
    if {$genusMMMCEnabled} {
      init_design -skip_sdc_read -top test
    } else {
      init_design -top test
    }
    syn_gen
    # avoid side-effect from syn_generic
    if {[expr {$genusEnableGTAMask & 0x4}]} {
      tentative_set_attr exp_opt_generic_timing_area_aware true /
    } else {
      tentative_set_attr exp_opt_generic_timing_area_aware false /
    }

    if {$genusMMMCEnabled} {
      reset_only_design design:test
    } else {
      delete_obj design:test
    }
  }
  proc test_command_option {cmd option} {
    set saved_errorInfo $::errorInfo
    set rsl ""
    set msg "<unknown>"
    redirect -variable msg {$cmd -help}
    if {![regexp -- $option $msg]} {
      set rsl "'$cmd $option' not supported"
      # could be a hidden option; only way is to try to use it and look for
      # specific command output
      if {$cmd eq "set_load_fast" && $option eq "-mode"} {
        redirect -msg -variable msg {catch {set_load_fast -mode a_non_existing_mode}}
        # If -mode is suported we see:
        #   Error   : A required object parameter could not be found. [TUI-61] [set_load_fast]
        #   : An object of type 'mode' named 'a_non_existing_mode' could not be found.
        # Otherwise we see:
        #   Error   : A command argument is of the wrong type. [TUI-66] [set_load_fast]
        #   : A floating point number was expected, but '-xmode' was seen instead.
        if {[regexp -- {TUI-61} $msg] && [regexp -- {object of type 'mode' named 'a_non_existing_mode' could not be found} $msg]} {
          set rsl ""
        } else {
          puts $msg
        }
      }
    }
    if {$::errorInfo ne $saved_errorInfo} {
      set ::errorInfo $saved_errorInfo
    }
    return $rsl
  }
  proc featureCheck {fname} {
    variable forceDisabledFeatures
    variable genusSkipRedundantLibEstablishEnabled
    variable genusPhysicalSetupEnabled
    puts "Info: checking genus version has optional features..."
    set f [open $fname "w"]
    #set version [get_db / .program_major_version]
    #puts    "# major version: $version"
    #puts $f "# major version: $version"
    set version [get_db / .program_version]
    puts    "# version: $version"
    puts $f "# version: $version"
    set ok 1
    if {$genusSkipRedundantLibEstablishEnabled} {
      if {![lib_has_minimum_functions [get_db designs] ]} {
        set ok 0
        puts "Library minimun functions check failed."
        puts "feature check failed: 1"
      }
    } else {
      if {[catch {test_min_gates} msg]} {
        set ok 0
        puts "feature check failed: $msg"
        # skip setup physical if no min gates
        set genusPhysicalSetupEnabled 0 
      }
    }
    puts    "min_lib_gates: $ok"
    puts $f "min_lib_gates: $ok"
    lappend cmd_feature crr_map_def ""
    lappend cmd_feature create_lib_context ""
    lappend cmd_feature create_slack_adjusts ""
    lappend cmd_feature set_pin_activity ""
    lappend cmd_feature setPowerDomainOfDelayCorner ""
    lappend cmd_feature crr_set_port_location ""
    lappend cmd_feature map_def ""
    lappend cmd_feature set_load_fast -mode
    puts "Info: checking optional command features..."
    foreach {cmd option} $cmd_feature {
      set ok 1
      set msg "forcibly disabled"
      if {[catch {$cmd -help} msg] || [lsearch -exact $forceDisabledFeatures $cmd] >= 0} {
        set ok 0
        puts "feature check failed: $msg"
      } elseif {$option ne ""} {
        set msg [test_command_option $cmd $option]
        if {$msg ne ""} {
          set ok 0
          puts "feature check failed: $msg"
        }
      }
      if {$option eq ""} {
        puts    "$cmd command: $ok"
        puts $f "$cmd command: $ok"
      } else {
        puts    "$cmd $option command_option: $ok"
        puts $f "$cmd $option command_option: $ok"
      }
    }
    lappend attr_feature root dft_tracking
    lappend attr_feature root dft_track_scan_chain
    lappend attr_feature port dft_tracking_scan_out
    lappend attr_feature root lp_toggle_rate_unit
    lappend attr_feature root map_avg_toggle_count_root_scale
    lappend attr_feature root use_inverter_for_scan_out
    lappend attr_feature port slack_adjust_base_by_mode
    lappend attr_feature root map_std_gate_power_area_factor
    lappend attr_feature root map_eliminate_oupin_pos_slack
    lappend attr_feature root innovus_crr_design_level_unit_dynamic_power_per_area
    lappend attr_feature root init_design_skip_consistency_check
    lappend attr_feature root program_major_version
    puts "Info: checking optional attribute features..."
    foreach {obj attr} $attr_feature {
      set ok 1
      if {![get_attribute_status $attr -type $obj] || [lsearch -exact $forceDisabledFeatures $attr] >= 0} {
        set ok 0
      } elseif {$attr == "program_major_version"} {
        variable minMajorVersion
        set version [get_db / .program_major_version]
        if {$version < $minMajorVersion} {
          puts "Error: version $version < minMajorVersion $minMajorVersion"
          set ok 0
        }
      }
      puts    "${obj}/${attr} attribute: $ok"
      puts $f "${obj}/${attr} attribute: $ok"
    }
    close $f
  }
  proc execute_cmd {cmd} {
    if {[catch {namespace eval :: $cmd} msg]} {
      puts "Worker Error: $msg"
      return 0
    }
    return 1
  }
  proc connectMainSocket {} {
    variable mainSocket
    if {[llength $mainSocket]} {
      puts "Info: setting up main worker channel < $mainSocket"
      lassign [split $mainSocket ":"] host port
      if { $host == "" } {
        set host "localhost"
      }
      variable mainPipe [socket $host $port]
      puts "Info: connected to bidirectional socket"
    }
  }
  proc worker {id} {
    variable libsRead
    variable inputPipes
    variable outputPipes
    variable inoutSockets
    variable workerId $id
    variable saveWorkersCmd
    set_db / .auto_super_thread false
    set_db / .super_thread_servers {}
    set_db / .max_cpus_per_server 0
    puts "Info: worker #$id pid is [pid]"
    beginProfile $id
    if {[llength $inoutSockets]} {
      set sock [lindex $inoutSockets $id]
      puts "Info: setting up worker #$id < $sock > $sock"
      lassign [split $sock ":"] host port
      variable inPipe [socket $host $port]
      puts "Info: connected to bidirectional socket"
      variable outPipe $inPipe
    } else {
      set iname [lindex $inputPipes $id]
      set oname [lindex $outputPipes $id]
      puts "Info: setting up worker #$id < $iname > $oname"
      variable inPipe [open $iname r]
      puts "Info: opened input pipe"
      variable outPipe [open $oname w]
      puts "Info: opened output pipe"
    }
    if {!$libsRead} {
      puts "Error: shutting down worker #$id early due to errors in library reading."
    } else {
      set errorCount 0
      set fcmd ""
      if {$saveWorkersCmd} {
        puts "Info: saving commands sent to worker #$id in 'genusWorker_$id.cmd'"
        set fcmd [open "genusWorker_$id.cmd" a]
        flush $fcmd
      }
      while {[gets $inPipe cmd] >= 0 && $cmd ne "coeGenus::quit"} {
        if {[llength $fcmd]} {
          puts "><><><><>< '$cmd'"
          puts $fcmd $cmd
          flush $fcmd
        }
        if {![execute_cmd $cmd]} {
          incr errorCount
        }
      }
      if {[llength $fcmd]} {
        close $fcmd
      }
      reportProfiledCommands
      if {$errorCount} {
        puts "Error: $errorCount commands caused errors in worker."
      } else {
        puts "Info: cleanly shutting down worker #$id."
      }
    }
    flush stdout
    if {$inPipe != $outPipe} {
      close $outPipe
    }
    close $inPipe
    set inPipe -1
    set outPipe -1
    endProfile
    flush stdout
  }
  proc countWorkers {} {
    variable inputPipes
    variable inoutSockets
    set n [llength $inputPipes]
    if {$n == 0} {
      set n [llength $inoutSockets]
    }
    return $n
  }
  proc writePIds {pids} {
    set f_pid [open genus.pids w]
    puts $f_pid [pid]
    if {[llength $pids]} {
      puts $f_pid $pids
    }
    close $f_pid
  }
  proc launchAndWaitWorkers {} {
    array set pid2id {}
    set n [countWorkers]
    puts "Info: starting $n workers... \{"
    if {[get_db / .max_cpus_per_server] <= $n} {
      set_db / .max_cpus_per_server [expr {$n + 1}]
    }
    lappend pids
    for {set i 0} {$i < $n} {incr i} {
      set pid [os::fork "::coeGenus::worker $i" -logfile "genusWorker_$i.log"]
      lappend pid2id($pid) $i
      lappend pids $pid
      puts "Info: started worker #$i with pid $pid"
    }
    writePIds $pids
    puts "\}"
    puts "Info: waiting for $n workers... \{"
    set n 0
    while {$n < [array size pid2id]} {
      foreach pid [os::wait] {
        incr n
        if {[info exists pid2id($pid)]} {
          puts "Info: worker #$pid2id($pid) with pid $pid finished."
        } else {
          puts "Warning: unknown worker with pid $pid finished."
        }
      }
    }
    puts "\}"
  }
  variable countLaunches 0
  array set pid2id {}
  proc forkWorkers {} {
    variable countLaunches
    variable pid2id
    array unset pid2id
    array set pid2id {}
    set secs_begin [get_db / .elapsed_time]
    set n [countWorkers]
    puts "Info: starting $n workers... \{"
    incr countLaunches
    if {[get_db / .max_cpus_per_server] <= $n} {
      set_db / .max_cpus_per_server [expr {$n + 1}]
    }
    lappend pids
    for {set i 0} {$i < $n} {incr i} {
      set pid [os::fork "::coeGenus::worker $i" -logfile "genusWorker_$i.log$countLaunches"]
      lappend pid2id($pid) $i
      lappend pids $pid
      puts "Info: started worker #$i with pid $pid"
    }
    writePIds $pids
    set secs_end [get_db / .elapsed_time]
    puts "\} ([expr {$secs_end - $secs_begin}]sec)"
  }
  proc waitWorkers {} {
    variable pid2id
    puts "Info: waiting for [array size pid2id] workers... \{"
    writePIds ""
    set n 0
    while {$n < [array size pid2id]} {
      foreach pid [os::wait] {
        incr n
        if {[info exists pid2id($pid)]} {
          puts "Info: worker #$pid2id($pid) with pid $pid finished."
        } else {
          puts "Warning: unknown worker with pid $pid finished."
        }
      }
    }
    puts "\}"
  }
  proc openAndCloseWorkerChannels {} {
    variable inputPipes
    variable outputPipes
    variable inoutSockets
    puts "Info: open and close all worker input channels... \{"
    puts "DEBUG: inoutSockets = '$inoutSockets'"
    puts "DEBUG: inputPipes = '$inputPipes'"
    puts "DEBUG: outputPipes = '$outputPipes'"
    if {[llength $inoutSockets]} {
      foreach sock $inoutSockets {
        puts "  < $sock"
        flush stdout
        lassign [split $sock ":"] host port
        if {[catch {close [socket $host $port]} msg]} {
          puts "Error: $msg."
          flush stdout
        }
      }
    }
    if {[llength $inputPipes]} {
      set n [countWorkers]
      for {set id 0} {$id < $n} {incr id} {
        set iname [lindex $inputPipes $id]
        set oname [lindex $outputPipes $id]
        puts "  < $iname"
        flush stdout
        if {[catch {close [open $iname r]} msg]} {
          puts "Error: $msg."
          flush stdout
        }
        puts "  > $oname"
        flush stdout
        if {[catch {close [open $oname w]} msg]} {
          puts "Error: $msg."
          flush stdout
        }
      }
    }
    puts "\}"
  }
  proc executeCommandsFromMainSocket {} {
    forkWorkers
    waitWorkers
  }
  proc executeCommandsFromMainSocket {} {
    variable mainPipe
    set errorCount 0
    set cmd ""
    openAndCloseWorkerChannels; # avoid deadlock otherwise
puts "DEBUG: mainPipe = $mainPipe"
    while {[gets $mainPipe cmd] >= 0 && $cmd ne "coeGenus::quit"} {
      puts "><><><><>< '$cmd'"
      flush stdout
      if {![execute_cmd $cmd]} {
        incr errorCount
      }
    }
    puts "><><><><>< '$cmd'"
    if {$errorCount} {
      puts "Error: $errorCount commands caused errors in main worker."
    } else {
      puts "Info: cleanly shutting down main worker."
    }
  }
  proc generateMmmcFile {} {
    variable genusMMMCPowerDomain 
    close [open dummy.sdc w]
    set inputFile "./viewDefinition.tcl"
    set outputFile "./mmmc.dummy.tcl"
    set fp [open $inputFile r]
    set file_data [regsub -all {\\\n} [read $fp] {}]
    set data [split $file_data "\n"]
    set root [file dirname [pwd]]
    close $fp
    set fp [open $outputFile w]
    foreach raw_d $data {
      set d ""
      eval lappend d [string trim $raw_d]
      if {$d ne ""} {
        set head [lindex $d 0]
        if {[string equal $head "create_rc_corner"] == 1} {
          set cmd ""
          set validOption 1
          set expandPath 0
          foreach option $d {
            if {[regexp {^\-} $option]} {
              if {[string equal $option "-qrc_library"] == 1} {
                set validOption 0
              } else {
                set validOption 1
              }
            }
            if {$validOption} {
              if {$expandPath && ([string range $option 0 1] eq "./")} {
                set path [string range $option 1 end]
                lappend cmd $root$path
              } else {
                lappend cmd $option
              }
              if {[string equal $option "-qrc_tech"] == 1} {
                set expandPath 1
              }
            }
          }
          puts $fp $cmd
        } elseif {[string equal $head "create_constraint_mode"] == 1} { 
          set cmd ""
          set sdcOption 0
          foreach option $d {
            if {[regexp {^\-} $option]} {
              if {[string equal $option "-sdc_files"] == 1 || [string equal $option "-ilm_sdc_files"] == 1} {
                set sdcOption 1
                lappend cmd $option dummy.sdc
              } else {
                set sdcOption 0
              }
            }
            if {!$sdcOption} {
              lappend cmd $option
            }
          } 
          puts $fp $cmd
        } elseif {[string equal $head "create_analysis_view"] == 1} {
          set cmd ""
          set validOption 1
          foreach option $d {
            if {[regexp {^\-} $option]} {
              if {[string equal $option "-latency_file"] == 1} {
                set validOption 0
              } else {
                set validOption 1
              }
            }
            if {$validOption} {
              lappend cmd $option
            }
          }
          puts $fp $cmd
        } elseif {[string equal $head "create_library_set"] == 1} {
          set cmd ""
          set expandPath 0
          foreach option $d {
            if {$expandPath && ([string range $option 0 1] eq "./")} {
              set liblist ""
              foreach lib $option {
                set path [string range $lib 1 end]
                lappend liblist $root$path
              }
              lappend cmd $liblist
            } else {
              lappend cmd $option
            }
            if {[regexp {^\-} $option]} {
              if {[string equal $option "-timing"] == 1} {
                set expandPath 1
              }
            }
          }
          puts $fp $cmd 
        } elseif {([string equal $head "create_delay_corner"] == 1) && !$genusMMMCPowerDomain} {
          set cmd ""
          foreach option $d {
            if {[regexp {\@} $option]} {
              set fields [split $option " "]
              foreach field $fields {
                if {[regexp {\@} $field]} {
                  continue
                } else {
                  lappend cmd $field
                }
              }
            } else {
              lappend cmd $option
            }
          }
          puts $fp $cmd 
        } else {
          puts $fp $d
        }
      }
    }
    close $fp
  }
  proc hasRawConsts {} {
    return [llength [::get_db ports -if {.drivers.obj_type==constant}]]
  }
  proc hasNewAssign {} {
    set outputPorts [::get_db ports o*]
    set outputDrivers [::get_db $outputPorts .drivers]
    # assign i_ = o_
    if { [llength [::get_db $outputDrivers -if {.obj_type==port}]] } {
      return 1
    }
    # assign o_ = o_
    return [expr [llength [lsort -unique $outputDrivers]] != [llength $outputPorts]]
  }
  proc fixNewAssign {} {
    if {[hasNewAssign]} {
      remove_assigns_without_opt -dont_skip_unconstrained_paths -use_inverted_signal -ports o*
    }
  }
  proc hasNewAssignPH {} {
    set outputPorts [::get_db hports */o*]
    set outputDrivers [::get_db $outputPorts .drivers]
    if { [llength [::get_db $outputDrivers -if {.obj_type==hport}]] } {
      return 1
    }
    return [expr [llength [lsort -unique $outputDrivers]] != [llength $outputPorts]]
  }
  proc fixNewAssignPH {} {
    if {[hasNewAssignPH]} {
      remove_assigns_without_opt -dont_skip_unconstrained_paths -use_inverted_signal -design [vfind / -subdesign *]
    }
  }
  proc fixRawConstsPH {} {
    if {[llength [::get_db hports -if {.drivers.obj_type==constant}]]} {
      insert_tiehilo_cells -allow_inversion
      remove_assigns_without_opt -dont_skip_unconstrained_paths -use_inverted_signal -design [vfind / -subdesign *]
    }
  }
  proc hasMOG {} {
    foreach inst [vfind / -inst *] {
      if {[llength [lsearch -all [get_db [get_db $inst .pins] .direction] out]] > 1} {
        return 1
      }
    }
    return 0
  }
  proc enableSeqBubblePush {} {
    set_db allow_inverted_phase_ff_in_crr 1
    set_db / .lbr_seq_in_out_phase_opto true
  }
  proc disableSeqBubblePush {} {
    set_db allow_inverted_phase_ff_in_crr 0
    set_db / .lbr_seq_in_out_phase_opto false
  }
  proc setUnitPowerAreaFactor {design_unit_dyn_pwr design_unit_lkg_pwr sandbox_unit_dyn_pwr sandbox_unit_lkg_pwr} {
    set_db / .innovus_crr_design_level_unit_dynamic_power_per_area $design_unit_dyn_pwr
    set_db / .innovus_crr_design_level_unit_leakage_power_per_area $design_unit_lkg_pwr
    set_db / .innovus_crr_sandbox_level_unit_dynamic_power_per_area $sandbox_unit_dyn_pwr
    set_db / .innovus_crr_sandbox_level_unit_leakage_power_per_area $sandbox_unit_lkg_pwr
  }
  proc setTechProcessNode {} {
    variable genusDesignProcessNode
    variable genusDesignTechNode
    tentative_set_attr design_process_node $genusDesignProcessNode /
    tentative_set_attr design_tech_node $genusDesignTechNode /
  }
  proc setPLEOptions {{value "true"}} {
    tentative_set_attr phys_skip_native_qrc_parsing $value /
    tentative_set_attr phys_use_preplace_via_res $value /
  }
  proc setPLEFactors {} {
    variable prePlaceWireLengthSlope
    variable prePlaceWireLengthY0
    variable prePlaceResScaleFactor
    variable prePlaceCapScaleFactor
    variable prePlaceFanoutPenalty 
    variable prePlaceFanoutThreshold 
    variable prePlaceSiteSize 

    if {![get_attribute_status extraction_ple_correlation_factor -type root]} {
      return
    }
    
    set_db extraction_ple_user_override true
    set_db extraction_ple_correlation_factor "$prePlaceWireLengthSlope $prePlaceWireLengthY0"
    set_db extraction_ple_resistance_factor $prePlaceResScaleFactor
    set_db extraction_ple_capacitance_factor $prePlaceCapScaleFactor
    set_db extraction_ple_fanout_penalty $prePlaceFanoutPenalty
    set_db extraction_ple_fanout_threshold $prePlaceFanoutThreshold
    if {$prePlaceSiteSize > 0} {
      set_db extraction_ple_site_size $prePlaceSiteSize
    }
  }
  proc setSubnwPLEFactor {rFactor cFactor} {
    tentative_set_attr ple_cluster_net_resistance_scale_factor $rFactor /
    tentative_set_attr ple_cluster_net_capacitance_scale_factor $cFactor /
  }
  proc writeRetimeInstMap {fname} {
    if {$fname eq ""} {
      return
    }

    set fp [open $fname w]
    set retimeCount 0
    foreach i [get_db insts * -if {.is_flop == true}] {
      set orig_list [get_db $i .retime_original_registers]
      if {[llength $orig_list]} {
        puts $fp "[string map {ph/ {} \{ { } \} { }} [list [get_db $i .name] $orig_list]]"
        incr retimeCount
      } else {
        puts "Error: Cannot find retime_original_registers of [get_db $i .name]"
        puts $fp "[string map {ph/ {}} [list [get_db $i .name] [get_db $i .name]]]"
      }
    }
    close $fp
    showMsg "RETIME-INST-MAP-for-innovus $retimeCount"
  }
  proc connectScanPinsToPort {port} {
    set ph [find_peephole]
    if {![llength $ph]} {
      return 0
    }
    set hnet [vfind / -mindepth 6 -hnet $port]
    if {![llength $hnet]} {
      return 0
    }
    set scan_enable [get_db pins * -if {.lib_pins.scan_enable_polarity != none}]
    set scan_in [get_db pins * -if {.lib_pins.scan_in_polarity != none}]
    puts "Connecting '$scan_in' and '$scan_enable' to '$hnet'"
    disconnect $scan_enable $scan_in
    connect $scan_enable $scan_in -hnet $hnet
    return 1
  }
  proc connectScanChain {se si} {
    set ph [find_peephole]
    if {![llength $ph]} {
      puts "Error: Cannot connect scan chain for pure top design"
      return 0
    }
    set soPort [vfind / -port so*]
    if {![llength $soPort] || ![llength $se] || ![llength $si]} {
      if {$se eq $si } {
        return [connectScanPinsToPort $se]
      } else {
        puts "Error: Scan ports are not defined se '$se' si '$si' so '$soPort'"
        return 0
      }
    }
    set hse [vfind / -hpin $se]
    set hsi [vfind / -hpin $si]
    set hso [lindex [vfind / -hpin so*] 0]
    define_shift_enable -active high $hse
    define_scan_chain -sdi $hsi -shared_input -sdo $hso -shared_output
    check_dft_rules
    connect_scan_chains
  }
  
}
proc coeGenus::fixRawConsts {} {if {[hasRawConsts]} {
  insert_tiehilo_cells -allow_inversion
  remove_assigns_without_opt -dont_skip_unconstrained_paths -use_inverted_signal -ports o*}
}

set coeGenus::minMajorVersion 21.1
set coeGenus::simulateErrors {}
set coeGenus::ppid 378170
set coeGenus::usableCells {XOR3XL XOR3X1 XOR2XL XOR2X4 XOR2X2 XOR2X1 XNOR3XL XNOR3X1 XNOR2XL XNOR2X4 XNOR2X2 XNOR2X1 TLATXL TLATX4 TLATX2 TLATX1 TLATSRXL TLATSRX4 TLATSRX2 TLATSRX1 TLATNXL TLATNX4 TLATNX2 TLATNX1 TLATNTSCAX8 TLATNTSCAX6 TLATNTSCAX4 TLATNTSCAX3 TLATNTSCAX20 TLATNTSCAX2 TLATNTSCAX16 TLATNTSCAX12 TLATNSRXL TLATNSRX4 TLATNSRX2 TLATNSRX1 TLATNCAX8 TLATNCAX6 TLATNCAX4 TLATNCAX3 TLATNCAX20 TLATNCAX2 TLATNCAX16 TLATNCAX12 TIELO TIEHI TBUFXL TBUFX8 TBUFX6 TBUFX4 TBUFX3 TBUFX20 TBUFX2 TBUFX16 TBUFX12 TBUFX1 SRDFFX1 SRDFFSX1 SRDFFSRX1 SRDFFSRQX1 SRDFFSQX1 SRDFFRX1 SRDFFRQX1 SRDFFQX1 SRDFFNX1 SRDFFNSX1 SRDFFNSRX1 SRDFFNSRQX1 SRDFFNSQX1 SRDFFNRX1 SRDFFNRQX1 SRDFFNQX1 SPDFF4RX2 SPDFF4RX1 SPDFF2RX2 SPDFF2RX1 SMDFFHQX8 SMDFFHQX4 SMDFFHQX2 SMDFFHQX1 SEDFFXL SEDFFX4 SEDFFX2 SEDFFX1 SEDFFTRXL SEDFFTRX4 SEDFFTRX2 SEDFFTRX1 SEDFFHQX8 SEDFFHQX4 SEDFFHQX2 SEDFFHQX1 SDFFXL SDFFX4 SDFFX2 SDFFX1 SDFFTRXL SDFFTRX4 SDFFTRX2 SDFFTRX1 SDFFSXL SDFFSX4 SDFFSX2 SDFFSX1 SDFFSRXL SDFFSRX4 SDFFSRX2 SDFFSRX1 SDFFSRHQX8 SDFFSRHQX4 SDFFSRHQX2 SDFFSRHQX1 SDFFSHQX8 SDFFSHQX4 SDFFSHQX2 SDFFSHQX1 SDFFRXL SDFFRX4 SDFFRX2 SDFFRX1 SDFFRHQX8 SDFFRHQX4 SDFFRHQX2 SDFFRHQX1 SDFFQXL SDFFQX4 SDFFQX2 SDFFQX1 SDFFNSRXL SDFFNSRX4 SDFFNSRX2 SDFFNSRX1 SDFFHQX8 SDFFHQX4 SDFFHQX2 SDFFHQX1 SDFF4RX2 SDFF4RX1 SDFF2RX2 SDFF2RX1 RTLATX1 RTLATSRX1 RTLATRX1 RDFFX1 RDFFSX1 RDFFSRX1 RDFFSRQX1 RDFFSQX1 RDFFRX1 RDFFRQX1 RDFFQX1 RDFFNX1 RDFFNSX1 RDFFNSRX1 RDFFNSRQX1 RDFFNSQX1 RDFFNRX1 RDFFNRQX1 RDFFNQX1 PINVX1 PBUFX2 OR4XL OR4X8 OR4X6 OR4X4 OR4X2 OR4X1 OR3XL OR3X8 OR3X6 OR3X4 OR3X2 OR3X1 OR2XL OR2X8 OR2X6 OR2X4 OR2X2 OR2X1 OAI33XL OAI33X4 OAI33X2 OAI33X1 OAI32XL OAI32X4 OAI32X2 OAI32X1 OAI31XL OAI31X4 OAI31X2 OAI31X1 OAI2BB2XL OAI2BB2X4 OAI2BB2X2 OAI2BB2X1 OAI2BB1XL OAI2BB1X4 OAI2BB1X2 OAI2BB1X1 OAI22XL OAI22X4 OAI22X2 OAI22X1 OAI222XL OAI222X4 OAI222X2 OAI222X1 OAI221XL OAI221X4 OAI221X2 OAI221X1 OAI21XL OAI21X4 OAI21X2 OAI21X1 OAI211XL OAI211X4 OAI211X2 OAI211X1 OA22XL OA22X4 OA22X2 OA22X1 OA21XL OA21X4 OA21X2 OA21X1 NOR4XL NOR4X8 NOR4X6 NOR4X4 NOR4X2 NOR4X1 NOR4BXL NOR4BX4 NOR4BX2 NOR4BX1 NOR4BBXL NOR4BBX4 NOR4BBX2 NOR4BBX1 NOR3XL NOR3X8 NOR3X6 NOR3X4 NOR3X2 NOR3X1 NOR3BXL NOR3BX4 NOR3BX2 NOR3BX1 NOR2XL NOR2X8 NOR2X6 NOR2X4 NOR2X2 NOR2X1 NOR2BXL NOR2BX4 NOR2BX2 NOR2BX1 NAND4XL NAND4X8 NAND4X6 NAND4X4 NAND4X2 NAND4X1 NAND4BXL NAND4BX4 NAND4BX2 NAND4BX1 NAND4BBXL NAND4BBX4 NAND4BBX2 NAND4BBX1 NAND3XL NAND3X8 NAND3X6 NAND3X4 NAND3X2 NAND3X1 NAND3BXL NAND3BX4 NAND3BX2 NAND3BX1 NAND2XL NAND2X8 NAND2X6 NAND2X4 NAND2X2 NAND2X1 NAND2BXL NAND2BX4 NAND2BX2 NAND2BX1 MXI4XL MXI4X4 MXI4X2 MXI4X1 MXI3XL MXI3X4 MXI3X2 MXI3X1 MXI2XL MXI2X8 MXI2X6 MXI2X4 MXI2X2 MXI2X1 MX4XL MX4X4 MX4X2 MX4X1 MX3XL MX3X4 MX3X2 MX3X1 MX2XL MX2X8 MX2X6 MX2X4 MX2X2 MX2X1 MDFFHQX8 MDFFHQX4 MDFFHQX2 MDFFHQX1 LSLHX1_TO LSLHX1_FROM LSLH_ISONL_X1_TO_ON LSLH_ISONL_X1_FROM_OFF LSLH_ISONH_X1_TO_ON LSLH_ISONH_X1_FROM_OFF LSLH_ISOL_X1_TO_ON LSLH_ISOL_X1_FROM_OFF LSLH_ISOH_X1_TO_ON LSLH_ISOH_X1_FROM_OFF LSHLX1_TO LSHLX1_FROM LSHL_ISONL_X1_TO_ON LSHL_ISONL_X1_FROM_OFF LSHL_ISONH_X1_TO_ON LSHL_ISONH_X1_FROM_OFF LSHL_ISOL_X1_TO_ON LSHL_ISOL_X1_FROM_OFF LSHL_ISOH_X1_TO_ON LSHL_ISOH_X1_FROM_OFF ISONLX1_ON ISONLX1_OFF ISOLX1_ON ISOLX1_OFF ISOHX1_ON ISOHX1_OFF ISOHLDX1_ON ISOHLDX1_OFF INVXL INVX8 INVX6 INVX4 INVX3 INVX20 INVX2 INVX16 INVX12 INVX1 HSWX1 HSWNX1 HSWDX1 HSWDNX1 FSWX1 FSWNX1 FILL8 FILL64 FILL4 FILL32 FILL2 FILL16 FILL1 EDFFXL EDFFX4 EDFFX2 EDFFX1 EDFFTRXL EDFFTRX4 EDFFTRX2 EDFFTRX1 EDFFHQX8 EDFFHQX4 EDFFHQX2 EDFFHQX1 DLY4X4 DLY4X1 DLY3X4 DLY3X1 DLY2X4 DLY2X1 DLY1X4 DLY1X1 DFFXL DFFX4 DFFX2 DFFX1 DFFTRXL DFFTRX4 DFFTRX2 DFFTRX1 DFFSXL DFFSX4 DFFSX2 DFFSX1 DFFSRXL DFFSRX4 DFFSRX2 DFFSRX1 DFFSRHQX8 DFFSRHQX4 DFFSRHQX2 DFFSRHQX1 DFFSHQX8 DFFSHQX4 DFFSHQX2 DFFSHQX1 DFFRXL DFFRX4 DFFRX2 DFFRX1 DFFRHQX8 DFFRHQX4 DFFRHQX2 DFFRHQX1 DFFQXL DFFQX4 DFFQX2 DFFQX1 DFFNSRXL DFFNSRX4 DFFNSRX2 DFFNSRX1 DFFHQX8 DFFHQX4 DFFHQX2 DFFHQX1 DFF4X2 DFF4X1 DFF4RX2 DFF4RX1 DFF2X2 DFF2X1 DFF2RX2 DFF2RX1 CLKXOR2X8 CLKXOR2X4 CLKXOR2X2 CLKXOR2X1 CLKMX2X8 CLKMX2X6 CLKMX2X4 CLKMX2X3 CLKMX2X2 CLKMX2X12 CLKINVX8 CLKINVX6 CLKINVX4 CLKINVX3 CLKINVX20 CLKINVX2 CLKINVX16 CLKINVX12 CLKINVX1 CLKBUFX8 CLKBUFX6 CLKBUFX4 CLKBUFX3 CLKBUFX20 CLKBUFX2 CLKBUFX16 CLKBUFX12 CLKAND2X8 CLKAND2X6 CLKAND2X4 CLKAND2X3 CLKAND2X2 CLKAND2X12 BUFX8 BUFX6 BUFX4 BUFX3 BUFX20 BUFX2 BUFX16 BUFX12 BMXIX4 BMXIX2 AOI33XL AOI33X4 AOI33X2 AOI33X1 AOI32XL AOI32X4 AOI32X2 AOI32X1 AOI31XL AOI31X4 AOI31X2 AOI31X1 AOI2BB2XL AOI2BB2X4 AOI2BB2X2 AOI2BB2X1 AOI2BB1XL AOI2BB1X4 AOI2BB1X2 AOI2BB1X1 AOI22XL AOI22X4 AOI22X2 AOI22X1 AOI222XL AOI222X4 AOI222X2 AOI222X1 AOI221XL AOI221X4 AOI221X2 AOI221X1 AOI21XL AOI21X4 AOI21X2 AOI21X1 AOI211XL AOI211X4 AOI211X2 AOI211X1 AO22XL AO22X4 AO22X2 AO22X1 AO21XL AO21X4 AO21X2 AO21X1 ANTENNA AND4XL AND4X8 AND4X6 AND4X4 AND4X2 AND4X1 AND3XL AND3X8 AND3X6 AND3X4 AND3X2 AND3X1 AND2XL AND2X8 AND2X6 AND2X4 AND2X2 AND2X1 ADDHXL ADDHX4 ADDHX2 ADDHX1 ADDFXL ADDFX4 ADDFX2 ADDFX1 ADDFHXL ADDFHX4 ADDFHX2 ADDFHX1 ACHCONX2}
set coeGenus::dontUseCells HOLDX1

### Communication channels between master and workers
set coeGenus::inputPipes pip/t00_to.pipe
set coeGenus::outputPipes pip/t00_from.pipe
set coeGenus::inoutSockets {}
set coeGenus::mainSocket {}

### Global flow defines
set_db / .flow_verbose false
set_db / .metric_enable false
set_db / .partition_based_synthesis false
set_db / .pbs_debug_level 0
set_db / .tinfo_tstamp_file ""
set_db / .write_verification_files false
set_db / .write_vlog_bit_blast_bus_connections true
set_db / .write_vlog_line_wrap_limit 3990
set_db / .metric_auto_capture false
set_db / .power_unit nW
set_db / .power_format {%.4f}
coeGenus::tentative_set_attr avoid_tied_inputs false /
coeGenus::tentative_set_attr joules_silent true /
coeGenus::tentative_set_attr read_lef_ver60 true /
coeGenus::tentative_set_attr lef_out_of_order_eeq_macro true /
coeGenus::tentative_set_attr iopt_from_invs_crr false /
coeGenus::tentative_set_attr ifca_lef_allow_backside_layers true /
coeGenus::tentative_set_attr exp_opt_generic_timing_area_aware false /
set_db / .information_level 0
set coeGenus::gcompDynFix 1
set coeGenus::powerModeSpeedup 1
coeGenus::tentative_set_attr map_crr_full_structuring 1 /
coeGenus::tentative_set_attr map_use_path_adjust_for_crr_for_pos_paths true /
coeGenus::tentative_set_attr use_tiling_delay_penalty 3 /
legacy::set_attribute unmap_scan_flops true /
set coeGenus::skip_map_def 1
namespace eval coeGenus {
  set coeTimingCRREnhancementVersion 1

  if {![tentative_set_attr consider_full_feedthrough_load_caps true /]} {
    puts "Info: no consider full feedthrough load caps attribute"
  }
  if {![tentative_set_attr crr_feedthrough_fix_speedup true /]} {
    puts "Info: no speed up for full feedthrough load cap consideration"
  }
  if {![tentative_set_attr map_fix_buffering_for_dont_optimize_nodes true /]} {
    puts "Info: no buffering fix for dont optimize nodes"
  }
    

  if {![tentative_set_attr crr_slack_adjust_for_restructuring true /]} {
    puts "Info: no consider crr_slack_adjust_for_restructuring"
  }
  if {![tentative_set_attr exp_map_use_adjusted_curve_for_sandbox_indel true /]} {
    puts "Info: no consider exp_map_use_adjusted_curve_for_sandbox_indel"
  }
  if {![tentative_set_attr map_always_annotate_ext_load_info_in_sandbox true /]} {
    puts "Info: no consider map_always_annotate_ext_load_info_in_sandbox"
  }
  if {![tentative_set_attr use_new_compute_delay_tran_for_port true /]} {
    puts "Info: no consider use_new_compute_delay_tran_for_port"
  }
      

  if {![tentative_set_attr remap_preserve_fix true /]} {
    puts "Info: no remap preserve fix attribute"
  }
      
}
namespace eval coeGenus {

  proc one_line_inst_stats {design} {
    # Returns something like:
    #   {43 insts} (10(3b/7i)+18+10+5) avg_in=2.23
    # meaning the sandbox has 43 instances: 3 buffers, 7 inverters,
    # 18 2-input gates, 10 3-input gates, 5 4-input gates; the average
    # number of inputs per gate is 2.23.
    # Gates with 8 or more inputs are all reported in the "8-input" bucket.
    set total [get_db $design .num_insts]
    lappend result "$total insts"
    if {$total == 0} { set total 1 } ; # avoid divide by zero
    set n0 0
    set n1 0
    set b1 0
    set i1 0
    set n2 0
    set n3 0
    set n4 0
    set n5 0
    set n6 0
    set n7 0
    set n8 0
    set total_inputs 0
    foreach i [get_db $design .insts] {
      set n [llength [get_db $i .pins -if {.direction == in}]]
      incr total_inputs $n
      switch -- $n {
       0 { incr n0 }
       1 { incr n1
           if {[get_db $i .is_buffer]} {
             incr b1
           } elseif {[get_db $i .is_inverter]} {
             incr i1
           }
         }
       2 { incr n2 }
       3 { incr n3 }
       4 { incr n4 }
       5 { incr n5 }
       6 { incr n6 }
       7 { incr n7 }
       default { incr n8 }
      }
    }
    set bi "${n1}\(${b1}b/${i1}i\)"
    if {$n8} {
      lappend result "($bi+$n2+$n3+$n4+$n5+$n6+$n7+$n8)"
    } elseif {$n7} {
      lappend result "($bi+$n2+$n3+$n4+$n5+$n6+$n7)"
    } elseif {$n6} {
      lappend result "($bi+$n2+$n3+$n4+$n5+$n6)"
    } elseif {$n5} {
      lappend result "($bi+$n2+$n3+$n4+$n5)"
    } elseif {$n4} {
      lappend result "($bi+$n2+$n3+$n4)"
    } else {
      lappend result "($bi+$n2+$n3)"
    }
    set avg_inputs [format "%.2f" [expr {$total_inputs * 1.0 / $total}]]
    lappend result "avg_in=$avg_inputs"
    return $result
  }
  proc one_line_port_stats {design} {
    # Returns something like:
    #   {19 regular outputs} {22 feedthru ports} {min/max/avg slack = -701.4 1058.4 87.5} {depth = 1 31 14.5}
    # indicating how many outputs driven by regular logic, how many feedthru
    # that represent the side loads of the sandbox inputs, the min/max/average
    # slack at the regular outputs and the min/max/average depth at those
    # regular outputs.
    # Note that only "valid" slack and depth numbers are reported.
    # Occasionally some outputs may be unconstrained or for some reason
    # reported as having "inf" depth. Those outputs are not counted for
    # reporting purposes. They are added to the result line right before the
    # min/max/avg slack report. They'll look something like:
    # ... ports\} {1 bad depth values = no_value} {2 bad depth values = inf inf} \{min/max/avg slack ...
    phys::push_settings {
      {hlo_path_depth_endp_fix true /}
      {hlo_path_depth_annotate_endpoints true /}
      {hlo_path_depth_annotate_pin_depths true /}
    } "one_line_port_stats"
    report_path_depth -annotate
    set min_slk ""
    set max_slk ""
    set min_dpth ""
    set max_dpth ""
    set total_slk 0
    set total_dpth 0
    set regular 0
    set feedthru 0
    set acc_slacks 0.0
    set acc_depths 0.0
    lappend bad_slk
    lappend bad_dpth
    foreach p [get_db $design .ports -if {.direction == out}] {
      set driver [get_db $p .drivers -if {!.is_port}]
      if {[llength $driver]} {
        incr regular
        set slack [get_db $p .slack]
        set depth [get_db $p .pin_depth]
        if {$slack ne "" && [string is double $slack]} {
          incr total_slk
          set acc_slacks [expr {$slack + $acc_slacks}]
          if {$min_slk eq ""} {
            set min_slk $slack
            set max_slk $slack
          } else {
            set min_slk [expr {min($min_slk,$slack)}]
            set max_slk [expr {max($max_slk,$slack)}]
          }
        } else {
          lappend bad_slk $slack
        }
        if {$depth ne "" && [string is integer $depth]} {
          incr total_dpth
          set acc_depths [expr {$depth + $acc_depths}]
          if {$min_dpth eq ""} {
            set min_dpth $depth
            set max_dpth $depth
          } else {
            set min_dpth [expr {min($min_dpth,$depth)}]
            set max_dpth [expr {max($max_dpth,$depth)}]
          }
        } else {
          lappend bad_dpth $depth
        }
      } else {
        incr feedthru
      }
    }
    phys::pop_settings "one_line_port_stats"
    if {$total_slk == 0} { set total_slk 1 } ; # avoid divide by zero
    if {$total_dpth == 0} { set total_dpth 1 } ; # avoid divide by zero
    set avg_slk [format "%.1f" [expr {$acc_slacks / $total_slk}]]
    set avg_dpth [format "%.1f" [expr {$acc_depths / $total_dpth}]]
    lappend result "$regular regular outputs"
    lappend result "$feedthru feedthru ports"
    if {[llength $bad_slk]} {
      lappend result "[llength $bad_slk] bad slack values = $bad_slk"
    }
    if {[llength $bad_dpth]} {
      lappend result "[llength $bad_dpth] bad depth values = $bad_dpth"
    }
    lappend result "min/max/avg slack = $min_slk $max_slk $avg_slk"
    lappend result "depth = $min_dpth $max_dpth $avg_dpth"
    return $result
  }
  proc crr_map_giga_syn {{enable "10101"}} {
    variable resultValid 1 
    set design [vfind / -design top]
    set debug [expr {[get_db information_level] > 1}]
    puts "======================= Calling crr_map_giga_syn $enable ==================== \{"
    puts "Stats: enabled $enable"
    set insts_init [get_db $design .num_insts]
    preserve_feed_thru_nets
    ## this recipe does not both elim and gtds and maps
    phys::push_settings {
      {itds_global_opt_effort ultra /}
      {advstr_st_mode itds_global /}
    } "crr_map_giga_syn"
    if {$debug} {
      puts "Stats: initial [one_line_inst_stats $design]; [one_line_port_stats $design]"
    }
    set what ""
    set nx_recipe [string index $enable 0]
    if {$nx_recipe} {
      # For now, $nx_recipe-1 is assigned to attr nx_opt_itds_recipe, but in
      # the future we could use this value to encode more elaborated settings.
      lappend settings
      lappend reset_attrs
      switch -- $nx_recipe {
        {1} {
          # do nothing
        }
        {2} {
          lappend settings {advstr_recipe timing /}
          if {$debug} {
            puts "DEBUG: advstr_recipe [list [get_db advstr_recipe /]] --> timing"
          }
          phys::push_settings $settings "giga_syn_adv_str"
          pbs::advstr_recipe reset_attrs "map"
        }
        {3} {
          lappend settings {advstr_recipe area_timing /}
          if {$debug} {
            puts "DEBUG: advstr_recipe [list [get_db advstr_recipe /]] --> area_timing"
          }
          phys::push_settings $settings "giga_syn_adv_str"
          pbs::advstr_recipe reset_attrs "map"
        }
        {4} {
          lappend settings {advstr_recipe area /}
          if {$debug} {
            puts "DEBUG: advstr_recipe [list [get_db advstr_recipe /]] --> area"
          }
          phys::push_settings $settings "giga_syn_adv_str"
          pbs::advstr_recipe reset_attrs "map"
        }
        {5} {
          lappend settings {advstr_level_increase_threshold -1 /}
          phys::push_settings $settings "giga_syn_adv_str"
        }
        {6} {
          lappend settings {advstr_level_gain_accept_threshold 50 /}
          phys::push_settings $settings "giga_syn_adv_str"
        }
        {7} {
          lappend settings {advstr_node_gain_threshold -3 /}
          phys::push_settings $settings "giga_syn_adv_str"
        }
        {8} {
          lappend settings {advstr_node_gain_threshold -20 /}
          phys::push_settings $settings "giga_syn_adv_str"
        }
      }
      pbs::flat_genopt_advstr_one_def $design 1 1
      if {[llength $reset_attrs]} {
        phys::reset_root_attributes $reset_attrs
      }
      if {[llength $settings]} {
        phys::pop_settings "giga_syn_adv_str"
      }
      if {$debug} {
        if {[llength $settings] || [llength $reset_attrs]} {
          puts "DEBUG: run with extra settings \{'"
          foreach i $settings {
            puts "  $i"
          }
          foreach i $reset_attrs {
            puts "  $i --> [get_db $i]"
          }
          puts "\}'"
        }
        puts "Stats: post-genopt [one_line_inst_stats $design]; [one_line_port_stats $design]"
      }
      append what "G$nx_recipe"
    }
    if {[string index $enable 1] == "1"} {
      crr_map_use_crr_gst
      if {$debug} {
        puts "Stats: post-crr_map [one_line_inst_stats $design]; [one_line_port_stats $design]"
      }
      append what "C"
    }
    set insts_genopt [get_db $design .num_insts]
    set info_iopt ""
    if {[string index $enable 2] == "1"} {
      FL_TnsOptimize
      if {$debug} {
        puts "Stats: post-ioptD [one_line_inst_stats $design]"
      }
      append info_iopt " --> [get_db $design .num_insts] (D)"
    }
    if {[string index $enable 3] == "1"} {
      iopt_cell_count_opto $design
      if {$debug} {
        puts "Stats: post-ioptCC [one_line_inst_stats $design]"
      }
      append info_iopt " --> [get_db $design .num_insts] (CC)"
    }
    if {[string index $enable 4] == "1"} {
      FL_AreaPowerOptimize
      if {$debug} {
        puts "Stats: post-ioptAP [one_line_inst_stats $design]"
      }
      append info_iopt " --> [get_db $design .num_insts] (AP)"
    }
    if {[llength $info_iopt]} {
      FL_EndOptimize
    }
    phys::pop_settings "crr_map_giga_syn"
    set insts_after [get_db $design .num_insts]
    set percentG [format "%.2f" [expr {$insts_genopt * 100.0 / $insts_init}]]
    set percent [format "%.2f" [expr {$insts_after * 100.0 / $insts_init}]]
    set extra ""
    if {$debug} {
      set extra "; [one_line_port_stats $design]"
    }
    puts "Stats: summary inst count $insts_init --> $insts_genopt ($what,${percentG}%)${info_iopt} --> $insts_after (${percent}%)${extra}"
    puts "\} ===================== Done calling crr_map_giga_syn ======================"
  }
  
}

### Initial command
coeGenus::tentative_set_attr use_master_mlibs_for_dyn_power_std_slew_load true /
close [open "genus.pre-read_libs" "w"]
coeGenus::connectMainSocket
if {![catch {redirect -msg -variable coeGenus::initCmdOutput {read_libs /home/icd1/workspace/RISC-V-PROCESSOR-45nm/lib/slow_vdd1v0_basicCells.lib; coeGenus::readLef {/home/icd1/workspace/RISC-V-PROCESSOR-45nm/lef/gsclib045_tech.lef /home/icd1/workspace/RISC-V-PROCESSOR-45nm/lef/gsclib045_macro.lef }; read_qrc {/home/icd1/workspace/RISC-V-PROCESSOR-45nm/QRC_Tech/gpdk045.tch}}} msg]} { puts $coeGenus::initCmdOutput; set coeGenus::libsRead 1 } { coeGenus::logError $coeGenus::initCmdOutput }
coeGenus::disableSeqBubblePush
coeGenus::tentative_set_attr exact_match_seq_sync_ctrls true /
close [open "genus.post-read_libs" "w"]

namespace eval coeGenus {syncOnFile genus.go 5000}
if {[file exists derate.tcl] && [file size derate.tcl] > 1} {
  puts {Info: derating cells.}
  tcl_source derate.tcl
}
namespace eval coeGenus {
  set forceDisabledFeatures {}
  markLibCellsPreserve $usableCells $dontUseCells
  if {!$genusSkipRedundantLibEstablishEnabled} {
    featureCheck genus.features
  }
  initPhysical
  markLibCellsPreserve $usableCells $dontUseCells
  if {$genusSkipRedundantLibEstablishEnabled} {
    featureCheck genus.features
  }
  initDontUseGroups
  if {!$genusMMMCEnabled} {
    catch {edit_netlist_new_design -name top}
  }
}

# pragma protect end

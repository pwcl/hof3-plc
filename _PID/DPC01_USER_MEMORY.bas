//DPC01 PID loop data - Membrane Differential Pressure Control Master Loop
//** &USER_MEMORY_630 to &USER_MEMORY_669 currently allocated ** 

REG &DPC01status = &USER_MEMORY_630
BITREG &DPC01status = [|DPC01modeRev, |DPC01modeMan, |DPC01modePID, |DPC01modeSpRamp, |DPC01modeSpRampLast, |DPC01progOutModePID, |DPC01modeManEnable, |DPC01autoInterlock, |DPC01manInterlock, |DPC01setOutputInterlock, |DPC01pidInterlock, |DPC01spRampOFFInterlock, |DPC01spRampONInterlock, |DPC01cvP, |DPC01calcMode, |DPC01calc]
MEM &DPC01status = 0
REG &DPC01cmd = &USER_MEMORY_631
MEM &DPC01cmd = 0
REG &DPC01state = &USER_MEMORY_632
MEM &DPC01state = 0
REG &DPC01pv = &USER_MEMORY_633
MEM &DPC01pv = 0
REG &DPC01cv = &USER_MEMORY_634
MEM &DPC01cv = 0
REG &DPC01sp = &USER_MEMORY_635
MEM &DPC01sp = 0
REG &DPC01err = &USER_MEMORY_636
MEM &DPC01err = 0
REG &DPC01errLast = &USER_MEMORY_637
MEM &DPC01errLast = 0
REG &DPC01errLastLast = &USER_MEMORY_638
MEM &DPC01errLastLast = 0
REG &DPC01p = &USER_MEMORY_639
MEM &DPC01p = 120
REG &DPC01i = &USER_MEMORY_640
MEM &DPC01i = 30
REG &DPC01d = &USER_MEMORY_641
MEM &DPC01d = 0
REG &DPC01tacc = &USER_MEMORY_642
MEM &DPC01tacc = 0
REG &DPC01spRampTarget = &USER_MEMORY_643
MEM &DPC01spRampTarget = 0
REG &DPC01spRampRate = &USER_MEMORY_644
MEM &DPC01spRampRate = 0
REG &DPC01spRampMaxErr = &USER_MEMORY_645
MEM &DPC01spRampMaxErr = 0
REG &DPC01cvMax = &USER_MEMORY_646
MEM &DPC01cvMax = 10000
REG &DPC01cvMaxDt = &USER_MEMORY_647
MEM &DPC01cvMaxDt = 10000
REG &DPC01sp01 = &USER_MEMORY_650 //Production - Diff Pressure
MEM &DPC01sp01 = 500
REG &DPC01sp02 = &USER_MEMORY_651
MEM &DPC01sp02 = 0
REG &DPC01sp03 = &USER_MEMORY_652
MEM &DPC01sp03 = 0
REG &DPC01sp04 = &USER_MEMORY_653
MEM &DPC01sp04 = 0
REG &DPC01sp05 = &USER_MEMORY_654
MEM &DPC01sp05 = 0
REG &DPC01sp06 = &USER_MEMORY_655
MEM &DPC01sp06 = 0
REG &DPC01sp07 = &USER_MEMORY_656
MEM &DPC01sp07 = 0
REG &DPC01sp08 = &USER_MEMORY_657
MEM &DPC01sp08 = 0
REG &DPC01sp09 = &USER_MEMORY_658
MEM &DPC01sp09 = 0
REG &DPC01sp10 = &USER_MEMORY_659
MEM &DPC01sp10 = 0
REG &DPC01cv01 = &USER_MEMORY_660 //Mix Output
MEM &DPC01cv01 = 1000
REG &DPC01cv02 = &USER_MEMORY_661
MEM &DPC01cv02 = 0
REG &DPC01cv03 = &USER_MEMORY_662
MEM &DPC01cv03 = 0
REG &DPC01cv04 = &USER_MEMORY_663
MEM &DPC01cv04 = 0
REG &DPC01cv05 = &USER_MEMORY_664
MEM &DPC01cv05 = 0
REG &DPC01cv06 = &USER_MEMORY_665
MEM &DPC01cv06 = 0
REG &DPC01cv07 = &USER_MEMORY_666
MEM &DPC01cv07 = 0
REG &DPC01cv08 = &USER_MEMORY_667
MEM &DPC01cv08 = 0
REG &DPC01cv09 = &USER_MEMORY_668
MEM &DPC01cv09 = 0
REG &DPC01cv10 = &USER_MEMORY_669
MEM &DPC01cv10 = 0






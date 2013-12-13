// FD100 Main Sequence

// This sequence is responsible for the main state of the plant.  For
// example: mixing, recirculating, concentrating.

// When the plant is in the Recirc state, both the retentate and
// permeate lines are returned to the main tank.  This state fills the
// membrane and associated piping with liquid.

// This file is broken up into four main parts: initialisation, the
// step transitions, the one-shot actions, and the step actions that
// happen every scan.


// Clear Sequence Outputs.  These registers are used to hold bit-wise
// values such as whether pump PP01 should be turned on.  By setting
// these registers to zero, all those bits are cleared in each scan,
// meaning that the code below need only set each bit on if required.
// The declaration for each bit can be found in _USER_MEMORY.bas.
&fd100ProgOut01 = 0 
&fd100ProgOut02 = 0


// *****
// Timer
// *****

// If we're in any state other than "awaiting command", then check to
// see if we want to do a timer-based log
if &fd100StepNum != fd100StepNum_WAITINS then
  // If the logging timer is enabled (i.e. has a positive value) then 
  // increment it and check if we're ready to log  
  if &fd100LogTimePre_s10 >= 0 then
    // Timer is enabled, increment it
    &fd100LogTimeAcc_s10 = &fd100LogTimeAcc_s10 + &lastScanTimeShort
    // Check if it's time to log
    if &fd100LogTimeAcc_m >= &fd100LogTimePre_m\
    and &fd100LogTimeAcc_s10 >= &fd100LogTimePre_s10 then
      // Log timer-based event
      gosub logTimerEvent
      // Reset timer
      &fd100LogTimeAcc_m = 0
      &fd100LogTimeAcc_s10 = 0
    endif
  endif
endif
//Create ONESHOT function for PB01... which is used to start sequence
IF (|PB01_I = ON) THEN
  IF (|PB01_1 = OFF) THEN
    |PB01_1 = ON
    |PB01_2 = OFF
  ELSE
    |PB01_1 = ON
    |PB01_2 = ON
  ENDIF
ELSE
  |PB01_1 = OFF
  |PB01_2 = OFF
ENDIF


// Selection from Raspberry Pi

// If fault checking is disabled, then set the selection messages to 0, meaning
// there is no fault detected.
if &fd100FaultStepNum = fd100Fault_disabled then
  // Faults are disabled
  &fd100cmd_prod_msg = 0
  &fd100cmd_cip_msg = 0
  &fd100cmd_rinse_msg = 0
  &fd100cmd_DRAIN_msg = 0
  &fd100cmd_STORE_msg = 0
else
  // Faults are enabled

  // Check for faults that would inhibit the selection of 'production'
  &OPmsg = 0

  IF ((|ES01_I1 = OFF) OR (|ES01_I2 = ON)) THEN
    &OPmsg = 3
  ELSIF (|PS01_I = OFF) THEN
    &OPmsg = 4
  ELSIF (|PS02_I = OFF) THEN
    &OPmsg = 5
  ELSIF (|PS03_I = OFF) THEN
    &OPmsg = 6
  ELSIF (&fd100Status = fd100Status_RINSE_FULL) THEN
    &OPmsg = 10
  ELSIF (&fd100Status = fd100Status_CIP_FULL) THEN
    &OPmsg = 12
  ELSIF (&fd100Status = fd100Status_CIP_MT) THEN
    &OPmsg = 13            
  ENDIF

  &fd100cmd_prod_msg = &OPmsg


  // Check for faults that would inhibit the selection of 'cip'
  &OPmsg = 0

  IF ((|ES01_I1 = OFF) OR (|ES01_I2 = ON)) THEN
    &OPmsg = 3
  ELSIF (|PS01_I = OFF) THEN
    &OPmsg = 4
  ELSIF (|PS02_I = OFF) THEN
    &OPmsg = 5
  ELSIF (|PS03_I = OFF) THEN
    &OPmsg = 6
  ELSIF (&fd100Status = fd100Status_RINSE_FULL) THEN
    &OPmsg = 10
  ELSIF (&fd100Status = fd100Status_PROD_FULL) THEN
    &OPmsg = 8
  ELSIF (&fd100Status = fd100Status_PROD_MT) THEN
    &OPmsg = 9            
  ENDIF

  &fd100cmd_cip_msg = &OPmsg


  // Check for faults that would inhibit the selection of 'rinse'
  &OPmsg = 0

  IF ((|ES01_I1 = OFF) OR (|ES01_I2 = ON)) THEN  //ESTOP
    &OPmsg = 3
  ELSIF (|PS01_I = OFF) THEN  //Water Pressure
    &OPmsg = 4
  ELSIF (|PS02_I = OFF) THEN  //High Pressure Air
    &OPmsg = 5
  ELSIF (|PS03_I = OFF) THEN  //High Low Air
    &OPmsg = 6
  ELSIF (&fd100Status = fd100Status_CIP_FULL) THEN
    &OPmsg = 12
  ELSIF (&fd100Status = fd100Status_PROD_FULL) THEN
    &OPmsg = 8           
  ENDIF

  &fd100cmd_rinse_msg = &OPmsg


  // Check for faults that would inhibit the selection of 'drain'
  &OPmsg = 0

  IF ((|ES01_I1 = OFF) OR (|ES01_I2 = ON)) THEN //ESTOP
    &OPmsg = 3
  ELSIF (|PS02_I = OFF) THEN //High Pressure Air
    &OPmsg = 5
  ELSIF (|PS03_I = OFF) THEN //High Low Air
    &OPmsg = 6           
  ENDIF

  &fd100cmd_DRAIN_msg = &OPmsg


  // Check for faults that would inhibit the selection of 'store'
  &OPmsg = 0

  IF ((|ES01_I1 = OFF) OR (|ES01_I2 = ON)) THEN //ESTOP
    &OPmsg = 3
  ELSIF (|PS02_I = OFF) THEN //High Pressure Air
    &OPmsg = 5
  ELSIF (|PS03_I = OFF) THEN //High Low Air
    &OPmsg = 6           
  ENDIF

  &fd100cmd_STORE_msg = &OPmsg

endif



// Process the instruction.  For the given instruction, check that there are no
// faults detected.  If we're all good to go, copy the instruction into the one-shot
// variable.
select &fd100cmd 

  case  fd100cmd_RECIRC:
    if ((&fd100cmd_prod_msg = 0) AND (&fd100FillSource = fd100FillSource_SITE)) then
      &fd100cmdOns = &fd100cmd
    elsif ((&fd100cmd_prod_msg = 0) AND (&fd100FillSource = fd100FillSource_NONE)) then
      &fd100cmdOns = &fd100cmd
    elsif ((&fd100cmd_prod_msg = 0) AND (&fd100FillSource = fd100FillSource_TANK)) then
      &fd100cmdOns = &fd100cmd 
    elsif ((&fd100cmd_rinse_msg = 0) AND (&fd100FillSource = fd100FillSource_WATER)) then
      &fd100cmdOns = &fd100cmd
    elsif ((&fd100cmd_cip_msg = 0) AND (&fd100FillSource = fd100FillSource_CHEM)) then
      &fd100cmdOns = &fd100cmd
    elsif ((&fd100cmd_cip_msg = 0) AND (&fd100FillSource = fd100FillSource_MANCHEM)) then
      &fd100cmdOns = &fd100cmd 
    endif
  

  case  fd100cmd_DRAIN:
    if (&fd100cmd_DRAIN_msg = 0) then
      &fd100cmdOns = &fd100cmd
    endif
  

  case  fd100cmd_STORE:
    if (&fd100cmd_STORE_msg = 0) then
      &fd100cmdOns = &fd100cmd
    endif
  

  default:
    &fd100cmdOns = &fd100cmd

endsel
 
&fd100cmd = fd100cmd_noAction



// ******************
// Step Transisitions
// ******************


&tempStepNum = &fd100StepNum
select &tempStepNum

 case  fd100StepNum_RESET: //*** Powerup and Reset State
  &tempStepNum = fd100StepNum_WAITINS


 case fd100StepNum_WAITINS: //*** Awaiting Instruction From RPi
  IF (&fd100cmdOns=fd100cmd_PB) THEN
   &tempStepNum = fd100StepNum_PB 
  ENDIF
  IF (&fd100cmdOns=fd100cmd_RECIRC) THEN
   &tempStepNum = fd100StepNum_FILL 
  ENDIF
  IF ((&fd100cmdOns=fd100cmd_DRAIN) AND (|PS01_I = ON)) THEN
   &tempStepNum = fd100StepNum_MT2WASTE 
  ENDIF
  IF ((&fd100cmdOns=fd100cmd_DRAIN) AND (|PS01_I = OFF)) THEN
   &tempStepNum = fd100StepNum_DRAIN2WASTE 
  ENDIF
  IF ((&fd100cmdOns=fd100cmd_STORE) AND (|PS01_I = ON)) THEN
   &tempStepNum = fd100StepNum_MT2STORE 
  ENDIF
  IF ((&fd100cmdOns=fd100cmd_STORE) AND (|PS01_I = OFF)) THEN
   &tempStepNum = fd100StepNum_DRAIN2STORE 
  ENDIF 

  // If we're changing states, start the logging timer
  if &tempStepNum != fd100StepNum_WAITINS then
   &fd100LogTimeAcc_s10 = 0
   &fd100LogTimeAcc_m = 0
  endif
   
 
 case fd100StepNum_PB: //*** Awaiting Start From Pushbutton
  IF (&PB01State=PB01Pressed) THEN
   // Log the start event
   &EventID = EventID_STARTED
   force_log
   &EventID = EventID_NONE

   // Move to END state to signal that the pushbutton has been pressed, 
   // and we're ready to go to the next step
   &tempStepNum = fd100StepNum_END 
  ENDIF
  //If Stop Command from RPi then go back to waiting for new instruction  
  IF (&fd100cmdOns=fd100cmd_stop) THEN
   gosub logStopEvent
   &tempStepNum = fd100StepNum_WAITINS 
  ENDIF
  //If PB01 not push within a time period go back to waiting for new instruction
  IF ((&fd100StepTimeAcc_m >= &fd100StepTimePre_PB_m) AND (&fd100StepTimeAcc_s10 >= &fd100StepTimePre_PB_s10)) THEN
   &tempStepNum = fd100StepNum_WAITINS  
  ENDIF
  gosub checkForAbort
 
  
 case fd100StepNum_END: //Wait for ACK from RPi
  //If Ack Command from RPi then go back to waiting for new instruction  
  IF (&fd100cmdOns=fd100cmd_ACK) THEN
   &tempStepNum = fd100StepNum_WAITINS 
  ENDIF
  //If Stop Command from RPi then go back to waiting for new instruction  
  IF (&fd100cmdOns=fd100cmd_stop) THEN
   gosub logStopEvent
   &tempStepNum = fd100StepNum_WAITINS 
  ENDIF
  //If Abort Command from RPi then go back to waiting for new instruction  
  gosub checkForAbort


 case fd100StepNum_FILL: //Fill Feedtank
  //Start Recirc After Feedtank reaches min level. 
  IF ((&LT01_100 > (&LT01SP03 + &LT01SP04))\
   AND ((&fd100FillSource != fd100FillSource_TANK)\
    OR ((&fd100StepTimeAcc_m >= &fd100StepTimePre_FILL_m)\
     AND (&fd100StepTimeAcc_s10 >= &fd100StepTimePre_FILL_s10)))) THEN  
   &tempStepNum = fd100StepNum_MIX 
  ENDIF
  IF (&fd100cmdOns=fd100cmd_stop) THEN
   gosub logStopEvent
   &tempStepNum = fd100StepNum_END 
  ENDIF
  gosub checkForAbort


 case fd100StepNum_MIX: //Mix Via Bypass Line
  // Stop Recirculation if level drops too low. 
  IF (&LT01_100 < (&LT01SP03 - &LT01SP04)) THEN
   &tempStepNum = fd100StepNum_FILL 
  ENDIF
  // Mix Time Before Recirculating through HOF
  IF &fd100StepTimeAcc_m >= &fd100StepTimePre_MIX_m\
  AND &fd100StepTimeAcc_s10 >= &fd100StepTimePre_MIX_s10\
  AND &fd100StepTimePre_MIX_s10 >= 0\
  AND |fd102_fd100_dosingChem=OFF\
  AND (    (&fd100Temperature = fd100Temperature_HEAT AND &TT01_100 > &TT01SP01)\
        OR (&fd100Temperature = fd100Temperature_COOL AND &TT01_100 < &TT01SP01)\
        OR (&fd100Temperature = fd100Temperature_NONE)\
       ) THEN
    &tempStepNum = fd100StepNum_RECIRC  
  ENDIF
  // Stop Production or CIP Chemical Wash  
  IF (&fd100cmdOns=fd100cmd_stop) THEN
   gosub logStopEvent
   &tempStepNum = fd100StepNum_END 
  ENDIF
  gosub checkForAbort


 case fd100StepNum_RECIRC: //Production or CIP Chemical Wash - Recirc To Mix
  //Stop Recirculation if level drops too low. 
  IF (&LT01_100 < (&LT01SP03 - &LT01SP04)) THEN
   &tempStepNum = fd100StepNum_FILL 
  ENDIF
  //Stop Recirculation and return to Mix if dosing Chemical. 
  IF (|fd102_fd100_dosingChem=ON) THEN
   &tempStepNum = fd100StepNum_MIX 
  ENDIF
  //Recirculation Time Before Concentrating through HOF ... If _s10 < 0  then don't go to CONC
  IF ((&fd100StepTimeAcc_m >= &fd100StepTimePre_RECIRC_m)\
   AND (&fd100StepTimeAcc_s10 >= &fd100StepTimePre_RECIRC_s10)\
   AND (&fd100StepTimePre_RECIRC_s10 >= 0)) THEN
    &tempStepNum = fd100StepNum_CONC  
  ENDIF
  //Total Production or CIP Chemical Wash Time Before Stopping ... If _s10 < 0  then ignore
  IF ((&fd100TimeAcc_RECIRC_m >= &fd100TimePre_RECIRC_m)\
   AND (&fd100TimeAcc_RECIRC_s10 >= &fd100TimePre_RECIRC_s10)\
   AND (&fd100TimePre_RECIRC_s10 >= 0)) THEN
    &tempStepNum = fd100StepNum_END  
  ENDIF  
  //Stop Production or CIP Chemical Wash  
  IF (&fd100cmdOns=fd100cmd_stop) THEN
   &tempStepNum = fd100StepNum_END 
  ENDIF
  gosub checkForAbort
  

 case  fd100StepNum_CONC: //Production - Circulate through filter
  //Stop Concentration if level drops too low. 
  IF (&LT01_100 < (&LT01SP03 - &LT01SP04)) THEN
   &tempStepNum = fd100StepNum_FILL 
  ENDIF
  //Total Production Time Before Stopping ... If _s10 < 0  then ignore
  IF ((&fd100TimeAcc_RECIRC_m >= &fd100TimePre_RECIRC_m)\
   AND (&fd100TimeAcc_RECIRC_s10 >= &fd100TimePre_RECIRC_s10)\
   AND (&fd100TimePre_RECIRC_s10 >= 0)) THEN
    &tempStepNum = fd100StepNum_MT2SITE  
  ENDIF  
  IF (&fd100cmdOns=fd100cmd_stop) THEN
   gosub logStopEvent
   &tempStepNum = fd100StepNum_MT2SITE 
  ENDIF
  gosub checkForAbort
   

 case fd100StepNum_MT2SITE: //Production - Empty Feedtank To Site
  //Feed Tank Reached Min Level. 
  IF (&LT01_100 < &LT01SP05) THEN
   &tempStepNum = fd100StepNum_END
  ENDIF
  gosub checkForAbort
  

 case fd100StepNum_MT2WASTE: //Production or CIP Chemical Wash - Pump Feedtank To Drain
  //Feed Tank Reached Empty Level. 
  IF (&LT01_100 < &LT01SP06) THEN
   &tempStepNum = fd100StepNum_DRAIN2WASTE
  ENDIF
  gosub checkForAbort
  

 case fd100StepNum_DRAIN2WASTE: //Production or CIP Chemical Wash - Drain Plant
  //Drain Plant Time
  IF ((&fd100StepTimeAcc_m >= &fd100StepTimePre_DRAIN_m)\
   AND (&fd100StepTimeAcc_s10 >= &fd100StepTimePre_DRAIN_s10)) THEN
    &tempStepNum = fd100StepNum_END  
  ENDIF
  gosub checkForAbort
  

 case fd100StepNum_MT2STORE: //Production or CIP Chemical Wash - Pump Feedtank To Drain
  //Feed Tank Reached Empty Level. 
  IF (&LT01_100 < &LT01SP06) THEN
   &tempStepNum = fd100StepNum_DRAIN2STORE
  ENDIF
  gosub checkForAbort
  

 case fd100StepNum_DRAIN2STORE: //Production or CIP Chemical Wash - Drain Plant
  //Drain Plant Time
  IF ((&fd100StepTimeAcc_m >= &fd100StepTimePre_DRAIN_m)\
   AND (&fd100StepTimeAcc_s10 >= &fd100StepTimePre_DRAIN_s10)) THEN
    &tempStepNum = fd100StepNum_END  
  ENDIF
  gosub checkForAbort
   

 default:
  &tempStepNum = fd100StepNum_RESET
endsel



// **********************
// One-shot (ONS) Actions
// **********************

// These actions only occur as the state is changing.  They do not
// occur every scan.

IF (&tempStepNum != &fd100StepNum) THEN
 &fd100StepNum = &tempStepNum
 &fd100StepTimeAcc_s10 = 0
 &fd100StepTimeAcc_m = 0 

 select &tempStepNum
  case fd100StepNum_RESET: //Powerup and Reset State
   // Reset FT02's over-max-flow timer
   &FT02_OverMaxFlowTimeAcc_s10 = 0
   &FT02_OverMaxFlowTimeAcc_m = 0

   // Reset FT03's over-max-flow timer
   &FT03_OverMaxFlowTimeAcc_s10 = 0
   &FT03_OverMaxFlowTimeAcc_m = 0
  

  case fd100StepNum_WAITINS: //Awaiting Instruction
   &fd100TimeAcc_RECIRC_s10 = 0
   &fd100TimeAcc_RECIRC_m = 0
  
   // Disable timer-based logging while awaiting instruction
   &fd100LogTimeAcc_s10 = -10



  case fd100StepNum_PB: //Awaiting Pushbutton
  

  case fd100StepNum_END: //End wait for Acknowledgement from RPi  
   // Log the fact that we've finished whatever we were doing
   &EventID = EventID_FINISHED
   force_log
   &EventID = EventID_NONE
   
  

  case fd100StepNum_FILL: //Production or CIP Chemical Wash - Fill Feedtank
   // Log the fact that filling's started
   &EventID = EventID_FILLING_STARTED
   force_log
   &EventID = EventID_NONE
   
   &PC05cv=&PC05cv01 //Open CV01 to enable recirc
   &fd100_LT01max = 0 

   

  case fd100StepNum_MIX: //Production or CIP Chemical Wash - Mix Via Bypass Line
   // Log the fact that mixing's started
   &EventID = EventID_MIXING_STARTED
   force_log
   &EventID = EventID_NONE

   &DPC01cv=&DPC01cv01 // Set PC01sp to control the speed of the Main Feed Pump
   &PC01cv=&PC01cv01   // Set Initial the speed of the Main Feed Pump
   if (&fd100FillSource = fd100FillSource_NONE) then
    &fd100Status = fd100Status_PROD_FULL //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_SITE) then
    &fd100Status = fd100Status_PROD_FULL //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_WATER) then
    &fd100Status = fd100Status_RINSE_FULL //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_CHEM) then
    &fd100Status = fd100Status_CIP_FULL //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_MANCHEM) then
    &fd100Status = fd100Status_CIP_FULL //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_TANK) then
    &fd100Status = fd100Status_UNKNOWN //Set Plant Status
   endif   



  case fd100StepNum_RECIRC: //Production or CIP Chemical Wash - Recirc through filter
   // Log the fact that recirc's started
   &EventID = EventID_RECIRC_STARTED
   force_log
   &EventID = EventID_NONE

   // Set up the PID controllers for Recirc 
   &DPC01spRampTarget = &DPC01sp01
   &PC05spRampTarget  = &PC05sp01
   &PC03spRampTarget  = &PC03sp01 // Backwash target pressure 
   &PC03cv            = &PC03cv01 // Backwash's starting position
    

  case fd100StepNum_CONC: //Production - Concentrate
   // Log the fact that recirc's started
   &EventID = EventID_CONC_STARTED
   force_log
   &EventID = EventID_NONE

   &RC01cv           = &RC01cv01 //Concentration Ratio Starting Value
   &RC01spRampTarget = &RC01sp01 //Concentration Ratio
   

  case fd100StepNum_MT2SITE: //Production - Empty Feedtank To Site
   // Log the fact that we've started emptying to site
   &EventID = EventID_MT2SITE_STARTED
   force_log
   &EventID = EventID_NONE
  

  case fd100StepNum_MT2WASTE: //Production or CIP Chemical Wash - Pump Feedtank To Drain 
   // Log the fact that we've started pumping to drain
   &EventID = EventID_MT2WASTE_STARTED
   force_log
   &EventID = EventID_NONE

   &PC01cv=&PC01cv02
   

  case fd100StepNum_DRAIN2WASTE: //Production or CIP Chemical Wash - Empty Feedtank To Drain
   // Log the fact that we've started passive draining
   &EventID = EventID_DRAIN2WASTE_STARTED
   force_log
   &EventID = EventID_NONE

   if (&fd100FillSource = fd100FillSource_NONE) then
    &fd100Status = fd100Status_PROD_MT //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_SITE) then
    &fd100Status = fd100Status_PROD_MT //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_WATER) then
    &fd100Status = fd100Status_RINSE_MT //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_CHEM) then
    &fd100Status = fd100Status_CIP_MT //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_MANCHEM) then
    &fd100Status = fd100Status_CIP_MT //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_TANK) then
    &fd100Status = fd100Status_UNKNOWN //Set Plant Status
   endif 


  case fd100StepNum_MT2STORE: //Production or CIP Chemical Wash - Pump Feedtank To Drain 
   // Log the fact that we've started passive draining
   &EventID = EventID_MT2STORE_STARTED
   force_log
   &EventID = EventID_NONE

   &PC01cv=&PC01cv02
   

  case fd100StepNum_DRAIN2STORE: //Production or CIP Chemical Wash - Empty Feedtank To Drain
   // Log the fact that we've started passive draining
   &EventID = EventID_DRAIN2STORE_STARTED
   force_log
   &EventID = EventID_NONE

   if (&fd100FillSource = fd100FillSource_NONE) then
    &fd100Status = fd100Status_PROD_MT //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_SITE) then
    &fd100Status = fd100Status_PROD_MT //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_WATER) then
    &fd100Status = fd100Status_RINSE_MT //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_CHEM) then
    &fd100Status = fd100Status_CIP_MT //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_MANCHEM) then
    &fd100Status = fd100Status_CIP_MT //Set Plant Status
   endif
   if (&fd100FillSource = fd100FillSource_TANK) then
    &fd100Status = fd100Status_UNKNOWN //Set Plant Status
   endif     
         
  default:

 endsel
ENDIF



// ************
// Step Actions
// ************

select &tempStepNum
 case fd100StepNum_RESET: //Powerup and Reset State
  &V1x_last = 0.0
  &R01_last = 1.0
  &R01 = 1.0
  

 case fd100StepNum_WAITINS: //Awaiting Instruction
  &V1x_last = 0.0
  &R01_last = 1.0
  &R01 = 1.0 
 

 case fd100StepNum_PB: //Awaiting Pushbutton
  &V1x_last = 0.0
  &R01_last = 1.0
  &R01 = 1.0 
  &fd100StepTimeAcc_s10 = &fd100StepTimeAcc_s10 + &lastScanTimeShort
  |fd100_IL01waiting = ON //PB01 LED Light To flash to incidate wait condition
  

 case fd100StepNum_END: //End wait for Acknowledgement from RPi
  &V1x_last = 0.0
  &R01_last = 1.0
  &R01 = 1.0   
  

 case fd100StepNum_FILL: //Production or CIP Chemical Wash - Fill Feedtank
   if ((&LT01_100 <= &fd100_LT01max + 100) AND (|fd100Fault_fd100_Pause=OFF)) then // 100 = 1%
    &fd100StepTimeAcc_s10 = &fd100StepTimeAcc_s10 + &lastScanTimeShort
   else
    &fd100_LT01max = &LT01_100
    &fd100StepTimeAcc_s10 = 0
    &fd100StepTimeAcc_m = 0
   endif 
  |fd100_fd100Fault_enable1 = ON
  |fd100_fd100Fault_FILL = ON
  |fd100_DV06en1 = ON //Energise If Fill Source is WATER  
  |fd100_IL01 = ON //PB01 LED Light
  |fd100_IV08en1 = ON //Energise If Fill Source is SITE and Level Low 
  |fd100_IV10en1 = ON //Energise If Fill Source is WATER and Level Low 
  |fd100_IV15 = ON //Seal Water
  |fd100_PP03en1 = ON //Fill from Storage Tank 
  |fd100_PC05so = ON //Open CV01 to enable recirc
 

 case fd100StepNum_MIX: //Production or CIP Chemical Wash - Mix Via Bypass Line
  if (|fd100Fault_fd100_Pause=OFF) then
   if (&fd100StepTimePre_MIX_s10 >= 0) then
    &fd100StepTimeAcc_s10 = &fd100StepTimeAcc_s10 + &lastScanTimeShort
   else
    &fd100StepTimeAcc_s10 = 0
    &fd100StepTimeAcc_m = 0
   endif 
  endif 
  |fd100_fd100Fault_enable1 = ON
  |fd100_DV06en1 = ON        // Energise if Fill Source is WATER  
  |fd100_IL01 = ON           // PB01 LED Light
  |fd100_IV08en1 = ON        // Energise if Fill Source is SITE and Level Low 
  |fd100_IV10en1 = ON        // Energise if Fill Source is WATER and Level Low 
  |fd100_IV15 = ON           // Seal Water
  |fd100_PP01 = ON           // Run Pump
  |fd100_DPC01so = ON        // Set SP of HOF Filter Inlet Pressure Control Loop
  |fd100_PC01pidEn1 = ON     // HOF Filter Inlet Pressure Control Loop
  |fd100_PC05so = ON         // Open CV01 to enable recirc
  |fd100Temperatureen1 = ON  // Cool or Heat As Selected
  |fd100_fd102_chemdoseEn1 = ON // Dose Chemical if CIP


 case fd100StepNum_RECIRC: //Production or CIP Chemical Wash - Recirc through filter
  if (|fd100Fault_fd100_Pause=OFF) then
   if (&fd100StepTimePre_RECIRC_s10 >= 0) then
    &fd100StepTimeAcc_s10 = &fd100StepTimeAcc_s10 + &lastScanTimeShort
   else
    &fd100StepTimeAcc_s10 = 0
    &fd100StepTimeAcc_m = 0
   endif
   if (&fd100TimePre_RECIRC_s10  >= 0) then
    &fd100TimeAcc_RECIRC_s10 = &fd100TimeAcc_RECIRC_s10 + &lastScanTimeShort
   else
    &fd100TimeAcc_RECIRC_s10 = 0
    &fd100TimeAcc_RECIRC_m = 0
   endif
  endif 
  |fd100_fd100Fault_enable1 = ON
  |fd100_DV06en1 = ON //Energise If Fill Source is WATER  
  |fd100_IL01 = ON //PB01 LED Light
  |fd100_IV08en1 = ON //Energise If Fill Source is SITE and Level Low 
  |fd100_IV10en1 = ON //Energise If Fill Source is WATER and Level Low 
  |fd100_IV15 = ON //Seal Water
  |fd100_PP01 = ON //Run Pump
  |fd100_DPC01pidEn1 = ON //HOF Differential Pressure Control Loop
  |fd100_PC01pidEn1 = ON //HOF Inlet Pressure Control Loop
  |fd100_PC03pid = ON //Backwash Pressure Control Loop
  |fd100_PC05pidEn1 = ON //Trans Membrane Pressure Control Loop
  |fd100Temperatureen1 = ON //Cool or Heat As Selected 
  |fd100_fd101_recirc = ON //Start Route Sequence
  |fd100_fd102_chemdoseEn1 = ON //Dose Chemical If CIP
  
    
 case fd100StepNum_CONC: //Production - Concentrate
  if (|fd100Fault_fd100_Pause=OFF) then
   if (&fd100TimePre_RECIRC_s10  >= 0) then
    &fd100TimeAcc_RECIRC_s10 = &fd100TimeAcc_RECIRC_s10 + &lastScanTimeShort
   else
    &fd100TimeAcc_RECIRC_s10 = 0
    &fd100TimeAcc_RECIRC_m = 0
   endif
  endif  
  |fd100_fd100Fault_enable1 = ON
  |fd100_DV04 = ON //Permeate To Site
  |fd100_DV06en1 = ON //Energise If Fill Source is WATER via CIP  
  |fd100_IL01 = ON //PB01 LED Light
  |fd100_IV07 = ON //Retentate To Site
  |fd100_IV08en1 = ON //Energise If Fill Source is SITE and Level Low   
  |fd100_IV10en1 = ON //Energise If Fill Source is WATER via CIP and Level Low  
  |fd100_IV15 = ON //Seal Water
  |fd100_PP01 = ON //Run Pump
  |fd100_DPC01pidEn1 = ON //HOF Differential Pressure Control Loop
  |fd100_PC01pidEn1 = ON //HOF Inlet Pressure Control Loop
  |fd100_PC03pid = ON //Backwash Pressure Control Loop
  |fd100_PC05pidEn1 = ON //Trans Membrane Pressure Control Loop
  |fd100_RC01pidEn1 = ON //Concetration Ratio Control Loop
  |fd100Temperatureen1 = ON //Cool or Heat As Selected 
  |fd100_fd101_recirc = ON //Start Route Sequence

  // Check if we're over FT02's max flow rate
  if (&FT02_100 > FT02_EUMax * FT02_EUMultiplier) then
    // Increment timer
    &FT02_OverMaxFlowTimeAcc_s10 = &FT02_OverMaxFlowTimeAcc_s10 + &lastScanTimeShort
  endif

  // Check if we're over FT03's max flow rate
  if (&FT03_100 > FT03_EUMax * FT03_EUMultiplier) then
    // Increment timer
    &FT03_OverMaxFlowTimeAcc_s10 = &FT03_OverMaxFlowTimeAcc_s10 + &lastScanTimeShort
  endif
    

 case fd100StepNum_MT2SITE: //Production - Empty Feedtank To Site
  |fd100_fd100Fault_enable1 = ON
  |fd100_DV04 = ON //Permeate To Site  
  |fd100_IL01 = ON //PB01 LED Light
  |fd100_IV07 = ON //Retentate To Site 
  |fd100_IV15 = ON //Seal Water
  |fd100_PP01 = ON //Run Pump
  |fd100_DPC01pidEn1 = ON //HOF Differential Pressure Control Loop
  |fd100_PC01pidEn1 = ON //HOF Inlet Pressure Control Loop
  |fd100_PC03pid = ON //Backwash Pressure Control Loop
  |fd100_PC05pidEn1 = ON //Trans Membrane Pressure Control Loop
  |fd100_RC01pidEn1 = ON //Concetration Ratio Control Loop
  |fd100Temperatureen1 = ON //Cool or Heat As Selected 
  |fd100_fd101_recirc = ON //Start Route Sequence 
   

 case fd100StepNum_MT2WASTE: //Production or CIP Chemical Wash - Pump Feedtank To Drain
  |fd100_fd100Fault_enable1 = ON  
  |fd100_IL01 = ON //PB01 LED Light 
  |fd100_IV15 = ON //Seal Water
  |fd100_PP01 = ON //Run Pump 
  |fd100_PC01so = ON
  |fd100_fd101_drain = ON //Cycle Filter Valves to Drain
  &V1x_last = 0.0
  &R01_last = 1.0
  &R01 = 1.0  
  

 case fd100StepNum_DRAIN2WASTE: //Production or CIP Chemical Wash - Empty Feedtank To Drain
  IF (&LT01_100 < &LT01SP06) THEN
   &fd100StepTimeAcc_s10 = &fd100StepTimeAcc_s10 + &lastScanTimeShort
  ELSE
   &fd100StepTimeAcc_s10 = 0
   &fd100StepTimeAcc_m = 0 
  ENDIF
  |fd100_fd101_drain = ON //Cycle Filter Valves to Drain   
  &V1x_last = 0.0
  &R01_last = 1.0
  &R01 = 1.0
  

 case fd100StepNum_MT2STORE: //Production or CIP Chemical Wash - Pump Feedtank To Store
  |fd100_DV05 = ON
  |fd100_fd100Fault_enable1 = ON  
  |fd100_IL01 = ON //PB01 LED Light 
  |fd100_IV15 = ON //Seal Water
  |fd100_PP01 = ON //Run Pump 
  |fd100_PC01so = ON
  |fd100_fd101_drain = ON //Cycle Filter Valves to Drain
  &V1x_last = 0.0
  &R01_last = 1.0
  &R01 = 1.0  
  

 case fd100StepNum_DRAIN2STORE: //Production or CIP Chemical Wash - Empty Feedtank To Store
  IF (&LT01_100 < &LT01SP06) THEN
   &fd100StepTimeAcc_s10 = &fd100StepTimeAcc_s10 + &lastScanTimeShort
  ELSE
   &fd100StepTimeAcc_s10 = 0
   &fd100StepTimeAcc_m = 0 
  ENDIF
  |fd100_DV05 = ON
  |fd100_fd101_drain = ON //Cycle Filter Valves to Drain   
  &V1x_last = 0.0
  &R01_last = 1.0
  &R01 = 1.0
     
 default:

endsel



// *************
// Timer Updates
// *************

//Step Timer Update Minutes when seconds greater than 59.9s
if (&fd100StepTimeAcc_s10 > 599) then
  &fd100StepTimeAcc_s10 = &fd100StepTimeAcc_s10 - 600
  &fd100StepTimeAcc_m = &fd100StepTimeAcc_m + 1
endif
if (&fd100StepTimeAcc_m > 32000) then
  &fd100StepTimeAcc_m = 32000
endif

//Production Timer Update Minutes when seconds greater than 59.9s
if (&fd100TimeAcc_RECIRC_s10 > 599) then
  &fd100TimeAcc_RECIRC_s10 = &fd100TimeAcc_RECIRC_s10 - 600
  &fd100TimeAcc_RECIRC_m = &fd100TimeAcc_RECIRC_m + 1
endif
if (&fd100TimeAcc_RECIRC_m > 32000) then
  &fd100TimeAcc_RECIRC_m = 32000
endif

// FT02's over-max-flow timer, update minutes when seconds greater than 59.9s
if (&FT02_OverMaxFlowTimeAcc_s10 > 599) then
  &FT02_OverMaxFlowTimeAcc_s10 = &FT02_OverMaxFlowTimeAcc_s10 - 600
  &FT02_OverMaxFlowTimeAcc_m = &FT02_OverMaxFlowTimeAcc_m + 1
endif
if (&FT02_OverMaxFlowTimeAcc_m > 32000) then
  &FT02_OverMaxFlowTimeAcc_m = 32000
endif

// FT03's over-max-flow timer, update minutes when seconds greater than 59.9s
if (&FT03_OverMaxFlowTimeAcc_s10 > 599) then
  &FT03_OverMaxFlowTimeAcc_s10 = &FT03_OverMaxFlowTimeAcc_s10 - 600
  &FT03_OverMaxFlowTimeAcc_m = &FT03_OverMaxFlowTimeAcc_m + 1
endif
if (&FT03_OverMaxFlowTimeAcc_m > 32000) then
  &FT03_OverMaxFlowTimeAcc_m = 32000
endif

// Logging timer, update minutes when seconds greater than 59.9s
if (&fd100LogTimeAcc_s10 > 599) then
  &fd100LogTimeAcc_s10 = &fd100LogTimeAcc_s10 - 600
  &fd100LogTimeAcc_m = &fd100LogTimeAcc_m + 1
endif
if (&fd100LogTimeAcc_m > 32000) then
  &fd100LogTimeAcc_m = 32000
endif



// *******************
// Fault Monitor Logic
// *******************

// Clear the fault message if the push button has been pressed to restart
// the plant, or if the fault message should be off.
&OPmsg = &fd100Faultcmd_resetMsg
if (|fd100Fault_PB01toRestart = ON and &PB01State=PB01Pressed)\
or |fd100Fault_msg1 = OFF then
  &OPmsg = 0
endif


// Check for possible fault conditions
if (|fd100Fault_msg1 = ON) then
  IF (|PP01motFault = ON) THEN
    // Fault on the main pump
    &OPmsg = 1
  ELSIF ((|fd100Fault_PB01toPause = ON) AND (&PB01State=PB01Pressed)) THEN
    // The push button has been pressed to pause the plant
    &OPmsg = 2
  ELSIF ((|ES01_I1 = OFF) OR (|ES01_I2 = ON)) THEN
    // The emergency stop has been pressed
    &OPmsg = 3
  ELSIF (|PS01_I = OFF) THEN
    // Insufficient water pressure
    &OPmsg = 4
  ELSIF (|PS02_I = OFF) THEN
    // Insufficient high-pressure compressed air
    &OPmsg = 5
  ELSIF (|PS03_I = OFF) THEN
    // Insufficient low-pressure compressed air
    &OPmsg = 6
  ELSIF ((|FS01_I = OFF) AND (|PP01out = ON)) THEN
    // No seal water on the main pump and the main pump is running
    &OPmsg = 7
  ELSIF ((|fd100Fault_PB01toPause = ON) AND (&fd100cmdOns=fd100cmd_PAUSE)) THEN
    // Pause instruction received
    &OPmsg = 14
  ELSIF ((|fd100_fd100Fault_FILL = ON)\
  AND (&fd100StepTimeAcc_m >= &fd100StepTimePre_FILL_m)\
  AND (&fd100StepTimeAcc_s10 > &fd100StepTimePre_FILL_s10)\
  AND (&LT01_100 < (&LT01SP03 + &LT01SP04))) THEN
    // While attempting to fill the tank, the level is still too low and
    // we've exhausted the allowed time.
    &OPmsg = 15
  ELSIF (&TT01_100 < &TT01SP03) THEN
    // The feed tank's temperature is too low
    &OPmsg = 16
  ELSIF (&TT01_100 > &TT01SP04) THEN
    // The feed tank's temperature is too high 
    &OPmsg = 17
  ELSIF (&PT01_1000 > &PT01SP01) THEN
    // The inlet pressure to the membrane is too high
    &OPmsg = 18
  ELSIF (&PT05_1000 > &PT05SP01) THEN
    // The transmembrane pressure is too high
    &OPmsg = 19
  ELSIF (&PT03_1000 > &PT03SP01) THEN
    // The backwash pressure is too high
    &OPmsg = 20
  ELSIF (&DPT01_1000 > &DPT01SP01) THEN
    // Along membrane pressure too high
    &OPmsg = 21
  ELSIF (&PH01_100 < &PH01SP01) THEN
    // pH is too low
    &OPmsg = 22
  ELSIF (&PH01_100 > &PH01SP02) THEN
    // pH is too high
    &OPmsg = 23                  
  ENDIF
 
endif



// Check if the fault has changed since last time, logging if changed,
// and set the new fault message (the reason why a fault occurred).
if &fd100Faultcmd_resetMsg != &OPmsg then
  gosub logFaultEvent   
  &fd100Faultcmd_resetMsg = &OPmsg
else
  &fd100Faultcmd_resetMsg = &OPmsg
endif



// Selection From RPi
&fd100FaultcmdOns = &fd100Faultcmd 
&fd100Faultcmd = fd100Faultcmd_NO_ACTION


// Process instruction
&tempStepNum = &fd100FaultStepNum
select &fd100FaultcmdOns

  case fd100Faultcmd_ENABLE_FAULTS:
    // Enable fault checking
    if &fd100FaultStepNum = fd100Fault_disabled then
      &tempStepNum = fd100Fault_reset
    endif  
     
    
  case fd100Faultcmd_DISABLE_FAULTS:
    // Disable fault checking 
    &tempStepNum = fd100Fault_disabled 
    

  default:
    // Do nothing

endsel

// Clear Sequence Outputs... these are then set on below
&fd100FaultProgOut01 = 0

// Step Transistions
select &tempStepNum 

  case fd100Fault_reset:
    IF (|fd100_fd100Fault_enable1 = ON) THEN
      &tempStepNum = fd100Fault_monitor1 
    ENDIF  


  case fd100Fault_monitor1:
    IF (|fd100_fd100Fault_enable1 = OFF) THEN
      &tempStepNum = fd100Fault_reset 
    ENDIF
    IF (&fd100Faultcmd_resetMsg > 0) THEN
      &tempStepNum = fd100Fault_action1 
    ENDIF  


  case fd100Fault_action1:
    IF (|fd100_fd100Fault_enable1 = OFF) THEN
      &tempStepNum = fd100Fault_reset 
    ENDIF
    IF ((&fd100Faultcmd_resetMsg = 0) AND (&PB01State=PB01Pressed)) THEN
      &tempStepNum = fd100Fault_monitor1 
    ENDIF 


  case fd100Fault_disabled:
    // Do nothing 


 default:
   &tempStepNum = fd100Fault_reset

endsel

//Step Ons Actions
IF (&tempStepNum != &fd100FaultStepNum) THEN
  &fd100FaultStepNum = &tempStepNum 

  select &tempStepNum

    case fd100Fault_reset:


    case fd100Fault_monitor1:


    case fd100Fault_action1:         
      // Do nothing (fault logging occurs above)
      
    case fd100Fault_disabled:
      // Do nothing

    default:
      // Do nothing

  endsel
ENDIF

//Step Actions
select &tempStepNum

  case fd100Fault_reset:
 

  case fd100Fault_monitor1:
    |fd100Fault_msg1 = ON
    |fd100Fault_PB01toPause = ON


  case fd100Fault_action1:
    |fd100Fault_IL01fault = ON //PB01 LED Light To flash to incidate fault 
    |fd100Fault_msg1 = ON
    |fd100Fault_PB01toRestart = ON  
    |fd100Fault_PP01pause = ON
    |fd100Fault_PP03pause = ON
    |fd100Fault_DPC01pidHold = ON
    |fd100Fault_PC01pidHold = ON
    |fd100Fault_PC05pidHold = ON
    |fd100Fault_RC01pidHold = ON
    |fd100Fault_temperatureHold = ON
    |fd100Fault_fd100_Pause = ON
    |fd100Fault_fd101_Pause = ON
    |fd100Fault_fd102_Pause = ON


  case fd100Fault_disabled:
    // Do nothing 

           
 default:
 
endsel


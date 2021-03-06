//FD102 CIP Chemical Dose Sequence

// Automatically-dosing the chemical consists of operating the dosing pump for 
// a given length of time and then purging the line with a shot of water.

//Clear Sequence Outputs... these are then set on below
&fd102ProgOut01 = 0
&tempStepNum = &fd102StepNum

// ******************
// Step Transisitions
// ******************

select &tempStepNum
  case  fd102StepNum_RESET:
    if ((|fd100_fd102_chemdoseEn1 = ON)\
    and (&fd100FillSource = fd100FillSource_AUTO_CHEM)) then
      &tempStepNum = fd102StepNum_CHECK_PH
    endif


  case  fd102StepNum_CHECK_PH:
    if &fd102_pHDesired = -1 then
      // No pH checking is desired
      &tempStepNum = fd102StepNum_END

    else       
      // Wait for the specified length of time
      if ((&fd102StepTimeAcc_m >= &fd102StepTimePre_CHECK_PH_m) \
      and (&fd102StepTimeAcc_s10 >= &fd102StepTimePre_CHECK_PH_s10)) then
        // Check if the pH has reached the threshold
        if &PH01_100 >= &fd102_pHDesired then
          // We have reached the threshold, stay here but reset step timer
          &fd102StepTimeAcc_m = 0
          &fd102StepTimeAcc_s10 = 0          
        else
          &tempStepNum = fd102StepNum_DOSE_CHEM
        endif
        
      endif       
    endif

    // Check if we've effectively been asked to stop
    if ((|fd100_fd102_chemdoseEn1 = OFF)\
    or (&fd100FillSource != fd100FillSource_AUTO_CHEM)) then
      &tempStepNum = fd102StepNum_WASH
    endif
  

  case  fd102StepNum_DOSE_CHEM:
    // If we've spent enough time here, go to line-purging
    if ((&fd102StepTimeAcc_m >= &fd102StepTimePre_DOSE_CHEM_m) \
    and (&fd102StepTimeAcc_s10 >= &fd102StepTimePre_DOSE_CHEM_s10)) then
      &tempStepNum = fd102StepNum_PURGE
    endif

    // Check if we've effectively been asked to stop
    if ((|fd100_fd102_chemdoseEn1 = OFF)\
    or (&fd100FillSource != fd100FillSource_AUTO_CHEM)) then
      &tempStepNum = fd102StepNum_WASH
    endif
  

  case  fd102StepNum_PURGE:
    if ((&fd102StepTimeAcc_m >= &fd102StepTimePre_PURGE_m) \
    and (&fd102StepTimeAcc_s10 >= &fd102StepTimePre_PURGE_s10)) then
      &tempStepNum = fd102StepNum_CHECK_PH
    endif
    if ((|fd100_fd102_chemdoseEn1 = OFF)\
    or (&fd100FillSource != fd100FillSource_AUTO_CHEM)) then
      &tempStepNum = fd102StepNum_WASH
    endif


  case  fd102StepNum_WASH:
    // If we've spent enough time washing, go to End
    if ((&fd102StepTimeAcc_m >= &fd102StepTimePre_WASH_m) \
    and (&fd102StepTimeAcc_s10 >= &fd102StepTimePre_WASH_s10)) then
      &tempStepNum = fd102StepNum_END
    endif


  case  fd102StepNum_END:
    if ((|fd100_fd102_chemdoseEn1 = OFF)\
    or (&fd100FillSource != fd100FillSource_AUTO_CHEM)) then
      &tempStepNum = fd102StepNum_RESET
    endif    
        

  default:
    &tempStepNum = fd102StepNum_RESET

endsel

// **********************
// One-shot (ONS) Actions
// **********************

IF (&tempStepNum != &fd102StepNum) THEN
  &fd102StepNum = &tempStepNum
  &fd102StepTimeAcc_s10 = 0
  &fd102StepTimeAcc_m = 0
  select &tempStepNum
    case  fd102StepNum_RESET:
      &fd102_DoseCount = 0
  
    case  fd102StepNum_DOSE_CHEM:
      &fd102_DoseCount = &fd102_DoseCount + 1
  
    case  fd102StepNum_PURGE:
 
    case  fd102StepNum_WASH:

    case  fd102StepNum_END:         
  
    default:

  endsel
ENDIF

// ************
// Step Actions
// ************

select &tempStepNum
  case  fd102StepNum_RESET:
 
  case  fd102StepNum_CHECK_PH:
    // Increment step timer if we're not paused
    if (|fd100Fault_fd102_Pause=OFF) then
      &fd102StepTimeAcc_s10 = &fd102StepTimeAcc_s10 + &lastScanTimeShort
    endif


  case  fd102StepNum_DOSE_CHEM:
    // Increment step timer if we're not paused
    if (|fd100Fault_fd102_Pause=OFF) then
      &fd102StepTimeAcc_s10 = &fd102StepTimeAcc_s10 + &lastScanTimeShort
    endif

    |fd102_DV06=ON
    |fd102_IV09=ON
    |fd102_PP02=ON
    |fd102_fd100_dosingChem=ON
  

  case  fd102StepNum_PURGE:
    // Increment step timer if we're not paused
    if (|fd100Fault_fd102_Pause=OFF) then
      &fd102StepTimeAcc_s10 = &fd102StepTimeAcc_s10 + &lastScanTimeShort
    endif

    |fd102_DV06=ON
    |fd102_IV10=ON
    |fd102_fd100_dosingChem=ON


  case  fd102StepNum_WASH:
    // Increment step timer if we're not paused
    if (|fd100Fault_fd102_Pause=OFF) then
      &fd102StepTimeAcc_s10 = &fd102StepTimeAcc_s10 + &lastScanTimeShort
    endif
    |fd102_DV06=ON
    |fd102_IV10=ON
    |fd102_fd100_dosingChem=ON
 

  case  fd102StepNum_END:    
         
  default:

endsel

// ****************
// Increment timers
// ****************

if (&fd102StepTimeAcc_s10 > 599) then
  &fd102StepTimeAcc_s10 = 0
  &fd102StepTimeAcc_m = &fd102StepTimeAcc_m + 1
endif
if (&fd102StepTimeAcc_m > 32000) then
  &fd102StepTimeAcc_m = 32000
endif


// **************
// Fault checking
// **************


if &fd102_DoseCount > &fd102_MaxDoseCount then
  // We've exceeded our maximum dose count
  |fd102_fd100_faultDosingChem = ON
endif
 

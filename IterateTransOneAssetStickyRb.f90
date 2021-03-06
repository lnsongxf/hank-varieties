SUBROUTINE IterateTransOneAssetStickyRb

USE Parameters
USE Globals
USE Procedures

IMPLICIT NONE

INTEGER 	:: it,ii,itfg
REAL(8) 	:: ldiffB,lminprice_W,lpvgovbc,lpvlumpincr,linitlumpincr
REAL(8), DIMENSION(Ttransition) :: lbond,lfirmdiscount,lrb,lrb1,lfundbond,lworldbond,lrgov

iteratingtransition = .true.

lminprice_W = 0.01

IF(Display>=1 .and. stickytransition==.true.) write(*,*)' Solving for sticky price transition without ZLB'
IF(Display>=1 .and. zlbtransition==.true.) write(*,*)' Solving for sticky price transition with ZLB'

!forward guidance time
itfg = MINLOC(cumdeltatrans, 1, MASK = cumdeltatrans>=ForwardGuideShockQtrs)

!capital related stuff is zero
equmTRANS(:)%fundbond = 0.0
equmTRANS(:)%caputil = 1.0
equmTRANS(:)%tfpadj = equmTRANS(:)%tfp
equmTRANS(:)%deprec = deprec
equmTRANS(:)%investment = 0.0
equmTRANS(:)%KNratio = 0.0
equmTRANS(:)%KYratio = 0.0
equmTRANS(:)%rcapital = 0.0
equmTRANS(:)%dividend = 0.0
equmTRANS(:)%divrate = 0.0
equmTRANS(:)%ra = 0.0
equmTRANS(:)%equity = 0.0
equmTRANS(:)%illassetdrop = 1.0	


!guess  liquid return
IF(UseFlexTransitionAsGuess==0) THEN


	!construct sequence of guesses of Rb
	IF (monetaryshock==.true.) THEN
		equmTRANS(:)%pi = equmINITSS%pi

		IF(forwardguide==.false.) THEN
			IF(zlbtransition==.false.) equmTRANS(:)%rnom = equmINITSS%rnom +phitaylor*equmTRANS(:)%pi + equmTRANS(:)%mpshock
			IF(zlbtransition==.true.) equmTRANS(:)%rnom = max(equmINITSS%rnom +phitaylor*equmTRANS(:)%pi + equmTRANS(:)%mpshock, 0.0)
					
		ELSE IF(forwardguide==.true. ) THEN
			IF(zlbtransition==.false.) equmTRANS(1:itfg-1)%rnom = equmINITSS%rnom +phifg*equmTRANS(1:itfg-1)%pi + equmTRANS(1:itfg-1)%mpshock
			IF(zlbtransition==.true.) equmTRANS(1:itfg-1)%rnom = max(equmINITSS%rnom +phifg*equmTRANS(1:itfg-1)%pi + equmTRANS(1:itfg-1)%mpshock, 0.0)

			IF(zlbtransition==.false.) equmTRANS(itfg:Ttransition)%rnom = equmINITSS%rnom +phitaylor*equmTRANS(itfg:Ttransition)%pi + equmTRANS(itfg:Ttransition)%mpshock
			IF(zlbtransition==.true.) equmTRANS(itfg:Ttransition)%rnom = max(equmINITSS%rnom +phitaylor*equmTRANS(itfg:Ttransition)%pi + equmTRANS(itfg:Ttransition)%mpshock, 0.0)			
		END IF	
		equmTRANS(:)%rb = equmTRANS(:)%rnom - equmTRANS(:)%pi
	ELSEIF (monetaryshock==.false.) THEN
		equmTRANS(:)%rb = equmINITSS%rb		
	END IF
	
ELSE IF(UseFlexTransitionAsGuess==1 ) THEN
	equmTRANS%rb = irfpointer%equmFLEX%rb

END IF

!borrowing rate
IF(FixBorrowRateTransition==0) equmTRANS(:)%rborr = equmTRANS(:)%rb + equmTRANS(:)%borrwedge
IF(FixBorrowRateTransition==1) equmTRANS(:)%rborr = equmINITSS%rborr

!world bond
equmTRANS(1)%worldbond = equmINITSS%worldbond
DO it = 1,Ttransition-1
	CALL WorldBondFunction2( equmTRANS(it)%rb,equmTRANS(it+1)%worldbond,equmINITSS%worldbond,equmINITSS%rb,bondelast)
	equmTRANS(it+1)%worldbond = equmTRANS(it)%worldbond + bondadjust*deltatransvec(it)*(equmTRANS(it+1)%worldbond-equmTRANS(it)%worldbond)
END DO


!inflation and nominal interest rates
IF(zlbtransition==.false.) THEN
	IF(BackwardTermInTaylorRule==0) THEN
		IF(forwardguide==.false.) THEN
			equmTRANS(:)%pi = (equmTRANS(:)%rb - equmINITSS%rnom - equmTRANS(:)%mpshock) / (phitaylor-1.0) !taylor rule
			equmTRANS(:)%rnom = equmTRANS(:)%rb + equmTRANS(:)%pi !fisher equn
			
		ELSE IF(forwardguide==.true.) THEN

			equmTRANS(1:itfg-1)%pi = (equmTRANS(1:itfg-1)%rb - equmINITSS%rnom - equmTRANS(1:itfg-1)%mpshock) / (phifg-1.0) !taylor rule
			equmTRANS(1:itfg-1)%rnom = equmTRANS(1:itfg-1)%rb + equmTRANS(1:itfg-1)%pi !fisher equn
			
			equmTRANS(itfg:Ttransition)%pi = (equmTRANS(itfg:Ttransition)%rb - equmINITSS%rnom - equmTRANS(itfg:Ttransition)%mpshock) / (phitaylor-1.0) !taylor rule
			equmTRANS(itfg:Ttransition)%rnom = equmTRANS(itfg:Ttransition)%rb + equmTRANS(itfg:Ttransition)%pi !fisher equn
				
		END IF		


	ELSE IF(BackwardTermInTaylorRule==1) THEN
		equmTRANS(1)%pi = (equmTRANS(1)%rb - equmINITSS%rnom - taylorpers*deltatransvec(1)*equmTRANS(1)%mpshock) / (phitaylor*taylorpers*deltatransvec(1)-1.0)
		equmTRANS(1)%rnom = equmTRANS(1)%rb + equmTRANS(1)%pi !fisher equn
		DO it = 2,Ttransition
			equmTRANS(it)%pi = (equmTRANS(it)%rb - taylorpers*deltatransvec(it)*equmINITSS%rnom &
								- (1.0-taylorpers*deltatransvec(it))*equmTRANS(it-1)%rnom  &
								- taylorpers*deltatransvec(it)*equmTRANS(it)%mpshock) / (phitaylor*taylorpers*deltatransvec(it)-1.0) !taylor rule
			equmTRANS(it)%rnom = equmTRANS(it)%rb + equmTRANS(it)%pi !fisher equn
		END DO
	END IF

ELSE IF(zlbtransition==.true.) THEN
	DO it = 1,Ttransition
		IF(equmTRANS(it)%rb > (equmINITSS%rnom + equmTRANS(it)%mpshock) / phitaylor) THEN !ZLB does not bind
			equmTRANS(it)%pi = (equmTRANS(it)%rb - equmINITSS%rnom - equmTRANS(it)%mpshock) / (phitaylor-1.0) !taylor rule
			equmTRANS(it)%rnom = equmTRANS(it)%rb + equmTRANS(it)%pi !fisher equn		
		ELSE IF(equmTRANS(it)%rb <= (equmINITSS%rnom + equmTRANS(it)%mpshock)/phitaylor) THEN !ZLB binds
			equmTRANS(it)%pi = -equmTRANS(it)%rb
			equmTRANS(it)%rnom = 0.0
		END IF
	END DO
END IF


!solve phillips curve backwards for marginal costs
IF (FirmDiscountRate==1) lfirmdiscount = equmTRANS(:)%rho
IF (FirmDiscountRate==2) lfirmdiscount = equmINITSS%rb
IF (FirmDiscountRate==4) lfirmdiscount = equmTRANS(:)%rb
IF (FirmDiscountRate==3 .or. FirmDiscountRate==5) THEN
	lfirmdiscount = equmTRANS(:)%rb
	write(*,*) 'warning: cannot set firm discount rate to ra_t with one asset model. setting to rb_t'
END IF

!marginal costs
!final period of transition
it = Ttransition
equmTRANS(it)%mc = (lfirmdiscount(it) 	- (equmFINALSS%tfp-equmTRANS(it)%tfp)/(equmTRANS(it)%tfp*deltatransvec(it)) &
										- (equmFINALSS%labor-equmTRANS(it)%labor)/(equmTRANS(it)%labor*deltatransvec(it)) ) *equmFINALSS%pi * priceadjcost/ equmTRANS(it)%elast &
										+ (equmTRANS(it)%elast-1.0)/equmTRANS(it)%elast - ((equmFINALSS%pi-equmTRANS(it)%pi)/deltatransvec(it)) * priceadjcost/ equmTRANS(it)%elast
equmTRANS(it)%mc = max(lminprice_W,equmTRANS(it)%mc)

!solve backwards
DO it = Ttransition-1,1,-1
	equmTRANS(it)%mc = (lfirmdiscount(it) 	- (equmTRANS(it+1)%tfp-equmTRANS(it)%tfp)/(equmTRANS(it)%tfp*deltatransvec(it)) &
											- (equmTRANS(it+1)%labor-equmTRANS(it)%labor)/(equmTRANS(it)%labor*deltatransvec(it)) ) *equmTRANS(it+1)%pi * priceadjcost/ equmTRANS(it)%elast &
											+ (equmTRANS(it)%elast-1.0)/equmTRANS(it)%elast - ((equmTRANS(it+1)%pi-equmTRANS(it)%pi)/deltatransvec(it)) * priceadjcost/ equmTRANS(it)%elast
	equmTRANS(it)%mc = max(lminprice_W,equmTRANS(it)%mc)

END DO

equmTRANS(:)%gap = equmTRANS(:)%elast*equmTRANS(:)%mc / (equmTRANS(:)%elast-1.0) - 1.0
equmTRANS(:)%wage = equmTRANS(:)%mc*(1.0-alpha)* equmTRANS(:)%tfpadj
equmTRANS(:)%netwage = (1.0-equmTRANS(:)%labtax)*equmTRANS(:)%wage
equmTRANS(:)%output = equmTRANS(:)%tfp * equmTRANS(:)%labor
equmTRANS(:)%priceadjust = (priceadjcost/2.0)*(equmTRANS(:)%pi**2)*equmTRANS(:)%output
equmTRANS(:)%profit = (1.0-equmTRANS(:)%mc)*equmTRANS(:)%output - equmTRANS(:)%priceadjust

	
!government budget constraint,expenditures and tax rates
IF (AdjGovBudgetConstraint==1) THEN !adjust spending
	equmTRANS(:)%govbond = equmINITSS%govbond
	equmTRANS(:)%labtax = equmINITSS%labtax
	IF(RebateCorpTaxLumpSum==0) equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer		
	IF(RebateCorpTaxLumpSum==1) THEN
		equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer + corptax*(equmTRANS(:)%profit - equmINITSS%profit)
	END IF
	IF(RebateCorpTaxLumpSum==2) THEN
		equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer + (1.0-labtax)*corptax*(equmTRANS(:)%profit - equmINITSS%profit)
	END IF 
		
	equmTRANS(:)%taxrev = equmTRANS(:)%labtax*equmTRANS(:)%wage*equmTRANS(:)%labor - equmTRANS(:)%lumptransfer + corptax*equmTRANS(:)%profit
	IF(DistributeProfitsInProportion == 1 .and. TaxHHProfitIncome == 1) equmTRANS(:)%taxrev = equmTRANS(:)%taxrev + equmTRANS(:)%labtax*(1.0-profdistfrac)*equmTRANS(:)%profit*(1.0-corptax)
	
	equmTRANS(:)%govexp = equmTRANS(:)%taxrev + equmTRANS(:)%rb*equmINITSS%govbond

ELSE IF(AdjGovBudgetConstraint==2) THEN  !adjust lump sum taxes
	equmTRANS(:)%govbond = equmINITSS%govbond
	equmTRANS(:)%govexp = equmINITSS%govexp
	equmTRANS(:)%labtax = equmINITSS%labtax
	equmTRANS(:)%taxrev = equmTRANS(:)%govexp - equmTRANS(:)%rb*equmINITSS%govbond
	equmTRANS(:)%lumptransfer = equmTRANS(:)%labtax*equmTRANS(:)%wage*equmTRANS(:)%labor + corptax*equmTRANS(:)%profit + equmTRANS(:)%rb*equmINITSS%govbond - equmTRANS(:)%govexp
	IF(DistributeProfitsInProportion == 1 .and. TaxHHProfitIncome == 1) equmTRANS(:)%lumptransfer = equmTRANS(:)%lumptransfer + equmTRANS(:)%labtax*(1.0-profdistfrac)*equmTRANS(:)%profit*(1.0-corptax)

			
ELSE IF(AdjGovBudgetConstraint==3) THEN !adjust debt
	IF(GovExpConstantFracOutput==0) equmTRANS(:)%govexp = equmINITSS%govexp
	IF(GovExpConstantFracOutput==1) equmTRANS(:)%govexp = equmTRANS(:)%output*equmINITSS%govexp/equmINITSS%output

	IF(RebateCorpTaxLumpSum==0) equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer		
	IF(RebateCorpTaxLumpSum==1) THEN
		equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer + corptax*(equmTRANS(:)%profit - equmINITSS%profit)
	END IF
	IF(RebateCorpTaxLumpSum==2) THEN
		equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer + (1.0-labtax)*corptax*(equmTRANS(:)%profit - equmINITSS%profit)
	END IF 		
	equmTRANS(:)%taxrev = equmTRANS(:)%labtax*equmTRANS(:)%wage*equmTRANS(:)%labor - equmTRANS(:)%lumptransfer + corptax*equmTRANS(:)%profit
	IF(DistributeProfitsInProportion == 1 .and. TaxHHProfitIncome == 1) equmTRANS(:)%taxrev = equmTRANS(:)%taxrev + equmTRANS(:)%labtax*(1.0-profdistfrac)*equmTRANS(:)%profit*(1.0-corptax)

	!compute required increase in lumptransfer
	lrgov = equmTRANS(:)%rb
	lpvgovbc = equmFINALSS%govbond
	lpvlumpincr = 0.0
	DO it = Ttransition,1,-1
		lpvgovbc = (lpvgovbc + deltatransvec(it)*(equmTRANS(it)%govexp - equmTRANS(it)%taxrev))/(1.0+deltatransvec(it)*lrgov(it))
		IF(cumdeltatrans(it)>=taxincrstart) lpvlumpincr = (lpvlumpincr + deltatransvec(it))/(1.0+deltatransvec(it)*(lrgov(it)+taxincrdecay))
		IF(cumdeltatrans(it)<taxincrstart) lpvlumpincr = lpvlumpincr/(1.0+deltatransvec(it)*lrgov(it))
	END DO	

	linitlumpincr = (equmINITSS%govbond-lpvgovbc) / lpvlumpincr
	DO it = 1,Ttransition
		IF(cumdeltatrans(it)>=taxincrstart) equmTRANS(it)%lumptransfer = equmTRANS(it)%lumptransfer + linitlumpincr*exp(-taxincrdecay*(cumdeltatrans(it)-taxincrstart))
	END DO

	equmTRANS(:)%taxrev = equmTRANS(:)%labtax*equmTRANS(:)%wage*equmTRANS(:)%labor - equmTRANS(:)%lumptransfer + corptax*equmTRANS(:)%profit
	IF(DistributeProfitsInProportion == 1 .and. TaxHHProfitIncome == 1) equmTRANS(:)%taxrev = equmTRANS(:)%taxrev + equmTRANS(:)%labtax*(1.0-profdistfrac)*equmTRANS(:)%profit*(1.0-corptax)
		
	equmTRANS(Ttransition)%govbond = equmFINALSS%govbond
	DO it = Ttransition-1,2,-1
		equmTRANS(it)%govbond = (equmTRANS(it+1)%govbond - deltatransvec(it)*(equmTRANS(it)%taxrev-equmTRANS(it)%govexp)) / (1.0+deltatransvec(it)*lrgov(it))
	END DO
	equmTRANS(1)%govbond = equmINITSS%govbond

	equmTRANS(:)%lumptransfer = equmTRANS(:)%lumptransfer + (equmTRANS(:)%rb-lrgov(:))*equmTRANS(:)%govbond
	equmTRANS(:)%taxrev = equmTRANS(:)%labtax*equmTRANS(:)%wage*equmTRANS(:)%labor - equmTRANS(:)%lumptransfer + corptax*equmTRANS(:)%profit
	IF(DistributeProfitsInProportion == 1 .and. TaxHHProfitIncome == 1) equmTRANS(:)%taxrev = equmTRANS(:)%taxrev + equmTRANS(:)%labtax*(1.0-profdistfrac)*equmTRANS(:)%profit*(1.0-corptax)
	
ELSE IF(AdjGovBudgetConstraint==4) THEN  !adjust proportional tax rate
	equmTRANS(:)%govbond = equmINITSS%govbond
	equmTRANS(:)%govexp = equmINITSS%govexp
	equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer
	equmTRANS(:)%taxrev = equmTRANS(:)%govexp - equmTRANS(:)%rb*equmINITSS%govbond

	IF(DistributeProfitsInProportion == 0 .or. TaxHHProfitIncome == 0) equmTRANS(:)%labtax  = (equmTRANS(:)%lumptransfer - corptax*equmTRANS(:)%profit - equmTRANS(:)%rb*equmINITSS%govbond + equmTRANS(:)%govexp) / (equmTRANS(:)%wage*equmTRANS(:)%labor)
	IF(DistributeProfitsInProportion == 1 .and. TaxHHProfitIncome == 1) equmTRANS(:)%labtax  = (equmTRANS(:)%lumptransfer - corptax*equmTRANS(:)%profit - equmTRANS(:)%rb*equmINITSS%govbond + equmTRANS(:)%govexp) / (equmTRANS(:)%wage*equmTRANS(:)%labor + (1.0-profdistfrac)*equmTRANS(:)%profit*(1.0-corptax))

END IF

equmTRANS(:)%bond = -equmTRANS(:)%worldbond - equmTRANS(:)%govbond - equmTRANS(:)%fundbond

ii = 1	 
ldiffB = 1.0
DO WHILE (ii<=maxitertranssticky .and. ldiffB>toltransition )
	!solve for transtion
	CALL Transition
	
	!computed implied equilibrium quantities
	lbond = statsTRANS(:)%Eb
	IF(ConvergenceRelToOutput==0) THEN
		ldiffB= maxval(abs(lbond/equmTRANS(:)%bond - 1.0))
	ELSEIF(ConvergenceRelToOutput==1) THEN
		ldiffB= maxval(abs(lbond-equmTRANS(:)%bond)/equmINITSS%output)
	END IF
	IF (Display>=1) write(*,"(A,I,A)") '  Transition iter ',ii, ':'
	IF (Display>=1) write(*,"(A,E10.3,A,E10.3,A,E10.3)")  ',  B err',ldiffB
	IF (Display>=1) write(*,*) '   household bond',lbond(2), ',  target bond',equmTRANS(2)%bond
	
	!update interest rate
	IF (ii<maxitertranssticky .and. ldiffB>toltransition ) THEN
		
		lfundbond = 0.0
		lworldbond = -lbond - equmTRANS(:)%govbond - lfundbond

		it = Ttransition
		CALL WorldBondInverse2( (equmFINALSS%worldbond-lworldbond(it))/(bondadjust*deltatransvec(it)) + lworldbond(it) ,lrb(it),equmINITSS%worldbond,equmINITSS%rb,bondelast)
		DO it = Ttransition-1,1,-1
			CALL WorldBondInverse2( (lworldbond(it+1)-lworldbond(it))/(bondadjust*deltatransvec(it)) + lworldbond(it), lrb(it),equmINITSS%worldbond,equmINITSS%rb,bondelast)
		END DO

		CALL PartialUpdate(Ttransition,stepstickytransB,equmTRANS(:)%rb,lrb,lrb1)
		equmTRANS(:)%rb = lrb1

	ElSE
		!run distribution stats with full
		iteratingtransition = .false.
		CALL Transition
		equmTRANS(:)%bond = lbond
		equmTRANS(:)%rb = lrb
		
	END IF
	
	!borrowing rate
	IF(FixBorrowRateTransition==0) equmTRANS(:)%rborr = equmTRANS(:)%rb + equmTRANS(:)%borrwedge
	IF(FixBorrowRateTransition==1) equmTRANS(:)%rborr = equmINITSS%rborr
	
	!world bond
	equmTRANS(1)%worldbond = equmINITSS%worldbond
	DO it = 1,Ttransition-1
		CALL WorldBondFunction2( equmTRANS(it)%rb,equmTRANS(it+1)%worldbond,equmINITSS%worldbond,equmINITSS%rb,bondelast)
		equmTRANS(it+1)%worldbond = equmTRANS(it)%worldbond + bondadjust*deltatransvec(it)*(equmTRANS(it+1)%worldbond-equmTRANS(it)%worldbond)
	END DO


	!inflation and nominal interest rates
	IF(zlbtransition==.false.) THEN
		IF(BackwardTermInTaylorRule==0) THEN
			IF(forwardguide==.false.) THEN
				equmTRANS(:)%pi = (equmTRANS(:)%rb - equmINITSS%rnom - equmTRANS(:)%mpshock) / (phitaylor-1.0) !taylor rule
				equmTRANS(:)%rnom = equmTRANS(:)%rb + equmTRANS(:)%pi !fisher equn
				
			ELSE IF(forwardguide==.true.) THEN

				equmTRANS(1:itfg-1)%pi = (equmTRANS(1:itfg-1)%rb - equmINITSS%rnom - equmTRANS(1:itfg-1)%mpshock) / (phifg-1.0) !taylor rule
				equmTRANS(1:itfg-1)%rnom = equmTRANS(1:itfg-1)%rb + equmTRANS(1:itfg-1)%pi !fisher equn
				
				equmTRANS(itfg:Ttransition)%pi = (equmTRANS(itfg:Ttransition)%rb - equmINITSS%rnom - equmTRANS(itfg:Ttransition)%mpshock) / (phitaylor-1.0) !taylor rule
				equmTRANS(itfg:Ttransition)%rnom = equmTRANS(itfg:Ttransition)%rb + equmTRANS(itfg:Ttransition)%pi !fisher equn
					
			END IF		


		ELSE IF(BackwardTermInTaylorRule==1) THEN
			equmTRANS(1)%pi = (equmTRANS(1)%rb - equmINITSS%rnom - taylorpers*deltatransvec(1)*equmTRANS(1)%mpshock) / (phitaylor*taylorpers*deltatransvec(1)-1.0)
			equmTRANS(1)%rnom = equmTRANS(1)%rb + equmTRANS(1)%pi !fisher equn
			DO it = 2,Ttransition
				equmTRANS(it)%pi = (equmTRANS(it)%rb - taylorpers*deltatransvec(it)*equmINITSS%rnom &
									- (1.0-taylorpers*deltatransvec(it))*equmTRANS(it-1)%rnom  &
									- taylorpers*deltatransvec(it)*equmTRANS(it)%mpshock) / (phitaylor*taylorpers*deltatransvec(it)-1.0) !taylor rule
				equmTRANS(it)%rnom = equmTRANS(it)%rb + equmTRANS(it)%pi !fisher equn
			END DO
		END IF
	
	ELSE IF(zlbtransition==.true.) THEN
		DO it = 1,Ttransition
			IF(equmTRANS(it)%rb > (equmINITSS%rnom + equmTRANS(it)%mpshock) / phitaylor) THEN !ZLB does not bind
				equmTRANS(it)%pi = (equmTRANS(it)%rb - equmINITSS%rnom - equmTRANS(it)%mpshock) / (phitaylor-1.0) !taylor rule
				equmTRANS(it)%rnom = equmTRANS(it)%rb + equmTRANS(it)%pi !fisher equn		
			ELSE IF(equmTRANS(it)%rb <= (equmINITSS%rnom + equmTRANS(it)%mpshock)/phitaylor) THEN !ZLB binds
				equmTRANS(it)%pi = -equmTRANS(it)%rb
				equmTRANS(it)%rnom = 0.0
			END IF
		END DO
	END IF 

	!solve phillips curve backwards for marginal costs
	IF (FirmDiscountRate==1) lfirmdiscount = equmTRANS(:)%rho
	IF (FirmDiscountRate==2) lfirmdiscount = equmINITSS%rb
	IF (FirmDiscountRate==4) lfirmdiscount = equmTRANS(:)%rb
	IF (FirmDiscountRate==3 .or. FirmDiscountRate==5) THEN
		lfirmdiscount = equmTRANS(:)%rb
		write(*,*) 'warning: cannot set firm discount rate to ra_t with one asset model. setting to rb_t'
	END IF

	!labor
	equmTRANS(:)%labor = statsTRANS(:)%Elabor

	!marginal costs
	!final period of transition
	it = Ttransition
	equmTRANS(it)%mc = (lfirmdiscount(it) 	- (equmFINALSS%tfp-equmTRANS(it)%tfp)/(equmTRANS(it)%tfp*deltatransvec(it)) &
											- (equmFINALSS%labor-equmTRANS(it)%labor)/(equmTRANS(it)%labor*deltatransvec(it)) ) *equmFINALSS%pi * priceadjcost/ equmTRANS(it)%elast &
											+ (equmTRANS(it)%elast-1.0)/equmTRANS(it)%elast - ((equmFINALSS%pi-equmTRANS(it)%pi)/deltatransvec(it)) * priceadjcost/ equmTRANS(it)%elast
	equmTRANS(it)%mc = max(lminprice_W,equmTRANS(it)%mc)

	!solve backwards
	DO it = Ttransition-1,1,-1
		equmTRANS(it)%mc = (lfirmdiscount(it) 	- (equmTRANS(it+1)%tfp-equmTRANS(it)%tfp)/(equmTRANS(it)%tfp*deltatransvec(it)) &
												- (equmTRANS(it+1)%labor-equmTRANS(it)%labor)/(equmTRANS(it)%labor*deltatransvec(it)) ) *equmTRANS(it+1)%pi * priceadjcost/ equmTRANS(it)%elast &
												+ (equmTRANS(it)%elast-1.0)/equmTRANS(it)%elast - ((equmTRANS(it+1)%pi-equmTRANS(it)%pi)/deltatransvec(it)) * priceadjcost/ equmTRANS(it)%elast
		equmTRANS(it)%mc = max(lminprice_W,equmTRANS(it)%mc)

	END DO

	equmTRANS(:)%gap = equmTRANS(:)%elast*equmTRANS(:)%mc / (equmTRANS(:)%elast-1.0) - 1.0
	equmTRANS(:)%wage = equmTRANS(:)%mc*(1.0-alpha)* equmTRANS(:)%tfpadj
	equmTRANS(:)%netwage = (1.0-equmTRANS(:)%labtax)*equmTRANS(:)%wage
	equmTRANS(:)%output = equmTRANS(:)%tfp * equmTRANS(:)%labor
	equmTRANS(:)%priceadjust = (priceadjcost/2.0)*(equmTRANS(:)%pi**2)*equmTRANS(:)%output
	equmTRANS(:)%profit = (1.0-equmTRANS(:)%mc)*equmTRANS(:)%output - equmTRANS(:)%priceadjust


	!government budget constraint,expenditures and tax rates
	IF (AdjGovBudgetConstraint==1) THEN !adjust spending
		equmTRANS(:)%govbond = equmINITSS%govbond
		equmTRANS(:)%labtax = equmINITSS%labtax
		IF(RebateCorpTaxLumpSum==0) equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer		
		IF(RebateCorpTaxLumpSum==1) THEN
			equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer + corptax*(equmTRANS(:)%profit - equmINITSS%profit)
		END IF
		IF(RebateCorpTaxLumpSum==2) THEN
			equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer + (1.0-labtax)*corptax*(equmTRANS(:)%profit - equmINITSS%profit)
		END IF 
			
		equmTRANS(:)%taxrev = equmTRANS(:)%labtax*equmTRANS(:)%wage*equmTRANS(:)%labor - equmTRANS(:)%lumptransfer + corptax*equmTRANS(:)%profit
		IF(DistributeProfitsInProportion == 1 .and. TaxHHProfitIncome == 1) equmTRANS(:)%taxrev = equmTRANS(:)%taxrev + equmTRANS(:)%labtax*(1.0-profdistfrac)*equmTRANS(:)%profit*(1.0-corptax)
	
		equmTRANS(:)%govexp = equmTRANS(:)%taxrev + equmTRANS(:)%rb*equmINITSS%govbond

	ELSE IF(AdjGovBudgetConstraint==2) THEN  !adjust lump sum taxes
		equmTRANS(:)%govbond = equmINITSS%govbond
		equmTRANS(:)%govexp = equmINITSS%govexp
		equmTRANS(:)%labtax = equmINITSS%labtax
		equmTRANS(:)%taxrev = equmTRANS(:)%govexp - equmTRANS(:)%rb*equmINITSS%govbond
		equmTRANS(:)%lumptransfer = equmTRANS(:)%labtax*equmTRANS(:)%wage*equmTRANS(:)%labor + corptax*equmTRANS(:)%profit + equmTRANS(:)%rb*equmINITSS%govbond - equmTRANS(:)%govexp
		IF(DistributeProfitsInProportion == 1 .and. TaxHHProfitIncome == 1) equmTRANS(:)%lumptransfer = equmTRANS(:)%lumptransfer + equmTRANS(:)%labtax*(1.0-profdistfrac)*equmTRANS(:)%profit*(1.0-corptax)
					
	ELSE IF(AdjGovBudgetConstraint==3) THEN !adjust debt
		IF(GovExpConstantFracOutput==0) equmTRANS(:)%govexp = equmINITSS%govexp
		IF(GovExpConstantFracOutput==1) equmTRANS(:)%govexp = equmTRANS(:)%output*equmINITSS%govexp/equmINITSS%output

		IF(RebateCorpTaxLumpSum==0) equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer		
		IF(RebateCorpTaxLumpSum==1) THEN
			equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer + corptax*(equmTRANS(:)%profit - equmINITSS%profit)
		END IF
		IF(RebateCorpTaxLumpSum==2) THEN
			equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer + (1.0-labtax)*corptax*(equmTRANS(:)%profit - equmINITSS%profit)
		END IF 
		
		equmTRANS(:)%taxrev = equmTRANS(:)%labtax*equmTRANS(:)%wage*equmTRANS(:)%labor - equmTRANS(:)%lumptransfer + corptax*equmTRANS(:)%profit
		IF(DistributeProfitsInProportion == 1 .and. TaxHHProfitIncome == 1) equmTRANS(:)%taxrev = equmTRANS(:)%taxrev + equmTRANS(:)%labtax*(1.0-profdistfrac)*equmTRANS(:)%profit*(1.0-corptax)

		!compute required increase in lumptransfer
		lrgov = equmTRANS(:)%rb
		lpvgovbc = equmFINALSS%govbond
		lpvlumpincr = 0.0
		DO it = Ttransition,1,-1
			lpvgovbc = (lpvgovbc + deltatransvec(it)*(equmTRANS(it)%govexp - equmTRANS(it)%taxrev))/(1.0+deltatransvec(it)*lrgov(it))
			IF(cumdeltatrans(it)>=taxincrstart) lpvlumpincr = (lpvlumpincr + deltatransvec(it))/(1.0+deltatransvec(it)*(lrgov(it)+taxincrdecay))
			IF(cumdeltatrans(it)<taxincrstart) lpvlumpincr = lpvlumpincr/(1.0+deltatransvec(it)*lrgov(it))
		END DO	

		linitlumpincr = (equmINITSS%govbond-lpvgovbc) / lpvlumpincr
		DO it = 1,Ttransition
			IF(cumdeltatrans(it)>=taxincrstart) equmTRANS(it)%lumptransfer = equmTRANS(it)%lumptransfer + linitlumpincr*exp(-taxincrdecay*(cumdeltatrans(it)-taxincrstart))
		END DO

		equmTRANS(:)%taxrev = equmTRANS(:)%labtax*equmTRANS(:)%wage*equmTRANS(:)%labor - equmTRANS(:)%lumptransfer + corptax*equmTRANS(:)%profit
		IF(DistributeProfitsInProportion == 1 .and. TaxHHProfitIncome == 1) equmTRANS(:)%taxrev = equmTRANS(:)%taxrev + equmTRANS(:)%labtax*(1.0-profdistfrac)*equmTRANS(:)%profit*(1.0-corptax)
		
		equmTRANS(Ttransition)%govbond = equmFINALSS%govbond
		DO it = Ttransition-1,2,-1
			equmTRANS(it)%govbond = (equmTRANS(it+1)%govbond - deltatransvec(it)*(equmTRANS(it)%taxrev-equmTRANS(it)%govexp)) / (1.0+deltatransvec(it)*lrgov(it))
		END DO
		equmTRANS(1)%govbond = equmINITSS%govbond

		equmTRANS(:)%lumptransfer = equmTRANS(:)%lumptransfer + (equmTRANS(:)%rb-lrgov(:))*equmTRANS(:)%govbond
		equmTRANS(:)%taxrev = equmTRANS(:)%labtax*equmTRANS(:)%wage*equmTRANS(:)%labor - equmTRANS(:)%lumptransfer + corptax*equmTRANS(:)%profit
		IF(DistributeProfitsInProportion == 1 .and. TaxHHProfitIncome == 1) equmTRANS(:)%taxrev = equmTRANS(:)%taxrev + equmTRANS(:)%labtax*(1.0-profdistfrac)*equmTRANS(:)%profit*(1.0-corptax)

	ELSE IF(AdjGovBudgetConstraint==4) THEN  !adjust proportional tax rate
		equmTRANS(:)%govbond = equmINITSS%govbond
		equmTRANS(:)%govexp = equmINITSS%govexp
		equmTRANS(:)%lumptransfer = equmINITSS%lumptransfer
		equmTRANS(:)%taxrev = equmTRANS(:)%govexp - equmTRANS(:)%rb*equmINITSS%govbond

		IF(DistributeProfitsInProportion == 0 .or. TaxHHProfitIncome == 0) equmTRANS(:)%labtax  = (equmTRANS(:)%lumptransfer - corptax*equmTRANS(:)%profit - equmTRANS(:)%rb*equmINITSS%govbond + equmTRANS(:)%govexp) / (equmTRANS(:)%wage*equmTRANS(:)%labor)
		IF(DistributeProfitsInProportion == 1 .and. TaxHHProfitIncome == 1) equmTRANS(:)%labtax  = (equmTRANS(:)%lumptransfer - corptax*equmTRANS(:)%profit - equmTRANS(:)%rb*equmINITSS%govbond + equmTRANS(:)%govexp) / (equmTRANS(:)%wage*equmTRANS(:)%labor + (1.0-profdistfrac)*equmTRANS(:)%profit*(1.0-corptax))
	

	END IF


	!household bonds
	equmTRANS(:)%bond = -equmTRANS(:)%worldbond - equmTRANS(:)%govbond - equmTRANS(:)%fundbond
	
	ii = ii+1	
END DO

IF(stickytransition==.true.) THEN
	irfpointer%equmSTICKY = equmTRANS
	irfpointer%statsSTICKY = statsTRANS
	irfpointer%solnSTICKY = solnTRANS
ELSE IF	(zlbtransition==.true.) THEN
	irfpointer%equmZLB = equmTRANS
	irfpointer%statsZLB = statsTRANS
	irfpointer%solnZLB = solnTRANS
END IF


END SUBROUTINE IterateTransOneAssetStickyRb
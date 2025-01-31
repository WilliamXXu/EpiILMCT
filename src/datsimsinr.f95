!######################################################################
!# MODULE: datsimsinr
!# AUTHORS:
!#     Waleed Almutiry <walmutir@uoguelph.ca>,
!#     Vineetha Warriyar. K. V. <vineethawarriyar.kod@ucalgary.ca> and
!#     Rob Deardon <robert.deardon@ucalgary.ca>
!#
!# DESCRIPTION:
!#
!#     To simulate epidemic from the SINR continuous-time ILMs:
!#
!#     This program is free software; you can redistribute it and/or
!#     modify it under the terms of the GNU General Public License,
!#     version 3,  as published by the Free Software Foundation.
!#
!#     This program is distributed in the hope that it will be useful,
!#     but without any warranty; without even the implied warranty of
!#     merchantability or fitness for a particular purpose.  See the GNU
!#     General Public License,  version 3,  for more details.
!#
!#     A copy of the GNU General Public License,  version 3,  is available
!#     at http://www.r-project.org/Licenses/GPL-3
!#
!# Part of the R/EpiILMCT package
!# Contains:
!#           datasimulationsinr ........... subroutine
!#           rateSINR ..................... subroutine
!#           randnormal22 ................. function
!#           randgamma22 .................. function
!#           initrandomseed22 ............. subroutine
!#
!######################################################################

module datsimsinr
    use, intrinsic :: iso_c_binding
    implicit none
    public :: datasimulationsinr_f

contains


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! 			EPIDEMIC SIMULATION subroutine		 	 	 !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    subroutine datasimulationsinr_f(n, anum, num, observednum, observedepi, tmax, suspar, nsuspar, powersus, &
    & transpar, ntranspar, powertrans, kernelpar, spark, gamma, deltain1, deltain2, deltanr1, deltanr2, &
    & suscov, transcov, cc, d3, epidat)  bind(C,  name="datasimulationsinr_f_")

    external infinity_value
    external seedin
    external seedout
    external randomnumber

    integer (C_INT), intent(in) :: n, nsuspar, ntranspar, num, anum, observednum   ! integers
    real (C_DOUBLE), intent(in), dimension(n, nsuspar) :: suscov               ! susceptibility covariates
    real (C_DOUBLE), intent(in), dimension(n, ntranspar) :: transcov           ! transmissibility covariates
    real (C_DOUBLE), intent(in), dimension(n, n) :: d3, cc                       ! network & distance matrices
    real (C_DOUBLE), intent(in), dimension(nsuspar) :: suspar, powersus         ! susceptibility parameters
    real (C_DOUBLE), intent(in), dimension(ntranspar) :: transpar, powertrans   ! transmissibility parameters
    real (C_DOUBLE), intent(in) :: spark, gamma, tmax                 ! spark& notification effect& max infec. time
    real (C_DOUBLE), intent(in) :: deltain1, deltain2, deltanr1, deltanr2  ! Parameters of the infectious period distribution
    real (C_DOUBLE), intent(in), dimension(2) :: kernelpar               ! parameter of the kernel function
    real (C_DOUBLE), intent(in), dimension(observednum, 6) :: observedepi ! observed epidemic to start
    real (C_DOUBLE), dimension(observednum, 6) :: observedepi1 ! observed epidemic to start
    real (C_DOUBLE), dimension(n, 6), intent(out) :: epidat               ! OUTPUT
    integer (C_INT) :: nnn1                                            ! # of infected by the end of epidemic
    integer (C_INT), dimension(n, 2) :: xx                               ! Auxiliary variable
    real (C_DOUBLE), dimension(1, 2) :: ts                               ! OUTPUT from the rate subroutine
    real (C_DOUBLE) :: t0                                              ! current infection time during the simulation
    real (C_DOUBLE) :: Inf, u                                             ! defining Infinity
    integer (C_INT) :: ctr, i, j, sdg, mg
    integer (C_INT), allocatable, dimension(:) :: mmg


! defining Infinity
    call infinity_value(Inf)
    call seedin()

    SELECT CASE (anum)
    CASE (1)

! case (1): for contact network or distanse based with spark term.  (SINR)
!			also for distanse based without spark term.

! defining auxiliary variable (xx) for the status of each individual:
! 0 : susceptible
! 1 : infectious
! 2 : notified
! 3 : removed

        xx          = 0
        xx(:, 1)     = (/(j, j=1, n)/)
        epidat      = 0.0_c_double
        observedepi1 = observedepi
! initial observed epidemic:
        if (observednum .eq. 1) then
            if (observedepi1(1,1) .eq. 0) then
                call randomnumber(u)
                observedepi1(1,1) = int(u*n) + 1
            end if
        end if

        do j = 1,  observednum
            if (observedepi1(j, 2) .eq. 0.0_c_double) then
                epidat(j, 1)  = observedepi1(j, 1)
                epidat(j, 6)  = observedepi1(j, 6)
                epidat(j, 5)  = deltain1
                epidat(j, 4)  = epidat(j, 5) + epidat(j, 6)
                epidat(j, 3)  = deltanr1
                epidat(j, 2)  = epidat(j, 4) + epidat(j, 3)
            else
                epidat(j, :)  = observedepi1(j, :)
            end if
        end do

! the current infection time to start from:
        t0 = deltain2
        if ( epidat(observednum, 6) .gt. t0 ) then
            t0 =  epidat(observednum, 6)
        end if

        xx(int(epidat(1:observednum, 1)), 2) = 1

        mg  = size(pack(int(epidat(1:(observednum), 1)), epidat(1:(observednum), 4) .lt. t0 ))
        if (mg .gt. 0) then
            allocate(mmg(mg))
            mmg = pack(int(epidat(1:(observednum), 1)), epidat(1:(observednum), 4) .lt. &
                        & t0 )
            xx(mmg, 2) = 2
            deallocate(mmg)
        end if

        mg  = size(pack(int(epidat(1:(observednum), 1)), epidat(1:(observednum), 2) .lt. &
                & t0 ))
        if (mg .gt. 0) then
            allocate(mmg(mg))
            mmg = pack(int(epidat(1:(observednum), 1)), epidat(1:(observednum), 2) .lt. &
                         & t0 )
            xx(mmg, 2) = 3
            deallocate(mmg)
        end if

! starting simulating the epidemic
        ctr = observednum
        do while( (ctr .le. n) )
            ctr = ctr + 1
! to provide the next infected individual with minmum waiting time to infection:
            call rateSINR(n, num, suspar, nsuspar, powersus, transpar, ntranspar, powertrans, &
                & kernelpar, spark, gamma, xx, suscov, transcov, cc, d3, ts)

            ! to judge stopping the epidemic or keep generating:
            if ( (ts(1, 2) .ne. Inf) .and. (ts(1, 1) .ne. 0.0_c_double) ) then
                ts = ts
            else
                where(xx(:, 2) .eq. 1) xx(:, 2) = 2
                exit
            end if

!making sure there is still infectious individuals that can transmit the disease

            sdg = 0
            do i = 1,  (ctr-1)
                if ( (epidat(i, 2) .gt. (ts(1, 2)+t0)) ) then
                    sdg = sdg +1
                else
                    sdg = sdg
                end if
            end do

! assigning infection time,  incubation period,  notification time,  delay period and
! removal time for the newly infected:

            if (sdg .eq. 0 ) then
                where(xx(:, 2) .eq. 1) xx(:, 2) = 2
                exit
            else
                epidat(ctr, 6) = ts(1, 2) + t0
                epidat(ctr, 5) = deltain1
                epidat(ctr, 4) = epidat(ctr, 5) + epidat(ctr, 6)
                epidat(ctr, 3) = deltanr1
                epidat(ctr, 2) = epidat(ctr, 3) + epidat(ctr, 4)
                epidat(ctr, 1) = ts(1, 1)
                t0 = epidat(ctr, 6)
                xx(int(epidat(ctr, 1)), 2) = 1
            end if

            if ( (epidat(ctr, 4) .gt. tmax) ) then
                epidat(ctr, 2) = 0.0_c_double
                epidat(ctr, 3) = 0.0_c_double
                epidat(ctr, 4) = 0.0_c_double
                epidat(ctr, 5) = 0.0_c_double
                epidat(ctr, 6) = 0.0_c_double
                exit
            end if

! update the auxiliary variable of the status of individuals:
            mg  = size(pack(int(epidat(1:ctr-1, 1)), epidat(1:ctr-1, 4) .lt. epidat(ctr, 6) ))
            if (mg .gt. 0) then
                allocate(mmg(mg))
                mmg = pack(int(epidat(1:ctr-1, 1)), epidat(1:ctr-1, 4) .lt. epidat(ctr, 6) )
                xx(mmg, 2) = 2
                deallocate(mmg)
            end if

            mg  = size(pack(int(epidat(1:ctr-1, 1)), epidat(1:ctr-1, 2) .lt. epidat(ctr, 6) ))
            if (mg .gt. 0) then
                allocate(mmg(mg))
                mmg = pack(int(epidat(1:ctr-1, 1)), epidat(1:ctr-1, 2) .lt. epidat(ctr, 6) )
                xx(mmg, 2) = 3
                deallocate(mmg)
            end if

        end do

! assigning infinity values for those uninfected by the end of the epidemic

        nnn1 = count(epidat(:, 2)  .ne. 0.0_c_double)
        do i = (nnn1+1),  n
            do j = 1, n
                if (all(int(epidat(1:(i-1), 1)) .ne. j)) then
                    epidat(i, 1) = dble(j)
                end if
            end do
            epidat(i, 2) = Inf
            epidat(i, 3) = 0.0_c_double
            epidat(i, 4) = Inf
            epidat(i, 5) = 0.0_c_double
            epidat(i, 6) = Inf
        end do


    CASE (2)

! case (2): for contact without spark term.  (SINR)

! defining auxiliary variable (xx) for the status of each individual:
! 0 : susceptible
! 1 : infectious
! 2 : notified
! 3 : removed

        xx          = 0
        xx(:, 1)     = (/(j, j=1, n)/)
        epidat      = 0.0_c_double
        observedepi1 = observedepi

! initial observed epidemic:
        if (observednum .eq. 1) then
            if (observedepi1(1,1) .eq. 0) then
                call randomnumber(u)
                observedepi1(1,1) = int(u*n) + 1
            end if
        end if

        do j = 1,  observednum
            if (observedepi1(j, 2) .eq. 0.0_c_double) then
                epidat(j, 1)  = observedepi1(j, 1)
                epidat(j, 6)  = observedepi1(j, 6)
                epidat(j, 5)  = deltain1
                epidat(j, 4)  = epidat(j, 5) + epidat(j, 6)
                epidat(j, 3)  = deltanr1
                epidat(j, 2)  = epidat(j, 4) + epidat(j, 3)
            else
                epidat(j, :)  = observedepi1(j, :)
            end if
        end do

! the current infection time to start from:
        t0 = deltain2
        if ( epidat(observednum, 6) .gt. t0 ) then
            t0 =  epidat(observednum, 6)
        end if

        xx(int(epidat(1:observednum, 1)), 2) = 1

        mg  = size(pack(int(epidat(1:(observednum), 1)), epidat(1:(observednum), 4) .lt. &
                & t0 ))
        if (mg .gt. 0) then
            allocate(mmg(mg))
            mmg = pack(int(epidat(1:(observednum), 1)), epidat(1:(observednum), 4) .lt. &
                & t0 )
            xx(mmg, 2) = 2
            deallocate(mmg)
        end if

        mg  = size(pack(int(epidat(1:(observednum), 1)), epidat(1:(observednum), 2) .lt. &
                & t0 ))
        if (mg .gt. 0) then
            allocate(mmg(mg))
            mmg = pack(int(epidat(1:(observednum), 1)), epidat(1:(observednum), 2) .lt. &
                & t0 )
            xx(mmg, 2) = 3
            deallocate(mmg)
        end if

! starting simulating the epidemic

        ctr = observednum
        do while( (ctr .le. n) )

            ctr = ctr + 1

! to provide the next infected individual with minmum waiting time to infection:
            call rateSINR(n, num, suspar, nsuspar, powersus, transpar, ntranspar, powertrans,  &
                        & kernelpar, spark, gamma, xx, suscov, transcov, cc, d3, ts)

! to judge stopping the epidemic or keep generating:
            if ( (ts(1, 2) .ne. Inf) .and. (ts(1, 1) .ne. 0.0_c_double) ) then
                ts = ts
            else
                where(xx(:, 2) .eq. 1) xx(:, 2) = 2
                exit
            end if

!making sure there is still infectious individuals that can transmit the disease

            sdg = 0
            do i = 1,  (ctr-1)
                if ( (epidat(i, 2) .gt. (ts(1, 2)+t0)) .and. &
                  & (cc(int(epidat(i, 1)), int(ts(1, 1))) .gt. 0.0_c_double) ) then
                    sdg = sdg +1
                else
                    sdg = sdg
                end if
            end do

! assigning infection time,  incubation period,  notification time,  delay period and
! removal time for the newly infected:

            if (sdg .eq. 0 ) then
                where(xx(:, 2) .eq. 1) xx(:, 2) = 2
                exit
            else
                epidat(ctr, 6) = ts(1, 2) + t0
                epidat(ctr, 5) = deltain1
                epidat(ctr, 4) = epidat(ctr, 5) + epidat(ctr, 6)
                epidat(ctr, 3) = deltanr1
                epidat(ctr, 2) = epidat(ctr, 3) + epidat(ctr, 4)
                epidat(ctr, 1) = ts(1, 1)
                t0 = epidat(ctr, 6)
                xx(int(epidat(ctr, 1)), 2) = 1
            end if

            if ( (epidat(ctr, 4) .gt. tmax) ) then
                epidat(ctr, 2) = 0.0_c_double
                epidat(ctr, 3) = 0.0_c_double
                epidat(ctr, 4) = 0.0_c_double
                epidat(ctr, 5) = 0.0_c_double
                epidat(ctr, 6) = 0.0_c_double
                exit
            end if


! update the auxiliary variable of the status of individuals:

            mg  = size(pack(int(epidat(1:ctr-1, 1)), epidat(1:ctr-1, 4) .lt. epidat(ctr, 6) ))
            if (mg .gt. 0) then
                allocate(mmg(mg))
                mmg = pack(int(epidat(1:ctr-1, 1)), epidat(1:ctr-1, 4) .lt. epidat(ctr, 6) )
                xx(mmg, 2) = 2
                deallocate(mmg)
            end if

            mg  = size(pack(int(epidat(1:ctr-1, 1)), epidat(1:ctr-1, 2) .lt. epidat(ctr, 6) ))
            if (mg .gt. 0) then
                allocate(mmg(mg))
                mmg = pack(int(epidat(1:ctr-1, 1)), epidat(1:ctr-1, 2) .lt. epidat(ctr, 6) )
                xx(mmg, 2) = 3
                deallocate(mmg)
            end if

        end do

! assigning infinity values for those uninfected by the end of the epidemic

        nnn1 = count(epidat(:, 2)  .ne. 0.0_c_double)
        do i = (nnn1+1),  n
            do j = 1, n
                if (all(int(epidat(1:(i-1), 1)) .ne. j)) then
                    epidat(i, 1) = dble(j)
                end if
            end do
            epidat(i, 2) = Inf
            epidat(i, 3) = 0.0_c_double
            epidat(i, 4) = Inf
            epidat(i, 5) = 0.0_c_double
            epidat(i, 6) = Inf
        end do

    END SELECT
    call seedout()

    end subroutine datasimulationsinr_f


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! 			INFECTIVITY rateSINR subroutine 		 	 !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

    subroutine rateSINR(n, num, suspar, nsuspar, powersus, transpar, ntranspar, powertrans, kernelpar, spark, gamma, xx, &
    & suscov, transcov, cc, d3, mms)

    external infinity_value

    integer ::i, mg, mg1, mg2, j, m

    integer, intent(in) :: n, nsuspar, ntranspar, num           !integers
    integer, intent(in), dimension(n, 2) :: xx
    real(kind = C_DOUBLE), intent(in), dimension(n, nsuspar) :: suscov      ! susceptibility covariates
    real(kind = C_DOUBLE), intent(in), dimension(n, ntranspar) :: transcov  ! transmissibility covariates
    real(kind = C_DOUBLE), intent(in), dimension(n, n) :: d3, cc              ! network and distance matrices
    real(kind = C_DOUBLE), intent(in), dimension(nsuspar) :: suspar, powersus! susceptibility parameters
    real(kind = C_DOUBLE), intent(in), dimension(ntranspar) :: transpar, powertrans ! transmissibility parameters
    real(kind = C_DOUBLE), intent(in) :: spark, gamma                       ! spark & notification effec parameters
    real(kind = C_DOUBLE), intent(in), dimension(2) :: kernelpar            ! parameters of the kernel function
    real(kind = C_DOUBLE), dimension(nsuspar) :: suscov1                   ! suseptible covar. for one individual
    real(kind = C_DOUBLE), dimension(ntranspar) :: transcov1, transcov2     ! transmissibilty covar. for one individual
    real(kind = C_DOUBLE) :: Inf
    real(kind = C_DOUBLE), dimension(1, 2) :: mms

    integer, allocatable, dimension(:) :: mmg, mmg1, mmg2
    real(kind = C_DOUBLE), allocatable, dimension(:, :) :: rr
    real(kind = C_DOUBLE), allocatable, dimension(:) :: hg, hg2

    call infinity_value(Inf)


    SELECT CASE (num)

    CASE (1)
! Calculating the infectivity rateSINR of contact network-based ILM with spark term.
! defining infectious individuals:

        mg  = size( pack(xx(:, 1), xx(:, 2).eq. 1.0_c_double ) )
        allocate(mmg(mg))
        mmg = pack(xx(:, 1), xx(:, 2).eq. 1.0_c_double )

! defining susceptible individuals:
        mg1 = size( pack(xx(:, 1), xx(:, 2).eq. 0.0_c_double ) )
        allocate(mmg1(mg1))
        mmg1 = pack(xx(:, 1), xx(:, 2).eq. 0.0_c_double )

! defining notified individuals:
        mg2 = size( pack(xx(:, 1), xx(:, 2).eq. 2.0_c_double ) )
        allocate(mmg2(mg2))
        mmg2 = pack(xx(:, 1), xx(:, 2).eq. 2.0_c_double )


! declaring a variable with size equal to the number of susceptible individuals
! the first column is the id number of the susceptible individuals
        allocate(rr(mg1, 2))
        rr(:, 1) = mmg1

! start calculating the infectivity rate for each susceptible individuals:
        do i = 1, mg1
            allocate(hg(mg))
            do j = 1,  mg
                do m = 1,  ntranspar
                    transcov1(m) = transcov(mmg(j), m)**powertrans(m)
                end do
                hg(j) = dot_product(transpar, transcov1) * cc(mmg(j), mmg1(i))
            end do

            allocate(hg2(mg2))
            do j = 1,  mg2
                do m = 1,  ntranspar
                    transcov2(m) = transcov(mmg2(j), m)**powertrans(m)
                end do
                hg2(j) = gamma * dot_product(transpar, transcov2) * cc(mmg2(j), mmg1(i))
            end do

            do m = 1,  nsuspar
                suscov1(m) = suscov(mmg1(i), m)**powersus(m)
            end do

            rr(i, 2) = (dot_product(suspar, suscov1)*(sum(hg)+sum(hg2)))+ spark

            deallocate(hg)
            deallocate(hg2)

        end do

! assigning waiting time to infection for each susceptible individual:
        do i = 1, mg1
            if (rr(i, 2) .eq. 0.0_c_double) then
                rr(i, 2) = Inf
            else
                rr(i, 2) = randgamma22(1.0_c_double, 1.0_c_double/rr(i, 2))
            end if
        end do

! choose the one with minmum waiting time as the newly infected individual:
        if (all(rr(:, 2) .eq. Inf).eqv. .true.) then
            mms(1, 1)  = 0.0_c_double
            mms(1, 2)  = Inf
        else
            mms(1, 1:2)  = rr(int(minloc(rr(:, 2), 1)), :)
        end if

        deallocate(rr)
        deallocate(mmg2)
        deallocate(mmg1)
        deallocate(mmg)

    CASE (2)
! Calculating the infectivity rateSINR of distance-based ILM with spark term with
! "powerlaw" kernel.

! defining infectious individuals:
        mg  = size( pack(xx(:, 1), xx(:, 2).eq. 1.0_c_double ) )
        allocate(mmg(mg))
        mmg = pack(xx(:, 1), xx(:, 2).eq. 1.0_c_double )

! defining susceptible individuals:
        mg1 = size( pack(xx(:, 1), xx(:, 2).eq. 0.0_c_double ) )
        allocate(mmg1(mg1))
        mmg1 = pack(xx(:, 1), xx(:, 2).eq. 0.0_c_double )

! defining notified individuals:
        mg2 = size( pack(xx(:, 1), xx(:, 2).eq. 2.0_c_double ) )
        allocate(mmg2(mg2))
        mmg2 = pack(xx(:, 1), xx(:, 2).eq. 2.0_c_double )

! declaring a variable with size equal to the number of susceptible individuals
! the first column is the id number of the susceptible individuals
        allocate(rr(mg1, 2))
        rr(:, 1) = mmg1

! start calculating the infectivity rate for each susceptible individuals:
        do i = 1, mg1
            allocate(hg(mg))
            do j = 1,  mg
                do m = 1,  ntranspar
                    transcov1(m) = transcov(mmg(j), m)**powertrans(m)
                end do
                hg(j) = dot_product(transpar, transcov1) * (d3(mmg(j), mmg1(i))**(-kernelpar(1)))
            end do

            allocate(hg2(mg2))
            do j = 1,  mg2
                do m = 1,  ntranspar
                    transcov2(m) = transcov(mmg2(j), m)**powertrans(m)
                end do
                hg2(j) = gamma * dot_product(transpar, transcov2) * &
                      & (d3(mmg2(j), mmg1(i))**(-kernelpar(1)))
            end do

            do m = 1,  nsuspar
                suscov1(m) = suscov(mmg1(i), m)**powersus(m)
            end do

            rr(i, 2) = (dot_product(suspar, suscov1)*(sum(hg)+sum(hg2)))+ spark

            deallocate(hg)
            deallocate(hg2)

        end do

! assigning waiting time to infection for each susceptible individual:
        do i = 1, mg1
            if (rr(i, 2) .eq. 0.0_c_double) then
                rr(i, 2) = Inf
            else
                rr(i, 2) = randgamma22(1.0_c_double, 1.0_c_double/rr(i, 2))
            end if
        end do

! choose the one with minmum waiting time as the newly infected individual:
        if (all(rr(:, 2) .eq. Inf).eqv. .true.) then
            mms(1, 1)  = 0.0_c_double
            mms(1, 2)  = Inf
        else
            mms(1, 1:2)  = rr(int(minloc(rr(:, 2), 1)), :)
        end if

        deallocate(rr)
        deallocate(mmg2)
        deallocate(mmg1)
        deallocate(mmg)

    CASE (3)
! Calculating the infectivity rateSINR of distance-based ILM with spark term with
! "Cauchy" kernel.

! defining infectious individuals:
        mg  = size( pack(xx(:, 1), xx(:, 2).eq. 1.0_c_double ) )
        allocate(mmg(mg))
        mmg = pack(xx(:, 1), xx(:, 2).eq. 1.0_c_double )

! defining susceptible individuals:
        mg1 = size( pack(xx(:, 1), xx(:, 2).eq. 0.0_c_double ) )
        allocate(mmg1(mg1))
        mmg1 = pack(xx(:, 1), xx(:, 2).eq. 0.0_c_double )

! defining notified individuals:
        mg2 = size( pack(xx(:, 1), xx(:, 2).eq. 2.0_c_double ) )
        allocate(mmg2(mg2))
        mmg2 = pack(xx(:, 1), xx(:, 2).eq. 2.0_c_double )


! declaring a variable with size equal to the number of susceptible individuals
! the first column is the id number of the susceptible individuals
        allocate(rr(mg1, 2))
        rr(:, 1) = mmg1

! start calculating the infectivity rate for each susceptible individuals:
        do i = 1, mg1
            allocate(hg(mg))
            do j = 1,  mg
                do m = 1,  ntranspar
                    transcov1(m) = transcov(mmg(j), m)**powertrans(m)
                end do
                hg(j) = dot_product(transpar, transcov1) * &
                & (kernelpar(1)/((d3(mmg(j), mmg1(i))**(2.0_c_double)) + &
                & (kernelpar(1)**(2.0_c_double))))
            end do

            allocate(hg2(mg2))
            do j = 1,  mg2
                do m = 1,  ntranspar
                    transcov2(m) = transcov(mmg2(j), m)**powertrans(m)
                end do
                hg2(j) = gamma * dot_product(transpar, transcov2) * &
                & (kernelpar(1)/((d3(mmg2(j), mmg1(i))**(2.0_c_double)) + &
                & (kernelpar(1)**(2.0_c_double))))
            end do

            do m = 1,  nsuspar
                suscov1(m) = suscov(mmg1(i), m)**powersus(m)
            end do

            rr(i, 2) = (dot_product(suspar, suscov1)*(sum(hg)+sum(hg2)))+ spark

            deallocate(hg)
            deallocate(hg2)

        end do

! assigning waiting time to infection for each susceptible individual:
        do i = 1, mg1
            if (rr(i, 2) .eq. 0.0_c_double) then
                rr(i, 2) = Inf
            else
                rr(i, 2) = randgamma22(1.0_c_double, 1.0_c_double/rr(i, 2))
            end if
        end do

! choose the one with minmum waiting time as the newly infected individual:
        if (all(rr(:, 2) .eq. Inf).eqv. .true.) then
            mms(1, 1)  = 0.0_c_double
            mms(1, 2)  = Inf
        else
            mms(1, 1:2)  = rr(int(minloc(rr(:, 2), 1)), :)
        end if

        deallocate(rr)
        deallocate(mmg2)
        deallocate(mmg1)
        deallocate(mmg)

    CASE (4)
! Calculating the infectivity rateSINR of both distance and network-based ILM with
! spark term with "powerlaw" distance kernel.

! defining infectious individuals:
        mg  = size( pack(xx(:, 1), xx(:, 2).eq. 1.0_c_double ) )
        allocate(mmg(mg))
        mmg = pack(xx(:, 1), xx(:, 2).eq. 1.0_c_double )

! defining susceptible individuals:
        mg1 = size( pack(xx(:, 1), xx(:, 2).eq. 0.0_c_double ) )
        allocate(mmg1(mg1))
        mmg1 = pack(xx(:, 1), xx(:, 2).eq. 0.0_c_double )

! defining notified individuals:
        mg2 = size( pack(xx(:, 1), xx(:, 2).eq. 2.0_c_double ) )
        allocate(mmg2(mg2))
        mmg2 = pack(xx(:, 1), xx(:, 2).eq. 2.0_c_double )

! declaring a variable with size equal to the number of susceptible individuals
! the first column is the id number of the susceptible individuals
        allocate(rr(mg1, 2))
        rr(:, 1) = mmg1

! start calculating the infectivity rate for each susceptible individuals:
        do i = 1, mg1
            allocate(hg(mg))
            do j = 1,  mg
                do m = 1,  ntranspar
                transcov1(m) = transcov(mmg(j), m)**powertrans(m)
                end do
                hg(j) = dot_product(transpar, transcov1) * &
                & ( (d3(mmg(j), mmg1(i))**(-kernelpar(1))) + &
                & (kernelpar(2)*cc(mmg(j), mmg1(i))))
            end do

            allocate(hg2(mg2))
            do j = 1,  mg2
                do m = 1,  ntranspar
                    transcov2(m) = transcov(mmg2(j), m)**powertrans(m)
                end do
                hg2(j) = gamma * dot_product(transpar, transcov2) * &
                & ( (d3(mmg2(j), mmg1(i))**(-kernelpar(1))) + &
                & (kernelpar(2)*cc(mmg2(j), mmg1(i))))
            end do

            do m = 1,  nsuspar
                suscov1(m) = suscov(mmg1(i), m)**powersus(m)
            end do

            rr(i, 2) = (dot_product(suspar, suscov1)*(sum(hg)+sum(hg2)))+ spark

            deallocate(hg)
            deallocate(hg2)

        end do

! assigning waiting time to infection for each susceptible individual:
        do i = 1, mg1
            if (rr(i, 2) .eq. 0.0_c_double) then
                rr(i, 2) = Inf
            else
                rr(i, 2) = randgamma22(1.0_c_double, 1.0_c_double/rr(i, 2))
            end if
        end do

! choose the one with minmum waiting time as the newly infected individual:
        if (all(rr(:, 2) .eq. Inf).eqv. .true.) then
            mms(1, 1)  = 0.0_c_double
            mms(1, 2)  = Inf
        else
            mms(1, 1:2)  = rr(int(minloc(rr(:, 2), 1)), :)
        end if

        deallocate(rr)
        deallocate(mmg2)
        deallocate(mmg1)
        deallocate(mmg)

    CASE (5)
! Calculating the infectivity rateSINR of both distance and network-based ILM with
! spark term with "Cauchy" distance kernel.

! defining infectious individuals:
        mg  = size( pack(xx(:, 1), xx(:, 2).eq. 1.0_c_double ) )
        allocate(mmg(mg))
        mmg = pack(xx(:, 1), xx(:, 2).eq. 1.0_c_double )

! defining susceptible individuals:
        mg1 = size( pack(xx(:, 1), xx(:, 2).eq. 0.0_c_double ) )
        allocate(mmg1(mg1))
        mmg1 = pack(xx(:, 1), xx(:, 2).eq. 0.0_c_double )

! defining notified individuals:
        mg2 = size( pack(xx(:, 1), xx(:, 2).eq. 2.0_c_double ) )
        allocate(mmg2(mg2))
        mmg2 = pack(xx(:, 1), xx(:, 2).eq. 2.0_c_double )

! declaring a variable with size equal to the number of susceptible individuals
! the first column is the id number of the susceptible individuals
        allocate(rr(mg1, 2))
        rr(:, 1) = mmg1

! start calculating the infectivity rate for each susceptible individuals:
        do i = 1, mg1
            allocate(hg(mg))
            do j = 1,  mg
                do m = 1,  ntranspar
                    transcov1(m) = transcov(mmg(j), m)**powertrans(m)
                end do
                hg(j) = dot_product(transpar, transcov1) * &
                & ((kernelpar(1)/((d3(mmg(j), mmg1(i))**(2.0_c_double)) + &
                & (kernelpar(1)**(2.0_c_double)))) + &
                & (kernelpar(2)*cc(mmg(j), mmg1(i))))
            end do

            allocate(hg2(mg2))
            do j = 1,  mg2
                do m = 1,  ntranspar
                    transcov2(m) = transcov(mmg2(j), m)**powertrans(m)
                end do
                hg2(j) = gamma * dot_product(transpar, transcov2) * &
                & ( (kernelpar(1)/((d3(mmg2(j), mmg1(i))**(2.0_c_double)) + &
                & (kernelpar(1)**(2.0_c_double)))) + &
                & (kernelpar(2)*cc(mmg2(j), mmg1(i))) )
            end do

            do m = 1,  nsuspar
                suscov1(m) = suscov(mmg1(i), m)**powersus(m)
            end do

            rr(i, 2) = (dot_product(suspar, suscov1)*(sum(hg)+sum(hg2)))+ spark

            deallocate(hg)
            deallocate(hg2)

        end do

! assigning waiting time to infection for each susceptible individual:
        do i = 1, mg1
            if (rr(i, 2) .eq. 0.0_c_double) then
                rr(i, 2) = Inf
            else
                rr(i, 2) = randgamma22(1.0_c_double, 1.0_c_double/rr(i, 2))
            end if
        end do

! choose the one with minmum waiting time as the newly infected individual:
        if (all(rr(:, 2) .eq. Inf).eqv. .true.) then
            mms(1, 1)  = 0.0_c_double
            mms(1, 2)  = Inf
        else
            mms(1, 1:2)  = rr(int(minloc(rr(:, 2), 1)), :)
        end if

        deallocate(rr)
        deallocate(mmg2)
        deallocate(mmg1)
        deallocate(mmg)


    END SELECT

    end subroutine rateSINR

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!! Generating random variables for diffierent distributions !!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

!####################  NORMAL distribution ######################

    FUNCTION randnormal22(mean, stdev) RESULT(c)
    implicit none

    real(kind = C_DOUBLE) :: mean, stdev, c, temp(2), r, theta
    real(kind = C_DOUBLE),  PARAMETER :: PI=3.141592653589793238462_c_double

    CALL randomnumber(temp(1))
    CALL randomnumber(temp(2))
        r=(-2.0_c_double*log(temp(1)))**0.5_c_double
        theta = 2.0_c_double*PI*temp(2)
        c= mean+stdev*r*sin(theta)

    END FUNCTION randnormal22

!#################### GAMMA distribution ######################

    RECURSIVE FUNCTION randgamma22(shape,  SCALE) RESULT(ans)

    real(kind = C_DOUBLE) :: SHAPE, scale, u, w, d, c, x, xsq, g, ans, v

! DESCRIPTION: Implementation based on "A Simple Method for Generating Gamma Variables"
! by George Marsaglia and Wai Wan Tsang.
! ACM Transactions on Mathematical Software and released in public domain.
! ## Vol 26,  No 3,  September 2000,  pages 363-372.

        IF (shape >= 1.0_c_double) THEN
            d = SHAPE - (1.0_c_double/3.0_c_double)
            c = 1.0_c_double/((9.0_c_double * d)**0.5_c_double)
            DO while (.true.)
                x = randnormal22(0.0_c_double,  1.0_c_double)
                v = 1.0 + c*x
                DO while (v <= 0.0_c_double)
                    x = randnormal22(0.0_c_double,  1.0_c_double)
                    v = 1.0_c_double + c*x
                END DO
                v = v*v*v
                CALL randomnumber(u)
                xsq = x*x
                IF ((u < 1.0_c_double -.0331_c_double*xsq*xsq) .OR.  &
                (log(u) < 0.5_c_double*xsq + d*(1.0_c_double - v + log(v))) ) then
                    ans=scale*d*v
                    RETURN
                END IF

            END DO
        ELSE
            g = randgamma22(shape+1.0_c_double,  1.0_c_double)
            CALL randomnumber(w)
            ans=scale*g*(w**(1.0_c_double/shape))
            RETURN
        END IF

    END FUNCTION randgamma22



end module datsimsinr

SUBROUTINE  BckgrndCC(nsig,tbk,pbk,q,hbk,zh,   &
                      cv_bk,t_k)
!
!$$$  subprogram documentation block
!                .      .    .                                       .
! subprogram:  BckgrndCC  generate background field for
!           fractional cloud cover based on RH
!
!   PRGMMR: Ming Hu          ORG: GSD/AMB        DATE: 2006-10-27
!
! ABSTRACT: 
!  This subroutine calculate cloud field based on background fields
!
! PROGRAM HISTORY LOG:
!    2009-01-20  Hu  Add NCO document block
!
!
!   input argument list:
!     nlon        - no. of lons on subdomain (buffer points on ends)
!     nlat        - no. of lats on subdomain (buffer points on ends)
!     nsig        - no. of levels
!     tbk         - 3D background potentional temperature (K)
!     pbk         - 3D background pressure  (hPa)
!     q           - 3D moisture  (kg/kg)
!     hbk         - 3D height
!     zh          - terrain
!
!   output argument list:
!     cv_bk       - 3D background cloud cover
!     t_k         - 3D temperature in K
!     z_lcl       - lifting condensation level
!
! USAGE:
!   INPUT FILES: 
!
!   OUTPUT FILES:
!
! REMARKS:
!
! ATTRIBUTES:
!   LANGUAGE: FORTRAN 90 
!   MACHINE:  Linux cluster (WJET)
!
!$$$
!
!_____________________________________________________________________
!
  use kinds, only: r_single,i_kind,r_kind
  use constants, only: h1000, rd_over_cp, g_over_rd

  implicit none

  integer(i_kind),intent(in):: nsig
! background
!
! read in from WRF
!
  real(r_single),intent(in) :: tbk(nsig)   ! potential temperature
  real(r_single),intent(in) :: zh         ! terrain elevation
  real(r_single),intent(in) :: q(nsig)     ! moisture
  real(r_single),intent(in) :: hbk(nsig)   ! height
  real(r_single),intent(in) :: pbk(nsig)   ! pressure

  real(r_single),intent(out) :: t_k(nsig)  ! temperature in K
  real(r_single):: z_lcl     ! lifting condensation level
  real(r_single),intent(out) :: cv_bk(nsig)!  cloud cover

!  CONSTANTS:
  real(r_single) :: gamma_d   ! dry adiabatic lapse rate (K/m)
  real(r_single) :: z_ref_lcl
  PARAMETER(z_ref_lcl = 180.0_r_single)

!  misc.
!
  real(r_single) :: rhbk(nsig)   ! rh

  INTEGER :: i,j,k


  REAL(r_kind) :: f_qvsat
  REAL(r_kind) :: qvsat
  REAL(r_kind) :: rh_to_cldcv

  REAL(r_kind) :: z_ref,x
  REAL(r_kind) :: arg,arg2, t_ref_c, td_ref_c
  REAL(r_kind) :: frac_z, t_ref_k,rh_ref

!
!================================================================
!
  gamma_d = g_over_rd/rd_over_cp
!
! get the RH
!
  do k=1,nsig
        t_k(k)=tbk(k)*(pbk(k)/h1000)**rd_over_cp
        qvsat=f_qvsat(pbk(k)*100.0_r_kind,t_k(k))   
                    ! Saturation water vapor specific humidity 
        qvsat = qvsat/(1.0 - qvsat)  ! convert to saturation mixing ratio (kg/kg)
        rhbk(k)=100._r_kind*MIN(1._r_kind,MAX(0._r_kind,(q(k)/qvsat)))
                                     ! q is mixing ration kg/kg
  enddo
!
!  Find the lifting condensation level
!
  z_lcl = -99999.0_r_kind
      z_ref = z_ref_lcl + zh
      IF (z_ref <= hbk(2) .OR. z_ref > hbk(nsig-1)) THEN
        write(6,*) 'Error, ref.level is out of bounds at pt:' &
                    ,i,j,z_ref,hbk(2),hbk(nsig-1)
        stop 200
      END IF

      DO k = 3,nsig-1
        IF ( z_ref < hbk(k) .and. z_ref >= hbk(k-1)) THEN
          frac_z = (z_ref-hbk(k-1))/(hbk(k)-hbk(k-1))
          t_ref_k = t_k(k-1)+ frac_z*(t_k(k)-t_k(k-1))
          t_ref_c = t_ref_k - 273.15_r_kind
!
          rh_ref = rhbk(k-1)+ frac_z*(rhbk(k)-rhbk(k-1))
!   compute dew point depression.
!          td_ref_c = dwpt(t_ref_c,rh_ref)
          x = 1._r_kind-0.01_r_kind*rh_ref
          td_ref_c =t_ref_c-(14.55_r_kind+0.114_r_kind*t_ref_c)*x+      &
                ((2.5_r_kind+0.007_r_kind*t_ref_c)*x)**3+      &
                (15.9_r_kind+0.117_r_kind*t_ref_c)*x**14

        END IF
      END DO  ! k = 2,nz-1
!
      z_lcl = z_ref + (t_ref_c - td_ref_c)/gamma_d
      z_lcl = min(hbk(nsig-1),max(z_lcl,hbk(2)))
!
!  get background cloud cover
!
  cv_bk=0.0_r_kind
  do k=1,nsig
        IF (hbk(k) >= z_lcl) THEN
           arg = hbk(k) - zh
           arg2=rhbk(k)*0.01_r_kind
           cv_bk(k) = rh_to_cldcv(arg2,arg)
        ENDIF
  enddo
!

END SUBROUTINE BckgrndCC

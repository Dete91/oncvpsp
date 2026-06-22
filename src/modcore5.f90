!
! Copyright (c) 1989-2024 by D. R. Hamann, Mat-Sim Research LLC and Rutgers
! University
!
!
! This program is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.
!
! Creates a model core charge AND a model core kinetic energy density by
! analytic continuation to the origin, following the meta-oncvpsp formalism.
! The "diff" densities cross over (via fcrossover) from the all-electron
! minus pseudo valence difference in the outer region to the all-electron
! core quantity in the inner region; the inner part is then continued
! smoothly to r=0 with rtloc so that the value at the origin equals
! fcfact times the pseudo-valence maximum.  rcfact scales a supplementary
! bump added inside the minimum core radius.

 subroutine modcore5(rhtps,rhoc,rhotae,tau,tauc,taups, &
&                    rhomod,taumod,fcfact,rcfact,ircmin,ircmax, &
&                    mmax,rr,icmod,lrhomod)

!rhtps  total pseudo-valence charge density
!rhoc  all-electron core charge density
!rhotae  total all-electron valence charge density
!tau  total all-electron kinetic energy density (full atom)
!tauc  all-electron core kinetic energy density
!taups  total pseudo-valence kinetic energy density
!rhomod  model core charge (col 1) and derivatives (cols 2-5, unused here)
!taumod  model core kinetic energy density
!fcfact  amplitude prefactor: origin value = fcfact * pseudo-valence maximum
!rcfact  scale prefactor for the inner supplementary bump
!ircmin  rr index of minimum core radius
!ircmax  rr index of maximum core radius
!mmax  dimension of log grid
!rr  log radial grid
!icmod  rtloc polynomial selector (5 for the icmod=5 continuation)
!lrhomod  .true.  -> build the model core charge (rhomod) and the model core
!                   KED (taumod); standard icmod=5 behavior.
!         .false. -> build only the model core KED (taumod); the rhomod block
!                   is skipped so a previously built rhomod is left untouched
!                   (used by the icmod=6 icmod3-density + icmod5-KED combination)

 implicit none
 integer, parameter :: dp=kind(1.0d0)

!Input variables
 integer :: mmax,ircmin,ircmax,icmod
 logical :: lrhomod
 real(dp) :: fcfact,rcfact
 real(dp) :: rr(mmax)
 real(dp) :: rhtps(mmax),rhoc(mmax),rhotae(mmax)
 real(dp) :: tau(mmax),tauc(mmax),taups(mmax)

!Output variables
 real(dp) :: rhomod(mmax,5),taumod(mmax)

!Local function
 real(dp) :: fcrossover

!Local variables
 integer :: ii,iter,irx,irxmin,irxmax
 real(dp) :: rhopsmax,taupsmax,mrho0,mtau0,xx
 real(dp), allocatable :: rhodiff(:),taudiff(:),rholoc(:),tauloc(:)

 allocate(rhodiff(mmax),taudiff(mmax),rholoc(mmax),tauloc(mmax))

 if(lrhomod) then
   write(6,'(/a)') 'Model core charge and kinetic energy density (icmod=5)'
 else
   write(6,'(/a)') 'Model core kinetic energy density (icmod=6 combination)'
 end if

! pseudo-valence maxima set the origin amplitudes
 rhopsmax=0.0d0
 taupsmax=0.0d0
 do ii=mmax,1,-1
   if(rhtps(ii)>rhopsmax) rhopsmax=rhtps(ii)
   if(taups(ii)>taupsmax) taupsmax=taups(ii)
 end do

! difference densities: AE-PS valence in the outer region crossing over to
! the AE core quantity in the inner region.  The AE total atom density is
! reconstructed as rhotae+rhoc; tau is already the full-atom AE quantity.
 rhodiff(:)=0.0d0
 taudiff(:)=0.0d0
 do ii=1,mmax
   xx=(1.3d0*rr(ircmax)-rr(ii))/(0.3d0*rr(ircmax))
   rhodiff(ii)= fcrossover(xx)*((rhotae(ii)+rhoc(ii))-rhtps(ii)) &
&             + fcrossover(-xx)*rhoc(ii)
   taudiff(ii)= fcrossover(xx)*(tau(ii)-taups(ii)) &
&             + fcrossover(-xx)*tauc(ii)
 end do

! ---- model core charge ----
!interval-halving search for the continuation radius so that
!rholoc(1)=fcfact*rhopsmax
!Skipped when lrhomod is .false. (icmod=6): the model core charge is then
!supplied separately by modcore3 and rhomod must not be overwritten here.

 if(lrhomod) then

 irxmax=0
 do ii=ircmin,1,-1
   if(irxmax==0 .and. rr(ii)<0.8d0*rr(ircmin)) irxmax=ii
   if(rr(ii)<0.1d0*rr(ircmin)) then
     irxmin=ii
     exit
   end if
 end do

 mrho0=fcfact*rhopsmax

 do ii=1,ircmin
   xx=rr(ii)/rr(ircmin)
   rhodiff(ii)=rhodiff(ii)+rcfact*rhopsmax*(1-xx**2)**4
 end do

 irx=ircmin

 do iter=1,20
   call rtloc(rr,rhodiff,rholoc,0.0d0,irx,mmax,icmod)
   if(rholoc(1)<mrho0) then
     irxmax=irx
   else
     irxmin=irx
   end if
   irx=(irxmax+irxmin)/2
 end do !iter

 write(6,'(a,f8.4)') 'Model core charge extension to rr=0 begins at rr =', &
&      rr(irx)

 rhomod(:,:)=0.0d0
 rhomod(:,1)=rholoc(:)

 end if !lrhomod

! ---- model core kinetic energy density ----
!interval-halving search for the continuation radius so that
!tauloc(1)=fcfact*taupsmax

 irxmax=0
 do ii=ircmin,1,-1
   if(irxmax==0 .and. rr(ii)<0.8d0*rr(ircmin)) irxmax=ii
   if(rr(ii)<0.1d0*rr(ircmin)) then
     irxmin=ii
     exit
   end if
 end do

 mtau0=fcfact*taupsmax

 do ii=1,ircmin
   xx=rr(ii)/rr(ircmin)
   taudiff(ii)=taudiff(ii)+rcfact*taupsmax*(1-xx**2)**4
 end do
 tauloc(:)=taudiff(:)

 irx=ircmin

 do iter=1,20
   call rtloc(rr,taudiff,tauloc,0.0d0,irx,mmax,icmod)
   if(tauloc(1)<mtau0) then
     irxmax=irx
   else
     irxmin=irx
   end if
   irx=(irxmax+irxmin)/2
 end do !iter

 write(6,'(a,f8.4)') 'Model tau extension to rr=0 begins at rr =',rr(irx)

 taumod(:)=tauloc(:)

 deallocate(rhodiff,taudiff,rholoc,tauloc)

 return
 end subroutine modcore5

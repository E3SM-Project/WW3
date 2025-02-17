#include "w3macros.h"
!/ ------------------------------------------------------------------- /
      MODULE W3IOBCMD
!/
!/                  +-----------------------------------+
!/                  | WAVEWATCH III           NOAA/NCEP |
!/                  |           H. L. Tolman            |
!/                  |                        FORTRAN 90 |
!/                  | Last update :         01-Mar-2018 |
!/                  +-----------------------------------+
!/
!/    See subroutine for update log.
!/
!/    Copyright 2009-2010 National Weather Service (NWS),
!/       National Oceanic and Atmospheric Administration.  All rights
!/       reserved.  WAVEWATCH III is a trademark of the NWS. 
!/       No unauthorized use without permission.
!/
!  1. Purpose :
!
!     Processing of boundary data output.
!
!  2. Variables and types :
!
!      Name      Type  Scope    Description
!     ----------------------------------------------------------------
!      VERBPTBC  C*10  Public   Nest file version number.
!      IDSTRBC   C*32  Public   Restart file ID string.
!     ----------------------------------------------------------------
!
!  3. Subroutines and functions :
!
!      Name      Type  Scope    Description
!     ----------------------------------------------------------------
!      W3IOBC    Subr. Public   Boundary data IO.
!     ----------------------------------------------------------------
!
!  4. Subroutines and functions used :
!
!      Name      Type  Module   Description
!     ----------------------------------------------------------------
!      W3SETO, W3SETG, W3SETW, W3SETA, W3DMO5
!                Subr. W3xDATMD Manage data structures.
!      W3CSPC    Subr. W3CSPCMD Spectral grid conversion.
!      W3LLTOEQ  Subr. W3CSPCMD Standard to rotated lat/lon conversion.
!      STRACE    Subr. W3SERVMD Subroutine tracing.
!      EXTCDE    Subr. W3SERVMD Abort program with exit code.
!     ----------------------------------------------------------------
!
!  5. Remarks :
!
!     None.
!
!  6. Switches :
!
!     See subroutine W3IOBC.
!
!  7. Source code :
!
!/ ------------------------------------------------------------------- /
      PUBLIC
!/
!/ Public variables  (ID strings)
!/
      CHARACTER(LEN=10), PARAMETER :: VERBPTBC = '2018-03-01'
      CHARACTER(LEN=32), PARAMETER ::                        &
                          IDSTRBC  = 'WAVEWATCH III BOUNDARY DATA FILE'
!/
      CONTAINS
!/ ------------------------------------------------------------------- /
      SUBROUTINE W3IOBC ( INXOUT, NDSB, TIME1, TIME2, IOTST, IMOD )
!/
!/                  +-----------------------------------+
!/                  | WAVEWATCH III           NOAA/NCEP |
!/                  |           H. L. Tolman            |
!/                  |                        FORTRAN 90 |
!/                  | Last update :         20-Jan-2017 |
!/                  +-----------------------------------+
!/
!/    12-Jan-1999 : Distributed FORTRAN 77 version.     ( version 1.18 )
!/    20-May-1999 : Remove read bug for IPBP and RDBP   ( see web page )
!/    30-Dec-1999 : Upgrade to FORTRAN 90               ( version 2.00 )
!/                  Major changes to logistics.
!/    13-Dec-2004 : Multiple grid version.              ( version 3.06 )
!/    19-Sep-2005 : Allow for change of spec. res.      ( version 3.08 )
!/                  (on read only).
!/    30-Sep-2005 : Add 'DUMP' option.                  ( version 3.08 )
!/    27-Jun-2006 : Adding file name preamble.          ( version 3.09 )
!/    29-May-2009 : Preparing distribution version.     ( version 3.14 )
!/    30-Oct-2009 : Implement curvilinear grid type.    ( version 3.14 )
!/                  (W. E. Rogers & T. J. Campbell, NRL)
!/    28-Jul-2010 : Moving NKI, NTHI, XFRI, FR1I and
!/                  TH1I to W3ODATMD.                   ( version 3.14.3 )
!/    31-Oct-2010 : Implementing unstructured grid      ( version 3.14.3 )
!/                  (A. Roland and F. Ardhuin) 
!/    05-Apr-2011 : Moved the W3CSPC call into loop     ( version 3.14.3 )
!/    12-Jun-2012 : Add /RTD option or rotated grid option. 
!/                  (Jian-Guo Li)                       ( version 4.06 )
!/    03-Jul-2013 : Corrected ABPIN indices             ( version 4.11 )
!/    14-Jan-2014 : Corrected ABPIN indices for W3CSPC  ( version 4.18 ) 
!/    20-Jan-2017 : Allow input boundary points to lie outside the grid
!/                  within a distance of 0.1 times the grid cell size.
!/                  (T.J. Campbell, NRL)                ( version 6.02 )
!/    01-Mar-2018 : Rotate boundary points and directions 
!/                  of input spectra for rotated grids  ( version 6.02 )
!/    07-Oct-2019 : RTD option with standard lat-lon
!/                  grid when nesting to rotated grid   ( version 7.11 )
!/
!  1. Purpose :
!
!     Write/read boundary conditions file(s).
!
!  2. Method :
!
!     The file(s) are opened within the routine, the names are
!     pre-defined as nest.FILEXT for the input file and nest1.FILEXT
!     through nest9.FILEXT for up to 9 output files. 
!
!  3. Parameters :
!
!     Parameter list
!     ----------------------------------------------------------------
!       INXOUT  C*(*)  I   Test string for read/write, valid are:
!                          'READ', 'WRITE' or 'DUMP'.
!       NDSB    Int.   I   Data set unit number.
!       TIME1   I.A.  I/O  Present time.                          (w)
!                          Time of first field.                   (r)
!       TIME2   I.A.   O   Time of second field.                  (r)
!       IOTST   Int.   O   Test indictor for reading.
!                           1 : File not found.
!                           0 : Fields read.
!                          -1 : Past end of file.
!       IMOD    Int.   I   Optional grid number, defaults to 1.
!     ----------------------------------------------------------------
!                                            (w) used for write only
!                                            (r) used for write only
!
!  4. Subroutines used :
!
!     See module documentation.
!
!  5. Called by :
!
!      Name      Type  Module   Description
!     ----------------------------------------------------------------
!      W3WAVE    Subr. W3WAVEMD Actual wave model routine.
!     ----------------------------------------------------------------
!
!  6. Error messages :
!
!       Tests on INXOUT, file status and data present in file.
!
!  7. Remarks :
!
!     - Array dimensions are tested in W3IOGR.
!     - Spectra are stored as frequency (sigma) spectra to guarantee
!       conservation under grid transformation.
!     - At the moment it is mplicitly assumed that the number of
!       spectral components is larger that the number of spectra
!       per time step per file.
!     - Dump option used in multi-grid model.
!
!  8. Structure :
!
!       See source code.
!
!  9. Switches :
!
!     !/SHRD  Switch for shared / distributed memory architecture.
!     !/DIST  Id.
!
!     !/S     Enable subroutine tracing.
!     !/T     General test output.
!     !/T0    Point info test output.
!     !/T1    Wave heights at input/output points.
!
! 10. Source code :
!
!/ ------------------------------------------------------------------- /
      USE CONSTANTS
!
      USE W3GDATMD, ONLY: W3SETG
      USE W3WDATMD, ONLY: W3SETW
      USE W3ADATMD, ONLY: W3SETA
      USE W3ODATMD, ONLY: W3SETO, W3DMO5
      USE W3CSPCMD, ONLY: W3CSPC
      USE W3TRIAMD, ONLY: W3NESTUG      
!
      USE W3GDATMD, ONLY: NK, NTH, NSPEC, NSEA, NSEAL, NX, NY,        &
                          X0, Y0, SX, SY, GSU, MAPSTA, MAPFS, MAPSF,  &
                          XFR, FR1, SIG2, TH, DTH, FILEXT, FACHFE,    &
                          GTYPE, UNGTYPE, SMCTYPE
      USE W3GDATMD, ONLY: DXYMAX  
#ifdef W3_T1
      USE W3GDATMD, ONLY: SIG
#endif
#ifdef W3_RTD
 !!   Use rotated N-Pole lat/lon and conversion sub.  JGLi12Jun2012
      USE W3GDATMD, ONLY: PoLat, PoLon, AnglD
      USE W3SERVMD, ONLY: W3LLTOEQ, W3EQTOLL, W3ACTURN
#endif
      USE W3WDATMD, ONLY: VA
      USE W3ADATMD, ONLY: CG
      USE W3ODATMD, ONLY: NDSE, NDST, IAPROC, NAPROC, NAPERR, NAPBPT, &
                          NBI, NBI2, NFBPO, NBO, NBO2, NDSL,          &
                          NKI, NTHI, XFRI, FR1I, TH1I,                &
                          IPBPI, ISBPI, XBPI, YBPI, RDBPI,            &
                          IPBPO, ISBPO, XBPO, YBPO, RDBPO,            &
                          ABPI0, ABPIN, ABPOS, FLBPI, FILER, FILEW,   &
                          FILED, SPCONV, FNMPRE
      USE W3GSRUMD
!
      USE W3SERVMD, ONLY: EXTCDE
#ifdef W3_S
      USE W3SERVMD, ONLY: STRACE
#endif
!
#ifdef W3_SMC
      USE W3PSMCMD, ONLY: W3SMCGMP
#endif
!
      IMPLICIT NONE
!/
!/ ------------------------------------------------------------------- /
!/ Parameter list
!/
      INTEGER, INTENT(IN)           :: NDSB
      INTEGER, INTENT(INOUT)        :: TIME1(2)
      INTEGER, INTENT(OUT)          :: TIME2(2), IOTST
      INTEGER, INTENT(IN), OPTIONAL :: IMOD
      CHARACTER, INTENT(IN)         :: INXOUT*(*)
!/
!/
!/ ------------------------------------------------------------------- /
!/ Local parameters
!/
      INTEGER                 :: IFILE, IERR, I, J, IX, IY, ISEA,     &
                                 IP, ISP, NPTS, ISOUT, IS, IGRD
#ifdef W3_T1
      INTEGER               :: IK, ITH
#endif
#ifdef W3_S
      INTEGER, SAVE           :: IENT = 0
#endif
#ifdef W3_T1
      REAL                  :: HS, HS0
#endif
#ifdef W3_RTD
  !!    Declare rotation angle and rotated lat/lon variables for
  !!    boundary points.   JGLi12Jun2012
      REAL, ALLOCATABLE      :: Anglbdy(:), ELatbdy(:), ELonbdy(:) 
      REAL                   :: Spectr(NK*NTH)
      REAL                   :: XRLIM, YRLIM
#endif
      REAL, ALLOCATABLE       :: TMPSPC(:,:)
      LOGICAL                 :: FLOK
      CHARACTER(LEN=18)       :: FILEN
      CHARACTER(LEN=10)       :: VERTST
      CHARACTER(LEN=32)       :: IDTST
!/
!/ ------------------------------------------------------------------- /
!/
#ifdef W3_S
      CALL STRACE (IENT, 'W3IOBC')
#endif
!
      IOTST  = 0
!
! test parameter list input ------------------------------------------ *
!
      IF ( PRESENT(IMOD) ) THEN
          IGRD   = IMOD
        ELSE
          IGRD   = 1
        END IF
!
      CALL W3SETO ( IGRD, NDSE, NDST )
      CALL W3SETG ( IGRD, NDSE, NDST )
      CALL W3SETW ( IGRD, NDSE, NDST )
      CALL W3SETA ( IGRD, NDSE, NDST )
!
      IF (INXOUT.NE.'READ' .AND. INXOUT.NE.'WRITE' .AND.              &
          INXOUT.NE.'DUMP' ) THEN
          IF ( IAPROC .EQ. NAPERR ) WRITE (NDSE,900) INXOUT
          CALL EXTCDE ( 1 )
        END IF
!
#ifdef W3_T
      WRITE (NDST,9000) INXOUT, FILER, FILEW, FILED, NDSB
#endif
!
! open file ---------------------------------------------------------- *
!
      I      = LEN_TRIM(FILEXT)
      J      = LEN_TRIM(FNMPRE)
!
      IF ( INXOUT.EQ.'READ'  .AND. FILER ) THEN
          WRITE (FILEN,'(A5,A)') 'nest.', FILEXT(:I)
#ifdef W3_T
          WRITE (NDST,9001) FILEN(:5+I), NDSB
#endif
          OPEN (NDSB,FILE=FNMPRE(:J)//FILEN(:5+I),FORM='UNFORMATTED', &
                ERR=801,IOSTAT=IERR,STATUS='OLD')
        END IF
!
      IF ( INXOUT.EQ.'WRITE' .AND. FILEW ) THEN
          DO IFILE=1, NFBPO
            NDSL(IFILE) = NDSB + IFILE - 1
            WRITE (FILEN,'(A4,I1,A1,A)') 'nest', IFILE, '.',          &
                                         FILEXT(:I)
#ifdef W3_T
            WRITE (NDST,9001) FILEN(:6+I), NDSL(IFILE)
#endif
            OPEN (NDSL(IFILE),FILE=FNMPRE(:J)//FILEN(:6+I),           &
                  FORM='UNFORMATTED',ERR=800,IOSTAT=IERR)
            END DO
        END IF
!
      IF ( INXOUT.EQ.'DUMP'  .AND. FILED ) THEN
          WRITE (FILEN,'(A5,A)') 'nest.', FILEXT(:I)
#ifdef W3_T
          WRITE (NDST,9001) FILEN(:5+I), NDSB
#endif
          OPEN (NDSB,FILE=FNMPRE(:J)//FILEN(:5+I),FORM='UNFORMATTED', &
                ERR=800,IOSTAT=IERR)
        END IF
!
! test info ---------------------------------------------------------- *
! ( new files only )
! ... writing
!
      IF ( INXOUT.EQ.'WRITE' .AND. FILEW ) THEN
          IF ( IAPROC .EQ. NAPBPT ) THEN
              DO IFILE=1, NFBPO
                WRITE (NDSL(IFILE))                                   &
                      IDSTRBC, VERBPTBC, NK, NTH, XFR, FR1, TH(1),    &
                      NBO(IFILE)-NBO(IFILE-1)
!
#ifdef W3_T
                WRITE (NDST,9002) IFILE, NDSL(IFILE), IDSTRBC,       &
                       VERBPTBC, NBO(IFILE)-NBO(IFILE-1)
#endif
!
#ifdef W3_RTD
 ! By running the ww3_grid program the arrays XBPO, YBPO have been
 ! remapped to standard lat-lon and stored in mod_def.*
 !
#endif
                WRITE (NDSL(IFILE))                                   &
                       (XBPO(I),I=NBO(IFILE-1)+1,NBO(IFILE)),         &
                       (YBPO(I),I=NBO(IFILE-1)+1,NBO(IFILE)),         &
                     ((IPBPO(I,J),I=NBO(IFILE-1)+1,NBO(IFILE)),J=1,4),&
                     ((RDBPO(I,J),I=NBO(IFILE-1)+1,NBO(IFILE)),J=1,4)
!
#ifdef W3_T0
                WRITE (NDST,9003)
                DO I=NBO(IFILE-1)+1, NBO(IFILE)
                  WRITE (NDST,9004) I-NBO(IFILE-1), XBPO(I),      &
                         YBPO(I), (IPBPO(I,J),J=1,4),             &
                         (RDBPO(I,J),J=1,4)
                  END DO
#endif
!
                END DO
            END IF
        END IF
!
! ... dumping
!
      IF ( INXOUT.EQ.'DUMP' .AND. FILED ) THEN
          IF ( IAPROC .EQ. NAPBPT ) THEN
              WRITE (NDSB) IDSTRBC, VERBPTBC, NK, NTH, XFR, FR1, TH(1), NBI
!
#ifdef W3_T
              WRITE (NDST,9002) 1, NDSB, IDSTRBC, VERBPTBC, NBI
#endif
!
              WRITE (NDSB) (XBPI(I),I=1,NBI), (YBPI(I),I=1,NBI),      &
                           ((IPBPI(I,J),I=1,NBI),J=1,4),              &
                           ((RDBPI(I,J),I=1,NBI),J=1,4)
!
#ifdef W3_T0
          WRITE (NDST,9003)
          DO I=1, NBI
            WRITE (NDST,9004) I, XBPI(I), YBPI(I),                &
                   (IPBPI(I,J),J=1,4), (RDBPI(I,J),J=1,4)
            END DO
#endif
!
            END IF
        END IF
!
! ... reading
!
      IF ( INXOUT.EQ.'READ' .AND. FILER ) THEN
!
          READ (NDSB,ERR=803,IOSTAT=IERR)                             &
                IDTST, VERTST, NKI, NTHI, XFRI, FR1I, TH1I, NBI
!
#ifdef W3_T
          WRITE (NDST,9002) 1, NDSB, IDTST, VERTST, NBI
#endif
!
          IF ( IDTST .NE. IDSTRBC ) THEN
              IF ( IAPROC .EQ. NAPERR )                               &
                   WRITE (NDSE,901) IDTST, IDSTRBC
              CALL EXTCDE ( 10 )
            END IF
          IF ( VERTST .NE. VERBPTBC ) THEN
              IF ( IAPROC .EQ. NAPERR )                               &
                   WRITE (NDSE,902) VERTST, VERBPTBC
              CALL EXTCDE ( 11 )
            END IF
!
! Determines if the spectrum in nest file needs to be converted 
!
          SPCONV = NKI.NE.NK .OR. NTHI.NE.NTH .OR.                    &
                   ABS(XFRI/XFR-1.).GT.0.01 .OR.                      &
                   ABS(FR1I/FR1-1.).GT.0.01 .OR.                      &
                   ABS(TH1I-TH(1)).GT.0.01*DTH 
!
          CALL W3DMO5 ( IGRD, NDSE, NDST, 1 )
!
          READ (NDSB,ERR=803,IOSTAT=IERR)                             &
              (XBPI(I),I=1,NBI), (YBPI(I),I=1,NBI),                   &
              ((IPBPI(I,J),I=1,NBI),J=1,4),                           &
              ((RDBPI(I,J),I=1,NBI),J=1,4)
!
#ifdef W3_RTD
 ! All boundary conditions position arrays XBPI, YBPI are defined
 ! in standard lat/lon coordinates. If Polat = 90. (and Polon = -180.),
 ! the b.c. positions don't need to be remapped 
        IF ( Polat < 90. ) THEN
 !!   Convert standard into rotated lat/lon. JGLi12Jun2012
          ALLOCATE ( Anglbdy(NBI),  ELatbdy(NBI), ELonbdy(NBI) )

          CALL W3LLTOEQ ( YBPI, XBPI, ELatbdy, ELonbdy,     &
       &                 Anglbdy, PoLat, PoLon, NBI )

          XBPI = ELonbdy
          YBPI = ELatbdy
 !!    W3LLTOEQ outputs longitudes on 0->360 degree grid
 !!    Next section will revise to -180->180 convention if required
 !!    by nested model rotated grid; determined by X0 lon value
          IF ( X0 .LT. 0.0 ) THEN
            DO I=1, NBI
              IF ( XBPI(I) .GT. 180.0) XBPI(I) = XBPI(I) - 360.0
            ENDDO
          END IF
 !!    The old (4.18) W3GFPT was very strict so this loop reassigns RTD 
 !!    values to within a tolerance of the boundary - possibly this is
 !!    no longer required after the 20-Jan-2017 change?
          XRLIM = X0 + (NX-1) * SX
          YRLIM = Y0 + (NY-1) * SY
          DO I=1, NBI
            IF ( ABS(XBPI(I) - X0) .LT. SX/4.0 ) XBPI(I) = X0
            IF ( ABS(YBPI(I) - Y0) .LT. SY/4.0 ) YBPI(I) = Y0
            IF ( ABS(XBPI(I) - XRLIM) .LT. SX/4.0 ) XBPI(I) = XRLIM
            IF ( ABS(YBPI(I) - YRLIM) .LT. SY/4.0 ) YBPI(I) = YRLIM
          ENDDO

          DEALLOCATE ( Anglbdy,  ELatbdy, ELonbdy )

        END IF ! ( Polat < 90. )

#endif
          FLOK   = .TRUE.
          IF (GTYPE .EQ. UNGTYPE) THEN
            CALL W3NESTUG(DXYMAX,FLOK) 
#ifdef W3_SMC
 !Li   For SMC grid check whether boundary points are within cell area.
          ELSE IF( GTYPE .EQ. SMCTYPE ) THEN
            CALL W3SMCGMP( IGRD, NBI, XBPI, YBPI, ISBPI )
            IF ( IAPROC .EQ. NAPERR ) WRITE (NDSE,920)    &
               ( ISBPI(I), XBPI(I), YBPI(I), I=1,NBI ) 
#endif
          ELSE 
            DO I=1, NBI
              ! W3GFTP: find the nearest grid point to the input boundary point
              ! DCIN=0.1 is the distance outside of source grid in units of
              ! cell width to treat target point as inside the source grid.
              IF ( W3GFPT( GSU, XBPI(I), YBPI(I), IX, IY, DCIN=0.1 ) ) THEN
                IF ( ABS(MAPSTA(IY,IX)) .NE. 2 ) THEN
                    IF ( IAPROC .EQ. NAPERR )                         &
                        WRITE (NDSE,909) IX, IY, ABS(MAPSTA(IY,IX))
                    FLOK   = .FALSE.
                  END IF
              ELSE
                IF ( IAPROC .EQ. NAPERR )                             &
                    WRITE (NDSE,910) I, XBPI(I), YBPI(I)
                CALL EXTCDE ( 12 )
              END IF
            ISBPI(I) = MAPFS(IY,IX)
            END DO
          END IF    
!
#ifdef W3_T0
          WRITE (NDST,9003)
          DO I=1, NBI
            WRITE (NDST,9005) I, ISBPI(I), XBPI(I), YBPI(I),      &
                   (IPBPI(I,J),J=1,4), (RDBPI(I,J),J=1,4)
            END DO
#endif
!
          IF ( .NOT.FLOK ) CALL EXTCDE ( 20 )
!
          DO ISEA=1, NSEA
            IX     = MAPSF(ISEA,1)
            IY     = MAPSF(ISEA,2)
            IF ( ABS(MAPSTA(IY,IX)) .EQ. 2 ) THEN
                FLOK   = .FALSE.
                DO I=1, NBI
                  IF ( ISEA .EQ. ISBPI(I) ) FLOK = .TRUE.
                  END DO
                IF ( .NOT.FLOK .AND. IAPROC.EQ.NAPERR )               &
                    WRITE (NDSE,911) IX, IY
              END IF
            END DO
!
!     Read first time and allocate ABPI0/N
!
          READ (NDSB,END=810,ERR=810) TIME2, NBI2
          BACKSPACE (NDSB)
#ifdef W3_T
          WRITE (NDST,9012) NDSB, TIME2, NBI2
#endif
          CALL W3DMO5 ( IGRD, NDSE, NDST, 3 )
!
        END IF
!
! Save previous spectra on read -------------------------------------- *
!
      IF ( INXOUT.EQ.'READ' .AND. .NOT.FILER ) THEN
#ifdef W3_T
          WRITE (NDST,9020)
#endif
          TIME1  = TIME2
          ABPI0(:,1:NBI2) = ABPIN(:,1:NBI2)
        END IF
!
! TIME --------------------------------------------------------------- *
!
      IF ( INXOUT .EQ. 'WRITE'  ) THEN
          DO IFILE=1, NFBPO
            NPTS   = NBO2(IFILE) - NBO2(IFILE-1)
            WRITE (NDSL(IFILE)) TIME1, NPTS
#ifdef W3_T
            WRITE (NDST,9010) IFILE, NDSL(IFILE), TIME1, NPTS
#endif
            END DO
        END IF
!
      IF ( INXOUT .EQ. 'DUMP'  ) THEN
          WRITE (NDSB) TIME1, NBI2
#ifdef W3_T
          WRITE (NDST,9011) NDSB, TIME1, NBI2
#endif
        END IF
!
      IF ( INXOUT .EQ. 'READ'  ) THEN
          READ (NDSB,ERR=810,END=810) TIME2, NBI2
#ifdef W3_T
          WRITE (NDST,9011) NDSB, TIME2, NBI2
#endif
        END IF
!
! Spectra ------------------------------------------------------------ *
!
      IF ( INXOUT .EQ. 'WRITE' ) THEN
!
#ifdef W3_T1
          WRITE (NDST,9040)
#endif
!
          DO IFILE=1, NFBPO
            DO ISOUT=NBO2(IFILE-1)+1, NBO2(IFILE)
!
              ISEA   = ISBPO(ISOUT)
!
! ... Shared memory version data gather
!
#ifdef W3_SHRD
              DO IS=1, NSPEC
                ABPOS(IS,ISOUT) = VA(IS,ISEA) * SIG2(IS) /      &
                                    CG(1+(IS-1)/NTH,ISEA)
                END DO
#endif
!
! ... Distributed memory version data gather
!   ( Array pre-filled in W3WAVE )
!
#ifdef W3_DIST
              DO IS=1, NSPEC
                ABPOS(IS,ISOUT) = ABPOS(IS,ISOUT) * SIG2(IS) /  &
                                    CG(1+(IS-1)/NTH,ISEA)
                END DO
#endif
!
#ifdef W3_RTD
 ! Polat == 90. means the grid is standard lat-lon, and the spectra
 ! need not be rotated back 
              IF ( Polat < 90. ) THEN
                ! Added spectral turning for rotated grid
                ! (rotate back to standard pole)
                Spectr = ABPOS(:,ISOUT)
                CALL W3ACTURN( NTH, NK, -AnglD(ISEA), Spectr )
                ABPOS(:,ISOUT) = Spectr
                END IF
#endif
!
              WRITE (NDSL(IFILE)) (ABPOS(IS,ISOUT),IS=1,NSPEC)
!
#ifdef W3_T1
              HS     = 0.
              DO IK=1, NK
                DO ITH=1, NTH
                  IS = ITH + (IK-1)*NTH
                  HS = HS + ABPOS(IS,ISOUT)*SIG(IK)
                  END DO
                END DO
              HS     = 4. * SQRT ( HS * DTH * 0.5 * (XFR-1./XFR) )
              WRITE (NDST,9041) NDSL(IFILE), ISOUT, ISEA, HS
#endif
!
              END DO
            END DO
!
        END IF
!
      IF ( INXOUT .EQ. 'DUMP' ) THEN
          DO I=1, NBI2
            WRITE (NDSB) ABPIN(:,I)
            END DO
        END IF
!
      IF ( INXOUT .EQ. 'READ' ) THEN
!
          IF ( .NOT. SPCONV ) THEN
              DO IP=1, NBI2
                READ (NDSB,ERR=803,IOSTAT=IERR) ABPIN(:,IP)
                END DO
            ELSE
!
! In this case the spectral resolution is not compatible and 
! the spectrum TMPSPC in nest file must be re-gridded into ABPIN to fit the model run
! spectral conversion is done by W3CSPC in w3cspcmd.ftn 
!
              ALLOCATE ( TMPSPC(NKI*NTHI,NBI2) )
              DO IP=1, NBI2
                READ (NDSB,ERR=803,IOSTAT=IERR) TMPSPC(:,IP)
                END DO
              CALL W3CSPC ( TMPSPC     ,    NKI, NTHI, XFRI, FR1I, TH1I, &
                            ABPIN(:,1:NBI2),NK,  NTH,  XFR,  FR1,  TH(1),&
                            NBI2, NDST, NDSE, FACHFE )
              DEALLOCATE ( TMPSPC )
            END IF
!
#ifdef W3_T1
          WRITE (NDST,9042)
          DO IP=1, NBI2
            HS     = 0.
            HS0    = 0.
            DO ISP=1, NSPEC
              HS     = HS + ABPIN(ISP,IP)*SIG2(ISP)
              IF ( .NOT.FILER ) HS0 = HS0 + ABPI0(ISP,IP)*SIG2(ISP)
              END DO
            HS     = 4. * SQRT ( HS * DTH * 0.5 * (XFR-1./XFR) )
            HS0    = 4. * SQRT ( HS0 * DTH * 0.5 * (XFR-1./XFR) )
            WRITE (NDST,9043) IP, HS0, HS
            END DO
#endif
!
        END IF
!
! Set first spectra on first read ------------------------------------ *
!
      IF ( INXOUT.EQ.'READ' .AND. FILER ) THEN
#ifdef W3_T
          WRITE (NDST,9021)
#endif
          TIME1 = TIME2
          DO IP=1, NBI2
            ABPI0(:,IP) = ABPIN(:,IP)
            END DO
          ABPI0(:,0) = 0.
          ABPIN(:,0) = 0.
        END IF
!
! Reset flags -------------------------------------------------------- *
!
      IF ( INXOUT .EQ. 'WRITE' ) FILEW  = .FALSE.
      IF ( INXOUT .EQ. 'DUMP'  ) FILED  = .FALSE.
      IF ( INXOUT .EQ. 'READ'  ) FILER  = .FALSE.
!
      RETURN
!
! Escape locations IO errors
!
  800 CONTINUE
      IF ( IAPROC .EQ. NAPERR ) WRITE (NDSE,1000) FILEN, IERR
      CALL EXTCDE ( 40 )
!
  801 CONTINUE
      IF ( IAPROC .EQ. NAPERR ) WRITE (NDSE,1001) IMOD
      IOTST  = 1
      FLBPI  = .FALSE.
      RETURN
!
  802 CONTINUE
      IF ( IAPROC .EQ. NAPERR ) WRITE (NDSE,1002)
      CALL EXTCDE ( 41 )
!
  803 CONTINUE
      IF ( IAPROC .EQ. NAPERR ) WRITE (NDSE,1003) IERR
      CALL EXTCDE ( 42 )
!
  810 CONTINUE
      IF ( FILER ) THEN
          IF ( IAPROC .EQ. NAPERR ) WRITE (NDSE,1010)
          CALL EXTCDE ( 43 )
        END IF
!
#ifdef W3_T
      WRITE (NDST,9022)
#endif
      TIME1(1) = TIME2(1)
      TIME1(2) = TIME2(2)
      DO 812, IP=0, NBI2
        DO 811, ISP=1, NSPEC
          ABPI0(ISP,IP) = ABPIN(ISP,IP)
  811     CONTINUE
  812   CONTINUE
!
      IOTST  = -1
      FLBPI  = .FALSE.
      RETURN
!
! Formats
!
  900 FORMAT (/' *** WAVEWATCH III ERROR IN W3IOBC :'/                &
               '     ILLEGAL INXOUT VALUE: ',A/)
  901 FORMAT (/' *** WAVEWATCH III ERROR IN W3IOBC :'/                &
               '     ILLEGAL IDSTRBC, READ : ',A/                     &
               '                  CHECK : ',A/)
  902 FORMAT (/' *** WAVEWATCH III ERROR IN W3IOBC :'/                &
               '     ILLEGAL VEROGR, READ : ',A/                      &
               '                   CHECK : ',A/)
!
  909 FORMAT (/' *** WAVEWATCH III ERROR IN W3IOBC :'/                &
               '     POINT',2I4,' NOT ACTIVE SEA POINT (',I1,')')
  910 FORMAT (/' *** WAVEWATCH III ERROR IN W3IOBC :'/                &
               '     POINT',I4,2E14.6,' NOT LOCATED IN GRID')
  911 FORMAT ( ' *** WAVEWATCH III WARNING : POINT',2I7,              &
                   ' WILL NOT BE UPDATED')
  920 FORMAT (/' *** SMCTYPE mapped boundary cells:'/ ((I8,2F9.3)) )
!
 1000 FORMAT (/' *** WAVEWATCH III ERROR IN W3IOBC : '/               &
               '     ERROR IN OPENING FILE ',A/                       &
               '     IOSTAT =',I5/)
!
! Note: This 1001 error can occur when multi-grid time steps are not
!       compatible.
 1001 FORMAT (/' *** WAVEWATCH III WARNING IN W3IOBC : '/             &
               '     INPUT FILE WITH BOUNDARY CONDITIONS NOT FOUND'/  &
               '     BOUNDARY CONDITIONS WILL NOT BE UPDATED ',I5/)
 1002 FORMAT (/' *** WAVEWATCH III ERROR IN W3IOBC : '/               &
               '     PREMATURE END OF FILE'/)
 1003 FORMAT (/' *** WAVEWATCH III ERROR IN W3IOBC : '/               &
               '     ERROR IN READING FROM FILE'/                     &
               '     IOSTAT =',I5/)
!
 1010 FORMAT (/' *** WAVEWATCH III ERROR IN W3IOBC : '/               &
               '     NO DATA IN INPUT FILE'/)
!
#ifdef W3_T
 9000 FORMAT (' TEST W3IOBC : INXOUT  : ',A5/                      &
              '               FLAGS   : ',3L2/                     &
              '               UNIT    : ',I4)
 9001 FORMAT (' TEST W3IOBC : OPENING FILE ',A,'  (',I2,')')
 9002 FORMAT (' TEST W3IOBC : FILE #  : ',I4/                      &
              '               UNIT    : ',I4/                      &
              '               ID      : ',A/                       &
              '               VERSION : ',A/                       &
              '               POINTS  : ',I4)
#endif
!
#ifdef W3_T0
 9003 FORMAT (' TEST W3IOBC : POINT DATA ')
 9004 FORMAT ('             ',I3,2E10.3,2X,4I4,2X,4F5.2)
 9005 FORMAT ('             ',I3,I4,2E10.3,2X,4I4,2X,4F5.2)
#endif
!
#ifdef W3_T
 9010 FORMAT (' TEST W3IOBC : OUTPUT FILE ',I1,' UNIT',I3,' TIME', &
                 I9.8,I7.6,',',I5,' SPECTRA')
 9011 FORMAT (' TEST W3IOBC : INPUT FILE UNIT',I3,' TIME',         &
                 I9.8,I7.6,',',I5,' SPECTRA')
 9012 FORMAT (' TEST W3IOBC : INPUT FILE UNIT',I3,' TIME',         &
                 I9.8,I7.6,',',I5,' SPECTRA (TEST READ)')
#endif
!
#ifdef W3_T
 9020 FORMAT (' TEST W3IOBC : SAVING OLD DATA')
 9021 FORMAT (' TEST W3IOBC : SAVING FIRST DATA')
 9022 FORMAT (' TEST W3IOBC : EOF REACHED')
#endif
!
#ifdef W3_T1
 9040 FORMAT (' TEST W3IOBC : UNIT, ISOUT, ISEA, HS(NO TAIL) ')
 9041 FORMAT ( '            ',I3,2I6,F8.2)
 9042 FORMAT (' TEST W3IOBC : IP, HS(NO TAIL) ')
 9043 FORMAT ( '         ',I6,2F8.2)
#endif
!/
!/ End of W3IOBC ----------------------------------------------------- /
!/
      END SUBROUTINE W3IOBC
!/
!/ End of module W3IOBCMD -------------------------------------------- /
!/
      END MODULE W3IOBCMD

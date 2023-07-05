module DomainType

  use NamelistRead, only: namelist_type
  use DateTimeUtilsModule
  
  implicit none
  save
  private
  
  type, public :: domain_type
  
    integer             :: iloc              ! i index in grid  
    integer             :: jloc              ! j index in grid
    real                :: DT                ! run timestep (s)
    character(len=12)   :: startdate         ! Start date of the model run ( YYYYMMDDHHmm ) 
    character(len=12)   :: enddate           ! End date of the model run ( YYYYMMDDHHmm ) 
    character(len=12)   :: nowdate           ! Current date of the model run ( YYYYMMDDHHmm ) 
    real*8              :: start_datetime    ! unix start datetime (s since 1970-01-01 00:00:00) ?UTC? 
    real*8              :: end_datetime      ! unix end datetime (s since 1970-01-01 00:00:00) ?UTC? 
    real*8              :: curr_datetime     ! unix current datetime (s since 1970-01-01 00:00:00) ?UTC? 
    integer             :: itime             ! current integer time step of model run
    integer             :: ntime             ! total number of integer time steps in model run
    double precision    :: time_dbl          ! current time of model run in seconds from beginning
    real                :: lat               ! latitude (°)
    real                :: lon               ! longitude (°)
    real                :: ZREF              ! measurement height of wind speed (m)
    real                :: terrain_slope     ! terrain slope (°)
    real                :: azimuth           ! terrain azimuth or aspect (° clockwise from north)
    integer             :: vegtyp            ! land cover type
    integer             :: croptype          ! crop type
    integer             :: isltyp            ! soil type
    integer             :: IST               ! surface type 1-soil; 2-lake
    real, allocatable, dimension(:) :: zsoil   ! depth of layer-bottom from soil surface
    real, allocatable, dimension(:) :: dzsnso  ! snow/soil layer thickness [m]
    real, allocatable, dimension(:) :: zsnso   ! depth of snow/soil layer-bottom
    integer                         :: soilcolor

    contains
  
      procedure, public  :: Init         
      procedure, private :: InitAllocate 
      procedure, private :: InitDefault     
  
  end type domain_type
  
  contains   
  
    subroutine Init(this, namelist)
  
      class(domain_type)  :: this
      type(namelist_type) :: namelist
  
      call this%InitAllocate(namelist)
      call this%InitDefault()
  
    end subroutine Init
  
    subroutine InitAllocate(this, namelist)
  
      class(domain_type) :: this
      type(namelist_type) :: namelist
  
      associate(nsoil => namelist%nsoil, &
                nsnow => namelist%nsnow)

      if(.NOT.allocated(this%zsoil))  allocate(this%zsoil  (nsoil))
      if(.NOT.allocated(this%dzsnso)) allocate(this%dzsnso (-nsnow+1:nsoil))
      if(.NOT.allocated(this%zsnso))  allocate(this%zsnso  (-nsnow+1:nsoil))
  
      end associate

    end subroutine InitAllocate
  
    subroutine InitDefault(this)
  
      class(domain_type) :: this
  
      this%iloc           = huge(1)
      this%jloc           = huge(1)
      this%dt             = huge(1.0)
      this%startdate      = 'EMPTYDATE999'
      this%enddate        = 'EMPTYDATE999'
      this%nowdate        = 'EMPTYDATE999'
      this%start_datetime = huge(1)
      this%end_datetime   = huge(1)
      this%curr_datetime  = huge(1)
      this%itime          = huge(1) 
      this%ntime          = huge(1) 
      this%time_dbl       = huge(1.d0)
      this%lat            = huge(1.0)
      this%lon            = huge(1.0)
      this%terrain_slope  = huge(1.0)
      this%azimuth        = huge(1.0)
      this%ZREF           = huge(1.0)
      this%vegtyp         = huge(1)
      this%croptype       = huge(1)
      this%isltyp         = huge(1)
      this%IST            = huge(1)
      this%soilcolor      = huge(1)
      this%zsoil(:)       = huge(1.0)
      this%dzsnso(:)      = huge(1.0)
      this%zsnso(:)       = huge(1.0)
  
    end subroutine InitDefault
  
  end module DomainType
  
  
module ForcingGridType

use NamelistRead,   only: namelist_type
use AttributesType, only: attributes_type
use DomainGridType, only: domaingrid_type

implicit none
private

type, public :: forcinggrid_type

! atmospheric inputs (meteorology, chemistry)
real,allocatable,dimension(:,:)                   :: SFCPRS       ! surface pressure (pa)
real,allocatable,dimension(:,:)                   :: SFCTMP       ! surface air temperature [K]
real,allocatable,dimension(:,:)                   :: Q2           ! specific humidity (note: in some Noah-MP versions Q2 is mixing ratio)
real,allocatable,dimension(:,:)                   :: PRCP         ! total input precipitation[mm/s]
real,allocatable,dimension(:,:)                   :: PRCPCONV     ! convective precipitation entering  [mm/s]
real,allocatable,dimension(:,:)                   :: PRCPNONC     ! non-convective precipitation entering [mm/s]
real,allocatable,dimension(:,:)                   :: PRCPSHCV     ! shallow convective precip entering  [mm/s]
real,allocatable,dimension(:,:)                   :: PRCPSNOW     ! snow entering land model [mm/s] 
real,allocatable,dimension(:,:)                   :: PRCPGRPL     ! graupel entering land model [mm/s]
real,allocatable,dimension(:,:)                   :: PRCPHAIL     ! hail entering land model [mm/s]             
real,allocatable,dimension(:,:)                   :: SOLDN        ! downward shortwave radiation (w/m2)
real,allocatable,dimension(:,:)                   :: LWDN         ! atmospheric longwave radiation (w/m2)
real,allocatable,dimension(:,:)                   :: FOLN         ! foliage nitrogen concentration (%)
real,allocatable,dimension(:,:)                   :: O2PP         ! atmospheric co2 concentration partial pressure (pa)
real,allocatable,dimension(:,:)                   :: CO2PP        ! atmospheric o2 concentration partial pressure (pa) 
real,allocatable,dimension(:,:)                   :: UU           ! wind speed in eastward dir (m/s)  
real,allocatable,dimension(:,:)                   :: VV           ! wind speed in northward dir (m/s)  

! surface inputs
real,allocatable,dimension(:,:)                   :: TBOT         ! bottom condition for soil temperature [K]

! outputs
real,allocatable,dimension(:,:)                   :: UR           ! wind speed at reference height (m/s)
real,allocatable,dimension(:,:)                   :: THAIR        ! potential temperature (k)
real,allocatable,dimension(:,:)                   :: QAIR         ! specific humidity (kg/kg) (q2/(1+q2))
real,allocatable,dimension(:,:)                   :: EAIR         ! vapor pressure air (pa)
real,allocatable,dimension(:,:)                   :: RHOAIR       ! density air (kg/m3)
real,allocatable,dimension(:,:)                   :: FPICE        ! fraction of ice in precipitation (-)
real,allocatable,dimension(:,:)                   :: SWDOWN       ! downward solar filtered by sun angle [w/m2]
real                                              :: JULIAN       ! julian day of year
integer                                           :: YEARLEN      ! year length (days)
             
real, allocatable, dimension(:,:,:)               :: SOLAD  !incoming direct solar radiation (w/m2)
real, allocatable, dimension(:,:,:)               :: SOLAI  !incoming diffuse solar radiation (w/m2)

! standalone forcings
character(len=256)                                :: forcings_dir         ! name of the forcings directory
character(len=256)                                :: forcings_file_prefix ! name of the forcings directory
character(len=256)                                :: forcings_file_name   ! name of the forcings directory
character(len=7)                                  :: forcing_file_type    ! Start date of the model run ( HOURLY, DAILY, MONTHLY, or YEARLY )
integer                                           :: iread,ncid,status,iread_max,iread_step
real,allocatable,dimension(:,:,:)                 :: read_windspeed
real,allocatable,dimension(:,:,:)                 :: read_winddir
real,allocatable,dimension(:,:,:)                 :: read_temperature
real,allocatable,dimension(:,:,:)                 :: read_pressure
real,allocatable,dimension(:,:,:)                 :: read_humidity
real,allocatable,dimension(:,:,:)                 :: read_swrad
real,allocatable,dimension(:,:,:)                 :: read_lwrad
real,allocatable,dimension(:,:,:)                 :: read_rain
real,allocatable,dimension(:)                     :: read_time
real                                              :: sim_dt
real*8                                            :: file_min_time,file_max_time


  contains

    procedure, public  :: Init         
    procedure, private :: InitAllocate        
    procedure, private :: InitDefault
    procedure, public  :: InitTransfer     
    procedure, public  :: ReadForcings     
    procedure, public  :: SetForcings    
    procedure, private :: GetForcingsFileName
    procedure, private :: FindTimeStepIndex

end type

contains   

  subroutine Init(this,attributes)

    class(forcinggrid_type), intent(inout) :: this
    type(attributes_type),   intent(in)    :: attributes

    call this%InitAllocate(attributes)
    call this%InitDefault()

  end subroutine Init
  
  subroutine InitAllocate(this, attributes)

    class(forcinggrid_type), intent(inout) :: this
    type(attributes_type),   intent(in)    :: attributes

    associate(n_x => attributes%metadata%n_x, &
              n_y => attributes%metadata%n_y)

    allocate(this%SFCPRS(n_x,n_y))
    allocate(this%SFCTMP(n_x,n_y))
    allocate(this%Q2(n_x,n_y))
    allocate(this%PRCP(n_x,n_y))
    allocate(this%PRCPCONV(n_x,n_y))
    allocate(this%PRCPNONC(n_x,n_y))
    allocate(this%PRCPSHCV(n_x,n_y))
    allocate(this%PRCPSNOW(n_x,n_y))
    allocate(this%PRCPGRPL(n_x,n_y))
    allocate(this%PRCPHAIL(n_x,n_y))
    allocate(this%SOLDN(n_x,n_y))
    allocate(this%LWDN(n_x,n_y))
    allocate(this%FOLN(n_x,n_y))
    allocate(this%O2PP(n_x,n_y))
    allocate(this%CO2PP(n_x,n_y))
    allocate(this%UU(n_x,n_y))
    allocate(this%VV(n_x,n_y))
    allocate(this%TBOT(n_x,n_y))
    allocate(this%UR(n_x,n_y))
    allocate(this%THAIR(n_x,n_y))
    allocate(this%QAIR(n_x,n_y))
    allocate(this%EAIR(n_x,n_y))
    allocate(this%RHOAIR(n_x,n_y))
    allocate(this%FPICE(n_x,n_y))
    allocate(this%SWDOWN(n_x,n_y))
    allocate(this%SOLAD(n_x,n_y,2))
    allocate(this%SOLAI(n_x,n_y,2))

    end associate

  end subroutine InitAllocate

  subroutine InitDefault(this)

    class(forcinggrid_type) :: this

    this%SFCPRS(:,:)    = huge(1.0)
    this%SFCTMP(:,:)    = huge(1.0)
    this%Q2(:,:)        = huge(1.0)
    this%PRCP(:,:)      = huge(1.0)
    this%PRCPCONV(:,:)  = huge(1.0)
    this%PRCPNONC(:,:)  = huge(1.0)
    this%PRCPSHCV(:,:)  = huge(1.0)
    this%PRCPSNOW(:,:)  = huge(1.0)
    this%PRCPGRPL(:,:)  = huge(1.0)
    this%PRCPHAIL(:,:)  = huge(1.0)
    this%SOLDN(:,:)     = huge(1.0)
    this%LWDN(:,:)      = huge(1.0) 
    this%FOLN(:,:)      = huge(1.0) 
    this%O2PP(:,:)      = huge(1.0) 
    this%CO2PP(:,:)     = huge(1.0) 
    this%UU(:,:)        = huge(1.0)
    this%VV(:,:)        = huge(1.0)
    this%TBOT(:,:)      = huge(1.0)
    this%UR(:,:)        = huge(1.0)
    this%THAIR(:,:)     = huge(1.0)
    this%QAIR(:,:)      = huge(1.0)
    this%EAIR(:,:)      = huge(1.0)
    this%RHOAIR(:,:)    = huge(1.0)
    this%FPICE(:,:)     = huge(1.0)
    this%SWDOWN(:,:)    = huge(1.0)
    this%JULIAN         = huge(1.0)
    this%YEARLEN        = huge(1)
    this%SOLAD(:,:,:)   = huge(1.0)
    this%SOLAI(:,:,:)   = huge(1.0)

  end subroutine InitDefault

  subroutine InitTransfer(this, namelist)

    class(forcinggrid_type) :: this
    type(namelist_type)     :: namelist

    this%forcings_dir         = namelist%forcings_dir
    this%forcings_file_prefix = namelist%forcings_file_prefix
    this%forcings_file_type   = namelist%forcings_file_type

  end subroutine InitTransfer

  subroutine ReadForcings(this,domaingrid)

    class(forcinggrid_type), intent(inout) :: this
    type(domaingrid_type),   intent(in)    :: domaingrid
    character(len=12)                      :: date           ! date ( YYYYMMDDHHmm )
    character(len=14)                      :: date_long      ! date ( YYYYMMDDHHmmss )
    character(len=2048)                    :: filename 
    character(len=4)                       :: year_str
    character(len=2)                       :: month_str,day_str,minute_str,second_str
    integer                                :: year_int,month_int,day_int,minute_int,second_int
    integer                                :: time_dim_len,ndays

    !---------------------------------------------------------------------
    ! Determine expected file name
    !---------------------------------------------------------------------
    date = domaingrid%nowdate
    year_str = date(1:4); month_str = date(5:6); day_str = date(7:8); hour_str = date(9:10)
    select case(this%forcing_file_type)
    case('YEARLY')
      filename = this%forcings_dir//this%forcings_file_prefix//'.'//year_str//'.nc'
    case('MONTHLY')
      filename = this%forcings_dir//this%forcings_file_prefix//'.'//year_str//month_str//'.nc'
    case('DAILY')
      filename = this%forcings_dir//this%forcings_file_prefix//'.'//year_str//month_str//day_str//'.nc'
    case('HOURLY')
      filename = this%forcings_dir//this%forcings_file_prefix//'.'//yea_str//month_str//day_str//hour_str//'.nc'
    case default
      write(*,*) 'ERROR Unrecognized forcing file type ''',trim(this%forcing_file_type),''' -- but must be HOURLY, DAILY, MONTHLY, or YEARLY'; stop ":  ERROR EXIT"
    end select

    !---------------------------------------------------------------------
    ! Determine unix time bounds for file (i.e., file_min_time, file_max_time)
    !---------------------------------------------------------------------
    select case(this%forcing_file_type)
    case('YEARLY')
      date_long(1:4) = year_str; date_long(5:6) = '01'; date_long(7:8) = '01'; date_long(9:10) = '00'; date_long(11:12) = '01'; date_long(13:14) = '01'
      this%file_min_time = date_to_unix (date_long)
      date_long(1:4) = year_str; date_long(5:6) = '12'; date_long(7:8) = '31'; date_long(9:10) = '23'; date_long(11:12) = '59'; date_long(13:14) = '59' 
      this%file_max_time = date_to_unix (date_long)
    case('MONTHLY')
      date_long(1:4) = year_str; date_long(5:6) = month_str; date_long(7:8) = '01'; date_long(9:10) = '00'; date_long(11:12) = '01', date_long(13:14) = '01' 
      this%file_min_time = date_to_unix (date_long)
      call unix_to_date (file_min_time+1, year_int, month_int, day_int, hour_int, minute_int, second_int)
      ndays = days_in_month(month_int,year_int,days_int)
      write(day_str,'(i2)') ndays; if(ndays < 10) day(1:1) = '0'
      date_long(1:4) = year_str; date_long(5:6) = month_str; date_long(7:8) = day_str; date_long(9:10) = '23'; date_long(11:12) = '59', date_long(13:14) = '01' 
      this%file_max_time = date_to_unix (date_long)
    case('DAILY')
      date_long(1:4) = year_str; date_long(5:6) = month_str; date_long(7:8) = day_str; date_long(9:10) = '00'; date_long(11:12) = '01'; date_long(13:14) = '01'
      this%file_min_time = date_to_unix (date_long)
      date_long(1:4) = year_str; date_long(5:6) = month_str; date_long(7:8) = day_str; date_long(9:10) = '23'; date_long(11:12) = '59'; date_long(13:14) = '59' 
      this%file_max_time = date_to_unix (date_long)
    case('HOURLY')
      date_long(1:4) = year_str; date_long(5:6) = month_str; date_long(7:8) = day_str; date_long(9:10) = hour_str; date_long(11:12) = '01'; date_long(13:14) = '01'
      this%file_min_time = date_to_unix (date_long)
      date_long(1:4) = year_str; date_long(5:6) = month_str; date_long(7:8) = day_str; date_long(9:10) = hour_str; date_long(11:12) = '59'; date_long(13:14) = '59' 
      this%file_max_time = date_to_unix (date_long)
    case default
      write(*,*) 'ERROR Unrecognized forcing file type ''',trim(this%forcing_file_type),''' -- but must be HOURLY, DAILY, MONTHLY, or YEARLY'; stop ":  ERROR EXIT"
    end select

    !---------------------------------------------------------------------
    ! Check that file exists
    !---------------------------------------------------------------------
    inquire(file = trim(filename), exist = lexist)
    if (.not. lexist) then; write(*,*) 'ERROR Could not find forcings file ''',trim(filename),''' for datetime ''',trim(date),'''';stop ":  ERROR EXIT";endif

    !---------------------------------------------------------------------
    ! Open file
    !---------------------------------------------------------------------
    status = nf90_open(path = trim(filename), mode = nf90_nowrite, ncid = ncid)
    if (status /= nf90_noerr) then; write(*,*) 'ERROR Could not open ''',trim(filename),''' for datetime ''',trim(date),''''; stop ":  ERROR EXIT"; endif

    !---------------------------------------------------------------------
    ! Read dimension lengths
    !---------------------------------------------------------------------
    ! x
    status = nf90_inq_dimid(ncid,this%name_dim_x,dimid_x)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to find dimension ''',trim(this%name_dim_x),''' in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    status = nf90_inquire_dimension(ncid,dimid_x,len=dim_len_x)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to read length of dimension ''',trim(this%name_dim_x),''' in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    
    ! y
    status = nf90_inq_dimid(ncid,this%name_dim_y,dimid_y)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to find dimension ''',trim(this%name_dim_y),''' in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    status = nf90_inquire_dimension(ncid,dimid_y,len=dim_len_y)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to read length of dimension ''',trim(this%name_dim_y),''' in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    
    ! time
    status = nf90_inq_dimid(ncid,this%name_dim_time,dimid_time)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to find dimension ''',trim(this%name_dim_time),''' in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    status = nf90_inquire_dimension(ncid,dimid_time,len=dim_len_time)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to read length of dimension ''',trim(this%name_dim_time),''' in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if

    !---------------------------------------------------------------------
    ! Allocate read arrays
    !---------------------------------------------------------------------
    ! windspeed
    if(allocated(this%read_windspeed)) then
      if((size(this%read_windspeed,1).ne.dim_len_x).or.(size(this%read_windspeed,2).ne.dim_len_y).or.(size(this%read_windspeed,3).ne.dim_len_time)) then
        deallocate(this%read_windspeed)
        allocate(this%read_windspeed(dim_len_x,dim_len_y,dim_len_time))
      else
        this%read_windspeed = 0
      end if 
    else
      allocate(this%read_windspeed(dim_len_x,dim_len_y,dim_len_time))
    end if

    ! winddir
    if(allocated(this%read_winddir)) then
      if((size(this%read_winddir,1).ne.dim_len_x).or.(size(this%read_winddir,2).ne.dim_len_y).or.(size(this%read_winddir,3).ne.dim_len_time)) then
        deallocate(this%read_winddir)
        allocate(this%read_winddir(dim_len_x,dim_len_y,dim_len_time))
      else
        this%read_winddir = 0
      end if 
    else
      allocate(this%read_winddir(dim_len_x,dim_len_y,dim_len_time))
    end if

    ! temperature
    if(allocated(this%read_temperature)) then
      if((size(this%read_temperature,1).ne.dim_len_x).or.(size(this%read_temperature,2).ne.dim_len_y).or.(size(this%read_temperature,3).ne.dim_len_time)) then
        deallocate(this%read_temperature)
        allocate(this%read_temperature(dim_len_x,dim_len_y,dim_len_time))
      else
        this%read_temperature = 0
      end if 
    else
      allocate(this%read_temperature(dim_len_x,dim_len_y,dim_len_time))
    end if

    ! pressure
    if(allocated(this%read_pressure)) then
      if((size(this%read_pressure,1).ne.dim_len_x).or.(size(this%read_pressure,2).ne.dim_len_y).or.(size(this%read_pressure,3).ne.dim_len_time)) then
        deallocate(this%read_pressure)
        allocate(this%read_pressure(dim_len_x,dim_len_y,dim_len_time))
      else
        this%read_pressure = 0
      end if 
    else
      allocate(this%read_pressure(dim_len_x,dim_len_y,dim_len_time))
    end if

    ! swrad
    if(allocated(this%read_swrad)) then
      if((size(this%read_swrad,1).ne.dim_len_x).or.(size(this%read_swrad,2).ne.dim_len_y).or.(size(this%read_swrad,3).ne.dim_len_time)) then
        deallocate(this%read_swrad)
        allocate(this%read_swrad(dim_len_x,dim_len_y,dim_len_time))
      else
        this%read_swrad = 0
      end if 
    else
      allocate(this%read_swrad(dim_len_x,dim_len_y,dim_len_time))
    end if

    ! lwrad
    if(allocated(this%read_lwrad)) then
      if((size(this%read_lwrad,1).ne.dim_len_x).or.(size(this%read_lwrad,2).ne.dim_len_y).or.(size(this%read_lwrad,3).ne.dim_len_time)) then
        deallocate(this%read_lwrad)
        allocate(this%read_lwrad(dim_len_x,dim_len_y,dim_len_time))
      else
        this%read_lwrad = 0
      end if 
    else
      allocate(this%read_lwrad(dim_len_x,dim_len_y,dim_len_time))
    end if

    ! rain
    if(allocated(this%read_rain)) then
      if((size(this%read_rain,1).ne.dim_len_x).or.(size(this%read_rain,2).ne.dim_len_y).or.(size(this%read_rain,3).ne.dim_len_time)) then
        deallocate(this%read_rain)
        allocate(this%read_rain(dim_len_x,dim_len_y,dim_len_time))
      else
        this%read_rain = 0
      end if 
    else
      allocate(this%read_rain(dim_len_x,dim_len_y,dim_len_time))
    end if

    ! time
    if(allocated(this%time)) then
      if(size(this%time,1).ne.dim_len_time) then
        deallocate(this%time)
        allocate(this%time(dim_len_time))
      else
        this%time = 0
      end if 
    else
      allocate(this%time(dim_len_time))
    end if

    !---------------------------------------------------------------------
    ! Read into read arrays
    !---------------------------------------------------------------------
    ! windspeed
    status = nf90_inq_varid(ncid,this%name_var_windspeed,varid_windspeed)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to find ''',trim(this%name_var_windspeed),''' variable in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    status = nf90_get_var(ncid,varid_windspeed)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to read ''',trim(this%name_var_windspeed),''' variable from forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if

    ! winddir
    status = nf90_inq_varid(ncid,this%name_var_winddir,varid_winddir)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to find ''',trim(this%name_var_winddir),''' variable in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    status = nf90_get_var(ncid,varid_winddir)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to read ''',trim(this%name_var_winddir),''' variable from forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if

    ! temperature
    status = nf90_inq_varid(ncid,this%name_var_temperature,varid_temperature)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to find ''',trim(this%name_var_temperature),''' variable in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    status = nf90_get_var(ncid,varid_temperature)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to read ''',trim(this%name_var_temperature),''' variable from forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if

    ! pressure
    status = nf90_inq_varid(ncid,this%name_var_pressure,varid_pressure)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to find ''',trim(this%name_var_pressure),''' variable in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    status = nf90_get_var(ncid,varid_pressure)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to read ''',trim(this%name_var_pressure),''' variable from forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if

    ! humidity
    status = nf90_inq_varid(ncid,this%name_var_humidity,varid_humidity)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to find ''',trim(this%name_var_humidity),''' variable in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    status = nf90_get_var(ncid,varid_humidity)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to read ''',trim(this%name_var_humidity),''' variable from forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if

    ! swrad
    status = nf90_inq_varid(ncid,this%name_var_swrad,varid_swrad)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to find ''',trim(this%name_var_swrad),''' variable in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    status = nf90_get_var(ncid,varid_swrad)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to read ''',trim(this%name_var_swrad),''' variable from forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if

    ! lwrad
    status = nf90_inq_varid(ncid,this%name_var_lwrad,varid_lwrad)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to find ''',trim(this%name_var_lwrad),''' variable in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    status = nf90_get_var(ncid,varid_lwrad)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to read ''',trim(this%name_var_lwrad),''' variable from forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    
    ! rain
    status = nf90_inq_varid(ncid,this%name_var_rain,varid_rain)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to find ''',trim(this%name_var_rain),''' variable in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    status = nf90_get_var(ncid,varid_rain)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to read ''',trim(this%name_var_rain),''' variable from forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if

    ! time
    status = nf90_inq_varid(ncid,this%name_var_time,varid_time)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to find ''',trim(this%name_var_time),''' variable in forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if
    status = nf90_get_var(ncid,varid_time)
    if (status .ne. nf90_noerr) then; write(*,*) 'ERROR Unable to read ''',trim(this%name_var_time),''' variable from forcing file ''',trim(this%forcings_file_name),'''';  stop ":  ERROR EXIT"; end if

    !---------------------------------------------------------------------
    ! Close file
    !---------------------------------------------------------------------
    status = nf90_close(ncid = ncid)
    if (status /= nf90_noerr) then; write(*,*) 'ERROR Unable to close ''',trim(filename),''''; stop ":  ERROR EXIT"; end if

    !---------------------------------------------------------------------
    ! Check x and y dimension lengths against x and y dimension lengths of the domain
    !---------------------------------------------------------------------
    n_x = size(domaingrid%n_x,1); n_y = size(domaingrid%n_y,2)
    if((dim_len_x.ne.n_x).or.(dim_len_y.ne.n_y)) then; write(*,*) 'ERROR the x and y dimensions in the forcing file ',trim(this%forcings_file_name),' do not match the domain x and y dimensions';stop ":  ERROR EXIT"; end if

    !---------------------------------------------------------------------
    ! Set iread (i.e., the index value of nowdate in read_time)
    !---------------------------------------------------------------------
    call this%FindTimeStepIndex(datetime,iread,filename)

    !---------------------------------------------------------------------
    ! Set iread_step (i.e., the index value of the next simulation time step in read_time minus iread)
    !---------------------------------------------------------------------
    iread_step = 1                  ! default value
    iread_next = iread + iread_step ! default value
    if((domaingrid%itime+1).le.domaingrid%ntime) then 
      next_datetime = domaingrid%sim_datetimes(domaingrid%itime + 1)
      if(next_dateime.le.this%max_file_datetime) then
        call this%FindTimeStepIndex(datetime,iread_next,filename)
        iread_step = iread_next - iread
        if(iread_step.lt.1) then; write(*,*) 'ERROR Unable to determine reading time step for ''',trim(filename),''''; stop ":  ERROR EXIT"; end if
      end if
    end if

  end subroutine ReadForcings

  subroutine SetForcings(this,domaingrid)

    class(forcinggrid_type), intent(inout) :: this
    character(len=12),intent(in)           :: date           ! date ( YYYYMMDDHHmm ) 

    ! check if curr_datetime is within the unix time bounds of read arrays
    if(domaingrid%curr_datetime > this%max_file_datetime) call this%ReadForcings(domaingrid)

    ! sanity check
    if(abs(this%read_time(iread)-domaingrid%curr_datetime).gt.epsilon(domaingrid%curr_datetime)) then
      write(*,*) 'ERROR Unable to find datetime ''',trim(domaingrid%nowdate),''' in forcing file ''',filename,''' - unix time = ',domaingrid%curr_datetime
    end if

    this%UU(:,:)     = this%read_UU(:,:,iread)
    this%VV(:,:)     = this%read_VV(:,:,iread)
    this%SFCTMP(:,:) = this%read_SFCTMP(:,:,iread)
    this%Q2(:,:)     = this%read_Q2(:,:,iread)
    this%SFCPRS(:,:) = this%read_SFCPRS(:,:,iread)
    this%SOLDN(:,:)  = this%read_SOLDN(:,:,iread)
    this%LWDN(:,:)   = this%read_LWDN(:,:,iread)
    this%PRCP(:,:)   = this%read_PRCP(:,:,iread)
    this%UU(:,:)     = this%read_UU(:,:,iread)

    ! advance iread
    iread = iread + iread_step

  end subroutine SetForcings

  subroutine FindTimeStepIndex(datetime,index,filename)

    real*8,intent(in)              :: datetime ! unix datetime (s since 1970-01-01 00:00:00) ?UTC? 
    integer,intent(out)            :: index    ! index value for argument datetime in read_time
    character(len=2048),intent(in) :: filename ! for error msg
    real,allocatable,dimension(:)  :: time_dif ! difference between read_time values and argument datetime

    allocate(time_dif(size(this%read_time,1))) 
    time_dif = abs(this%read_time-datetime)
    if(any(time_dif.le.epsilon(datetime))) then
      index = minloc(time_dif,1)
    else
      write(*,*) 'ERROR Searched forcing file ''',trim(filename),''' but could not find datetime (unix time) :',datetime
    end if

  end subroutine

end module ForcingGridType

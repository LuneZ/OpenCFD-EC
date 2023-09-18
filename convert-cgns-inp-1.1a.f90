! Convert CGNS mesh file to Gridgen generic format
! Code by Li Xinliang, lixl@imech.ac.cn
! ver 1.0, 2013-4-24  (Bug !)
! Ver 1.1, 2013-5-5, Bugs removed
!--------------------------------------------------------------------------------------
  module precision_EC
  implicit none
!      integer,parameter:: PRE_EC=4            ! Single precision
       integer,parameter:: PRE_EC=8           ! Double Precision
 end module  precision_EC 

  module const_var
   use precision_EC
   implicit none
   integer,parameter::  GBC_Wall=2, GBC_Symmetry=3, GBC_Farfield=4,GBC_Inflow=5, GBC_Outflow=6   ! ��Gridgen���ݵĶ���
   integer,parameter::  GBC_Extrapolate=401, GBC_Periodic=501     ! ��չ�Ķ��壬Gridgen Generic��δ����
   integer,parameter::  fno_log=103
  end module const_var

! ������ (�߽����ӣ� ����飬 "����")
    module Mod_Type_Def
    use precision_EC
    implicit none
    TYPE BC_MSG_TYPE              ! �߽�������Ϣ
 !   integer::  f_no, face, ist, iend, jst, jend, kst, kend, neighb, subface, orient   ! BXCFD .in format
     integer:: ib,ie,jb,je,kb,ke,bc                      ! �߽��������棩�Ķ��壬 .inp format
     integer:: ib1,ie1,jb1,je1,kb1,ke1,nb1               ! ��������
    END TYPE BC_MSG_TYPE
   
    TYPE Block_TYPE                                 ! ���ݽṹ������� ���������α����������������Ϣ 
     integer::  Block_no           ! ���
	 integer::  nx,ny,nz           ! ������nx,ny,nz
	 integer::  subface            ! ������
     character(len=50):: blockname
	 real(PRE_EC),pointer,dimension(:,:,:):: x,y,z     ! coordinates of vortex, ����ڵ�����
	 TYPE(BC_MSG_TYPE),pointer,dimension(:)::bc_msg     ! �߽�������Ϣ 
     End TYPE Block_TYPE  
    end module  Mod_Type_Def

  module Global_Var    
   use const_var        ! ����
   use mod_type_def     ! �߽�����
   implicit none
   TYPE(Block_TYPE),pointer,dimension(:):: Block
   integer::  Num_Block                      
  end module Global_Var  

!-------------------------------------------------------------------
!-------------------------------------------------------------------
  program convert_cgns
!  Convert 1-to-1 multi-block mesh to gridgen generic format
  use Global_Var
  implicit none
  include "cgnslib_f.h"
 
   integer::  fn,nzones,ier
 
   print*, "convert cgns file to Gridgen generic file  ...... "
   open(fno_log, file="convert-cgns.log")                 ! log file
   call open_check_cgns("grid.cgns",fn,nzones,fno_log)
   Num_Block=nzones
   allocate(Block(Num_Block))
   call  read_mesh(fn)    ! ��ȡ����
   call read_bc(fn)       ! ��ȡ�߽���Ϣ
   call cg_close_f(fn,ier)  
   call clear_mem
   close(fno_log)
   print*, "convert cgns file to Gridgen generic file OK "
   end


  subroutine read_bc(fn)
   use Global_Var
   implicit none
   include "cgnslib_f.h"
   integer:: ier, fn, i,j,k,k1,k2,m
   integer:: nbocos, n1to1,bocotype, ptset_type,  npnts, NormalIndex, NormalListSize, NormalDataType, ndataset
   integer:: pnts(3,2),NormalList(10), srange(3,2), donor_range(3,2), transform(3)
   integer:: realtype,zonetype,GBCtype
   character(len=50):: zonename,boconame,connectname, donorname
   TYPE(Block_TYPE),pointer:: B
   TYPE(BC_MSG_TYPE),pointer:: BC

   write(fno_log,*) "write bc3d.inp  ......"
                                                                                     ! ����߽���Ϣ     
   do m=1,Num_Block
    write(fno_log,*) "---zone: ", m
    B=> Block(m)
    call cg_nbocos_f(fn, 1, m, nbocos, ier)                ! Physics boundary
	call cg_n1to1_f(fn, 1, m, n1to1, ier)                  ! 1to1 boundary
	 B%subface=nbocos+n1to1              
     write(fno_log,*) "boundary number is ", B%subface, "phys boundary:",nbocos, "1to1 boudary :", n1to1
	 allocate(B%bc_msg(B%subface))
     
	 
 !------Physical boundary-------------	
	do k=1,nbocos
     BC=>B%bc_msg(k)
     call cg_boco_info_f(fn, 1, m, k, boconame, bocotype, ptset_type,    &
       npnts, NormalIndex, NormalListSize, NormalDataType, ndataset, ier)
!     print*, "k=",k, "boconame=",boconame
!	 print*, "bocotype=",bocotype, " ptset_type=",ptset_type, "npnts=",npnts
       if(ptset_type .ne. PointRange) then                            
       print*, "Error !  Ptset_type != PointRange !!!"               ! opencfd-ec use PointRange type boundary
	   stop  
       endif
       call  cg_boco_read_f(fn, 1, m, k, pnts, NormalList, ier)
       call convert_bctype(bocotype,GBCtype,m,k)
       BC%ib=pnts(1,1) ; BC%ie=pnts(1,2)
       BC%jb=pnts(2,1) ; BC%je=pnts(2,2)
       BC%kb=pnts(3,1) ; BC%ke=pnts(3,2)
       BC%bc=GBCtype
     enddo
  !--------1to1 boundary---------------------
    do k=1,n1to1
	   k1=nbocos+k
       BC=>B%bc_msg(k1)
       call cg_1to1_read_f(fn, 1, m, k, connectname, donorname, srange, donor_range, transform, ier) 
!        print*, "connectname=", connectname, " donorname= ", donorname
        Bc%bc=-1
        Bc%nb1=0
		do k2=1,Num_Block
		  if(trim(donorname)== trim(Block(k2)%blockname) ) then
          Bc%nb1=k2
		  exit 
		  endif
		enddo
        
		if(Bc%nb1 .eq. 0) then
		   print*, "Error, Do not find the dornor zone !!!"
		   stop
		endif

 		write(fno_log,*) "--------------------------------------"
        write(fno_log,*) "zone", m, " boundary",k1, " donor zone",k2
		write(fno_log,*) "srange"
        write(fno_log,*) ((srange(i,j),j=1,2),i=1,3)
        write(fno_log,*) "donor_range"
        write(fno_log,*) ((donor_range(i,j),j=1,2),i=1,3)
        write(fno_log,*) "transform"
        write(fno_log,*) transform
		
	    call set_link_range(srange,donor_range,transform,Bc%ib,Bc%ie,Bc%jb,Bc%je,Bc%kb,Bc%ke, &
		                   Bc%ib1,Bc%ie1,Bc%jb1,Bc%je1,Bc%kb1,Bc%ke1)
	enddo
!---------------------------------------------
   enddo

  call write_inp

  end


!----------------------------------------------------------------
! Open CGNS file and check 
  subroutine open_check_cgns(filename,fn,nzones,fno_log)
   implicit none
   include "cgnslib_f.h"
   character(len=50):: filename,basename
   integer:: fn,nzones,ier,  precision,nbase,cell_dim,phys_dim,fno_log
   real version

!------------------------------------------------  
  call cg_open_f(filename,CG_MODE_READ,fn,ier)
  if (ier .ne. CG_OK) call cg_error_exit_f           ! �ļ��򿪲��ɹ�
! ----check cgns file message----------  
  call cg_version_f(fn,version,ier)                  ! �����ļ���CGNS�汾
     write(fno_log,*)  "CGNS file Version is", version
  call cg_precision_f(fn,precision,ier)              ! ���ݾ��ȣ�32λ or 64λ��
     write(fno_log,*) "Date precision (32/64 bit): ", precision
  call cg_nbases_f(fn,nbase,ier)                      ! Base ����Ŀ ������Ҫ1����
     write(fno_log,*) "Total base number is:", nbase
  call cg_base_read_f(fn, 1, basename, cell_dim, phys_dim, ier)
     write(fno_log,*) "Basename: ", basename                  ! Base ��
	 write(fno_log,*) "Cell_dim: " , Cell_dim, "  Phys_dim: ",Phys_dim   ! ����ռ估����ռ��ά��
!-----------read zone (block) number
  call cg_nzones_f(fn, 1, nzones, ier)                          ! ��������Ŀ
    write(fno_log,*) "Total Block number is :", nzones
    write(fno_log,*) "---------------------------------------------------------------"

  end	


!------------------------------------------------------------------
! -------- read coordinate data  ----------------------------------
  subroutine read_mesh(fn)
  use Global_Var
  implicit none
  include "cgnslib_f.h"
  integer:: fn,nx,ny,nz,m,ier,isize(3,3),imin(3),imax(3),zonetype,realtype
  integer:: i,j,k
  TYPE(Block_TYPE),pointer:: B
   character(len=50):: zonename
   
    if(PRE_EC == 4) then
	  realtype=RealSingle         ! CGNS single type
	else
	  realtype=RealDouble         ! CGNS double type
	endif

  do m=1,Num_Block
    B=> Block(m)
    call cg_zone_type_f(fn, 1, m, zonetype, ier)                    ! ����������
	if(zonetype .ne. Structured ) then                              ! ������ݲ�֧�ַǽṹ���� !
	  print*, "Error !!! the zoen is not a STRUCTURED zone !!!"
      stop
	 endif

	call cg_zone_read_f(fn, 1, m, zonename, isize, ier)            ! ���� zone ��Ϣ
    write(fno_log,*) " Zone ", m, zonename
    write(fno_log,*) "nx,ny,nz=",isize(:,1)
	 B%Block_no=m
	 B%Blockname=trim(zonename)
	 B%nx=isize(1,1)
	 B%ny=isize(2,1)
     B%nz=isize(3,1)
	 nx=B%nx; ny=B%ny ; nz=B%nz
	 imin(:)=1
	 imax(1)=nx; imax(2)=ny; imax(3)=nz

     allocate(B%x(nx,ny,nz),B%y(nx,ny,nz),B%z(nx,ny,nz))
	    
	 call cg_coord_read_f(fn,1,m,"CoordinateX",realtype,imin,imax,B%x,ier)           ! ��������
	 call cg_coord_read_f(fn,1,m,"CoordinateY",realtype,imin,imax,B%y,ier)
	 call cg_coord_read_f(fn,1,m,"CoordinateZ",realtype,imin,imax,B%z,ier)
  enddo


  open(99,file="Mesh3d.dat",form="unformatted")                                     ! ����PLOT3D��ʽд��Mesh3d.dat
  write(99) Num_Block
  write(99) ((Block(m)%nx,Block(m)%ny,Block(m)%nz),m=1,Num_Block)
  do m=1,Num_Block
  B=>Block(m)
  write(99) (((B%x(i,j,k),i=1,B%nx),j=1,B%ny),k=1,B%nz),  &
            (((B%y(i,j,k),i=1,B%nx),j=1,B%ny),k=1,B%nz),  &
            (((B%z(i,j,k),i=1,B%nx),j=1,B%ny),k=1,B%nz)
  enddo
  close(99)
  print*, "---------------------Mesh3d write OK -------------------------"
  end



!----Convert CGNS boundary type to Gridgen (.inp) boundary type 
  subroutine convert_bctype(bocotype,GBCtype,mb,mk)
  use  const_var
  implicit none
  include "cgnslib_f.h"
  
  integer:: bocotype, GBCtype,mb,mk
  
  Select case (bocotype)
    case (BCwall,  BCWallViscous, BCWallViscousHeatFlux, BCWallViscousIsothermal)
	   GBCtype=GBC_Wall                   ! Wall boundary 
    case (BCSymmetryPlane, BCWallInviscid)
       GBCtype=GBC_Symmetry               ! Inviscid wall is treated as symmetry plane
    case (BCFarfield )
	   GBCtype=GBC_Farfield
    case (BCInflow, BCInflowSubsonic, BCInflowSupersonic)
	   GBCtype=GBC_Inflow
    case (BCOutflow, BCOutflowSubsonic, BCOutflowSupersonic )
	  GBCtype=GBC_Outflow
    case (BCExtrapolate )
      GBCtype= GBC_Extrapolate
    case (BCDegenerateLine) 
	  GBCtype= GBC_Extrapolate                            ! �˻��߾��������߽紦��
      write(fno_log,*) " Warning! Find DegenerateLine boundary, treated as Extrapolate boundary ! Block, subface=",mb,mk
    case default 
      print*, "----------------------------"               ! ������OpenCFD-EC��֧�ֵı߽�����
	  print*, "Warning !  Find a NEW Boundary condition,  not supported by OpenCFD-EC "
	  print*,  BCTypeName(bocotype), " in Block, subface=",mb,mk
      print*, "you should check it carefully"
      GBCtype=1000+bocotype                                 ! �¶���ı߽���������
  End Select
  End subroutine
   
   
!        ����Gridgen ��Generic�߽��ʽ(.inp)д�� bc3d.inp
   subroutine write_inp
    use Global_Var
    implicit none
    integer:: m,ksub
    TYPE(Block_TYPE),pointer:: B
    TYPE(BC_MSG_TYPE),pointer:: BC

    open(99,file="bc3d.inp")
    write(99,*) 1
    write(99,*) Num_Block
	do m=1,Num_Block
     B => Block(m)
     write(99,*) B%nx, B%ny, B%nz
	 write(99,*) "Block ", m
	 write(99,*) B%subface
	  do ksub=1,B%subface
        Bc => B%bc_msg(ksub)
	   write(99,"(9I6)") Bc%ib,Bc%ie,Bc%jb,Bc%je,Bc%kb,Bc%ke,Bc%bc
	   if(Bc%bc == -1) then
	     write(99,"(12I6)") Bc%ib1,Bc%ie1,Bc%jb1,Bc%je1,Bc%kb1,Bc%ke1,Bc%nb1
       endif
	  enddo
	enddo
	close(99)
    end


! �������������Ӧ��ϵ ��CGNS ת��Ϊ Gridgen ��ʽ��
    subroutine set_link_range(srange,donor_range,transform,ib,ie,jb,je,kb,ke,ib1,ie1,jb1,je1,kb1,ke1)
    implicit none
	integer:: ksa, srange(3,2),donor_range(3,2),Grange(3,2),transform(3)
	integer:: ib,ie,jb,je,kb,ke,ib1,ie1,jb1,je1,kb1,ke1
	integer:: k,k1
!                                      source range Դ����
       ib=srange(1,1) ; ie=srange(1,2)
       jb=srange(2,1) ; je=srange(2,2)
       kb=srange(3,1) ; ke=srange(3,2)
	   if(kb .ne. ke) then
	     kb=-kb; ke=-ke               !  Gridgen .inp��ʽ;  ������ĵ�2ά �ø��ű�ʾ�� �Ա���ʶ��
	     ksa=3                        ! ������� ��2ά ����ά�ռ�ĵ�3ά  
	   else
	     jb=-jb; je=-je
	     ksa=2
	   endif
!                                       ��������  donor range
     do k=1,3  
       k1=abs(transform(k))                   ! �������ӵ���������
!        ver 1.1, donro_range()�����Ѱ��ź����������Ӵ�������transform()�ķ���        
		 Grange(k1,1)=donor_range(k1,1)       
         Grange(k1,2)=donor_range(k1,2)

!       if(transform(k) .gt. 0) then
!         Grange(k1,1)=donor_range(k1,1)       ! ��������
!         Grange(k1,2)=donor_range(k1,2)
!	   else
!         Grange(k1,1)=donor_range(k1,2)       ! ��������
!         Grange(k1,2)=donor_range(k1,1)
!	   endif

	 enddo
	 
	   k1=abs(transform(ksa)) 
	   Grange(k1,1)=- Grange(k1,1)          ! ������ĵ�2ά �ø��ű�ʾ
	   Grange(k1,2)=- Grange(k1,2)
     

	  ib1=Grange(1,1) ; 	ie1=Grange(1,2)    ! donor range 
	  jb1=Grange(2,1) ; 	je1=Grange(2,2) 
  	  kb1=Grange(3,1) ; 	ke1=Grange(3,2) 
    end

  subroutine clear_mem       ! �ͷ��ڴ�
  use Global_Var
  implicit none
  integer:: m
  TYPE(Block_TYPE),pointer:: B
  do m=1, Num_Block
   B=>Block(m)
   deallocate(B%x,B%y,B%z)
   deallocate(B%bc_msg)
  enddo
  deallocate(Block)
  end

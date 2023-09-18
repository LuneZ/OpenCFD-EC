! ��ʼ���������������ݽṹ������ֵ
! ���ڶ������񣬸����ϼ��������Ϣ��������������
!  ��������Ƿ������ڶ������� 
!  ������������= 2*K+1 ����2������=4*K+1 ����3������=8*K+1 ����4������ ...  
!---------------------------------------------------------------------------------
!------------------------------------------------------------------------------     
  subroutine init
   use Global_var
   implicit none
   integer :: i,j,k,m,nx1,ny1,nz1,Num_Block1,ksub,Kmax_grid
   real(PRE_EC),allocatable,dimension(:,:,:):: xc,yc,zc
   integer,allocatable,dimension(:):: NI,NJ,NK
   Type (Block_TYPE),pointer:: B
   TYPE (BC_MSG_TYPE),pointer:: Bc
 !--------------------------------------------------------------------
 ! initial of const variables
   Ralfa(1)=1.d0 ;  Ralfa(2)=3.d0/4.d0 ; Ralfa(3)=1.d0/3.d0
   Rbeta(1)=1.d0 ;  Rbeta(2)=1.d0/4.d0 ; Rbeta(3)=2.d0/3.d0
   Rgamma(1)=0.d0;  Rgamma(2)=1.d0/4.d0; Rgamma(3)=2.d0/3.d0
   Cv=1.d0/(gamma*(gamma-1.d0)*Ma*Ma)
!--------------------------------------------------------------------- 
!-----------------------------------------------------------------------------------------
   call partation                         ! ����ָ� ��ȷ��ÿ�������Ľ��̣�
   allocate( Mesh(Num_Mesh) )             ! �����ݽṹ�� ������ �����Ա�ǡ�����顱���� Mesh(1)Ϊ������������ϸ������Mesh(2),Mesh(3)Ϊ�֡����ֵ�����
   call Creat_main_Mesh                   ! ����������(������������ϸ������) (�������ļ�Mesh3d.dat)
   call read_main_Mesh                    ! ����������
   call read_inc    !������������Ϣ (bc3d.inc)
   call Update_coordinate_buffer_onemesh(1)
   call Comput_Goemetric_var(1)
   call update_Mesh_Center(1)    ! �������ĵ�������Ghost ֵ ����������ʹ�ã�

   if(IF_Debug==1) call Output_mesh_debug                  ! ����������������
  
    if(IF_Walldist ==  1)  then
	   call comput_dist_wall   ! ����(���ȡ)������ľ���
    else
	   if(my_id .eq. 0) print*, " Need not read wall_dist.dat "
	endif

   if(Num_Mesh .ge. 2) then
     call Creat_Mesh(1,2)                 ! ����1��������ϸ������Ϣ������2�����񣨴�����
   endif
   if(Num_Mesh .ge. 3) then
     call Creat_Mesh(2,3)                 ! ����2��������Ϣ�������񣩣� ����3�������������
   endif
   
   do m=1,Num_Mesh
     call set_BcK(m)   ! �趨�߽�ָʾ�� (2013-11)
   enddo 

! !!! FVM_FDM FVM_FDM !!!!         hybrid Finite-Difference/ Finite-Valume Method   
   call init_FDM
! !!!----------------------------------------------------------------------------
  end   


!--------------------------------------------------------------------------------------
!   �������ݽṹ�� ��ϸ���� �����漸�������غ������
  subroutine Creat_main_Mesh
   use Global_var
   implicit none
   integer:: m,Num_Cell,ierr
   Type (Mesh_TYPE),pointer:: MP
   Type (Block_TYPE),pointer:: B
   
!   print*, "-----------------------------"
! ---------node Coordinates----------------------------------------  
!  �����ļ���PLOT3D��ʽ��   
   MP=>Mesh(1)
   MP%NVAR=NVAR   ! ���������ϵı�����Ŀ
   MP%Num_Block=Num_Block                      ! ��mpi���̰����Ŀ���
   allocate(MP%Block(Num_block))               ! ����������顱
   call set_size_blocks                        ! �趨ÿ��Ĵ�С
   call allocate_mem_Blocks(1)                 ! ��ÿ��ĳ�Ա���鿪���ڴ�

!  �趨������ֵ
   allocate(MP%Res_max(NVAR),MP%Res_rms(NVAR))   ! ���в���������в� 
   MP%Kstep=0
   MP%tt=0.d0
   Num_Cell=0   ! �������
    do m=1,Num_Block
    B => MP%Block(m)
    Num_Cell=Num_Cell+(B%nx-1)*(B%ny-1)*(B%nz-1)
	
	B%IF_OverLimit=0                       ! ����������־ �����;��ȵȣ�

    enddo
    call MPI_ALLREDUCE(Num_Cell,MP%Num_Cell,1,MPI_INTEGER,MPI_SUM,MPI_COMM_WORLD,ierr)
	if (my_id .eq. 0) then
	  print*, "creat main mesh OK, Num_Cell=",MP%Num_Cell
    endif
  end   subroutine Creat_main_Mesh


!---------------------------------------------
! �趨ÿ��Ĵ�С(B%nx,B%ny,B%nz), ���������ļ�Mesh3d.dat 
  subroutine set_size_blocks
   use Global_var
   implicit none
   integer:: m,mb
   Type (Mesh_TYPE),pointer:: MP
   Type (Block_TYPE),pointer:: B
   integer:: NB,NB1,k,ierr
!   integer,allocatable,dimension(:):: NI,NJ,NK
  
   MP=>Mesh(1)
   NB=Total_Block
   allocate(bNI(NB),bNJ(NB),bNK(NB))         ! ���ά����ȫ�֣�
  
  if(my_id .eq. 0) then      ! �����̽��ж�д����

   if( Mesh_File_Format .eq. 1) then   ! ��ʽ�ļ�
     open(99,file="Mesh3d.dat")
     read(99,*) NB1   ! Block number
     read(99,*) (bNI(k), bNJ(k), bNK(k), k=1,NB)
    else                                ! �޸�ʽ�ļ�
     open(99,file="Mesh3d.dat",form="unformatted")
     read(99) NB1                       ! �ܿ���
      if(NB1 .ne. NB) then 
	     print*, "Warning !!! Block number Error !!!"
         print*, "please check 'partation.dat' ..."
		 stop
	  endif
	 read(99) (bNI(k), bNJ(k), bNK(k), k=1,NB)
    endif
    close(99)
   endif
   
   call MPI_bcast(bNI,NB,MPI_Integer,0,  MPI_COMM_WORLD,ierr)
   call MPI_bcast(bNJ,NB,MPI_Integer,0,  MPI_COMM_WORLD,ierr)
   call MPI_bcast(bNK,NB,MPI_Integer,0,  MPI_COMM_WORLD,ierr)
   
   do m=1,MP%Num_Block   ! �����̰����Ŀ���
    B=> MP%Block(m)       ! ����
    mb= my_blocks(m)      ! ���
    B%block_no=mb         ! ���  
    B%mpi_id=my_id        ! ����Ľ��̺�
    B%nx=bNI(mb)
    B%ny=bNJ(mb)
    B%nz=bNK(mb)
    B%IFLAG_FVM_FDM=Method_FVM   ! Ĭ����������� 
	B%IF_OverLimit=0

   enddo
!   deallocate(NI,NJ,NK)
!   print*, " define size ok ...", my_id

  end subroutine set_size_blocks

!------����������Ϣ (����ö���������Ϊ���ܵ�����)----------------------------------
  



! �����ϼ�������Ϣ������������m2 
  subroutine Creat_Mesh(m1,m2)
   use Global_Var
   implicit none
   integer:: NB,NVAR1,m,m1,m2,ksub,nx,ny,nz,i,j,k,i1,j1,k1,Bsub,Num_Cell,ierr
   Type (Block_TYPE),pointer:: B1,B2
   TYPE (BC_MSG_TYPE),pointer:: Bc1,Bc2
   Type (Mesh_TYPE),pointer:: MP1,MP2
   MP1=>Mesh(m1)             ! ��һ������ ��ϸ����
   Mp2=>Mesh(m2)             ! ��������   ��������
   
   MP2%NVAR=5                ! �������ϵı�����Ŀ

   NB=MP1%Num_Block
   MP2%Num_Block=NB          !  ����m2��m1 ������ͬ
   MP2%Mesh_no=m2            ! �����
   MP2%Num_Cell=0      
   NVAR1=MP2%NVAR    ! NVAR1=5  ������ʹ������ģ��
   allocate(MP2%Res_max(NVAR1),MP2%Res_rms(NVAR1)) 
   allocate(MP2%Block(NB))   ! ��MP2�д������ݽṹ�����顱
     Num_Cell=0
   do m=1,NB
     B1=>MP1%Block(m)
     B2=>MP2%Block(m)
	 B2%Block_no=B1%block_no
     nx=(B1%nx-1)/2+1        ! ������ĵ���
	 ny=(B1%ny-1)/2+1
	 nz=(B1%nz-1)/2+1
	 B2%nx=nx
	 B2%ny=ny
	 B2%nz=nz    
	 Num_Cell=Num_Cell+(nx-1)*(ny-1)*(nz-1)          ! ͳ��MP2��������Ԫ��
     B2%IFLAG_FVM_FDM=Method_FVM   ! Ĭ����������� 
 	 B2%IF_OverLimit=0           ! ���������ޣ����;���
  
    enddo
    call MPI_ALLREDUCE(Num_Cell,MP2%Num_Cell,1,MPI_INTEGER,MPI_SUM,MPI_COMM_WORLD,ierr)


!    ������������������
!--------------------------------------------------
     call allocate_mem_Blocks(m2)           ! �����ڴ�
!------------------------------------------------
    do m=1,NB
     B1=>MP1%Block(m)
     B2=>MP2%Block(m)
!   �趨������Ϣ�����ݴ֡�ϸ����Ķ�Ӧ��ϵ��
     do k=1,B2%nz     
	   do j=1,B2%ny
	     do i=1,B2%nx
	       i1=2*i-1 ; j1=2*j-1 ;k1=2*k-1
	       B2%x(i,j,k)=B1%x(i1,j1,k1)         !��������ϸ����Ķ�Ӧ��ϵ ����һ��������һ��������㣩
           B2%y(i,j,k)=B1%y(i1,j1,k1)
		   B2%z(i,j,k)=B1%z(i1,j1,k1)
	     enddo
	   enddo
	 enddo
	 enddo
!-----------------------------------------------  
    do m=1,NB
     B1=>MP1%Block(m)
     B2=>MP2%Block(m)

!    ����������Ϣ
     Bsub=B1%subface        ! ������
     B2%subface=Bsub
     allocate(B2%bc_msg(Bsub))
     do ksub=1, Bsub
	   Bc1=> B1%bc_msg(ksub)    ! ��һ�������������Ϣ
	   Bc2=> B2%bc_msg(ksub)    ! ���������������Ϣ
      
	   Bc2%ib=(Bc1%ib-1)/2+1   ! �֡�ϸ�����±�Ķ�Ӧ��ϵ
	   Bc2%ie=(Bc1%ie-1)/2+1   ! �֡�ϸ�����±�Ķ�Ӧ��ϵ
	   Bc2%jb=(Bc1%jb-1)/2+1
	   Bc2%je=(Bc1%je-1)/2+1
	   Bc2%kb=(Bc1%kb-1)/2+1
	   Bc2%ke=(Bc1%ke-1)/2+1
 	   
	   Bc2%ib1=(Bc1%ib1-1)/2+1   ! �֡�ϸ�����±�Ķ�Ӧ��ϵ
	   Bc2%ie1=(Bc1%ie1-1)/2+1   ! �֡�ϸ�����±�Ķ�Ӧ��ϵ
	   Bc2%jb1=(Bc1%jb1-1)/2+1
	   Bc2%je1=(Bc1%je1-1)/2+1
	   Bc2%kb1=(Bc1%kb1-1)/2+1
	   Bc2%ke1=(Bc1%ke1-1)/2+1
      
	   Bc2%bc=Bc1%bc            ! �߽����� ��-1 Ϊ�ڱ߽磩
	   Bc2%face=Bc1%face        ! ������(1-6�ֱ���� i-,j-,k-,i+,j+,k+)
	   Bc2%f_no=Bc1%f_no        ! �����
	   Bc2%nb1=Bc1%nb1          ! ���ӿ�
	   Bc2%face1=Bc1%face1      ! �����������(1-6)
	   Bc2%f_no1=Bc1%f_no1      ! ������������
	   Bc2%L1=Bc1%L1            ! ���ӷ�ʽ����
	   Bc2%L2=Bc1%L2
	   Bc2%L3=Bc1%L3
     enddo
   enddo

   call Update_coordinate_buffer_onemesh(m2)
   call Comput_Goemetric_var(m2)

   call update_Mesh_Center(m2)

   Mesh(m2)%Kstep=0
   Mesh(m2)%tt=0.d0
  
  end  subroutine Creat_Mesh

! ------------------------------------------------------------------------------

  subroutine Init_flow
    use Global_var
    implicit none
    integer:: i,j,k,m,m1,NVAR1
    Type (Mesh_TYPE),pointer:: MP
    Type (Block_TYPE),pointer:: B	 
  
   if(Iflag_init .le. 0) then
	 call init_flow_zero                   ! �Ӿ��ȳ�����������ֹ���������� ���ȴӴ�������㣬�ٲ�ֵ��ϸ����
   else
	 call read_flow_data
   endif
 
 !    n��n-1ʱ������ ����ʼʱ����Ϊ��ͬ��, ˫ʱ�䲽LU-SGSʹ�� ����֧�ֵ�������
    if(Time_Method .eq. Time_dual_LU_SGS) then             
      MP=> Mesh(1)
      NVAR1=MP%NVAR
      do m=1,MP%Num_Block
      B => MP%Block(m)                
	   do k=-1,B%nz+1
        do j=-1,B%ny+1
         do i=-1,B%nx+1
          do m1=1,NVAR1
           B%Un(m1,i,j,k)=B%U(m1,i,j,k)
		   B%Un1(m1,i,j,k)=B%U(m1,i,j,k)
		  enddo
		 enddo
		enddo
	   enddo
	  enddo		   
    endif   
  end subroutine Init_flow




!--------------------------------------------------------------------------------
! ��������ʼ���� ������������£����������ʼ���㣨Ȼ���ֵ��ϸ����  
  subroutine init_flow_zero
   use Global_var
   implicit none
   real(PRE_EC):: d0,u0,v0,w0,p0,T0,vx,tmp,pin0
   integer:: i,j,k,m,step,nMesh,n
   Type (Mesh_TYPE),pointer:: MP
   Type (Block_TYPE),pointer:: B	 
!-------------------------------------------------------------------
   if(my_id .eq. 0) then      
    if( Iflag_init .eq. Init_By_FreeStream)then    ! ������������ʼ��
      print*, "Initial by Free-stream flow ......"
    else  if( Iflag_init .eq. Init_By_Zeroflow) then
      print*, "Initial by Zero flow ......"                                          ! �þ�ֹ������ʼ��
    endif
   endif

  
   MP=> Mesh(Num_Mesh)   ! Mesh(Num_Mesh) ����ֵ�����
   do m=1,MP%Num_Block
     B => MP%Block(m)                
     if(IF_TurboMachinary ==0  .and. IF_Innerflow==0 ) then    ! ����ģʽ

	  d0=1.d0
      p0=1.d0/(gamma*Ma*Ma)
     if( Iflag_init .eq. Init_By_FreeStream)then    ! ������������ʼ��
       u0=cos(A_alfa)*cos(A_beta)
       v0=sin(A_alfa)*cos(A_beta) 
       w0=sin(A_beta)
     else  if( Iflag_init .eq. Init_By_Zeroflow) then                                          ! �þ�ֹ������ʼ��
 	   u0=0.d0
       v0=0.d0
       w0=0.d0
     endif


	   do k=1-LAP,B%nz+LAP-1
       do j=1-LAP,B%ny+LAP-1
       do i=1-LAP,B%nx+LAP-1

           B%U(1,i,j,k)=d0
           B%U(2,i,j,k)=d0*u0
           B%U(3,i,j,k)=d0*v0
           B%U(4,i,j,k)=d0*w0
           B%U(5,i,j,k)=p0/(gamma-1.d0)+0.5d0*d0*(u0*u0+v0*v0+w0*w0)

           if(MP%NVAR .eq. 6) then
! see:       http://turbmodels.larc.nasa.gov/spalart.html
		     B%U(6,i,j,k)=5.d0                 ! �趨Ϊ����ճ��ϵ����5�� ��0.98c�Ժ�汾��

		   else if (MP%NVAR .eq. 7) then
		     B%U(6,i,j,k)=10.d0*Kt_Inf   ! �Ķ��� ����ֵ����Ϊ������10����
			 B%U(7,i,j,k)=Wt_Inf         ! �Ⱥ�ɢ��
           endif
       enddo
       enddo
	   enddo
     
	 else   ! Ҷ�ֻ�ģʽ

    
	  if( Iflag_init .eq. Init_By_Zeroflow) then                                         
        vx=0.d0
		d0=1.d0
		p0=1.d0/(gamma*Ma*Ma)
	  else 
       if(P_outlet > 0) then       !            
	     pin0=1.d0/(gamma)       ! �����ѹ
	     p0= P_OUTLET                  ! ��ѹ ����Ϊ��ʼѹ����
 	     T0= (P_OUTLET/pin0)**((gamma-1.d0)/gamma)   ! ��ʼ�¶� (����=1, ���ܶ�=1,��ѹ=1/gamma)
	     d0= P_OUTLET/T0*gamma*Ma*Ma          ! ��ʼ�ܶ�
         vx=sqrt(2.d0*Cp*(1.d0-T0))   ! ��ʼ�ٶ�
       else
         p0=1.d0/(gamma*Ma*Ma)
		 d0=1.d0
		 vx=1.d0
	   endif
  	  endif


	  do k=1-LAP,B%nz+LAP-1
      do j=1-LAP,B%ny+LAP-1
      do i=1-LAP,B%nx+LAP-1
     
	       u0=vx
		   v0= Turbo_w*B%zc(i,j,k)   ! ����ٶ� ��������ת��
		   w0= -Turbo_w*B%yc(i,j,k)   
           B%U(1,i,j,k)=d0
           B%U(2,i,j,k)=d0*u0
           B%U(3,i,j,k)=d0*v0
           B%U(4,i,j,k)=d0*w0
           B%U(5,i,j,k)=p0/(gamma-1.d0)+0.5d0*d0*(u0*u0+v0*v0+w0*w0)
          
            if(MP%NVAR .eq. 6) then
		     B%U(6,i,j,k)=5.d0                 ! �趨Ϊ����ճ��ϵ����5�� ��0.98c�Ժ�汾��
		    else if (MP%NVAR .eq. 7) then
		     B%U(6,i,j,k)=10.d0*Kt_Inf   ! �Ķ��� ����ֵ����Ϊ������10����
			 B%U(7,i,j,k)=Wt_Inf         ! �Ⱥ�ɢ��
            endif

       enddo
	   enddo
	   enddo

     endif

   enddo

   call Boundary_condition_onemesh(Num_Mesh)     ! �߽����� ���趨Ghost Cell��ֵ��
   call update_buffer_onemesh(Num_Mesh)          ! ͬ������Ľ�����

!  Initial smoothing    ! ��ʼ��˳ (����Kstep_Init_Smooth����
   do n=1,Kstep_init_smooth
     if(my_id .eq. 0 .and. mod(n,10) .eq. 0) print*, "Initial smoothing",n
	 call smoothing_oneMesh(Num_Mesh,Smooth_2nd)     
   enddo
   
   
   
!-----------------------------------------------------------------
!------------------------------------------------------
!   ׼����ֵ�Ĺ���
!   �����������㣬�𼶲�ֵ��ϸ����
   do nMesh=Num_Mesh,1,-1 
     do step=1, Pre_Step_Mesh(nMesh)   
       call NS_Time_advance(nMesh)
       if(mod(step,Kstep_show) .eq. 0) call output_Res(nMesh)
     enddo
!     call output (nMesh)
     if(nMesh .gt. 1) then
       call prolong_U(nMesh,nMesh-1,1)                  ! ��nMesh�������ϵ���������ֵ����һ������; flag=1 ��ֵU����
	   call Boundary_condition_onemesh(nMesh-1)         ! �߽����� ���趨Ghost Cell��ֵ��
	   call update_buffer_onemesh(nMesh-1)              ! ͬ������Ľ����� 
       print*, " Prolong  to mesh ", nMesh-1, "   OK"           
     endif
   enddo

  end subroutine init_flow_zero 


!----------------------------------------------------


  subroutine allocate_mem_Blocks(nMesh)
   use Global_var
   implicit none
   integer:: nMesh,m,nx,ny,nz,NVAR1
   Type (Mesh_TYPE),pointer:: MP
   Type (Block_TYPE),pointer:: B

    MP=>Mesh(nMesh)
    NVAR1=MP%NVAR

   do m=1,MP%Num_Block
	 B=>MP%Block(m)

     nx=B%nx ; ny= B%ny  ; nz= B%nz

	  	 
!   �����ڴ�   (x,y,z) �ڵ����ꣻ (xc,yc,zc)������������; Vol ����������� U, Un �غ����
     allocate( B%x(0:nx+1,0:ny+1,0:nz+1), B%y(0:nx+1,0:ny+1,0:nz+1),B%z(0:nx+1,0:ny+1,0:nz+1))   ! �������
  
!  �������꣬ LAP��������  ������ʹ����������������          
   	 allocate( B%xc(1-LAP:nx+LAP-1,1-LAP:ny+LAP-1,1-LAP:nz+LAP-1) , &
	           B%yc(1-LAP:nx+LAP-1,1-LAP:ny+LAP-1,1-LAP:nz+LAP-1) , &
			   B%zc(1-LAP:nx+LAP-1,1-LAP:ny+LAP-1,1-LAP:nz+LAP-1)  )   ! LAP ��������   
	 
	 
	 allocate( B%U(NVAR1,1-LAP:nx+LAP-1,1-LAP:ny+LAP-1,1-LAP:nz+LAP-1) )   ! LAP ��������   ! bug is removed
	 allocate( B%Un(NVAR1,-1:nx+1,-1:ny+1,-1:nz+1))  ! ˫�� Ghost Cell
     allocate( B%Vol(nx-1,ny-1,nz-1)) 
     allocate( B%Res(NVAR1,-1:nx+1,-1:ny+1,-1:nz+1))        !  �в�
	 allocate( B%dt(-1:nx+1,-1:ny+1,-1:nz+1))               !  ʱ�䲽��
	 allocate( B%deltU(5,-1:nx+1,-1:ny+1,-1:nz+1))          !  ��ʱ�䲽U�Ĳ�ֵ ����������ʹ�ã��Ӵ������ֵ������5����������
	 allocate( B%dU(NVAR1,-1:nx+1,-1:ny+1,-1:nz+1))         !  ��ʱ�䲽U�Ĳ�ֵ ��LU-SGS��ʹ�ã�
     allocate( B%Si(nx,ny,nz), B%Sj(nx,ny,nz), B%Sk(nx,ny,nz) )  ! �����
     allocate( B%ni1(nx,ny,nz),B%ni2(nx,ny,nz),B%ni3(nx,ny,nz), & 
               B%nj1(nx,ny,nz),B%nj2(nx,ny,nz),B%nj3(nx,ny,nz), &
               B%nk1(nx,ny,nz),B%nk2(nx,ny,nz),B%nk3(nx,ny,nz))
	 allocate( B%dw(nx-1,ny-1,nz-1))         ! ������ľ���
!  Jocabian�任ϵ������������ճ�����еĵ��� 
     allocate(B%ix1(nx,ny,nz),B%iy1(nx,ny,nz),B%iz1(nx,ny,nz), &
	          B%jx1(nx,ny,nz),B%jy1(nx,ny,nz),B%jz1(nx,ny,nz), &
              B%kx1(nx,ny,nz),B%ky1(nx,ny,nz),B%kz1(nx,ny,nz))
     allocate(B%ix2(nx,ny,nz),B%iy2(nx,ny,nz),B%iz2(nx,ny,nz), &
	          B%jx2(nx,ny,nz),B%jy2(nx,ny,nz),B%jz2(nx,ny,nz), &
              B%kx2(nx,ny,nz),B%ky2(nx,ny,nz),B%kz2(nx,ny,nz))
     allocate(B%ix3(nx,ny,nz),B%iy3(nx,ny,nz),B%iz3(nx,ny,nz), &
	          B%jx3(nx,ny,nz),B%jy3(nx,ny,nz),B%jz3(nx,ny,nz), &
              B%kx3(nx,ny,nz),B%ky3(nx,ny,nz),B%kz3(nx,ny,nz))
     allocate(B%ix0(nx,ny,nz),B%iy0(nx,ny,nz),B%iz0(nx,ny,nz), &
	          B%jx0(nx,ny,nz),B%jy0(nx,ny,nz),B%jz0(nx,ny,nz), &
              B%kx0(nx,ny,nz),B%ky0(nx,ny,nz),B%kz0(nx,ny,nz))
!-------------------------------------------------------
      allocate(B%dtime_mesh(nx-1,ny-1,nz-1))   ! ʱ�䲽������ ������������������
               B%dtime_mesh(:,:,:)=1.d0                ! ��ֵ
	 
	 if(Time_Method .eq. Time_Dual_LU_SGS) then             ! ˫ʱ��LU_SGSʹ�� n-1ʱ�̵�������
          allocate(B%Un1(NVAR1,-1:nx+1,-1:ny+1,-1:nz+1))
	 endif

!-------------------------------------------------------

     if(If_viscous .eq. 1) then 
      allocate(B%mu(-1:nx+1,-1:ny+1,-1:nz+1))   ! ����ճ��ϵ��
	  allocate(B%mu_t(-1:nx+1,-1:ny+1,-1:nz+1))    ! ����ճ��ϵ��
	  B%mu(:,:,:)=1.d0/Re
	  B%mu_t(:,:,:)=0.d0
     endif
!------������  (��������������ʱʹ��)------------------------------------
     allocate( B%Surf1(ny,nz,3),B%Surf2(nx,nz,3), B%Surf3(nx,ny,3),  &
               B%Surf4(ny,nz,3),B%Surf5(nx,nz,3), B%Surf6(nx,ny,3)   )          
	 B%Surf1(:,:,:)=0.d0; B%Surf2(:,:,:)=0.d0; B%Surf3(:,:,:)=0.d0
     B%Surf4(:,:,:)=0.d0; B%Surf5(:,:,:)=0.d0; B%Surf6(:,:,:)=0.d0
!---------------------------------------------------------------------------
! --------�������㣨���ܡ��ܶ�����Ϊ1���������㣩----------------------------
     B%x(:,:,:)=0.d0; B%y(:,:,:)=0.d0; B%z(:,:,:)=0.d0; B%xc(:,:,:)=0.d0; B%yc(:,:,:)=0.d0; B%zc(:,:,:)=0.d0 
     B%U(1,:,:,:)=1.d0; B%U(2,:,:,:)=0.d0; B%U(3,:,:,:)=0.d0; B%U(4,:,:,:)=0.d0; B%U(5,:,:,:)=1.d0
	 
	 if(NVAR1 .eq. 6) then
	    B%U(6,:,:,:)=1.d0
	 else if (NVAR1 .eq. 7) then
	    B%U(6,:,:,:)=0.d0
		B%U(7,:,:,:)=1.d0
	 endif
	   B%Res(:,:,:,:)=0.d0
   
    if( nMesh .ne. 1) then
       allocate( B%QF(NVAR1,-1:nx+1,-1:ny+1,-1:nz+1))         ! ǿ�Ⱥ���
	    B%QF(:,:,:,:)=0.d0                                    ! ǿ�Ⱥ�����ʼ��Ϊ0
    endif
 
 !----�߽�ָʾ�� (1 ����߽磬0�ڱ߽�)
     allocate(B%BcI(ny-1,nz-1,2),B%BcJ(nx-1,nz-1,2),B%BcK(nx-1,ny-1,2))
     B%BcI(:,:,:)=0
	 B%BcJ(:,:,:)=0
	 B%BcK(:,:,:)=0
    
   enddo

  end subroutine allocate_mem_Blocks


 ! �趨�߽�ָʾ�� (0 ����߽磬 1 �ڱ߽�), ���� �߽׸�ʽ ���Ƿ����ñ߽��ʽ��
   subroutine set_BcK(nm)  
   use Global_var
   implicit none
   Type (Block_TYPE),pointer:: B
   TYPE (BC_MSG_TYPE),pointer:: Bc
   integer :: i,j,k,m,nm,ksub
   integer:: ib,ie,jb,je,kb,ke
     do m=1,Mesh(nm)%Num_Block
       B=>Mesh(nm)%Block(m)
       B%BcI(:,:,:)=0
	   B%BcJ(:,:,:)=0
	   B%BcK(:,:,:)=0
     do  ksub=1,B%subface
     Bc=> B%bc_msg(ksub)
     ib=Bc%ib; ie=Bc%ie; jb=Bc%jb; je=Bc%je ; kb=Bc%kb; ke=Bc%ke      
     if(Bc%bc >=0 ) then   ! ���ڱ߽�
       if(Bc%face .eq. 1 ) then   
         B%BcI(jb:je-1,kb:ke-1,1)=1
	   else if(Bc%face .eq. 2) then
         B%BcJ(ib:ie-1,kb:ke-1,1)=1
	   else if(Bc%face .eq. 3) then
         B%BcK(ib:ie-1,jb:je-1,1)=1
       else if(Bc%face .eq. 4 ) then   
         B%BcI(jb:je-1,kb:ke-1,2)=1
	   else if(Bc%face .eq. 5) then
         B%BcJ(ib:ie-1,kb:ke-1,2)=1
	   else if(Bc%face .eq. 6) then
         B%BcK(ib:ie-1,jb:je-1,2)=1
       endif
	 endif
	enddo
    enddo
   end
!------------------------------------------------
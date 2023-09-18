!----------------------------------------------------------------------
! �ڸ��������������N-S���� ���ƽ�1��ʱ�䲽��
! ���ڵ�������nMesh=1;  ���ڶ�������nMesh=1,2,3, ... �ֱ��Ӧ��ϸ���񡢴����񡢸������� ...
! 2015-11-26: A bug in Line 299 is removed   (KRK should be a shared data)
 
  subroutine NS_Time_advance(nMesh)
   use Global_var
   implicit none
   integer:: nMesh
   if(Time_Method .eq. Time_Euler1) then
     call NS_Time_advance_1Euler(nMesh)                    ! 1��Euler
   else if (Time_Method .eq. Time_LU_SGS ) then            !  LU_SGS
     call NS_Time_advance_LU_SGS(nMesh)
   else if (Time_Method .eq. Time_Dual_LU_SGS) then        ! Dual_LU_SGS
     call  NS_Time_Dual_LU_SGS(nMesh)
   else if (Time_Method .eq. Time_RK3) then
     call NS_Time_advance_RK3(nMesh)                       ! 3��RK
   else
     print*, "This time advance method is not supported!!!"
   endif
    call force_vt_kw(nMesh)     ! ǿ�� vt, k,w �Ǹ�

  end subroutine NS_Time_advance

!---------------------------------------------------------------------------------------------
! ǿ��vt, k,w�Ǹ�   
   subroutine force_vt_kw(nMesh)
    use Global_var
    implicit none
    integer:: nMesh,mBlock,nx,ny,nz,i,j,k
    Type (Block_TYPE),pointer:: B
    Type (Mesh_TYPE),pointer:: MP
  
    MP=>Mesh(nMesh)
    do mBlock=1,MP%Num_Block
       B => MP%Block(mBlock)
       nx=B%nx; ny=B%ny ; nz=B%nz
    if(MP%NVAR == 6) then
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(i,j,k)
      do k=1,nz-1
 	  do j=1,ny-1
      do i=1,nx-1
       if(B%U(6,i,j,k) < 0)  B%U(6,i,j,k)=1.d-10
      enddo
      enddo
	  enddo
!$OMP END PARALLEL DO
    else if (MP%NVAR == 7) then
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(i,j,k)
 	  do k=1,nz-1
	  do j=1,ny-1
      do i=1,nx-1
       if(B%U(6,i,j,k) < 0)  B%U(6,i,j,k)=1.d-10
       if(B%U(7,i,j,k) < 0)  B%U(7,i,j,k)=1.d-10
	  enddo
      enddo
	  enddo
!$OMP END PARALLEL DO
    endif
   enddo    
  end
!--------------------------------------------------------------------------------------











! ���� LU_SGS��������ʱ���ƽ�һ��ʱ�䲽 ����nMesh������ �ĵ�������
  subroutine NS_Time_advance_LU_SGS(nMesh)
   use Global_var
   implicit none
   integer::nMesh,mBlock,NVAR1,i,j,k,m,nx,ny,nz
   Type (Block_TYPE),pointer:: B
   real(PRE_EC):: du
   call Set_Un(nMesh)
   call Comput_Residual_one_mesh(nMesh)              ! ���������ϼ���в� (�Լ�Du)
   if(nMesh .ne. 1) call Add_force_function(nMesh)   !  ���ǿ�Ⱥ�������������Ĵ�����ʹ�ã�
  
   NVAR1=Mesh(nMesh)%NVAR
   do mBlock=1,Mesh(nMesh)%Num_Block
     B => Mesh(nMesh)%Block(mBlock)
     nx=B%nx; ny=B%ny; nz=B%nz
!--------------------------------------------------------------------------------------
!   ʱ���ƽ� 

!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(nx,ny,nz,NVAR1,B)
     do k=1,nz-1
       do j=1,ny-1
         do i=1,nx-1
           do m=1,NVAR1
             B%U(m,i,j,k)=B%Un(m,i,j,k)+B%dU(m,i,j,k)           ! LU_SGS����
            enddo
         enddo
       enddo
	 enddo
!$OMP END PARALLEL DO       
  
  enddo

!----------------------------------------------------------------   
    if( IFLAG_LIMIT_Flow == 1) then                      ! ��ѹ�����ܶȽ�������
	  call limit_flow(nMesh)
	endif 

!---------------------------------------------------------------------------------------  
   call Boundary_condition_onemesh(nMesh)             ! �߽����� ���趨Ghost Cell��ֵ��
   call update_buffer_onemesh(nMesh)                  ! ͬ������Ľ�����
   
   Mesh(nMesh)%tt=Mesh(nMesh)%tt+dt_global            ! ʱ�� ��ʹ��ȫ��ʱ�䲽����ʱ�����壩
   Mesh(nMesh)%Kstep=Mesh(nMesh)%Kstep+1              ! ���㲽��

  end subroutine NS_Time_advance_LU_SGS
!--------------------------------------------------------------------------------------



!  ����˫ʱ�䲽���� LU_SGS��������ʱ���ƽ�һ��ʱ�䲽 
!  ĿǰDual LU_SGS �����в�֧�ֶ�������,���nMeshֻ��Ϊ1

  subroutine NS_Time_Dual_LU_SGS(nMesh)
    use Global_var
    implicit none
    integer::nMesh,mBlock,NVAR1,i,j,k,m,nx,ny,nz,Kt_in
    Type (Block_TYPE),pointer:: B
    Type (Mesh_TYPE),pointer:: MP
    real(PRE_EC):: max_res
    
	MP=>Mesh(nMesh)
    NVAR1=MP%NVAR
 do kt_in=1, step_inner_Limit                      ! ��ѭ������

   call Comput_Residual_one_mesh(nMesh)              ! ���������ϼ���вDu
   do mBlock=1,Mesh(nMesh)%Num_Block
     B => Mesh(nMesh)%Block(mBlock)
     nx=B%nx; ny=B%ny; nz=B%nz
!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(nx,ny,nz,NVAR1,B)
     do k=1,nz-1
       do j=1,ny-1
         do i=1,nx-1
           do m=1,NVAR1
             B%U(m,i,j,k)=B%U(m,i,j,k)+B%dU(m,i,j,k)           ! LU_SGS����
            enddo
         enddo
       enddo
	 enddo
!$OMP END PARALLEL DO       
   enddo

!----------------------------------------------------------------   
    if( IFLAG_LIMIT_FLOW == 1) then                      ! ��ѹ�����ܶȽ�������
	  call limit_flow(nMesh)
	endif 


  call Boundary_condition_onemesh(nMesh)             ! �߽����� ���趨Ghost Cell��ֵ��
  call update_buffer_onemesh(nMesh)                  ! ͬ������Ľ�����
  call comput_max_Res_onemesh(nMesh)                 ! �������в�������в�

     max_res=MP%Res_rms(1)       ! ���������в� (��Ϊ�ڵ�����׼)
     do m=1,NVAR1
 	  max_res=max(max_res,MP%Res_rms(m))
	 enddo
     if( max_res .le. Res_Inner_Limit) exit   ! �ﵽ�в��׼�������ڵ���
 enddo
   
   if(my_id .eq. 0) then 	
	 print*, "Inner step ... ", kt_in
	 print*, "rms residual eq =", MP%Res_rms(1:NVAR1)
   endif

    
 
   do mBlock=1,Mesh(nMesh)%Num_Block
     B => Mesh(nMesh)%Block(mBlock)
     nx=B%nx; ny=B%ny; nz=B%nz

!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(nx,ny,nz,NVAR1,B)
     do k=1,nz-1
       do j=1,ny-1
         do i=1,nx-1
           do m=1,NVAR1
			 B%Un1(m,i,j,k)=B%Un(m,i,j,k)        
             B%Un(m,i,j,k)=B%U(m,i,j,k)  
            enddo
         enddo
       enddo
	 enddo
!$OMP END PARALLEL DO       
   
  enddo


   Mesh(nMesh)%tt=Mesh(nMesh)%tt+dt_global            ! ʱ�� ��ʹ��ȫ��ʱ�䲽����ʱ�����壩
   Mesh(nMesh)%Kstep=Mesh(nMesh)%Kstep+1              ! ���㲽��

  end subroutine NS_Time_Dual_LU_SGS
!--------------------------------------------------------------------------------------












! ����1��Euler������ʱ���ƽ�һ��ʱ�䲽 ����nMesh������ �ĵ�������
  subroutine NS_Time_advance_1Euler(nMesh)
   use Global_var
   implicit none
   integer::nMesh,mBlock,NVAR1,i,j,k,m,nx,ny,nz
   Type (Block_TYPE),pointer:: B
   real(PRE_EC):: du
   call Set_Un(nMesh)
   call Comput_Residual_one_mesh(nMesh)              ! ���������ϼ���в�
   if(nMesh .ne. 1) call Add_force_function(nMesh)   !  ���ǿ�Ⱥ�������������Ĵ�����ʹ�ã�

    NVAR1=Mesh(nMesh)%NVAR
   do mBlock=1,Mesh(nMesh)%Num_Block
     B => Mesh(nMesh)%Block(mBlock)
     nx=B%nx; ny=B%ny; nz=B%nz
!--------------------------------------------------------------------------------------
!   ʱ���ƽ� 
!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(nx,ny,nz,NVAR1,B)
     do k=1,nz-1
       do j=1,ny-1
         do i=1,nx-1
           do m=1,NVAR1
             du=B%Res(m,i,j,k)/B%vol(i,j,k)   
             B%U(m,i,j,k)=B%Un(m,i,j,k)+B%dt(i,j,k)*du
           enddo
         enddo
       enddo
	 enddo
!$OMP END PARALLEL DO 
  
  enddo    


!----------------------------------------------------------------   
    if( IFLAG_LIMIT_FLOW == 1) then                      ! ��ѹ�����ܶȽ�������
	  call limit_flow(nMesh)
	endif 

!---------------------------------------------------------------------------------------  
   call Boundary_condition_onemesh(nMesh)             ! �߽����� ���趨Ghost Cell��ֵ��
   call update_buffer_onemesh(nMesh)                  ! ͬ������Ľ�����
   Mesh(nMesh)%tt=Mesh(nMesh)%tt+dt_global            ! ʱ�� ��ʹ��ȫ��ʱ�䲽����ʱ�����壩
   Mesh(nMesh)%Kstep=Mesh(nMesh)%Kstep+1              ! ���㲽��

  end subroutine NS_Time_advance_1Euler
!----------------------------------------------------------------------------------------


! ����3��RK�����ƽ�1��ʱ�䲽 ����nMesh������ �ĵ�������
  subroutine NS_Time_advance_RK3(nMesh)
   use Global_var
   implicit none
   integer::nMesh,mBlock,NVAR1,i,j,k,m,nx,ny,nz
   Type (Block_TYPE),pointer:: B
   real(PRE_EC):: du
 
   NVAR1=Mesh(nMesh)%NVAR
   do mBlock=1,Mesh(nMesh)%Num_Block
     B => Mesh(nMesh)%Block(mBlock)

!$OMP PARALLEL DO PRIVATE(i,j,k,m) SHARED(NVAR1,B)
	 do k=-1,B%nz+1
       do j=-1,B%ny+1
	     do i=-1,B%nx+1
	       do m=1,NVAR1
	         B%Un(m,i,j,k)=B%U(m,i,j,k)
           enddo
	     enddo
       enddo
	 enddo
!$OMP END PARALLEL DO 
 
   enddo

   do KRK=1,3                                          ! 3-step Runge-Kutta Method
	 call Comput_Residual_one_mesh(nMesh)              ! ����в�
     if(nMesh .ne. 1) call Add_force_function(nMesh)   ! ���ǿ�Ⱥ�������������Ĵ�����ʹ�ã�
	 do mBlock=1,Mesh(nMesh)%Num_Block
       B => Mesh(nMesh)%Block(mBlock)                  ! ��nMesh ������ĵ�mBlock��
       nx=B%nx; ny=B%ny; nz=B%nz
!--------------------------------------------------------------------------------------
!    ʱ���ƽ�

!$OMP PARALLEL DO PRIVATE(i,j,k,m,du) SHARED(NVAR1,nx,ny,nz,Ralfa,Rbeta,Rgamma,B,KRK)
       do k=1,nz-1 
         do j=1,ny-1
           do i=1,nx-1
             do m=1,NVAR1
		       du=B%Res(m,i,j,k)/B%Vol(i,j,k)  
               B%U(m,i,j,k)=Ralfa(KRK)*B%Un(m,i,j,k)+Rgamma(KRK)*B%U(m,i,j,k)+B%dt(i,j,k)*Rbeta(KRK)*du        ! 3��RK
             enddo
           enddo
         enddo
	   enddo
 !$OMP END PARALLEL DO 
   enddo    

!---------------------------------------------------------------------------------------

    if( IFLAG_LIMIT_FLOW == 1) then                      ! ��ѹ�����ܶȽ�������
	  call limit_flow(nMesh)
	endif 

 
     call Boundary_condition_onemesh(nMesh)         ! �߽����� ���趨Ghost Cell��ֵ��
     call update_buffer_onemesh(nMesh)              ! ͬ������Ľ�����
   enddo   
   Mesh(nMesh)%tt=Mesh(nMesh)%tt+dt_global          ! ʱ�� ��ʹ��ȫ��ʱ�䲽����ʱ�����壩
   Mesh(nMesh)%Kstep=Mesh(nMesh)%Kstep+1            ! ���㲽��

  end subroutine NS_Time_advance_RK3


! �������в�;������в��������
  subroutine comput_max_Res_onemesh(nMesh)
   use Global_var
   implicit none
	integer:: nMesh,mBlock,i,j,k,m,ierr
	logical F_NaN
 	real(PRE_EC):: Res,Res_max(7),Res_rms(7)
    Type (Mesh_TYPE),pointer:: MP
    Type (Block_TYPE),pointer:: B
 
     MP=> Mesh(nMesh)
   
      Res_max(:)=0.d0
	  Res_rms(:)=0.d0
 
   do mBlock=1,MP%NUM_BLOCK 
!     call comput_max_Res_oneblock(nMesh,mBlock)
   	  B => MP%Block(mBlock)                 !��nMesh ������ĵ�mBlock��

!$OMP PARALLEL DO DEFAULT(FIRSTPRIVATE) SHARED(MP,B) REDUCTION(MAX: Res_max) REDUCTION(+: Res_rms)   
	 do k=1,B%nz-1
       do j=1,B%ny-1
         do i=1,B%nx-1
! -------------------------------------------------------------------------------------------
!    ʱ���ƽ�
           do m=1,MP%NVAR
             Res=B%Res(m,i,j,k)
!--------------------------------------------------------------------------------------------------
! detech "NaN", Since Ver 0.72, which is useful for debug
             F_NaN=Isnan(Res)
             if(F_NaN) then
 		       print*, "NaN in Residual is found !, In block",B%block_no
			   print*, "location i,j,k,m=",i,j,k,m
!               B%Res(m,i,j,k)=0.d0    ! ǿ��Ϊ0
			    print*, "Stop"
			   stop
		     endif  
              Res_max(m)=max(Res_max(m),abs(Res))    ! ���в�
			  Res_rms(m)=Res_rms(m)+Res*Res           ! �������в�
!--------------------------------------------------------------------------------------------------       
	       enddo
         enddo
       enddo
	 enddo
!$OMP END PARALLEL DO
  enddo
 
    call MPI_ALLREDUCE(Res_max(1),MP%Res_max(1),MP%NVAR,OCFD_DATA_TYPE,MPI_MAX,MPI_COMM_WORLD,ierr)
    call MPI_ALLREDUCE(Res_rms(1),MP%Res_rms(1),MP%NVAR,OCFD_DATA_TYPE,MPI_SUM,MPI_COMM_WORLD,ierr)
    MP%Res_rms(:)=sqrt(MP%Res_rms(:)/(MP%Num_Cell))   !�������в�

  end  subroutine comput_max_Res_onemesh

!-------------------------------------------------------------

!--------------------------------------------------------------
! ��ӡ�в���в�;������в
  subroutine output_Res(nMesh)
   use Global_var
   implicit none
	integer:: nMesh
    call   comput_max_Res_onemesh(nMesh)
!-----------------------------------
   if(my_id .eq. 0) then
    print*, "Kstep, t=", Mesh(nMesh)%Kstep, Mesh(nMesh)%tt
    print*, "----------The Max Residuals are-------- ", " ---Mesh---",nMesh
    write(*, "(7E20.10)") Mesh(nMesh)%Res_max(:)
    print*, "  The R.M.S Residuals are "
    write(*, "(7E20.10)") Mesh(nMesh)%Res_rms(:)
    open(99,file="Residual.dat",position="append")
    write(99,"(I8,15E20.10)") Mesh(nMesh)%Kstep, Mesh(nMesh)%Res_max(:),Mesh(nMesh)%Res_rms(:)
    close(99) 
   endif

  end  subroutine output_Res

!-------------------------------------------------------------


!----------------------------------------------------------
! ��SA,SST���̵���������������
  subroutine limit_vt(nMesh,mBlock)
   use Global_Var
   use Flow_Var 
   implicit none
   Type (Block_TYPE),pointer:: B
   integer nMesh,mBlock,NVAR1,nx,ny,nz,i,j,k
   
   B => Mesh(nMesh)%Block(mBlock)                 !��nMesh ������ĵ�mBlock��
   nx=B%nx; ny=B%ny; nz=B%nz
   NVAR1=Mesh(nMesh)%NVAR
   if(NVAR1 .eq. 6) then
!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(nx,ny,nz,B)
    do k=0,nz
    do j=0,ny
	do i=0,nx
	 if(B%U(6,i,j,k) .lt. 0.d0) B%U(6,i,j,k)=0.d0
	enddo
	enddo
	enddo
!$OMP END PARALLEL DO
   else if (NVAR1 .eq. 7) then
!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(nx,ny,nz,B)
    do k=0,nz
	do j=0,ny
	do i=0,nx
	 if(B%U(6,i,j,k) .lt. 0.d0) B%U(6,i,j,k)=0.d0
	 if(B%U(7,i,j,k) .lt. 0.d0) B%U(7,i,j,k)=0.d0
    enddo
	enddo
	enddo
!$OMP END PARALLEL DO

  endif
  end	 







!----------------------------------------------------------------------
! �����������N-S���� ���ƽ�1��ʱ�䲽��
! nMesh=1,2,3 �ֱ��Ӧ��ϸ���񡢴����񡢸�������
! ����2�������3�����������ӳ���
! Code by Li Xinliang & Leng Yan
!---------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------
! �����������ƽ�1��ʱ�䲽 (3��RK or 1th Euler)
  subroutine NS_2stge_multigrid
   use Global_var
   implicit none
   integer::nMesh,m
   Type (Block_TYPE),pointer:: B
   integer,parameter:: Time_step_coarse_mesh=3       ! �������������
!---------------------------------------------------
! -------------------------  ����1 -----------------
   if(Time_Method .eq. Time_Euler1) then
	 call  NS_Time_advance_1Euler(1)                 ! ϸ����1��Euler�����ƽ�1�� -> U(n+1)
   else
	 call  NS_Time_advance_RK3(1)                    ! ϸ����RK�����ƽ�1�� -> U(n+1)
   endif 
   call  Comput_Residual_one_mesh(1)                 ! ��������1�Ĳв� R(n+1)  
   call  interpolation2h(1,2,2)                      ! �Ѳв��ֵ������2 (������QF����)
   call  interpolation2h(1,2,1)                      ! ���غ����������1��ֵ������2   ��flag=1 ��ֵ�غ������=2 ��ֵ�в
!------------------------------
   call  Boundary_condition_onemesh(2)               ! ����߽�����
   call  update_buffer_onemesh(2)                    ! �ڱ߽�����
   call  Comput_Residual_one_mesh(2)                 ! ��������2�Ĳв�
   call  comput_force_function(2)                    ! ����ǿ�Ⱥ���QF
   if(Time_Method .eq. Time_Euler1) then
	 call Set_Un(2)                                  ! ��¼��ʼֵ  ��RK�������Ѿ������˸ò��� 
     do m=1, Time_step_coarse_mesh
	   call  NS_Time_advance_1Euler(2)               ! 1��Euler�������ɲ�
     enddo
   else 
	 call  NS_Time_advance_RK3(2)                    ! RK�����ƽ�1�� ������2��
   endif
   call  comput_delt_U(2)                            ! ����������deltU ��������Un���棩
   call  prolong_U(2,1,2)                            ! ����������ֵ��ϸ���� (������Un����); flag=2 ��ֵdeltU (������Un��)
!------------------------------------	 
   call  comput_new_U(1)                             ! �����µ�U  (U=U+deltU)
   call  Boundary_condition_onemesh(1)               ! ����߽�����
   call  update_buffer_onemesh(1)                    ! �ڱ߽�����

  end subroutine NS_2stge_multigrid
!------------------------------------------------------------------------------------------
!-----------------------------------------------------------------------------------------
! ���������ϵ���1��ʱ�䲽 ��V-�͵����� 3��RK or 1��Euler
  subroutine NS_3stge_multigrid
   use Global_var
   implicit none
   integer::nMesh,m
   integer,parameter:: Time_step_coarse_mesh=3       ! ������������� (��1��Euler��Ч)
!---------------------------------------------------
! ---- ---------------------------------- ����1 -----------------
   if(Time_Method .eq. Time_Euler1) then
	 call  NS_Time_advance_1Euler(1)                 ! ϸ����1��Euler�����ƽ�1�� -> U(n+1)
   else
	 call  NS_Time_advance_RK3(1)                    ! ϸ����RK�����ƽ�1�� -> U(n+1)
   endif
   call  Comput_Residual_one_mesh(1)                 ! ��������1�Ĳв� R(n+1)   ! ????? �ò��ƺ�����ʡ�� ?????  
! -----------------------------  
   call  interpolation2h(1,2,2)                      ! �Ѳв��ֵ������2 (����������2��QF����)
   call  interpolation2h(1,2,1)                      ! ���غ����������1��ֵ������2 �����浽U���棩  ��flag=1 ��ֵ�غ������=2 ��ֵ�в
!-------����2 --------------------
   call  Boundary_condition_onemesh(2)               ! ����߽�����
   call  update_buffer_onemesh(2)                    ! �ڱ߽�����
   call  Comput_Residual_one_mesh(2)                 ! ��������2�Ĳв�         Res_2h(0)
   call  comput_force_function(2)                    ! ����ǿ�Ⱥ���QF ������2��QF_2h=QF_2h-Res_2h(0) 
   if(Time_Method .eq. Time_Euler1) then
	 call Set_Un(2)                                  ! ��¼��ʼֵ  ��RK�������Ѿ������˸ò��� 
     do m=1, Time_step_coarse_mesh
	   call  NS_Time_advance_1Euler(2)               ! 1��Euler�������ɲ�
     enddo
   else 
	 call  NS_Time_advance_RK3(2)                    ! RK�����ƽ�1�� ������2��
   endif
   call  Comput_Residual_one_mesh(2)                 ! ��������2�Ĳв� R_2h(n+1) 
   call  Add_force_function(2)                       ! �����ǿ�Ȳв�(������Res����)  RF_2h(n+1)=R_2h(n+1)+QF_2h  ;  Ŀ�ģ���ֵ������3��
   call  interpolation2h(2,3,2)                      ! �Ѳв��ֵ������3 (����������3��QF����)
   call  interpolation2h(2,3,1)                      ! ���غ����������2��ֵ������3 �����浽U���棩  ��flag=1 ��ֵ�غ������=2 ��ֵ�в
!------����3----------------------	  
   call  Boundary_condition_onemesh(3)               ! �߽�����: ����߽� 
   call  update_buffer_onemesh(3)                    ! �ڱ߽�
   call  Comput_Residual_one_mesh(3)                 ! ��������3�Ĳв�
   call  comput_force_function(3)                    ! ����ǿ�Ⱥ���QF ������3��
   if(Time_Method .eq. Time_Euler1) then
	 call Set_Un(3)
     do m=1, Time_step_coarse_mesh
	   call  NS_Time_advance_1Euler(3)               ! 1��Euler�������ɲ�
     enddo
   else 
	 call  NS_Time_advance_RK3(3)                    ! RK�����ƽ�1�� ������3��
   endif
   call  comput_delt_U(3)                            ! ����������deltU (=U-Un)
   call  prolong_U(3,2,2)                            ! ����������ֵ������2 (������deltU����); flag=2 ��ֵdeltU 
!------����2------------------------      
   call  comput_new_U(2)                             ! ����2�����µ�U  (U=U+deltU)
   call  comput_delt_U(2)                            ! ����������deltU =U-Un
   call  prolong_U(2,1,2)                            ! ����������ֵ��ϸ���� (������deltU����); flag=2 ��ֵdeltU 
!------����1------------------------------
   call  comput_new_U(1)                             ! �����µ�U  (U=U+deltU)
   call Boundary_condition_onemesh(1)                ! ����߽�����
   call update_buffer_onemesh(1)                     ! �ڱ߽�����

  end subroutine NS_3stge_multigrid

!------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------
  
!  ����ǿ�Ⱥ��� QF=Ih_to_2h Res(n-1) - Res(n)        ! QF�д�����ϸ�����ֵ�����Ĳв�
  subroutine comput_force_function(nMesh)
   use Global_var
   implicit none
   integer::nMesh,mBlock,NVAR1,i,j,k,m
   Type (Block_TYPE),pointer:: B
    NVAR1=Mesh(nMesh)%NVAR
   do mBlock=1,Mesh(nMesh)%Num_Block
     B => Mesh(nMesh)%Block(mBlock)

!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(B,NVAR1)
	 do k=-1,B%nz+1
       do j=-1,B%ny+1
	     do i=-1,B%nx+1
	       do m=1,NVAR1
	         B%QF(m,i,j,k)=B%QF(m,i,j,k)-B%Res(m,i,j,k)            ! QFԭ�ȴ����Ŵ�ϸ�����ֵ�����Ĳв�
           enddo
	     enddo
       enddo
	 enddo
!$OMP END PARALLEL DO 
   enddo

  end  subroutine comput_force_function

!------------------------------------------------------------
!  ��ǿ�Ⱥ�����ӵ��в��� RF=R+QF        
  subroutine Add_force_function(nMesh)
   use Global_var
   implicit none
   integer::nMesh,mBlock,NVAR1,i,j,k,m
   Type (Block_TYPE),pointer:: B
    NVAR1=Mesh(nMesh)%NVAR
   do mBlock=1,Mesh(nMesh)%Num_Block
     B => Mesh(nMesh)%Block(mBlock)
!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(B,NVAR1)
	 do k=-1,B%nz+1
       do j=-1,B%ny+1
	     do i=-1,B%nx+1
	       do m=1,NVAR1
	         B%Res(m,i,j,k)=B%Res(m,i,j,k)+B%QF(m,i,j,k)            ! ���ǿ�Ⱥ�����Ĳв��Դ�����B%Res���� ����ʡ�ڴ棩
           enddo
	     enddo
       enddo
	 enddo
!$OMP END PARALLEL DO 
   enddo
 
  end  subroutine Add_force_function

!----------------------------------------------------------------------  
!  ���������� deltU=U-Un
  subroutine comput_delt_U(nMesh)
   use Global_var
   implicit none
   integer::nMesh,mBlock,i,j,k,m
   Type (Block_TYPE),pointer:: B
   do mBlock=1,Mesh(nMesh)%Num_Block
     B => Mesh(nMesh)%Block(mBlock)
!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(B)
	 do k=-1,B%nz+1
       do j=-1,B%ny+1
	     do i=-1,B%nx+1
	       do m=1,5
	         B%deltU(m,i,j,k)=B%U(m,i,j,k)-B%Un(m,i,j,k)
           enddo
	     enddo
       enddo
	 enddo
 !$OMP END PARALLEL DO 
  enddo
  end  subroutine comput_delt_U
!-----------------------------------------------------------------------
! �趨Un=U
  subroutine Set_Un(nMesh)
   use Global_var
   implicit none
   integer::nMesh,mBlock,NVAR1,i,j,k,m
   Type (Block_TYPE),pointer:: B
   NVAR1=Mesh(nMesh)%NVAR
   do mBlock=1,Mesh(nMesh)%Num_Block
     B => Mesh(nMesh)%Block(mBlock)
!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(B,NVAR1)
	 do k=-1,B%nz+1
       do j=-1,B%ny+1
	     do i=-1,B%nx+1
	       do m=1,NVAR1
	         B%Un(m,i,j,k)=B%U(m,i,j,k)
           enddo
	     enddo
       enddo
	 enddo
!$OMP END PARALLEL DO 
   enddo
  
  end  subroutine Set_Un
!-------------------------------����U --------------------------------------
  subroutine comput_new_U(nMesh)
   use Global_var
   implicit none
   integer::nMesh,mBlock,i,j,k,m
   Type (Block_TYPE),pointer:: B
   do mBlock=1,Mesh(nMesh)%Num_Block
     B => Mesh(nMesh)%Block(mBlock)
!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(B)
	 do k=-1,B%nz+1
       do j=-1,B%ny+1
	     do i=-1,B%nx+1
	       do m=1,5                                             ! ��6����������ճ��ϵ��vt (SAģ��ʹ��),����Ҫ����
	         B%U(m,i,j,k)=B%U(m,i,j,k)+B%deltU(m,i,j,k)         ! Un���洢�����U�������� ���Ӵ������ֵ������
           enddo
	     enddo
       enddo
	 enddo
!$OMP END PARALLEL DO 
   enddo

  end  subroutine comput_new_U
!---------------------------------------------------------------------------
! ��������ϸ����Ĳ�ֵ(Prolong) �� ϸ������������ϲ�ֵ (interpolation)
!----------------------------------------------------------------------
! ������m1���غ����(U) ��U�Ĳ��ֵ������m2 (��һ��ϸ����)
! flag=1ʱ����U��ֵ����һ������  (׼����ֵʱʹ��)
! flag=2ʱ����deltU��ֵ����һ������ ��deltU�����ű�ʱ�䲽���ϸ�ʱ�䲽U�Ĳ 

  Subroutine prolong_U(m1,m2,flag)
   use Global_Var
   use interface_defines
   implicit none
   integer:: m1,m2,mb,flag
   Type (Mesh_TYPE),pointer:: MP1,MP2
   Type (Block_TYPE),pointer:: B1,B2
   if(m1 .le. 1 .or. m1-m2 .ne. 1) print*, "Error !!!!"
     MP1=>Mesh(m1)
     MP2=>Mesh(m2)
     do mb=1,MP1%Num_Block
       B1=>MP1%Block(mb)
	   B2=>Mp2%Block(mb)
	   if(flag .eq. 1) then
!	   call prolongation(B1%nx,B1%ny,B1%nz,B2%nx,B2%ny,B2%nz,B1%U(1,-1,-1,-1),B2%U(1,-1,-1,-1))   ! �ɵĳ���ӿڣ����°�Fortran������
	    call prolongation(B1%nx,B1%ny,B1%nz,B2%nx,B2%ny,B2%nz,B1%U,B2%U)
  	   else
!	    call prolongation(B1%nx,B1%ny,B1%nz,B2%nx,B2%ny,B2%nz,B1%deltU(1,-1,-1,-1),B2%deltU(1,-1,-1,-1))
	    call prolongation(B1%nx,B1%ny,B1%nz,B2%nx,B2%ny,B2%nz,B1%deltU,B2%deltU)
     endif
   enddo

  end Subroutine prolong_U
!-------------------------------------------------------------
!   ��������ϸ�����ϵĲ�ֵ     
!   U1�Ǵ������ϵ�ֵ�� U2��ϸ�����ϵ�ֵ
  subroutine prolongation(nx1,ny1,nz1,nx2,ny2,nz2,U1,U2)
   use precision_EC
   implicit none
    integer:: i,j,k,m,nx1,ny1,nz1,nx2,ny2,nz2,NV
    real(PRE_EC),dimension(:,:,:,:),pointer:: U1,U2
 !   real(PRE_EC):: U1(NVAR,-1:nx1+1,-1:ny1+1,-1:nz1+1),U2(NVAR,-1:nx2+1,-1:ny2+1,-1:nz2+1)
    integer:: ia(2,0:nx2),ja(2,0:ny2),ka(2,0:nz2),U_bound(4)
 !   integer,parameter::NVAR=6
    real(PRE_EC),parameter:: a1=27.d0/64.d0,a2=9.d0/64.d0,a3=3.d0/64.d0,a4=1.d0/64.d0   ! ��ֵϵ��
    
!  Ѱ�Ҳ�ֵ���ܵ���±� 
!  ia(1,i) �Ǿ���i������Ĵ��������±ꣻia(2,i)�Ǵν�����±�	 
    U_bound=UBOUND(U1)   ! ��1ά���Ͻ� ��NVAR)
    NV=U_bound(1)   ! NVAR= 5, 6 or 7 
    
   do i=0,nx2
	 if(mod(i,2).eq.0) then
	   ia(1,i)=i/2                    !�����
	   ia(2,i)=i/2+1                  !�ν���
	 else  
	   ia(1,i)=i/2+1                  !�����
	   ia(2,i)=i/2                    !�ν���
	 endif
   enddo
   do j=0,ny2
	 if( mod(j,2).eq. 0) then
	   ja(1,j)=j/2
	   ja(2,j)=j/2+1
	 else
	   ja(1,j)=j/2+1
	   ja(2,j)=j/2
	 endif
   enddo
   do k=0,nz2
	 if(mod(k,2).eq.0) then
	   ka(1,k)=k/2                    !�����
	   ka(2,k)=k/2+1                  !�ν���
	 else  
	   ka(1,k)=k/2+1                  !�����
	   ka(2,k)=k/2                    !�ν���
	 endif
   enddo
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(i,j,k,m)

   do k=0,nz2
	 do j=0,ny2
	   do i=0,nx2
	     do m=1,NV
!               ��ֵ��������Ȩ��a1, �ν����Ȩ��a2, ��Զ���Ȩ��a3	 
	       U2(m,i,j,k)=a1*U1(m,ia(1,i),ja(1,j),ka(1,k))+a2*(U1(m,ia(2,i),ja(1,j),ka(1,k))+U1(m,ia(1,i),ja(2,j),ka(1,k)) &
	                   +U1(m,ia(1,i),ja(1,j),ka(2,k)))+a3*(U1(m,ia(2,i),ja(1,j),ka(2,k))+U1(m,ia(1,i),ja(2,j),ka(2,k)) &
	                   +U1(m,ia(2,i),ja(2,j),ka(1,k)))+a4*U1(m,ia(2,i),ja(2,j),ka(2,k))
         enddo
	   enddo
     enddo
   enddo
!$OMP END PARALLEL DO 
  end subroutine prolongation
!---------------------------------------------------------------------------------
! ������m1���غ����U��ֵ������m2 (ϸ����->������) 
  Subroutine interpolation2h(m1,m2,flag)
   use Global_Var
   implicit none
   Type (Mesh_TYPE),pointer:: MP1,MP2
   Type (Block_TYPE),pointer:: B1,B2
   real(PRE_EC),dimension(:,:,:,:),pointer:: P1,P2
   integer:: NVAR1,flag,m1,m2,mb,i,j,k,m,i1,i2,j1,j2,k1,k2
!  flag==1 ��ֵ�غ������ flag==2 ��ֵ�в�
   if( m2-m1 .ne. 1) print*, "Error !!!!"
     MP1=>Mesh(m1)
     MP2=>Mesh(m2) 
	 NVAR1=5              ! ֻ��ֵ5���غ����  
     do mb=1,MP1%Num_Block
       B1=>MP1%Block(mb)
  	   B2=>Mp2%Block(mb)
       if(flag .eq. 1) then  ! ��ֵ�غ����
	     P1=>B1%U
	     P2=>B2%U
!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(B1,B2,NVAR1,P1,P2)
	     do k=1,B2%nz-1
           do j=1,B2%ny-1
	         do i=1,B2%nx-1
	           i1=2*i-1 ; i2=2*i
	           j1=2*j-1 ; j2=2*j
	           k1=2*k-1 ; k2=2*k
               do m=1,NVAR1
!     �Կ��������ΪȨ�صļ�Ȩƽ�� 	 
	             P2(m,i,j,k)=(P1(m,i1,j1,k1)*B1%Vol(i1,j1,k1)+P1(m,i1,j2,k1)*B1%Vol(i1,j2,k1)   &
		                      +P1(m,i1,j2,k2)*B1%Vol(i1,j2,k2)+P1(m,i2,j1,k1)*B1%Vol(i2,j1,k1)   &
	                          +P1(m,i2,j1,k2)*B1%Vol(i2,j1,k2)+P1(m,i2,j2,k1)*B1%Vol(i2,j2,k1)   &
					          +P1(m,i2,j2,k2)*B1%Vol(i2,j2,k2)+P1(m,i1,j1,k2)*B1%Vol(i1,j1,k2))/B2%Vol(i,j,k)
  	           enddo
	         enddo
	       enddo
	     enddo
!$OMP END PARALLEL DO 

       else     ! ��ֵ�в�  ����m1�����ϵĲв�B%Res ��ֵ��m2������B%QF (Ȼ���ȥ��m2�����ϵĲв�γ�ǿ�Ⱥ���)��
   	     P1=>B1%Res
	     P2=>B2%QF

!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(B2,P1,P2,NVAR1)
	     do k=0,B2%nz
           do j=0,B2%ny
	         do i=0,B2%nx
	           i1=2*i-1 ; i2=2*i
	           j1=2*j-1 ; j2=2*j
	           k1=2*k-1 ; k2=2*k
               do m=1,NVAR1
	             P2(m,i,j,k)=P1(m,i1,j1,k1)+P1(m,i1,j2,k1)+P1(m,i1,j2,k2)+P1(m,i2,j1,k1)   &    ! �в�Ĳ�ֵ�� �����
		                     +P1(m,i2,j1,k2)+P1(m,i2,j2,k1)+P1(m,i2,j2,k2)+P1(m,i1,j1,k2)
  	           enddo
	         enddo
	       enddo
	     enddo
 !$OMP END PARALLEL DO 

 	   endif
     enddo

  end Subroutine interpolation2h

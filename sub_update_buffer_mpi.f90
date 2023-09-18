!----�������֮�������--------------------------------------------------------------------------
! Copyright by Li Xinliang
! Ver 0.41 �޸���ori�Ķ��巽�����Լ���BXCFD
! Ver 0.43b  �޸��˽ǵ�ļ��㷽�� 
! Ver 0.46a �����˼������ӷ����ӳ��� get_ijk_orient()��һ����ҪBug   (face1��face2Ū����)
! Ver 0.50  (2010-12-9):  ����������˫��Ghost Cell, �����Բ��õ���Ghost Cell
! Ver 0.84  (2012-7-10):  ����Gridgen ��.inp��ʽ������
! Ver 0.9-mpi  MPI���а� ������Ϊ���а棩

!---------Continue boundary (inner boundary) ------------------------------------------------------
! ��������������������غ������������������� 
! ��������洢�ڽڵ㣬�������洢�����ĵ㣬 ������������봫���������ķ������±��Ӧ��ʽ����������
! MPI���а棻 
!  ���ԣ� ������(block)λ��ͬһ����(proc),�����ֱ�Ӵ���(��ͨ��MPI),�����Ч�ʣ�
!  ʹ��MPI����ʱ������ʹ��MPI_Bsend()����ȫ����Ϣ�� Ȼ��ʹ��MPI_recv()���ա� 

! ���ڶ�������ʱ��Ҳ��������� ��Ӧ��NVAR1�� , ...
     subroutine update_buffer_onemesh(nMesh)
     use Global_Var
     use interface_defines
     implicit none
     integer:: nMesh,ierr
! --------------------------------------------------------------------------------------- 
! ģ��߽�ͨ�ţ�  MPI �汾
    call Umessage_send_mpi(nMesh)   ! ʹ��MPI����ȫ����Ϣ ����Ŀ���Ҳ�ڱ������ڣ���ͨ��MPI,ֱ�ӽ�����Ϣ.
    call Umessage_recv_mpi(nMesh)   ! ����ȫ����Ϣ
   
    call MPI_Barrier(MPI_COMM_WORLD,ierr)
    
	if(If_TurboMachinary ==1) then
        call Umessage_Turbo_Periodic(nMesh)   !  �������ڱ߽����� 
    endif
    
	call Umessage_corner(nMesh)     ! ����������Ϣ�����ò�ֵ�ķ�����

  end subroutine update_buffer_onemesh

!---------------------------------------------------------------

! ͬһ����������֮���ͨ�� ����ֱ��ͨ�ţ�

     subroutine Umessage_send_mpi(nMesh)  
     use Global_Var
     use interface_defines
     implicit none
!---------------------------------------------    
     Type (Block_TYPE),pointer:: B,B1
     Type (BC_MSG_TYPE),pointer:: Bc
     integer:: i,j,k,m,i1,j1,k1,mb,mBlock,ksub,nMesh,Send_to_ID,Num_Data,tag,ierr
     integer:: kb(3),ke(3),kb1(3),ke1(3),ka(3),L1,L2,L3,P(3),Ks(3)
     real(PRE_EC),allocatable,dimension(:,:,:,:):: Usend

 ! --------------------------------------------------------------------------------------- 
 do mBlock=1,Mesh(nMesh)%Num_Block
   B => Mesh(nMesh)%Block(mBlock)

  do  ksub=1,B%subface
   Bc=> B%bc_msg(ksub)

!-----------------------------------------------------------------------------------------------
      if(Bc%bc .ge. 0 ) cycle          ! ���ڱ߽� inner boundary
      
!--------------------------------------------------------
!  B��ΪԴ���ݣ� B1��ΪĿ�����ݣ�   ���ݴ�Դ����д��Ŀ������

!      Դ����:�ٽ��߽��LAP�� �ڵ�;   i=kb(1) to ke(1), j=kb(2) to ke(2),  k= kb(3) to ke(3)
!      Ŀ������ ���ٽ��߽��LAP�� Ghost��,  �ְ汾LAP=2��

!      Դ���� 
       kb(1)=Bc%ib; ke(1)=Bc%ie-1; kb(2)=Bc%jb; ke(2)=Bc%je-1; kb(3)=Bc%kb; ke(3)=Bc%ke-1
       k=mod(Bc%face-1,3)+1                 ! k=1,2,3 Ϊi,j,k����
	   if(Bc%face .gt. 3) kb(k)=kb(k)-LAP   ! i+, j+ or k+ ��
       ke(k)=kb(k)+LAP-1

!      Ŀ������ ���߽��������LAP��Ghost�㣩
       kb1(1)=Bc%ib1; ke1(1)=Bc%ie1-1; kb1(2)=Bc%jb1; ke1(2)=Bc%je1-1; kb1(3)=Bc%kb1; ke1(3)=Bc%ke1-1
       k=mod(Bc%face1-1,3)+1                    ! k=1,2,3 Ϊi,j,k����
	   if(Bc%face1 .le. 3)  kb1(k)=kb1(k)-LAP   ! i-, j- or k- ��
       ke1(k)=kb1(k)+LAP-1


!  L1,L2,L3 : ����ά������ ; P(1),P(2),P(3): �������Ӵ���(˳��or ����)
       L1=abs(Bc%L1); P(1)=sign(1,Bc%L1)    ! L1=1 ��ζ�ţ���ά����Ŀ�����ݵĵ�1ά���ӣ� =2 Ϊ���2ά����, ...
       L2=abs(Bc%L2); P(2)=sign(1,Bc%L2)
       L3=abs(Bc%L3); P(3)=sign(1,Bc%L3)

!   ks(k) : Ŀ�����ݵ�kά����ʼ�±�
	   do k=1,3  !   Ŀ������ ��ʼ�±�     
	    if(P(k) .gt. 0) then
		 ks(k)=kb(k)     ! ˳�򣬴�kb��ʼ
		else
		 ks(k)=ke(k)     ! ���� ��ke��ʼ
	    endif
	  enddo
!
!-------------------------------------------------------------
      allocate(Usend(NVAR,kb1(1):ke1(1),kb1(2):ke1(2),kb1(3):ke1(3)))
       do k=kb1(3),ke1(3)             ! Ŀ�����ݵ��±� (i,j,k) , ��kb��ke
	     do j=kb1(2),ke1(2)
		   do i=kb1(1),ke1(1)
		     ka(1)=i-kb1(1)            
			 ka(2)=j-kb1(2)
			 ka(3)=k-kb1(3)
			 i1=ks(1)+ka(L1)*P(1)        ! Դ���ݵ��±� (i1,j1,k1), ��kb1��ke1 (�迼�� a.˳�������, b. ά������), L1,L2,L3����ά�����ӣ�P(k)����˳��/����
			 j1=ks(2)+ka(L2)*P(2)
			 k1=ks(3)+ka(L3)*P(3)
			 do m=1,NVAR
			  Usend(m,i,j,k)=B%U(m,i1,j1,k1)   ! ��Դ���ݣ��ڵ㣩 ������ Ŀ������ (��ʱ����)   
             enddo
           enddo
		 enddo
		enddo
  
  !    
	 Send_to_ID=B_proc(Bc%nb1)              ! ����Ŀ������ڵĽ��̺�

	 if( Send_to_ID .ne. my_id) then        ! Ŀ��鲻�ڱ�������
       Num_data=NVAR*(ke1(1)-kb1(1)+1)*(ke1(2)-kb1(2)+1)*(ke1(3)-kb1(3)+1)      ! ������
       tag=  Bc%nb1*1000+Bc%f_no1                                         ! ���; ���Bc%nb1, �����Bc%f_no1 ����һ�����̷��Ͷ�����ݰ�ʱ������ʶ��
	   call MPI_Bsend(Usend,Num_data,OCFD_DATA_TYPE, Send_to_ID, tag, MPI_COMM_WORLD,ierr )
!	   call MPI_send(Usend,Num_data,OCFD_DATA_TYPE, Send_to_ID, tag, MPI_COMM_WORLD,ierr )
	 else 
!        Ŀ���Ҳ�ڱ������ڣ�ֱ��д�� (��ͨ��MPI)
         mb=B_n(Bc%nb1)          ! ���ڲ����
		 B1 =>  Mesh(nMesh)%Block(mb)  ! ���ڿ� ��Ŀ��飩
	     do k=kb1(3),ke1(3)             ! 
	      do j=kb1(2),ke1(2)
		   do i=kb1(1),ke1(1)
			 do m=1,NVAR
			  B1%U(m,i,j,k)=Usend(m,i,j,k)    
             enddo
            enddo
		  enddo
		 enddo
	  endif	
	  deallocate(Usend)

  enddo
  enddo
 
  end
!--------------------------------------------------------------------------

! ��ȫ����Ϣ����

subroutine Umessage_recv_mpi(nMesh) ! ʹ��MPI����ȫ����Ϣ
     use Global_Var
     use interface_defines
     implicit none
!---------------------------------------------    
     Type (Block_TYPE),pointer:: B
     Type (BC_MSG_TYPE),pointer:: Bc
     integer:: i,j,k,m,mBlock,ksub,nMesh,Recv_from_ID,kb(3),ke(3)
	 integer:: tag,Num_DATA,ierr,Status(MPI_Status_SIZE)
     real(PRE_EC),allocatable,dimension(:,:,:,:):: Urecv

!---------------------------------------------------------------------------------------
! ���ս׶Σ���ȫ����Ϣ����
 do mBlock=1,Mesh(nMesh)%Num_Block
  B => Mesh(nMesh)%Block(mBlock)
  do  ksub=1,B%subface
   Bc=> B%bc_msg(ksub)
   if(Bc%bc .ge. 0 ) cycle               ! �ڱ߽� inner boundary
   Recv_from_ID=B_proc(Bc%nb1)           ! ���ڿ飨����Դ�飩���ڵĽ��̺�
   if(Recv_from_ID .eq. my_id) cycle     ! Դ���ڱ������ڣ���ʹ��MPIͨ�� (Umessage_send_mpi()�����д�����)  
   
!------------------------------------------------------------------------------------------------
!      Ŀ������ ���߽��������LAP��Ghost�㣩
       kb(1)=Bc%ib; ke(1)=Bc%ie-1; kb(2)=Bc%jb; ke(2)=Bc%je-1; kb(3)=Bc%kb; ke(3)=Bc%ke-1
       k=mod(Bc%face-1,3)+1                    ! k=1,2,3 Ϊi,j,k����
	   if(Bc%face .le. 3)  kb(k)=kb(k)-LAP   ! i-, j- or k- ��
       ke(k)=kb(k)+LAP-1

       allocate(Urecv(NVAR,kb(1):ke(1),kb(2):ke(2),kb(3):ke(3)))    ! �������飬����Ŀ�����ݵĸ�ʽ
       Num_data=NVAR*(ke(1)-kb(1)+1)*(ke(2)-kb(2)+1)*(ke(3)-kb(3)+1)      ! ������
	   tag=B%Block_no*1000+Bc%f_no                                  ! tag ��ǣ���ǿ��+�����
	   
	   call MPI_Recv(Urecv,Num_data,OCFD_DATA_TYPE,Recv_from_ID,tag,MPI_COMM_WORLD,status,ierr)

        do k=kb(3),ke(3)             ! Ŀ�����ݵ��±� (i,j,k) , ��kb��ke
	     do j=kb(2),ke(2)
		   do i=kb(1),ke(1)
			 do m=1,NVAR
             B%U(m,i,j,k)=Urecv(m,i,j,k)
			 enddo
           enddo
		  enddo
		enddo
       deallocate(Urecv)

   enddo
   enddo
  end


!------------------------------------------------------------------------
 subroutine Umessage_corner(nMesh)   ! ����������Ϣ�����ò�ֵ�ķ�����
   use Global_Var
   use interface_defines
   implicit none
   integer:: nMesh,mBlock
   Type (Block_TYPE),pointer:: B
 
  do mBlock=1,Mesh(nMesh)%Num_Block
  B => Mesh(nMesh)%Block(mBlock)
  !   �ǵ�������������ʽ���
  ! Visual Fortran ��Intel Fortran�����ݣ� �����ò�ͬ���﷨
   call get_U_conner(B%nx,B%ny,B%nz,NVAR,B%U)          ! ʹ��Intel Fortran
  
  enddo
  end
 

!---------------------------------------------------------------------------------
  subroutine Update_coordinate_buffer
    use Global_Var
    implicit none
    integer nMesh
	do nMesh=1,Num_Mesh
  	  call Update_coordinate_buffer_onemesh(nMesh)
	enddo
   end subroutine Update_coordinate_buffer
!-----------------------------------------------------------------


!---------Continue boundary (inner boundary) -------------------------------
! �������ڽ�������������������� 
! ��������洢�ڽڵ㣬�������洢�����ĵ㣬 ������������봫���������ķ������±��Ӧ��ʽ����������
! �������1���������
    subroutine Update_coordinate_buffer_onemesh(nMesh)
     use Global_Var
     use interface_defines
     implicit none
     integer:: nMesh,ierr
	 call Coordinate_send_mpi(nMesh)
     call Coordinate_recv_mpi(nMesh)
     call MPI_Barrier(MPI_COMM_WORLD,ierr)

     call Coordinate_Periodic(nMesh)              ! ���ڱ߽������
     call coordinate_boundary_and_corner(nMesh)   ! ���ڱ߽������
     call MPI_Barrier(MPI_COMM_WORLD,ierr)

 !---test----------------------------------------------------------
   end 





    subroutine Coordinate_send_mpi(nMesh)
     use Global_Var
     use interface_defines
     implicit none
     Type (Block_TYPE),pointer:: B,B1
     Type (BC_MSG_TYPE),pointer:: Bc,Bc1
     real(PRE_EC),allocatable:: Ux_send(:,:,:,:)   ! ��Ž����ϵ����ݣ����꣩
     integer:: i,j,k,m,i1,j1,k1,i2,j2,k2,km,mBlock,ksub,m_neighbour,msub,nMesh,mb
	 integer:: Send_to_ID,Num_Data,tag,ierr
     integer:: kb(3),ke(3),kb1(3),ke1(3),Ka(3),L1,L2,L3,P(3),ks(3)
 ! ---------------------------------------------------------------------------------------- 
  do mBlock=1,Mesh(nMesh)%Num_Block
   B => Mesh(nMesh)%Block(mBlock)
   do  ksub=1,B%subface
   Bc=> B%bc_msg(ksub)

   if(Bc%bc .ge. 0 ) cycle    ! �������ڱ߽� inner boundary
!--------------------------------------------------------------------------------------------  
!    ��Դ���� ���� ��Ŀ�����ݣ� 

!      Դ���� ���ٽ��߽��1���ڵ㣩
       kb(1)=Bc%ib; ke(1)=Bc%ie; kb(2)=Bc%jb; ke(2)=Bc%je; kb(3)=Bc%kb; ke(3)=Bc%ke
       k=mod(Bc%face-1,3)+1         ! k=1,2,3 Ϊi,j,k����
	   if(Bc%face .le. 3) then      ! i-, j- or k- ����
	    kb(k)=kb(k)+1       !  i=2 (�ڵ�)
	   else
	    kb(k)=kb(k)-1       !  i=nx-1 (�ڵ�) 
	   endif
        ke(k)=kb(k)

!      Ŀ������ ���߽����1�� Ghost��
       kb1(1)=Bc%ib1; ke1(1)=Bc%ie1; kb1(2)=Bc%jb1; ke1(2)=Bc%je1; kb1(3)=Bc%kb1; ke1(3)=Bc%ke1
       k=mod(Bc%face1-1,3)+1
	   if(Bc%face1 .le. 3) then          ! i-, j- or k-
	    kb1(k)=kb1(k)-1                  !  i=0 (Ghost��)
	   else
	    kb1(k)=kb1(k)+1                  ! i=nx+1 (Ghost��)
	   endif
	    ke1(k)=kb1(k)
	   

       L1=abs(Bc%L1); P(1)=sign(1,Bc%L1)
       L2=abs(Bc%L2); P(2)=sign(1,Bc%L2)
       L3=abs(Bc%L3); P(3)=sign(1,Bc%L3)
 
 !   Ŀ������ ��ʼ�±�     
	   do k=1,3
	    if(P(k) .gt. 0) then
		 ks(k)=kb(k)     ! ˳�򣬴�kb��ʼ
		else
		 ks(k)=ke(k)     ! ���� ��ke��ʼ
	    endif
	  enddo
!---------------------------------------------------------
!    �������飬����������� ����Ŀ�����ݵĸ�ʽ��
      allocate(Ux_send(3,kb1(1):ke1(1),kb1(2):ke1(2),kb1(3):ke1(3)))

!----------------------------------------------------------
! ��Դ���� ������ Ŀ������      
       
       do k=kb1(3),ke1(3)
	     do j=kb1(2),ke1(2)
		   do i=kb1(1),ke1(1)
		     ka(1)=i-kb1(1)
			 ka(2)=j-kb1(2)
			 ka(3)=k-kb1(3)
			 i1=ks(1)+ka(L1)*P(1)
			 j1=ks(2)+ka(L2)*P(2)
			 k1=ks(3)+ka(L3)*P(3)
			 Ux_send(1,i,j,k)=B%x(i1,j1,k1)    ! ��Դ���ݣ��ڵ㣩 ������ ��ʱ����
             Ux_send(2,i,j,k)=B%y(i1,j1,k1)
             Ux_send(3,i,j,k)=B%z(i1,j1,k1)
           enddo
		 enddo
		enddo

    	 Send_to_ID=B_proc(Bc%nb1)              ! ����Ŀ������ڵĽ��̺�
    
   
	 if( Send_to_ID .ne. my_id) then        ! Ŀ��鲻�ڱ�������
       Num_data=3*(ke1(1)-kb1(1)+1)*(ke1(2)-kb1(2)+1)*(ke1(3)-kb1(3)+1)      ! ������
       tag=  Bc%nb1*1000+Bc%f_no1                                         ! ���; ���Bc%nb1, �����Bc%f_no1 ����һ�����̷��Ͷ�����ݰ�ʱ������ʶ��
	   call MPI_Bsend(Ux_send,Num_data,OCFD_DATA_TYPE, Send_to_ID, tag, MPI_COMM_WORLD,ierr )
!	   call MPI_send(Ux_send,Num_data,OCFD_DATA_TYPE, Send_to_ID, tag, MPI_COMM_WORLD,ierr )
	 else 
       mb=B_n(Bc%nb1)    ! Bc%nb1 ���ڸý����е��ڲ����
       B1 =>  Mesh(nMesh)%Block(mb)    ! ���ڽ���
	   do k=kb1(3),ke1(3)
	     do j=kb1(2),ke1(2)
		   do i=kb1(1),ke1(1)
  		    B1%x(i,j,k)=Ux_send(1,i,j,k)    ! ��ʱ���鿽����Ŀ�����ݣ�Ghost �㣩
            B1%y(i,j,k)=Ux_send(2,i,j,k)
            B1%z(i,j,k)=Ux_send(3,i,j,k)
           enddo
		 enddo
	   enddo
      endif
	 deallocate(Ux_send)
  
  enddo
  enddo

 end subroutine Coordinate_send_mpi


!---------------------------------------------------------------------------------------
! ���գ�������Ϣ��
    subroutine Coordinate_recv_mpi(nMesh)
     use Global_Var
     use interface_defines
     implicit none
     Type (Block_TYPE),pointer:: B
     Type (BC_MSG_TYPE),pointer:: Bc
     real(PRE_EC),allocatable:: Ux_recv(:,:,:,:)   ! ��Ž����ϵ����ݣ����꣩
     integer:: i,j,k,mBlock,ksub,nMesh,Recv_from_ID,Num_data,tag,ierr,Status(MPI_Status_SIZE)

     integer:: kb(3),ke(3)
 ! ---------------------------------------------------------------------------------------- 
  do mBlock=1,Mesh(nMesh)%Num_Block

   B => Mesh(nMesh)%Block(mBlock)
   do  ksub=1,B%subface
   Bc=> B%bc_msg(ksub)
   if(Bc%bc .ge. 0 ) cycle    ! �������ڱ߽� inner boundary
!--------------------------------------------------------------------------------------------  
    Recv_from_ID=B_proc(Bc%nb1)           ! ���ڿ飨����Դ�飩���ڵĽ��̺�
    if(Recv_from_ID .eq. my_id) cycle     ! Դ���ڱ������ڣ���ʹ��MPIͨ�� ( Coordinate_send_mpi()�����д�����)  

!      Ŀ������ ���߽����1�� Ghost��
       kb(1)=Bc%ib; ke(1)=Bc%ie; kb(2)=Bc%jb; ke(2)=Bc%je; kb(3)=Bc%kb; ke(3)=Bc%ke
       k=mod(Bc%face-1,3)+1
	   if(Bc%face .le. 3) then          ! i-, j- or k-
	    kb(k)=kb(k)-1                  !  i=0 (Ghost��)
	   else
	    kb(k)=kb(k)+1                  ! i=nx+1 (Ghost��)
	   endif
	    ke(k)=kb(k)
       allocate(Ux_recv(3,kb(1):ke(1),kb(2):ke(2),kb(3):ke(3)))        ! �������飬����Ŀ�����ݵĸ�ʽ
       Num_data=3*(ke(1)-kb(1)+1)*(ke(2)-kb(2)+1)*(ke(3)-kb(3)+1)      ! ������
	   tag=B%Block_no*1000+Bc%f_no                                     ! tag ��ǣ���ǿ��+�����
	   call MPI_Recv(Ux_recv,Num_data,OCFD_DATA_TYPE,Recv_from_ID,tag,MPI_COMM_WORLD,status,ierr)

	   do k=kb(3),ke(3)
	     do j=kb(2),ke(2)
		   do i=kb(1),ke(1)
  		    B%x(i,j,k)=Ux_recv(1,i,j,k)    ! ��ʱ���鿽����Ŀ�����ݣ�Ghost �㣩
            B%y(i,j,k)=Ux_recv(2,i,j,k)
            B%z(i,j,k)=Ux_recv(3,i,j,k)
           enddo
		 enddo
	   enddo
       deallocate(Ux_recv)
	
	enddo
	enddo
   end subroutine Coordinate_recv_mpi





!---------------------------------------------------------------------------------------
!  ����߽磬����������������巨��� ;  �ǲ����򣬲����ڲ���   
	subroutine coordinate_boundary_and_corner(nMesh)
     use Global_Var
     use interface_defines
     implicit none
     Type (Block_TYPE),pointer:: B
     Type (BC_MSG_TYPE),pointer:: Bc
     integer:: i1,j1,k1,i2,j2,k2,mBlock,ksub,nMesh
 ! ---------------------------------------------------------------------------------------- 
 do mBlock=1,Mesh(nMesh)%Num_Block

   B => Mesh(nMesh)%Block(mBlock)
   do  ksub=1,B%subface
   Bc=> B%bc_msg(ksub)
 
   if(Bc%bc .ge. 0 ) then    ! ���ڱ߽� Not inner boundary

!   ��Ӧ���ڱ߽磬��������ϵ���������ڵ�ֵ����� (x0=2*x1-x2)
    i1=Bc%ib; i2=Bc%ie; j1=Bc%jb; j2=Bc%je; k1=Bc%kb; k2=Bc%ke
    if(Bc%face .eq. 1 ) then             !  boundary  i-
      B%x(i1-1,j1:j2,k1:k2)  =2.d0*B%x(i1,j1:j2,k1:k2)-B%x(i1+1,j1:j2,k1:k2)
      B%y(i1-1,j1:j2,k1:k2)  =2.d0*B%y(i1,j1:j2,k1:k2)-B%y(i1+1,j1:j2,k1:k2)
      B%z(i1-1,j1:j2,k1:k2)  =2.d0*B%z(i1,j1:j2,k1:k2)-B%z(i1+1,j1:j2,k1:k2)
    else if(Bc%face .eq. 2 ) then        !  boundary  j-
      B%x(i1:i2,j1-1,k1:k2)  =2.d0*B%x(i1:i2,j1,k1:k2)-B%x(i1:i2,j1+1,k1:k2)
      B%y(i1:i2,j1-1,k1:k2)  =2.d0*B%y(i1:i2,j1,k1:k2)-B%y(i1:i2,j1+1,k1:k2)
      B%z(i1:i2,j1-1,k1:k2)  =2.d0*B%z(i1:i2,j1,k1:k2)-B%z(i1:i2,j1+1,k1:k2)
    else if (Bc%face .eq. 3 ) then       ! k-
      B%x(i1:i2,j1:j2,k1-1)  =2.d0*B%x(i1:i2,j1:j2,k1)-B%x(i1:i2,j1:j2,k1+1)
      B%y(i1:i2,j1:j2,k1-1)  =2.d0*B%y(i1:i2,j1:j2,k1)-B%y(i1:i2,j1:j2,k1+1)
      B%z(i1:i2,j1:j2,k1-1)  =2.d0*B%z(i1:i2,j1:j2,k1)-B%z(i1:i2,j1:j2,k1+1)
    else if (Bc%face .eq. 4 ) then       ! i+
      B%x(i2+1,j1:j2,k1:k2)  =2.d0*B%x(i2,j1:j2,k1:k2)-B%x(i2-1,j1:j2,k1:k2)
      B%y(i2+1,j1:j2,k1:k2)  =2.d0*B%y(i2,j1:j2,k1:k2)-B%y(i2-1,j1:j2,k1:k2)
      B%z(i2+1,j1:j2,k1:k2)  =2.d0*B%z(i2,j1:j2,k1:k2)-B%z(i2-1,j1:j2,k1:k2)
    else if (Bc%face .eq. 5 ) then       ! j+
      B%x(i1:i2,j2+1,k1:k2)  =2.d0*B%x(i1:i2,j2,k1:k2)-B%x(i1:i2,j2-1,k1:k2)
      B%y(i1:i2,j2+1,k1:k2)  =2.d0*B%y(i1:i2,j2,k1:k2)-B%y(i1:i2,j2-1,k1:k2)
      B%z(i1:i2,j2+1,k1:k2)  =2.d0*B%z(i1:i2,j2,k1:k2)-B%z(i1:i2,j2-1,k1:k2)
    else if (Bc%face .eq. 6 ) then       ! k+
      B%x(i1:i2,j1:j2,k2+1)  =2.d0*B%x(i1:i2,j1:j2,k2)-B%x(i1:i2,j1:j2,k2-1)
      B%y(i1:i2,j1:j2,k2+1)  =2.d0*B%y(i1:i2,j1:j2,k2)-B%y(i1:i2,j1:j2,k2-1)
      B%z(i1:i2,j1:j2,k2+1)  =2.d0*B%z(i1:i2,j1:j2,k2)-B%z(i1:i2,j1:j2,k2-1)
    endif
   endif
  enddo
  enddo

  !   �ǵ�������������ʽ���     

  do mBlock=1,Mesh(nMesh)%Num_Block
     B => Mesh(nMesh)%Block(mBlock)
     call get_xyz_conner(B%nx,B%ny,B%nz,B%x)   
     call get_xyz_conner(B%nx,B%ny,B%nz,B%y)
     call get_xyz_conner(B%nx,B%ny,B%nz,B%z)
  enddo
  end subroutine coordinate_boundary_and_corner





 !----------------------------------------------------------
 ! ����ǵ�(���ǲ�����)����  : �������12�����8������
    subroutine get_xyz_conner(nx,ny,nz,x)
    use precision_EC
    implicit none 
    integer:: nx,ny,nz
    real(PRE_EC),dimension(:,:,:),pointer::x
    
!    real(PRE_EC):: x(0:nx+1,0:ny+1,0:nz+1)
!   12���� �����������������õ���  

!-------------Modified By Li Xinliang ----------------------------------------------------------
     x(0,0,1:nz)=(x(1,0,1:nz)+x(0,1,1:nz))*0.5d0
     x(nx+1,0,1:nz)=(x(nx,0,1:nz)+x(nx+1,1,1:nz))*0.5d0
     x(0,ny+1,1:nz)=(x(1,ny+1,1:nz)+x(0,ny,1:nz))*0.5d0
     x(nx+1,ny+1,1:nz)=(x(nx,ny+1,1:nz)+x(nx+1,ny,1:nz))*0.5d0
   
     x(0,1:ny,0)=(x(1,1:ny,0)+x(0,1:ny,1))*0.5d0
     x(nx+1,1:ny,0)=(x(nx,1:ny,0)+x(nx+1,1:ny,1))*0.5d0
     x(0,1:ny,nz+1)=(x(1,1:ny,nz+1)+x(0,1:ny,nz))*0.5d0
     x(nx+1,1:ny,nz+1)=(x(nx,1:ny,nz+1)+x(nx+1,1:ny,nz))*0.5d0

     x(1:nx,0,0)=(x(1:nx,1,0)+x(1:nx,0,1))*0.5d0
     x(1:nx,ny+1,0)=(x(1:nx,ny,0)+x(1:nx,ny+1,1))*0.5d0
     x(1:nx,0,nz+1)=(x(1:nx,1,nz+1)+x(1:nx,0,nz))*0.5d0
     x(1:nx,ny+1,nz+1)=(x(1:nx,ny,nz+1)+x(1:nx,ny+1,nz))*0.5d0
!-------------------------------------------------------------------------
 ! 8������ ��������6�������õ���
    x(0,0,0)=(2.d0*(x(1,0,0)+x(0,1,0)+x(0,0,1))-(x(1,1,0)+x(1,0,1)+x(0,1,1)))/3.d0
    x(nx+1,0,0)=(2.d0*(x(nx,0,0)+x(nx+1,1,0)+x(nx+1,0,1))-(x(nx,1,0)+x(nx,0,1)+x(nx+1,1,1)))/3.d0
    x(0,ny+1,0)=(2.d0*(x(1,ny+1,0)+x(0,ny,0)+x(0,ny+1,1))-(x(1,ny,0)+x(1,ny+1,1)+x(0,ny,1)))/3.d0
    x(nx+1,ny+1,0)=(2.d0*(x(nx,ny+1,0)+ x(nx+1,ny,0)+ x(nx+1,ny+1,1))-( x(nx,ny,0)+ x(nx,ny+1,1)+ x(nx+1,ny,1)))/3.d0
    x(0,0,nz+1)=(2.d0*(x(1,0,nz+1)+x(0,1,nz+1)+x(0,0,nz))-(x(1,1,nz+1)+x(1,0,nz)+x(0,1,nz)))/3.d0
    x(nx+1,0,nz+1)=(2.d0*(x(nx,0,nz+1)+x(nx+1,1,nz+1)+x(nx+1,0,nz))-(x(nx,1,nz+1)+x(nx,0,nz)+x(nx+1,1,nz)))/3.d0
    x(0,ny+1,nz+1)=(2.d0*(x(1,ny+1,nz+1)+x(0,ny,nz+1)+x(0,ny+1,nz))-(x(1,ny,nz+1)+x(1,ny+1,nz)+x(0,ny,nz)))/3.d0
    x(nx+1,ny+1,nz+1)=(2.d0*(x(nx,ny+1,nz+1)+ x(nx+1,ny,nz+1)+ x(nx+1,ny+1,nz))   &
                        -( x(nx,ny,nz+1)+ x(nx,ny+1,nz)+ x(nx+1,ny,nz)))/3.d0

     end
!-------------------------------------------------------------------
 ! ����ǵ�(���ǲ�����)��������  : �������12�����8������
    subroutine get_U_conner(nx,ny,nz,NVAR,U)
    use precision_EC
	implicit none 
    integer:: nx,ny,nz,NVAR
    real(PRE_EC),dimension(:,:,:,:),Pointer::U

! 12����  �ڲ��� 
    U(:,0,0,1:nz-1)=(U(:,1,0,1:nz-1)+U(:,0,1,1:nz-1))*0.5d0
    U(:,nx,0,1:nz-1)=(U(:,nx-1,0,1:nz-1)+U(:,nx,1,1:nz-1))*0.5d0
    U(:,0,ny,1:nz-1)=(U(:,1,ny,1:nz-1)+U(:,0,ny-1,1:nz-1))*0.5d0
    U(:,nx,ny,1:nz-1)=(U(:,nx-1,ny,1:nz-1)+U(:,nx,ny-1,1:nz-1))*0.5d0
   
    U(:,0,1:ny-1,0)=(U(:,1,1:ny-1,0)+U(:,0,1:ny-1,1))*0.5d0
    U(:,nx,1:ny-1,0)=(U(:,nx-1,1:ny-1,0)+U(:,nx,1:ny-1,1))*0.5d0
    U(:,0,1:ny-1,nz)=(U(:,1,1:ny-1,nz)+U(:,0,1:ny-1,nz-1))*0.5d0
    U(:,nx,1:ny-1,nz)=(U(:,nx-1,1:ny-1,nz)+U(:,nx,1:ny-1,nz-1))*0.5d0

    U(:,1:nx-1,0,0)=(U(:,1:nx-1,1,0)+U(:,1:nx-1,0,1))*0.5d0
    U(:,1:nx-1,ny,0)=(U(:,1:nx-1,ny-1,0)+U(:,1:nx-1,ny,1))*0.5d0
    U(:,1:nx-1,0,nz)=(U(:,1:nx-1,1,nz)+U(:,1:nx-1,0,nz-1))*0.5d0
    U(:,1:nx-1,ny,nz)=(U(:,1:nx-1,ny-1,nz)+U(:,1:nx-1,ny,nz-1))*0.5d0


! 8������
    U(:,0,0,0)=(2.d0*(U(:,1,0,0)+U(:,0,1,0)+U(:,0,0,1))-(U(:,1,1,0)+U(:,1,0,1)+U(:,0,1,1)))/3.d0
    U(:,nx,0,0)=(2.d0*(U(:,nx-1,0,0)+U(:,nx,1,0)+U(:,nx,0,1))-(U(:,nx-1,1,0)+U(:,nx-1,0,1)+U(:,nx,1,1)))/3.d0
    U(:,0,ny,0)=(2.d0*(U(:,1,ny,0)+U(:,0,ny-1,0)+U(:,0,ny,1))-(U(:,1,ny-1,0)+U(:,1,ny,1)+U(:,0,ny-1,1)))/3.d0
    U(:,nx,ny,0)=(2.d0*(U(:,nx-1,ny,0)+ U(:,nx,ny-1,0)+ U(:,nx,ny,1))-( U(:,nx-1,ny-1,0)+ U(:,nx-1,ny,1)+ U(:,nx,ny-1,1)))/3.d0
    U(:,0,0,nz)=(2.d0*(U(:,1,0,nz)+U(:,0,1,nz)+U(:,0,0,nz-1))-(U(:,1,1,nz)+U(:,1,0,nz-1)+U(:,0,1,nz-1)))/3.d0
    U(:,nx,0,nz)=(2.d0*(U(:,nx-1,0,nz)+U(:,nx,1,nz)+U(:,nx,0,nz-1))-(U(:,nx-1,1,nz)+U(:,nx-1,0,nz-1)+U(:,nx,1,nz-1)))/3.d0
    U(:,0,ny,nz)=(2.d0*(U(:,1,ny,nz)+U(:,0,ny-1,nz)+U(:,0,ny,nz-1))-(U(:,1,ny-1,nz)+U(:,1,ny,nz-1)+U(:,0,ny-1,nz-1)))/3.d0
    U(:,nx,ny,nz)=(2.d0*(U(:,nx-1,ny,nz)+ U(:,nx,ny-1,nz)+ U(:,nx,ny,nz-1))   & 
                   -( U(:,nx-1,ny-1,nz)+ U(:,nx-1,ny,nz-1)+ U(:,nx,ny-1,nz-1)))/3.d0

     end


!------------------------------------------------------------------------
! ���������������� ��Ghost �������������  ����������������ٶȾ��������ԣ���ֱ������ϵ�µ��ٶȷ����������������ԣ�

! ���(BC_PeriodicL)�ĵ� -Turbo_Seta;  �Ҳ�ĵ� + Turbo_Seta
 
 subroutine Umessage_Turbo_Periodic(nMesh)
     use Global_Var
     use interface_defines
     implicit none
!---------------------------------------------    
     Type (Block_TYPE),pointer:: B
     Type (BC_MSG_TYPE),pointer:: Bc
     integer:: i,j,k,m,mBlock,ksub,nMesh,Recv_from_ID,kb(3),ke(3)
     real(PRE_EC):: Seta,SetaP,seta0,ur,us,rr
!---------------------------------------------------------------------------------------
! 
 do mBlock=1,Mesh(nMesh)%Num_Block
  B => Mesh(nMesh)%Block(mBlock)
  do  ksub=1,B%subface
   Bc=> B%bc_msg(ksub)
   if(Bc%bc .ne. BC_PeriodicL .and. Bc%bc .ne. BC_PeriodicR ) cycle               ! �������Ա߽�
     if(Bc%bc == Bc_PeriodicL ) then
	    setaP= -Turbo_Periodic_Seta    !  Ҷ�ֻ������������ܽ�
 	 else 
	    SetaP=  Turbo_Periodic_Seta
	 endif

!------------------------------------------------------------------------------------------------
!    �߽��������LAP��Ghost��
       kb(1)=Bc%ib; ke(1)=Bc%ie-1; kb(2)=Bc%jb; ke(2)=Bc%je-1; kb(3)=Bc%kb; ke(3)=Bc%ke-1
       k=mod(Bc%face-1,3)+1                    ! k=1,2,3 Ϊi,j,k����
	   if(Bc%face .le. 3)  kb(k)=kb(k)-LAP   ! i-, j- or k- ��
       ke(k)=kb(k)+LAP-1
   
!  �����ٶ�ur,�����ٶ�us�����µ����귽���ؽ��� ��������������
	   
        do k=kb(3),ke(3)             ! Ŀ�����ݵ��±� (i,j,k) , ��kb��ke
	     do j=kb(2),ke(2)
		   do i=kb(1),ke(1)
             rr=sqrt(B%yc(i,j,k)**2+B%zc(i,j,k)**2)
			 seta=acos(B%yc(i,j,k)/rr)
			 if(B%zc(i,j,k) < 0) seta=-seta
 			 seta0=seta-SetaP     ! ԭ�Ƕ�
 			 ur=B%U(3,i,j,k)*cos(seta0)+B%U(4,i,j,k)*sin(seta0)          ! �����ٶ� (�����ܶ�)
		     us=-B%U(3,i,j,k)*sin(seta0)+B%U(4,i,j,k)*cos(seta0)         ! �����ٶ� (�����ܶ�)
		     
			 B%U(3,i,j,k)=ur*cos(seta)-us*sin(seta)                       ! ��ֵ 
			 B%U(4,i,j,k)=ur*sin(seta)+us*cos(seta)
 		   enddo
		  enddo
		enddo

   enddo
   enddo
  end

! ���գ�������Ϣ��
    subroutine Coordinate_Periodic(nMesh)
     use Global_Var
     use interface_defines
     implicit none
     Type (Block_TYPE),pointer:: B
     Type (BC_MSG_TYPE),pointer:: Bc
     integer:: i,j,k,mBlock,ksub,nMesh
     integer:: kb(3),ke(3)
     real(PRE_EC):: Seta,SetaP,rr,Xp,Yp,Zp

 ! ---------------------------------------------------------------------------------------- 
  do mBlock=1,Mesh(nMesh)%Num_Block

   B => Mesh(nMesh)%Block(mBlock)
   do  ksub=1,B%subface
   Bc=> B%bc_msg(ksub)

!--------------------------------------------------------------------------------------------  
    if(Bc%bc .ne. BC_PeriodicL .and. Bc%bc .ne. BC_PeriodicR ) cycle               ! �������Ա߽�
    if(Bc%bc == Bc_PeriodicL ) then    ! �����ڱ߽�
	    setaP= -Turbo_Periodic_Seta    !  Ҷ�ֻ������������ܽ�
	    Xp = - Periodic_dX;  Yp=- Periodic_dY; Zp= - Periodic_dZ
	endif

	if(Bc%bc == BC_PeriodicR)  then
	  SetaP=  Turbo_Periodic_Seta
      Xp =  Periodic_dX;  Yp= Periodic_dY; Zp=  Periodic_dZ
	endif

!      Ŀ������ ���߽����1�� Ghost��
       kb(1)=Bc%ib; ke(1)=Bc%ie; kb(2)=Bc%jb; ke(2)=Bc%je; kb(3)=Bc%kb; ke(3)=Bc%ke
       k=mod(Bc%face-1,3)+1
	   if(Bc%face .le. 3) then          ! i-, j- or k-
	    kb(k)=kb(k)-1                  !  i=0 (Ghost��)
	   else
	    kb(k)=kb(k)+1                  ! i=nx+1 (Ghost��)
	   endif
	    ke(k)=kb(k)

     if( IF_TurboMachinary == 1) then  ! Ҷ�ֻ�ģʽ
        do k=kb(3),ke(3)             ! Ŀ�����ݵ��±� (i,j,k) , ��kb��ke
	     do j=kb(2),ke(2)
		   do i=kb(1),ke(1)
             rr=sqrt(B%y(i,j,k)**2+B%z(i,j,k)**2)
			 seta=acos(B%y(i,j,k)/rr)
			 if(B%z(i,j,k) < 0) seta=-seta
 			 seta=seta+SetaP     ! ���������������� ��ת SetaP �Ƕ�
             B%y(i,j,k)=rr*cos(seta)
             B%z(i,j,k)=rr*sin(seta)
           enddo
		  enddo
		enddo
	 else             ! ��Ҷ�ֻ�ģʽ
        do k=kb(3),ke(3)             
	     do j=kb(2),ke(2)
		   do i=kb(1),ke(1)
             B%x(i,j,k)=B%x(i,j,k)+Xp    ! �������������� ���һ������
             B%y(i,j,k)=B%y(i,j,k)+Yp
             B%z(i,j,k)=B%z(i,j,k)+Zp
           enddo
		  enddo
		enddo
     endif


	
	enddo
	enddo
   end 


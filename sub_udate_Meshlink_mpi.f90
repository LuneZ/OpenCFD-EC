!----�������֮�������--------------------------------------------------------------------------
! ����LAP�� ���� (���ĵ�) ��Ϣ


!---------Continue boundary (inner boundary) ------------------------------------------------------
!  �������������������������������  ������ʹ�������Ա߽��������� 
!  ��������洢�ڽڵ㣬�������洢�����ĵ㣬 ������������봫���������ķ������±��Ӧ��ʽ����������
!  MPI���а棻 
!  ���ԣ� ������(block)λ��ͬһ����(proc),�����ֱ�Ӵ���(��ͨ��MPI),�����Ч�ʣ�
!  ʹ��MPI����ʱ������ʹ��MPI_Bsend()����ȫ����Ϣ�� Ȼ��ʹ��MPI_recv()���ա� 

     subroutine update_Mesh_Center(nMesh)
     use Global_Var
     use interface_defines
     implicit none
     integer:: nMesh,ierr
! --------------------------------------------------------------------------------------- 
! ģ��߽�ͨ�ţ�  MPI �汾
    call Mesh_send_mpi(nMesh)   ! ʹ��MPI����ȫ����Ϣ ����Ŀ���Ҳ�ڱ������ڣ���ͨ��MPI,ֱ�ӽ�����Ϣ.
    call Mesh_recv_mpi(nMesh)   ! ����ȫ����Ϣ
    call MPI_Barrier(MPI_COMM_WORLD,ierr)
    call Mesh_Center_Periodic(nMesh)     ! ���������������޸����� ����תһ���Ƕ�, ������Dx,Dy,Dz��

  end subroutine update_Mesh_Center

!---------------------------------------------------------------

! ͬһ����������֮���ͨ�� ����ֱ��ͨ�ţ�

     subroutine Mesh_send_mpi(nMesh)  
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
      allocate(Usend(3,kb1(1):ke1(1),kb1(2):ke1(2),kb1(3):ke1(3)))
       do k=kb1(3),ke1(3)             ! Ŀ�����ݵ��±� (i,j,k) , ��kb��ke
	     do j=kb1(2),ke1(2)
		   do i=kb1(1),ke1(1)
		     ka(1)=i-kb1(1)            
			 ka(2)=j-kb1(2)
			 ka(3)=k-kb1(3)
			 i1=ks(1)+ka(L1)*P(1)        ! Դ���ݵ��±� (i1,j1,k1), ��kb1��ke1 (�迼�� a.˳�������, b. ά������), L1,L2,L3����ά�����ӣ�P(k)����˳��/����
			 j1=ks(2)+ka(L2)*P(2)
			 k1=ks(3)+ka(L3)*P(3)
			 Usend(1,i,j,k)=B%xc(i1,j1,k1)   ! ��Դ���ݣ��ڵ㣩 ������ Ŀ������ (��ʱ����)   
			 Usend(2,i,j,k)=B%yc(i1,j1,k1)   ! ��Դ���ݣ��ڵ㣩 ������ Ŀ������ (��ʱ����)   
			 Usend(3,i,j,k)=B%zc(i1,j1,k1)   ! ��Դ���ݣ��ڵ㣩 ������ Ŀ������ (��ʱ����)   
           
		   enddo
		 enddo
		enddo
  
  !    
	 Send_to_ID=B_proc(Bc%nb1)              ! ����Ŀ������ڵĽ��̺�

	 if( Send_to_ID .ne. my_id) then        ! Ŀ��鲻�ڱ�������
       Num_data=3*(ke1(1)-kb1(1)+1)*(ke1(2)-kb1(2)+1)*(ke1(3)-kb1(3)+1)      ! ������
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
			  B1%xc(i,j,k)=Usend(1,i,j,k)    
			  B1%yc(i,j,k)=Usend(2,i,j,k)    
			  B1%zc(i,j,k)=Usend(3,i,j,k)    
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

subroutine Mesh_recv_mpi(nMesh) ! ʹ��MPI����ȫ����Ϣ
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
   if(Bc%bc .ge. 0 ) cycle               ! �ڱ߽� inner boundary �������Ա߽�
   Recv_from_ID=B_proc(Bc%nb1)           ! ���ڿ飨����Դ�飩���ڵĽ��̺�
   if(Recv_from_ID .eq. my_id) cycle     ! Դ���ڱ������ڣ���ʹ��MPIͨ�� (Umessage_send_mpi()�����д�����)  
   
!------------------------------------------------------------------------------------------------
!      Ŀ������ ���߽��������LAP��Ghost�㣩
       kb(1)=Bc%ib; ke(1)=Bc%ie-1; kb(2)=Bc%jb; ke(2)=Bc%je-1; kb(3)=Bc%kb; ke(3)=Bc%ke-1
       k=mod(Bc%face-1,3)+1                    ! k=1,2,3 Ϊi,j,k����
	   if(Bc%face .le. 3)  kb(k)=kb(k)-LAP   ! i-, j- or k- ��
       ke(k)=kb(k)+LAP-1

       allocate(Urecv(3,kb(1):ke(1),kb(2):ke(2),kb(3):ke(3)))    ! �������飬����Ŀ�����ݵĸ�ʽ
       Num_data=3*(ke(1)-kb(1)+1)*(ke(2)-kb(2)+1)*(ke(3)-kb(3)+1)      ! ������
	   tag=B%Block_no*1000+Bc%f_no                                  ! tag ��ǣ���ǿ��+�����
	   
	   call MPI_Recv(Urecv,Num_data,OCFD_DATA_TYPE,Recv_from_ID,tag,MPI_COMM_WORLD,status,ierr)

        do k=kb(3),ke(3)             ! Ŀ�����ݵ��±� (i,j,k) , ��kb��ke
	     do j=kb(2),ke(2)
		   do i=kb(1),ke(1)
             B%xc(i,j,k)=Urecv(1,i,j,k)
             B%yc(i,j,k)=Urecv(2,i,j,k)
             B%zc(i,j,k)=Urecv(3,i,j,k)
           enddo
		  enddo
		enddo
       deallocate(Urecv)
   enddo
   enddo
  end


!------------------------------------------------------------------------
! ���������������� ��Ghost ���������е���
! ���(BC_PeriodicL)�ĵ� -Turbo_Seta;  �Ҳ�ĵ� + Turbo_Seta
 
  subroutine Mesh_Center_Periodic(nMesh)
     use Global_Var
     use interface_defines
     implicit none
!---------------------------------------------    
     Type (Block_TYPE),pointer:: B
     Type (BC_MSG_TYPE),pointer:: Bc
     integer:: i,j,k,m,mBlock,ksub,nMesh,kb(3),ke(3)
     real(PRE_EC):: Seta,SetaP,rr,Xp,Yp,Zp
!---------------------------------------------------------------------------------------
! 
 do mBlock=1,Mesh(nMesh)%Num_Block
  B => Mesh(nMesh)%Block(mBlock)
  do  ksub=1,B%subface
   Bc=> B%bc_msg(ksub)
   if(Bc%bc .ne. BC_PeriodicL .and. Bc%bc .ne. BC_PeriodicR ) cycle               ! �������Ա߽�
    if(Bc%bc == Bc_PeriodicL ) then    ! �����ڱ߽�
	    setaP= -Turbo_Periodic_Seta    !  Ҷ�ֻ������������ܽ�
	    Xp = - Periodic_dX;  Yp=- Periodic_dY; Zp= - Periodic_dZ
	endif

	if(Bc%bc == BC_PeriodicR)  then
	  SetaP=  Turbo_Periodic_Seta
      Xp =  Periodic_dX;  Yp= Periodic_dY; Zp=  Periodic_dZ
	endif

!------------------------------------------------------------------------------------------------
!    �߽��������LAP��Ghost��
       kb(1)=Bc%ib; ke(1)=Bc%ie-1; kb(2)=Bc%jb; ke(2)=Bc%je-1; kb(3)=Bc%kb; ke(3)=Bc%ke-1
       k=mod(Bc%face-1,3)+1                    ! k=1,2,3 Ϊi,j,k����
	   if(Bc%face .le. 3)  kb(k)=kb(k)-LAP   ! i-, j- or k- ��
       ke(k)=kb(k)+LAP-1
	   
     if( IF_TurboMachinary == 1) then  ! Ҷ�ֻ�ģʽ
        do k=kb(3),ke(3)             ! Ŀ�����ݵ��±� (i,j,k) , ��kb��ke
	     do j=kb(2),ke(2)
		   do i=kb(1),ke(1)
             rr=sqrt(B%yc(i,j,k)**2+B%zc(i,j,k)**2)
			 seta=acos(B%yc(i,j,k)/rr)
			 if(B%zc(i,j,k) < 0) seta=-seta
 			 seta=seta+SetaP     ! ���������������� ��ת SetaP �Ƕ�
             B%yc(i,j,k)=rr*cos(seta)
             B%zc(i,j,k)=rr*sin(seta)
           enddo
		  enddo
		enddo
	 else             ! ��Ҷ�ֻ�ģʽ
        do k=kb(3),ke(3)             
	     do j=kb(2),ke(2)
		   do i=kb(1),ke(1)
             B%xc(i,j,k)=B%xc(i,j,k)+Xp
             B%yc(i,j,k)=B%yc(i,j,k)+Yp
             B%zc(i,j,k)=B%zc(i,j,k)+Zp
           enddo
		  enddo
		enddo
     endif


   enddo
   enddo
  end

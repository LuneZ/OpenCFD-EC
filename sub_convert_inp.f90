!----Boundary message (bc3d.inp, Gridgen general format)----------------------------------------------------------
! ��ȡ�߽��ʽ�ļ�(bc3d.inp)����ת��ΪOpenCFD-EC���ڽ�.inc��ʽ (����OpenCFD-EC�����ֲᡷ 2.4.3��)
! OpenCFD-EC�ڽ��Ĵ洢��ʽ��bc3d.inp����һЩ������Ϣ ����Щ����BXCFD��.in��ʽ����������������f_no,
! ������face �Լ����ӵ������f_no1,���ӵ�������face1
! �Լ����Ӵ���L1, L2, L3  (����L1=1��ʾ��ά�����ӿ�ĵ�1ά�����ӣ� L1=-1��ʾ�����ӿ�ĵ�1Ϊ��������).
! ��Щ������ϢΪ��-��֮���ͨ�ţ�������MPI����ͨ�ţ��ṩ�˱����������ڼ򻯴���
 
 module  Type_def1
    TYPE BC_MSG_TYPE              ! �߽�������Ϣ
 !   integer::  f_no, face, ist, iend, jst, jend, kst, kend, neighb, subface, orient   ! BXCFD .in format
     integer:: ib,ie,jb,je,kb,ke,bc,face,f_no                      ! �߽��������棩�Ķ��壬 .inp format
     integer:: ib1,ie1,jb1,je1,kb1,ke1,nb1,face1,f_no1             ! ��������
	 integer:: L1,L2,L3                     ! ����ţ�����˳��������
   END TYPE BC_MSG_TYPE


    TYPE Block_TYPE1                          ! ���ݽṹ��������Bc_msg 
	 integer::  nx,ny,nz                      ! ������nx,ny,nz
	 integer::  subface                       ! ������
 	 TYPE(BC_MSG_TYPE),pointer,dimension(:)::bc_msg     ! �߽�������Ϣ 
    END TYPE Block_TYPE1   
 End module  Type_def1

!------------------------------------------------------
  subroutine convert_inp_inc 
   use Type_def1
   implicit none
  
   integer:: NB,m,ksub,nx,ny,nz,k,j,k1,ksub1
   integer:: kb(3),ke(3),kb1(3),ke1(3),s(3),p(3),Lp(3)
   TYPE(Block_TYPE1),Pointer,dimension(:):: Block
   Type (Block_TYPE1),pointer:: B,B1
   TYPE (BC_MSG_TYPE),pointer:: Bc,Bc1
     
   Interface   
     subroutine Convert_bc(Bc,kb,ke,kb1,ke1)
       use Type_Def1
       implicit none
       TYPE (BC_MSG_TYPE),pointer:: Bc
	   integer,dimension(3):: kb,ke,kb1,ke1
	 end subroutine
    end Interface
   

   print*, "Convert bc3d.inp to bc3d.inc ..."
   open(88,file="bc3d.inp")
   read(88,*)
   read(88,*) NB
   allocate(Block(NB))
   do m=1,NB
    B => Block(m)
    read(88,*) B%nx,B%ny,B%nz
	read(88,*)
    read(88,*) B%subface   !number of the subface in the Block m
     
	allocate(B%bc_msg(B%subface))   ! �߽�����

    do ksub=1, B%subface
      Bc => B%bc_msg(ksub)
      Bc%f_no=ksub                        ! �����
	  read(88,*)  kb(1),ke(1),kb(2),ke(2),kb(3),ke(3),Bc%bc
	 
	  if(Bc%bc .lt. 0) then
 !  --------�����ӵ���� (�ڱ߽�)--------------------------------------------------------	    
	   read(88,*) kb1(1),ke1(1),kb1(2),ke1(2),kb1(3),ke1(3),Bc%nb1
      else
 !---------��������� (����߽�)----------------------------------------
            kb1(:)=0; ke1(:)=0; Bc%nb1=0
	  endif
	 call Convert_bc(Bc,kb,ke,kb1,ke1)
  enddo
  enddo
   
   close(88)

!  �������ӿ�Ŀ�� f_no1  (����MPI����ͨ����ʹ��)
   do m=1,NB
     B => Block(m)
     do ksub=1, B%subface
       Bc => B%bc_msg(ksub)
       if(Bc%bc .lt. 0) then
         Bc%f_no1=0
		 B1=>Block(Bc%nb1)         ! ָ�����ӿ�
         
		 do ksub1=1,B1%subface
		 Bc1=>B1%bc_msg(ksub1)
		 if(Bc%ib1==Bc1%ib .and. Bc%ie1==Bc1%ie .and. Bc%jb1==Bc1%jb .and. Bc%je1==Bc1%je   &
		    .and. Bc%kb1==Bc1%kb .and. Bc%ke1==Bc1%ke  .and. Bc1%nb1==m) then
		    Bc%f_no1=ksub1
		  exit
		 endif 	 
         enddo

         if(Bc%f_no1 ==0) then
		  print*, " Error in find linked block number !!!"
		  print*, "Block, subface=",m, ksub
		  stop
		 endif
	   endif
      enddo
	enddo

   open(99,file="bc3d.inc")
    write(99,*) " Inp-liked file of OpenCFD-EC"
    write(99,*) NB
	do m=1,NB
     B => Block(m)
     write(99,*) B%nx, B%ny, B%nz
	 write(99,*) "Block ", m
	 write(99,*) B%subface
	  do ksub=1,B%subface
        Bc => B%bc_msg(ksub)
	   write(99,"(9I6)") Bc%ib,Bc%ie,Bc%jb,Bc%je,Bc%kb,Bc%ke,Bc%bc,Bc%face,Bc%f_no
	   write(99,"(12I6)") Bc%ib1,Bc%ie1,Bc%jb1,Bc%je1,Bc%kb1,Bc%ke1,Bc%nb1,Bc%face1,Bc%f_no1,Bc%L1,Bc%L2,Bc%L3
      enddo
	enddo
	close(99)

   print*, "Convert bc3d.inp to bc3d.inc OK"


  end  

!-----------------------------------------------------------------------------------




!   ��Gridgen��ʽ ת��Ϊ OpenCFD-EC �ı߽����Ӹ�ʽ
!     ������š� ���Ӵ��� (L1,L2,L3)��
      subroutine Convert_bc(Bc,kb,ke,kb1,ke1)
       use Type_Def1
       implicit none
       TYPE (BC_MSG_TYPE),pointer:: Bc
	   integer,dimension(3):: kb,ke,kb1,ke1,s,p,LP
       integer:: k,j,k1

	   if(Bc%bc .ge. 0) then
	     Bc%ib1=0; Bc%ie1=0; Bc%jb1=0; Bc%je1=0; Bc%kb1=0; Bc%ke1=0; Bc%nb1=0
         Bc%L1=0; Bc%L2=0; Bc%L3=0; Bc%face1=0; Bc%f_no1=0
       endif
     

!   �жϸ�������� (i-, i+, j-,j+, k-,k+)     
       do k=1,3
  	     if(kb(k) .eq. ke(k) ) then 
	       s(k)=0                           ! ����ά
	     else if (kb(k) .gt. 0) then 
	       s(k)=1                           ! ��
	     else
	       s(k)=-1                          ! ��
	     endif
       enddo

!    �߽�����Ĵ�С     
	 Bc%ib=min(abs(kb(1)),abs(ke(1))) ;  Bc%ie=max(abs(kb(1)),abs(ke(1)))
     Bc%jb=min(abs(kb(2)),abs(ke(2))) ;  Bc%je=max(abs(kb(2)),abs(ke(2)))
     Bc%kb=min(abs(kb(3)),abs(ke(3))) ;  Bc%ke=max(abs(kb(3)),abs(ke(3))) 


!   �жϸ�������� (i-, i+, j-,j+, k-,k+)     
      if(s(1) .eq. 0) then
	     if (Bc%ib .eq. 1) then
	      Bc%face=1               ! i-
	     else
	      Bc%face=4               ! i+
	    endif
      else if(s(2) .eq. 0) then
	    if(Bc%jb .eq. 1) then
	      Bc%face=2                 ! j-
	    else
	      Bc%face=5                 ! j+
	    endif
      else
 	   if(Bc%kb  .eq. 1) then
	    Bc%face=3                 ! k-
	   else
	    Bc%face=6                 ! k+
	   endif
     endif 

!---------------------------------------------------------------------------
!------�ڱ߽�������������������
  if( Bc%bc .lt. 0) then            ! �ڱ߽�
!      ��������˳��������L1,L2,L3
!      �����ά֮������ӹ�ϵ      
     do k=1,3  
	   if(kb1(k) .eq. ke1(k) ) then 
	       p(k)=0                      ! 
       else if (kb1(k) .gt. 0) then
	       p(k)=1                      ! .inp �ļ��� ����
       else
	       p(k)=-1
       endif
     enddo
 	   

!    ��Ӧ��������Ĵ�С     
	 Bc%ib1=min(abs(kb1(1)),abs(ke1(1))) ;  Bc%ie1=max(abs(kb1(1)),abs(ke1(1)))
     Bc%jb1=min(abs(kb1(2)),abs(ke1(2))) ;  Bc%je1=max(abs(kb1(2)),abs(ke1(2)))
     Bc%kb1=min(abs(kb1(3)),abs(ke1(3))) ;  Bc%ke1=max(abs(kb1(3)),abs(ke1(3))) 
    
 	  
!   �жϸ�������������� (i-, i+, j-,j+, k-,k+)     
      if(p(1) .eq. 0) then
	     if (Bc%ib1 .eq. 1) then
	      Bc%face1=1               ! i-
	     else
	      Bc%face1=4               ! i+
	    endif
      else if(p(2) .eq. 0) then
	    if(Bc%jb1 .eq. 1) then
	      Bc%face1=2                 ! j-
	    else
	      Bc%face1=5                 ! j+
	    endif
      else
 	   if(Bc%kb1 .eq. 1) then
	    Bc%face1=3
	   else
	    Bc%face1=6
	   endif
     endif  

!  ���㡰���Ӷԡ� ������  bc%L1, bc%L2, bc%L3 
 	   do k=1,3
	     do j=1,3
	       if(s(k) .eq. p(j)) Lp(k)=j          ! .inp�ļ������Ӹ�ʽ�� �������� ���Ը��� 0��0�� 
	     enddo
	   enddo    
	   
!    �������Ӵ��� ����Ϊ˳�򣻸�Ϊ����	  
	  do k=1,3
	   if(s(k) .ne. 0) then
	     k1=Lp(k)
	     if( (ke(k)-kb(k))*(ke1(k1)-kb1(k1)) .lt. 0) Lp(k)=-Lp(k)      ! ��������
	   else
         k1=Lp(k)
!		 if( (mod(Bc%face,2)-mod(Bc%face1,2))==0) Lp(k)=-Lp(k)         ! �������� �����棩 ! Bug 2012-7-13
! ��-������ LpΪ�� (���� i+ �����ӵ� j+�棬 ��Ϊ��������)
		 if( (Bc%face-1)/3 .eq. (Bc%face1-1)/3 ) Lp(k)=-Lp(k)        ! (Bc%face=1,2,3Ϊ +�棬4,5,6Ϊ-��)  ! �������� �����棩

	   endif
	 enddo 
     
	 Bc%L1=Lp(1); Bc%L2=Lp(2); Bc%L3=Lp(3)   ! ���Ӵ��������� ������������ֲᡷ��
   endif
  end
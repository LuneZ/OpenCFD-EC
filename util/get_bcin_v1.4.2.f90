! �������ṹ����������Ϣ bc_in�ļ�
! Copyright by Li Xinliang, Institute of Mechanics, CAS, lixl@imech.ac.cn
! Ver 1.0, 2010-11-21
! Ver 1.1, 2010-12-3  : ���ڷ��μ����򣬿��Զ�ʶ��̱ڼ���߽磬 ���ҳ�������6��ƽ�棬�趨Զ����ԳƱ߽�������������Ϊ�̱ڣ�
! Ver 1.2, 2010-12-29: ������һ��СBug, �����ӵ�һ�ɰ��ڵ㴦��
! Ver 1.3, 2010-1-3:   ���á����ͨ������������������㷨��Ч��
! Ver 1.4.1, 2010-1-3:  ������״�༶�����㷨��ͨ���и���Ԫ(��Ƭ����)������������㷨��Ч��
! Ver 1.4.2, 2013-8-13: ��In2inp,f90 �ϲ����������У�������.in��.inp��ʽ�ļ�
!------------------------------------------------------------------------------------------------------------------------------ 
  module Global_Variables
  implicit none
  integer,parameter:: Nq=7  ! ÿһ����ָ�����ɸ���Ԫ��ÿ����ԪNq*Nq���㣻 ������״�༶��������ʱʹ��, ���Ե����������Ƽ���5-16֮�䣩�Դﵽ���Ч��
  integer,parameter:: Max_Link=50   ! һ���������50�����ӵ� 
  integer,parameter:: Max_Subface=100  ! һ�������100������
  integer,parameter:: BC_Wall=-10, BC_Farfield=-20 ,BC_Symmetry=-50   ! �̱ڡ�Զ�����Գ���
  real*8 :: Dist_limit , Dist_min  ! ��С������� 
  Integer:: Num_Block,Form_mesh
!------Types �����˵㡢��Ϳ��������ݽṹ -------------------------------------------------------------------------------------
! �㣺 ������ ���꣬���ӵ�ĸ��������ӵ����Ϣ�� �Ƿ�Ϊ�ڵ��־���Ƿ���������־
! �棺 ������ ��š�ά������
! �飺 ������ ��š�ά������
!-------------------------------------------------------------------------------------------------------------------------------
   TYPE Point_Type    ! ��
   real*8:: x, y, z   ! ����
   integer:: num_link ! ���ӵ�ĸ���
   integer:: search_flag, If_inner, color ! ����/Ⱦɫʱʹ�õı����    
   integer,dimension(MAX_Link):: block_link, face_link, n1_link, n2_link  ! ���ӵ����Ϣ����š���š��±꣩
   End TYPE Point_Type
  
   TYPE Subface_TYPE  ! ����
   integer:: subface_no, face_no, ib,jb,ie,je   ! �����(��ɫ)���������ڵ���ţ���ֹλ��
   integer:: subface_link , block_link , face_link , orient  ! ���ӵ����� , ���ӵĿ飬���ӵ��� , ����ָ���ԣ�1-4��  
   END TYPE Subface_TYPE
   

   TYPE Face_Type                     ! �� 
   integer:: face_no,n1,n2   ! ��š�����ά
   integer:: nk1,nk2   !��Ԫ����Ŀ
   Type (Point_Type),pointer,dimension(:,:) :: point 
   integer,pointer,dimension(:):: n1b,n1e,n2b,n2e
   real*8,pointer,dimension(:,:):: xc,yc,zc,dc  ! �������꣬�����ĵ�������
   End TYPE Face_Type
   
   TYPE Block_TYPE           !  ��
     integer :: Block_no,nx,ny,nz   ! ��š�����ά
     integer:: color_now, Num_Subface  ! ����ʹ�õ���ɫ�� ������Ŀ
     TYPE(Face_type),dimension(6):: Face
     TYPE (Subface_TYPE),dimension(Max_subface):: subface   ! ���� �������ڿ飩
  End TYPE Block_TYPE  
  
   TYPE (Block_TYPE), save,dimension(:),allocatable,target:: Block
  
  end module Global_Variables

!---------------------------------------------------------------
   program get_bcin
   use Global_Variables
   implicit none
   integer:: zone, face,i,j,m,nf,flag1
   TYPE (Block_Type), Pointer:: B
   TYPE (Face_Type), Pointer:: F

   print*, "----------------------------------------------------------------------------"
   print*, "- This code is used to create the Grid Link file (BXCFD bc_in Format)      -"
   print*, "-               Ver 1.4.1 , 2010-1-3                                       -"  
   print*, "- Copyright by Li Xinliang, Institute of Mechanics, CAS, lixl@imech.ac.cn  -"
   print*, "----------------------------------------------------------------------------"
   write(*,*)
   write(*,*)

   call read_coordinate    ! ��ȡ�������꣬��ʼ��

   call search_link        ! �������ӵ㣬��������������Ϣ ����������

   call Mark_inner_point   !����ڵ�

   call creat_subface      ! �������� �����ĳ���

 !    print*, "Do you want to search the wall and Far field bounary ? (1 for yes, 0 for no)"
 !    read(*,*)  flag1
 !    if( flag1 .eq. 1) then
 !      call search_wall_and_farfield   ! �����̱ڡ�Զ�����Գ���
 !    endif

   call write_bcin
   
   call Inp2In (Form_Mesh)

   print*, "OK, The link message is written into the file bc.in and bc.inp"   
!-----------------------------------
!    print*, "Write the test file test.dat"
!    open(99,file="test.dat")
!    write(99,*) "variables=x,y,z,link,color,inner,blink,flink,i1,i2,block,face"
!    do m=1,Num_Block
!      B => Block(m)
!    do nf=1,6 
!      F=> B%face(nf)
!     write(99,*) "zone i = ", F%n1, " j= ", F%n2
!     do j=1, F%n2
!     do i=1, F%n1
!     write(99,"(3f16.8,9I4)")  F%point(i,j)%x, F%point(i,j)%y,F%point(i,j)%z,F%point(i,j)%num_link,F%point(i,j)%color, &
!                F%point(i,j)%If_inner,F%point(i,j)%block_link(1),F%point(i,j)%face_link(1),&
!                i,j,m,nf
!     enddo
!     enddo
!    enddo
!    enddo
!   close(99)

  end



!---------------------------------------------------------------------------------------------------------------------------
! ��������ڵ�  
  subroutine Mark_inner_point
   use Global_Variables
   implicit none
   integer:: m,nf,i1,i2,flag1,flag2,flag3,flag4
   TYPE (Block_Type), Pointer:: B   ! ��ָ��
   TYPE (Face_Type), Pointer:: F    ! ��ָ��
   TYPE (Point_Type), Pointer:: P   ! ��ָ��

  do m=1,Num_Block
    B => Block(m)
  do nf=1,6 
    F=> B%face(nf)

!-----��ʾ "�����ڵ�"  �� ��Χ������ӵ����ͬһ�顢ͬһ�棩   
      do i2=2,F%n2-1
      do i1=2,F%n1-1
      P=> F%point(i1,i2)
! �޸� ��2010-12-29��     
!      if(P%num_link .le. 1) then   ! 1����0������  (������ӵĵ��Ϊ����߽��)

! 0�����ӱ�Ϊ�ڵ㣬1��������Ҫ�жϣ�������ӱ�Ϊ�߽��

       if(P%num_link .le. 0) then   ! 0�����ӱ�Ϊ�ڵ�
            P%If_inner=1
       else if  (P%num_link .eq. 1) then    
         call compare(m,nf,i1,i2, i1-1,i2, flag1) ! �ж������� �����ӵ��Ƿ���ͬһ��
         call compare(m,nf,i1,i2, i1+1,i2, flag2) 
         call compare(m,nf,i1,i2, i1,i2-1, flag3) 
         call compare(m,nf,i1,i2, i1,i2+1, flag4) 
         if( flag1*flag2*flag3*flag4 .eq. 1 ) P%If_inner=1   ! �����ڵ� 
      endif     
      enddo
      enddo
   enddo
   enddo
  print*, "Mark Inner Point OK"
 end subroutine Mark_inner_point


!------------------------------------------------------------------------------------------------------------------
! �������� �������㷨��  
  subroutine creat_subface
   use Global_Variables
   implicit none
   integer:: m,nf,i1,i2,color_now,ia,ja,ie,je,mt,nft,iat,jat,orient
   integer:: i1t,j1t,i2t,j2t
   TYPE (Block_Type), Pointer:: B,Bt
   TYPE (Face_Type), Pointer:: F,Ft            ! �����д�t�������ӣ��桢���桢�㣩
   TYPE (SubFace_Type), Pointer:: SF,SFt
   TYPE (Point_Type), Pointer:: P,P1

  do m=1,Num_Block
    B => Block(m)
  do nf=1,6 
    F=> B%face(nf)

 !------------------------------------------------------------------
 
    do i2=2,F%n2-1
    do i1=2,F%n1-1
   
    P=> F%point(i1,i2)
    if(P%If_inner .eq. 1 .and. P%color .eq. 0) then  ! ����ڵ㣬���ѱ�Ⱦ��ɫ��������

! ͨ��Ⱦɫ�㷨���ҵ��ӿ���±߽� (ie,je)     (i1,i2)- (ie,je) ���������ڵ�
       call find_subface_boundary(m,nf,i1,i2,ie,je)

!------�������棬��Ⱦɫ--------------------------------------
       B%color_now=B%color_now+1   ! �趨��ǰ��ɫ ������һ�����棬�½�һ����ɫ��
! ���������Ⱦɫ
        do ja=i2,je
        do ia=i1,ie
           F%point(ia,ja)%color=B%Color_now         
        enddo
        enddo

!  �ǼǱ���������� (��š���ֹ������)
      SF=>B%subface(B%Color_now)  ! ָ�������    
      SF%subface_no=B%Color_now   ! ��� ����ɫ��
      SF%face_no=nf               ! ���������ڵ����
      SF%ib=i1-1 ;  SF%jb=i2-1    ! ��������Ͻǵ�����
      SF%ie=ie+1 ;  SF%je=je+1    ! ��������½ǵ�����


! ���������,�������ӵ�������Ϣ����Ⱦɫ
   if(F%point(i1,i2)%Num_link .ne. 0) then   
          mt=F%point(i1,i2)%block_link(1)     ! �ڵ����ӵĿ�� 
          nft=F%point(i1,i2)%face_link(1)     ! �ڵ����ӵ����
	
   ! �����������棬�Ǽ����������������Ϣ
          Bt=>Block(mt)   ! ���ӵĿ�
          Ft=>Bt%face(nft)                    ! ���ӵ���                    
          Bt%color_now=Bt%color_now+1         ! �趨��������ĵ�ǰ��ɫ  �������ӿ��н���һ���µ����棩
          SFt=>Bt%subface(Bt%color_now)       ! ���ӵ�����
          SFt%subface_no=Bt%color_now         ! ��������ı��
          SFt%face_no=nft                     ! �����������ڵ����
          SFt%block_link=m   ! ����ǰ��
          SFt%face_link=nf   ! ����ǰ��
          SFt%subface_link=B%Color_now  ! ����ǰ����

  !  �ǼǱ������������Ϣ		  
          SF%block_link=mt  ! ��������ӿ�� ��=�ڵ�����ӿ�ţ�
          SF%face_link=nft  ! ������������
          SF%subface_link=Bt%color_now        ! ��������������� ����ɫ,��������ĵ�ǰɫ��

 ! ȷ�����ϡ����½ǵ�����ӵ�         
          call find_corner_link_point(m,nf,SF%ib,SF%jb,i1t,j1t,mt,nft)
          call find_corner_link_point(m,nf,SF%ie,SF%je,i2t,j2t,mt,nft)

  !  �Ǽ���������Ľǵ㣨��Χ����Ϣ
         SFt%ib=min(i1t,i2t) ; SFt%ie=max(i1t,i2t)
         SFt%jb=min(j1t,j2t) ; SFt%je=max(j1t,j2t)

  ! ��������Ⱦɫ
        do ja=i2,je
        do ia=i1,ie
          iat=F%point(ia,ja)%n1_link(1)
          jat=F%point(ia,ja)%n2_link(1)
          Ft%point(iat,jat)%color=Bt%color_now   ! ���ӵĵ�ҲȾɫ ��ͬʱ�������漰�������棬��Ⱦɫ��
        enddo
        enddo
 
 !  ��������ָ����
      if( mod(F%face_no,2) .eq. 1) then  !  l�����ǵ�2���±�仯�ķ��� (l*m=n)
           call find_corner_link_point(m,nf,SF%ib,SF%je,i2t,j2t,mt,nft)   ! (ib,je)���ӵĵ�
      else                               !  l�����ǵ�1���±�仯�ķ���
           call find_corner_link_point(m,nf,SF%ie,SF%jb,i2t,j2t,mt,nft)   ! (ie,jb)���ӵĵ�
      endif

      call comput_orient(Ft%face_no,i1t,j1t,i2t,j2t,orient )
         SF%orient=orient
         SFt%orient=orient
   else
! ������
         SF%block_link=0  
         SF%face_link=0  
         SF%subface_link=0        
         SF%orient=0
   endif
!-----------------------------------------------------------
  endif
   
  enddo
  enddo
 
   B%Num_subface=B%Color_now  ! �������Ŀ

 !------------------------------------------
  enddo
    print*, "zone = ", m ,  "Subface Number=", B%Num_Subface
 
  enddo
 
 end subroutine creat_subface

!--------------------------------------------------------------------------------------------
!---ͨ��Ⱦɫ�����ҵ��ӿ���±߽��(ie,je), ��(i1,i2)-(ie,je)Χ�ɵľ��������ڵĵ㣬ȫ�����ڵ�
   subroutine find_subface_boundary(m,nf,i1,i2,ie,je)
   use Global_Variables
   implicit none
   integer:: m,nf,i1,i2,ie,je,ia,ja
   TYPE (Face_Type), Pointer:: F
   TYPE (Point_Type), Pointer:: P

    F=> Block(m)%face(nf)
 !  Ѱ�Ҹ��������ο����ֹλ�� (ie,je)
 Loop1:  do ia=i1, F%n1
          P=> F%point(ia,i2)
          if(P%If_inner .eq. 0) then 
          ie=ia-1 
          exit Loop1
          endif
         enddo Loop1
         
 Loop2:  do ja=i2, F%n2
           do ia=i1,ie
            P=> F%point(ia,ja)
            if(P%If_inner .eq. 0) then 
            je=ja-1
            exit Loop2
            endif
          enddo
         enddo Loop2
    end subroutine find_subface_boundary

!----------------------------------------------------
! �ҵ��ǵ�(ib,ie)��Ӧ�����ӵ�(i1t,j1t) , ���ڸõ���ܲ�ֹһ�����ӣ������Ҫ�������ڵ����ӵ���ͬһ�顢ͬһ��ĵ�
      subroutine find_corner_link_point(m,nf,ib,jb,i1t,j1t,mt,nft)
          use Global_Variables
          implicit none
          integer:: m,nf,ib,jb,i1t,j1t,mt,nft,ns
          TYPE (Point_Type), Pointer:: P
          P=>Block(m)%face(nf)%point(ib,jb)   ! �ǵ�
  Loop3:  do ns=1,P%Num_link        ! ��ȫ�����ӵ������������ӿ�=mt, ������=nft�ĵ㣩
            if(P%block_link(ns) .eq. mt .and. P%face_link(ns) .eq. nft) then
             i1t=P%n1_link(ns); j1t=P%n2_link(ns)    ! ���ӵ�
            exit Loop3           
	    endif
	   enddo Loop3
      end subroutine find_corner_link_point


!---------------------------------------------------------------
!  �Ƚ������� m��,nf���ϵ�������(i1,j1) �� (i2,j2) �Ƿ������ͬ��������Ϣ
    subroutine compare(m,nf, i1,j1, i2,j2,flag1) 
!   subroutine compare(P,P1,flag1)
   use Global_Variables
   implicit none
   integer:: m,nf, i1,j1, i2,j2, flag1 , pb,pf, n
   TYPE (Face_Type), Pointer::F
   TYPE (Point_Type), Pointer:: P1,P2
    F=> Block(m)%face(nf)
    P1=> F%Point(i1,j1)
    P2 => F%point(i2,j2)
    if(P1%num_link .eq. 0)  then   ! P��������
       if(P2%num_link .eq. 0) then  
         flag1=1           !������������ӣ�ƥ��
       else if (i2 .eq. 1 .or. j2 .eq. 1 .or. i2 .eq. F%n1 .or. j2 .eq. F%n2) then
         flag1=1           ! ��ı߽�㼴ʹ������Ҳ���Ժ������ӵ�ƥ��
       else   
        flag1=0            ! �����ӵ��������ӵ㣬��ƥ��
       endif
    else     
         pb=P1%block_link(1) ; pf=P1%face_link(1)    ! (��һ����) ���ӵĿ�������
         flag1=0
Loop1:   do n=1,P2%num_link                           ! ������2�����ȫ��������Ϣ
         if(P2%block_link(n) .eq. Pb .and. P2%face_link(n) .eq. Pf) then   
         flag1=1                      ! ��š���ž�ƥ��
         exit Loop1
         endif
         enddo Loop1
     endif

   end subroutine compare
!---------------------------------------------------------------

! ����������ͬ�ĵ㣨���ӵ㣩
   subroutine search_link
   use Global_Variables
   implicit none
   integer:: m,nf,mt,nft,i1,i2,j1,j2,i1t,i2t,n,ns,mt1,nft1,mt_now,nft_now 
   integer:: zone,face,i,j,flag1,i0,j0,Link_max_point,ni1,nj1,ni2,nj2
   real*8:: m1,m2,mp1,mp2,tmp,d1

   real*8:: dist2
   TYPE (Block_Type), Pointer:: B,Bt
   TYPE (Face_Type), Pointer:: F,Ft
   TYPE (Point_Type), Pointer:: P,Pt


!-------------������� ���ζ༶������ (��Ƭ������) ��Ч��, ��ֵ����Ϊ�޸Ĳ���Nq�Ĳο�-------------------
   print*, "To Estimate the efficient of Multi-stage search program ..."
   m1=0; m2=0;mp1=0;mp2=0
   do m=1,Num_Block
     B => Block(m)
     do nf=1,6 
     F=> B%face(nf)
      do j1=1,F%nk2
 !     print*, F%n2b(j1),F%n2e(j1)
      do i1=1,F%nk1
 !---------------- ��������   
       do mt=1,Num_Block
        Bt=> Block(mt)
        do nft=1,6
         Ft=> Bt%face(nft)
         do j2=1,Ft%nk2
         do i2=1,Ft%nk1
         tmp=1.d0*(F%n2e(j1)-F%n2b(j1)+1)*(F%n1e(i1)-F%n1b(i1)+1)*(Ft%n2e(j2)-Ft%n2b(j2)+1)*(Ft%n1e(i2)-Ft%n1b(i2)+1)
         if(tmp .lt. 0) then
          print*, i1,j1,i2,j2
          print*, F%n2e(j1),F%n2b(j1), F%n1e(i1), F%n1b(i1), Ft%n2e(j2), Ft%n2b(j2), Ft%n1e(i2),F%n1b(i2)
         endif

        if(sqrt((F%xc(i1,j1)-Ft%xc(i2,j2))**2+(F%yc(i1,j1)-Ft%yc(i2,j2))**2+(F%zc(i1,j1)-Ft%zc(i2,j2))**2)  &
                 .gt. F%dc(i1,j1)+Ft%dc(i2,j2)+Dist_limit ) then  ! ���������̫Զ����������
         m1=m1+1
         mp1=mp1+1.d0*(F%n2e(j1)-F%n2b(j1)+1)*(F%n1e(i1)-F%n1b(i1)+1)*(Ft%n2e(j2)-Ft%n2b(j2)+1)*(Ft%n1e(i2)-Ft%n1b(i2)+1)
        else
         m2=m2+1
         mp2=mp2+1.d0*(F%n2e(j1)-F%n2b(j1)+1)*(F%n1e(i1)-F%n1b(i1)+1)*(Ft%n2e(j2)-Ft%n2b(j2)+1)*(Ft%n1e(i2)-Ft%n1b(i2)+1)
       endif
      enddo
      enddo
      enddo
      enddo
      enddo
      enddo
      enddo
      enddo
 
      print*, "The speed-up by using multi-stage search technique is:",    mp1/mp2
      print*, "If the speed-up is low, you can modify the parameter 'Nq' to increase it" 


!---Search the face point----------------------------------------------------------

  Link_max_point=0   ! ������ӵ��������
   print*, "Search the Edge Points ......"
 !------������--------             
   do m=1,Num_Block
    print*, "----------------------------- :  Zone ", m 
     B => Block(m)
     do nf=1,6 
     print*, "face ", nf
     F=> B%face(nf)
     do nj1=1,F%nk2
     do ni1=1,F%nk1
       do i2= F%n2b(nj1),F%n2e(nj1)
       do i1= F%n1b(ni1),F%n1e(ni1)
        P=> F%point(i1,i2)
        P%Search_flag=1     ! ��ʾ�ѱ�������
!--------------------------------------------------------------    
!       ��������       
       do mt=1,Num_Block
        Bt=> Block(mt)
        do nft=1,6
         Ft=> Bt%face(nft)
         do nj2=1,Ft%nk2
         do ni2=1,Ft%nk1
          d1=sqrt((F%xc(ni1,nj1)-Ft%xc(ni2,nj2))**2+(F%yc(ni1,nj1)-Ft%yc(ni2,nj2))**2+(F%zc(ni1,nj1)-Ft%zc(ni2,nj2))**2)
          if(d1 .gt. F%dc(ni1,nj1)+Ft%dc(ni2,nj2)+Dist_limit )  cycle  ! ���������̫Զ����������
 !---------------------------------------
          do i2t= Ft%n2b(nj2),Ft%n2e(nj2)
          do i1t= Ft%n1b(ni2),Ft%n1e(ni2)
            Pt=>Ft%point(i1t,i2t)
           if(Pt%Search_flag .eq. 0 ) then       ! ��δ��������
            dist2=(P%x-Pt%x)**2+(P%y-Pt%y)**2+(P%z-Pt%z)**2

           if(dist2 .lt. Dist_limit**2  ) then       ! �ҵ�������ͬ�ĵ�        
!        һ�Զ�Ӧ��         
           P%num_link=P%num_link+1
           P%block_link(P%num_link)=mt
           P%face_link(P%num_link)=nft
           P%n1_link(P%num_link)=i1t
           P%n2_link(P%num_link)=i2t
           Pt%num_link=Pt%num_link+1
           Pt%block_link(Pt%num_link)=m
           Pt%face_link(Pt%num_link)=nf
           Pt%n1_link(Pt%num_link)=i1
           Pt%n2_link(Pt%num_link)=i2

           if(P%num_link .gt. Link_max_point) Link_max_point=P%num_link
           if(Pt%num_link .gt. Link_max_point) Link_max_point=Pt%num_link
           endif
          endif
        enddo
        enddo
        enddo
        enddo
        enddo
        enddo 
     enddo
     enddo
     enddo
     enddo
     enddo
     enddo

  print*, "Search Edge OK ..."
  print*, "Max Link is ", Link_max_point



  print*, "Search OK ..."

!-----------------------------------
!    print*, "Write the file link.dat"
!    open(99,file="link.dat")

!    do m=1,Num_Block
!      B => Block(m)
!    do nf=1,6 
!      F=> B%face(nf)
!     write(99,*) "Zone= ", m, " Face= ", nf , "-----------------------------------------"
!     do j=1, F%n2
!     do i=1, F%n1
!      P=> F%point(i,j)
!     write(99,*) i,j,P%Num_link
!     do n=1,P%Num_link
!     write(99,*) P%block_link(n),P%face_link(n),P%n1_link(n),P%n2_link(n)
!     enddo
!     enddo
!     enddo
!    enddo
!    enddo
!   close(99)


 
  end subroutine search_link
        
  
!-----------------------------------------------------------------
! ��ȡ������Ϣ���洢��������
! ������С������Dist_min (����С��0.1��Dis_min����������Ϊ��ͬһ���㣩 
  
  subroutine read_coordinate
   use Global_Variables
   implicit none
   integer,allocatable,dimension(:):: NI,NJ,NK
   real*8,allocatable,dimension(:,:,:):: x,y,z
   integer:: nx,ny,nz,i,j,k,m,nf,ib(6),jb(6),kb(6),ie(6),je(6),ke(6)
   integer:: i1,i2,nf1,ni1,nj1,n1,nk1,nk2
    TYPE (Block_Type), Pointer:: B
   TYPE (Face_Type), Pointer:: F
   TYPE (SubFace_Type), Pointer:: SF
   TYPE (Point_Type), Pointer:: P

   real*8:: di,dj,dk,d1,tmp
!-----------------------------------------------------------------------  
   Dist_min=1000.d0  ! ��ֵ
  
 !  print*, "==================================================================="
 !  print*, "Please input the distance threshold Dist_limit"
 !  print*, "two points with distance < Dist_limit will be considered as the same point"
 !  print*, "if Dist_limit<=0, this code will automatically set it"
 !  print*, "????? Input Dist_limit ?????"
 !  read(*,*) Dist_limit
 
 
   print*, "Is Mesh3d.dat formatted file ?  1 for formatted, 0 for unformatted"
   read(*,*) Form_Mesh   
   if(Form_Mesh .eq. 1) then
    open(99,file="Mesh3d.dat")
    read(99,*) Num_Block
   else
    open(99,file="Mesh3d.dat",form="unformatted")
    read(99) Num_Block         ! �ܿ���
   endif

  
    allocate(Block(Num_Block))               
    allocate(NI(Num_Block),NJ(Num_Block),NK(Num_Block) )   ! ÿ��Ĵ�С
   if(Form_Mesh .eq. 1) then
    read(99,*) (NI(k), NJ(k), NK(k), k=1,Num_Block)
   else
    read(99) (NI(k), NJ(k), NK(k), k=1,Num_Block)
   endif
! ��ȡÿ�鼸����Ϣ, ��¼���ϵ���Ϣ----------------------------------------   
    do m=1,Num_Block
     B => Block(m)
     B%Block_no=m
     B%nx=NI(m); B%ny=NJ(m) ; B%nz=NK(m)   ! nx,ny,nz ÿ��Ĵ�С
     nx=B%nx ; ny= B%ny ; nz=B%nz
! ----------  ������ -----------------------------------------------
    allocate(x(nx,ny,nz), y(nx,ny,nz), z(nx,ny,nz))  ! �������
   if(Form_Mesh .eq. 1) then
    read(99,*) (((x(i,j,k),i=1,nx),j=1,ny),k=1,nz) , &
                (((y(i,j,k),i=1,nx),j=1,ny),k=1,nz) , &
                (((z(i,j,k),i=1,nx),j=1,ny),k=1,nz)
   else  
    read(99) (((x(i,j,k),i=1,nx),j=1,ny),k=1,nz) , &
                (((y(i,j,k),i=1,nx),j=1,ny),k=1,nz) , &
                (((z(i,j,k),i=1,nx),j=1,ny),k=1,nz)
   endif

!------------
    do k=1,nz-1
    do j=1,ny-1
    do i=1,nx-1
      di=sqrt( (x(i+1,j,k)-x(i,j,k))**2+ (y(i+1,j,k)-y(i,j,k))**2 + (z(i+1,j,k)-z(i,j,k))**2 )
      dj=sqrt( (x(i,j+1,k)-x(i,j,k))**2+ (y(i,j+1,k)-y(i,j,k))**2 + (z(i,j+1,k)-z(i,j,k))**2 )
      dk=sqrt( (x(i,j,k+1)-x(i,j,k))**2+ (y(i,j,k+1)-y(i,j,k))**2 + (z(i,j,k+1)-z(i,j,k))**2 )
     Dist_min=min(Dist_min,di,dj,dk)
    enddo
    enddo
    enddo
!-------------

!  ��¼6�������Ϣ 
! face 1  (i-)     
     F=> B%face(1)
     F%face_no=1 ; F%n1= ny ; F%n2= nz           
     allocate(F%point(F%n1,F%n2))
     do i2=1,F%n2
     do i1=1,F%n1
       F%point(i1,i2)%x=x(1,i1,i2);   F%point(i1,i2)%y=y(1,i1,i2);  F%point(i1,i2)%z=z(1,i1,i2)
     enddo
     enddo

! face 2  (j-)     
     F=> B%face(2)
     F%face_no=2 ; F%n1= nx ; F%n2= nz           
     allocate(F%point(F%n1,F%n2))
     do i2=1,F%n2
     do i1=1,F%n1
       F%point(i1,i2)%x=x(i1,1,i2);   F%point(i1,i2)%y=y(i1,1,i2);  F%point(i1,i2)%z=z(i1,1,i2)
     enddo
     enddo

! face 3  (k-)     
     F=> B%face(3)
     F%face_no=3 ; F%n1= nx ; F%n2= ny           
     allocate(F%point(F%n1,F%n2))
     do i2=1,F%n2
     do i1=1,F%n1
       F%point(i1,i2)%x=x(i1,i2,1);   F%point(i1,i2)%y=y(i1,i2,1);  F%point(i1,i2)%z=z(i1,i2,1)
     enddo
     enddo

! face 4  (i+)     
     F=> B%face(4)
     F%face_no=4 ; F%n1= ny ; F%n2= nz           
     allocate(F%point(F%n1,F%n2))
     do i2=1,F%n2
     do i1=1,F%n1
       F%point(i1,i2)%x=x(nx,i1,i2);   F%point(i1,i2)%y=y(nx,i1,i2);  F%point(i1,i2)%z=z(nx,i1,i2)
     enddo
     enddo

! face 5  (j+)     
     F=> B%face(5)
     F%face_no=5 ; F%n1= nx ; F%n2= nz           
     allocate(F%point(F%n1,F%n2))
     do i2=1,F%n2
     do i1=1,F%n1
       F%point(i1,i2)%x=x(i1,ny,i2);   F%point(i1,i2)%y=y(i1,ny,i2);  F%point(i1,i2)%z=z(i1,ny,i2)
     enddo
     enddo

! face 6  (k+)     
     F=> B%face(6)
     F%face_no=6 ; F%n1= nx ; F%n2= ny           
     allocate(F%point(F%n1,F%n2))
     do i2=1,F%n2
     do i1=1,F%n1
       F%point(i1,i2)%x=x(i1,i2,nz);   F%point(i1,i2)%y=y(i1,i2,nz);  F%point(i1,i2)%z=z(i1,i2,nz)
     enddo
     enddo
!----------------------------------

    deallocate(x,y,z) 

!  ��ʼ������Ϣ    
   do nf=1,6
    F=> B%face(nf)
!   ��ʼ������Ϣ   
    do i2=1,F%n2
    do i1=1,F%n1
    F%point(i1,i2)%Search_flag=0    ! ����ʱʹ�õ���ʱ���� 
    F%Point(i1,i2)%color=0
    F%point(i1,i2)%If_inner=0       ! "�����ڵ�" ��־
    F%point(i1,i2)%num_link=0       ! ���ӵ�����
    F%point(i1,i2)% block_link(:)=0    ! 
    F%point(i1,i2)% face_link(:)=0
    F%point(i1,i2)% n1_link(:)=0
    F%point(i1,i2)% n2_link(:)=0
    enddo
    enddo
   enddo

    ! ��ʼ��������Ϣ 
     B%Num_Subface=0  
     B%color_now=0

     do k=1, Max_Subface
     SF=> B%subface(k)
     SF%subface_no=0 ; SF%face_no=0; SF%ib=0 ; SF%jb=0 ; SF%ie=0 ; SF%je=0
     SF%subface_link=0; SF%block_link=0 ; SF%face_link=0 ; SF%orient=0
     enddo
  !--------------------------------------------------------------
  ! ������Ԫ�� ��¼ÿ����Ԫ�����ĵ㼰�뾶
     do nf=1,6 
      F=> B%face(nf)
      nk1=int((F%n1-1)/Nq)+1    !��Ԫ����Ŀ ��nk1*nk2�飩
      nk2=int((F%n2-1)/Nq)+1
      F%nk1=nk1  
      F%nk2=nk2
      allocate(F%n1b(nk1),F%n1e(nk1),F%n2b(nk2),F%n2e(nk2))
      allocate(F%xc(nk1,nk2),F%yc(nk1,nk2),F%zc(nk1,nk2),F%dc(nk1,nk2))

! �Ѵ��±��1��F%n1�ĵ�ָ�����ɶΣ�ÿ��Nq����; ����������������һ����Ŀ��Щ
!  F%n1b(k) ��F%n1e(k) �ǵ�k�ε���ֹ�±�    
      do k=1,nk1
        F%n1b(k)=(k-1)*Nq+1        
        if(k .ne. nk1) then
          F%n1e(k)=k*Nq
        else
          F%n1e(k)=F%n1
        endif   
      enddo

! �Ѵ��±��1��F%n2�ĵ�ָ�����ɶΣ�ÿ��Nq����; ����������������һ����Ŀ��Щ
      do k=1,nk2
        F%n2b(k)=(k-1)*Nq+1        
        if(k .ne. nk2) then
          F%n2e(k)=k*Nq
        else
          F%n2e(k)=F%n2
        endif   
      enddo


      do nj1=1,nk2
      do ni1=1,nk1

      F%xc(ni1,nj1)=0.d0; F%yc(ni1,nj1)=0.d0 ; F%dc(ni1,nj1)=0.d0
      do j=F%n2b(nj1), F%n2e(nj1)
      do i=F%n1b(ni1), F%n1e(ni1)
       P=> F%point(i,j)
       F%xc(ni1,nj1)=F%xc(ni1,nj1)+P%x
       F%yc(ni1,nj1)=F%yc(ni1,nj1)+P%y
       F%zc(ni1,nj1)=F%zc(ni1,nj1)+P%z
      enddo
      enddo
      tmp=(F%n2e(nj1)-F%n2b(nj1)+1)*(F%n1e(ni1)-F%n1b(ni1)+1)
      F%xc(ni1,nj1)=F%xc(ni1,nj1)/tmp
      F%yc(ni1,nj1)=F%yc(ni1,nj1)/tmp
      F%zc(ni1,nj1)=F%zc(ni1,nj1)/tmp

      do j=F%n2b(nj1), F%n2e(nj1)
      do i=F%n1b(ni1), F%n1e(ni1)
       P=> F%point(i,j)
       d1=sqrt((P%x-F%xc(ni1,nj1))**2+(P%y-F%yc(ni1,nj1))**2 +(P%z-F%zc(ni1,nj1))**2 )
       if(d1 .gt. F%dc(ni1,nj1)) F%dc(ni1,nj1)=d1
      enddo
      enddo
 !     print*, F%xc,F%yc,F%zc,F%dc
    enddo
    enddo

   enddo      ! face

!---------------------------------------------------------------------------------------   
   enddo      ! block
   close(99)
   print*, "read Mesh3d OK ..."
   print*, "Minima Mesh Space is ", Dist_min
    
 !   if(Dist_limit .le. 0) Dist_limit=0.5d0*Dist_min  ! ���ü���ż� ��0.5����С�����ࣩ������С�ڸ��ż��������㽫��Ϊ��ͬһ����
    Dist_limit=0.5d0*Dist_min  ! ���ü���ż� ��0.5����С�����ࣩ������С�ڸ��ż��������㽫��Ϊ��ͬһ����
    print*, "The distance threshold is ", Dist_limit
   end subroutine read_coordinate

!---------------------------------------------------------
! ��������ָ����
!  �����l�������ӵ�Ŀ�������(i1,j1)ָ��(i2,j2)��һ�������߶�
    subroutine comput_orient(fno,i1,j1,i2,j2,orient )
    implicit none
    integer:: fno,i1,j1,i2,j2,orient,p1,p2
! �ж� ��(i1,j1) ָ�� (i2,j2) ʸ���ķ��� ��1,-1, 2, -2 ��ʾ i, -i, j, -j ����     
    if(i1 .eq. i2 ) then
      if(j2 .gt. j1) then
        p1=2            ! j����
      else
        p1=-2           ! -j����
      endif
    else
      if(i2 .gt. i1) then
        p1=1
      else
        p1=-1
      endif
    endif
! ���ݣ������棩����ţ�ָ�򣩣���P����(P1�� i, -i, j, -j������ ת������ l, -l, m, -m ���� ���� P2��
   if( mod(fno,2) .eq. 0) then
     p2=p1
   else
     if(p1 .eq. 1)  p2=2
     if(p1 .eq. -1) p2=-2
     if(p1 .eq. 2)  p2=1
     if(p1 .eq. -2) p2=-1
   endif
!  ����P2���趨ָ����orient    
    if(p2 .eq. 1) orient=1
    if(p2 .eq. 2) orient=2
    if(p2 .eq. -1) orient=3
    if(p2 .eq. -2) orient=4
  
   end subroutine comput_orient

! -------дbc_in�ļ�----------------------------------------  
  subroutine write_bcin
   use Global_Variables
   implicit none
   integer:: m,ns,ist,jst,kst,iend,jend,kend,face,block_link
   TYPE (Block_Type), Pointer:: B   ! ��ָ��
   TYPE (Face_Type), Pointer:: F    ! ��ָ��
   TYPE (Subface_Type), Pointer:: SF   ! �ӿ�ָ��
   open(109,file="bc.in")
   write(109,*) " BC file , By Li Xinliang"
   write(109,*) "# Blocks"
   write(109,*) Num_Block
   do m=1,Num_Block
   B => Block(m)
    write(109,*) "Block  ", m
    write(109,*) "Subfaces"
    write(109,*) B%Num_subface, 1, 1, -1
     write(109,*) " f_no, face, istart,iend, jstart, jend, kstart, kend, neighb, subface ori theta"
     do ns=1,B%Num_subface
     SF=>B%subface(ns)
     face=SF%face_no
     call convert_ijk(ist,jst,kst,SF%ib,SF%jb,face,B%nx,B%ny,B%nz) 
     call convert_ijk(iend,jend,kend,SF%ie,SF%je,face,B%nx,B%ny,B%nz) 
     if(SF%block_link .eq. 0) then
       Block_link=-1
     else
       Block_link=SF%block_link
     endif

     write(109,"(11I7,E16.5)") ns,face,ist,iend,jst,jend,kst,kend, block_link, SF%subface_link, SF%orient , 0.d0
     enddo
    enddo
   close(109)
   end subroutine write_bcin


!-----------------------------------------------------------------
! �����ϵľֲ�����(i1,i2)ת��Ϊ���ϵ�ȫ������(i,j,k)  
  subroutine convert_ijk(i,j,k,i1,i2,face_no,nx,ny,nz)
  implicit none
  integer:: i,j,k,i1,i2,face_no,nx,ny,nz
   if(face_no .eq. 1) then
     i=1; j=i1; k=i2
   else if (face_no .eq. 2) then
     i=i1; j=1; k=i2
   else if (face_no .eq. 3) then
     i=i1; j=i2; k=1
   else if (face_no .eq. 4) then
     i=nx; j=i1; k=i2
   else if (face_no .eq. 5) then
     i=i1; j=ny ; k=i2
   else if (face_no .eq. 6) then
     i=i1; j=i2; k=nz
   endif
   end subroutine convert_ijk

!-----------------------------------------------------
! �����̱ڡ�Զ�����Գ���
   subroutine search_wall_and_farfield
   use Global_Variables
   implicit none
   integer:: i,j,k,m,ns,nf
   real*8:: xc,yc,zc,tmp,xrms,yrms,zrms
   TYPE (Block_Type), Pointer:: B   ! ��ָ��
   TYPE (Face_Type), Pointer:: F    ! ��ָ��
   TYPE (Subface_Type), Pointer:: SF   ! �ӿ�ָ��
 !---------------------
   open(103,file="surface.dat")
   write(103,*) "variables=x,y,z,bc" 
   do m=1,Num_Block
     B => Block(m)
   do ns=1,B%Num_subface
     SF=>B%subface(ns)
     nf=SF%face_no
     F=>B%face(nf)
    if(SF%block_link .eq. 0 ) then
!  ����������ƽ��(����)����
     xc=0.d0; yc=0.d0; zc=0.d0
     xrms=0.d0;yrms=0.d0;zrms=0.d0
     do j=SF%jb,SF%je
     do i=SF%ib,SF%ie
       xc=xc+F%point(i,j)%x
       yc=yc+F%point(i,j)%y
       zc=zc+F%point(i,j)%z
      enddo
      enddo
       tmp=1.d0*(SF%ie-SF%ib+1)*(SF%je-SF%jb+1)
       xc=xc/tmp; yc=yc/tmp ; zc=zc/tmp

!  ����������������ĵ��λ�ò�  
       do j=SF%jb,SF%je
       do i=SF%ib,SF%ie
        xrms=xrms+(F%point(i,j)%x-xc)**2
        yrms=yrms+(F%point(i,j)%y-yc)**2
        zrms=zrms+(F%point(i,j)%z-zc)**2
       enddo
       enddo
        xrms=sqrt(xrms/tmp) ; yrms=sqrt(yrms/tmp) ; zrms=sqrt(zrms/tmp)

!       print*, "------------------"
!       print*, "Block =", B%Block_no, "subface=",SF%subface_no, "x,y,z=", xc, yc,zc
!       print*, "xrms,yrms,zrms=",xrms,yrms,zrms
!        We assume "Y=0" is the symmetry plane !!!!  if Y=0 is not the symmetry plane, please modify the code !
!    �����ƽ�棬��Ӧ����Զ����Գ��� ��ֻ�����ڷ��μ�����      
      if(xrms .lt. Dist_limit .or. yrms .lt. Dist_limit .or. zrms .lt. Dist_limit ) then
         if(abs(yc) .lt. Dist_limit) then  
          SF%block_link=BC_Symmetry        ! �Գ���
         else 
           SF%block_link=BC_Farfield       ! Զ��
         endif
      else 
        SF%block_link=BC_Wall
      endif
!------write to surface file-------------------------
      write(103,*) "zone i=", SF%ie-SF%ib+1, " j= ", SF%je-SF%jb+1
      do j=SF%jb,SF%je
      do i=SF%ib,SF%ie
       write(103, "(4f20.10)") F%point(i,j)%x, F%point(i,j)%y,F%point(i,j)%z, SF%block_link*1.d0
      enddo
      enddo
     endif
     enddo
     enddo
 
   close(103)
   end  


!==========================================================================
! In2inp, Transform BXCFD .in file to Gridgen .inp file  
! ������������Ϣ����BXCFD�� .in��ʽ ת��ΪGridgen .inp��ʽ
! Copyright by Li Xinliang, lixl@imech.ac.cn
! Ver 1.0, 2012-7-11

!------Types ��������Ϳ��������ݽṹ ----------------------------------------------------------------------
! �棺 ������ ��š�ά����������Ϣ
! �飺 ������ ��š�ά������
!-----------------------------------------------------------------------------------------------------------
!---------------------------------------------------------------------
  module Def_block
  implicit none
  Integer:: NB    ! �������

! �߽���Ϣ, Gridgen .inp��ʽ
   TYPE BC_MSG_TYPE             ! �߽�������Ϣ 
     integer:: ist, iend, jst, jend, kst, kend, neighb, subface, orient   ! BXCFD .in format
     integer:: ib,ie,jb,je,kb,ke,bc,face,f_no                      ! �߽��������棩�Ķ��壬 .inp format
     integer:: ib1,ie1,jb1,je1,kb1,ke1,nb1,face1,f_no1             ! ��������
   END TYPE BC_MSG_TYPE
  
   TYPE Block_TYPE           !  ��
     integer:: nx,ny,nz
	 integer::  subface  !  ������Ŀ
     TYPE (BC_MSG_TYPE),dimension(:),pointer:: bc_msg   ! ���� �������ڿ飩
   End TYPE Block_TYPE  
  
   TYPE (Block_TYPE), save,dimension(:),allocatable,target:: Block
  
  end module Def_block

!============================================================================
  subroutine Inp2In (Form_Mesh)
  use Def_block
  implicit none
  integer:: Form_Mesh
  print*, " Transform  from .in file to .inp file ......"
!----------------------------
  call read_bcin(Form_Mesh)
  call trans_in_inp
  call write_inp
  end

  
!--------------------------------------------------------------------

  
 !----Mesh control message (bc2d.in)------------------------------------------
  subroutine read_bcin (Ia) 
   use Def_block
   implicit none
   integer::m,ksub,Ia,NB1
   Type (Block_TYPE),pointer:: B
   TYPE (BC_MSG_TYPE),pointer:: Bc

   print*, "read bc.in ......"
   open(88,file="bc.in")
   read(88,*)
   read(88,*)
   read(88,*) NB
   allocate (Block(NB))

   do m=1,NB
     B => Block(m)
     read(88,*)
     read(88,*) 
     read(88,*) B%subface   !number of the subface in the Block m
     read(88,*)
     allocate(B%bc_msg(B%subface))
     do ksub=1, B%subface
       Bc => B%bc_msg(ksub)
       read(88,*)  Bc%f_no, Bc%face, Bc%ist, Bc%iend, Bc%jst, Bc%jend,  Bc%kst, Bc%kend, Bc%neighb, Bc%subface, Bc%orient
     enddo
   enddo
   close(88)
   print*, "read bc3d.in OK"
   
 !  print*, "read Mesh3d.dat for nx,ny,nz"
 !  print*, "please input the format of Mesh3d.dat, 1 formatted, 2 unformatted, 0 not read"
 !  read(*,*) Ia
   
   if(Ia .eq. 1 ) then
     open(100,file="Mesh3d.dat")
     read(100,*) NB1
     if(NB1 .ne. NB) then
	  print*, "error ! NB in Mesh3d.dat is not the same as that in bc3d.in "
	  stop
	 endif 
	  read(100,*) ((Block(m)%nx,Block(m)%ny,Block(m)%nz),m=1,NB)
   
   else if (Ia .eq. 0 ) then
     open(100,file="Mesh3d.dat",form="unformatted")
     read(100) NB1
     if(NB1 .ne. NB) then
	  print*, "error ! NB in Mesh3d.dat is not the same as that in bc3d.in "
	  stop
	 endif 
	  read(100) ((Block(m)%nx,Block(m)%ny,Block(m)%nz),m=1,NB)
   else
	 do m=1,NB
	  Block(m)%nx=0; Block(m)%ny=0; Block(m)%nz=0
	 enddo
   endif


  end  subroutine read_bcin
!-------------------------------------------------------------------------------------------------------------
!------------------------------------------------------------------------------------------------------------- 
! �� .in�ļ�ת��Ϊ .inp�ļ�  
  subroutine trans_in_inp
   use Def_block
   implicit none
   integer,parameter:: BC_Wall_in=-10, BC_Farfield_in=-20, BC_Periodic_in=-30,BC_Symmetry_in=-40,BC_Outlet_in=-22   ! .in ���ڱ߽������Ķ���
   integer,parameter:: BC_Wall=2, BC_Symmetry=3, BC_Farfield=4,BC_Outlet=401, BC_Periodic=501     ! ��Griggen .inp�ļ��Ķ����������������ע��
   integer:: m,ksub
   integer:: Lp(3),Ls(3),tmp  
   Type (Block_TYPE),pointer:: B,B1
   TYPE (BC_MSG_TYPE),pointer:: Bc,Bc1
    do m=1,NB
     B => Block(m)
      do ksub=1, B%subface
       Bc => B%bc_msg(ksub)
        if(Bc%neighb .lt. 0) then    ! ����߽�
          Bc%ib=Bc%ist ; Bc%ie=Bc%iend ;  Bc%jb=Bc%jst ; Bc%je=Bc%jend ;  Bc%kb=Bc%kst ; Bc%ke=Bc%kend
		
		   if(Bc%neighb .eq. BC_Wall_in ) then 
		    Bc%bc=BC_Wall
		   else if (Bc%neighb .eq. BC_Farfield_in ) then 
		    Bc%bc=BC_Farfield
		   else if (Bc%neighb .eq. BC_Periodic_in ) then 
		    Bc%bc=BC_Periodic
		   else if (Bc%neighb .eq. BC_Symmetry_in ) then 
		    Bc%bc=BC_Symmetry
		   else if (Bc%neighb .eq. BC_Outlet_in ) then 
		    Bc%bc=BC_Outlet
 		   else
		    print*, "The boundary condition is not supported!", NB, ksub
	       endif 
		else
		  Bc%bc=-1
          B1=>Block(Bc%neighb)
		  Bc1=>B1%bc_msg(Bc%subface)
		  Bc%nb1=Bc%neighb
		  Bc%face1=Bc1%face
		  Bc%f_no1=Bc1%f_no

          Bc%ib=Bc%ist ; Bc%ie=Bc%iend ;  Bc%jb=Bc%jst ; Bc%je=Bc%jend ;  Bc%kb=Bc%kst ; Bc%ke=Bc%kend
		  if(Bc%kst .eq. Bc% kend ) then
		    Bc%jb=-Bc%jst ; Bc%je=-Bc%jend
		  else
		    Bc%kb=-Bc%kst ; Bc%ke=-Bc%kend
          endif
          call get_orient(Bc%face,Bc1%face,Bc%orient,Lp,Ls)  ! Lp(k)==-1 ��������, Ls(k)==-1 �ı���� 
		   
		   Bc%ib1= Ls(1)*Bc1%ist ;  Bc%ie1=Ls(1)*Bc1%iend
		   if(Lp(1) .eq. -1) then
		    tmp=Bc%ib1; Bc%ib1=Bc%ie1; Bc%ie1=tmp
           endif
		   Bc%jb1= Ls(2)*Bc1%jst ;  Bc%je1=Ls(2)*Bc1%jend
		   if(Lp(2) .eq. -1) then
		    tmp=Bc%jb1; Bc%jb1=Bc%je1; Bc%je1=tmp
           endif
		   Bc%kb1= Ls(3)*Bc1%kst ;  Bc%ke1=Ls(3)*Bc1%kend
		   if(Lp(3) .eq. -1) then
		    tmp=Bc%kb1; Bc%kb1=Bc%ke1; Bc%ke1=tmp
           endif
		  
		endif
      enddo 
    enddo
 end  subroutine trans_in_inp

!------------------------------------------------------------------------------------------  
   subroutine write_inp
   use Def_block
   implicit none
   integer:: m,ksub
   Type (Block_TYPE),pointer:: B
   TYPE (BC_MSG_TYPE),pointer:: Bc
   open(99,file="bc.inp")
    write(99,*) 1
	write(99,*) NB
	do m=1,NB
     B => Block(m)
     write(99,*) B%nx, B%ny, B%nz
	 write(99,*) "Block ", m 
	 write(99,*) B%subface 
	  do ksub=1, B%subface
       Bc => B%bc_msg(ksub)
	   write(99,"(7I6)") Bc%ib,Bc%ie,Bc%jb,Bc%je,Bc%kb,Bc%ke,Bc%bc
       if(Bc%bc .eq. -1) then
	   write(99,"(7I6)") Bc%ib1,Bc%ie1,Bc%jb1,Bc%je1,Bc%kb1,Bc%ke1,Bc%nb1
       endif
	  enddo
    enddo
   close(99)
 end
  


!  ����orient��ֵ��ȷ��.inp�ļ������Ӵ��� 
!  �� OpenCFD-EC�����ֲ�  
!      subroutine get_ijk_orient(i2,j2,i1,j1,ibegin,iend,jbegin,jend,orient,face1,face2)  ! bug bug but !!! (face1, face2)
      subroutine get_orient(face1,face2,orient,Lp,Ls)
      implicit none 
      integer:: l1,m1,l2,m2,tmp,face1,face2,orient,Lp(3),Ls(3),k0,k1,k2
 
 !           
          if(mod(face1,2) .eq. 1) then    ! i-, j- or k- ��
            l1=2 ; m1= 1                  ! l�ǵ�2���±꣬ m�ǵ�1���±�
          else                            ! i+, j+ or k+ ��
            l1=1 ; m1= 2                  ! l�ǵ�1���±꣬ m�ǵ�2���±�
          endif
         
          if(orient .eq. 1) then           ! ����orient�� ��ת���ӷ��� �����������ֲᡷ��
            l2=l1 ; m2=-m1
          else if (orient .eq. 2) then
            l2=m1 ; m2=l1
          else if (orient .eq. 3) then
            l2=-l1; m2=m1
          else 
            l2=-m1; m2=-l1
          endif
          
          if(mod(face2,2) .eq. 1) then            ! ���� i-, j- or k- �� 
            tmp=l2; l2=m2; m2=tmp                  ! swap l2 and m2
          endif

! .inp�ļ����������� Ϊ����<-->���� ��<-->���� 
! Lp(k)==-1 �������� (ib,ie)--> (ie,ib)
! Ls(k)==-1 �ı���� (ib,ie) ---> (-ib, -ie)
          
		  if(face2 .eq. 1 .or. face2 .eq. 4) then  ! i- or i+
		    k0=1; k1=2 ; k2=3                  ! k0 ���棻 k1 -- l;  k2--m
		  else  if(face2 .eq. 2 .or. face2 .eq. 5) then  ! j- or j+
            k0=2; k1=1; k2=3
          else
		    k0=3; k1=1; k2=2
		  endif
		   
		   Lp(k0)=1 ; Ls(k0)=1            ! ���轻�����򣬸ı���� 
		   Lp(k1)=sign(1,l2)
           if(abs(l2) .eq. 1) then
		     Ls(k1)=1
		   else
             Ls(k1)=-1
		   endif

		   Lp(k2)=sign(1,m2)
           if(abs(m2) .eq. 1) then
		     Ls(k2)=1
		   else
             Ls(k2)=-1
		   endif
       end subroutine get_orient
    




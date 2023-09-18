!----Boundary message (bc3d.inp, Gridgen general format)----------------------------------------------------------
! Cut large Block into pieces
! Ver 1.1, 2013-9-6:  Cut Mesh and bc3d.inp
 
  module const_var1
  implicit none
 
!    integer,parameter:: PRE_SC=4            ! Single precision
     integer,parameter:: PRE_SC=8           ! Double Precision
     integer,parameter::  BC_Wall=2, BC_Symmetry=3,   BC_Inflow=5, BC_Outflow=6 , BC_NonReflection=9, BC_Dilchlet=1 
     integer,parameter::  BC_WallH=20        ! ����߽� (ʹ��Ghost Cell)
     integer,parameter::  BC_inZ=-1, BC_In=-2,  BC_Periodic=-3       ! -1Ӳ�������ӣ� -2��������� ; -3���ڱ߽� �������ӣ�
     integer,parameter:: Maxsub=100 ,NPMAX=100  ! ÿ������������
  end module

  module  Type_def1
    use const_var1
	implicit none

    TYPE BC_MSG_TYPE              ! �߽�������Ϣ
     integer:: ib,ie,jb,je,kb,ke,bc,face,f_no                      ! �߽��������棩�Ķ��壬 .inp format
     integer:: ib1,ie1,jb1,je1,kb1,ke1,nb1,face1,f_no1             ! ��������
	 integer:: L1,L2,L3                                            ! ����ţ�����˳��������
     integer:: b1,e1,b2,e2,b1t,e1t,b2t,e2t           ! ������ά������
   END TYPE BC_MSG_TYPE


    TYPE Block_TYPE1                          ! ���ݽṹ��������Bc_msg 
	 integer::  nx,ny,nz                      ! ������nx,ny,nz
	 integer::  subface                       ! ������
 	 integer:: Block_No
     real(PRE_SC),pointer,dimension(:,:,:,:):: xyz   ! x, y, z
	 TYPE(BC_MSG_TYPE),pointer,dimension(:)::bc_msg     ! �߽�������Ϣ 
     integer:: Pi,Pj,Pk                                 ! (ԭ��)��������ķָ��� ; (�¿�)��������Ŀ����
     integer:: ib,jb,kb                                 ! �ӿ����ʼ�±�
	 integer:: nb_ori       ! ԭ���
	 integer:: nbk0      ! �ӿ����ʼ���
	END TYPE Block_TYPE1   
    
	TYPE bcnp_type              ! �ӿ�
     integer:: idx,blk,idxt,blkt,nn  ! �׵�ַ���ӿ�� ��Դ�����ӣ��� ��Ŀ     
    END TYPE 
   
   End module  Type_def1


    module global_var1
    use Type_def1
    TYPE(Block_TYPE1),Pointer,dimension(:):: Block,Block_new
    integer:: Mesh_form,NB,NBnew
    integer,allocatable,dimension(:):: PI,PJ,PK
    type(bcnp_type),target:: bcn(NPMAX,2)
	end module global_var1

!---------------------------------


   program cut_block
    use global_var1
    implicit none
!----Cut Mesh --------------------
    call read_cutfile
	call cut_mesh
    call write_new_mesh
!---cut bc3d.inp -----------------
     call convert_inp_inc  
     call cut_inp   ! �����ӿ�� inp��Ϣ
     call set_new_inner  ! �趨�µ������߽�
	 call search_fno1(2)  ! ���� fno1��Ϣ
	 call write_inp_new  ! д���µı߽���Ϣ	 


   end


!----------------------------------------------------------
   subroutine cut_inp 
     use global_var1
     implicit none
	 integer:: m,ks
     Type (Block_TYPE1),pointer:: B,B1
     TYPE (BC_MSG_TYPE),pointer:: Bc,Bc1
 	 
     call creat_new_bcmsg
!---------------------------
     do m=1,NB
	  B=>Block(m)
	  do ks=1,B%subface
      Bc=>B%bc_msg(ks)
       if(Bc%bc>0) then  
        call search_1d_bd(m,ks) ! ����߽�
       else
	    call search_1d_lk(m,ks)  ! �����ӵı߽�
       endif
	  enddo
      
     enddo
!----------------------------
	 call set_ibie  ! ����ib1,ie1����Ϣ���趨ib,ie
		 
   end

!-------------------------------------------------
   subroutine set_ibie
    use global_var1
    Type (Block_TYPE1),pointer:: B
    TYPE (BC_MSG_TYPE),pointer:: Bc
    integer:: m,ks
    do m=1,NBnew
     B => Block_new(m)
    do ks=1,B%subface
     Bc=>B%bc_msg(ks)
     select case (Bc%face)
	  case (1)
	    Bc%ib=1; Bc%ie=1; Bc%jb=Bc%b1 ; Bc%je =Bc%e1 ; Bc%kb=Bc%b2; Bc%ke=Bc%e2
      case (4)
	    Bc%ib=B%nx; Bc%ie=B%nx; Bc%jb=Bc%b1 ; Bc%je =Bc%e1 ; Bc%kb=Bc%b2; Bc%ke=Bc%e2
      case(2)
	    Bc%ib=Bc%b1; Bc%ie=Bc%e1; Bc%jb=1 ; Bc%je =1 ; Bc%kb=Bc%b2; Bc%ke=Bc%e2
      case(5)
	    Bc%ib=Bc%b1; Bc%ie=Bc%e1; Bc%jb=B%ny ; Bc%je =B%ny ; Bc%kb=Bc%b2; Bc%ke=Bc%e2
      case(3)
	    Bc%ib=Bc%b1; Bc%ie=Bc%e1;  Bc%jb=Bc%b2; Bc%je=Bc%e2; Bc%kb=1 ; Bc%ke =1 
      case(6)
	    Bc%ib=Bc%b1; Bc%ie=Bc%e1;  Bc%jb=Bc%b2; Bc%je=Bc%e2; Bc%kb=B%nz ; Bc%ke = B%nz
	 end select 


    enddo
	enddo

    end










  subroutine write_inp_new  
    use global_var1
    Type (Block_TYPE1),pointer:: B,B1
    TYPE (BC_MSG_TYPE),pointer:: Bc,Bc1


   open(99,file="bc3d_new.inc")
    write(99,*) " Inp-liked file of OpenCFD-EC"
    write(99,*) NBnew

	do m=1,NBnew
     B => Block_new(m)
     write(99,*) B%nx, B%ny, B%nz
	 write(99,*) "Block ", m
	 write(99,*) B%subface
	  do ksub=1,B%subface
        Bc => B%bc_msg(ksub)
	   write(99,"(9I6)")  Bc%ib,Bc%ie,Bc%jb,Bc%je,Bc%kb,Bc%ke,Bc%bc,Bc%face,Bc%f_no
	   write(99,"(12I6)") Bc%ib1,Bc%ie1,Bc%jb1,Bc%je1,Bc%kb1,Bc%ke1,Bc%nb1,Bc%face1,Bc%f_no1,Bc%L1,Bc%L2,Bc%L3
      enddo
	enddo
	close(99)
   end



!----creat bc_msg ----------	
	 subroutine creat_new_bcmsg
	 use global_var1
	 implicit none
     Type (Block_TYPE1),pointer:: B
     TYPE (BC_MSG_TYPE),pointer:: Bc
	 integer:: m,ks

	 do m=1,NBnew
      B=>Block_new(m)
	  B%subface=0
	  allocate(B%bc_msg(Maxsub))
	  do ks=1,Maxsub
	  Bc=>B%bc_msg(ks)
	  Bc%ib=0; Bc%ie=0;Bc%jb=0;Bc%je=0;Bc%kb=0;Bc%ke=0; Bc%bc=0; Bc%face=0; Bc%f_no=0
	  Bc%ib1=0; Bc%ie1=0; Bc%jb1=0; Bc%je1=0; Bc%kb1=0; Bc%ke1=0
	  Bc%nb1=0; Bc%face1=0; Bc%f_no1=0; Bc%L1=0; Bc%L2=0; Bc%L3=0
	  Bc%b1=0; Bc%e1=0; Bc%b2=0; Bc%e2=0
	  Bc%b1t=0; Bc%e1t=0; Bc%b2t=0; Bc%e2t=0           
	 enddo
     enddo
	 end

!------------------------------------------------
! �����ӵı߽�
     subroutine search_1d_bd(m,ks)   
	 use global_var1
	 implicit none
     TYPE (BC_MSG_TYPE),pointer:: Bc,Bc1
     TYPE (bcnp_type),pointer ::BP,BP1,BP2
     Type (Block_TYPE1),pointer:: B,B1
	 	  
	  integer,dimension(2)::ib,ie,ns
      integer:: npk(2),blkm(3)  ! npk ÿһά�Ŀ����� blkm ��ά�Ŀ��ַ
      integer:: ks,q,m,k,blk,idx,k1,k2
	  B=>Block(m)
      Bc=>B%bc_msg(ks)
	  npk(:)=1   ! ÿһά�Ŀ���
	  call get_ib(ib,ie,ns,blkm,m,ks)    ! ÿһά����ʼ����ֹ��ַ
      
	  do q=1,2   ! 2 ά
      npk(q)=1
	  BP=>bcn(npk(q),q)
	  
	  call get_bk(blk,idx,ib(q),ns(q),m)
	  BP%blk=blk   ! ���ַ
	  BP%idx=idx   ! ƫ�Ƶ�ַ
	  BP%nn=1
	  do k=ib(q)+1,ie(q)
	  call get_bk(blk,idx,k,ns(q),m)
       if(blk .ne. BP%blk ) then
         npk(q)=npk(q)+1  ! ��������
         BP=>bcn(npk(q),q)
		 BP%blk=blk  ! ��Ԫ�ؿ��ַ
		 BP%idx=idx  ! ��Ԫ��ƫ�Ƶ�ַ
         BP%nn=1
	    else
		 BP%nn=BP%nn+1
		endif
	   enddo
	
	 enddo
 
!-  write bc msg in new block ----
     do k1=1,npk(1)
	 do k2=1,npk(2)
      BP1=>bcn(k1,1)
	  BP2=>bcn(k2,2)

!	  blkm(ns(1))=k1   ! ���ϵĵ�1ά
!	  blkm(ns(2))=k2
	  blkm(ns(1))=BP1%blk   
	  blkm(ns(2))=BP2%blk


      blk=B%nbk0+B%PI*B%PJ*(blkm(3)-1)+B%PI*(blkm(2)-1)+blkm(1)-1     ! �¿��
      B1=>block_new(blk)
      B1%subface=B1%subface+1   ! �½��߽�����
	  k=B1%subface
	  Bc1=>B1%bc_msg(k)
      Bc1%b1=BP1%idx ; Bc1%e1=BP1%idx+BP1%nn-1
	  Bc1%b2=BP2%idx ; Bc1%e2=BP2%idx+BP2%nn-1
	  Bc1%bc=Bc%bc
	  Bc1%face=Bc%face
	  Bc1%f_no=k
	 enddo
	 enddo

	end
!---------------------------------------------



!------------------------------------------------
! �����ӵı߽�
     subroutine search_1d_lk(m,ks)   
	 use global_var1
	 implicit none
     TYPE (BC_MSG_TYPE),pointer:: Bc,Bc1
     TYPE (bcnp_type),pointer ::BP,BP1,BP2
     Type (Block_TYPE1),pointer:: B,Bt,B1,B1t
	 	  
	  integer,dimension(2)::ib,ie,ns   
      integer,dimension(2):: ibt,nst,Lt  

	  integer:: npk(2),blkm(3),blkmt(3) ! npk ÿһά�Ŀ����� blkm ��ά�Ŀ��ַ
      integer:: ks,q,m,k,blk,idx,k1,k2,mt,kt,blkt,idxt,nst3
	  integer:: kb1t(3),ke1t(3),nkt(6)

	  B=>Block(m)
      Bc=>B%bc_msg(ks)
	  mt=Bc%nb1   ! ���ӿ��
      Bt=>Block(mt)  !���ӿ�

	  npk(:)=1   ! ÿһά�Ŀ���

	  call get_ib(ib,ie,ns,blkm,m,ks)           ! ÿһά����ʼ����ֹ��ַ
      call get_ibt(ibt,ns,nst,Lt,blkmt, m,ks)   ! ����ά����ʼ��ַ��ά��


	  do q=1,2   ! 2 ά
      npk(q)=1
	  BP=>bcn(npk(q),q)
	  
	  call get_bk(blk,idx,ib(q),ns(q),m)   ! ���ַ��������ַ
      call get_bk(blkt,idxt,ibt(q),nst(q),mt)

	  BP%blk=blk   ! ���ַ
	  BP%idx=idx   ! ƫ�Ƶ�ַ
	  BP%nn=1
	  BP%blkt=blkt
	  BP%idxt=idxt


	  do k=ib(q)+1,ie(q)          ! ������ index
	     kt=ibt(q)+Lt(q)*(k-ib(q))   ! ���� index

	  call get_bk(blk,idx,k,ns(q),m)
	  call get_bk(blkt,idxt,kt,nst(q),mt)

       if(blk .ne. BP%blk  .or. blkt .ne. BP%blkt) then
         npk(q)=npk(q)+1  ! ��������
         BP=>bcn(npk(q),q)
		 BP%blk=blk  ! ��Ԫ�ؿ��ַ
		 BP%idx=idx  ! ��Ԫ��ƫ�Ƶ�ַ
         BP%nn=1
	     BP%blkt=blkt
		 BP%idxt=idxt
	    else
		 BP%nn=BP%nn+1
		endif
	   enddo
	
	 enddo
 
!-  write bc msg in new block ----
     do k1=1,npk(1)
	 do k2=1,npk(2)
      BP1=>bcn(k1,1)
	  BP2=>bcn(k2,2)

      ! ���������� ��ά�Ŀ�����
!	  blkm(ns(1))=k1   
!	  blkm(ns(2))=k2

	  blkm(ns(1))=BP1%blk   
	  blkm(ns(2))=BP2%blk
      blkmt(nst(1))=BP1%blkt
	  blkmt(nst(2))=BP2%blkt

      blk=B%nbk0+B%PI*B%PJ*(blkm(3)-1)+B%PI*(blkm(2)-1)+blkm(1)-1     ! �¿��
      blkt=Bt%nbk0+Bt%PI*Bt%PJ*(blkmt(3)-1)+Bt%PI*(blkmt(2)-1)+blkmt(1)-1     ! ���ӿ��
         
	 
	 
	  B1=>block_new(blk)
      B1%subface=B1%subface+1   ! �½��߽�����
	  k=B1%subface
	  Bc1=>B1%bc_msg(k)
      Bc1%b1=BP1%idx ; Bc1%e1=BP1%idx+BP1%nn-1
	  Bc1%b2=BP2%idx ; Bc1%e2=BP2%idx+BP2%nn-1
	  Bc1%bc=Bc%bc
	  Bc1%face=Bc%face
	  Bc1%f_no=k
      

	  Bc1%b1t=BP1%idxt
      Bc1%e1t=Bc1%b1t+Lt(1)*(BP1%nn-1)
   	  Bc1%b2t=BP2%idxt
      Bc1%e2t=Bc1%b2t+Lt(2)*(BP2%nn-1)	  


	  Bc1%L1=Bc%L1
	  Bc1%L2=Bc%L2
      Bc1%L3=Bc%L3
	  Bc1%face1=Bc%face1
	  Bc1%nb1=blkt               ! ���ӿ��
	  B1t=>block_new(Bc1%nb1)  


!-----------------------------------------------------
      kb1t(nst(1))=min(Bc1%b1t,Bc1%e1t)
	  ke1t(nst(1))=max(Bc1%b1t,Bc1%e1t)

      kb1t(nst(2))=min(Bc1%b2t,Bc1%e2t)
	  ke1t(nst(2))=max(Bc1%b2t,Bc1%e2t)
      nst3=6-nst(1)-nst(2)     ! ����һά ���˻�ά��
    
	  nkt(1:3)=1; nkt(4)=B1t%nx; nkt(5)=B1t%ny; nkt(6)=B1t%nz
	  kb1t(nst3)=nkt(Bc1%face1)
	  ke1t(nst3)=nkt(Bc1%face1)
 
      Bc1%ib1=kb1t(1) ; Bc1%ie1=ke1t(1) 
	  Bc1%jb1=kb1t(2) ; Bc1%je1=ke1t(2)
	  Bc1%kb1=kb1t(3) ; Bc1%ke1=ke1t(3)

	 enddo
	 enddo

	end
!---------------------------------------------














!------------------------------------------------
! �趨�µ��ڱ߽�

     subroutine set_new_inner
	 use global_var1
	 implicit none
     TYPE (BC_MSG_TYPE),pointer:: Bc
     Type (Block_TYPE1),pointer:: B,B1,B2
	 	  
     integer:: m,m0,m1,ms
	  
	  do m=1,NBnew
	   B1=>Block_new(m)
       m0=B1%nb_ori
	   B=>Block(m0) 

       if(B1%PI .ne. 1) then   ! ������
	     m1=m-1   ! �����
		 B2=>Block_new(m1)  ! ���ӿ�

		 B1%subface=B1%subface+1  ! ����
		 ms=B1%subface
		 Bc=>B1%bc_msg(ms)
	
		 Bc%ib=1 ;  Bc%ie=1 ; Bc%jb=1; Bc%je=B1%ny ; Bc%kb=1 ; Bc%ke=B1%nz
		 Bc%bc=BC_In ;     Bc%face=1  ;  Bc%f_no=ms
		 Bc%ib1=B2%nx; Bc%ie1=B2%nx; Bc%jb1=1; Bc%je1=B2%ny; Bc%kb1=1; Bc%ke1=B2%nz
		 Bc%nb1=m1 ;       Bc%face1=4   
		 Bc%L1=1 ; Bc%L2=2 ; Bc%L3=3
       endif

       if(B1%PI .ne. B%PI) then   ! ������
	     m1=m+1   ! �����
		 B2=>Block_new(m1)  ! ���ӿ�

		 B1%subface=B1%subface+1  ! ����
		 ms=B1%subface
		 Bc=>B1%bc_msg(ms)
	
		 Bc%ib=B1%nx ;  Bc%ie=B1%nx ;  Bc%jb=1; Bc%je=B1%ny ; Bc%kb=1 ; Bc%ke=B1%nz
		 Bc%bc=BC_In ;     Bc%face=4  ;  Bc%f_no=ms
		 Bc%ib1=1; Bc%ie1=1; Bc%jb1=1; Bc%je1=B2%ny; Bc%kb1=1; Bc%ke1=B2%nz
		 Bc%nb1=m1 ;       Bc%face1=1   
		 Bc%L1=1 ; Bc%L2=2 ; Bc%L3=3
       endif


       if(B1%PJ .ne. 1) then   ! j- ����
	     m1=m-B%PI      ! �²���
		 B2=>Block_new(m1)  ! ���ӿ�

		 B1%subface=B1%subface+1  ! ����
		 ms=B1%subface
		 Bc=>B1%bc_msg(ms)
	
		 Bc%ib=1 ;  Bc%ie=B1%nx ;  Bc%jb=1; Bc%je=1 ;           Bc%kb=1 ; Bc%ke=B1%nz
		 Bc%bc=BC_In ;     Bc%face=2  ;  Bc%f_no=ms
		 Bc%ib1=1; Bc%ie1=B2%nx;   Bc%jb1=B2%ny; Bc%je1=B2%ny;  Bc%kb1=1; Bc%ke1=B2%nz
		 Bc%nb1=m1 ;       Bc%face1=5   
		 Bc%L1=1 ; Bc%L2=2 ; Bc%L3=3
       endif

       if(B1%PJ .ne. B%PJ) then   ! j+ ����
	     m1=m+B%PI      ! �ϲ���
		 B2=>Block_new(m1)  ! ���ӿ�

		 B1%subface=B1%subface+1  ! ����
		 ms=B1%subface
		 Bc=>B1%bc_msg(ms)
	
		 Bc%ib=1 ;  Bc%ie=B1%nx ;  Bc%jb=B1%ny; Bc%je=B1%ny ;      Bc%kb=1 ; Bc%ke=B1%nz
		 Bc%bc=BC_In ;     Bc%face=5  ;  Bc%f_no=ms
		 Bc%ib1=1; Bc%ie1=B2%nx;   Bc%jb1=1; Bc%je1=1;           Bc%kb1=1; Bc%ke1=B2%nz
		 Bc%nb1=m1 ;       Bc%face1=2   
		 Bc%L1=1 ; Bc%L2=2 ; Bc%L3=3
       endif


       if(B1%PK .ne. 1) then   ! k- ����
	     m1=m-B%PI*B%PJ      ! ǰ����
		 B2=>Block_new(m1)   ! ���ӿ�

		 B1%subface=B1%subface+1  ! ����
		 ms=B1%subface
		 Bc=>B1%bc_msg(ms)
	
		 Bc%ib=1 ;  Bc%ie=B1%nx ;  Bc%jb=1; Bc%je=B1%ny ;      Bc%kb=1 ; Bc%ke=1
		 Bc%bc=BC_In ;     Bc%face=3  ;  Bc%f_no=ms
		 Bc%ib1=1;  Bc%ie1=B2%nx;   Bc%jb1=1; Bc%je1=B2%ny;    Bc%kb1=B2%nz; Bc%ke1=B2%nz
		 Bc%nb1=m1 ;       Bc%face1=6   
		 Bc%L1=1 ; Bc%L2=2 ; Bc%L3=3
       endif


       if(B1%PK .ne. B%PK) then   ! k- ����
	     m1=m+B%PI*B%PJ      ! ǰ����
		 B2=>Block_new(m1)   ! ���ӿ�

		 B1%subface=B1%subface+1  ! ����
		 ms=B1%subface
		 Bc=>B1%bc_msg(ms)
	
		 Bc%ib=1 ;  Bc%ie=B1%nx ;  Bc%jb=1; Bc%je=B1%ny ;      Bc%kb=B1%nz ; Bc%ke=B1%nz
		 Bc%bc=BC_In ;     Bc%face=6  ;  Bc%f_no=ms
		 Bc%ib1=1;  Bc%ie1=B2%nx;   Bc%jb1=1; Bc%je1=B2%ny;    Bc%kb1=1; Bc%ke1=1
		 Bc%nb1=m1 ;       Bc%face1=3   
		 Bc%L1=1 ; Bc%L2=2 ; Bc%L3=3
       endif
     enddo
	end
!---------------------------------------------











!-----�ҳ���1,2ά����ʼ����ֹ��ַ
	  subroutine get_ib(ib,ie,ns,blkm,m,ks)    
	  use global_var1
	  implicit none
	  integer::ib(2),ie(2),ns(2),blkm(3),m,ks
      Type (Block_TYPE1),pointer:: B
      TYPE (BC_MSG_TYPE),pointer:: Bc
       
	   B=>Block(m)
	   Bc=>B%bc_msg(ks)

       if(Bc%face==1 .or. Bc%face == 4) then
	    ib(1)=Bc%jb; ie(1)=Bc%je ; ns(1)=2       ! ��1ά�� j���� 
		ib(2)=Bc%kb; ie(2)=Bc%ke ; ns(2)=3       ! ��2ά�� k����
	   else if(Bc%face== 2 .or. Bc%face == 5) then
        ib(1)=Bc%ib; ie(1)=Bc%ie ; ns(1)=1
		ib(2)=Bc%kb; ie(2)=Bc%ke ; ns(2)=3
	   else
	    ib(1)=Bc%ib; ie(1)=Bc%ie; ns(1)=1
		ib(2)=Bc%jb; ie(2)=Bc%je; ns(2)=2
	   endif


! �˻�ά�Ŀ�����
	  select case (Bc%face)  
       case(1)
		   blkm(1)=1
	   case(4)
		   blkm(1)=B%PI
	   case(2)
		   blkm(2)=1
	   case(5)
		   blkm(2)=B%PJ
	   case(3)
		   blkm(3)=1
	   case(6)
		   blkm(3)=B%PK
	   end select
    end

 
  ! �����ӿ����Ϣ 
  ! ibt(1), ibt(2): ��1����2����ά 
  ! nst(1), nst(2): ��1,2����ά�� ά��
  ! Lt(1),Lt(2): ���Ӵ��� (1 or -1)
      subroutine get_ibt(ibt,ns,nst,Lt,blkmt, m,ks)   
	  use global_var1
	  implicit none
	  integer::ibt(2),ns(2),nst(2),Lt(2),blkmt(3),m,ks,Lk(3),bt(3),et(3),k
      Type (Block_TYPE1),pointer:: B,B1
      TYPE (BC_MSG_TYPE),pointer:: Bc
       
	   B=>Block(m)
	   Bc=>B%bc_msg(ks)
       LK(1)=Bc%L1; LK(2)=Bc%L2; LK(3)=Bc%L3 
       bt(1)=Bc%ib1; bt(2)=Bc%jb1 ; bt(3)=Bc%kb1
       et(1)=Bc%ie1; et(2)=Bc%je1; et(3)=Bc%ke1

	   do k=1,2
       nst(k)=abs(LK(ns(k)))    ! ��1,2ά������
	   Lt(k)=sign(1,LK(ns(k)))  ! ��������
                               ! ���ӵ���ʼ��ַ
		 if(Lt(k) > 0) then
          ibt(k)=bt(nst(k))       
         else
	      ibt(k)=et(nst(k))
		 endif
	   enddo
       
	   B1=>block(Bc%nb1)

! �������ӿ飩�˻�ά�Ŀ�����
	  select case (Bc%face1)  
       case(1)
		   blkmt(1)=1
	   case(4)
		   blkmt(1)=B1%PI
	   case(2)
		   blkmt(2)=1
	   case(5)
		   blkmt(2)=B1%PJ
	   case(3)
		   blkmt(3)=1
	   case(6)
		   blkmt(3)=B1%PK
	   end select

    end




! -----------
 !  �����±�k, ������ǵ�bk���ӿ�,�����±�bi
  subroutine get_bk(bk,ki,k,ns,mb)    ! k, �±꣬ ns ά��, nb (ԭ)���
     use global_var1
     implicit none
     integer:: bk,ki,k,ns,mb,Pn,nn            ! Pn ������ nn �������
     Type (Block_TYPE1),pointer:: B
	 B=> block(mb)
     if(ns == 1) then  ! ��1ά
	  nn=B%nx
	  Pn=B%Pi
	 else if(ns==2) then
	  nn=B%ny
	  Pn=B%Pj
	 else if(ns==3) then
	  nn=B%nz
	  Pn=B%Pk
	 else
	  print*, "Error at get_bk !!"
	  stop
	 endif
     call get_bki(bk,ki,k,nn,Pn)
  end

  subroutine get_bki(bk,ki,k,nn,Pn)
     implicit none
	 integer:: bk,k,nn,Pn,k1,ki
	     bk=0
  	     do k1=1,Pn
          if( k >=int(nn*(k1-1)/Pn)+1  .and. k<=int(nn*k1/Pn) ) then
           bk=k1
	       exit 
 	      endif
		 enddo
   
         if(bk==0) then
		 print*, "error at get_bki !!"
		 stop
		 endif
        
		ki=k-int(nn*(bk-1)/Pn)
  end
   









!--------------------------------------------------------

   subroutine read_cutfile
   use global_var1
   implicit none
   integer:: m
   	
	NBnew=0
	open(99,file="Mesh3d.cut")
	read(99,*)
    read(99,*) Mesh_form, NB
    allocate(PI(NB),PJ(NB),PK(NB))
    do m=1,NB
	 read(99,*)
	 read(99,*) PI(m),PJ(m),PK(m)
	 NBnew=NBnew+PI(m)*PJ(m)*PK(m)
	enddo
    close(99)
    print*, "NB=",NB, " NBnew= ",NBnew
   end
!---------------------------------------------------
   
   subroutine cut_mesh
   use global_var1
   implicit none
   integer:: NB0,NB1,i,j,k,m,nx,ny,nz,nx1,ny1,nz1,i1,j1,k1,m0,m1,n
   integer:: i2,j2,k2,m2
   integer,allocatable,dimension(:):: NI,NJ,NK
   Type (Block_TYPE1),pointer:: B,B1
    

    allocate(Block(NB))
	allocate(Block_new(NBnew))
    allocate(NI(NB),NJ(NB),NK(NB))

     if(mesh_form==0) then
	  open(100,file="Mesh0.dat",form="unformatted")
	  read(100) NB1
	else
	  open(100,file="Mesh0.dat")
	  read(100,*) NB1
    endif	 


	if(NB1 .ne. NB) then
	 print*, "Block number in Mesh0.dat is not equal to that in Mesh3d.cut! "
	 stop
	endif

    if(mesh_form==0) then
     read(100) ((NI(k),NJ(k),Nk(k)),k=1,NB)
    else
     read(100,*) ((NI(k),NJ(k),Nk(k)),k=1,NB)
	endif

!================================================	 
     m1=1
	 do m=1,NB
 	  B=>Block(m)
      B%Block_no=m
	  B%Pi=PI(m)
	  B%Pj=PJ(m)
	  B%Pk=PK(m)
      B%nbk0=m1    ! ��ʼ�ӿ��
      B%nx=NI(m)
	  B%ny=NJ(m)
	  B%nz=NK(m)
	  nx=B%nx; ny=B%ny; nz=B%nz
      allocate(B%xyz(nx,ny,nz,3))
      
	  if(mesh_form==0) then
	    read(100) ((((B%xyz(i,j,k,n),i=1,nx),j=1,ny),k=1,nz),n=1,3)
      else
	   read(100,*) ((((B%xyz(i,j,k,n),i=1,nx),j=1,ny),k=1,nz),n=1,3)
	  endif


	   do k1=1,PK(m)
	   do j1=1,PJ(m)
	   do i1=1,PI(m)
	     B1=>Block_new(m1)
		 B1%block_no=m1        ! ���
		 B1%nb_ori=m           ! ԭ���
		 B1%Pi=i1      ! i ����Ŀ����
		 B1%Pj=j1
		 B1%Pk=k1
		 
		 B1%nx=int((nx*i1)/PI(m))- int((nx*(i1-1))/PI(m))
		 B1%ny=int((ny*j1)/PJ(m))- int((ny*(j1-1))/PJ(m))
		 B1%nz=int((nz*k1)/PK(m))- int((nz*(k1-1))/PK(m))
         nx1=B1%nx; ny1=B1%ny ; nz1=B1%nz
         B1%ib= int((nx*(i1-1))/PI(m))+1
		 B1%jb= int((ny*(j1-1))/PJ(m))+1
		 B1%kb= int((nz*(k1-1))/PK(m))+1
 		 allocate(B1%xyz(nx1,ny1,nz1,3))
 	 	 B1%block_no=m1
		 
		 do m2=1,3
         do k2=1,nz1
		 do j2=1,ny1
		 do i2=1,nx1
		  i=B1%ib+i2-1
		  j=B1%jb+j2-1
		  k=B1%kb+k2-1
          B1%xyz(i2,j2,k2,m2)=B%xyz(i,j,k,m2)
         enddo
 		 enddo
		 enddo
		 enddo
		 m1=m1+1

	 enddo
	 enddo
	 enddo

   enddo
   close(100)

   end


!--------------------------------------------------------
  subroutine write_new_mesh
   use global_var1
   implicit none
   integer:: i,j,k,m,n
   Type (Block_TYPE1),pointer:: B
   open(99,file="Mesh3d_new.dat",form="unformatted")
   write(99) NBnew
   write(99) (Block_new(m)%nx,Block_new(m)%ny,Block_new(m)%nz,m=1,NBnew)
   do m=1,NBnew
   B=> Block_new(m)
   write(99) ((((B%xyz(i,j,k,n),i=1,B%nx),j=1,B%ny),k=1,B%nz),n=1,3)
   enddo
   close(99)
   end
        


!------------------------------------------------------
  subroutine convert_inp_inc 
   use global_var1
   implicit none
  
   integer:: NB1,m,ksub,nx,ny,nz,k,j,k1,ksub1
   integer:: kb(3),ke(3),kb1(3),ke1(3),s(3),p(3),Lp(3)
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
   read(88,*) NB1
   if(NB1 .ne. NB ) then
    print*, "NB in bc3d.inp is not correct !"
	stop
   endif 

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

  call search_fno1(1)

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



!-----------------------------------------------------
! �����飬����fno1
! Kflag==1 search old block;  2 new block
subroutine search_fno1(Kflag)
   use global_var1
   implicit none
   integer:: NB1,m,kflag,ksub,ksub1
   Type (Block_TYPE1),pointer:: B,B1
   TYPE (BC_MSG_TYPE),pointer:: Bc,Bc1
   
   if(Kflag==1) then
    NB1=NB
   else
    NB1=NBnew
   endif

!  �������ӿ�Ŀ�� f_no1  (����MPI����ͨ����ʹ��)
   do m=1,NB1
     if(Kflag==1) then
 	  B => Block(m)
     else
	  B=> Block_new(m)
	 endif

	 do ksub=1, B%subface
       Bc => B%bc_msg(ksub)
       if(Bc%bc .lt. 0) then
         Bc%f_no1=0
		 
		 if(Kflag==1) then
		   B1=>Block(Bc%nb1)         ! ָ�����ӿ�
         else
		   B1=>Block_new(Bc%nb1)
		 endif


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
  end


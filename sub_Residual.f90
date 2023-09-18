 !-----The core subroutines: Comput inviscous and viscous flux ------------------------------
 !     OpenCFD-EC 3D 
 !     Copyright by Li Xinliang, LHD, Institute of Mechanics, CAS. lixl@imech.ac.cn
 !     Code by Li Xinliang and Leng Yan
 !     Ver 0.43 2010-11-28
 !     Ver 0.50 2010-12-9
 !     Ver 0.74 2011-12-29
 !     Ver 0.8  2012-5-5
 !     Ver 0.97a 2013-5-4:  viscous flux code modified, corner points is not used
 !     Ver 1.01  2013-11-13:  boundary scheme can be used 
 !     Ver 1.16  2017-7-11:   ������������ޣ��򱾿齵Ϊ1��ӭ�磬�ҹر�ճ���
  
! ����в�����ȫ���飩
  Subroutine Comput_Residual_one_mesh(nMesh)
   use Global_Var
   use Flow_Var 
   implicit none
   integer:: nMesh,NVAR1,mBlock,nx,ny,nz,i,j,k,m,KL,IR,JR,KR
   integer,save:: Iflag1=0
   real(PRE_EC):: Sfac,Sfac1
   Type (Mesh_TYPE),pointer:: MP
   Type (Block_TYPE),pointer:: B

!---------------------------------------------  
  if(Time_Method .eq. Time_Dual_LU_SGS) then
	 if(Iflag1 .eq. 0) then
	   Iflag1=1
	   Sfac=1.d0/(3.d0*dt_global)  ! ��һ��ʱ�䲽�� Un=U(n-1), ʱ�侫��1��
	   Sfac1=1.d0/dt_global
	 else
	   Sfac=1.d0/(2.d0*dt_global) 
	   Sfac1=3.d0/(2.d0*dt_global)       
	 endif
  else
     Sfac=0.d0
	 Sfac1=0.d0
  endif

!----------------------------------------------- 
   MP=>Mesh(nMesh)
   MP%Res_max(:) =0.d0  ! ���в�
   MP%Res_rms(:) =0.d0  ! �������в�            
   NVAR1=MP%NVAR
!----------------------------------------------
   do mBlock=1,MP%Num_Block
     B => MP%Block(mBlock)                  ! ��nMesh ������ĵ�mBlock��
     nx=B%nx; ny=B%ny; nz=B%nz
     KL=1-LAP
	 IR=nx+LAP-1
	 JR=ny+LAP-1
	 KR=nz+LAP-1
	 allocate(d(KL:IR,KL:JR,KL:KR),uu(KL:IR,KL:JR,KL:KR),v(KL:IR,KL:JR,KL:KR),  &
              w(KL:IR,KL:JR,KL:KR), T(KL:IR,KL:JR,KL:KR), &
              cc(KL:IR,KL:JR,KL:KR),p(KL:IR,KL:JR,KL:KR))
    
	
	 allocate(Flux(NVAR1,nx,ny,nz))                            ! ͨ��(���巽��)
     allocate(Lci(nx,ny,nz),Lcj(nx,ny,nz),Lck(nx,ny,nz),Lvi(nx,ny,nz),Lvj(nx,ny,nz),Lvk(nx,ny,nz))  ! �װ뾶����ճ��ճ�ԣ�

!------------------------------------------------------------------------------------     
	 call limit_vt(nMesh,mBlock)    ! ��SA��SST���̵�������(vt,Kt,Wt)��������

	 call comput_duvtpc(nMesh,mBlock)                      ! ��������� d,u,v,T,p,cc , vt,kt,Wt

!---------------------------------------------------------------------------------------
!  ���N-S���̵ĺ���ģ�飺 ����в�Ҷ��  
     call Residual (nMesh,mBlock)                          ! ����һ�������Ĳв�Ҷ�� ; ��nMesh ������ĵ�mBlock��
!----------------------------------------------
!    OpenCFD-SEC�� ���ò�ַ�����ÿ�Ĳв�
! !!! FVM-FDM --------------
   	 if(B%IFLAG_FVM_FDM  .eq. Method_FDM) call Residual_FDM(nMesh,mBlock)  ! ���������������в��������   !!!SEC!!!
!---FVM-FDM-------------

! ����Ҷ�ֻ�����������Դ�� ���������
    if(IF_TurboMachinary .eq. 1) then

!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(i,j,k)
	  do k=1,nz-1
	  do j=1,ny-1
      do i=1,nx-1
       B%Res(3,i,j,k)=B%Res(3,i,j,k)+B%vol(i,j,k)*d(i,j,k)*(Turbo_w**2*B%yc(i,j,k)+2.d0*Turbo_w*w(i,j,k))
       B%Res(4,i,j,k)=B%Res(4,i,j,k)+B%vol(i,j,k)*d(i,j,k)*(Turbo_w**2*B%zc(i,j,k)-2.d0*Turbo_w*v(i,j,k))
       B%Res(5,i,j,k)=B%Res(5,i,j,k)+B%vol(i,j,k)*d(i,j,k)*Turbo_w**2*(v(i,j,k)*B%yc(i,j,k)+w(i,j,k)*B%zc(i,j,k))
	  enddo
	  enddo
	  enddo
!$OMP END PARALLEL DO
   endif




!  ˫ʱ�䲽��������Ӹ��Ӳв�     
	 if(Time_Method .eq. Time_Dual_LU_SGS) then
!$OMP PARALLEL DO DEFAULT(SHARED) PRIVATE(i,j,k,m)
	  do k=1,nz-1
	  do j=1,ny-1
      do i=1,nx-1
      do m=1,NVAR1
       B%Res(m,i,j,k)=B%Res(m,i,j,k)-(3.d0*B%U(m,i,j,k)-4.d0*B%Un(m,i,j,k)+B%Un1(m,i,j,k))*B%vol(i,j,k)*Sfac
      enddo
	  enddo
	  enddo
	  enddo
!$OMP END PARALLEL DO
     endif



     call comput_Lijk(nMesh,mBlock)                        ! �����װ뾶  (Blazek's book, p189-190), �в��˳���ֲ�ʱ�䲽����LU-SGS�о�ʹ�ø�ֵ
	 if(If_Residual_smoothing .eq. 1 ) then
	     call Residual_smoothing(nMesh,mBlock)             ! �в��˳
	 endif
	 call comput_dt(nMesh,mBlock)                          ! ����(����) ʱ�䲽��

     if(Time_Method .eq. Time_LU_SGS .or. Time_Method .eq. Time_Dual_LU_SGS) then
        call du_LU_SGS(nMesh,mBlock,Sfac1)                      ! ����LU_SGS��������DU=U(n+1)-U(n)
     endif

	 deallocate(d,uu,v,w,T,cc,p,Flux)
     deallocate(Lci,Lcj,Lck,Lvi,Lvj,Lvk)


   enddo    
   

  end Subroutine Comput_Residual_one_mesh


!------------------------------------------------------------------------------
! ����в� (�в�=�Ҷ���=������); �����N-S���̵ĺ���ģ��; 
! Flux (= inviscous flux + viscous flux )

    subroutine Residual(nMesh,mBlock)
     Use Global_Var
     Use Flow_Var
     implicit none
     integer:: nx,ny,nz,i,j,k,m,nMesh,mBlock !,Scheme,IFlux,Reconstruction
     Type (Block_TYPE),pointer:: B
     TYPE (Mesh_TYPE),pointer:: MP
     MP=> Mesh(nMesh)
     B => MP%Block(mBlock)
     
     if(If_viscous .eq. 1 ) then
      call get_viscous(nMesh,mBlock)                   ! �������ճ��ϵ��  
!  ����ģ��
     if(MP%Iflag_turbulence_model .eq. Turbulence_BL) then
       call  turbulence_model_BL(nMesh,mBlock)               !  BLģ��
     else if(MP%Iflag_turbulence_model .eq. Turbulence_SA) then
       call Turbulence_model_SA(nMesh,mBlock)                  ! SAģ��
     else if(MP%Iflag_turbulence_model .eq. Turbulence_NewSA) then
       call Turbulence_model_NewSA(nMesh,mBlock)                  ! New SAģ�� (By Li XL, He ZW and Li L)
   
     else if(MP%Iflag_turbulence_model .eq. Turbulence_SST) then
	   call  Turbulence_model_SST(nMesh,mBlock)

     else
       B%mu_t(:,:,:)=0.d0                                ! ����
     endif 

!    ������ճ��ϵ����������	 
 	 call limit_mut(nMesh,mBlock)

     endif
     
!-----------------��ճ��-------------------------------------
     call flux_inviscous_i(nMesh,mBlock)
     call flux_inviscous_j(nMesh,mBlock)
     call flux_inviscous_k(nMesh,mBlock)
    
! ���������ճ��ͨ��
    if(If_viscous .eq. 1) then
     call flux_viscous_i(nMesh,mBlock)
     call flux_viscous_j(nMesh,mBlock)
     call flux_viscous_k(nMesh,mBlock)
    endif
 
    end  
!---------------------------------------------------------------------------------------------------------
!  i�������ճͨ��, ��������(i,j+1/2,k+1/2) (��(I-1/2,J,K)) Ϊ���Ĳ����ͨ�� 
!  ֧��OpenMP, since ver0.71 
   subroutine flux_inviscous_i(nMesh,mBlock)
    Use Global_Var
    Use Flow_Var
    implicit none
    real(PRE_EC),dimension(5):: UL,UR,QL,QR,Flux0
    real(PRE_EC):: U0(1-LAP:LAP,5)
    integer:: mBlock,NVAR1,i,j,k,m,nx1,ny1,nz1,ksub,nMesh
    integer:: Scheme,IFlux,Reconstruction
    real(PRE_EC):: s1x,s1y,s1z,s2x,s2y,s2z,s3x,s3y,s3z,s0,t10,t1x,t1y,t1z  ! ������(s1)���з���(s2,s3)
    real(PRE_EC):: d0,uu0,v0,w0,p0,E0,un
    Type (Block_TYPE),pointer:: B
    TYPE (Mesh_TYPE),pointer:: MP
    Type (BC_MSG_TYPE),pointer:: Bc
    
    MP=> Mesh(nMesh)
    B => MP%Block(mBlock)
    NVAR1=MP%NVAR
	
!	Scheme=MP%Iflag_Scheme         ! ��ֵ��ʽ ����ͬ�����ϲ��ò�ͬ��ʽ��
    
	IFlux=MP%Iflag_Flux            ! ͨ������
    Reconstruction=MP%IFlag_Reconstruction  ! �ع���ʽ
    nx1=B%nx ; ny1=B%ny ; nz1=B%nz


! OpenMP�ı���ָʾ��������ע�ͣ��� ָ��Do ѭ������ִ�У� ָ��һЩ������˽�еı���
!$OMP PARALLEL DEFAULT(FIRSTPRIVATE) SHARED (MP,B,NVAR1,IFlux,Reconstruction,nx1,ny1,nz1,gamma,Flux,d,uu,v,w,p)
!$OMP DO   
	do k=1,nz1
      do j=1,ny1
        do i=1,nx1
          do m=1,NVAR1
            Flux(m,i,j,k)=0.d0            ! ��ʼ��
          enddo
        enddo
      enddo
    enddo
!$OMP END DO
 
!$OMP DO   
	do k=1,nz1-1 
      do j=1,ny1-1
        do i=1,nx1

!      �趨�߽��ʽ (�����ڵ��ʽ���߽���ʽ)
		    Scheme=MP%Iflag_Scheme
		   
		   if(B%BcI(j,k,1)==1) then            ! �Ƿ�Ϊ����߽�
		     if(i .eq. 1) then
			   Scheme=Scheme_CD2    ! ��1���������2�����ĸ�ʽ �����������񣬱���ͨ���غ㣩  
             else if (i < LAP) then
		       Scheme=MP%Bound_Scheme            ! �߽��ʽ
             endif
           endif
		 
		   if(B%BcI(j,k,2)==1) then      ! �Ƿ�Ϊ����߽�
			if(i .eq. nx1 ) then
			 Scheme=Scheme_CD2        ! ���ұ߽磬����2������
			else if (i > nx1-LAP+1) then
		     Scheme=MP%Bound_Scheme   ! �߽��ʽ
            endif
           endif

          if(B%IF_OverLimit == 1)  Scheme=Scheme_UD1            ! ���������ޣ�����ָ��¶ȣ��� �ÿ����1��ӭ��
		 		 

!-----����ķ�����������з���-----------------------------------------------------------------------------
!  Ϊ�˽�ʡ�ڴ棬�����򲻴洢����ķ������з�����ʹ��ʱ���� (������Щ������)
          s1x=B%ni1(i,j,k); s1y=B%ni2(i,j,k) ; s1z= B%ni3(i,j,k)            ! ��һ���ķ�����
          t1x=B%x(i,j+1,k)-B%x(i,j,k+1); t1y=B%y(i,j+1,k)-B%y(i,j,k+1); t1z=B%z(i,j+1,k)-B%z(i,j,k+1)   ! �Խ���1
          t10=1.d0/(sqrt(t1x*t1x+t1y*t1y+t1z*t1z))  
          s2x=t1x*t10; s2y=t1y*t10; s2z=t1z*t10                             ! ��һ�����з���1 ���Խ���1��
          s3x=s1y*s2z-s1z*s2y; s3y=s1z*s2x-s1x*s2z ; s3z= s1x*s2y-s1y*s2x   ! �з���2 �����������з���1��
!--------------------------------------------------------------------------------------------
! �ڵ㣬����2,3�׸�ʽ�ع�  (I-1/2,J,K) ���ֵ��
! �����ֲἰ�̿����У�ͨ��д�ع���(I+1/2,J,K)���ֵ�� ���������ع�(I-1/2,J,K)���ֵΪ�˷��� 
! ��Ҫʹ��4�����ֵ�� I-2, I-1, I, I+1; ������ֵ(UL)ʹ��I-2,I-1,I���ֵ�ع��� ��ֵ(UR)ʹ��I-1,I,I+1���ֵ�ع�  
          if(Reconstruction .eq. Reconst_Original) then
! ʹ��ԭʼ�����ع� U0(:,:) �洢����4�����ϵ��ܶȡ��ٶȡ�ѹ��
                U0(:,1)=d(i-LAP:i+LAP-1,j,k) 
			    U0(:,2)=uu(i-LAP:i+LAP-1,j,k) 
			    U0(:,3)=v(i-LAP:i+LAP-1,j,k)
			    U0(:,4)=w(i-LAP:i+LAP-1,j,k)
			    U0(:,5)=p(i-LAP:i+LAP-1,j,k)
            call Reconstuction_original(U0,UL,UR,gamma,Scheme)          ! ��ֵ��ʽ
          else if (Reconstruction .eq. Reconst_Conservative) then
! ʹ���غ�����ع� U0(:,:) �洢����4�����ϵ��غ�����������ܶȡ������ܶȺ������ܶȣ�
            do m=1,5
               U0(:,m)=B%U(m,i-LAP:i+LAP-1,j,k)
            enddo
            call Reconstuction_conservative(U0,UL,UR,gamma,Scheme)
          else
! �������������ع�
            do m=1,5
              U0(:,m)=B%U(m,i-LAP:i+LAP-1,j,k)
            enddo
            call Reconstuction_Characteristic(U0,UL,UR,gamma,Scheme)
          endif   
!-------�ع��������õ�(I-1/2,J,K)���ϵ�����ֵUL,UR  (������Ϊԭʼ����)------------
!----��� UL, UR �е��ܶȡ�ѹ���Ƿ�Ϊ�� -------------------------
! ���Ϊ������ʹ��1��ӭ��        
	  if(IF_Scheme_Positivity == 1) then
		if(UL(1) .le. Lim_Zero  .or. UL(5) .le. Lim_Zero) then      ! Lim_Zero=1.d-20 
          UL(1)=d(i-1,j,k)            ! 1��ӭ��
		  UL(2)=uu(i-1,j,k)
		  UL(3)=v(i-1,j,k)
		  UL(4)=w(i-1,j,k)
		  UL(5)=p(i-1,j,k)
		endif

       if(UR(1) .le. Lim_Zero .or. UR(5) .le. Lim_Zero) then
          UR(1)=d(i,j,k)         ! 1��ӭ��
		  UR(2)=uu(i,j,k)
		  UR(3)=v(i,j,k)
		  UR(4)=w(i,j,k)
		  UR(5)=p(i,j,k)
       endif
     endif




!----------------------------------------------------------------
!-----��UL,UR����������ת�任���õ�����ϵ(s1,s2,s3) (�������з���1���з���2) �е��غ����QL,QR
!  �������ܶȡ�ѹ�������ֲ��䣻 �������ٶȣ�ͶӰ���µ������᷽��
!  ��ֵ
          QL(1)=UL(1)                           ! �ܶȣ�������������ת���ֲ��䣩
          QL(2)=UL(2)*s1x+UL(3)*s1y+UL(4)*s1z   ! �����ٶ�
          QL(3)=UL(2)*s2x+UL(3)*s2y+UL(4)*s2z   ! �з���1���ٶȷ���
          QL(4)=UL(2)*s3x+UL(3)*s3y+UL(4)*s3z   ! �з���2���ٶȷ���
          QL(5)=UL(5)                           ! ѹ���������� 
! ��ֵ ��������������ֵ��ͬ��
          QR(1)=UR(1)                            
          QR(2)=UR(2)*s1x+UR(3)*s1y+UR(4)*s1z    
          QR(3)=UR(2)*s2x+UR(3)*s2y+UR(4)*s2z    
          QR(4)=UR(2)*s3x+UR(3)*s3y+UR(4)*s3z    
          QR(5)=UR(5)                             
!---------ͨ������ (FVS��FDS), ��������ֵ���㴩�������ͨ��(��չ1ά���⣩-------------
          if(IFlux .eq. Flux_Steger_Warming ) then
            call Flux_steger_warming_1Da(QL,QR,Flux0,gamma)     ! Steger-Warming FVS���� 
          else  if(IFlux .eq. Flux_Roe ) then
            call Flux_Roe_1D(QL,QR,Flux0,gamma)                 ! Roe FDS����
          else  if(IFlux .eq. Flux_Van_Leer ) then
            call Flux_Van_Leer_1Da(QL,QR,Flux0,gamma)           ! Van Leer FVS����
          else  if(IFlux .eq. Flux_Ausm ) then          
            call Flux_Ausmpw_1Da(QL,QR,Flux0,gamma)             ! AUSM + ����
          else
            call Flux_HLL_HLLC_1D(QL,QR,Flux0,gamma,IFlux)      !HLL/HLLC FDS����������Riemann�⣩
          endif
! ---��(s1,s2,s3)����ϵ�µ�ͨ��Flux0 ���б任���õ�(x,y,z)����ϵ�µ�ͨ���� �������ֲ��䣬��������ͶӰ
! ---�任�󣬳���������͵õ�����(I-1/2,J,K)�� ���� (i,j+1/2,k+1/2)�㣩���ڲ����ͨ��	  
          Flux(1,i,j,k)=-Flux0(1)*B%Si(i,j,k)                        ! ����ͨ�� ������������������ת���仯��
          Flux(2,i,j,k)=-(Flux0(2)*s1x+Flux0(3)*s2x+Flux0(4)*s3x)*B%Si(i,j,k)  ! x����Ķ���ͨ��  ��ͶӰ��x����
          Flux(3,i,j,k)=-(Flux0(2)*s1y+Flux0(3)*s2y+Flux0(4)*s3y)*B%Si(i,j,k)  ! y����Ķ���ͨ��
          Flux(4,i,j,k)=-(Flux0(2)*s1z+Flux0(3)*s2z+Flux0(4)*s3z)*B%Si(i,j,k)  ! z����Ķ���ͨ��
          Flux(5,i,j,k)=-Flux0(5)*B%Si(i,j,k)                        ! ����ͨ�� ��������
        enddo
      enddo
    enddo
!$OMP END DO

    
!----------------Residual -------------------------------
!$OMP DO   
	do k=1,nz1-1
      do j=1,ny1-1
        do i=1,nx1-1
          do m=1,5
            B%Res(m,i,j,k)=Flux(m,i+1,j,k)-Flux(m,i,j,k)        
          enddo
        enddo
      enddo
    enddo
!$OMP END DO

!$OMP END PARALLEL

   end subroutine flux_inviscous_i
!--------------------------------------------------------------------------------------------------------------------
!--------------------------------------------------------------------------------------------------------------------
! ����j�������((I,J-1/2,K)�����ڽ���)����ճͨ�� 
   subroutine flux_inviscous_j(nMesh,mBlock)
    Use Global_Var
    Use Flow_Var
    implicit none
    real(PRE_EC),dimension(5):: UL,UR,QL,QR,Flux0
    real(PRE_EC):: U0(1-LAP:LAP,5)
    integer:: mBlock,i,j,k,m,nx1,ny1,nz1,ksub,nMesh
    integer:: Scheme,IFlux,Reconstruction
    real(PRE_EC):: s1x,s1y,s1z,s2x,s2y,s2z,s3x,s3y,s3z,s0,t10,t1x,t1y,t1z  ! ������(s1)���з���(s2,s3)
    real(PRE_EC):: d0,uu0,v0,w0,p0,E0,un
    Type (Block_TYPE),pointer:: B
    TYPE (Mesh_TYPE),pointer:: MP
    Type (BC_MSG_TYPE),pointer:: Bc
    MP=> Mesh(nMesh)
    B => MP%Block(mBlock)
    Scheme=MP%Iflag_Scheme                  ! ��ֵ��ʽ ����ͬ�����ϲ��ò�ͬ��ʽ��
    IFlux=MP%Iflag_Flux                     ! ͨ������
    Reconstruction=MP%IFlag_Reconstruction  ! �ع���ʽ
    nx1=B%nx ; ny1=B%ny ; nz1=B%nz
    Flux=0.d0                               ! ��ʼ��
   
!$OMP PARALLEL DEFAULT(FIRSTPRIVATE) SHARED(MP,B,IFlux,Reconstruction,nx1,ny1,nz1,gamma,Flux,d,uu,v,w,p)

!$OMP DO   
    do k=1,nz1-1 
      do j=1,ny1
		do i=1,nx1-1   
  
  
  !      �趨�߽��ʽ (�����ڵ��ʽ���߽���ʽ)

		   Scheme=MP%Iflag_Scheme
		    if(B%BcJ(i,k,1)==1) then            ! �Ƿ�Ϊ����߽�
             if(j .eq. 1) then
			   Scheme=Scheme_CD2    ! ��1���������2�����ĸ�ʽ �����������񣬱���ͨ���غ㣩  
			 else if( j < LAP ) then                  ! ������߽�
               Scheme=MP%Bound_Scheme            ! �߽��ʽ
			 endif
            endif
		  
		    if(B%BcJ(i,k,2)==1) then
             if(j .eq. ny1) then
			   Scheme=Scheme_CD2    ! ��1���������2�����ĸ�ʽ �����������񣬱���ͨ���غ㣩  
		     else if( j > ny1-LAP+1 ) then      ! �����ұ߽�
               Scheme=MP%Bound_Scheme            ! �߽��ʽ
			 endif
            endif

           if(B%IF_OverLimit == 1)  Scheme=Scheme_UD1            ! ���������ޣ�����ָ��¶ȣ��� �ÿ����1��ӭ��



          s1x=B%nj1(i,j,k); s1y=B%nj2(i,j,k) ; s1z= B%nj3(i,j,k)  ! ��һ���ķ�����
          t1x=B%x(i+1,j,k+1)-B%x(i,j,k); t1y=B%y(i+1,j,k+1)-B%y(i,j,k) ; t1z=B%z(i+1,j,k+1)-B%z(i,j,k)  ! �Խ���1
          t10=1.d0/(sqrt(t1x*t1x+t1y*t1y+t1z*t1z))  
          s2x=t1x*t10; s2y=t1y*t10; s2z=t1z*t10     ! ��һ�����з���1 ���Խ���1��
          s3x=s1y*s2z-s1z*s2y; s3y=s1z*s2x-s1x*s2z ; s3z= s1x*s2y-s1y*s2x   ! �з���2 �����������з���1: s1*s2��
!--------------------------------------------------------------------------------------------
! �ڵ㣬����2,3�׸�ʽ�ع�  (I,J-1/2,K) ���ֵ��
          if(Reconstruction .eq. Reconst_Original) then
! ʹ��ԭʼ�����ع� U0(:,:) �洢����4�����ϵ��ܶȡ��ٶȡ�ѹ��
             U0(:,1)=d(i,j-LAP:j+LAP-1,k)
			 U0(:,2)=uu(i,j-LAP:j+LAP-1,k) 
			 U0(:,3)=v(i,j-LAP:j+LAP-1,k)
			 U0(:,4)=w(i,j-LAP:j+LAP-1,k)
			 U0(:,5)=p(i,j-LAP:j+LAP-1,k)
            call Reconstuction_original(U0,UL,UR,gamma,Scheme)          ! ��ֵ��ʽ
          else if (Reconstruction .eq. Reconst_Conservative) then
! ʹ���غ�����ع� U0(:,:) �洢����4�����ϵ��غ�����������ܶȡ������ܶȺ������ܶȣ�
            do m=1,5
              U0(:,m)=B%U(m,i,j-LAP:j+LAP-1,k)
            enddo
            call Reconstuction_conservative(U0,UL,UR,gamma,Scheme)
          else
! �������������ع�
            do m=1,5
              U0(:,m)=B%U(m,i,j-LAP:j+LAP-1,k)
            enddo
            call Reconstuction_Characteristic(U0,UL,UR,gamma,Scheme)
          endif
!-------�ع��������õ�(I,J-1/2,K)���ϵ�����ֵUL,UR  ��ԭʼ�������ܶȡ��ٶȡ�ѹ����------------

!----��� UL, UR �е��ܶȡ�ѹ���Ƿ�Ϊ�� -------------------------
! ���Ϊ������ʹ��1��ӭ��        
	  if(IF_Scheme_Positivity == 1) then
		if(UL(1) .le. Lim_Zero  .or. UL(5) .le. Lim_Zero) then      ! Lim_Zero=1.d-20 
          UL(1)=d(i,j-1,k)            ! 1��ӭ��
		  UL(2)=uu(i,j-1,k)
		  UL(3)=v(i,j-1,k)
		  UL(4)=w(i,j-1,k)
		  UL(5)=p(i,j-1,k)
		endif

       if(UR(1) .le. Lim_Zero .or. UR(5) .le. Lim_Zero) then
          UR(1)=d(i,j,k)         ! 1��ӭ��
		  UR(2)=uu(i,j,k)
		  UR(3)=v(i,j,k)
		  UR(4)=w(i,j,k)
		  UR(5)=p(i,j,k)
       endif
     endif






!-----��UL,UR����������ת�任���õ�����ϵ(s1,s2,s3) (�������з���1���з���2) �е��غ����QL,QR
!  ��ֵ
          QL(1)=UL(1)                           ! �ܶȣ�������������ת���ֲ��䣩
          QL(2)=UL(2)*s1x+UL(3)*s1y+UL(4)*s1z   ! ��������ٶȷ���  ��ͶӰ��������
          QL(3)=UL(2)*s2x+UL(3)*s2y+UL(4)*s2z   ! �з���1���ٶȷ���
          QL(4)=UL(2)*s3x+UL(3)*s3y+UL(4)*s3z   ! �з���2���ٶȷ���
          QL(5)=UL(5)                           ! ѹ���������� 
! ��ֵ ������������ͬ�ϣ�
          QR(1)=UR(1)                           
          QR(2)=UR(2)*s1x+UR(3)*s1y+UR(4)*s1z   
          QR(3)=UR(2)*s2x+UR(3)*s2y+UR(4)*s2z   
          QR(4)=UR(2)*s3x+UR(3)*s3y+UR(4)*s3z   
          QR(5)=UR(5)                          
!---------ͨ������ (FVS��FDS), ��������ֵ���㴩�������ͨ��(��չ1ά���⣩-------------
          if(IFlux .eq. Flux_Steger_Warming ) then
            call Flux_steger_warming_1Da(QL,QR,Flux0,gamma)     ! Steger-Warming FVS���� 
          else  if(IFlux .eq. Flux_Roe ) then
            call Flux_Roe_1D(QL,QR,Flux0,gamma)                 ! Roe FDS����
          else  if(IFlux .eq. Flux_Van_Leer ) then
            call Flux_Van_Leer_1Da(QL,QR,Flux0,gamma)           ! Van Leer FVS����
          else  if(IFlux .eq. Flux_Ausm ) then
            call Flux_Ausmpw_1Da(QL,QR,Flux0,gamma)   
          else 
            call Flux_HLL_HLLC_1D(QL,QR,Flux0,gamma,IFlux)      !HLL/HLLC FDS����������Riemann�⣩
          endif
! ---��(s1,s2,s3)����ϵ�µ�ͨ��Flux0 ���б任���õ�(x,y,z)����ϵ�µ�ͨ���� �������ֲ��䣬��������ͶӰ	  
          Flux(1,i,j,k)=-Flux0(1)*B%Sj(i,j,k)                                  ! ����ͨ�� ������������������ת���仯��
          Flux(2,i,j,k)=-(Flux0(2)*s1x+Flux0(3)*s2x+Flux0(4)*s3x)*B%Sj(i,j,k)  ! x����Ķ���ͨ��  ��ͶӰ��x����
          Flux(3,i,j,k)=-(Flux0(2)*s1y+Flux0(3)*s2y+Flux0(4)*s3y)*B%Sj(i,j,k)  ! y����Ķ���ͨ��
          Flux(4,i,j,k)=-(Flux0(2)*s1z+Flux0(3)*s2z+Flux0(4)*s3z)*B%Sj(i,j,k)  ! z����Ķ���ͨ��
          Flux(5,i,j,k)=-Flux0(5)*B%Sj(i,j,k)                                  ! ����ͨ�� �������� 
        enddo
      enddo
    enddo
!$OMP END DO   

!----------------Residual -------------------------------
!$OMP DO   
    do k=1,nz1-1
      do j=1,ny1-1
        do i=1,nx1-1
          do m=1,5
            B%Res(m,i,j,k)=B%Res(m,i,j,k)+Flux(m,i,j+1,k)-Flux(m,i,j,k)           
          enddo
        enddo
      enddo
    enddo
!$OMP END DO  
!$OMP END PARALLEL
 
   end subroutine flux_inviscous_j
!--------------------------------------------------------------------------------------------------------------------
!--------------------------------------------------------------------------------------------------------------------
! ����k�������((I,J,K-1/2)�����ڽ���)����ճͨ�� 
   subroutine flux_inviscous_k(nMesh,mBlock)
    Use Global_Var
    Use Flow_Var
    implicit none
    real(PRE_EC),dimension(5):: UL,UR,QL,QR,Flux0
    real(PRE_EC):: U0(1-LAP:LAP,5)
    integer:: mBlock,i,j,k,m,nx1,ny1,nz1,ksub,nMesh
    integer:: Scheme,IFlux,Reconstruction
    real(PRE_EC):: s1x,s1y,s1z,s2x,s2y,s2z,s3x,s3y,s3z,s0,t10,t1x,t1y,t1z  ! ������(s1)���з���(s2,s3)
    real(PRE_EC):: d0,uu0,v0,w0,p0,E0,un
    Type (Block_TYPE),pointer:: B
    TYPE (Mesh_TYPE),pointer:: MP
    Type (BC_MSG_TYPE),pointer:: Bc
    MP=> Mesh(nMesh)
    B => MP%Block(mBlock)
    Scheme=MP%Iflag_Scheme                  ! ��ֵ��ʽ ����ͬ�����ϲ��ò�ͬ��ʽ��
    IFlux=MP%Iflag_Flux                     ! ͨ������
    Reconstruction=MP%IFlag_Reconstruction  ! �ع���ʽ
    nx1=B%nx ; ny1=B%ny ; nz1=B%nz
    
	Flux=0.d0                               ! ��ʼ��

!$OMP PARALLEL DEFAULT(FIRSTPRIVATE) SHARED(MP,B,IFlux,Reconstruction,nx1,ny1,nz1,gamma,Flux,d,uu,v,w,p)

!$OMP  DO  
    do k=1,nz1 
      do j=1,ny1-1
        do i=1,nx1-1

 !      �趨�߽��ʽ (�����ڵ��ʽ���߽���ʽ)

		   Scheme=MP%Iflag_Scheme
		   if(B%BcK(i,j,1)==1) then            ! �Ƿ�Ϊ����߽�
              if(k .eq. 1) then
 			   Scheme=Scheme_CD2    ! ��1���������2�����ĸ�ʽ �����������񣬱���ͨ���غ㣩  
			  else if( k < LAP ) then                  ! ������߽�
               Scheme=MP%Bound_Scheme            ! �߽��ʽ
			  endif
           endif
	
		   if(B%BcK(i,j,2)==1) then
             if(k .eq. nz1) then
			   Scheme=Scheme_CD2    ! ��1���������2�����ĸ�ʽ �����������񣬱���ͨ���غ㣩  
		     else if( k > nz1-LAP+1 ) then      ! �����ұ߽�
               Scheme=MP%Bound_Scheme            ! �߽��ʽ
			 endif
           endif
           
		   if(B%IF_OverLimit == 1)  Scheme=Scheme_UD1            ! ���������ޣ�����ָ��¶ȣ��� �ÿ����1��ӭ��


          s1x=B%nk1(i,j,k); s1y=B%nk2(i,j,k) ; s1z= B%nk3(i,j,k)  ! ��һ���ķ�����
          t1x=B%x(i+1,j+1,k)-B%x(i,j,k); t1y=B%y(i+1,j+1,k)-B%y(i,j,k) ; t1z=B%z(i+1,j+1,k)-B%z(i,j,k)  ! �Խ���1
          t10=1.d0/(sqrt(t1x*t1x+t1y*t1y+t1z*t1z))  
          s2x=t1x*t10; s2y=t1y*t10; s2z=t1z*t10     ! ��һ�����з���1 ���Խ���1��
          s3x=s1y*s2z-s1z*s2y; s3y=s1z*s2x-s1x*s2z ; s3z= s1x*s2y-s1y*s2x   ! �з���2 �����������з���1: s1*s2��
!--------------------------------------------------------------------------------------------
! �ڵ㣬����2,3�׸�ʽ�ع�  (I,J-1/2,K) ���ֵ��
          if(Reconstruction .eq. Reconst_Original) then
! ʹ��ԭʼ�����ع� U0(:,:) �洢����4�����ϵ��ܶȡ��ٶȡ�ѹ��
              U0(:,1)=d(i,j,k-LAP:k+LAP-1) 
			  U0(:,2)=uu(i,j,k-LAP:k+LAP-1) 
			  U0(:,3)=v(i,j,k-LAP:k+LAP-1)
			  U0(:,4)=w(i,j,k-LAP:k+LAP-1)
			  U0(:,5)=p(i,j,k-LAP:k+LAP-1)
            call Reconstuction_original(U0,UL,UR,gamma,Scheme)          ! ��ֵ��ʽ
          else if (Reconstruction .eq. Reconst_Conservative) then
! ʹ���غ�����ع� U0(:,:) �洢����4�����ϵ��غ�����������ܶȡ������ܶȺ������ܶȣ�
            do m=1,5
              U0(:,m)=B%U(m,i,j,k-LAP:k+LAP-1)
            enddo
            call Reconstuction_conservative(U0,UL,UR,gamma,Scheme)
          else
! �������������ع�
            do m=1,5
              U0(:,m)=B%U(m,i,j,k-LAP:k+LAP-1)
            enddo
            call Reconstuction_Characteristic(U0,UL,UR,gamma,Scheme)
          endif  
!-------�ع��������õ�(I,J-1/2,K)���ϵ�����ֵUL,UR  ��ԭʼ�������ܶȡ��ٶȡ�ѹ����------------

!----��� UL, UR �е��ܶȡ�ѹ���Ƿ�Ϊ�� -------------------------
! ���Ϊ������ʹ��1��ӭ��        
	  if(IF_Scheme_Positivity == 1) then
		if(UL(1) .le. Lim_Zero  .or. UL(5) .le. Lim_Zero) then      ! Lim_Zero=1.d-20 
          UL(1)=d(i,j,k-1)            ! 1��ӭ��
		  UL(2)=uu(i,j,k-1)
		  UL(3)=v(i,j,k-1)
		  UL(4)=w(i,j,k-1)
		  UL(5)=p(i,j,k-1)
		endif

       if(UR(1) .le. Lim_Zero .or. UR(5) .le. Lim_Zero) then
          UR(1)=d(i,j,k)         ! 1��ӭ��
		  UR(2)=uu(i,j,k)
		  UR(3)=v(i,j,k)
		  UR(4)=w(i,j,k)
		  UR(5)=p(i,j,k)
       endif
     endif



!-----��UL,UR����������ת�任���õ�����ϵ(s1,s2,s3) (�������з���1���з���2) �е��غ����QL,QR
!  ��ֵ
          QL(1)=UL(1)                           ! �ܶȣ�������������ת���ֲ��䣩
          QL(2)=UL(2)*s1x+UL(3)*s1y+UL(4)*s1z   ! ��������ٶȷ���  ��ͶӰ��������
          QL(3)=UL(2)*s2x+UL(3)*s2y+UL(4)*s2z   ! �з���1���ٶȷ���
          QL(4)=UL(2)*s3x+UL(3)*s3y+UL(4)*s3z   ! �з���2���ٶȷ���
          QL(5)=UL(5)                           ! ѹ���������� 
! ��ֵ ������������ͬ�ϣ�
          QR(1)=UR(1)                           
          QR(2)=UR(2)*s1x+UR(3)*s1y+UR(4)*s1z   
          QR(3)=UR(2)*s2x+UR(3)*s2y+UR(4)*s2z   
          QR(4)=UR(2)*s3x+UR(3)*s3y+UR(4)*s3z   
          QR(5)=UR(5)                          
!---------ͨ������ (FVS��FDS), ��������ֵ���㴩�������ͨ��(��չ1ά���⣩-------------
          if(IFlux .eq. Flux_Steger_Warming ) then
            call Flux_steger_warming_1Da(QL,QR,Flux0,gamma)     ! Steger-Warming FVS���� 
          else  if(IFlux .eq. Flux_Roe ) then
            call Flux_Roe_1D(QL,QR,Flux0,gamma)                ! Roe FDS����
          else  if(IFlux .eq. Flux_Van_Leer ) then
            call Flux_Van_Leer_1Da(QL,QR,Flux0,gamma)          ! Van Leer FVS����
          else  if(IFlux .eq. Flux_Ausm ) then
            call Flux_Ausmpw_1Da(QL,QR,Flux0,gamma)   
          else
            call Flux_HLL_HLLC_1D(QL,QR,Flux0,gamma,IFlux)    !HLL/HLLC FDS����������Riemann�⣩
          endif
! ---��(s1,s2,s3)����ϵ�µ�ͨ��Flux0 ���б任���õ�(x,y,z)����ϵ�µ�ͨ���� �������ֲ��䣬��������ͶӰ
	  
          Flux(1,i,j,k)=-Flux0(1)*B%Sk(i,j,k)                                  ! ����ͨ�� ������������������ת���仯��
          Flux(2,i,j,k)=-(Flux0(2)*s1x+Flux0(3)*s2x+Flux0(4)*s3x)*B%Sk(i,j,k)  ! x����Ķ���ͨ��  ��ͶӰ��x����
          Flux(3,i,j,k)=-(Flux0(2)*s1y+Flux0(3)*s2y+Flux0(4)*s3y)*B%Sk(i,j,k)  ! y����Ķ���ͨ��
          Flux(4,i,j,k)=-(Flux0(2)*s1z+Flux0(3)*s2z+Flux0(4)*s3z)*B%Sk(i,j,k)  ! z����Ķ���ͨ��
          Flux(5,i,j,k)=-Flux0(5)*B%Sk(i,j,k)                                  ! ����ͨ�� ��������
        enddo
      enddo
    enddo
!$OMP END DO  

!---------------------------------------------------------------
!  �߽紦��
!$OMP  DO  
    do  ksub=1,B%subface
      Bc=> B%bc_msg(ksub)
      if(Bc%bc .gt. 0  .and. (Bc%face .eq. 3 .or. Bc%face .eq. 6)) then   ! ���ڱ߽磬��Ϊk-��k+�߽�
        k=Bc%kb
        do j= Bc%jb, Bc%je-1
          do i= Bc%ib, Bc%ie-1
            d0=(d(i,j,k)+d(i,j,k-1))*0.5d0 
            uu0=(uu(i,j,k)+uu(i,j,k-1))*0.5d0 
            v0=(v(i,j,k)+v(i,j,k-1))*0.5d0 
            w0=(w(i,j,k)+w(i,j,k-1))*0.5d0
            p0=(p(i,j,k)+p(i,j,k-1))*0.5d0
            E0=p0/(gamma-1.d0)+d0*(uu0*uu0+v0*v0+w0*w0)*0.5d0
            un=uu0*B%nk1(i,j,k)+v0*B%nk2(i,j,k)+w0*B%nk3(i,j,k)          ! �����ٶ�       
            Flux(1,i,j,k)=-d0*un*B%Sk(i,j,k)
            Flux(2,i,j,k)=-(d0*un*uu0+p0*B%nk1(i,j,k))*B%Sk(i,j,k)
            Flux(3,i,j,k)=-(d0*un*v0+p0*B%nk2(i,j,k))*B%Sk(i,j,k)
            Flux(4,i,j,k)=-(d0*un*w0+p0*B%nk3(i,j,k))*B%Sk(i,j,k)
            Flux(5,i,j,k)=-(E0+p0)*un*B%Sk(i,j,k)
          enddo
        enddo
      endif
    enddo
!$OMP END DO  

!----------------Residual -------------------------------
!$OMP  DO  
    do k=1,nz1-1
      do j=1,ny1-1
        do i=1,nx1-1
          do m=1,5
            B%Res(m,i,j,k)=B%Res(m,i,j,k)+Flux(m,i,j,k+1)-Flux(m,i,j,k)           
          enddo
        enddo
      enddo
    enddo
!$OMP END DO  
!$OMP END PARALLEL

   end subroutine flux_inviscous_k

!----------------ճ��ͨ��---------------------------------------------------------------------------------------------- 
!--------------------------------------------------------------------------------------------------------------------
!-----------i-�����ճ��ͨ��-----------------------------------------------------------------  
! Ϊ�˱�֤�ȶ��ԣ�����ʹ�ü�����ǲ�������㣨�� (0,0,k), (0,j,0) ������㴦��ֵ��

   subroutine flux_viscous_i(nMesh,mBlock)
    Use Global_Var
    Use Flow_Var
    implicit none
    integer:: mBlock,i,j,k,m,nx,ny,nz,nMesh
    real(PRE_EC):: ix,iy,iz,jx,jy,jz,kx,ky,kz,s1x,s1y,s1z,ui,vi,wi,Ti,uj,vj,wj,Tj,uk,vk,wk,Tk
    real(PRE_EC):: ux,uy,uz,vx,vy,vz,wx,wy,wz,Tx,Ty,Tz
    real(PRE_EC):: s11,s12,s13,s22,s23,s33,u1,v1,w1,E1,E2,E3
    real(PRE_EC):: mu0,k0
    real(PRE_EC):: tmp1,tmp2
    real(PRE_EC):: ui1,ui2,uj1,uj2,uk1,uk2,vi1,vi2,vj1,vj2,vk1,vk2, &
	               wi1,wi2,wj1,wj2,wk1,wk2,Ti1,Ti2,Tj1,Tj2,Tk1,Tk2

    Type (Block_TYPE),pointer:: B
    TYPE (Mesh_TYPE),pointer:: MP
    MP=> Mesh(nMesh)
    B => MP%Block(mBlock)
    nx=B%nx; ny=B%ny; nz=B%nz
    tmp1=4.d0/3.d0; tmp2=2.d0/3.d0


! revised 2017-7-11
if(B%IF_OverLimit == 1 ) then     ! ���������ޣ� ����1��ӭ�������ճ�ԣ� ������ճ����

!$OMP  PARALLEL DO  
   do k=1,nz-1 
   do j=1,ny-1
     B%Surf1(j,k,1)=0.d0
     B%Surf1(j,k,2)=0.d0
     B%Surf1(j,k,3)=0.d0
     B%Surf4(j,k,1)=0.d0
     B%Surf4(j,k,2)=0.d0
     B%Surf4(j,k,3)=0.d0
   enddo
   enddo
!$OMP END  PARALLEL DO  

	return             ! ����ճ�������
endif

!$OMP PARALLEL DEFAULT(FIRSTPRIVATE) SHARED(MP,B,nx,ny,nz,tmp1,tmp2,Cp,PrL,PrT,uu,v,w,T,flux)

!$OMP  DO  
    do k=1,nz-1 
      do j=1,ny-1
        do i=1,nx
          s1x=B%ni1(i,j,k); s1y=B%ni2(i,j,k) ; s1z= B%ni3(i,j,k)  ! ��һ���ķ�����
! ���������ڼ������꣨�±꣩�ĵ���;  (I-1/2,J,K)��
! ע�⣬�������洢���������ģ������꣨�洢������ڵ㣩������
! ���������ö������Ĳ�ּ��㣬��������Χ����㵼����ƽ��
! e.g. uj(I-1/2,J,K)=0.5*(uj(I,J,K)+uj(I-1,J,K));  uj(I,J,K)=(uu(I,J+1,k)-uu(I,J-1,K))*0.5
          ui=uu(i,j,k)-uu(i-1,j,k)              ! du/di (I-1/2,J,K)= u(I,J,K)-u(I-1,J,K)
          vi=v(i,j,k)-v(i-1,j,k)
          wi=w(i,j,k)-w(i-1,j,k)
          Ti=T(i,j,k)-T(i-1,j,k)
  
  ! Ϊ�˱�֤�ȶ��ԣ�����ʹ�ü�����ǲ�������㣨�� (0,0,k), (0,j,0) ������㴦��ֵ��
      
		  if( (i==1 .or. i==B%nx) .and. (j==1 .or. j==B%ny-1) ) then
           
		   uj1=0.d0; vj1=0.d0; wj1=0.d0; Tj1=0.d0
		   uj2=0.d0; vj2=0.d0; wj2=0.d0; Tj2=0.d0
		   		 
		  else 
		   uj1=0.5d0*(uu(i,j-1,k)+uu(i-1,j-1,k))
		   vj1=0.5d0*(v(i,j-1,k)+v(i-1,j-1,k))
		   wj1=0.5d0*(w(i,j-1,k)+w(i-1,j-1,k))
		   Tj1=0.5d0*(T(i,j-1,k)+T(i-1,j-1,k))
		   uj2=0.5d0*(uu(i,j+1,k)+uu(i-1,j+1,k))
		   vj2=0.5d0*(v(i,j+1,k)+v(i-1,j+1,k))
		   wj2=0.5d0*(w(i,j+1,k)+w(i-1,j+1,k))
		   Tj2=0.5d0*(T(i,j+1,k)+T(i-1,j+1,k))
          endif
        
          if( (i==1 .or. i==B%nx) .and. (k==1 .or. k==B%nz-1) ) then

 		   uk1=0.d0; vk1=0.d0; wk1=0.d0; Tk1=0.d0
		   uk2=0.d0; vk2=0.d0; wk2=0.d0; Tk2=0.d0
		 
		  else
            uk1=0.5d0*(uu(i,j,k-1)+uu(i-1,j,k-1))
            vk1=0.5d0*(v(i,j,k-1)+v(i-1,j,k-1))
            wk1=0.5d0*(w(i,j,k-1)+w(i-1,j,k-1))
            Tk1=0.5d0*(T(i,j,k-1)+T(i-1,j,k-1))
            uk2=0.5d0*(uu(i,j,k+1)+uu(i-1,j,k+1))
            vk2=0.5d0*(v(i,j,k+1)+v(i-1,j,k+1))
            wk2=0.5d0*(w(i,j,k+1)+w(i-1,j,k+1))
            Tk2=0.5d0*(T(i,j,k+1)+T(i-1,j,k+1))
          endif
 		   uj=0.5d0*(uj2-uj1)
 		   vj=0.5d0*(vj2-vj1)
 		   wj=0.5d0*(wj2-wj1)
 		   Tj=0.5d0*(Tj2-Tj1)
 		   uk=0.5d0*(uk2-uk1)
		   vk=0.5d0*(vk2-vk1)
		   wk=0.5d0*(wk2-wk1)
		   Tk=0.5d0*(Tk2-Tk1)

          ix=B%ix1(i,j,k); iy=B%iy1(i,j,k); iz=B%iz1(i,j,k)
          jx=B%jx1(i,j,k); jy=B%jy1(i,j,k); jz=B%jz1(i,j,k)
          kx=B%kx1(i,j,k); ky=B%ky1(i,j,k); kz=B%kz1(i,j,k)

!----�����������ƫ����----------------------------------------------
          ux=ui*ix+uj*jx+uk*kx
          vx=vi*ix+vj*jx+vk*kx
          wx=wi*ix+wj*jx+wk*kx
          Tx=Ti*ix+Tj*jx+Tk*kx

          uy=ui*iy+uj*jy+uk*ky
          vy=vi*iy+vj*jy+vk*ky
          wy=wi*iy+wj*jy+wk*ky
          Ty=Ti*iy+Tj*jy+Tk*ky

          uz=ui*iz+uj*jz+uk*kz
          vz=vi*iz+vj*jz+vk*kz
          wz=wi*iz+wj*jz+wk*kz
          Tz=Ti*iz+Tj*jz+Tk*kz

!---ճ��Ӧ��----------------------------------------------------------
    ! (I-1/2,J,k)��, �� (i,j+1/2,k+1/2)�� ����ճ��ϵ��
         mu0=0.5d0*(B%mu(i,j,k)+B%mu_t(i,j,k) + B%mu(i-1,j,k)+B%mu_t(i-1,j,k))  
         k0=0.5d0*Cp*(B%mu(i,j,k)/PrL + B%mu_t(i,j,k)/PrT + B%mu(i-1,j,k)/PrL +B%mu_t(i-1,j,k)/PrT)   ! (I-1/2,J,K) ����ȴ���ϵ��
!-----------------------------------------------------------
         s11=mu0*(tmp1*ux-tmp2*(vy+wz))    ! tmp1=4.d0/3.d0; tmp2=2.d0/3.d0
         s12=mu0*(uy+vx)
         s13=mu0*(uz+wx)
         s22=mu0*(tmp1*vy-tmp2*(ux+wz))
         s23=mu0*(vz+wy)
         s33=mu0*(tmp1*wz-tmp2*(ux+vy))
!---(I-1/2,J,K)���ϵ��ٶ�--------------------------------------------   
         u1=(uu(i,j,k)+uu(i-1,j,k))*0.5d0
         v1=(v(i,j,k)+v(i-1,j,k))*0.5d0
         w1=(w(i,j,k)+w(i-1,j,k))*0.5d0
!--������ճ��ͨ��-------------------------------
         E1=u1*s11+v1*s12+w1*s13+k0*Tx
         E2=u1*s12+v1*s22+w1*s23+k0*Ty
         E3=u1*s13+v1*s23+w1*s33+k0*Tz
!-------ͨ��=��ճͨ��+ճ��ͨ��---------------------------------------
! ճ��ͨ��=Fv.n=Fv1*s1x+Fv2*s1y+Fv3*s1z---------------
         Flux(2,i,j,k)= (s11*s1x+s12*s1y+s13*s1z)* B%Si(i,j,k)  
         Flux(3,i,j,k)= (s12*s1x+s22*s1y+s23*s1z)* B%Si(i,j,k)
         Flux(4,i,j,k)= (s13*s1x+s23*s1y+s33*s1z)* B%Si(i,j,k)
         Flux(5,i,j,k)= (E1*s1x+E2*s1y+E3*s1z)* B%Si(i,j,k)
!----------------------------------------------------------
      enddo
    enddo
  enddo
!$OMP END DO  

!---------------------------------------------------------
!$OMP  DO  

     do k=1,nz-1
     do j=1,ny-1
     do i=1,nx-1
     do m=2,5
      B%Res(m,i,j,k)=B%Res(m,i,j,k)+Flux(m,i+1,j,k)-Flux(m,i,j,k)           
     enddo
     enddo
     enddo
     enddo
!$OMP END DO  

!---��¼�߽紦��ճ����-------------------------------------
!$OMP  DO  
   do k=1,nz-1 
   do j=1,ny-1
     B%Surf1(j,k,1)=Flux(2,1,j,k)
     B%Surf1(j,k,2)=Flux(3,1,j,k)
     B%Surf1(j,k,3)=Flux(4,1,j,k)
     B%Surf4(j,k,1)=Flux(2,nx,j,k)
     B%Surf4(j,k,2)=Flux(3,nx,j,k)
     B%Surf4(j,k,3)=Flux(4,nx,j,k)
   enddo
   enddo
!$OMP END DO  
!$OMP  END PARALLEL

 end subroutine flux_viscous_i

!----------------------------------------------------------------------------------------------------
!----------------------------------------------------------------------------------------------------
! j�����ճ��ͨ��   
   subroutine flux_viscous_j(nMesh,mBlock)
   Use Global_Var
   Use Flow_Var
   implicit none
   integer:: mBlock,i,j,k,m,nx,ny,nz,nMesh
   real(PRE_EC):: s1x,s1y,s1z
   real(PRE_EC):: ix,iy,iz,jx,jy,jz,kx,ky,kz,ui,vi,wi,Ti,uj,vj,wj,Tj,uk,vk,wk,Tk
   real(PRE_EC):: ux,uy,uz,vx,vy,vz,wx,wy,wz,Tx,Ty,Tz
   real(PRE_EC):: s11,s12,s13,s22,s23,s33,u1,v1,w1,E1,E2,E3
   real(PRE_EC):: mu0,k0
   real(PRE_EC):: tmp1,tmp2
   Type (Block_TYPE),pointer:: B
   TYPE (Mesh_TYPE),pointer:: MP
   real(PRE_EC):: ui1,ui2,uj1,uj2,uk1,uk2,vi1,vi2,vj1,vj2,vk1,vk2, &
	               wi1,wi2,wj1,wj2,wk1,wk2,Ti1,Ti2,Tj1,Tj2,Tk1,Tk2
   
   MP=> Mesh(nMesh)
   B => MP%Block(mBlock)
   nx=B%nx; ny=B%ny; nz=B%nz

   tmp1=4.d0/3.d0; tmp2=2.d0/3.d0

  if(B%IF_OverLimit == 1 ) then     ! ���������ޣ� ����1��ӭ�������ճ�ԣ� ������ճ����
 !$OMP Parallel DO
   do k=1,nz-1 
   do i=1,nx-1
     B%Surf2(i,k,1)=0.d0
     B%Surf2(i,k,2)=0.d0
     B%Surf2(i,k,3)=0.d0
     B%Surf5(i,k,1)=0.d0
     B%Surf5(i,k,2)=0.d0
     B%Surf5(i,k,3)=0.d0
   enddo
   enddo
!$OMP END Parallel DO
   return
   endif


!$OMP PARALLEL DEFAULT(FIRSTPRIVATE) SHARED(MP,B,nx,ny,nz,tmp1,tmp2,Cp,PrL,PrT,uu,v,w,T,flux)
!$OMP DO
   do k=1,nz-1 
   do j=1,ny
   do i=1,nx-1
    s1x=B%nj1(i,j,k); s1y=B%nj2(i,j,k) ; s1z= B%nj3(i,j,k)  ! ��һ���ķ�����

! ���������ڼ������꣨�±꣩�ĵ���;  (I,J-1/2,K)��
   uj=uu(i,j,k)-uu(i,j-1,k)
   vj=v(i,j,k)-v(i,j-1,k)
   wj=w(i,j,k)-w(i,j-1,k)
   Tj=T(i,j,k)-T(i,j-1,k)


	   if( (j==1 .or. j==B%ny) .and. (i==1 .or. i==B%nx-1) ) then
 
 	    ui1=0.d0; vi1=0.d0; wi1=0.d0; Ti1=0.d0
	    ui2=0.d0; vi2=0.d0; wi2=0.d0; Ti2=0.d0

	   else
		ui1=0.5d0*(uu(i-1,j,k)+uu(i-1,j-1,k))
		vi1=0.5d0*(v(i-1,j,k)+v(i-1,j-1,k))
		wi1=0.5d0*(w(i-1,j,k)+w(i-1,j-1,k))
		Ti1=0.5d0*(T(i-1,j,k)+T(i-1,j-1,k))
		ui2=0.5d0*(uu(i+1,j,k)+uu(i+1,j-1,k))
		vi2=0.5d0*(v(i+1,j,k)+v(i+1,j-1,k))
		wi2=0.5d0*(w(i+1,j,k)+w(i+1,j-1,k))
		Ti2=0.5d0*(T(i+1,j,k)+T(i+1,j-1,k))
       endif
	
	   if( (j==1 .or. j==B%ny) .and. (k==1 .or. k==B%nz-1) ) then
   		   uk1=0.d0; vk1=0.d0; wk1=0.d0; Tk1=0.d0
		   uk2=0.d0; vk2=0.d0; wk2=0.d0; Tk2=0.d0

	   else	 
		 uk1=0.5d0*(uu(i,j,k-1)+uu(i,j-1,k-1))
		 vk1=0.5d0*(v(i,j,k-1)+v(i,j-1,k-1))
		 wk1=0.5d0*(w(i,j,k-1)+w(i,j-1,k-1))
		 Tk1=0.5d0*(T(i,j,k-1)+T(i,j-1,k-1))
		 uk2=0.5d0*(uu(i,j,k+1)+uu(i,j-1,k+1))
		 vk2=0.5d0*(v(i,j,k+1)+v(i,j-1,k+1))
		 wk2=0.5d0*(w(i,j,k+1)+w(i,j-1,k+1))
		 Tk2=0.5d0*(T(i,j,k+1)+T(i,j-1,k+1))
       endif
	    ui=0.5d0*(ui2-ui1)
	    vi=0.5d0*(vi2-vi1)
	    wi=0.5d0*(wi2-wi1)
	    Ti=0.5d0*(Ti2-Ti1)
	    uk=0.5d0*(uk2-uk1)
	    vk=0.5d0*(vk2-vk1)
	    wk=0.5d0*(wk2-wk1)
	    Tk=0.5d0*(Tk2-Tk1)


      ix=B%ix2(i,j,k); iy=B%iy2(i,j,k); iz=B%iz2(i,j,k)
      jx=B%jx2(i,j,k); jy=B%jy2(i,j,k); jz=B%jz2(i,j,k)
      kx=B%kx2(i,j,k); ky=B%ky2(i,j,k); kz=B%kz2(i,j,k)

!----�����������ƫ����----------------------------------------------
   ux=ui*ix+uj*jx+uk*kx
   vx=vi*ix+vj*jx+vk*kx
   wx=wi*ix+wj*jx+wk*kx
   Tx=Ti*ix+Tj*jx+Tk*kx

   uy=ui*iy+uj*jy+uk*ky
   vy=vi*iy+vj*jy+vk*ky
   wy=wi*iy+wj*jy+wk*ky
   Ty=Ti*iy+Tj*jy+Tk*ky

   uz=ui*iz+uj*jz+uk*kz
   vz=vi*iz+vj*jz+vk*kz
   wz=wi*iz+wj*jz+wk*kz
   Tz=Ti*iz+Tj*jz+Tk*kz

!---ճ��Ӧ��----------------------------------------------------------
   mu0=0.5d0*(B%mu(i,j,k)+B%mu_t(i,j,k) + B%mu(i,j-1,k)+B%mu_t(i,j-1,k))  
   k0=0.5d0*Cp*(B%mu(i,j,k)/PrL + B%mu_t(i,j,k)/PrT + B%mu(i,j-1,k)/PrL +B%mu_t(i,j-1,k)/PrT)   ! (I-1/2,J,K) ����ȴ���ϵ��
   
   s11=mu0*(tmp1*ux-tmp2*(vy+wz))    ! tmp1=4.d0/3.d0; tmp2=2.d0/3.d0
   s12=mu0*(uy+vx)
   s13=mu0*(uz+wx)
   s22=mu0*(tmp1*vy-tmp2*(ux+wz))
   s23=mu0*(vz+wy)
   s33=mu0*(tmp1*wz-tmp2*(ux+vy))
!---(I,J-1/2,K)���ϵ��ٶ�--------------------------------------------   
   u1=(uu(i,j,k)+uu(i,j-1,k))*0.5d0
   v1=(v(i,j,k)+v(i,j-1,k))*0.5d0
   w1=(w(i,j,k)+w(i,j-1,k))*0.5d0
!--������ճ��ͨ��-------------------------------
   E1=u1*s11+v1*s12+w1*s13+k0*Tx
   E2=u1*s12+v1*s22+w1*s23+k0*Ty
   E3=u1*s13+v1*s23+w1*s33+k0*Tz

!-------ͨ��=��ճͨ��+ճ��ͨ��---------------------------------------
! ճ��ͨ��=Fv.n=Fv1*s1x+Fv2*s1y+Fv3*s1z---------------
    Flux(2,i,j,k)=(s11*s1x+s12*s1y+s13*s1z)* B%Sj(i,j,k)  
    Flux(3,i,j,k)=(s12*s1x+s22*s1y+s23*s1z)* B%Sj(i,j,k)
    Flux(4,i,j,k)=(s13*s1x+s23*s1y+s33*s1z)* B%Sj(i,j,k)
    Flux(5,i,j,k)=(E1*s1x+E2*s1y+E3*s1z)* B%Sj(i,j,k)

   enddo
   enddo
   enddo
!$OMP END DO

!$OMP DO
     do k=1,nz-1
     do j=1,ny-1
     do i=1,nx-1
     do m=2,5
      B%Res(m,i,j,k)=B%Res(m,i,j,k)+Flux(m,i,j+1,k)-Flux(m,i,j,k)           
     enddo
     enddo
     enddo
     enddo
!$OMP END DO

!---��¼�߽紦��ճ����-------------------------------------

!$OMP  DO
   do k=1,nz-1 
   do i=1,nx-1
     B%Surf2(i,k,1)=Flux(2,i,1,k)
     B%Surf2(i,k,2)=Flux(3,i,1,k)
     B%Surf2(i,k,3)=Flux(4,i,1,k)
     B%Surf5(i,k,1)=Flux(2,i,ny,k)
     B%Surf5(i,k,2)=Flux(3,i,ny,k)
     B%Surf5(i,k,3)=Flux(4,i,ny,k)
   enddo
   enddo
!$OMP END DO
!$OMP END PARALLEL


 end subroutine flux_viscous_j
 
!------------------------------------------------------------------------------------------------------------- 
!------------------------------------------------------------------------------------------------------------- 
! k�����ճ��ͨ��   
   subroutine flux_viscous_k(nMesh,mBlock)
   Use Global_Var
   Use Flow_Var
   implicit none
   integer:: mBlock,i,j,k,m,nx,ny,nz,nMesh
   real(PRE_EC):: s1x,s1y,s1z
   real(PRE_EC):: ix,iy,iz,jx,jy,jz,kx,ky,kz,ui,vi,wi,Ti,uj,vj,wj,Tj,uk,vk,wk,Tk
   real(PRE_EC):: ux,uy,uz,vx,vy,vz,wx,wy,wz,Tx,Ty,Tz
   real(PRE_EC):: s11,s12,s13,s22,s23,s33,u1,v1,w1,E1,E2,E3
   real(PRE_EC):: mu0,k0
   real(PRE_EC):: tmp1,tmp2
   Type (Block_TYPE),pointer:: B
   TYPE (Mesh_TYPE),pointer:: MP
   real(PRE_EC):: ui1,ui2,uj1,uj2,uk1,uk2,vi1,vi2,vj1,vj2,vk1,vk2, &
	               wi1,wi2,wj1,wj2,wk1,wk2,Ti1,Ti2,Tj1,Tj2,Tk1,Tk2

   MP=> Mesh(nMesh)
   B => MP%Block(mBlock)
   nx=B%nx; ny=B%ny; nz=B%nz

   tmp1=4.d0/3.d0; tmp2=2.d0/3.d0

 if(B%IF_OverLimit == 1 ) then     ! ���������ޣ� ����1��ӭ�������ճ�ԣ� ������ճ����
!$OMP  Parallel DO
   do j=1,ny-1 
   do i=1,nx-1
     B%Surf3(i,j,1)=0.d0
     B%Surf3(i,j,2)=0.d0
     B%Surf3(i,j,3)=0.d0
     B%Surf6(i,j,1)=0.d0
     B%Surf6(i,j,2)=0.d0
     B%Surf6(i,j,3)=0.d0
   enddo
   enddo
!$OMP END Parallel DO
 return
  endif



!$OMP PARALLEL DEFAULT(FIRSTPRIVATE) SHARED(MP,B,nx,ny,nz,tmp1,tmp2,Cp,PrL,PrT,uu,v,w,T,flux)

!$OMP  DO
   do k=1,nz 
   do j=1,ny-1
   do i=1,nx-1
    s1x=B%nk1(i,j,k); s1y=B%nk2(i,j,k) ; s1z= B%nk3(i,j,k)  ! ��һ���ķ�����

! ���������ڼ������꣨�±꣩�ĵ���;  (I,J,K-1/2)��

   uk=uu(i,j,k)-uu(i,j,k-1)
   vk=v(i,j,k)-v(i,j,k-1)
   wk=w(i,j,k)-w(i,j,k-1)
   Tk=T(i,j,k)-T(i,j,k-1)

 	 if( (k==1 .or. k==B%nz) .and. (i==1 .or. i==B%nx-1) ) then
 	    ui1=0.d0; vi1=0.d0; wi1=0.d0; Ti1=0.d0
	    ui2=0.d0; vi2=0.d0; wi2=0.d0; Ti2=0.d0
    
	 else
	  ui1=0.5d0*(uu(i-1,j,k)+uu(i-1,j,k-1))
	  vi1=0.5d0*(v(i-1,j,k)+v(i-1,j,k-1))
	  wi1=0.5d0*(w(i-1,j,k)+w(i-1,j,k-1))
	  Ti1=0.5d0*(T(i-1,j,k)+T(i-1,j,k-1))
	  ui2=0.5d0*(uu(i+1,j,k)+uu(i+1,j,k-1))
	  vi2=0.5d0*(v(i+1,j,k)+v(i+1,j,k-1))
	  wi2=0.5d0*(w(i+1,j,k)+w(i+1,j,k-1))
	  Ti2=0.5d0*(T(i+1,j,k)+T(i+1,j,k-1))
     endif

  	 if( (k==1 .or. k==B%nz) .and. (j==1 .or. j==B%ny-1) ) then
	   uj1=0.d0; vj1=0.d0; wj1=0.d0; Tj1=0.d0
	   uj2=0.d0; vj2=0.d0; wj2=0.d0; Tj2=0.d0

	 else
      uj1=0.5d0*(uu(i,j-1,k)+uu(i,j-1,k-1))
      vj1=0.5d0*(v(i,j-1,k)+v(i,j-1,k-1))
      wj1=0.5d0*(w(i,j-1,k)+w(i,j-1,k-1))
      Tj1=0.5d0*(T(i,j-1,k)+T(i,j-1,k-1))
      uj2=0.5d0*(uu(i,j+1,k)+uu(i,j+1,k-1))
      vj2=0.5d0*(v(i,j+1,k)+v(i,j+1,k-1))
      wj2=0.5d0*(w(i,j+1,k)+w(i,j+1,k-1))
      Tj2=0.5d0*(T(i,j+1,k)+T(i,j+1,k-1))
	 endif
	  ui=0.5d0*(ui2-ui1)
	  vi=0.5d0*(vi2-vi1)
	  wi=0.5d0*(wi2-wi1)
	  Ti=0.5d0*(Ti2-Ti1)

	  uj=0.5d0*(uj2-uj1)
	  vj=0.5d0*(vj2-vj1)
	  wj=0.5d0*(wj2-wj1)
	  Tj=0.5d0*(Tj2-Tj1)


      ix=B%ix3(i,j,k); iy=B%iy3(i,j,k); iz=B%iz3(i,j,k)
      jx=B%jx3(i,j,k); jy=B%jy3(i,j,k); jz=B%jz3(i,j,k)
      kx=B%kx3(i,j,k); ky=B%ky3(i,j,k); kz=B%kz3(i,j,k)

!----�����������ƫ����----------------------------------------------
   ux=ui*ix+uj*jx+uk*kx
   vx=vi*ix+vj*jx+vk*kx
   wx=wi*ix+wj*jx+wk*kx
   Tx=Ti*ix+Tj*jx+Tk*kx

   uy=ui*iy+uj*jy+uk*ky
   vy=vi*iy+vj*jy+vk*ky
   wy=wi*iy+wj*jy+wk*ky
   Ty=Ti*iy+Tj*jy+Tk*ky

   uz=ui*iz+uj*jz+uk*kz
   vz=vi*iz+vj*jz+vk*kz
   wz=wi*iz+wj*jz+wk*kz
   Tz=Ti*iz+Tj*jz+Tk*kz

!---ճ��Ӧ��----------------------------------------------------------
   mu0=0.5d0*(B%mu(i,j,k)+B%mu_t(i,j,k) + B%mu(i,j,k-1)+B%mu_t(i,j,k-1))          ! (I,J,k-1/2)���ճ��ϵ�� ������+������  
   k0=0.5d0*Cp*(B%mu(i,j,k)/PrL + B%mu_t(i,j,k)/PrT + B%mu(i,j,k-1)/PrL +B%mu_t(i,j,k-1)/PrT)   ! (I,J,K-1/2) ����ȴ���ϵ��

   s11=mu0*(tmp1*ux-tmp2*(vy+wz))    ! tmp1=4.d0/3.d0; tmp2=2.d0/3.d0
   s12=mu0*(uy+vx)
   s13=mu0*(uz+wx)
   s22=mu0*(tmp1*vy-tmp2*(ux+wz))
   s23=mu0*(vz+wy)
   s33=mu0*(tmp1*wz-tmp2*(ux+vy))

!---(I,J,K-1/2)���ϵ��ٶ�--------------------------------------------   
   u1=(uu(i,j,k)+uu(i,j,k-1))*0.5d0
   v1=(v(i,j,k)+v(i,j,k-1))*0.5d0
   w1=(w(i,j,k)+w(i,j,k-1))*0.5d0
!--������ճ��ͨ��-------------------------------
   E1=u1*s11+v1*s12+w1*s13+k0*Tx
   E2=u1*s12+v1*s22+w1*s23+k0*Ty
   E3=u1*s13+v1*s23+w1*s33+k0*Tz
!-------ͨ��=��ճͨ��+ճ��ͨ��---------------------------------------
! ճ��ͨ��=Fv.n=Fv1*s1x+Fv2*s1y+Fv3*s1z---------------
    Flux(2,i,j,k)=(s11*s1x+s12*s1y+s13*s1z)* B%Sk(i,j,k)  
    Flux(3,i,j,k)=(s12*s1x+s22*s1y+s23*s1z)* B%Sk(i,j,k)
    Flux(4,i,j,k)=(s13*s1x+s23*s1y+s33*s1z)* B%Sk(i,j,k)
    Flux(5,i,j,k)=(E1*s1x+E2*s1y+E3*s1z)* B%Sk(i,j,k)
!--------------------------------------------------------------------  
   enddo
   enddo
   enddo
!$OMP END DO

!$OMP  DO
     do k=1,nz-1
     do j=1,ny-1
     do i=1,nx-1
     do m=2,5
      B%Res(m,i,j,k)=B%Res(m,i,j,k)+Flux(m,i,j,k+1)-Flux(m,i,j,k)           
     enddo
	 enddo
     enddo
     enddo
!$OMP END DO

!---��¼�߽紦��ճ����-------------------------------------
!$OMP  DO
   do j=1,ny-1 
   do i=1,nx-1
     B%Surf3(i,j,1)=Flux(2,i,j,1)
     B%Surf3(i,j,2)=Flux(3,i,j,1)
     B%Surf3(i,j,3)=Flux(4,i,j,1)
     B%Surf6(i,j,1)=Flux(2,i,j,nz)
     B%Surf6(i,j,2)=Flux(3,i,j,nz)
     B%Surf6(i,j,3)=Flux(4,i,j,nz)
   enddo
   enddo
!$OMP END DO
!$OMP END PARALLEL


 end subroutine flux_viscous_k








!--------------------------------------------------------------------------
! ԭʼ�����ع�  
   subroutine Reconstuction_original(U0,UL,UR,gamma,Iflag_Scheme)
     use  const_var
  	 implicit none
     real(PRE_EC):: U0(1-LAP:LAP,5) ,UL(5),UR(5),gamma
     integer:: Iflag_Scheme,m
!    U0(k,m) : k=1,4 for  i-2,i-1,i,i+1    ;   m=1,5 for d,u,v,w,p
     do m=1,5
       call scheme_fP(UL(m),U0(:,m),Iflag_Scheme) 
       call scheme_fm(UR(m),U0(:,m),Iflag_Scheme) 
     enddo
   end subroutine Reconstuction_original

! �غ�����ع�
   subroutine Reconstuction_conservative(U0,UL,UR,gamma,Iflag_Scheme)
     use  const_var
   	 implicit none
     real(PRE_EC):: U0(1-LAP:LAP,5),UL(5),UR(5),QL(5),QR(5),gamma
     integer:: Iflag_Scheme,m
!    U0(k,m) : k=1,4 for  i-2,i-1,i,i+1   ; m for the conservative variables U0(1,m)=d, U0(2,m)=d*u, ....
     do m=1,5
        call scheme_fP(QL(m),U0(:,m),Iflag_Scheme) 
        call scheme_fm(QR(m),U0(:,m),Iflag_Scheme) 
      enddo
!          find a bug  UL(4)=(QL(4)-(UL(2)*QL(2)+ .... 
       UL(1)=QL(1); UL(2)=QL(2)/UL(1); UL(3)=QL(3)/UL(1); UL(4)=QL(4)/UL(1)    ! density and velocities
       UL(5)=(QL(5)-(UL(2)*QL(2)+UL(3)*QL(3)+UL(4)*QL(4))*0.5d0)*(gamma-1.d0)  ! pressure
       UR(1)=QR(1); UR(2)=QR(2)/UR(1); UR(3)=QR(3)/UR(1); UR(4)=QR(4)/UR(1) 
       UR(5)=(QR(5)-(UR(2)*QR(2)+UR(3)*QR(3)+UR(4)*QR(4))*0.5d0)*(gamma-1.d0)  ! pressure
   end subroutine Reconstuction_conservative


!------------------------------ ���������ع� --------------------------------------------------
! ���������ҿ���
   subroutine Reconstuction_Characteristic(U0,UL,UR,gamma,Iflag_Scheme)
   use  const_var
   implicit none
   real(PRE_EC):: U0(1-LAP:LAP,5),V0(1-LAP:LAP,5),UL(5),UR(5),gamma
   real(PRE_EC):: Uh(5),S(5,5),S1(5,5),VL(5),VR(5),QL(5),QR(5)
   real(PRE_EC):: v2,d1,u1,v1,p1,c1,w1,tmp0,tmp1,tmp3,tmp5
   integer:: Iflag_Scheme,i,j,k,m
! U0(k,m) : k=1-LAP,LAP    ; m for the conservative variables U0(1,m)=d, U0(2,m)=d*u, ....
   Uh(:)=0.5d0*(U0(0,:)+U0(1,:))           ! conservative variables in the point I-1/2  (or i)
   d1=Uh(1); u1=Uh(2)/d1; v1=Uh(3)/d1; w1=Uh(4)/d1; p1=(Uh(5)-(Uh(2)*u1+Uh(3)*v1+Uh(4)*w1)*0.5d0)*(gamma-1.d0)  ! density, velocity, pressure and sound speed
   c1=sqrt(gamma*p1/d1)
   v2=(u1*u1+v1*v1+w1*w1)*0.5d0
   tmp1=(gamma-1.d0)/c1
   tmp3=(gamma-1.d0)/(c1*c1)
   tmp5=1.d0/(2.d0*c1)
   tmp0=1.d0/tmp3

! A=S(-1)*LAMDA*S    see �������������ѧ�� 158-159ҳ   (with alfa1=1, alfa2=0, alfa3=0)
   S(1,1)=V2-tmp0;       S(1,2)=-u1 ;   S(1,3)=-v1 ;        S(1,4)=-w1;                  S(1,5)=1.d0
   S(2,1)=-v1 ;          S(2,2)=0.d0 ;  S(2,3)=1.d0 ;       S(2,4)=0.d0;                 S(2,5)=0.d0 
   S(3,1)=-w1 ;          S(3,2)=0.d0 ;  S(3,3)=0.d0 ;       S(3,4)=1.d0 ;                S(3,5)=0.d0 
   S(4,1)=-u1-V2*tmp1;   S(4,2)=1.d0+tmp1*u1;     S(4,3)=tmp1*v1;     S(4,4)=tmp1*w1;    S(4,5)=-tmp1
   S(5,1)=-u1+V2*tmp1;   S(5,2)=1.d0-tmp1*u1;     S(5,3)=-tmp1*v1;    S(5,4)=-tmp1*w1;   S(5,5)=tmp1 
   
   S1(1,1)=-tmp3;    S1(1,2)=0.d0;   S1(1,3)=0.d0;    S1(1,4)=-tmp5 ;                   S1(1,5)=tmp5
   S1(2,1)=-tmp3*u1; S1(2,2)=0.d0;   S1(2,3)=0.d0;    S1(2,4)=0.5d0-u1*tmp5 ;           S1(2,5)=0.5d0+u1*tmp5
   S1(3,1)=-tmp3*v1; S1(3,2)=1.d0;   S1(3,3)=0.d0;    S1(3,4)=-v1*tmp5;                 S1(3,5)=v1*tmp5
   S1(4,1)=-tmp3*w1; S1(4,2)=0.d0;   S1(4,3)=1.d0;    S1(4,4)=-w1*tmp5;                 S1(4,5)=w1*tmp5
   S1(5,1)=-tmp3*V2; S1(5,2)=v1;     S1(5,3)=w1;      S1(5,4)=(c1*u1-V2-tmp0)*tmp5;     S1(5,5)=(c1*u1+V2+tmp0)*tmp5
! V=SU      V(k)=S*U(k)
   do k=1-LAP,LAP     
     do m=1,5
       V0(k,m)=0.d0
       do j=1,5
         V0(k,m)=V0(k,m)+S(m,j)*U0(k,j)
       enddo
     enddo
   enddo  
   do m=1,5
     call scheme_fP(VL(m),V0(:,m),Iflag_Scheme) 
     call scheme_fm(VR(m),V0(:,m),Iflag_Scheme) 
   enddo
   do m=1,5
     QL(m)=0.d0; QR(m)=0.d0
     do j=1,5
       QL(m)=QL(m)+S1(m,j)*VL(j)
       QR(m)=QR(m)+S1(m,j)*VR(j)
     enddo
   enddo
   UL(1)=QL(1); UL(2)=QL(2)/UL(1)
   UL(3)=QL(3)/UL(1); UL(4)=QL(4)/UL(1)
   UL(5)=(QL(5)-(UL(2)*QL(2)+UL(3)*QL(3)+UL(4)*QL(4))*0.5d0)*(gamma-1.d0)  ! density, velocity, pressure and sound speed
  
   UR(1)=QR(1); UR(2)=QR(2)/UR(1)
   UR(3)=QR(3)/UR(1); UR(4)=QR(4)/UR(1)
   UR(5)=(QR(5)-(UR(2)*QR(2)+UR(3)*QR(3)+UR(4)*QR(4))*0.5d0)*(gamma-1.d0)  
   end subroutine Reconstuction_Characteristic
!-----------------------------------------------------------------------------------------------------------





!----------����ճ��ϵ�� (Surthland��ʽ)------------------------
   subroutine get_viscous(nMesh,mBlock)
   Use Global_Var
   Use Flow_Var
   implicit none
   real(PRE_EC):: Tsb
   integer:: mBlock,i,j,k,nMesh,nx,ny,nz
  Type (Block_TYPE),pointer:: B
   B => Mesh(nMesh)%Block(mBlock)
   Tsb=110.4d0/T_inf
    nx=B%nx ; ny=B%ny ; nz=B%nz

!$OMP PARALLEL DO DEFAULT(PRIVATE) SHARED(B,nx,ny,nz,Tsb,T,Re)
     do k=1,nz-1
     do j=1,ny-1
     do i=1,nx-1
       B%mu(i,j,k)=1.d0/Re*(1.d0+Tsb)*sqrt(T(i,j,k)**3)/(Tsb+T(i,j,k))
     enddo
     enddo
     enddo
!$OMP END PARALLEL DO

!  ճ��ϵ���������ϵ�ֵ �������ٽ����ֵ��
    B%mu(0,1:ny-1,1:nz-1)=B%mu(1,1:ny-1,1:nz-1)
	B%mu(nx,1:ny-1,1:nz-1)=B%mu(nx-1,1:ny-1,1:nz-1)
	B%mu(1:nx-1,0,1:nz-1)=B%mu(1:nx-1,1,1:nz-1)
	B%mu(1:nx-1,ny,1:nz-1)=B%mu(1:nx-1,ny-1,1:nz-1)
 	B%mu(1:nx-1,1:ny-1,0)=B%mu(1:nx-1,1:ny-1,1)
  	B%mu(1:nx-1,1:ny-1,nz)=B%mu(1:nx-1,1:ny-1,nz-1)
  end subroutine get_viscous

!----------------------------------------------------
!  ������ճ��ϵ���������� (���ܳ��ָ�ֵ�����ܳ�������ճ��ϵ����MUT_MAX����
  subroutine limit_mut(nMesh,mBlock)
   Use Global_Var
   Use Flow_Var
   implicit none
!   real(PRE_EC),parameter:: MUT_MAX=200.d0
   integer:: mBlock,i,j,k,nMesh,nx,ny,nz
  Type (Block_TYPE),pointer:: B
  B => Mesh(nMesh)%Block(mBlock)
  nx=B%nx ; ny=B%ny ; nz=B%nz

!$OMP PARALLEL DO DEFAULT(FIRSTPRIVATE) SHARED(B,nx,ny,nz,MUT_MAX)
     do k=0,nz
     do j=0,ny
     do i=0,nx
       if(B%mu_t(i,j,k) .lt. 0.)  B%mu_t(i,j,k)=0.
       if( MUT_MAX >=0.d0 .and. B%mu_t(i,j,k) > MUT_MAX*B%mu(i,j,k)) B%mu_t(i,j,k)=MUT_MAX*B%mu(i,j,k)
     enddo
     enddo
     enddo
!$OMP END PARALLEL DO
   call Amut_boundary(nMesh,mBlock)
   end subroutine limit_mut




!---------------------------------------------------------
!  �����غ��������������� (d,u,v,T,p,c) 
!  ��������쳣 (���� �¶�Ϊ��ֵ)
!----------------------------------------------------------
  subroutine comput_duvtpc(nMesh,mBlock)
   use Global_Var
   use Flow_Var 
   implicit none
   Type (Block_TYPE),pointer:: B
   integer nMesh,mBlock,nx,ny,nz,i,j,k
   real(PRE_EC) p00  
   
   p00=1.d0/(gamma*Ma*Ma)
   B => Mesh(nMesh)%Block(mBlock)                 !��nMesh ������ĵ�mBlock��
   nx=B%nx; ny=B%ny; nz=B%nz


!$OMP PARALLEL DO DEFAULT(FIRSTPRIVATE) SHARED(p00,nx,ny,nz,B,d,uu,v,w,T,p,cc,Ma,Cv)
   do k=1-LAP,nz+LAP-1
     do j=1-LAP,ny+LAP-1
       do i=1-LAP,nx+LAP-1
         d(i,j,k)= B%U(1,i,j,k)
         uu(i,j,k)=B%U(2,i,j,k)/d(i,j,k)
         v(i,j,k)= B%U(3,i,j,k)/d(i,j,k)
         w(i,j,k)= B%U(4,i,j,k)/d(i,j,k)
         T(i,j,k)=(B%U(5,i,j,k)-0.5d0*d(i,j,k)*(uu(i,j,k)*uu(i,j,k)+v(i,j,k)*v(i,j,k)+w(i,j,k)*w(i,j,k)))/(Cv*d(i,j,k))
         p(i,j,k)= p00*d(i,j,k)*T(i,j,k)
		 cc(i,j,k)=sqrt(T(i,j,k))/Ma                   ! ����
       enddo
     enddo
   enddo
!$OMP END PARALLEL  DO 

! Debug Debug message
   if(IF_Debug == 2) then   ! show values at one point 
     if(B%Block_no == Pdebug(1)) then
	  i=Pdebug(2); j=Pdebug(3); k=Pdebug(4)
	  print*, "-----Debug , d,u,v,w,T,p= ----"
	  print*, d(i,j,k),uu(i,j,k),v(i,j,k),w(i,j,k),T(i,j,k),p(i,j,k)
	endif
  endif


  end subroutine comput_duvtpc




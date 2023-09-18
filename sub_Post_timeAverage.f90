!  ����ģ�飺 ����ʱ��ƽ��
!--------------------------------------------------------
  subroutine Time_average      
   use Global_Var
   implicit none
   integer:: i,j,k,m,mB,nf,nx,ny,nz
   integer,save:: Iflag=0
   real(PRE_EC):: d1,u1,v1,w1,T1,tmp

   Type (Block_TYPE),pointer:: B

!---��������1�� -----------------
   if(Iflag == 0) then
     Iflag=1             
    do mB=1,Mesh(1)%Num_Block
     B => Mesh(1)%Block(mB)                                        
     nx=B%nx; ny=B%ny; nz=B%nz
 	 allocate(B%U_average(0:nx,0:ny,0:nz,5))       ! ʱ���� d,u,v,w,T
     enddo

    call init_average        ! ��ʼ��ƽ����

   endif
!-------------------------------------
! ʱ��ƽ��  
   if(my_id .eq. 0) print*, "Time Average ......", Istep_average+1

   tmp=1.d0/(Istep_average+1.d0)
   do mB=1,Mesh(1)%Num_Block
     B => Mesh(1)%Block(mB)                                        
     nx=B%nx; ny=B%ny; nz=B%nz

!$OMP PARALLEL DO PRIVATE(i,j,k,d1,u1,v1,w1,T1) SHARED(nx,ny,nz,B,Cv,tmp,Istep_average)

     do k=0,nz
	 do j=0,ny
	 do i=0,nx
         d1= B%U(1,i,j,k)
         u1= B%U(2,i,j,k)/d1
         v1= B%U(3,i,j,k)/d1
         w1= B%U(4,i,j,k)/d1
         T1=(B%U(5,i,j,k)-0.5d0*d1*(u1*u1+v1*v1+w1*w1))/(Cv*d1)
      
	   B%U_average(i,j,k,1)=(Istep_average*B%U_average(i,j,k,1)+d1)*tmp    
	   B%U_average(i,j,k,2)=(Istep_average*B%U_average(i,j,k,2)+u1)*tmp    
	   B%U_average(i,j,k,3)=(Istep_average*B%U_average(i,j,k,3)+v1)*tmp    
	   B%U_average(i,j,k,4)=(Istep_average*B%U_average(i,j,k,4)+w1)*tmp    
	   B%U_average(i,j,k,5)=(Istep_average*B%U_average(i,j,k,5)+T1)*tmp    

	 enddo
	 enddo
	 enddo
   enddo
    Istep_average=Istep_average+1
  end

!-----------------------------------------------------
! ��ʼ��, Ŀǰ�汾ֻ֧�����¿�ʼƽ�����ݲ�֧�ֶ�ȡflow3d_average.dat
   subroutine init_average      
   use Global_Var
   implicit none
   integer:: i,j,k,mB,nf,nx,ny,nz

   Type (Block_TYPE),pointer:: B
    Istep_average=0
    do mB=1,Mesh(1)%Num_Block
     B => Mesh(1)%Block(mB)                                        
     nx=B%nx; ny=B%ny; nz=B%nz
      do k=0,nz
	  do j=0,ny
	  do i=0,nx
	   B%U_average(i,j,k,1)=0.d0 
	   B%U_average(i,j,k,2)=0.d0    
	   B%U_average(i,j,k,3)=0.d0    
	   B%U_average(i,j,k,4)=0.d0    
	   B%U_average(i,j,k,5)=0.d0    
	  enddo
	  enddo
	  enddo
     enddo
  end
!----------------------------------------------------      

 !  ���ƽ���� ��Plot3d��ʽ��, ��ϸ����flow3d_average.dat  
  subroutine output_flow_average
   use Global_Var
   implicit none
   
   Type (Mesh_TYPE),pointer:: MP
   Type (Block_TYPE),pointer:: B
   real(PRE_EC),allocatable,dimension(:,:,:,:):: U
   integer:: NB,m,m1,nx,ny,nz,i,j,k,mt,Num_data
   integer:: Recv_from_ID,tag,ierr, status(MPI_status_size)

   character(len=50):: filename   
   
   MP=>Mesh(1)

!---------------------------------------------------------------
 if(my_id .eq. 0) then
  
   print*, "write flow3d_average.dat ......"
   
   open(99,file="flow3d_average.dat",form="unformatted")                    ! d,u,v,w,T

   do m=1, Total_block   ! ȫ����
     
	 nx=bNi(m); ny=bNj(m); nz=bNk(m)
	 allocate(U(0:nx,0:ny,0:nz,5))

	if(B_proc(m) .eq. 0) then             ! ��Щ�����ڸ�����
      mt=B_n(m)                           ! �ÿ��ڽ����ڲ��ı��
	  B=>MP%Block(mt)
	 
	   do m1=1,5
	    do k=0,nz
	    do j=0,ny
	    do i=0,nx
		  U(i,j,k,m1)=B%U_average(i,j,k,m1)                     
        enddo
	    enddo
	    enddo
 	   enddo

    else                        ! ���ոÿ���Ϣ
	   Num_data=5*(nx+1)*(ny+1)*(nz+1)
	   Recv_from_ID=B_proc(m)
	   tag=B_n(m)             ! �ڸÿ��еı��
 	  call MPI_Recv(U,Num_data,OCFD_DATA_TYPE, Recv_from_ID, tag, MPI_COMM_WORLD,Status,ierr )
    endif
! write Data ....
    
	write(99) (((( U(i,j,k,m1),i=0,nx),j=0,ny),k=0,nz),m1=1,5)    
    
	deallocate(U)

   enddo
   
   write(99) Istep_average
   close(99)
 
 else     ! ��0�ڵ�

    do m=1,MP%Num_Block     ! �����̰����Ŀ�
      B=>MP%Block(m)
	  nx=B%nx; ny=B%ny; nz=B%nz
   	  allocate(U(0:nx,0:ny,0:nz,5))
	  Num_data=(nx+1)*(ny+1)*(nz+1)*5
 	  tag=m
	 
      do m1=1,5
	    do k=0,nz
	    do j=0,ny
	    do i=0,nx
		 U(i,j,k,m1)=B%U_average(i,j,k,m1)
        enddo
	    enddo
	    enddo
 	   enddo
	   
	   call MPI_Send(U,Num_data,OCFD_DATA_TYPE, 0, tag, MPI_COMM_WORLD,ierr )
      deallocate(U)
    enddo
   
  endif
   
   call MPI_Barrier(MPI_COMM_WORLD,ierr)
   if(my_id .eq. 0)  print*, "write flow3d_average.dat OK"

  end subroutine output_flow_average




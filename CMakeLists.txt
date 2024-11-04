cmake_minimum_required(VERSION 3.20)
project(OpenCFD_EC1 VERSION 1.16.0)

enable_language(Fortran)

# 设置优化标志
set(CMAKE_Fortran_FLAGS "${CMAKE_Fortran_FLAGS} -O3")

# 查找 MPI
find_package(MPI REQUIRED)

# 源文件列表
set(SRCS
    src/sub_modules.f90
    src/opencfd_ec3d_v1.16a.f90
    src/sub_interfaces.f90
    src/sub_init.f90
    src/sub_Residual.f90
    src/sub_flux_split.f90
    src/sub_boundary.f90
    src/sub_turbulence_BL.f90
    src/sub_turbulence_SA.f90
    src/sub_turbulence_NewSA.f90
    src/sub_turbulence_SST.f90
    src/sub_time_advance.f90
    src/sub_update_buffer_mpi.f90
    src/sub_Post.f90
    src/sub_time_acceleraction.f90
    src/sub_LU_SGS.f90
    src/sub_IO.f90
    src/sub_geometry.f90
    src/sub_partation_mpi.f90
    src/sub_convert_inp.f90
    src/sub_read_parameter.f90
    src/sub_scheme.f90
    src/sub_comput_dw.f90
    src/sub_debug.f90
    src/sub_filtering.f90
    src/sub_boundary_user.f90
    src/sub_udate_Meshlink_mpi.f90
    src/sub_Finite_Difference1.f90
    src/sub_Finite_Difference2.f90
    src/sub_Post_timeAverage.f90
    src/sub_limitflow.f90
)

# 创建可执行文件
add_executable(opencfd-ec1.16a ${SRCS})

# 链接 MPI
target_link_libraries(opencfd-ec1.16a PRIVATE MPI::MPI_Fortran)

# 设置可执行文件的输出目录
set_target_properties(opencfd-ec1.16a PROPERTIES RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_subdirectory(./util)
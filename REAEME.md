# 简介
本仓库Fork自中科院力学所李新亮研究员团队。

[源仓库地址为：](https://github.com/OpenCFD-IMECH/OpenCFD-EC.git)https://github.com/OpenCFD-IMECH/OpenCFD-EC.git

并在其基础上进行了重构。
1. 使用cmake工具代替makefile，方便跨平台；
2. 调整了项目结构，增加src/ doc/ 3rdparty/目录，源码结构更清晰；


# 安装

## 第三方库和依赖
- mpi
- cgns
- cmake
---
## Linux端

### 编译CGNS库
#### 1.解压cgns
```
cd 3rdparty/

tar -zxvf CGNS-3.14.tar.gz

cd CGNS-3.1.4/

```

#### 2.构建，开启Fortran支持
```
cmake -B build -DENABLE_FORTRAN=ON

//这里使用的cgns-3.1.4为2015年发布，时间比较久远。
//当前最新的v4.4.0的配置会有些不同，配置都增加了CGNS前缀，如果要使用最新的cgns版本，请自行查看cgns文档。

cmake -B build -DCGNS_ENABLE_FORTRAN=ON

```
#### 3.编译
```
cmake --build build -j8
```

cgns编译成功后，CGNS-3.1.4/build/src/目录下会生成如下文件
- libcgns.a
- libcgns.so
- libcgns.so.3.1
- cgnslib_f.h
- cgnstypes_f.h
- ...

关于如何调整生成文件目录，请自行查阅cmake相关配置。

---
### 编译主程序

#### 1.构建
进入OpenCFD-EC工作目录
```
cd OpenCFD-EC/

cmake -B build 

// 也可以 
mkdir build 
cd build 
cmake ..
```

#### 2.编译
```
cmake --build build -j8
```
编译完成后，在OpenCFD-EC/build/bin目录下可以看到14个可执行程序：
1. opencfd-ec1.16a（主求解程序）
2. Block_cut_1.1
3. convert-cgns-inp-1.2
4. convertXYZ-ver1.1
5. readflow3d-ver2.5
6. check-mesh-ver1.1
7. convert_inp
8. get_bcin_v1.4.2
9. partation-1.2
10. readflow3d-wing
11. comput-Q-ec1.0
12. convertMesh2d-3d-v1.1
13. In2inp-1.1
14. PlotZplane-1.3a
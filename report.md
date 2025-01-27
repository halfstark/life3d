# Life3D 实验

## 1. 实验平台

实验平台CPU: 13th Gen Intel i9-13905H, GPU: NVIDIA GeForce RTX 4060 Max-Q

## 2. 初步测试

首先针对在CPU平台进行了初步的测试，得到长宽为256，512以及运行次数为8，16下的运行结果

|长宽|运行次数|时间|
|-|-|-|
|256|8|30.6677|
|256|16|60.1061|
|512|8|241.223|
|512|16|480.9011|

## 3. 在GPU平台上的优化

### 3.1 demo work
首先考虑最简单的做法，在GPU中每个线程计算一块的数据(4x4)，并根据周围的点情况更新当前点的状况到一块临时的空间，更新完成后再通过`cudaMemcpy` 将临时空间拷贝到输入的空间，并进行下一次的迭代

|长宽|运行次数|时间|加速比|
|-|-|-|-|
|256|8|0.00384|7986|
|256|16|0.00408|14731|
|512|8|0.00388132|62149|
|512|16|0.003797|126627|

测试后可以发现当前的加速比随着输入大小的增加而上升，可拓展性较强。


### 3.2 使用更多的线程数目,减少cudaMemcpy

在demo中，每次存在临时空间到输入的 `cudaMemcpy`，可以将临时空间和输入的空间进行交换，实现的代码如下所示，在一个循环内调用两次核函数，同时让每个线程计算一个元素。

```c
// 核心计算代码，将世界向前推进T个时刻
void life3d_run(int N, char *universe, int T, char* device_universe,char* device_out)
{
    dim3 g = dim3(1, N, N);
    dim3 b = dim3(N, 1, 1);
    // cudaMemcpy(device_universe, universe, N*N*N*sizeof(char), cudaMemcpyHostToDevice);


    for (int i = 0; i < T; i+=2) {
        life3d<<<g, b>>>(device_universe, device_out, N);
        life3d<<<g, b>>>(device_out, device_universe, N);
    }
}
```
测试后在1024x8输入下，加速比达到1.938

### 3.2 使用shared memory减少访存的时间

使用shared memory首先需要考虑一下GPU上的shared memory大小

可以发现本次的GPU其实并不足以将全部的空间放入到shared memory中，所以只能在一个维度上使用共享内存

```shell
  Total amount of constant memory:               65536 bytes
  Total amount of shared memory per block:       49152 bytes
  Total number of registers available per block: 65536
```

对于在z轴上的线程，我们将其全部划分给一个block，对于两个相邻的线程而言，其在z轴上有3x3x2的数据属于重合数据，故可以使用shared_mem对z轴上的数据进行共享，实现的代码如下所示

```c
    for (int dx = -1; dx <= 1; dx++)
        for (int dy = -1; dy <= 1; dy++) {
            int nx = (x + dx + N) % N;
            int ny = (y + dy + N) % N;
            sharedIn[(dx+1)*3 + (dy+1) + z*9] = ATin(nx, ny, z);
        }
    __syncthreads();
    char now = ATin(x, y, z);
    for (int dx = -1; dx <= 1; dx++)
        for (int dy = -1; dy <= 1; dy++) {
                int nx = (x + dx + N) % N;
                int ny = (y + dy + N) % N;
                // sharedIn[z] = ATin(nx, ny, z);
                // __syncthreads();
                for (int dz = -1; dz <= 1; dz++) { 
                    if (dx == 0 && dy == 0&& dz == 0) continue;
                    int nz = (z + dz + N) % N;
                    cnt += sharedIn[nz*9 + (dx+1)*3 + (dy+1)];
                    // cnt += ATin(nx, ny, nz);
                }
        }
```
在1024x8上有10%左右的提升
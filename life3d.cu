/*-----------------------------------------------
 * 请在此处填写你的个人信息
 * 学号: SA24011013
 * 姓名: 程家骏
 * 邮箱: chengjiajun20@gmail.com
 ------------------------------------------------*/

#include <chrono>
#include <cstddef>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#define VERIFY
#define AT(x, y, z) universe[(x) * N * N + (y) * N + z]
#define ATin(x, y, z) in[(x) * N * N + (y) * N + z]
#define ATgolden(x, y, z) golden[(x) * N * N + (y) * N + z]

using std::cin, std::cout, std::endl;
using std::ifstream, std::ofstream;

// 存活细胞数
int population(int N, char *universe)
{
    int result = 0;
    for (int i = 0; i < N * N * N; i++)
        result += universe[i];
    return result;
}

__global__ void population_dev(int N, char *universe)
{
    int result = 0;
    for (int i = 0; i < N * N * N; i++)
        result += universe[i];
    printf("dev res %d\n",result);
    // return result;
}

// 打印世界状态
void print_universe(int N, char *universe)
{
    // 仅在N较小(<= 32)时用于Debug
    if (N > 32)
        return;
    for (int x = 0; x < N; x++)
    {
        for (int y = 0; y < N; y++)
        {
            for (int z = 0; z < N; z++)
            {
                if (AT(x, y, z))
                    cout << "O ";
                else
                    cout << "* ";
            }
            cout << endl;
        }
        cout << endl;
    }
    cout << "population: " << population(N, universe) << endl;
}
bool verify_universe(int N, char *universe, char* golden)
{
    // 仅在N较小(<= 32)时用于Debug
    for (int x = 0; x < N; x++)
    {
        for (int y = 0; y < N; y++)
        {
            for (int z = 0; z < N; z++)
            {
                if (AT(x, y, z) != ATgolden(x, y, z)) {
                    printf("verify failed\n");
                    return false;
                }
            }
        }
    }
    printf("verify success\n");
    return true;
}
__device__ void print_universe_dev(int N, char *universe)
{
    // 仅在N较小(<= 32)时用于Debug
    if (N > 32)
        return;
    for (int x = 0; x < N; x++)
    {
        for (int y = 0; y < N; y++)
        {
            for (int z = 0; z < N; z++)
            {
                if (AT(x, y, z))
                    printf("0 ");
                    // cout << "O ";
                else
                    printf("* ");
            }
            printf("\n");
        }
        printf("\n");
    }
    // cout << "population: " << population(N, universe) << endl;
}
__global__ void life3d(char* in, char* out, int N) {
    int x = blockIdx.z;
    int y = blockIdx.y;
    int z = threadIdx.x;
    // printf("x y z: %d %d %d\n", x, y, z);
    // int index = x*N*N + y*N + z;
    // print_universe_dev(N, in);

    // for (int i = 0; i < 4; i++) {
    //     for (int j = 0; j < 4; j++) {
    //         int x1 = x*4 + i;
    //         int y1 = y;
    //         int z1 = z*4 + j;
    //         // int index = (z*4 + j) + y*N + (x*4 + i)*N*N;
    //         // printf("x1 %d %d %d\n", x1, y1, z1);
    int cnt = 0;
    for (int dx = -1; dx <= 1; dx++)
        for (int dy = -1; dy <= 1; dy++)
            for (int dz = -1; dz <= 1; dz++) {
                if (dx == 0 && dy == 0 && dz == 0) continue;
                    int nx = (x + dx + N) % N;
                    int ny = (y + dy + N) % N;
                    int nz = (z + dz + N) % N;
                        // printf("")
                    cnt += ATin(nx, ny, nz);
            }
            // printf("cnt: %d\n", cnt);
            if (ATin(x, y, z) && (cnt < 5 || cnt > 7))
                out[x * N * N + y * N + z] = 0;
            else if (!ATin(x, y, z) && cnt == 6)
                out[x * N * N + y * N + z] = 1;
            else
                out[x * N * N + y * N + z] = ATin(x, y, z);
}
// 核心计算代码，将世界向前推进T个时刻
void life3d_run(int N, char *universe, int T, char* device_universe,char* device_out)
{
    dim3 g = dim3(1, N, N);
    dim3 b = dim3(N, 1, 1);
    // cudaMemcpy(device_universe, universe, N*N*N*sizeof(char), cudaMemcpyHostToDevice);


    for (int i = 0; i < T; i+=2) {
        // population_dev<<<1,1>>>(N, device_universe);
        life3d<<<g, b>>>(device_universe, device_out, N);
        life3d<<<g, b>>>(device_out, device_universe, N);
        // population_dev<<<1,1>>>(N, device_out);
        // cudaMemcpy(device_universe, device_out, N*N*N, cudaMemcpyDeviceToDevice);
        // cudaMemcpy(device_out, device_universe, N*N*N, cudaMemcpyDeviceToDevice);
        // cudaMemcpy(universe, device_out, N*N*N, cudaMemcpyDeviceToDevice);
        // print_universe(N, universe);
    }

}

void life3D_golden(int N, char *universe, int T) {
    char *next = (char *)malloc(N * N * N);
    for (int t = 0; t < T; t++)
    {
        // outerloop: iter universe
        for (int x = 0; x < N; x++)
            for (int y = 0; y < N; y++)
                for (int z = 0; z < N; z++)
                {
                    // inner loop: stencil
                    int alive = 0;
                    for (int dx = -1; dx <= 1; dx++)
                        for (int dy = -1; dy <= 1; dy++)
                            for (int dz = -1; dz <= 1; dz++)
                            {
                                if (dx == 0 && dy == 0 && dz == 0)
                                    continue;
                                int nx = (x + dx + N) % N;
                                int ny = (y + dy + N) % N;
                                int nz = (z + dz + N) % N;
                                alive += AT(nx, ny, nz);
                            }
                    if (AT(x, y, z) && (alive < 5 || alive > 7))
                        next[x * N * N + y * N + z] = 0;
                    else if (!AT(x, y, z) && alive == 6)
                        next[x * N * N + y * N + z] = 1;
                    else
                        next[x * N * N + y * N + z] = AT(x, y, z);
                }
        memcpy(universe, next, N * N * N);
    }
    free(next);
}

// 读取输入文件
void read_file(char *input_file, char *buffer)
{
    ifstream file(input_file, std::ios::binary | std::ios::ate);
    if (!file.is_open())
    {
        cout << "Error: Could not open file " << input_file << std::endl;
        exit(1);
    }
    std::streamsize file_size = file.tellg();
    file.seekg(0, std::ios::beg);
    if (!file.read(buffer, file_size))
    {
        std::cerr << "Error: Could not read file " << input_file << std::endl;
        exit(1);
    }
    file.close();
}

// 写入输出文件
void write_file(char *output_file, char *buffer, int N)
{
    ofstream file(output_file, std::ios::binary | std::ios::trunc);
    if (!file)
    {
        cout << "Error: Could not open file " << output_file << std::endl;
        exit(1);
    }
    file.write(buffer, N * N * N);
    file.close();
}

int main(int argc, char **argv)
{
    // cmd args
    if (argc < 5)
    {
        cout << "usage: ./life3d N T input output" << endl;
        return 1;
    }
    int N = std::stoi(argv[1]);
    int T = std::stoi(argv[2]);
    char *input_file = argv[3];
    char *output_file = argv[4];

    char *universe = (char *)malloc(N * N * N);
    char *universe_golen = (char *)malloc(N * N * N);

    read_file(input_file, universe);
    memcpy(universe_golen, universe, N * N * N);
    #ifdef VERIFY
    life3D_golden(N, universe_golen, T);
    #endif
    cudaError_t cudaStatus;

    char* dev_universe = NULL, *dev_out = NULL;
    cudaStatus = cudaMalloc((void**)&dev_universe, N*N*N);
    if (cudaStatus != cudaSuccess) {
        cout << "malloc failed\n";
        return -1;
    }
    cudaStatus = cudaMalloc((void**)&dev_out, N*N*N);
    if (cudaStatus != cudaSuccess) {
        cout << "malloc failed\n";
        return -1;
    }
    cudaMemcpy(dev_universe, universe, N*N*N, cudaMemcpyHostToDevice);
    // population_dev<<<1, 1>>>(N ,dev_universe);
    int start_pop = population(N, universe);
    auto start_time = std::chrono::high_resolution_clock::now();
    life3d_run(N, universe, T, dev_universe, dev_out);
    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> duration = end_time - start_time;
    cudaMemcpy(universe, dev_universe, N*N*N, cudaMemcpyDeviceToHost);
    cudaFree(dev_out);
    cudaFree(dev_universe);
    #ifdef VERIFY
    verify_universe(N, universe, universe_golen);
    #endif
    int final_pop = population(N, universe);
    write_file(output_file, universe, N);
    
    cout << "start population: " << start_pop << endl;
    cout << "final population: " << final_pop << endl;
    double time = duration.count();
    cout << "time: " << time << "s" << endl;
    cout << "cell per sec: " << T / time * N * N * N << endl;

    free(universe);
    return 0;
}

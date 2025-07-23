#include <iostream>
#include <arm_neon.h>
#include <opencv2/opencv.hpp>

int main() {
    std::cout << "=== NEON优化检查工具 ===" << std::endl;
    
    // 检查NEON是否可用
    #ifdef __ARM_NEON
        std::cout << "✓ NEON指令集可用" << std::endl;
    #else
        std::cout << "✗ NEON指令集不可用" << std::endl;
        return 1;
    #endif
    
    // 检查OpenCV NEON优化
    std::cout << "\n=== OpenCV NEON优化检查 ===" << std::endl;
    std::cout << "OpenCV版本: " << CV_VERSION << std::endl;
    
    // 检查环境变量
    const char* neon_env = std::getenv("OPENCV_NEON_OPTIMIZATION");
    const char* use_neon_env = std::getenv("OPENCV_USE_NEON");
    
    std::cout << "OPENCV_NEON_OPTIMIZATION: " << (neon_env ? neon_env : "未设置") << std::endl;
    std::cout << "OPENCV_USE_NEON: " << (use_neon_env ? use_neon_env : "未设置") << std::endl;
    
    // 测试NEON指令
    std::cout << "\n=== NEON指令测试 ===" << std::endl;
    
    // 创建测试数据
    float32_t a[4] = {1.0f, 2.0f, 3.0f, 4.0f};
    float32_t b[4] = {5.0f, 6.0f, 7.0f, 8.0f};
    float32_t result[4];
    
    // 使用NEON指令进行向量加法
    float32x4_t va = vld1q_f32(a);
    float32x4_t vb = vld1q_f32(b);
    float32x4_t vresult = vaddq_f32(va, vb);
    vst1q_f32(result, vresult);
    
    std::cout << "NEON向量加法测试: ";
    for (int i = 0; i < 4; i++) {
        std::cout << result[i] << " ";
    }
    std::cout << std::endl;
    
    // 测试OpenCV NEON优化
    std::cout << "\n=== OpenCV NEON优化测试 ===" << std::endl;
    
    // 创建测试图像
    cv::Mat test_image = cv::Mat::zeros(100, 100, CV_8UC1);
    cv::rectangle(test_image, cv::Point(10, 10), cv::Point(90, 90), 255, -1);
    
    // 测试高斯滤波（应该使用NEON优化）
    cv::Mat blurred;
    auto start = std::chrono::high_resolution_clock::now();
    
    for (int i = 0; i < 100; i++) {
        cv::GaussianBlur(test_image, blurred, cv::Size(5, 5), 1.0);
    }
    
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    
    std::cout << "OpenCV高斯滤波测试 (100次): " << duration.count() << " 微秒" << std::endl;
    
    // 检查编译标志
    std::cout << "\n=== 编译信息 ===" << std::endl;
    #ifdef __ARM_NEON
        std::cout << "编译时启用了NEON支持" << std::endl;
    #endif
    
    #ifdef CV_NEON
        std::cout << "OpenCV编译时启用了NEON优化" << std::endl;
    #else
        std::cout << "OpenCV编译时未启用NEON优化" << std::endl;
    #endif
    
    return 0;
} 
#include <iostream>
#include <string>
#include <vector>
#include <opencv2/opencv.hpp>
#include <chrono>
#include "LaneDetector.h"

/**
*@brief Function main that runs the main algorithm of the lane detection.
*@brief It will read a video of a car in the highway and it will output the
*@brief same video but with the plotted detected lane
*@param argv[] is a string to the full path of the demo video
*@return flag_plot tells if the demo has sucessfully finished
*/
int main() 
{
    LaneDetector lanedetector;  // 定义车道线检测对象
    cv::Mat frame;
    cv::Mat img_denoise;
    cv::Mat img_edges;
    cv::Mat img_mask;
    std::vector<cv::Vec4i> lines;
    std::vector<std::vector<cv::Vec4i> > left_right_lines;
    std::vector<cv::Point> lane;
    std::string turn;
    int flag_plot = -1;         // 返回值

    // 性能统计变量
    std::chrono::high_resolution_clock::time_point total_start_time;
    std::chrono::high_resolution_clock::time_point total_end_time;
    double total_processing_time = 0.0;
    int total_frames_processed = 0;

    // 打开测试视频文件
    cv::VideoCapture cap("video_challenge.mp4");
    if (!cap.isOpened())
        return -1;

    // 获取视频属性
    int frame_width = cap.get(cv::CAP_PROP_FRAME_WIDTH);
    int frame_height = cap.get(cv::CAP_PROP_FRAME_HEIGHT);
    double fps = cap.get(cv::CAP_PROP_FPS);
    
    // 创建彩色视频写入器（车道线检测结果）
    cv::VideoWriter color_video_writer("output_lane_detection_color.avi", 
                                      cv::VideoWriter::fourcc('M','J','P','G'), 
                                      fps, 
                                      cv::Size(frame_width, frame_height));

    // 创建黑白视频写入器（边缘检测结果）
    cv::VideoWriter bw_video_writer("output_edge_detection_bw.avi", 
                                   cv::VideoWriter::fourcc('M','J','P','G'), 
                                   fps, 
                                   cv::Size(frame_width, frame_height));

    if (!color_video_writer.isOpened()) {
        std::cout << "无法创建彩色输出视频文件" << std::endl;
        return -1;
    }

    if (!bw_video_writer.isOpened()) {
        std::cout << "无法创建黑白输出视频文件" << std::endl;
        return -1;
    }

    std::cout << "开始处理视频..." << std::endl;
    std::cout << "彩色输出文件: output_lane_detection_color.avi" << std::endl;
    std::cout << "黑白输出文件: output_edge_detection_bw.avi" << std::endl;
    std::cout << "视频信息: " << frame_width << "x" << frame_height << ", " << fps << "fps" << std::endl;

    // 记录总开始时间
    total_start_time = std::chrono::high_resolution_clock::now();

    // 车道线检测算法主循环
    while (1) 
    {
        // 读入一帧图像，不成功则退出
        if (!cap.read(frame))
            break;

        // 采用Gaussian滤波器去噪声
        img_denoise = lanedetector.deNoise(frame);

        // 边缘检测
        img_edges = lanedetector.edgeDetector(img_denoise);

        // 裁剪图像以获取ROI
        img_mask = lanedetector.mask(img_edges);

        // 将边缘检测结果转换为3通道以便写入视频
        cv::Mat edge_3channel;
        cv::cvtColor(img_mask, edge_3channel, cv::COLOR_GRAY2BGR);

        // 写入黑白边缘检测视频
        bw_video_writer.write(edge_3channel);

        // 在ROI区域通过Hough变换得到Hough线
        lines = lanedetector.houghLines(img_mask);

        if (!lines.empty())
        {
            // 分离左右车道线
            left_right_lines = lanedetector.lineSeparation(lines, img_edges);

            // 采用回归法获取单边车道线
            lane = lanedetector.regression(left_right_lines, frame);

            // 预测车道线是向左、向右还是直行
            turn = lanedetector.predictTurn();

            // 在视频图上绘制车道线并写入彩色视频
            flag_plot = lanedetector.plotLane(frame, lane, turn);
            
            // 将处理后的彩色帧写入视频文件
            color_video_writer.write(frame);
            
            std::cout << "检测到车道线，转向预测: " << turn << std::endl;
        }
        else 
        {
            flag_plot = -1;
            // 即使没有检测到车道线，也要写入原始彩色帧
            color_video_writer.write(frame);
            std::cout << "未检测到车道线" << std::endl;
        }

        total_frames_processed++;
    }

    // 记录总结束时间
    total_end_time = std::chrono::high_resolution_clock::now();
    auto total_duration = std::chrono::duration_cast<std::chrono::microseconds>(total_end_time - total_start_time);
    total_processing_time = total_duration.count() / 1000.0; // 转换为毫秒

    // 释放资源
    cap.release();
    color_video_writer.release();
    bw_video_writer.release();
    
    // 获取详细的性能统计信息
    double avg_denoise, avg_edge, avg_mask, avg_hough, avg_separation, avg_regression, avg_predict, avg_plot, avg_total;
    int frames;
    lanedetector.getPerformanceStats(avg_denoise, avg_edge, avg_mask, avg_hough, avg_separation, avg_regression, avg_predict, avg_plot, avg_total, frames);

    // 输出详细的性能报告
    std::cout << "\n==========================================" << std::endl;
    std::cout << "详细性能测试报告" << std::endl;
    std::cout << "==========================================" << std::endl;
    std::cout << "整机执行时间: " << total_processing_time << " ms" << std::endl;
    std::cout << "总处理帧数: " << total_frames_processed << std::endl;
    std::cout << "平均每帧处理时间: " << total_processing_time / total_frames_processed << " ms" << std::endl;
    std::cout << "实际处理帧率: " << 1000.0 / (total_processing_time / total_frames_processed) << " FPS" << std::endl;
    
    std::cout << "\n模块执行时间分析:" << std::endl;
    std::cout << "├── 图像去噪: " << avg_denoise << " ms (" << (avg_denoise/avg_total*100) << "%)" << std::endl;
    std::cout << "├── 边缘检测: " << avg_edge << " ms (" << (avg_edge/avg_total*100) << "%)" << std::endl;
    std::cout << "├── 掩码处理: " << avg_mask << " ms (" << (avg_mask/avg_total*100) << "%)" << std::endl;
    std::cout << "├── Hough变换: " << avg_hough << " ms (" << (avg_hough/avg_total*100) << "%)" << std::endl;
    std::cout << "├── 线分离: " << avg_separation << " ms (" << (avg_separation/avg_total*100) << "%)" << std::endl;
    std::cout << "├── 回归拟合: " << avg_regression << " ms (" << (avg_regression/avg_total*100) << "%)" << std::endl;
    std::cout << "├── 转向预测: " << avg_predict << " ms (" << (avg_predict/avg_total*100) << "%)" << std::endl;
    std::cout << "└── 结果绘制: " << avg_plot << " ms (" << (avg_plot/avg_total*100) << "%)" << std::endl;
    
    std::cout << "\n性能瓶颈分析:" << std::endl;
    double max_time = std::max({avg_denoise, avg_edge, avg_mask, avg_hough, avg_separation, avg_regression, avg_predict, avg_plot});
    if (max_time == avg_hough) {
        std::cout << "主要瓶颈: Hough变换 (" << avg_hough << " ms)" << std::endl;
    } else if (max_time == avg_edge) {
        std::cout << "主要瓶颈: 边缘检测 (" << avg_edge << " ms)" << std::endl;
    } else if (max_time == avg_regression) {
        std::cout << "主要瓶颈: 回归拟合 (" << avg_regression << " ms)" << std::endl;
    } else if (max_time == avg_plot) {
        std::cout << "主要瓶颈: 结果绘制 (" << avg_plot << " ms)" << std::endl;
    }
    
    std::cout << "\n优化建议:" << std::endl;
    if (avg_hough > avg_total * 0.3) {
        std::cout << "- Hough变换占用时间较多，可考虑优化参数或使用更高效的直线检测算法" << std::endl;
    }
    if (avg_edge > avg_total * 0.2) {
        std::cout << "- 边缘检测可考虑使用NEON指令集优化" << std::endl;
    }
    if (avg_plot > avg_total * 0.15) {
        std::cout << "- 绘制操作可考虑减少不必要的图形操作" << std::endl;
    }
    
    std::cout << "==========================================" << std::endl;
    std::cout << "视频处理完成！" << std::endl;
    std::cout << "彩色输出文件: output_lane_detection_color.avi" << std::endl;
    std::cout << "黑白输出文件: output_edge_detection_bw.avi" << std::endl;

    return flag_plot;
}
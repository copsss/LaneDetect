#include <iostream>
#include <string>
#include <vector>
#include <opencv2/opencv.hpp>
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

    // 打开测试视频文件
    cv::VideoCapture cap("video_project.mp4");
    if (!cap.isOpened())
        return -1;

    // 获取视频属性
    int frame_width = cap.get(cv::CAP_PROP_FRAME_WIDTH);
    int frame_height = cap.get(cv::CAP_PROP_FRAME_HEIGHT);
    double fps = cap.get(cv::CAP_PROP_FPS);
    
    // 创建视频写入器
    cv::VideoWriter video_writer("output_lane_detection.avi", 
                                cv::VideoWriter::fourcc('M','J','P','G'), 
                                fps, 
                                cv::Size(frame_width, frame_height));

    if (!video_writer.isOpened()) {
        std::cout << "无法创建输出视频文件" << std::endl;
        return -1;
    }

    std::cout << "开始处理视频，输出文件: output_lane_detection.avi" << std::endl;

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

            // 在视频图上绘制车道线并写入视频
            flag_plot = lanedetector.plotLane(frame, lane, turn);
            
            // 将处理后的帧写入视频文件
            video_writer.write(frame);
            
            std::cout << "检测到车道线，转向预测: " << turn << std::endl;
        }
        else 
        {
            flag_plot = -1;
            // 即使没有检测到车道线，也要写入原始帧
            video_writer.write(frame);
            std::cout << "未检测到车道线" << std::endl;
        }
    }

    // 释放资源
    cap.release();
    video_writer.release();
    
    std::cout << "视频处理完成！输出文件: output_lane_detection.avi" << std::endl;

    return flag_plot;
}
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
    cv::VideoCapture cap("video_harder_challenge.mp4");
    if (!cap.isOpened())
        return -1;

    // 获取视频属性
    int frame_width = cap.get(cv::CAP_PROP_FRAME_WIDTH);
    int frame_height = cap.get(cv::CAP_PROP_FRAME_HEIGHT);
    double fps = cap.get(cv::CAP_PROP_FPS);
    
    // 创建彩色视频写入器（车道线检测结果）
    cv::VideoWriter color_video_writer("video_harder_challenge_lane_detection_color.avi", 
                                      cv::VideoWriter::fourcc('M','J','P','G'), 
                                      fps, 
                                      cv::Size(frame_width, frame_height));

    // 创建黑白视频写入器（边缘检测结果）
    cv::VideoWriter bw_video_writer("video_harder_challenge_edge_detection_bw.avi", 
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
    std::cout << "彩色输出文件: video_harder_challenge_lane_detection_color.avi" << std::endl;
    std::cout << "黑白输出文件: video_harder_challenge_edge_detection_bw.avi" << std::endl;

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
    }

    // 释放资源
    cap.release();
    color_video_writer.release();
    bw_video_writer.release();
    
    std::cout << "视频处理完成！" << std::endl;
    std::cout << "彩色输出文件: video_harder_challenge_lane_detection_color.avi" << std::endl;
    std::cout << "黑白输出文件: video_harder_challenge_edge_detection_bw.avi" << std::endl;

    return flag_plot;
}
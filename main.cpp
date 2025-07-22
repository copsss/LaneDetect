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

    // 输入视频文件名
    std::string input_video = "video_challenge.mp4";
    // 自动生成输出视频文件名
    std::string output_video;
    size_t dot_pos = input_video.find_last_of('.');
    if (dot_pos != std::string::npos) {
        output_video = input_video.substr(0, dot_pos) + "_output" + input_video.substr(dot_pos);
    } else {
        output_video = input_video + "_output.mp4";
    }

    // 打开输入视频
    cv::VideoCapture cap(input_video);
    if (!cap.isOpened())
        return -1;

    // 获取视频参数
    int frame_width = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_WIDTH));
    int frame_height = static_cast<int>(cap.get(cv::CAP_PROP_FRAME_HEIGHT));
    double fps = cap.get(cv::CAP_PROP_FPS);
    int fourcc = static_cast<int>(cap.get(cv::CAP_PROP_FOURCC));
    if (fourcc == 0) fourcc = cv::VideoWriter::fourcc('m','p','4','v');

    // 创建输出视频写入器
    cv::VideoWriter writer(output_video, fourcc, fps, cv::Size(frame_width, frame_height));
    if (!writer.isOpened()) {
        std::cerr << "Failed to open output video file: " << output_video << std::endl;
        return -1;
    }

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

            // 在视频图上绘制车道线
            flag_plot = lanedetector.plotLane(frame, lane, turn);
        }
        else 
        {
            flag_plot = -1;
        }

        // 写入输出视频
        writer.write(frame);

        // 在25ms以内等待到按键则退出
        if (cv::waitKey(25) >= 0) break; 
    }

    writer.release();
    cap.release();
    return flag_plot;
}
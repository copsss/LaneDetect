/**
*@file LaneDetector.cpp
*@author Miguel Maestre Trueba
*@brief Definition of all the function that form part of the LaneDetector class.
*@brief The class will take RGB images as inputs and will output the same RGB image but
*@brief with the plot of the detected lanes and the turn prediction.
*/
#include <string>
#include <vector>
#include <opencv2/opencv.hpp>   
#include <chrono>
#include <iostream>
#include "LaneDetector.h"

// 全局变量用于记录模块执行时间
std::chrono::high_resolution_clock::time_point module_start_time;
std::chrono::high_resolution_clock::time_point module_end_time;
double total_denoise_time = 0.0;
double total_edge_detection_time = 0.0;
double total_mask_time = 0.0;
double total_hough_time = 0.0;
double total_line_separation_time = 0.0;
double total_regression_time = 0.0;
double total_predict_time = 0.0;
double total_plot_time = 0.0;
int frame_count = 0;

// 时间测量函数
void start_timer() {
    module_start_time = std::chrono::high_resolution_clock::now();
}

double end_timer() {
    module_end_time = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(module_end_time - module_start_time);
    return duration.count() / 1000.0; // 转换为毫秒
}

// 打印性能统计信息
void print_performance_stats() {
    if (frame_count > 0) {
        std::cout << "=== 性能统计信息 ===" << std::endl;
        std::cout << "总帧数: " << frame_count << std::endl;
        std::cout << "平均去噪时间: " << total_denoise_time / frame_count << " ms" << std::endl;
        std::cout << "平均边缘检测时间: " << total_edge_detection_time / frame_count << " ms" << std::endl;
        std::cout << "平均掩码时间: " << total_mask_time / frame_count << " ms" << std::endl;
        std::cout << "平均Hough变换时间: " << total_hough_time / frame_count << " ms" << std::endl;
        std::cout << "平均线分离时间: " << total_line_separation_time / frame_count << " ms" << std::endl;
        std::cout << "平均回归时间: " << total_regression_time / frame_count << " ms" << std::endl;
        std::cout << "平均预测时间: " << total_predict_time / frame_count << " ms" << std::endl;
        std::cout << "平均绘制时间: " << total_plot_time / frame_count << " ms" << std::endl;
        
        double total_avg_time = (total_denoise_time + total_edge_detection_time + total_mask_time + 
                                total_hough_time + total_line_separation_time + total_regression_time + 
                                total_predict_time + total_plot_time) / frame_count;
        std::cout << "平均总处理时间: " << total_avg_time << " ms" << std::endl;
        std::cout << "理论最大帧率: " << 1000.0 / total_avg_time << " FPS" << std::endl;
        std::cout << "===================" << std::endl;
    }
}

// IMAGE BLURRING
/**
*@brief Apply gaussian filter to the input image to denoise it
*@param inputImage is the frame of a video in which the
*@param lane is going to be detected
*@return Blurred and denoised image
*/
cv::Mat LaneDetector::deNoise(cv::Mat inputImage) 
{
    start_timer();
    
    cv::Mat output;
    cv::GaussianBlur(inputImage, output, cv::Size(3, 3), 0, 0);
    
    double elapsed = end_timer();
    total_denoise_time += elapsed;
    
    return output;
}

// EDGE DETECTION
/**
*@brief Detect all the edges in the blurred frame by filtering the image
*@param img_noise is the previously blurred frame
*@return Binary image with only the edges represented in white
*/
cv::Mat LaneDetector::edgeDetector(cv::Mat img_noise) 
{
    start_timer();
    
    cv::Mat output;
    cv::Mat kernel;
    cv::Point anchor;

    // Convert image from RGB to gray
    cv::cvtColor(img_noise, output, cv::COLOR_RGB2GRAY);
    // Binarize gray image
    cv::threshold(output, output, 140, 255, cv::THRESH_BINARY);

    // Create the kernel [-1 0 1]
    // This kernel is based on the one found in the
    // Lane Departure Warning System by Mathworks
    anchor = cv::Point(-1, -1);
    kernel = cv::Mat(1, 3, CV_32F);
    kernel.at<float>(0, 0) = -1;
    kernel.at<float>(0, 1) = 0;
    kernel.at<float>(0, 2) = 1;

    // Filter the binary image to obtain the edges
    cv::filter2D(output, output, -1, kernel, anchor, 0, cv::BORDER_DEFAULT);
    // 移除显示：cv::imshow("output", output);
    
    double elapsed = end_timer();
    total_edge_detection_time += elapsed;
    
    return output;
}

// MASK THE EDGE IMAGE
/**
*@brief Mask the image so that only the edges that form part of the lane are detected
*@param img_edges is the edges image from the previous function
*@return Binary image with only the desired edges being represented
*/
cv::Mat LaneDetector::mask(cv::Mat img_edges) 
{
    start_timer();
    
    cv::Mat output;
    cv::Mat mask = cv::Mat::zeros(img_edges.size(), img_edges.type());
    cv::Point pts[4] = {
        cv::Point(210, 720),
        cv::Point(550, 450),
        cv::Point(717, 450),
        cv::Point(1280, 720)
    };

    // Create a binary polygon mask
    cv::fillConvexPoly(mask, pts, 4, cv::Scalar(255, 0, 0));
    // Multiply the edges image and the mask to get the output
    cv::bitwise_and(img_edges, mask, output);
    
    double elapsed = end_timer();
    total_mask_time += elapsed;
    
    return output;
}

// HOUGH LINES
/**
*@brief Obtain all the line segments in the masked images which are going to be part of the lane boundaries
*@param img_mask is the masked binary image from the previous function
*@return Vector that contains all the detected lines in the image
*/
std::vector<cv::Vec4i> LaneDetector::houghLines(cv::Mat img_mask) 
{
    start_timer();
    
    std::vector<cv::Vec4i> line;

    // rho and theta are selected by trial and error
    HoughLinesP(img_mask, line, 1, CV_PI / 180, 20, 20, 30);
    
    double elapsed = end_timer();
    total_hough_time += elapsed;
    
    return line;
}

// LINE SEPARATION
/**
*@brief Separate lines into right and left lines
*@param lines is the input that contains all the detected lines
*@param img_edges is used for computational purposes
*@return The output is a vector that contains all the classified lines
*/
std::vector<std::vector<cv::Vec4i> > LaneDetector::lineSeparation(std::vector<cv::Vec4i> lines, cv::Mat img_edges) 
{
    start_timer();
    
    std::vector<std::vector<cv::Vec4i> > output(2);
    size_t j = 0;
    cv::Point ini;
    cv::Point fini;
    double slope_thresh_min = 0.3;
    double slope_thresh_max = 0.85;

    for (auto i : lines) {
        ini = cv::Point(i[0], i[1]);
        fini = cv::Point(i[2], i[3]);

        double slope = (static_cast<double>(fini.y) - static_cast<double>(ini.y)) /
                      (static_cast<double>(fini.x) - static_cast<double>(ini.x) + 0.00001);

        if ((abs(slope) > slope_thresh_min) && (abs(slope) < slope_thresh_max)) {
            if (slope > 0 && fini.x > 640) {
                output[0].push_back(i);
            }
            else if (slope < 0 && fini.x < 640) {
                output[1].push_back(i);
            }
        }
    }
    
    double elapsed = end_timer();
    total_line_separation_time += elapsed;
    
    return output;
}

// REGRESSION
/**
*@brief Regression takes all the classified line coordinates initial and final and returns a function
*@param left_right_lines is the output of the lineSeparation function
*@param inputImage is used to select where do the lines will end
*@return The function returns a vector containing the initial and final points of the line functions
*/
std::vector<cv::Point> LaneDetector::regression(std::vector<std::vector<cv::Vec4i> > left_right_lines, cv::Mat inputImage) 
{
    start_timer();
    
    std::vector<cv::Point> output(4);
    cv::Point ini;
    cv::Point fini;
    cv::Point ini2;
    cv::Point fini2;
    cv::Vec4d right_line;
    cv::Vec4d left_line;
    std::vector<cv::Point> right_pts;
    std::vector<cv::Point> left_pts;

    // If right lines are being detected, fit a line using all the init and final points of the lines
    if (left_right_lines[0].size() > 0) {
        for (auto j : left_right_lines[0]) {
            ini = cv::Point(j[0], j[1]);
            fini = cv::Point(j[2], j[3]);

            right_pts.push_back(ini);
            right_pts.push_back(fini);
        }
    }

    // If left lines are being detected, fit a line using all the init and final points of the lines
    if (left_right_lines[1].size() > 0) {
        for (auto j : left_right_lines[1]) {
            ini2 = cv::Point(j[0], j[1]);
            fini2 = cv::Point(j[2], j[3]);

            left_pts.push_back(ini2);
            left_pts.push_back(fini2);
        }
    }

    // If right lines are being detected, fit a line using all the init and final points of the lines
    if (right_pts.size() > 0) {
        // The right line is formed here
        cv::fitLine(right_pts, right_line, cv::DIST_L2, 0, 0.01, 0.01);
        right_m = right_line[1] / right_line[0];
        right_b = cv::Point(right_line[2], right_line[3]);
    }

    // If left lines are being detected, fit a line using all the init and final points of the lines
    if (left_pts.size() > 0) {
        // The left line is formed here
        cv::fitLine(left_pts, left_line, cv::DIST_L2, 0, 0.01, 0.01);
        left_m = left_line[1] / left_line[0];
        left_b = cv::Point(left_line[2], left_line[3]);
    }

    // One the slope and offset points have been obtained, apply the line equation to obtain the line points
    int ini_y = inputImage.rows;
    int fin_y = 470;

    double right_ini_x = ((ini_y - right_b.y) / right_m) + right_b.x;
    double right_fin_x = ((fin_y - right_b.y) / right_m) + right_b.x;

    double left_ini_x = ((ini_y - left_b.y) / left_m) + left_b.x;
    double left_fin_x = ((fin_y - left_b.y) / left_m) + left_b.x;

    output[0] = cv::Point(right_ini_x, ini_y);
    output[1] = cv::Point(right_fin_x, fin_y);
    output[2] = cv::Point(left_ini_x, ini_y);
    output[3] = cv::Point(left_fin_x, fin_y);
    
    double elapsed = end_timer();
    total_regression_time += elapsed;
    
    return output;
}

// TURN PREDICTION
/**
*@brief Predict if the lane is turning left, right or if it is going straight
*@brief It is done by seeing where the vanishing point is with respect to the center of the image
*@return String that says if there is left or right turn or if the road is straight
*/
std::string LaneDetector::predictTurn() 
{
    start_timer();
    
    std::string output;
    double vanish_x;
    double thr_vp = 10;

    // The vanishing point is the point where both lane boundary lines intersect
    vanish_x = static_cast<double>(((right_m*right_b.x) - (left_m*left_b.x) - right_b.y + left_b.y) / (right_m - left_m));

    // The vanishing points location determines where is the road turning
    if (vanish_x < (img_center - thr_vp))
        output = "Turn left";
    else if (vanish_x >(img_center + thr_vp))
        output = "Turn right";
    else if (vanish_x >= (img_center - thr_vp) && vanish_x <= (img_center + thr_vp))
        output = "Straight";
    
    double elapsed = end_timer();
    total_predict_time += elapsed;
    
    return output;
}

// PLOT RESULTS
/**
*@brief This function plots both sides of the lane, the turn prediction message and a transparent polygon that covers the area inside the lane boundaries
*@param inputImage is the original captured frame
*@param lane is the vector containing the information of both lines
*@param turn is the output string containing the turn information
*@return The function returns a 0
*/
int LaneDetector::plotLane(cv::Mat inputImage, std::vector<cv::Point> lane, std::string turn) 
{
    start_timer();
    
    std::vector<cv::Point> poly_points;
    cv::Mat output;

    // Create the transparent polygon for a better visualization of the lane
    inputImage.copyTo(output);
    poly_points.push_back(lane[2]);
    poly_points.push_back(lane[0]);
    poly_points.push_back(lane[1]);
    poly_points.push_back(lane[3]);
    cv::fillConvexPoly(output, poly_points, cv::Scalar(0, 0, 255), cv::LINE_AA, 0);
    cv::addWeighted(output, 0.3, inputImage, 1.0 - 0.3, 0, inputImage);

    // Plot both lines of the lane boundary
    cv::line(inputImage, lane[0], lane[1], cv::Scalar(0, 255, 255), 5, cv::LINE_AA);
    cv::line(inputImage, lane[2], lane[3], cv::Scalar(0, 255, 255), 5, cv::LINE_AA);

    // Plot the turn message
    cv::putText(inputImage, turn, cv::Point(50, 90), cv::FONT_HERSHEY_COMPLEX_SMALL, 3, cv::Scalar(0, 255, 0), 1, cv::LINE_AA);

    // 移除显示相关代码：
    // cv::namedWindow("Lane", cv::WINDOW_AUTOSIZE);
    // cv::imshow("Lane", inputImage);
    
    double elapsed = end_timer();
    total_plot_time += elapsed;
    frame_count++;
    
    return 0;
}

// 获取性能统计信息的函数
void LaneDetector::getPerformanceStats(double& avg_denoise, double& avg_edge, double& avg_mask, 
                                      double& avg_hough, double& avg_separation, double& avg_regression,
                                      double& avg_predict, double& avg_plot, double& avg_total, int& frames) {
    if (frame_count > 0) {
        avg_denoise = total_denoise_time / frame_count;
        avg_edge = total_edge_detection_time / frame_count;
        avg_mask = total_mask_time / frame_count;
        avg_hough = total_hough_time / frame_count;
        avg_separation = total_line_separation_time / frame_count;
        avg_regression = total_regression_time / frame_count;
        avg_predict = total_predict_time / frame_count;
        avg_plot = total_plot_time / frame_count;
        avg_total = (total_denoise_time + total_edge_detection_time + total_mask_time + 
                    total_hough_time + total_line_separation_time + total_regression_time + 
                    total_predict_time + total_plot_time) / frame_count;
        frames = frame_count;
    } else {
        avg_denoise = avg_edge = avg_mask = avg_hough = avg_separation = avg_regression = avg_predict = avg_plot = avg_total = 0.0;
        frames = 0;
    }
}

// 重置性能统计
void LaneDetector::resetPerformanceStats() {
    total_denoise_time = 0.0;
    total_edge_detection_time = 0.0;
    total_mask_time = 0.0;
    total_hough_time = 0.0;
    total_line_separation_time = 0.0;
    total_regression_time = 0.0;
    total_predict_time = 0.0;
    total_plot_time = 0.0;
    frame_count = 0;
}
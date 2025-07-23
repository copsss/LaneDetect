class LaneDetector
{
private:
	double img_size;
	double img_center;
	bool left_flag = false;     // Tells us if there's left boundary of lane detected
	bool right_flag = false;    // Tells us if there's right boundary of lane detected
	cv::Point right_b;          // Members of both line equations of the lane boundaries:
	double right_m;             // y = m*x + b
	cv::Point left_b;           //
	double left_m;              //

	

public:
	// Apply Gaussian blurring to the input Image
	cv::Mat deNoise(cv::Mat inputImage);

	// Filter the image to obtain only edges
	cv::Mat edgeDetector(cv::Mat img_noise);

	// Mask the edges image to only care about ROI
	cv::Mat mask(cv::Mat img_edges);

	// Detect Hough lines in masked edges image
	std::vector<cv::Vec4i> houghLines(cv::Mat img_mask);

	// Sprt detected lines by their slope into right and left lines
	std::vector<std::vector<cv::Vec4i> > lineSeparation(std::vector<cv::Vec4i> lines, cv::Mat img_edges);

	// Get only one line for each side of the lane
	std::vector<cv::Point> regression(std::vector<std::vector<cv::Vec4i> > left_right_lines, cv::Mat inputImage);

	// Determine if the lane is turning or not by calculating the position of the vanishing point
	std::string predictTurn();

	// Plot the resultant lane and turn prediction in the frame.
	int plotLane(cv::Mat inputImage, std::vector<cv::Point> lane, std::string turn);

	// Performance monitoring functions
	void getPerformanceStats(double& avg_denoise, double& avg_edge, double& avg_mask, 
	                        double& avg_hough, double& avg_separation, double& avg_regression,
	                        double& avg_predict, double& avg_plot, double& avg_total, int& frames);
	void resetPerformanceStats();
};
CC = aarch64-linux-gnu-gcc
CXX = aarch64-linux-gnu-g++
EXE = main
SRC = main.cpp LaneDetector.cpp

BUILD_FLAGS = -Wall
BUILD_FLAGS += -Wl,-rpath-link,/lib \
			-Wl,-rpath-link,/usr/lib \
			-Wl,-rpath-link,/usr/lib/aarch64-linux-gnu \
			-I/usr/local/opencv/include/opencv4 \
			-I/usr/include/aarch64-linux-gnu \
			-I/usr/local/include/opencv \
			-I/usr/include/glib-2.0
BUILD_FLAGS +=-L/usr/local/lib -lopencv_dnn -lopencv_highgui -lopencv_ml -lopencv_objdetect -lopencv_shape -lopencv_stitching -lopencv_superres -lopencv_videostab -lopencv_calib3d -lopencv_videoio -lopencv_imgcodecs -lopencv_features2d -lopencv_video -lopencv_photo -lopencv_imgproc -lopencv_flann -lopencv_core -ldl -lm -lpthread -lrt

all:
	@$(CXX) -g -std=c++11 -o $(EXE) $(SRC) $(BUILD_FLAGS)

clean:
	rm -rf $(EXE) *.o


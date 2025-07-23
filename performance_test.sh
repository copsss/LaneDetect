#!/bin/bash

# 车道偏离预警系统性能测试脚本
# 用于测试单核、单核+NEON、多核、多核+NEON四种配置的性能
# 包含模块执行时间测试和整机执行时间测试

echo "=========================================="
echo "车道偏离预警系统详细性能测试"
echo "测试环境：飞腾派开发板"
echo "测试时间：$(date)"
echo "=========================================="

# 测试参数
VIDEO_FILE="video_project.mp4"
TEST_DURATION=60  # 测试时长（秒）
OUTPUT_DIR="test_results"

# 创建输出目录
mkdir -p $OUTPUT_DIR

# 测试函数
run_performance_test() {
    local config_name=$1
    local cpu_cores=$2
    local use_neon=$3
    
    echo "开始测试配置: $config_name"
    echo "CPU核心数: $cpu_cores"
    echo "NEON优化: $use_neon"
    
    # 设置CPU亲和性（限制使用的核心数）
    if [ "$cpu_cores" -eq 1 ]; then
        export TASKSET="taskset -c 0"
    else
        export TASKSET="taskset -c 0-$(($cpu_cores-1))"
    fi
    
    # 设置NEON优化环境变量
    if [ "$use_neon" = "true" ]; then
        export OPENCV_CPU_OPTIMIZATION=1
        export OPENCV_NEON_OPTIMIZATION=1
        export OPENCV_USE_NEON=1
    else
        export OPENCV_CPU_OPTIMIZATION=0
        export OPENCV_NEON_OPTIMIZATION=0
        export OPENCV_USE_NEON=0
    fi
    
    # 记录开始时间
    start_time=$(date +%s.%N)
    
    # 运行程序并记录输出
    $TASKSET ./main > "$OUTPUT_DIR/${config_name}_output.log" 2>&1
    exit_code=$?
    
    # 记录结束时间
    end_time=$(date +%s.%N)
    
    # 计算运行时间
    runtime=$(echo "$end_time - $start_time" | bc -l)
    
    # 分析输出日志，提取性能数据
    if [ -f "$OUTPUT_DIR/${config_name}_output.log" ]; then
        # 提取整机执行时间
        total_time=$(grep "整机执行时间:" "$OUTPUT_DIR/${config_name}_output.log" | awk '{print $2}')
        total_frames=$(grep "总处理帧数:" "$OUTPUT_DIR/${config_name}_output.log" | awk '{print $2}')
        avg_frame_time=$(grep "平均每帧处理时间:" "$OUTPUT_DIR/${config_name}_output.log" | awk '{print $2}')
        actual_fps=$(grep "实际处理帧率:" "$OUTPUT_DIR/${config_name}_output.log" | awk '{print $2}')
        
        # 提取模块执行时间
        denoise_time=$(grep "图像去噪:" "$OUTPUT_DIR/${config_name}_output.log" | awk '{print $2}')
        edge_time=$(grep "边缘检测:" "$OUTPUT_DIR/${config_name}_output.log" | awk '{print $2}')
        mask_time=$(grep "掩码处理:" "$OUTPUT_DIR/${config_name}_output.log" | awk '{print $2}')
        hough_time=$(grep "Hough变换:" "$OUTPUT_DIR/${config_name}_output.log" | awk '{print $2}')
        separation_time=$(grep "线分离:" "$OUTPUT_DIR/${config_name}_output.log" | awk '{print $2}')
        regression_time=$(grep "回归拟合:" "$OUTPUT_DIR/${config_name}_output.log" | awk '{print $2}')
        predict_time=$(grep "转向预测:" "$OUTPUT_DIR/${config_name}_output.log" | awk '{print $2}')
        plot_time=$(grep "结果绘制:" "$OUTPUT_DIR/${config_name}_output.log" | awk '{print $2}')
        
        # 提取模块时间百分比
        denoise_percent=$(grep "图像去噪:" "$OUTPUT_DIR/${config_name}_output.log" | grep -o '[0-9.]*%' | head -1)
        edge_percent=$(grep "边缘检测:" "$OUTPUT_DIR/${config_name}_output.log" | grep -o '[0-9.]*%' | head -1)
        mask_percent=$(grep "掩码处理:" "$OUTPUT_DIR/${config_name}_output.log" | grep -o '[0-9.]*%' | head -1)
        hough_percent=$(grep "Hough变换:" "$OUTPUT_DIR/${config_name}_output.log" | grep -o '[0-9.]*%' | head -1)
        separation_percent=$(grep "线分离:" "$OUTPUT_DIR/${config_name}_output.log" | grep -o '[0-9.]*%' | head -1)
        regression_percent=$(grep "回归拟合:" "$OUTPUT_DIR/${config_name}_output.log" | grep -o '[0-9.]*%' | head -1)
        predict_percent=$(grep "转向预测:" "$OUTPUT_DIR/${config_name}_output.log" | grep -o '[0-9.]*%' | head -1)
        plot_percent=$(grep "结果绘制:" "$OUTPUT_DIR/${config_name}_output.log" | grep -o '[0-9.]*%' | head -1)
        
        # 提取性能瓶颈信息
        bottleneck=$(grep "主要瓶颈:" "$OUTPUT_DIR/${config_name}_output.log" | cut -d: -f2 | xargs)
        
        # 设置默认值（如果提取失败）
        total_time=${total_time:-"0.00"}
        total_frames=${total_frames:-"0"}
        avg_frame_time=${avg_frame_time:-"0.00"}
        actual_fps=${actual_fps:-"0.00"}
        denoise_time=${denoise_time:-"0.00"}
        edge_time=${edge_time:-"0.00"}
        mask_time=${mask_time:-"0.00"}
        hough_time=${hough_time:-"0.00"}
        separation_time=${separation_time:-"0.00"}
        regression_time=${regression_time:-"0.00"}
        predict_time=${predict_time:-"0.00"}
        plot_time=${plot_time:-"0.00"}
        
    else
        total_time="0.00"
        total_frames="0"
        avg_frame_time="0.00"
        actual_fps="0.00"
        denoise_time="0.00"
        edge_time="0.00"
        mask_time="0.00"
        hough_time="0.00"
        separation_time="0.00"
        regression_time="0.00"
        predict_time="0.00"
        plot_time="0.00"
        denoise_percent="0.00%"
        edge_percent="0.00%"
        mask_percent="0.00%"
        hough_percent="0.00%"
        separation_percent="0.00%"
        regression_percent="0.00%"
        predict_percent="0.00%"
        plot_percent="0.00%"
        bottleneck="未知"
    fi
    
    # 记录测试结果到CSV文件
    echo "$config_name,$cpu_cores,$use_neon,$total_time,$total_frames,$avg_frame_time,$actual_fps,$denoise_time,$edge_time,$mask_time,$hough_time,$separation_time,$regression_time,$predict_time,$plot_time,$denoise_percent,$edge_percent,$mask_percent,$hough_percent,$separation_percent,$regression_percent,$predict_percent,$plot_percent,$bottleneck" >> "$OUTPUT_DIR/detailed_performance_results.csv"
    
    echo "测试完成: $config_name"
    echo "  整机执行时间: ${total_time} ms"
    echo "  总处理帧数: $total_frames"
    echo "  平均每帧处理时间: ${avg_frame_time} ms"
    echo "  实际处理帧率: ${actual_fps} FPS"
    echo "  主要瓶颈: $bottleneck"
    echo "------------------------------------------"
}

# 创建详细结果文件头
echo "配置,CPU核心数,NEON优化,整机执行时间(ms),总帧数,平均帧时间(ms),实际FPS,去噪时间(ms),边缘检测时间(ms),掩码时间(ms),Hough时间(ms),线分离时间(ms),回归时间(ms),预测时间(ms),绘制时间(ms),去噪百分比,边缘检测百分比,掩码百分比,Hough百分比,线分离百分比,回归百分比,预测百分比,绘制百分比,主要瓶颈" > "$OUTPUT_DIR/detailed_performance_results.csv"

# 测试配置1：单核处理
run_performance_test "单核" 1 false

# 测试配置2：单核+NEON
run_performance_test "单核+NEON" 1 true

# 测试配置3：多核处理
run_performance_test "多核" 4 false

# 测试配置4：多核+NEON
run_performance_test "多核+NEON" 4 true

# 生成详细测试报告
echo "=========================================="
echo "详细性能测试结果汇总"
echo "=========================================="

if [ -f "$OUTPUT_DIR/detailed_performance_results.csv" ]; then
    echo "配置,CPU核心数,NEON优化,整机执行时间(ms),总帧数,平均帧时间(ms),实际FPS,主要瓶颈"
    tail -n +2 "$OUTPUT_DIR/detailed_performance_results.csv" | cut -d',' -f1,2,3,4,5,6,7,24
fi

# 生成模块时间对比报告
echo ""
echo "=========================================="
echo "模块执行时间对比分析"
echo "=========================================="

# 创建模块时间对比表
cat > "$OUTPUT_DIR/module_time_comparison.txt" << 'EOF'
模块执行时间对比分析
==========================================

EOF

# 为每个配置生成模块时间对比
for config in "单核" "单核+NEON" "多核" "多核+NEON"; do
    if [ -f "$OUTPUT_DIR/${config}_output.log" ]; then
        echo "配置: $config" >> "$OUTPUT_DIR/module_time_comparison.txt"
        echo "------------------------------------------" >> "$OUTPUT_DIR/module_time_comparison.txt"
        grep -E "(图像去噪|边缘检测|掩码处理|Hough变换|线分离|回归拟合|转向预测|结果绘制):" "$OUTPUT_DIR/${config}_output.log" >> "$OUTPUT_DIR/module_time_comparison.txt"
        echo "" >> "$OUTPUT_DIR/module_time_comparison.txt"
    fi
done

# 生成性能提升分析
echo "=========================================="
echo "性能提升分析"
echo "=========================================="

# 计算性能提升
if [ -f "$OUTPUT_DIR/detailed_performance_results.csv" ]; then
    # 提取基准性能（单核）
    baseline_fps=$(tail -n +2 "$OUTPUT_DIR/detailed_performance_results.csv" | head -1 | cut -d',' -f7)
    
    echo "基准性能（单核）: ${baseline_fps} FPS"
    echo ""
    
    # 计算各配置相对于基准的提升
    line_num=2
    for config in "单核+NEON" "多核" "多核+NEON"; do
        current_fps=$(tail -n +$line_num "$OUTPUT_DIR/detailed_performance_results.csv" | head -1 | cut -d',' -f7)
        if [ "$baseline_fps" != "0.00" ] && [ "$current_fps" != "0.00" ]; then
            improvement=$(echo "scale=1; ($current_fps - $baseline_fps) * 100 / $baseline_fps" | bc -l)
            echo "$config: ${current_fps} FPS (提升 ${improvement}%)"
        else
            echo "$config: ${current_fps} FPS (提升计算失败)"
        fi
        line_num=$((line_num + 1))
    done
fi

echo ""
echo "详细测试报告文件:"
echo "- 完整性能数据: $OUTPUT_DIR/detailed_performance_results.csv"
echo "- 模块时间对比: $OUTPUT_DIR/module_time_comparison.txt"
echo "- 各配置详细日志: $OUTPUT_DIR/*_output.log"
echo ""
echo "测试完成时间: $(date)" 
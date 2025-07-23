#!/bin/bash

# 车道偏离预警系统性能测试脚本
# 用于测试单核、单核+NEON、多核、多核+NEON四种配置的性能

echo "=========================================="
echo "车道偏离预警系统性能测试"
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
    else
        export OPENCV_CPU_OPTIMIZATION=0
        export OPENCV_NEON_OPTIMIZATION=0
    fi
    
    # 记录开始时间
    start_time=$(date +%s.%N)
    
    # 运行程序并记录输出
    $TASKSET ./main > "$OUTPUT_DIR/${config_name}_output.log" 2>&1 &
    main_pid=$!
    
    # 监控CPU使用率
    top -p $main_pid -b -n 1 > "$OUTPUT_DIR/${config_name}_cpu_usage.log" &
    top_pid=$!
    
    # 等待程序运行完成或超时
    sleep $TEST_DURATION
    
    # 停止监控
    kill $top_pid 2>/dev/null
    
    # 记录结束时间
    end_time=$(date +%s.%N)
    
    # 计算运行时间
    runtime=$(echo "$end_time - $start_time" | bc -l)
    
    # 分析输出日志，提取帧率信息
    if [ -f "$OUTPUT_DIR/${config_name}_output.log" ]; then
        # 统计处理的总帧数
        total_frames=$(grep -c "检测到车道线\|未检测到车道线" "$OUTPUT_DIR/${config_name}_output.log" 2>/dev/null || echo "0")
        
        # 计算平均帧率
        if [ "$total_frames" -gt 0 ] && [ "$runtime" != "0" ]; then
            fps=$(echo "scale=2; $total_frames / $runtime" | bc -l)
        else
            fps="0.00"
        fi
        
        # 计算平均处理时间（毫秒）
        avg_time=$(echo "scale=2; 1000 / $fps" | bc -l 2>/dev/null || echo "0.00")
    else
        fps="0.00"
        avg_time="0.00"
    fi
    
    # 记录测试结果
    echo "$config_name,$cpu_cores,$use_neon,$fps,$avg_time,$runtime" >> "$OUTPUT_DIR/performance_results.csv"
    
    echo "测试完成: $config_name"
    echo "  总帧数: $total_frames"
    echo "  平均帧率: ${fps} FPS"
    echo "  平均处理时间: ${avg_time} ms"
    echo "  总运行时间: ${runtime} 秒"
    echo "------------------------------------------"
}

# 创建结果文件头
echo "配置,CPU核心数,NEON优化,帧率(FPS),处理时间(ms),运行时间(s)" > "$OUTPUT_DIR/performance_results.csv"

# 测试配置1：单核处理
run_performance_test "单核" 1 false

# 测试配置2：单核+NEON
run_performance_test "单核+NEON" 1 true

# 测试配置3：多核处理
run_performance_test "多核" 4 false

# 测试配置4：多核+NEON
run_performance_test "多核+NEON" 4 true

# 生成测试报告
echo "=========================================="
echo "性能测试结果汇总"
echo "=========================================="

if [ -f "$OUTPUT_DIR/performance_results.csv" ]; then
    echo "配置,CPU核心数,NEON优化,帧率(FPS),处理时间(ms),运行时间(s)"
    tail -n +2 "$OUTPUT_DIR/performance_results.csv"
fi

echo ""
echo "详细日志文件保存在: $OUTPUT_DIR/"
echo "测试完成时间: $(date)" 
#!/bin/bash

# 车道偏离预警系统模块性能测试脚本
# 专门用于测试各个模块的执行时间和性能瓶颈

echo "=========================================="
echo "车道偏离预警系统模块性能测试"
echo "测试环境：飞腾派开发板"
echo "测试时间：$(date)"
echo "=========================================="

# 测试参数
OUTPUT_DIR="module_test_results"
TEST_ITERATIONS=5  # 每个模块测试5次取平均值

# 创建输出目录
mkdir -p $OUTPUT_DIR

# 模块性能测试函数
test_module_performance() {
    local config_name=$1
    local cpu_cores=$2
    local use_neon=$3
    
    echo "开始模块性能测试: $config_name"
    echo "CPU核心数: $cpu_cores"
    echo "NEON优化: $use_neon"
    
    # 设置CPU亲和性
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
    
    # 运行多次测试取平均值
    for i in $(seq 1 $TEST_ITERATIONS); do
        echo "  第 $i 次测试..."
        
        # 运行程序
        $TASKSET ./main > "$OUTPUT_DIR/${config_name}_test${i}.log" 2>&1
        
        # 提取模块时间数据
        if [ -f "$OUTPUT_DIR/${config_name}_test${i}.log" ]; then
            # 提取整机执行时间
            total_time=$(grep "整机执行时间:" "$OUTPUT_DIR/${config_name}_test${i}.log" | awk '{print $2}')
            total_frames=$(grep "总处理帧数:" "$OUTPUT_DIR/${config_name}_test${i}.log" | awk '{print $2}')
            
            # 提取各模块执行时间
            denoise_time=$(grep "图像去噪:" "$OUTPUT_DIR/${config_name}_test${i}.log" | awk '{print $2}')
            edge_time=$(grep "边缘检测:" "$OUTPUT_DIR/${config_name}_test${i}.log" | awk '{print $2}')
            mask_time=$(grep "掩码处理:" "$OUTPUT_DIR/${config_name}_test${i}.log" | awk '{print $2}')
            hough_time=$(grep "Hough变换:" "$OUTPUT_DIR/${config_name}_test${i}.log" | awk '{print $2}')
            separation_time=$(grep "线分离:" "$OUTPUT_DIR/${config_name}_test${i}.log" | awk '{print $2}')
            regression_time=$(grep "回归拟合:" "$OUTPUT_DIR/${config_name}_test${i}.log" | awk '{print $2}')
            predict_time=$(grep "转向预测:" "$OUTPUT_DIR/${config_name}_test${i}.log" | awk '{print $2}')
            plot_time=$(grep "结果绘制:" "$OUTPUT_DIR/${config_name}_test${i}.log" | awk '{print $2}')
            
            # 记录到临时文件
            echo "$total_time,$total_frames,$denoise_time,$edge_time,$mask_time,$hough_time,$separation_time,$regression_time,$predict_time,$plot_time" >> "$OUTPUT_DIR/${config_name}_raw_data.csv"
        fi
    done
    
    # 计算平均值
    if [ -f "$OUTPUT_DIR/${config_name}_raw_data.csv" ]; then
        # 计算各列的平均值
        avg_total_time=$(awk -F',' '{sum+=$1} END {print sum/NR}' "$OUTPUT_DIR/${config_name}_raw_data.csv")
        avg_total_frames=$(awk -F',' '{sum+=$2} END {print sum/NR}' "$OUTPUT_DIR/${config_name}_raw_data.csv")
        avg_denoise_time=$(awk -F',' '{sum+=$3} END {print sum/NR}' "$OUTPUT_DIR/${config_name}_raw_data.csv")
        avg_edge_time=$(awk -F',' '{sum+=$4} END {print sum/NR}' "$OUTPUT_DIR/${config_name}_raw_data.csv")
        avg_mask_time=$(awk -F',' '{sum+=$5} END {print sum/NR}' "$OUTPUT_DIR/${config_name}_raw_data.csv")
        avg_hough_time=$(awk -F',' '{sum+=$6} END {print sum/NR}' "$OUTPUT_DIR/${config_name}_raw_data.csv")
        avg_separation_time=$(awk -F',' '{sum+=$7} END {print sum/NR}' "$OUTPUT_DIR/${config_name}_raw_data.csv")
        avg_regression_time=$(awk -F',' '{sum+=$8} END {print sum/NR}' "$OUTPUT_DIR/${config_name}_raw_data.csv")
        avg_predict_time=$(awk -F',' '{sum+=$9} END {print sum/NR}' "$OUTPUT_DIR/${config_name}_raw_data.csv")
        avg_plot_time=$(awk -F',' '{sum+=$10} END {print sum/NR}' "$OUTPUT_DIR/${config_name}_raw_data.csv")
        
        # 计算总平均时间
        avg_total_module_time=$(echo "$avg_denoise_time + $avg_edge_time + $avg_mask_time + $avg_hough_time + $avg_separation_time + $avg_regression_time + $avg_predict_time + $avg_plot_time" | bc -l)
        
        # 计算各模块占比
        denoise_percent=$(echo "scale=2; $avg_denoise_time * 100 / $avg_total_module_time" | bc -l)
        edge_percent=$(echo "scale=2; $avg_edge_time * 100 / $avg_total_module_time" | bc -l)
        mask_percent=$(echo "scale=2; $avg_mask_time * 100 / $avg_total_module_time" | bc -l)
        hough_percent=$(echo "scale=2; $avg_hough_time * 100 / $avg_total_module_time" | bc -l)
        separation_percent=$(echo "scale=2; $avg_separation_time * 100 / $avg_total_module_time" | bc -l)
        regression_percent=$(echo "scale=2; $avg_regression_time * 100 / $avg_total_module_time" | bc -l)
        predict_percent=$(echo "scale=2; $avg_predict_time * 100 / $avg_total_module_time" | bc -l)
        plot_percent=$(echo "scale=2; $avg_plot_time * 100 / $avg_total_module_time" | bc -l)
        
        # 记录平均结果
        echo "$config_name,$cpu_cores,$use_neon,$avg_total_time,$avg_total_frames,$avg_denoise_time,$avg_edge_time,$avg_mask_time,$avg_hough_time,$avg_separation_time,$avg_regression_time,$avg_predict_time,$avg_plot_time,$denoise_percent,$edge_percent,$mask_percent,$hough_percent,$separation_percent,$regression_percent,$predict_percent,$plot_percent" >> "$OUTPUT_DIR/module_performance_summary.csv"
        
        echo "测试完成: $config_name"
        echo "  平均整机执行时间: ${avg_total_time} ms"
        echo "  平均总帧数: $avg_total_frames"
        echo "  平均模块总时间: ${avg_total_module_time} ms"
        echo "  主要瓶颈模块: $(get_bottleneck_module $avg_denoise_time $avg_edge_time $avg_mask_time $avg_hough_time $avg_separation_time $avg_regression_time $avg_predict_time $avg_plot_time)"
        echo "------------------------------------------"
    fi
}

# 获取瓶颈模块函数
get_bottleneck_module() {
    local denoise=$1
    local edge=$2
    local mask=$3
    local hough=$4
    local separation=$5
    local regression=$6
    local predict=$7
    local plot=$8
    
    local max_time=$(echo "$denoise $edge $mask $hough $separation $regression $predict $plot" | tr ' ' '\n' | sort -nr | head -1)
    
    if [ "$max_time" = "$hough" ]; then
        echo "Hough变换 (${hough} ms)"
    elif [ "$max_time" = "$edge" ]; then
        echo "边缘检测 (${edge} ms)"
    elif [ "$max_time" = "$regression" ]; then
        echo "回归拟合 (${regression} ms)"
    elif [ "$max_time" = "$plot" ]; then
        echo "结果绘制 (${plot} ms)"
    elif [ "$max_time" = "$denoise" ]; then
        echo "图像去噪 (${denoise} ms)"
    elif [ "$max_time" = "$separation" ]; then
        echo "线分离 (${separation} ms)"
    elif [ "$max_time" = "$mask" ]; then
        echo "掩码处理 (${mask} ms)"
    elif [ "$max_time" = "$predict" ]; then
        echo "转向预测 (${predict} ms)"
    else
        echo "未知"
    fi
}

# 创建结果文件头
echo "配置,CPU核心数,NEON优化,整机执行时间(ms),总帧数,去噪时间(ms),边缘检测时间(ms),掩码时间(ms),Hough时间(ms),线分离时间(ms),回归时间(ms),预测时间(ms),绘制时间(ms),去噪百分比,边缘检测百分比,掩码百分比,Hough百分比,线分离百分比,回归百分比,预测百分比,绘制百分比" > "$OUTPUT_DIR/module_performance_summary.csv"

# 测试各配置
test_module_performance "单核" 1 false
test_module_performance "单核+NEON" 1 true
test_module_performance "多核" 4 false
test_module_performance "多核+NEON" 4 true

# 生成模块性能分析报告
echo "=========================================="
echo "模块性能分析报告"
echo "=========================================="

# 创建详细分析报告
cat > "$OUTPUT_DIR/module_analysis_report.txt" << 'EOF'
车道偏离预警系统模块性能分析报告
==========================================

测试配置说明:
- 单核: 仅使用单个CPU核心
- 单核+NEON: 单核CPU + NEON指令集优化
- 多核: 使用多个CPU核心并行处理
- 多核+NEON: 多核CPU + NEON指令集优化

测试方法:
- 每个配置运行5次测试
- 取各模块执行时间的平均值
- 分析各模块在总处理时间中的占比
- 识别性能瓶颈模块

EOF

# 添加各配置的详细分析
for config in "单核" "单核+NEON" "多核" "多核+NEON"; do
    if [ -f "$OUTPUT_DIR/${config}_raw_data.csv" ]; then
        echo "配置: $config" >> "$OUTPUT_DIR/module_analysis_report.txt"
        echo "------------------------------------------" >> "$OUTPUT_DIR/module_analysis_report.txt"
        
        # 提取该配置的平均数据
        config_data=$(grep "^$config," "$OUTPUT_DIR/module_performance_summary.csv")
        if [ ! -z "$config_data" ]; then
            echo "整机执行时间: $(echo $config_data | cut -d',' -f4) ms" >> "$OUTPUT_DIR/module_analysis_report.txt"
            echo "总处理帧数: $(echo $config_data | cut -d',' -f5)" >> "$OUTPUT_DIR/module_analysis_report.txt"
            echo "" >> "$OUTPUT_DIR/module_analysis_report.txt"
            echo "模块执行时间分析:" >> "$OUTPUT_DIR/module_analysis_report.txt"
            echo "  图像去噪: $(echo $config_data | cut -d',' -f6) ms ($(echo $config_data | cut -d',' -f13)%)" >> "$OUTPUT_DIR/module_analysis_report.txt"
            echo "  边缘检测: $(echo $config_data | cut -d',' -f7) ms ($(echo $config_data | cut -d',' -f14)%)" >> "$OUTPUT_DIR/module_analysis_report.txt"
            echo "  掩码处理: $(echo $config_data | cut -d',' -f8) ms ($(echo $config_data | cut -d',' -f15)%)" >> "$OUTPUT_DIR/module_analysis_report.txt"
            echo "  Hough变换: $(echo $config_data | cut -d',' -f9) ms ($(echo $config_data | cut -d',' -f16)%)" >> "$OUTPUT_DIR/module_analysis_report.txt"
            echo "  线分离: $(echo $config_data | cut -d',' -f10) ms ($(echo $config_data | cut -d',' -f17)%)" >> "$OUTPUT_DIR/module_analysis_report.txt"
            echo "  回归拟合: $(echo $config_data | cut -d',' -f11) ms ($(echo $config_data | cut -d',' -f18)%)" >> "$OUTPUT_DIR/module_analysis_report.txt"
            echo "  转向预测: $(echo $config_data | cut -d',' -f12) ms ($(echo $config_data | cut -d',' -f19)%)" >> "$OUTPUT_DIR/module_analysis_report.txt"
            echo "  结果绘制: $(echo $config_data | cut -d',' -f13) ms ($(echo $config_data | cut -d',' -f20)%)" >> "$OUTPUT_DIR/module_analysis_report.txt"
        fi
        echo "" >> "$OUTPUT_DIR/module_analysis_report.txt"
    fi
done

# 生成性能对比表
echo "=========================================="
echo "模块性能对比表"
echo "=========================================="

if [ -f "$OUTPUT_DIR/module_performance_summary.csv" ]; then
    echo "配置,CPU核心数,NEON优化,整机执行时间(ms),总帧数,主要瓶颈模块"
    tail -n +2 "$OUTPUT_DIR/module_performance_summary.csv" | cut -d',' -f1,2,3,4,5
fi

# 生成优化建议
echo ""
echo "=========================================="
echo "性能优化建议"
echo "=========================================="

cat >> "$OUTPUT_DIR/module_analysis_report.txt" << 'EOF'

性能优化建议:
==========================================

1. Hough变换优化:
   - 如果Hough变换占用时间超过30%，建议:
     * 优化Hough变换参数
     * 使用更高效的直线检测算法
     * 考虑使用GPU加速

2. 边缘检测优化:
   - 如果边缘检测占用时间超过20%，建议:
     * 使用NEON指令集优化
     * 减少图像分辨率
     * 使用更高效的边缘检测算子

3. 回归拟合优化:
   - 如果回归拟合占用时间较多，建议:
     * 优化拟合算法
     * 减少拟合点数量
     * 使用更简单的拟合方法

4. 结果绘制优化:
   - 如果绘制操作占用时间超过15%，建议:
     * 减少不必要的图形操作
     * 优化绘制算法
     * 考虑异步绘制

5. 多核优化:
   - 对于多核配置，建议:
     * 将图像分割为多个区域并行处理
     * 使用线程池管理任务分配
     * 优化数据共享和同步机制

6. NEON优化:
   - 对于NEON配置，建议:
     * 确保数据对齐
     * 使用向量化指令
     * 优化内存访问模式

EOF

echo "详细分析报告已保存到: $OUTPUT_DIR/module_analysis_report.txt"
echo "模块性能数据已保存到: $OUTPUT_DIR/module_performance_summary.csv"
echo "原始测试数据保存在: $OUTPUT_DIR/*_raw_data.csv"
echo ""
echo "测试完成时间: $(date)" 
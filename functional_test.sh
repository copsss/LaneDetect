#!/bin/bash

# 车道偏离预警系统功能测试脚本
# 用于测试系统的各项功能是否正常工作

echo "=========================================="
echo "车道偏离预警系统功能测试"
echo "测试时间：$(date)"
echo "=========================================="

# 测试参数
OUTPUT_DIR="functional_test_results"
TEST_VIDEOS=("video_project.mp4" "video_challenge.mp4" "video_harder_challenge.mp4")

# 创建输出目录
mkdir -p $OUTPUT_DIR

# 测试结果统计
total_tests=0
passed_tests=0
failed_tests=0

# 测试函数
run_functional_test() {
    local test_name=$1
    local video_file=$2
    local expected_result=$3
    
    total_tests=$((total_tests + 1))
    
    echo "执行测试: $test_name"
    echo "测试视频: $video_file"
    echo "预期结果: $expected_result"
    
    # 检查视频文件是否存在
    if [ ! -f "$video_file" ]; then
        echo "❌ 测试失败: 视频文件 $video_file 不存在"
        failed_tests=$((failed_tests + 1))
        return 1
    fi
    
    # 临时修改程序以使用指定的视频文件
    cp main main_backup
    sed -i "s/video_project.mp4/$video_file/g" main.cpp
    
    # 重新编译
    make clean > /dev/null 2>&1
    make all > /dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        echo "❌ 测试失败: 编译失败"
        failed_tests=$((failed_tests + 1))
        # 恢复备份
        mv main_backup main
        return 1
    fi
    
    # 运行程序（限制运行时间）
    timeout 30s ./main > "$OUTPUT_DIR/${test_name}_output.log" 2>&1
    exit_code=$?
    
    # 恢复备份
    mv main_backup main
    make clean > /dev/null 2>&1
    make all > /dev/null 2>&1
    
    # 分析测试结果
    if [ $exit_code -eq 0 ]; then
        # 检查输出文件是否生成
        if [ -f "output_lane_detection_color.avi" ] && [ -f "output_edge_detection_bw.avi" ]; then
            echo "✅ 测试通过: $test_name"
            echo "  生成文件: output_lane_detection_color.avi, output_edge_detection_bw.avi"
            passed_tests=$((passed_tests + 1))
            
            # 移动输出文件到测试结果目录
            mv output_lane_detection_color.avi "$OUTPUT_DIR/${test_name}_color.avi"
            mv output_edge_detection_bw.avi "$OUTPUT_DIR/${test_name}_bw.avi"
            
            return 0
        else
            echo "❌ 测试失败: $test_name - 未生成输出文件"
            failed_tests=$((failed_tests + 1))
            return 1
        fi
    else
        echo "❌ 测试失败: $test_name - 程序异常退出 (退出码: $exit_code)"
        failed_tests=$((failed_tests + 1))
        return 1
    fi
}

# 测试用例1：正常车道线检测
echo "=========================================="
echo "测试用例1：正常车道线检测"
echo "=========================================="
run_functional_test "TC001_正常车道线检测" "video_project.mp4" "正确识别左右车道线"

# 测试用例2：弯道检测
echo "=========================================="
echo "测试用例2：弯道检测"
echo "=========================================="
run_functional_test "TC002_弯道检测" "video_challenge.mp4" "正确识别弯道方向"

# 测试用例3：复杂场景检测
echo "=========================================="
echo "测试用例3：复杂场景检测"
echo "=========================================="
run_functional_test "TC003_复杂场景检测" "video_harder_challenge.mp4" "对复杂场景具有鲁棒性"

# 测试用例4：边缘检测功能
echo "=========================================="
echo "测试用例4：边缘检测功能"
echo "=========================================="
echo "检查边缘检测输出文件..."
if [ -f "$OUTPUT_DIR/TC001_正常车道线检测_bw.avi" ]; then
    file_size=$(stat -c%s "$OUTPUT_DIR/TC001_正常车道线检测_bw.avi" 2>/dev/null || echo "0")
    if [ "$file_size" -gt 1000 ]; then
        echo "✅ 边缘检测功能正常 - 输出文件大小: ${file_size} 字节"
        passed_tests=$((passed_tests + 1))
    else
        echo "❌ 边缘检测功能异常 - 输出文件过小"
        failed_tests=$((failed_tests + 1))
    fi
else
    echo "❌ 边缘检测功能异常 - 未找到输出文件"
    failed_tests=$((failed_tests + 1))
fi
total_tests=$((total_tests + 1))

# 测试用例5：车道线检测功能
echo "=========================================="
echo "测试用例5：车道线检测功能"
echo "=========================================="
echo "检查车道线检测输出文件..."
if [ -f "$OUTPUT_DIR/TC001_正常车道线检测_color.avi" ]; then
    file_size=$(stat -c%s "$OUTPUT_DIR/TC001_正常车道线检测_color.avi" 2>/dev/null || echo "0")
    if [ "$file_size" -gt 1000 ]; then
        echo "✅ 车道线检测功能正常 - 输出文件大小: ${file_size} 字节"
        passed_tests=$((passed_tests + 1))
    else
        echo "❌ 车道线检测功能异常 - 输出文件过小"
        failed_tests=$((failed_tests + 1))
    fi
else
    echo "❌ 车道线检测功能异常 - 未找到输出文件"
    failed_tests=$((failed_tests + 1))
fi
total_tests=$((total_tests + 1))

# 测试用例6：系统稳定性测试
echo "=========================================="
echo "测试用例6：系统稳定性测试"
echo "=========================================="
echo "运行稳定性测试（连续运行5次）..."
stability_passed=0
for i in {1..5}; do
    echo "  第 $i 次运行..."
    timeout 10s ./main > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        stability_passed=$((stability_passed + 1))
    fi
done

if [ $stability_passed -eq 5 ]; then
    echo "✅ 系统稳定性测试通过 - 5/5 次运行成功"
    passed_tests=$((passed_tests + 1))
else
    echo "❌ 系统稳定性测试失败 - $stability_passed/5 次运行成功"
    failed_tests=$((failed_tests + 1))
fi
total_tests=$((total_tests + 1))

# 生成测试报告
echo "=========================================="
echo "功能测试结果汇总"
echo "=========================================="
echo "总测试数: $total_tests"
echo "通过测试: $passed_tests"
echo "失败测试: $failed_tests"
echo "通过率: $(echo "scale=1; $passed_tests * 100 / $total_tests" | bc -l)%"

# 保存测试结果到文件
cat > "$OUTPUT_DIR/functional_test_report.txt" << EOF
车道偏离预警系统功能测试报告
==========================================
测试时间: $(date)
总测试数: $total_tests
通过测试: $passed_tests
失败测试: $failed_tests
通过率: $(echo "scale=1; $passed_tests * 100 / $total_tests" | bc -l)%

测试用例详情:
1. TC001_正常车道线检测: $(if [ -f "$OUTPUT_DIR/TC001_正常车道线检测_color.avi" ]; then echo "通过"; else echo "失败"; fi)
2. TC002_弯道检测: $(if [ -f "$OUTPUT_DIR/TC002_弯道检测_color.avi" ]; then echo "通过"; else echo "失败"; fi)
3. TC003_复杂场景检测: $(if [ -f "$OUTPUT_DIR/TC003_复杂场景检测_color.avi" ]; then echo "通过"; else echo "失败"; fi)
4. TC004_边缘检测功能: $(if [ -f "$OUTPUT_DIR/TC001_正常车道线检测_bw.avi" ]; then echo "通过"; else echo "失败"; fi)
5. TC005_车道线检测功能: $(if [ -f "$OUTPUT_DIR/TC001_正常车道线检测_color.avi" ]; then echo "通过"; else echo "失败"; fi)
6. TC006_系统稳定性测试: $(if [ $stability_passed -eq 5 ]; then echo "通过"; else echo "失败"; fi)

输出文件位置: $OUTPUT_DIR/
EOF

echo ""
echo "详细测试报告保存在: $OUTPUT_DIR/functional_test_report.txt"
echo "测试完成时间: $(date)" 
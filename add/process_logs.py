#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import re
import csv
import glob
from collections import defaultdict

def extract_data_from_log(log_file):
    """从日志文件中提取性能数据"""
    data = {
        'total_time': None,
        'total_frames': None,
        'denoise_time': None,
        'edge_time': None,
        'mask_time': None,
        'hough_time': None,
        'separation_time': None,
        'regression_time': None,
        'predict_time': None,
        'plot_time': None
    }
    
    try:
        with open(log_file, 'r', encoding='utf-8') as f:
            content = f.read()
            
        # 提取整机执行时间
        match = re.search(r'整机执行时间:\s*([\d.]+)\s*ms', content)
        if match:
            data['total_time'] = float(match.group(1))
            
        # 提取总处理帧数
        match = re.search(r'总处理帧数:\s*(\d+)', content)
        if match:
            data['total_frames'] = int(match.group(1))
            
        # 提取各模块执行时间
        patterns = {
            'denoise_time': r'图像去噪:\s*([\d.]+)\s*ms',
            'edge_time': r'边缘检测:\s*([\d.]+)\s*ms',
            'mask_time': r'掩码处理:\s*([\d.]+)\s*ms',
            'hough_time': r'Hough变换:\s*([\d.]+)\s*ms',
            'separation_time': r'线分离:\s*([\d.]+)\s*ms',
            'regression_time': r'回归拟合:\s*([\d.]+)\s*ms',
            'predict_time': r'转向预测:\s*([\d.]+)\s*ms',
            'plot_time': r'结果绘制:\s*([\d.]+)\s*ms'
        }
        
        for key, pattern in patterns.items():
            match = re.search(pattern, content)
            if match:
                data[key] = float(match.group(1))
            else:
                data[key] = 0.0
                
    except Exception as e:
        print(f"处理文件 {log_file} 时出错: {e}")
        
    return data

def process_all_logs():
    """处理所有日志文件并生成CSV"""
    log_dir = "module_test_results"
    
    # 配置信息
    configs = {
        "单核": {"cpu_cores": 1, "neon": False},
        "单核+NEON": {"cpu_cores": 1, "neon": True},
        "多核": {"cpu_cores": 4, "neon": False},
        "多核+NEON": {"cpu_cores": 4, "neon": True}
    }
    
    # 存储所有数据
    all_data = defaultdict(list)
    
    # 处理每个配置的日志文件
    for config_name in configs.keys():
        pattern = os.path.join(log_dir, f"{config_name}_test*.log")
        log_files = glob.glob(pattern)
        
        print(f"处理配置 {config_name}: 找到 {len(log_files)} 个日志文件")
        
        for log_file in sorted(log_files):
            data = extract_data_from_log(log_file)
            if data['total_time'] is not None:  # 只处理成功提取数据的文件
                all_data[config_name].append(data)
                print(f"  {os.path.basename(log_file)}: 整机时间={data['total_time']}ms, 帧数={data['total_frames']}")
    
    # 计算平均值并生成CSV
    csv_file = os.path.join(log_dir, "processed_performance_summary.csv")
    
    with open(csv_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        
        # 写入表头
        header = [
            "配置", "CPU核心数", "NEON优化", "整机执行时间(ms)", "总帧数",
            "去噪时间(ms)", "边缘检测时间(ms)", "掩码时间(ms)", "Hough时间(ms)",
            "线分离时间(ms)", "回归时间(ms)", "预测时间(ms)", "绘制时间(ms)",
            "去噪百分比", "边缘检测百分比", "掩码百分比", "Hough百分比",
            "线分离百分比", "回归百分比", "预测百分比", "绘制百分比"
        ]
        writer.writerow(header)
        
        # 处理每个配置的数据
        for config_name, config_info in configs.items():
            if config_name in all_data and all_data[config_name]:
                data_list = all_data[config_name]
                
                # 计算平均值
                avg_data = {}
                for key in ['total_time', 'total_frames', 'denoise_time', 'edge_time', 
                           'mask_time', 'hough_time', 'separation_time', 'regression_time', 
                           'predict_time', 'plot_time']:
                    values = [d[key] for d in data_list if d[key] is not None]
                    if values:
                        avg_data[key] = sum(values) / len(values)
                    else:
                        avg_data[key] = 0.0
                
                # 计算模块总时间
                module_total = (avg_data['denoise_time'] + avg_data['edge_time'] + 
                              avg_data['mask_time'] + avg_data['hough_time'] + 
                              avg_data['separation_time'] + avg_data['regression_time'] + 
                              avg_data['predict_time'] + avg_data['plot_time'])
                
                # 计算百分比
                percentages = {}
                if module_total > 0.001:
                    percentages['denoise'] = (avg_data['denoise_time'] / module_total) * 100
                    percentages['edge'] = (avg_data['edge_time'] / module_total) * 100
                    percentages['mask'] = (avg_data['mask_time'] / module_total) * 100
                    percentages['hough'] = (avg_data['hough_time'] / module_total) * 100
                    percentages['separation'] = (avg_data['separation_time'] / module_total) * 100
                    percentages['regression'] = (avg_data['regression_time'] / module_total) * 100
                    percentages['predict'] = (avg_data['predict_time'] / module_total) * 100
                    percentages['plot'] = (avg_data['plot_time'] / module_total) * 100
                else:
                    percentages = {key: 0.0 for key in ['denoise', 'edge', 'mask', 'hough', 
                                                      'separation', 'regression', 'predict', 'plot']}
                
                # 写入数据行
                row = [
                    config_name,
                    config_info['cpu_cores'],
                    str(config_info['neon']).lower(),
                    f"{avg_data['total_time']:.3f}",
                    f"{avg_data['total_frames']:.0f}",
                    f"{avg_data['denoise_time']:.3f}",
                    f"{avg_data['edge_time']:.3f}",
                    f"{avg_data['mask_time']:.3f}",
                    f"{avg_data['hough_time']:.3f}",
                    f"{avg_data['separation_time']:.3f}",
                    f"{avg_data['regression_time']:.3f}",
                    f"{avg_data['predict_time']:.3f}",
                    f"{avg_data['plot_time']:.3f}",
                    f"{percentages['denoise']:.2f}",
                    f"{percentages['edge']:.2f}",
                    f"{percentages['mask']:.2f}",
                    f"{percentages['hough']:.2f}",
                    f"{percentages['separation']:.2f}",
                    f"{percentages['regression']:.2f}",
                    f"{percentages['predict']:.2f}",
                    f"{percentages['plot']:.2f}"
                ]
                writer.writerow(row)
                
                print(f"配置 {config_name} 处理完成:")
                print(f"  平均整机时间: {avg_data['total_time']:.3f} ms")
                print(f"  平均帧数: {avg_data['total_frames']:.0f}")
                print(f"  平均模块总时间: {module_total:.3f} ms")
                
                # 找出瓶颈模块
                module_times = {
                    'Hough变换': avg_data['hough_time'],
                    '边缘检测': avg_data['edge_time'],
                    '图像去噪': avg_data['denoise_time'],
                    '结果绘制': avg_data['plot_time'],
                    '掩码处理': avg_data['mask_time'],
                    '回归拟合': avg_data['regression_time'],
                    '线分离': avg_data['separation_time'],
                    '转向预测': avg_data['predict_time']
                }
                bottleneck = max(module_times.items(), key=lambda x: x[1])
                print(f"  主要瓶颈: {bottleneck[0]} ({bottleneck[1]:.3f} ms)")
                print()
    
    print(f"处理完成！结果已保存到: {csv_file}")
    return csv_file

def generate_detailed_analysis():
    """生成详细分析报告"""
    csv_file = "module_test_results/processed_performance_summary.csv"
    
    if not os.path.exists(csv_file):
        print("CSV文件不存在，请先运行数据处理")
        return
    
    analysis_file = "module_test_results/detailed_analysis_report.txt"
    
    with open(analysis_file, 'w', encoding='utf-8') as f:
        f.write("车道偏离预警系统详细性能分析报告\n")
        f.write("=" * 50 + "\n\n")
        
        # 读取CSV数据
        with open(csv_file, 'r', encoding='utf-8') as csv_f:
            reader = csv.DictReader(csv_f)
            data = list(reader)
        
        # 性能对比分析
        f.write("1. 整体性能对比\n")
        f.write("-" * 30 + "\n")
        for row in data:
            f.write(f"配置: {row['配置']}\n")
            f.write(f"  整机执行时间: {row['整机执行时间(ms)']} ms\n")
            f.write(f"  处理帧数: {row['总帧数']}\n")
            f.write(f"  理论帧率: {1000/float(row['整机执行时间(ms)']):.2f} FPS\n")
            f.write("\n")
        
        # 模块性能分析
        f.write("2. 模块性能分析\n")
        f.write("-" * 30 + "\n")
        for row in data:
            f.write(f"配置: {row['配置']}\n")
            f.write("  模块执行时间占比:\n")
            f.write(f"    图像去噪: {row['去噪时间(ms)']} ms ({row['去噪百分比']}%)\n")
            f.write(f"    边缘检测: {row['边缘检测时间(ms)']} ms ({row['边缘检测百分比']}%)\n")
            f.write(f"    掩码处理: {row['掩码时间(ms)']} ms ({row['掩码百分比']}%)\n")
            f.write(f"    Hough变换: {row['Hough时间(ms)']} ms ({row['Hough百分比']}%)\n")
            f.write(f"    线分离: {row['线分离时间(ms)']} ms ({row['线分离百分比']}%)\n")
            f.write(f"    回归拟合: {row['回归时间(ms)']} ms ({row['回归百分比']}%)\n")
            f.write(f"    转向预测: {row['预测时间(ms)']} ms ({row['预测百分比']}%)\n")
            f.write(f"    结果绘制: {row['绘制时间(ms)']} ms ({row['绘制百分比']}%)\n")
            f.write("\n")
        
        # 优化建议
        f.write("3. 性能优化建议\n")
        f.write("-" * 30 + "\n")
        for row in data:
            f.write(f"配置 {row['配置']}:\n")
            hough_percent = float(row['Hough百分比'])
            edge_percent = float(row['边缘检测百分比'])
            plot_percent = float(row['绘制百分比'])
            
            if hough_percent > 25:
                f.write(f"  - Hough变换占用时间较多({hough_percent:.1f}%)，建议优化参数或使用更高效的直线检测算法\n")
            if edge_percent > 20:
                f.write(f"  - 边缘检测占用时间较多({edge_percent:.1f}%)，建议使用NEON指令集优化\n")
            if plot_percent > 15:
                f.write(f"  - 绘制操作占用时间较多({plot_percent:.1f}%)，建议减少不必要的图形操作\n")
            f.write("\n")
    
    print(f"详细分析报告已生成: {analysis_file}")

if __name__ == "__main__":
    print("开始处理日志文件...")
    csv_file = process_all_logs()
    generate_detailed_analysis()
    print("所有处理完成！") 
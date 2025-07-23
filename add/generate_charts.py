#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
from matplotlib import rcParams

# 设置中文字体
rcParams['font.sans-serif'] = ['SimHei', 'DejaVu Sans']
rcParams['axes.unicode_minus'] = False

def load_data():
    """加载CSV数据"""
    df = pd.read_csv('module_test_results/processed_performance_summary.csv')
    return df

def create_performance_comparison_chart(df):
    """创建性能对比图表"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
    
    # 整机执行时间对比
    configs = df['配置']
    times = df['整机执行时间(ms)']
    fps = [1000/t for t in times]
    
    bars1 = ax1.bar(configs, times, color=['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4'])
    ax1.set_title('整机执行时间对比', fontsize=14, fontweight='bold')
    ax1.set_ylabel('执行时间 (ms)')
    ax1.tick_params(axis='x', rotation=45)
    
    # 在柱状图上添加数值标签
    for bar, time in zip(bars1, times):
        height = bar.get_height()
        ax1.text(bar.get_x() + bar.get_width()/2., height + 1000,
                f'{time:,.0f}ms', ha='center', va='bottom', fontsize=10)
    
    # 帧率对比
    bars2 = ax2.bar(configs, fps, color=['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4'])
    ax2.set_title('理论帧率对比', fontsize=14, fontweight='bold')
    ax2.set_ylabel('帧率 (FPS)')
    ax2.tick_params(axis='x', rotation=45)
    
    # 在柱状图上添加数值标签
    for bar, fps_val in zip(bars2, fps):
        height = bar.get_height()
        ax2.text(bar.get_x() + bar.get_width()/2., height + 0.1,
                f'{fps_val:.2f}FPS', ha='center', va='bottom', fontsize=10)
    
    plt.tight_layout()
    plt.savefig('module_test_results/performance_comparison.png', dpi=300, bbox_inches='tight')
    plt.show()

def create_module_breakdown_chart(df):
    """创建模块时间分解图表"""
    fig, axes = plt.subplots(2, 2, figsize=(16, 12))
    axes = axes.flatten()
    
    modules = ['去噪时间(ms)', '边缘检测时间(ms)', '掩码时间(ms)', 'Hough时间(ms)', 
               '线分离时间(ms)', '回归时间(ms)', '预测时间(ms)', '绘制时间(ms)']
    module_names = ['图像去噪', '边缘检测', '掩码处理', 'Hough变换', 
                   '线分离', '回归拟合', '转向预测', '结果绘制']
    
    colors = ['#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7', '#DDA0DD', '#98D8C8', '#F7DC6F']
    
    for i, config in enumerate(df['配置']):
        row = df[df['配置'] == config].iloc[0]
        times = [row[module] for module in modules]
        
        # 过滤掉时间太小的模块（小于1ms）
        significant_modules = []
        significant_times = []
        significant_colors = []
        
        for j, (name, time, color) in enumerate(zip(module_names, times, colors)):
            if time > 1.0:  # 只显示大于1ms的模块
                significant_modules.append(name)
                significant_times.append(time)
                significant_colors.append(color)
        
        if significant_times:
            wedges, texts, autotexts = axes[i].pie(significant_times, labels=significant_modules, 
                                                  colors=significant_colors, autopct='%1.1f%%',
                                                  startangle=90)
            axes[i].set_title(f'{config}\n模块时间分解', fontsize=12, fontweight='bold')
            
            # 设置文本颜色
            for autotext in autotexts:
                autotext.set_color('white')
                autotext.set_fontweight('bold')
    
    plt.tight_layout()
    plt.savefig('module_test_results/module_breakdown.png', dpi=300, bbox_inches='tight')
    plt.show()

def create_optimization_impact_chart(df):
    """创建优化效果对比图表"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
    
    # 多核vs单核效果
    single_core_time = df[df['配置'] == '单核']['整机执行时间(ms)'].iloc[0]
    multi_core_time = df[df['配置'] == '多核']['整机执行时间(ms)'].iloc[0]
    multi_core_neon_time = df[df['配置'] == '多核+NEON']['整机执行时间(ms)'].iloc[0]
    
    labels = ['单核', '多核', '多核+NEON']
    times = [single_core_time, multi_core_time, multi_core_neon_time]
    colors = ['#FF6B6B', '#4ECDC4', '#45B7D1']
    
    bars1 = ax1.bar(labels, times, color=colors)
    ax1.set_title('多核并行化效果', fontsize=14, fontweight='bold')
    ax1.set_ylabel('执行时间 (ms)')
    
    # 添加性能提升标签
    for i, (bar, time) in enumerate(zip(bars1, times)):
        height = bar.get_height()
        if i > 0:
            improvement = ((single_core_time - time) / single_core_time) * 100
            ax1.text(bar.get_x() + bar.get_width()/2., height + 5000,
                    f'提升{improvement:.1f}%', ha='center', va='bottom', fontsize=10, fontweight='bold')
    
    # NEON优化效果
    single_core_time = df[df['配置'] == '单核']['整机执行时间(ms)'].iloc[0]
    single_core_neon_time = df[df['配置'] == '单核+NEON']['整机执行时间(ms)'].iloc[0]
    multi_core_time = df[df['配置'] == '多核']['整机执行时间(ms)'].iloc[0]
    multi_core_neon_time = df[df['配置'] == '多核+NEON']['整机执行时间(ms)'].iloc[0]
    
    x = np.arange(2)
    width = 0.35
    
    bars1 = ax2.bar(x - width/2, [single_core_time, multi_core_time], width, 
                    label='无NEON', color=['#FF6B6B', '#4ECDC4'])
    bars2 = ax2.bar(x + width/2, [single_core_neon_time, multi_core_neon_time], width, 
                    label='有NEON', color=['#FF8E8E', '#6EDDD5'])
    
    ax2.set_title('NEON优化效果对比', fontsize=14, fontweight='bold')
    ax2.set_ylabel('执行时间 (ms)')
    ax2.set_xticks(x)
    ax2.set_xticklabels(['单核', '多核'])
    ax2.legend()
    
    # 添加NEON优化百分比
    neon_improvement_single = ((single_core_time - single_core_neon_time) / single_core_time) * 100
    neon_improvement_multi = ((multi_core_time - multi_core_neon_time) / multi_core_time) * 100
    
    ax2.text(-0.2, single_core_neon_time + 2000, f'+{neon_improvement_single:.1f}%', 
             ha='center', va='bottom', fontsize=10, fontweight='bold')
    ax2.text(0.8, multi_core_neon_time + 2000, f'+{neon_improvement_multi:.1f}%', 
             ha='center', va='bottom', fontsize=10, fontweight='bold')
    
    plt.tight_layout()
    plt.savefig('module_test_results/optimization_impact.png', dpi=300, bbox_inches='tight')
    plt.show()

def create_bottleneck_analysis_chart(df):
    """创建瓶颈分析图表"""
    fig, ax = plt.subplots(figsize=(12, 8))
    
    # 准备数据
    configs = df['配置']
    hough_times = df['Hough时间(ms)']
    plot_times = df['绘制时间(ms)']
    denoise_times = df['去噪时间(ms)']
    edge_times = df['边缘检测时间(ms)']
    
    x = np.arange(len(configs))
    width = 0.2
    
    bars1 = ax.bar(x - 1.5*width, hough_times, width, label='Hough变换', color='#FF6B6B')
    bars2 = ax.bar(x - 0.5*width, plot_times, width, label='结果绘制', color='#4ECDC4')
    bars3 = ax.bar(x + 0.5*width, denoise_times, width, label='图像去噪', color='#45B7D1')
    bars4 = ax.bar(x + 1.5*width, edge_times, width, label='边缘检测', color='#96CEB4')
    
    ax.set_title('各配置主要模块执行时间对比', fontsize=14, fontweight='bold')
    ax.set_ylabel('执行时间 (ms)')
    ax.set_xticks(x)
    ax.set_xticklabels(configs, rotation=45)
    ax.legend()
    
    # 添加数值标签
    for bars in [bars1, bars2, bars3, bars4]:
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.text(bar.get_x() + bar.get_width()/2., height + 0.5,
                       f'{height:.1f}', ha='center', va='bottom', fontsize=8)
    
    plt.tight_layout()
    plt.savefig('module_test_results/bottleneck_analysis.png', dpi=300, bbox_inches='tight')
    plt.show()

def main():
    """主函数"""
    print("开始生成性能分析图表...")
    
    # 加载数据
    df = load_data()
    print("数据加载完成")
    
    # 生成各种图表
    print("生成性能对比图表...")
    create_performance_comparison_chart(df)
    
    print("生成模块分解图表...")
    create_module_breakdown_chart(df)
    
    print("生成优化效果图表...")
    create_optimization_impact_chart(df)
    
    print("生成瓶颈分析图表...")
    create_bottleneck_analysis_chart(df)
    
    print("所有图表生成完成！")
    print("图表文件保存在 module_test_results/ 目录下：")
    print("- performance_comparison.png")
    print("- module_breakdown.png") 
    print("- optimization_impact.png")
    print("- bottleneck_analysis.png")

if __name__ == "__main__":
    main() 
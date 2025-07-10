import os
import subprocess
import time

# 创建输出目录
output_dir = "images"
os.makedirs(output_dir, exist_ok=True)

# 获取videos目录下所有MP4文件
video_dir = "videos"
video_files = [f for f in os.listdir(video_dir) if f.endswith(".mp4")]

if not video_files:
    print(f"在 {video_dir} 目录中未找到MP4文件")
    exit()

print(f"找到 {len(video_files)} 个MP4文件，开始处理...")

# 处理每个视频文件
for video_file in video_files:
    video_path = os.path.join(video_dir, video_file)
    video_name = os.path.splitext(video_file)[0]
    
    # 设置输出路径
    output_pattern = os.path.join(output_dir, f"{video_name}_%04d.jpg")
    
    start_time = time.time()
    
    # 构建FFmpeg命令
    cmd = [
        'ffmpeg',
        '-i', video_path,          # 输入文件
        '-vf', 'fps=1',            # 每秒提取1帧
        '-q:v', '2',               # 图像质量（2-31，值越小质量越高）
        '-loglevel', 'error',      # 只显示错误信息
        '-y',                      # 覆盖已存在文件
        output_pattern             # 输出模式
    ]
    
    print(f"处理视频: {video_file}")
    print("执行命令: " + " ".join(cmd))
    
    try:
        # 执行FFmpeg命令
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        
        # 统计生成的文件数量
        generated_files = len([f for f in os.listdir(output_dir) if f.startswith(video_name)])
        elapsed = time.time() - start_time
        
        print(f"处理完成: 生成 {generated_files} 张图片")
        print(f"耗时: {elapsed:.2f}秒")
    
    except subprocess.CalledProcessError as e:
        print(f"FFmpeg处理失败: {e.stderr}")
    except Exception as e:
        print(f"发生错误: {str(e)}")

print("\n所有视频处理完毕!")

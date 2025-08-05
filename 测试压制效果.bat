@echo off
chcp 65001 >nul

:: 请将该脚本和待测视频置于相同文件夹目录下。这样脚本可以直接识别同目录下的文件，可以免去填写视频文件的路径，只填视频名字就行。     
:: 懒得写“识别并使用与脚本同目录的FFmpeg.exe”了，咱统一用环境变量的FFmpeg，好吧兄弟。      

set "被测视频=2.mkv"
set "源视频=1.mkv"

set "跳采一半ON或不ON=on"

:: 跳采一半指：测2、4、6、8、10、12.......直到最后的偶数帧，即1、3、5、7、9......奇数帧不测，减少了一半需要测的帧数，将测试时间缩短一半。VMAF得分通常会比全程测试高0.1~0.5分。

:: ===============================以下没有需要自定义的参数了，可以不看=====================================================================================================


setlocal enabledelayedexpansion

if "!跳采一半ON或不ON!"=="on" ( set "jump1=[0:v]select='not(mod(n,2))'[0v]; [1:v]select='not(mod(n,2))'[1v]; [0v][1v]" 
set "jump2=select='not(mod(n,2))',"
) else ( 
set "jump1=[0:v][1:v]" 
set "jump2=" )


:: 获取CPU线程数        
for /f %%p in ('powershell -noprofile -c "[System.Environment]::ProcessorCount"') do ( set /a CPU_threads=%%p - 1 )


:: [获取视频时长、帧率等用于后续计算的信息]
for /f "tokens=*" %%a in (' cmd /c " ffmpeg -i "!源视频!" " 2^>^&1 ^| findstr /r "fps" ^| powershell -command "$input -split ',' | Select-String 'fps'"') do ( 
        set "fps_value=%%a" & set "fps_value=!fps_value:fps=!" & set "fps_value=!fps_value: =!" )
)

:: [“ffmpeg -i”命令显示的内容里，帧率最多显示到两位小数，会把常见的23.976帧约为23.98帧，为了计算更加准确，将检测获取到的帧率的值里是否有23.98，有就改为23.976]
echo [!fps_value!] | findstr /i "23.98" >nul && set "fps_value=23.976"


:: 自动设置VMAF模型类别。检查视频分辨率是否大于等于3840*2160，4K视频将使用4K的VMAF模型（vmaf_4k_v0.6.1.json），不是4k视频则使用1080p的VMAF模型（vmaf_v0.6.1.json）。有部分长比例的4k视频不是3840*2160，可能是3840*1500~1700，因此放低对高度的判定标准为1400。
for /f "tokens=*" %%y in (' cmd /c " ffmpeg -i "!源视频!" " 2^>^&1 ^| findstr /r "fps" ^| powershell -Command  ^
    " $All_matches = [regex]::Matches($input, '(\d{2,})x(\d{2,})'); foreach ($match in $All_matches) { $left = [int]$match.Groups[1].Value; $right = [int]$match.Groups[2].Value; if ( ($left -ge 3840 -and $right -ge 1400) -or ($left -ge 1400 -and $right -ge 3840) ) { Write-Output 'vmaf_4k_v0.6.1' } else { Write-Output 'vmaf_v0.6.1'} }"  
    ') do ( set vmaf_model=%%y ) 
if not defined vmaf_model ( set "vmaf_model=vmaf_v0.6.1" )


ffmpeg -hide_banner -nostdin  -r !fps_value! -i !被测视频! -r !fps_value! -i !源视频! -filter_complex "[0:v]!jump2!settb=AVTB,setpts=PTS-STARTPTS[main];[1:v]!jump2!settb=AVTB,setpts=PTS-STARTPTS[ref];[main][ref]libvmaf=model=version=!vmaf_model!:log_path='vmaf_log.txt':n_threads=!CPU_threads!:eof_action=endall"  -f null -

echo. & echo 总结： & echo. 

for /f "tokens=6" %%a in (' findstr /c:"metric name=""vmaf""" "vmaf_log.txt" ') do (  echo VMAF平均分：%%a & echo. )

echo 被测视频时间基：
ffprobe -v error -select_streams v:0 -show_entries stream=time_base -of default=noprint_wrappers=1:nokey=0 "!被测视频!"
echo. 
echo 源视频时间基：
ffprobe -v error -select_streams v:0 -show_entries stream=time_base -of default=noprint_wrappers=1:nokey=0 "!源视频!"
echo. 
pause
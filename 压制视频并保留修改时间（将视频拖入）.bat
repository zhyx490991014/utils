@echo off
chcp 65001 >nul
mode con: cols=220 lines=50
:: ↑设置CMD命令窗口大小，cols是横长，lines是纵长↑    
:: 开始压缩后，如果进度条无法单行刷新，请加大cmd窗口长度。    
:: win11下的cmd窗口被集合到“终端”里了，这行参数不起效，请右键终端标签页——设置——启动大小，在相关位置修改窗口的长宽。   

:: =========  [设置视频编码参数, 只需设置中间参数，不用填写文件路径]      
set "video_compression=  -c:v libx264 -preset fast -crf 24  -c:a aac -b:a 320k "


:: ========= [设置输出路径]  
set "input_folder=%~dp1"
set "output_folder=%input_folder%"

:: [此处已设置输出文件夹等于输入文件夹，即输出到源文件夹【%input_folder%】，如需自定义输出路径，可修改第二行代码，示例【set "output_folder=D:\CRF24输出"】 ]


:: ========= [设置拓展名，如留空则保留源文件拓展名，示例 【set "ext="】 或【set "ext=mp4"】]   

set "ext1="


:: ================== 以下是编码器的分类和使用建议，每人习惯不同，不一定按照以下参数。

:: cpu：
:: -c:v libx264 -preset medium -crf 24 
:: -c:v libx265 -preset medium -crf 24 
:: -c:v libsvtav1 -preset 9 -crf 34 

:: intel qsv加速：
:: -c:v hevc_qsv -preset medium -global_quality 24 

:: N卡 nvenc加速：
:: -c:v hevc_nvenc -preset p4 -cq 32 
:: -c:v av1_nvenc -preset p4 -cq 36     

:: A卡 AMF加速：
:: -c:v hevc_amf -preset balanced -qp_i 28 -qp_p 28 


:: ================== 以上是需要自行设置的全部部分，可以直接使用脚本了，下面的部分可以不看





if not "%output_folder:~-1%"=="\" (
    set "output_folder=%output_folder%\"
)

:: [ffmpeg路径，从脚本当前目录或环境变量中寻找ffmpeg.exe，优先寻找脚本当前目录。如果哪里都找不到ffmpeg.exe则报错退出脚本。只需要ffmpeg.exe本体，一个文件即可，不需要一整个文件夹。]
set "ffmpeg=%~dp0ffmpeg.exe"
if not exist "%ffmpeg%" ( for /f "delims=" %%a in (' "where ffmpeg.exe" ') do ( set ffmpeg=%%a ) )
if not exist "%ffmpeg%" ( powershell -Command "Write-Host -ForegroundColor Red "喔哟，出错啦！未找到ffmpeg.exe。请在当前脚本同级目录放置ffmpeg.exe，只需要ffmpeg.exe本体，一个exe文件即可，不需要解压出来的整个ffmpeg文件夹。或者正确配置ffmpeg的环境变量的路径，也有可能需要重启电脑应用一下环境变量的变动" " & echo. 
echo "这样吧，进入https://www.gyan.dev/ffmpeg/builds/，再点击下载ffmpeg-git-full.7z（git版本可理解为抢先版，full意思是完全体），解压后逐个点开，在“bin”的文件夹下面就是ffmpeg.exe，直接复制到本批处理脚本所在的文件夹里，" & echo.
echo "如果想要设置环境变量，则win+i（打开windows设置），在搜索栏搜索“环境变量”，点击“编辑系统环境变量”，再点“环境变量”，在下方的“系统变量”里点击“Path”，再点“编辑”，点“新建”，把刚才解压的ffmpeg.exe的文件路径粘贴过来，比如 D:\ffmpeg\bin，粘贴到“bin”的目录就行了，不用粘贴成“D:\ffmpeg\bin\ffmpeg.exe”，再点击确定，完事了。设置完毕后如果发现没有变化，可能需要重启电脑。" & echo. & pause & goto :EOF )



:: [计算拖入文件的个数，这个变量删了也不影响压缩，只是为了方便知道拖入了多少文件。比如 “共有5个文件，这是第2个文件”]
:: [此处原本的代码也是很简单的：“for %%a in (%*) do ( set /a count+=1 )”， 但为了避免文件名里有英文括号导致出错的问题，改为了下方的四行代码。]
set all=%*
setlocal enabledelayedexpansion

for %%a in ( !all! ) do ( set /a count+=1 )

setlocal disabledelayedexpansion




:process_files

:: [循环开始的地方。如果仍有视频要处理则继续进行，如果没有，则结束脚本。 ]
if "%~1"=="" ( goto :eof )

:: [保留和源文件相同的文件名和拓展名]
set "input_file=%~1" 
set "filename=%~n1" 

setlocal enabledelayedexpansion


:: [拓展名处理]  
set "ext=!ext1!"
if defined ext ( set "ext=!ext: =!" ) 
if not defined ext ( set "ext=%~x1" ) else ( set "ext=.!ext!" )


:: [设置输出文件为：自定义的输出文件夹路径+源文件名+拓展名]
set "output_file=!output_folder!!filename!!ext!"

:: [如文件名里有“&”符号，将其转义，以便后续使用]
set "input_file1=!input_file:&=^&!"
set "filename1=!filename:&=^&!"
set "output_file1=!output_file:&=^&!"
set "ffmpeg1=!ffmpeg:&=^&!"


set /a file+=1
echo.
echo [-----]  共有%count%个文件，这是第!file!个文件： !filename!!ext!
echo.
echo 开始处理......
echo.


:check_file
:: [检查是否存在同名输出文件，如果存在，则序号加1]
if exist "!output_file!" ( set /a "jk+=1" & set "output_file=!output_folder!!filename!~!jk!!ext!" & goto :check_file)



:: [获取视频时长、帧率等用于后续计算的信息]
for /f "tokens=*" %%y in (' cmd /c " "!ffmpeg1!" -i "!input_file1!" " 2^>^&1 ^| findstr /r "Duration fps"') do ( 
    for /f "tokens=*" %%a in ('echo %%y ^| findstr /r "Duration" ^| powershell -command "$input -split ',' | Select-String 'Duration' "')  do ( 
        set "Duration=%%a" & set "Duration=!Duration:Duration: =!"
        for /f %%k in ('powershell -command "[TimeSpan]::Parse('!Duration!').TotalSeconds "') do ( set "totalSeconds=%%k" ) )
    for /f "tokens=*" %%a in ('echo %%y ^| findstr /r "fps" ^| powershell -command "$input -split ',' | Select-String 'fps'"') do ( 
        set "fps_value=%%a" & set "fps_value=!fps_value:fps=!" & set "fps_value=!fps_value: =!" )
)

echo [!fps_value!] | findstr /i "23.98" >nul && set "fps_value=23.976"

for /f %%a in ('powershell -command "(!totalSeconds! * !fps_value!).ToString('F0')"') do ( set "All_frames=%%a" )

:: 获取源文件体积（以MB为单位）
for %%A in ("!input_file!") do (
for /f "usebackq" %%B in (`powershell -NoProfile -Command "Write-Output ([math]::Round((%%~zA / 1048576), 2))"`) do ( set "origin_size_mb=%%B" )
)
  

:: [———————————————— 以下是最重要的部分，正式开始处理视频。包括：启动ffmpeg压缩命令并将进度信息输出到powershell命令中计算、不断计算数值并显示更新我们自定义的新的进度信息栏、压缩完成之后赋予源文件的日期属性、准备处理下一个视频文件。]

:: [正式开始ffmpeg压缩视频，其中有关压缩参数的变量 video_compression 已经在开头设置过了]
:: [进度信息栏循环更新。如果这里的进度显示99.99%，但视频实际上已经处理完成了，视频文件已经压出来了，那便可以忽略，只是显示问题]
"!ffmpeg!" -i "!input_file!" !video_compression! -y "!output_file!" -progress pipe:1 -nostats  | powershell -Command ^
"Start-Sleep -Milliseconds 500; ^
while ($true) {  $line = [Console]::In.ReadLine(); ^
if ($null -eq $line) { break } ^
if ($line -match 'frame=(\d+)') { $frame = $matches[1] } ^
if ($line -match 'fps=(\d+\.?\d*)') { $fps = $matches[1] } ^
if ($line -match 'total_size=(\d+)') { $total_size = $matches[1] } ^
if ($line -match 'out_time=(\d+:\d+:\d+\.\d+)') { $out_time = $matches[1] } ^
if ($line -match 'bitrate=\s*(\d+\.?\d*)kbits/s') { $bitrate = $matches[1] } ^
if ($line -match 'speed=(\d+\.?\d*)x') { $speed = $matches[1] } ^
if ($frame -and $fps -and $total_size -and $out_time -and $bitrate -and $speed) { ^
$processbar = [math]::Round(([double]$frame / [double]$env:All_frames * 100),2); ^
if ( $fps -gt 1 ) { $time_left = (New-TimeSpan -Seconds (([double]$env:All_frames - [double]$frame) / [double]$fps)).ToString('c') } else { $time_left = "'∞'" }; ^
$final_size = [math]::Round((([double]$total_size * 100) / ([double]$processbar * 1024 * 1024)), 2); ^
$size_percentage = [math]::Round(($final_size / !origin_size_mb!) * 100); ^
$final_size = if ($final_size -gt 1024) { ($final_size / 1024).ToString('F2') + 'GB' } else { ($final_size).ToString('F2') + 'MB' }; ^
$out_time = $out_time.Substring(0, 8); $Duration = $env:Duration.Substring(0, 8) } ^
Write-Host -NoNewline -ForegroundColor Green \"`r[---] 进度:$processbar%%    剩余处理时间:$time_left    预估最终体积/预估为源视频的百分之几:$final_size $size_percentage%%    处理速率:($speed x / $fps fps)    码率:$bitrate kbps    视频时长:$out_time/$env:Duration    帧数:$frame/$env:All_frames \" ^
} "
 
 
:: [保留源文件的创建、修改、访问时间。注意，这里的日期属性是windows的文件特性，而不是视频的“时间戳”或者视频元数据内嵌的“日期信息”，这跟windows的文件“日期”是截然不同的，这便是为何在一些软件里选择类似“保留时间戳”、“不删除元数据”这样的选项时，会发现依然保不住源文件日期，因为就不是一回事。]
powershell -command ^
"(Get-Item -LiteralPath \"!output_file!\").CreationTime = (Get-Item -LiteralPath \"!input_file!\").CreationTime; ^
(Get-Item -LiteralPath \"!output_file!\").LastWriteTime = (Get-Item -LiteralPath \"!input_file!\").LastWriteTime; ^
(Get-Item -LiteralPath \"!output_file!\").LastAccessTime = (Get-Item -LiteralPath \"!input_file!\").LastAccessTime" 

:: 如果希望脚本暂停查看红字报错讯息，而不是一闪消失，请直接在下一行加“pause”，意为暂停。可以在任意空行加暂停，加哪儿就暂停哪儿。  

:: [回到开始的地方，处理下一个文件]
shift
goto :process_files

:EOF
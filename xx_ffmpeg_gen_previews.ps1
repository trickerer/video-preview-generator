########################
#
# Recursive traversal video preview generator for .mp4 and .webm files
# previews are created in hardcoded 'preview' folder created in every folder containing videos
#
# REQUIREMENTS:
# 3rd party apps:
#  ffmpeg
#  ffprobe
# constants:
#  $MYWORKDIR_DWNLD <- .config.ps1 (full path to default target directory)
#  $RUN_FFPROBE     <- .config.ps1 (full path to ffprobe.exe)
#  $RUN_FFMPEG      <- .config.ps1 (full path to ffmpeg.exe)
#  $TimeFormat      <- .config.ps1 (valid time format string, ex. "HH:mm:ss")
#

. "config.ps1"

#imports
$MYWORKDIR = $MYWORKDIR_DWNLD
$MYFFPROBE = $RUN_FFPROBE
$MYFFMPEG = $RUN_FFMPEG

#consts
$PREVIEW_W_MIN = 640
$PREVIEW_W_MAX = 1920
$TILE_W_MIN = 3
$TILE_W_MAX = 5
$TILE_H_MIN = 2
$TILE_H_MAX = 4
$SEEK_MODE_AUTO = 0
$SEEK_MODE_FULL = 1
$SEEK_MODE_FAST = 2
$SEEK_MODE_NAMES = @{
    $SEEK_MODE_AUTO.ToString()='auto'
    $SEEK_MODE_FULL.ToString()='full'
    $SEEK_MODE_FAST.ToString()='seek'
}

$FPI_DEFAULT = 45
$PREVIEW_EXT = '.jpg'
$PAT0 = '^[01][0-9]{3}$'
$PAT1 = '^[0-9]{1,2}[a-z]{1,4}$'

$DRAWTEXT_ALPHA = '0.65'
$BGCOLOR = '0x222222A0'
$DT_FONT = '''C\:/Windows/Fonts/l_10646.ttf''' #Lucida Sans Unicode

$WIDTH_DEFAULT = $PREVIEW_W_MAX
$TILE_W_DEFAULT = $TILE_W_MAX
$TILE_H_DEFAULT = $TILE_H_MAX

#functions
function get_ffmpeg_params_q{ Param ([IO.FileInfo]$basefile, [String]$dest_filename, [String]$frames, [Double]$secs, [Boolean]$horizontal,
                                     [String]$filesize, [String]$duration, [String]$bitrate, [String]$resolution, [String]$adv, $sadv)

    $fwidth = if ($horizontal -eq $true) {[Math]::Ceiling($preview_w / $tilew)} else {[Math]::Ceiling(($preview_w / $tilew) / 2)}
    $fdims = if ($horizontal -eq $true) {"$tilew`x$tileh"} else {"$($tilew * 2)x$([Math]::Floor($tileh / 2))"}
    $fsiz = "File Size\: $filesize"                        #File Size\: 5.5 MB (5 444 441 bytes)
    $fdur = "Duration\: $($duration -replace ':', '\:')"   #Duration\: 00\:00\:00
    $fbrt = "Bitrate\: $bitrate"                           #Bitrate\: 8962 kb/s
    $fres = "Resolution\: $resolution`@$fps_str fps"       #Resolution\: 1280x960

    $dtfsize1 = [Math]::Max([Int]($(if ($horizontal -eq $true) {$fwidth} else {$fwidth * 2})) / 20, 10)
    $dtfsize2 = [Math]::Max([Math]::Floor($preview_w / 100), 10)
    $padsize = [Math]::Floor($dtfsize2 * 6)

    $dtpadsize = $dtfsize2  # up and down
    $ty1 = $dtpadsize
    $ty2 = $ty1 + $dtpadsize + 1
    $ty3 = $ty2 + $dtpadsize + 1
    $ty4 = $ty3 + $dtpadsize + 1
    $tx = [Math]::Floor($dtfsize2 * 0.75)

    $fil=#"select='eq(n\,0)'," +
         "scale=w=$fwidth`:h=-1," +
         "drawtext=fontsize=$dtfsize1`:fontfile=$DT_FONT`:x=0:y=h-lh-lh/2:fontcolor=white:text='%{pts\:hms\}'" +
         ":alpha=$DRAWTEXT_ALPHA`:borderw=2:bordercolor=0x000000A0"
    $fils = ""
    for ($i = 0; $i -lt $tilew * $tileh; ++$i) {
        $fils += "[${i}:v]${fil}[v${i}];"
    }
    for ($i = 0; $i -lt $tilew * $tileh; ++$i) {
        $fils += "[v${i}]"
    }
    $fils += "concat=n=$($tilew * $tileh)`:v=1:a=0[o1];[o1]tile=$fdims`:padding=2:margin=1:color=$BGCOLOR," +
             "pad=h=ih+$padsize`:w=iw+$($fwidth -band 1)`:y=oh-ih:color=$BGCOLOR`:eval=init,scale=w=$preview_w`:h=-1," +
             "drawtext=fontsize=$dtfsize2`:fontfile=$DT_FONT`:x=$tx`:y=$ty1`:fontcolor=white:text='$fsiz'," +
             "drawtext=fontsize=$dtfsize2`:fontfile=$DT_FONT`:x=$tx`:y=$ty2`:fontcolor=white:text='$fres'," +
             "drawtext=fontsize=$dtfsize2`:fontfile=$DT_FONT`:x=$tx`:y=$ty3`:fontcolor=white:text='$fbrt'," +
             "drawtext=fontsize=$dtfsize2`:fontfile=$DT_FONT`:x=$tx`:y=$ty4`:fontcolor=white:text='$fdur'"

    $Params = New-Object Collections.ArrayList
    $Params.Add('-hide_banner') > $null
    $Params.Add('-y') > $null
    $Params.Add('-loglevel') > $null
    $Params.Add('error') > $null
    $Params.Add('-noautorotate') > $null
    if ($threads -ne 0)
    {
        $Params.Add('-threads') > $null
        $Params.Add($threads) > $null
    }
    for ($i = 0; $i -lt $tilew * $tileh; ++$i) {
        $Params.Add('-ss') > $null
        $Params.Add($i * $secs + $sadv) > $null
        $Params.Add('-t') > $null
        $Params.Add('0.001') > $null
        $Params.Add('-i') > $null
        $Params.Add(($basefile.FullName -replace '\\', '/')) > $null
    }
    $Params.Add('-copyts') > $null
    $Params.Add('-an') > $null
    $Params.Add('-filter_complex') > $null
    $Params.Add($fils) > $null
    $Params.Add('-frames:v') > $null
    $Params.Add('1') > $null
    $Params.Add('-q:v') > $null
    $Params.Add('5') > $null
    $Params.Add($dest_filename) > $null
    return $Params
}

function get_ffmpeg_params{ Param ([IO.FileInfo]$basefile, [String]$dest_filename, [String]$frames, [Double]$secs, [Boolean]$horizontal,
                                   [String]$filesize, [String]$duration, [String]$bitrate, [String]$resolution, [String]$adv, $sadv)

    $fwidth = if ($horizontal -eq $true) {[Math]::Ceiling($preview_w / $tilew)} else {[Math]::Ceiling(($preview_w / $tilew) / 2)}
    $fdims = if ($horizontal -eq $true) {"$tilew`x$tileh"} else {"$($tilew * 2)x$([Math]::Floor($tileh / 2))"}
    $fsiz = "File Size\: $filesize"                        #File Size\: 5.5 MB (5 444 441 bytes)
    $fdur = "Duration\: $($duration -replace ':', '\:')"   #Duration\: 00\:00\:00
    $fbrt = "Bitrate\: $bitrate"                           #Bitrate\: 8962 kb/s
    $fres = "Resolution\: $resolution`@$fps_str fps"       #Resolution\: 1280x960

    $dtfsize1 = [Math]::Max([Int]($(if ($horizontal -eq $true) {$fwidth} else {$fwidth * 2})) / 20, 10)
    $dtfsize2 = [Math]::Max([Math]::Floor($preview_w / 100), 10)
    $padsize = [Math]::Floor($dtfsize2 * 6)

    $dtpadsize = $dtfsize2  # up and down
    $ty1 = $dtpadsize
    $ty2 = $ty1 + $dtpadsize + 1
    $ty3 = $ty2 + $dtpadsize + 1
    $ty4 = $ty3 + $dtpadsize + 1
    $tx = [Math]::Floor($dtfsize2 * 0.75)

    $Params = New-Object Collections.ArrayList
    $Params.Add('-hide_banner') > $null
    $Params.Add('-y') > $null
    $Params.Add('-loglevel') > $null
    $Params.Add('error') > $null
    $Params.Add('-noautorotate') > $null
    if ($threads -ne 0)
    {
        $Params.Add('-threads') > $null
        $Params.Add($threads) > $null
    }
    $Params.Add('-i') > $null
    $Params.Add(($basefile.FullName -replace '\\', '/')) > $null
    $Params.Add('-an') > $null
    $Params.Add('-frames:v') > $null
    $Params.Add('1') > $null
    $Params.Add('-q:v') > $null
    $Params.Add('5') > $null
    $Params.Add('-vsync') > $null
    $Params.Add('0') > $null
    $Params.Add('-flags') > $null
    $Params.Add('+bitexact') > $null
    $Params.Add('-vf') > $null
    $Params.Add(
        "select='not(mod(n-$adv\,$frames))'," +
        "scale=w=$fwidth`:h=-1," +
        "drawtext=fontsize=$dtfsize1`:fontfile=$DT_FONT`:x=0:y=h-lh-lh/2:fontcolor=white:text='%{pts\:hms\}'" +
         ":alpha=$DRAWTEXT_ALPHA`:borderw=2:bordercolor=0x000000A0," +
        "tile=$fdims`:padding=2:margin=1:color=$BGCOLOR," +
        "pad=h=ih+$padsize`:w=iw+$($fwidth -band 1)`:y=oh-ih:color=$BGCOLOR`:eval=init," +
        "scale=w=$preview_w`:h=-1," +
        "drawtext=fontsize=$dtfsize2`:fontfile=$DT_FONT`:x=$tx`:y=$ty1`:fontcolor=white:text='$fsiz'," +
        "drawtext=fontsize=$dtfsize2`:fontfile=$DT_FONT`:x=$tx`:y=$ty2`:fontcolor=white:text='$fres'," +
        "drawtext=fontsize=$dtfsize2`:fontfile=$DT_FONT`:x=$tx`:y=$ty3`:fontcolor=white:text='$fbrt'," +
        "drawtext=fontsize=$dtfsize2`:fontfile=$DT_FONT`:x=$tx`:y=$ty4`:fontcolor=white:text='$fdur'"
    ) > $null
    $Params.Add($dest_filename) > $null
    return $Params
}

function process_file{ Param ([IO.FileInfo]$file, [String]$destdir)
    $ext = $file.Extension
    $size = $file.Length
    $filesize = "$([Math]::Round($size / 1mb, 2)) MB ($($size.ToString("N0")) bytes)"
    if ($ext -imatch '^\.(?:avi|mp4|webm|wmv)$')
    {
        $file_name_short = ($file.BaseName -replace '^(?<fname>(?:.._)?(?=[0-9]+)[^_]+)_.+?$', '${fname}') + $ext
        $src_short = $file.FullName.Substring($file.FullName.IndexOf($path_info.Name)) -replace '\\', '/'
        $src_short = $src_short.Remove($src_short.LastIndexOf('/') + 1) + $file_name_short
        $dest_file_name = $destdir + $file.BaseName + $PREVIEW_EXT
        if ([IO.File]::Exists($dest_file_name) -eq $true)
        {
            if ($report_existing -eq $true)
            { write("Preview for '$src_short' already exists! Skipped...") }
            return
        }
        #1. execute ffprobe and get:
        # 1) number of frames
        # 2) video dimensions
        # 3) video duration
        # 4) video bitrate
        $ffp_params = New-Object Collections.ArrayList
        $ffp_params.Add('-hide_banner') > $null
        #$ffp_params.Add('-loglevel') > $null
        #$ffp_params.Add('info') > $null
        $ffp_params.Add('-show_streams') > $null
        $ffp_params.Add('-select_streams') > $null
        $ffp_params.Add('v:0') > $null
        if ($ext -imatch '^\.(?:webm|wmv)$')
        { $ffp_params.Add('-count_packets') > $null }
        $ffp_params.Add('-i') > $null
        $ffp_params.Add($file.FullName) > $null
        $output = ((&"$MYFFPROBE" ($ffp_params)) 2>&1) #we have to get all output to parse duration
        $nb_frames_str = ($output -match '^nb_frames=.+$')[0].Split('=')[1]
        $nb_packets_str = ($output -match '^nb_read_packets=.+$')[0].Split('=')[1]
        $w_str = ($output -match '^width=.+$')[0].Split('=')[1]
        $h_str = ($output -match '^height=.+$')[0].Split('=')[1]
        $cw_str = ($output -match '^coded_width=.+$')[0].Split('=')[1]
        $ch_str = ($output -match '^coded_height=.+$')[0].Split('=')[1]
        $durbr_str = $null
        $i = $output.Length-1;
        do {
            $durbr_str = ($output[$i--].ToString().Split("`n") -match '^  Duration: .+$')[0]
        } while ($durbr_str -eq $null -and $i -ge 0)
        $stream_str = $null
        $i = $output.Length-1;
        do {
            $stream_str = ($output[$i--].ToString().Split("`n") -match '^.*[0-9.]+ (?:fps|tbr).*$')[0]
        } while ($stream_str -eq $null -and $i -ge 0)
        $dur_str = $durbr_str.Substring([String]('  Duration: ').Length, [String]('00:00:00.00').Length - 3)
        $dur_secs = (New-TimeSpan -Start '01-01-1970' -End $([DateTime]::Parse("01-01-1970 $dur_str"))).TotalSeconds
        $br_str = $durbr_str.Substring($durbr_str.IndexOf('bitrate: ') + [String]('bitrate: ').Length)
        $fps_str =($stream_str | Select-String '([0-9.]+) (?:fps|tbr)').Matches[0].Groups[1].Value
        $fps = [Double]$fps_str
        $width = if ($w_str -match '^\d+$') {[Int]($w_str)} elseif ($cw_str -match '^\d+$') {[Int]($cw_str)} else {0}
        $height = if ($h_str -match '^\d+$') {[Int]($h_str)} elseif ($ch_str -match '^\d+$') {[Int]($ch_str)} else {0}
        $nb_frames_str = if ($nb_frames_str -match '^\d+$') {$nb_frames_str} else {$nb_packets_str}
        if ($nb_frames_str -notmatch '^\d+$')
        {
            write("WARNING: Unable to get fpi ($src_short)! Falling back to $FPI_DEFAULT!")
            $nb_frames_str = ($FPI_DEFAULT * ($tilew * $tileh - 1)).ToString()
        }
        $nb_frames = [Int]($nb_frames_str)
        #2. calculate number of frames and time per image
        #3. calculate a half of remaining frames < fpi / time < spi to adjust seek
        #   so first and last screens have offsets rem/2 and nbf-rem/2 instead of 0 and nbf-rem
        $rem0 = $null
        $fpi = [Math]::DivRem($nb_frames, $tilew * $tileh - 1, [Ref]$rem0)
        $fpi = if ($fpi -le 1) {1} elseif ($rem0 -eq 0) {$fpi - 1} else {$fpi}
        $spi = $fpi / ($fps + 0.001)  # friggin' PS rounding kills me
        $rem = [Math]::Floor($rem0 / 2)
        $srem = if ($rem -eq 0) {0.0} else {($rem0 / 2) / $fps}
        #4. create preview directory in current folder
        #5. run ffmpeg with calculated params to generate preview
        $pars = @{
            basefile = $file
            dest_filename = $dest_file_name
            frames = $fpi.ToString()
            secs = $spi
            horizontal = $width -ge $height
            filesize = $filesize
            duration = $dur_str
            bitrate = $br_str
            resolution = "$width`x$height"
            adv = $rem
            sadv = $srem
            fps = $fps_str
        }
        if ($seek_mode -eq $SEEK_MODE_FULL)
        { $params = get_ffmpeg_params @pars; $use_full_parse = $true }
        elseif ($seek_mode -eq $SEEK_MODE_FAST)
        { $params = get_ffmpeg_params_q @pars; $use_full_parse = $false }
        else
        {
            $use_full_parse = ($file.Length -lt 20mb -and $fps -lt 50.0) -or ($dur_secs -lt 60.0) -or ($ext -imatch '^\.avi$')
            $params = if ($use_full_parse) {get_ffmpeg_params @pars} else {get_ffmpeg_params_q @pars}
        }
        write("[$(Get-Date -Format $TimeFormat)] [$(if ($use_full_parse) {'FULL'} else {'SEEK'})] Processing '$src_short'...")
        #write($params)
        if ([IO.Directory]::Exists($destdir) -ne $true)
        {
            [IO.Directory]::CreateDirectory($destdir) > $null
        }
        (&"$MYFFMPEG" ($params)) 2>&1
        return
    }
    #write("Skipped file '$file.Name'")
}

function process_folder{ Param ([IO.DirectoryInfo]$folder, [Int]$level)
    if ($folder.GetFileSystemInfos().Length -eq 0)
    { return }
    $my_pattern = if ($any_mode -eq $true) {'^.*$'} elseif ($level -eq 0) {$PAT0} elseif ($level -eq 1) {$PAT1} else {'^.*$'}
    if ($folder.Name -match $my_pattern)  # 0: './0219/'  # 1: './04hami/'
    {
        $folder.GetDirectories() | ForEach-Object {
            process_folder -folder $_ -level ($level+1)
        }
        $foldername = $folder.FullName -replace '\\', '/'
        if ($foldername[$foldername.Length-1] -ne '/')
        { $foldername += '/' }
        $dest_folder_name = "$foldername`preview/"
        if ($clear_mode -eq $true)
        {
            if ([IO.Directory]::Exists($dest_folder_name) -eq $true)
            {
                $dest_folder_name_short = "$($foldername.Substring($foldername.IndexOf($path_info.Name)))preview/"
                write("[Clear] removing directory '$dest_folder_name_short'...")
                Get-ChildItem $dest_folder_name -Recurse | Remove-Item -Force
                [IO.Directory]::Delete($dest_folder_name)
            }
            return
        }
        if ($any_mode -ne $true -and $level -lt 1)
        { return }
        $folder.GetFiles() | ForEach-Object {
            process_file -file $_ -destdir $dest_folder_name
        }
    }
}

function print_help{
    write(" Recursive traversal video preview generator for .mp4 and .webm files`n" +
          "  Syntax: $($script:MyInvocation.MyCommand.Name) [--help] [--clear] [options...] [--path #PATH]`n" +
          "`n" +
          "   Options:`n" +
          "    --path PATH             `tPath to target base folder. Default is '$MYWORKDIR_DWNLD'`n" +
          "`n" +
          "    --clear                 `tREMOVE all previews and 'preview' folders instead`n" +
          "    --any                   `tTraverse all folders not checking names`n" +
          "    --report-existing       `tPrint a message if preview already exists`n" +
          "    --threads INT           `tSet decode threads parameter. Default is 'auto'`n" +
          "    --width, -w INT         `tSet preview width, $PREVIEW_W_MIN to $PREVIEW_W_MAX. Default is '$WIDTH_DEFAULT'`n" +
          "    --force-mode, -m {$SEEK_MODE_AUTO,$SEEK_MODE_FULL,$SEEK_MODE_FAST}" +
           "`tForce seek mode: $SEEK_MODE_AUTO='auto' (default), $SEEK_MODE_FULL='full', $SEEK_MODE_FAST='seek'`n" +
          "    --tiles-horizontal, -x  `tSet horizontal tiles number, $TILE_W_MIN to $TILE_W_MAX. Default is '$tilew'`n" +
          "    --tiles-vertical, -y    `tSet vertical tiles number, $TILE_H_MIN to $TILE_H_MAX. Default is '$tileh'`n")
}

#INIT
#config
$proc_path = $MYWORKDIR
$clear_mode = $false
$any_mode = $false
$report_existing = $false
$threads = 0
$preview_w = $WIDTH_DEFAULT
$seek_mode = $SEEK_MODE_AUTO
$tilew = $TILE_W_DEFAULT
$tileh = $TILE_H_DEFAULT

$sleep_time = 0

$i = 0
while ($true)
{
    $str = [String]$args[$i]
    if ($args[$i] -eq $null)
    { break }
    elseif ($str -eq '--help')
    {
        print_help
        return
    }
    elseif ($str -eq '--path')
    {
        $str2 = $args[$i+1]
        ++$i
        $proc_path = $str2 -replace '\\', '/'
        if ($proc_path -ne '' -and $proc_path[$proc_path.Length-1] -ne '/')
        { $proc_path += '/' }
        write("[CFG] targeting non-default folder '$proc_path'")
        $sleep_time = [Math]::Max($sleep_time, 1)
    }
    elseif ($str -eq '--threads')
    {
        $str2 = $args[$i+1]
        ++$i
        if ($str2 -notmatch '^\d+$')
        {
            Write-Error("Invalid value for $str`: '$str2'")
            return
        }
        $threads = [Int]($str2)
        write("[CFG] using $threads decode threads")
        $sleep_time = [Math]::Max($sleep_time, 1)
    }
    elseif ($str -eq '--width' -or $str -eq '-w')
    {
        $str2 = $args[$i+1]
        ++$i
        if ($str2 -notmatch '^\d+$')
        {
            Write-Error("Invalid value for $str`: '$str2'")
            return
        }
        $preview_w = [Int]($str2)
        write("[CFG] using preview width: $preview_w")
        $sleep_time = [Math]::Max($sleep_time, 1)
    }
    elseif ($str -eq '--force-mode' -or $str -eq '-m')
    {
        $str2 = $args[$i+1]
        ++$i
        if ($str2 -notmatch '^[012]$')
        {
            Write-Error("Invalid value for $str`: '$str2'")
            return
        }
        $seek_mode = [Int]($str2)
        write("[CFG] using seek mode: $($SEEK_MODE_NAMES[$seek_mode.ToString()].ToUpper())")
        $sleep_time = [Math]::Max($sleep_time, 1)
    }
    elseif ($str -eq '--tiles-horizontal' -or $str -eq '-x')
    {
        $str2 = $args[$i+1]
        ++$i
        if ($str2 -notmatch '^[' + "$TILE_W_MIN-$TILE_W_MAX" + ']$')
        {
            Write-Error("Invalid value for $str`: '$str2'")
            return
        }
        $tilew = [Int]($str2)
        write("[CFG] using horizontal tiles: $tilew")
        $sleep_time = [Math]::Max($sleep_time, 1)
    }
    elseif ($str -eq '--tiles-vertical' -or $str -eq '-y')
    {
        $str2 = $args[$i+1]
        ++$i
        if ($str2 -notmatch '^[' + "$TILE_H_MIN-$TILE_H_MAX" + ']$')
        {
            Write-Error("Invalid value for $str`: '$str2'")
            return
        }
        $tileh = [Int]($str2)
        write("[CFG] using vertical tiles: $tileh")
        $sleep_time = [Math]::Max($sleep_time, 1)
    }
    elseif ($str -eq '--clear')
    {
        $clear_mode = $true
        write('[CFG] running clear mode')
        $sleep_time = [Math]::Max($sleep_time, 2)
    }
    elseif ($str -eq '--any')
    {
        $any_mode = $true
        write('[CFG] folder names checking DISABLED')
        $sleep_time = [Math]::Max($sleep_time, 1)
    }
    elseif ($str -eq '--report-existing')
    {
        $report_existing = $true
        write('[CFG] reporting existing previews ENABLED')
    }
    else
    {
        Write-Error("Unknown arg type: '$str'")
        return
    }
    ++$i
}

#final checks
if ([IO.Directory]::Exists($proc_path) -ne $true)
{
    write("Invalid path: '$proc_path'")
    return
}

if ($clear_mode -ne $true)
{
    if ($preview_w -eq 0)
    {
        print_help
        Write-Error('Error: width is not set!')
        return
    }
    elseif ($preview_w -lt $PREVIEW_W_MIN)
    {
        print_help
        Write-Error("Error: min preview width is $PREVIEW_W_MIN!")
        return
    }
    elseif ($preview_w -gt $PREVIEW_W_MAX)
    {
        print_help
        Write-Error("Error: max preview width is $PREVIEW_W_MAX!")
        return
    }
    #elseif ($preview_w -band 1)
    #{
    #    print_help
    #    Write-Error('Error: preview width value must be even!')
    #    return
    #}
}

$path_info = Get-ItemProperty $proc_path
if ($path_info -isnot [IO.DirectoryInfo])
{
    Write-Error('ERROR: selected path is not a directory!')
    return
}

if ($sleep_time -gt 0)
{ Start-Sleep -Seconds $sleep_time }

$startTime = (Get-Date -Format $TimeFormat)

#RUN
write ("[$startTime] Starting ffmpeg preview gen on '$proc_path'...")

##############################################
#                ROOT CALL                   #
process_folder -folder $path_info -level -1  #
##############################################

if ($clear_mode -eq $true)
{ write('Clearing complete') }

write ("Started at $startTime, ended at $(Get-Date -Format $TimeFormat)")

#
########################

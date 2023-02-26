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

#ffmpeg.exe -hide_banner -y -loglevel info -noautorotate -i 1.mp4 -an -frames:v 1 -q:v 5 -fps_mode vfr -flags +bitexact -threads 3
# -filter_complex "select='not(mod(n\,61))',scale=w=317:h=-1,
#drawtext=fontsize=19:fontfile='C\:/Windows/Fonts/l_10646.ttf':text='%{pts\:hms\}':x=0:y=h-lh-lh/2
# :fontcolor=white:alpha=0.65:borderw=2:bordercolor=0x000000B0,tile=4x3:padding=4:margin=0:color=0x222222A0,
#pad=h=ih+100:w=iw:y=oh-ih:color=0x222222A0:eval=init,
#drawtext=fontsize=18:fontfile='C\:/Windows/Fonts/l_10646.ttf':text='Resolution\: 1280x960':x=10:y=lh:fontcolor=white,
#drawtext=fontsize=18:fontfile='C\:/Windows/Fonts/l_10646.ttf':text='Bitrate\: 8962 kb/s':x=10:y=lh*2-1:fontcolor=white,
#drawtext=fontsize=18:fontfile='C\:/Windows/Fonts/l_10646.ttf':text='File Size\: 5.5 MB (5 444 441 bytes)':x=10:y=lh*3:fontcolor=white,
#drawtext=fontsize=18:fontfile='C\:/Windows/Fonts/l_10646.ttf':text='Duration\: 00\:00\:00':x=10:y=lh*5+4:fontcolor=white" prev.jpg

#imports
$MYWORKDIR = $MYWORKDIR_DWNLD
$MYFFPROBE = $RUN_FFPROBE
$MYFFMPEG = $RUN_FFMPEG

#consts
$PREVIEW_EXT = ".jpg"
$FPI_DEFAULT = "45"
$PAT0 = "^[01][0-9]{3}$"
$PAT1 = "^[0-9]{1,2}[a-z]{1,4}$"

$PREVIEW_W_MIN = 640
$PREVIEW_W_MAX = 1920
$DRAWTEXT_ALPHA = "0.65"
$BGCOLOR = "0x222222A0"
$DT_FONT = "'C\:/Windows/Fonts/l_10646.ttf'" #Lucida Sans Unicode
$TILE_W_INT = 5
$TILE_H_INT = 4
$TILE_DIMS = '' + $TILE_W_INT + 'x' + $TILE_H_INT
$TILE_DIMS_ROTATED = '' + $TILE_W_INT * 2 + 'x' + [Math]::Floor($TILE_H_INT / 2)

#functions
function get_ffmpeg_params{ Param ([IO.FileInfo]$basefile, [String]$dest_filename, [String]$frames, [Boolean]$horizontal,
                                   [String]$filesize, [String]$duration, [String]$bitrate, [String]$resolution, [String]$advance)

    $fwidth = if ($horizontal -eq $true) {[Math]::Ceiling($preview_w / $TILE_W_INT)} else {[Math]::Ceiling(($preview_w / $TILE_W_INT) / 2)}
    $fdims = if ($horizontal -eq $true) {$TILE_DIMS} else {$TILE_DIMS_ROTATED}
    $fsiz = "File Size\: " + $filesize                     #File Size\: 5.5 MB (5 444 441 bytes)
    $fdur = "Duration\: " + ($duration -replace ":", "\:") #Duration\: 00\:00\:00
    $fbrt = "Bitrate\: " + $bitrate                        #Bitrate\: 8962 kb/s
    $fres = "Resolution\: " + $resolution                  #Resolution\: 1280x960

    $dtfsize1 = [Math]::Max([Int]($fwidth) / 20, 10)
    $dtfsize2 = [Math]::Max([Math]::Floor($preview_w / 100), 10)
    $padsize = [Math]::Floor($dtfsize2 * 6)

    $dtpadsize = $dtfsize2  # up and down
    $ty1 = $dtpadsize
    $ty2 = $ty1 + $dtpadsize + 1
    $ty3 = $ty2 + $dtpadsize + 1
    $ty4 = $ty3 + $dtpadsize + 1
    $tx = [Math]::Floor($dtfsize2 * 0.75)

    $Params = New-Object Collections.ArrayList
    $Params.Add("-hide_banner") > $null
    $Params.Add("-y") > $null
    $Params.Add("-loglevel") > $null
    $Params.Add("error") > $null
    $Params.Add("-noautorotate") > $null
    $Params.Add("-i") > $null
    $Params.Add(($basefile.FullName -replace '\\', '/')) > $null
    $Params.Add("-an") > $null
    $Params.Add("-frames:v") > $null
    $Params.Add("1") > $null
    $Params.Add("-q:v") > $null
    $Params.Add("5") > $null
    $Params.Add("-vsync") > $null
    $Params.Add("0") > $null
    $Params.Add("-flags") > $null
    $Params.Add("+bitexact") > $null
    $Params.Add("-threads") > $null
    $Params.Add($threads) > $null
    $Params.Add("-vf") > $null
    $Params.Add(
        "select='not(mod(n-" + $advance + "\," + $frames + "))'," +
        "scale=w=" + $fwidth + ":h=-1," +
        "drawtext=fontsize=" + $dtfsize1 + ":fontfile=" + $DT_FONT + ":x=0:y=h-lh-lh/2:fontcolor=white:text='%{pts\:hms\}'" +
         ":alpha=" + $DRAWTEXT_ALPHA + ":borderw=2:bordercolor=0x000000A0," +
        "tile=" + $fdims + ":padding=2:margin=1:color=" + $BGCOLOR + "," +
        "pad=h=ih+" + $padsize + ":w=iw+" + ($fwidth -band 1) + ":y=oh-ih:color=" + $BGCOLOR + ":eval=init," +
        "drawtext=fontsize=" + $dtfsize2 + ":fontfile=" + $DT_FONT + ":x=" + $tx + ":y=" + $ty1 + ":fontcolor=white:text='" + $fsiz + "'," +
        "drawtext=fontsize=" + $dtfsize2 + ":fontfile=" + $DT_FONT + ":x=" + $tx + ":y=" + $ty2 + ":fontcolor=white:text='" + $fres + "'," +
        "drawtext=fontsize=" + $dtfsize2 + ":fontfile=" + $DT_FONT + ":x=" + $tx + ":y=" + $ty3 + ":fontcolor=white:text='" + $fbrt + "'," +
        "drawtext=fontsize=" + $dtfsize2 + ":fontfile=" + $DT_FONT + ":x=" + $tx + ":y=" + $ty4 + ":fontcolor=white:text='" + $fdur + "'," +
        "scale=w=" + $preview_w + ":h=-1"
    ) > $null
    $Params.Add($dest_filename) > $null
    return $Params
}

function process_file{ Param ([IO.FileInfo]$file, [String]$destdir)
    $ext = $file.Extension
    $size = $file.Length
    $filesize = "" + [Math]::Round($size / 1mb, 2) + " MB (" + $size.ToString("N0") + " bytes)"
    if ($ext -match "^\.(?:mp4|webm)$")
    {
        $file_name_short = ($file.BaseName -replace "^(?<fname>(?:.._)?(?=[0-9]+)[^_]+)_.+?$", '${fname}') + $ext
        $src_short = $file.FullName.Substring($file.FullName.IndexOf($path_info.Name)) -replace '\\', '/'
        $src_short = $src_short.Remove($src_short.LastIndexOf('/') + 1) + $file_name_short
        $dest_file_name = $destdir + $file.BaseName + $PREVIEW_EXT
        if ([IO.File]::Exists($dest_file_name) -eq $true)
        {
            if ($report_existing -eq $true)
            { write("Preview for '" + $src_short + "' already exists! Skipped...") }
            return
        }
        #1. execute ffprobe and get:
        # 1) number of frames
        # 2) video dimensions
        # 3) video duration
        # 4) video bitrate
        $ffp_params = New-Object Collections.ArrayList
        $ffp_params.Add("-hide_banner") > $null
        #$ffp_params.Add("-loglevel") > $null
        #$ffp_params.Add("info") > $null
        $ffp_params.Add("-show_streams") > $null
        $ffp_params.Add("-select_streams") > $null
        $ffp_params.Add("v:0") > $null
        if ($ext -eq ".webm")
        { $ffp_params.Add("-count_packets") > $null }
        $ffp_params.Add("-i") > $null
        $ffp_params.Add($file.FullName) > $null
        $output = ((&"$MYFFPROBE" ($ffp_params)) 2>&1) #we have to get all output to parse duration
        $nb_frames_str = ($output -match "^nb_frames=.+$")[0].Split('=')[1]
        $nb_packets_str = ($output -match "^nb_read_packets=.+$")[0].Split('=')[1]
        $w_str = ($output -match "^width=.+$")[0].Split('=')[1]
        $h_str = ($output -match "^height=.+$")[0].Split('=')[1]
        $cw_str = ($output -match "^coded_width=.+$")[0].Split('=')[1]
        $ch_str = ($output -match "^coded_height=.+$")[0].Split('=')[1]
        $durbr_str = ($output[$output.Length-1].ToString().Split("`n") -match "^  Duration: .+$")[0]
        $durbr_str = if ($durbr_str) {$durbr_str} else {($output[$output.Length-2].ToString().Split("`n") -match "^  Duration: .+$")[0]}
        $durbr_str = if ($durbr_str) {$durbr_str} else {($output[$output.Length-3].ToString().Split("`n") -match "^  Duration: .+$")[0]}
        $dur_str = $durbr_str.Substring([String]("  Duration: ").Length, [String]("00:00:00.00").Length - 3)
        $br_str = $durbr_str.Substring($durbr_str.IndexOf("bitrate: ") + [String]("bitrate: ").Length)
        $width = if ($w_str -match "^\d+$") {[Int]($w_str)} elseif ($cw_str -match "^\d+$") {[Int]($cw_str)} else {0}
        $height = if ($h_str -match "^\d+$") {[Int]($h_str)} elseif ($ch_str -match "^\d+$") {[Int]($ch_str)} else {0}
        $nb_frames_str = if ($nb_frames_str -match "^\d+$") {$nb_frames_str} else {$nb_packets_str}
        if ($nb_frames_str -notmatch "^\d+$")
        {
            write("WARNING: Unable to get fpi (" + $src_short + ")! Falling back to " + $FPI_DEFAULT + "!")
            $nb_frames_str = ($FPI_DEFAULT * ($TILE_W_INT * $TILE_H_INT - 1)).ToString()
        }
        $nb_frames = [Int]($nb_frames_str)
        #2. calculate number of frames per image
        #3. calculate a half of remaining frames < fpi to adjust seek
        #   so first and last screens have offsets rem/2 and nbf-rem/2 instead of 0 and nbf-rem
        $rem0 = $null
        $fpi = [Math]::DivRem($nb_frames, ($TILE_W_INT * $TILE_H_INT - 1), [Ref]$rem0)
        $fpi = if ($fpi -le 1) {1} elseif ($nb_frames % $fpi -eq 0) {$fpi - 1} else {$fpi}
        $rem = [Math]::Floor($rem0 / 2)
        #4. create preview directory in current folder
        #5. run ffmpeg with calculated params to generate preview
        $pars = @{
            basefile = $file
            dest_filename = $dest_file_name
            frames = $fpi.ToString()
            horizontal = $width -ge $height
            filesize = $filesize
            duration = $dur_str
            bitrate = $br_str
            resolution = "{0:d}x{1:d}" -f $width, $height
            advance = $rem.ToString()
        }
        $params = get_ffmpeg_params @pars
        write("Generating preview for '" + $src_short + "'...")
        #write($params)
        if ([IO.Directory]::Exists($destdir) -ne $true)
        {
            [IO.Directory]::CreateDirectory($destdir) > $null
        }
        (&"$MYFFMPEG" ($params)) 2>&1
        return
    }
    #write("Skipped file '" + $file.Name + "'")
}

function process_folder{ Param ([IO.DirectoryInfo]$folder, [Int]$level)
    if ($folder.GetFileSystemInfos().Length -eq 0)
    { return }
    $my_pattern = if ($any_mode -eq $true) {"^.*$"} elseif ($level -eq 0) {$PAT0} elseif ($level -eq 1) {$PAT1} else {"^.*$"}
    if ($folder.Name -match $my_pattern)  # 0: './0219/'  # 1: './04hami/'
    {
        $folder.GetDirectories() | ForEach-Object {
            process_folder -folder $_ -level ($level+1)
        }
        $foldername = $folder.FullName -replace '\\', '/'
        if ($foldername[$foldername.Length-1] -ne '/')
        { $foldername += '/' }
        $dest_folder_name = $foldername + "preview/"
        if ($clear_mode -eq $true)
        {
            if ([IO.Directory]::Exists($dest_folder_name) -eq $true)
            {
                $dest_folder_name_short = $foldername.Substring($foldername.IndexOf($path_info.Name)) + "preview/"
                write("[Clear] removing directory '" + $dest_folder_name_short + "'...")
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
          "  Syntax: " + $script:MyInvocation.MyCommand.Name + " [--help] [options...] --width #WIDTH --path #PATH`n`n" +
          "   Options:`n" +
          "    --clear          `t`tRemove all previews and 'preview' folders`n" +
          "    --any            `t`tTraverse all folders not checking names`n" +
          "    --report-existing`t`tPrint a message if preview already exists`n" +
          "    --threads INT    `t`tSet threads number to use. Default is 3`n" +
          "    --width, -w INT  `t`tSet preview width. Required`n")
}

#INIT
#config
$proc_path = $MYWORKDIR
$clear_mode = $false
$any_mode = $false
$report_existing = $false
$threads = 3
$preview_w = 0

$sleep_time = 0

$i = 0
$j = 0
while ($true)
{
    $str = [String]$args[$i]
    if ($args[$i] -eq $null)
    { break }
    elseif ($str -eq "--help")
    {
        print_help
        return
    }
    elseif ($str -eq "--path")
    {
        $str2 = $args[$i+1]
        ++$i
        $proc_path = $str2 -replace '\\', '/'
        if ($proc_path -ne "" -and $proc_path[$proc_path.Length-1] -ne '/')
        { $proc_path += '/' }
        write("[CFG] targeting non-default folder '" + $proc_path + "'")
        $sleep_time = [Math]::Max($sleep_time, 1)
    }
    elseif ($str -eq "--threads")
    {
        $str2 = $args[$i+1]
        ++$i
        if ($str2 -notmatch "^\d+$")
        {
            Write-Error("Invalid value for " + $str + ": '" + $str2 + "'")
            return
        }
        $threads = [Int]($str2)
        write("[CFG] using $threads threads")
        $sleep_time = [Math]::Max($sleep_time, 1)
    }
    elseif ($str -eq "--width" -or $str -eq "-w")
    {
        $str2 = $args[$i+1]
        ++$i
        if ($str2 -notmatch "^\d+$")
        {
            Write-Error("Invalid value for " + $str + ": '" + $str2 + "'")
            return
        }
        $preview_w = [Int]($str2)
        write("[CFG] using preview width $preview_w")
        $sleep_time = [Math]::Max($sleep_time, 1)
    }
    elseif ($str -eq "--clear")
    {
        $clear_mode = $true
        write("[CFG] running clear mode")
        $sleep_time = [Math]::Max($sleep_time, 2)
    }
    elseif ($str -eq "--any")
    {
        $any_mode = $true
        write("[CFG] folder names checking DISABLED")
        $sleep_time = [Math]::Max($sleep_time, 1)
    }
    elseif ($str -eq "--report-existing")
    {
        $report_existing = $true
        write("[CFG] reporting existing previews ENABLED")
    }
    else
    {
        write("Unknown arg type: '" + $str + "'")
        return
    }
    ++$i
}

#final checks
if ([IO.Directory]::Exists($proc_path) -ne $true)
{
    write("Invalid path: '" + $proc_path + "'")
    return
}

if ($clear_mode -ne $true)
{
    if ($preview_w -eq 0)
    {
        print_help
        Write-Error("Error: width is not set!")
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
    #    Write-Error("Error: preview width value must be even!")
    #    return
    #}
}

$path_info = Get-ItemProperty $proc_path
if ($path_info.GetType() -ne [IO.DirectoryInfo])
{
    Write-Error("ERROR: selected path is not a directory!")
    return
}

if ($sleep_time -gt 0)
{ Start-Sleep -Seconds $sleep_time }

$startTime = (Get-Date -Format $TimeFormat)

#RUN
write ('[' + $startTime + "] Starting ffmpeg preview gen on '" + $proc_path + "'...")

##############################################
#                ROOT CALL                   #
process_folder -folder $path_info -level -1  #
##############################################

if ($clear_mode -eq $true)
{ write("Clearing complete") }

write ("Started at " + $startTime + ", ended at " + (Get-Date -Format $TimeFormat))

#
########################

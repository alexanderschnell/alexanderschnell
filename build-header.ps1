# Generates header-<hash>.svg - an animated mainframe (TSO/JES) terminal GitHub profile header,
# and points README.md at it. Pure SVG + SMIL + CSS (no JS), so it animates inside GitHub READMEs.
#
# Run locally:  powershell -ExecutionPolicy Bypass -File build-header.ps1
# Runs daily in GitHub Actions (.github/workflows/update-header.yml) to refresh the date, job
# number, uptime and contribution count.
#
# NOTE: PowerShell variable names are case-insensitive ($t == $T) - keep names distinct.
# NOTE: keep this file pure ASCII (Windows PowerShell 5.1 reads BOM-less files as ANSI).

[System.Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
$ErrorActionPreference = 'Stop'

# ---------------- personal config ----------------
$START_DATE = '2025-05-06'                # FSWEP role start, 'yyyy-MM-dd'. Empty = hide the UPTIME line.
$GH_LOGIN   = if ($env:GITHUB_REPOSITORY_OWNER) { $env:GITHUB_REPOSITORY_OWNER } else { 'alexanderschnell' }

# ---------------- layout config ----------------
$X0       = 52        # left text margin
$Y0       = 160       # first terminal line baseline
$LH       = 24        # line height
$FS       = 17        # terminal font size
$ADV      = 10.2      # monospace advance (0.6em) - every char is placed explicitly
$CMD_CPS  = 0.045     # seconds per typed char
$SRC_CPS  = 0.013     # seconds per char of COBOL source
$OUT_CPS  = 0.008     # seconds per system-output char
$HOLD     = 4.5       # seconds the final screen stays up before the loop restarts
$FONT     = "'IBM Plex Mono','JetBrains Mono','Cascadia Code',Consolas,'Courier New',monospace"

# palette: black + blue
$BLU0 = '#3d8bff'; $CYN = '#5ad1ff'; $WHT = '#f2f2f2'; $YEL = '#fff35c'
$LBL  = '#7aa2ff'; $RED = '#ff4b4b'; $DIM = '#2a4f8a'

# ---------------- dynamic values ----------------
$now     = [DateTime]::UtcNow
$julian  = '{0}.{1:000}' -f $now.Year, $now.DayOfYear
$days    = [int]($now.Date - [DateTime]'2024-02-20').TotalDays
$jobNo   = '{0:00000}' -f ((($days * 37) % 89000) + 10000)
$jobNo2  = '{0:00000}' -f ([int]$jobNo + 1)

$uptime = $null
if ($START_DATE) {
    $sd = [DateTime]::ParseExact($START_DATE, 'yyyy-MM-dd', $null)
    $months = ($now.Year - $sd.Year) * 12 + $now.Month - $sd.Month
    if ($now.Day -lt $sd.Day) { $months-- }
    $anchor = $sd.AddMonths($months)
    $uptime = '{0}Y {1}M {2}D  SINCE {3}' -f [math]::Floor($months / 12), ($months % 12), [int]($now.Date - $anchor.Date).TotalDays, $sd.ToString('yyyy-MM-dd')
}

$contrib = $null
$token = if ($env:GITHUB_TOKEN) { $env:GITHUB_TOKEN } elseif ($env:GH_TOKEN) { $env:GH_TOKEN } else { $null }
if ($token) {
    try {
        $q = @{ query = "query { user(login: `"$GH_LOGIN`") { contributionsCollection { contributionCalendar { totalContributions } } } }" } | ConvertTo-Json
        $r = Invoke-RestMethod -Uri 'https://api.github.com/graphql' -Method Post -Body $q -Headers @{ Authorization = "bearer $token"; 'User-Agent' = 'profile-header-builder' }
        $contrib = $r.data.user.contributionsCollection.contributionCalendar.totalContributions
    } catch { Write-Warning "contribution lookup failed: $_" }
}

# ---------------- timing tokens ----------------
# Times are emitted as {{T:sec}} / {{Ek}} tokens and resolved to keyTimes once the loop length is known.
function F($n) { '{0:0.####}' -f $n }
function KT($tm) { if ($tm -is [string]) { $tm } else { "{{T:$(F $tm)}}" } }
$DUR = '{{DUR}}'
$script:sceneEnd = @{}
$script:curEnd = '{{E1}}'

function Esc($s) { $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;') }
function Line-Text($segments, $ly) {
    $chars = 0; $spans = ''
    foreach ($s in $segments) { $spans += "<tspan fill=`"$($s[1])`">$(Esc $s[0])</tspan>"; $chars += $s[0].Length }
    $xs = (0..($chars - 1) | ForEach-Object { F ($X0 + $_ * $ADV) }) -join ' '
    "<text x=`"$xs`" y=`"$ly`" xml:space=`"preserve`">$spans</text>"
}

$script:cursor = New-Object System.Collections.ArrayList   # (time, x, y)
$script:defs = ''; $script:body = ''; $script:clipId = 0
function Cur($tm, $cxp, $cyp) { [void]$script:cursor.Add(@($tm, $cxp, $cyp)) }

# Discrete clip reveal: chars appear one by one from t0; cleared at the current scene end.
function Reveal($segments, $ly, $t0, $cps) {
    $total = ($segments | ForEach-Object { $_[0].Length } | Measure-Object -Sum).Sum
    $id = "c$($script:clipId)"; $script:clipId++
    $vals = @('0'); $kts = @('0'); $tm = $t0
    for ($n = 1; $n -le $total; $n++) {
        $vals += F ($n * $ADV + 2); $kts += KT $tm
        Cur $tm ($X0 + $n * $ADV) $ly
        if ($n -lt $total) { $tm += $cps }
    }
    $vals += '0'; $kts += $script:curEnd
    $script:defs += "<clipPath id=`"$id`"><rect x=`"$($X0 - 2)`" y=`"$($ly - 19)`" width=`"0`" height=`"25`"><animate attributeName=`"width`" dur=`"$DUR`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"$($vals -join ';')`" keyTimes=`"$($kts -join ';')`"/></rect></clipPath>`n"
    $script:body += "<g clip-path=`"url(#$id)`">$(Line-Text $segments $ly)</g>`n"
    return $tm
}
function Show-Window($ta, $tb = $script:curEnd) {
    "<animate attributeName=`"opacity`" dur=`"$DUR`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"0;1;0`" keyTimes=`"0;$(KT $ta);$(KT $tb)`"/>"
}
function End-Scene($key, $tm) { $script:sceneEnd[$key] = $tm }

$L = { param($i) $Y0 + ($i - 1) * $LH }   # baseline of screen line i

# ================= SCENE 1: edit + compile COBOL =================
$tm = 1.7
$tm = Reveal @(,@('READY', $WHT)) (& $L 1) $tm 0.001; Cur $tm $X0 (& $L 2); $tm += 0.5
$tm = Reveal @(@('EDIT ', $BLU0), @("'ALEX.COBOL(PROFILE)'", $CYN)) (& $L 2) $tm $CMD_CPS; $tm += 0.4
$src = @(
    @(@('000100 ', $DIM), @('IDENTIFICATION DIVISION.', $CYN)),
    @(@('000200 ', $DIM), @('PROGRAM-ID. ', $CYN), @('PROFILE', $WHT), @('.', $CYN)),
    @(@('000300 ', $DIM), @('PROCEDURE DIVISION.', $CYN)),
    @(@('000400 ', $DIM), @('    DISPLAY ', $LBL), @("'ALEX SCHNELL'", $YEL), @('.', $LBL)),
    @(@('000500 ', $DIM), @('    DISPLAY ', $LBL), @("'FSWEP MAINFRAME DEVELOPER'", $YEL), @('.', $LBL)),
    @(@('000600 ', $DIM), @('    STOP RUN.', $LBL))
)
for ($i = 0; $i -lt $src.Count; $i++) { $tm = Reveal $src[$i] (& $L (3 + $i)) $tm $SRC_CPS; $tm += 0.12 }
$tm += 0.4
$tm = Reveal @(@('END OF COMPILATION 1, PROGRAM PROFILE, HIGHEST SEVERITY ', $BLU0), @('0', $YEL), @('.', $BLU0)) (& $L 9) $tm $OUT_CPS
$tm += 1.4
End-Scene 'E1' $tm; $tm += 0.25; $script:curEnd = '{{E2}}'

# ================= SCENE 2: JCL, S0C7 abend, fix, resubmit =================
$tm = Reveal @(,@('READY', $WHT)) (& $L 1) $tm 0.001; Cur $tm $X0 (& $L 2); $tm += 0.35
$tm = Reveal @(@('//ALEXPROF ', $WHT), @('JOB ', $CYN), @("(ACCT),'A SCHNELL',CLASS=A,MSGCLASS=X", $LBL)) (& $L 2) $tm $CMD_CPS; $tm += 0.15
$tm = Reveal @(@('//STEP01   ', $WHT), @('EXEC ', $CYN), @('PGM=PROFILE', $LBL)) (& $L 3) $tm $CMD_CPS; $tm += 0.15
$tm = Reveal @(@('//SYSOUT   ', $WHT), @('DD   ', $CYN), @('SYSOUT=*', $LBL)) (& $L 4) $tm $CMD_CPS; $tm += 0.35
$tm = Reveal @(,@('SUBMIT', $BLU0)) (& $L 5) $tm $CMD_CPS; $tm += 0.35
$tm = Reveal @(,@("IKJ56250I JOB ALEXPROF(JOB$jobNo) SUBMITTED", $BLU0)) (& $L 6) $tm $OUT_CPS; $tm += 0.3

# progress bar that dies at 60%
$label = 'STEP01   EXEC PGM=PROFILE'
$ly = & $L 7
$tm = Reveal @(,@($label, $LBL)) $ly $tm $OUT_CPS; $tm += 0.1
$bx = $X0 + ($label.Length + 2) * $ADV; $bw = 300; $pdur = 1.1; $fail = ($bw - 6) * 0.6
$script:body += "<g opacity=`"0`">$(Show-Window $tm)" +
    "<rect x=`"$bx`" y=`"$($ly - 14)`" width=`"$bw`" height=`"17`" fill=`"none`" stroke=`"$DIM`" stroke-width=`"1.3`"/>" +
    "<rect x=`"$($bx + 3)`" y=`"$($ly - 11)`" width=`"0`" height=`"11`" fill=`"url(#bar)`" filter=`"url(#glow)`"><animate attributeName=`"width`" dur=`"$DUR`" repeatCount=`"indefinite`" values=`"0;0;$fail;$fail;0`" keyTimes=`"0;$(KT $tm);$(KT ($tm + $pdur));$($script:curEnd);1`"/></rect></g>`n"
for ($p = 0; $p -le 6; $p++) {
    $ta = $tm + $pdur * $p / 6
    $tb = if ($p -lt 6) { $tm + $pdur * ($p + 1) / 6 } else { $tm + $pdur + 0.35 }
    $script:body += "<text x=`"$($bx + $bw + 14)`" y=`"$ly`" fill=`"$BLU0`" opacity=`"0`">$(Show-Window $ta $tb)$($p * 10)%</text>`n"
}
$tm += $pdur + 0.35
$abendT = $tm
$script:body += "<g opacity=`"0`">$(Show-Window $tm)<rect x=`"$($bx + 3)`" y=`"$($ly - 11)`" width=`"$fail`" height=`"11`" fill=`"$RED`" filter=`"url(#glow)`"/>" +
    "<text x=`"$($bx + $bw + 14)`" y=`"$ly`" fill=`"$RED`" font-weight=`"700`">ABEND</text></g>`n"
$tm = Reveal @(@("`$HASP165 ALEXPROF ENDED AT N1 - ", $RED), @('ABEND=S0C7', $YEL), @('  DATA EXCEPTION', $RED)) (& $L 8) $tm $OUT_CPS
$tm += 1.3
$tm = Reveal @(@('FIX: ', $CYN), @('INITIALIZE WS-AMOUNT. ', $WHT), @('* PACKED FIELD WAS SPACES', $DIM)) (& $L 9) $tm $CMD_CPS; $tm += 0.3
$tm = Reveal @(,@("IKJ56250I JOB ALEXPROF(JOB$jobNo2) SUBMITTED", $BLU0)) (& $L 10) $tm $OUT_CPS; $tm += 0.6
$tm = Reveal @(@("`$HASP165 ALEXPROF ENDED AT N1  ", $BLU0), @('MAXCC=0000', $YEL)) (& $L 11) $tm $OUT_CPS
$okT = $tm
$tm += 1.6
End-Scene 'E2' $tm; $tm += 0.25; $script:curEnd = '{{E3}}'

# ================= SCENE 3: SYSOUT =================
$i = 1
$tm = Reveal @(,@("------------ SYSOUT  ALEXPROF  JOB$jobNo2  RC=0000 ------------", $DIM)) (& $L $i) $tm 0.004; $i++; $tm += 0.2
$tm = Reveal @(@('NAME    ===> ', $CYN), @('ALEX SCHNELL', $YEL)) (& $L $i) $tm 0.02; $i++; $tm += 0.3
$tm = Reveal @(@('ROLE    ===> ', $CYN), @('FSWEP MAINFRAME DEVELOPER', $WHT), @(' @ EMPLOYMENT AND SOCIAL DEV. CANADA', $BLU0)) (& $L $i) $tm $OUT_CPS; $i++; $tm += 0.3
$tm = Reveal @(@('STUDY   ===> ', $CYN), @('COMPUTER ENGINEERING TECHNOLOGY - COMPUTING SCIENCE', $WHT)) (& $L $i) $tm $OUT_CPS; $i++; $tm += 0.3
$ly = & $L $i
$tm = Reveal @(,@('STACK   ===> ', $CYN)) $ly $tm $OUT_CPS; $tm += 0.1
$chips = @( @('COBOL','#ff79c6'), @('JCL','#5ad1ff'), @('JAVA','#f0a040'), @('C','#a8b9cc'), @('C++','#ff6b6b'), @('JAVASCRIPT','#fff35c'), @('AI','#b07cff') )
$cx = $X0 + 13 * $ADV
foreach ($c in $chips) {
    $cw = $c[0].Length * 8.6 + 30
    $script:body += "<g opacity=`"0`">$(Show-Window $tm)<animateTransform attributeName=`"transform`" type=`"translate`" dur=`"$DUR`" repeatCount=`"indefinite`" values=`"0 8;0 8;0 0;0 0`" keyTimes=`"0;$(KT $tm);$(KT ($tm + 0.22));1`"/>" +
        "<rect x=`"$cx`" y=`"$($ly - 16)`" width=`"$cw`" height=`"21`" rx=`"3`" fill=`"$($c[1])`" fill-opacity=`"0.14`" stroke=`"$($c[1])`" stroke-width=`"1.3`"/>" +
        "<circle cx=`"$($cx + 11)`" cy=`"$($ly - 5.5)`" r=`"3.5`" fill=`"$($c[1])`"/>" +
        "<text x=`"$($cx + 20)`" y=`"$ly`" font-size=`"14`" font-weight=`"700`" fill=`"$($c[1])`">$($c[0])</text></g>`n"
    Cur $tm ($cx + $cw + 8) $ly
    $cx += $cw + 9; $tm += 0.15
}
$i++; $tm += 0.4
if ($uptime) { $tm = Reveal @(@('UPTIME  ===> ', $CYN), @($uptime, $WHT)) (& $L $i) $tm $OUT_CPS; $i++; $tm += 0.3 }
if ($null -ne $contrib) { $tm = Reveal @(@('COMMITS ===> ', $CYN), @("$contrib", $YEL), @(' CONTRIBUTIONS IN THE LAST YEAR', $WHT)) (& $L $i) $tm $OUT_CPS; $i++; $tm += 0.3 }
$tm = Reveal @(,@('READY', $WHT)) (& $L $i) $tm 0.001; $i++
Cur $tm $X0 (& $L $i)
$LOOP = [math]::Round($tm + $HOLD, 1)
End-Scene 'E3' ($LOOP - 0.05)

# ---------------- cursor ----------------
$cv = @(); $ck = @(); $cyv = @()
$first = $script:cursor[0]
$cv += F $first[1]; $cyv += F ($first[2] - 15); $ck += '0'
foreach ($c in $script:cursor) { $cv += F $c[1]; $cyv += F ($c[2] - 15); $ck += KT $c[0] }
$cursorSvg = "<g class=`"blink`" opacity=`"0`"><animate attributeName=`"opacity`" dur=`"$DUR`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"0;1`" keyTimes=`"0;$(KT $first[0])`"/><rect width=`"10`" height=`"19`" fill=`"$BLU0`" filter=`"url(#glow)`">" +
  "<animate attributeName=`"x`" dur=`"$DUR`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"$($cv -join ';')`" keyTimes=`"$($ck -join ';')`"/>" +
  "<animate attributeName=`"y`" dur=`"$DUR`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"$($cyv -join ';')`" keyTimes=`"$($ck -join ';')`"/></rect></g>"

# ---------------- EBCDIC decode of the title ----------------
$hex = 'C1 D3 C5 E7 40 E2 C3 C8 D5 C5 D3 D3'   # "ALEX SCHNELL" in EBCDIC
$d0 = 0.5; $d1 = 1.5; $wipe = 740
$decode = "values=`"0;0;$wipe;$wipe`" keyTimes=`"0;$(KT $d0);$(KT $d1);1`""

# ---------------- status line ----------------
$status = "<text x=`"$($X0 + 70)`" y=`"452`" font-size=`"13`" fill=`"$LBL`" xml:space=`"preserve`">|  CONNECTED  |  <tspan>SYSTEM AVAILABLE</tspan></text>"
$statusAb = "<g opacity=`"0`">$(Show-Window $abendT $okT)<rect x=`"$($X0 + 196)`" y=`"439`" width=`"200`" height=`"18`" fill=`"#000`"/><text x=`"$($X0 + 202)`" y=`"452`" font-size=`"13`" font-weight=`"700`" fill=`"$RED`">X SYSTEM  ABEND S0C7</text></g>"
$flash = "<rect x=`"16`" y=`"140`" width=`"968`" height=`"285`" fill=`"$RED`" opacity=`"0`"><animate attributeName=`"opacity`" dur=`"$DUR`" repeatCount=`"indefinite`" values=`"0;0;.32;.04;.22;0;0`" keyTimes=`"0;$(KT $abendT);$(KT ($abendT + 0.08));$(KT ($abendT + 0.2));$(KT ($abendT + 0.3));$(KT ($abendT + 0.7));1`"/></rect>"

# ---------------- assemble ----------------
$SW = 1000; $SH = 480
$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $SW $SH" width="$SW" height="$SH" font-family="$FONT" font-size="$FS" role="img" aria-label="Alex Schnell - FSWEP Mainframe Developer at Employment and Social Development Canada, writing COBOL and JCL on the mainframe through the Asgard terminal. Also Java, C, C++, JavaScript, AI.">
<title>Alex Schnell - COBOL and JCL on the mainframe</title>
<style>
  .blink rect { animation: blink 1s steps(1) infinite; }
  @keyframes blink { 50% { opacity: 0; } }
  .flicker { animation: flicker 6s infinite; }
  @keyframes flicker { 0%,100%{opacity:1} 41%{opacity:1} 42%{opacity:.82} 43%{opacity:1} 77%{opacity:1} 77.5%{opacity:.7} 78%{opacity:1} }
  .ga { animation: ga 4.5s infinite steps(1); }
  .gb { animation: gb 4.5s infinite steps(1); }
  @keyframes ga { 0%,88%,100%{opacity:0;transform:none} 89%{opacity:.85;transform:translate(-5px,1px)} 91%{opacity:.85;transform:translate(4px,-2px)} 93%{opacity:.6;transform:translate(-2px,2px)} 95%{opacity:0} }
  @keyframes gb { 0%,88%,100%{opacity:0;transform:none} 89%{opacity:.85;transform:translate(5px,-1px)} 91%{opacity:.85;transform:translate(-3px,2px)} 93%{opacity:.6;transform:translate(3px,-1px)} 95%{opacity:0} }
  .dot { animation: dot 2s ease-in-out infinite; }
  @keyframes dot { 50% { opacity: .25; } }
</style>
<defs>
  <filter id="glow" x="-20%" y="-50%" width="140%" height="200%"><feGaussianBlur stdDeviation="2.2" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <filter id="bigglow" x="-10%" y="-60%" width="120%" height="220%"><feGaussianBlur stdDeviation="6" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <linearGradient id="bar" x1="0" x2="1"><stop offset="0" stop-color="#1f5fd6"/><stop offset="1" stop-color="#7cc4ff"/></linearGradient>
  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#060a14"/><stop offset="1" stop-color="#000000"/></linearGradient>
  <radialGradient id="vig" cx=".5" cy=".45" r=".75"><stop offset=".6" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".55"/></radialGradient>
  <linearGradient id="band" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="$BLU0" stop-opacity="0"/><stop offset=".5" stop-color="$BLU0" stop-opacity=".07"/><stop offset="1" stop-color="$BLU0" stop-opacity="0"/></linearGradient>
  <pattern id="scan" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="4" height="1.4" fill="#000" fill-opacity=".35"/></pattern>
  <clipPath id="win"><rect x="16" y="16" width="968" height="448" rx="14"/></clipPath>
  <clipPath id="titleclip"><rect x="$($X0 - 10)" y="50" width="0" height="70"><animate attributeName="width" dur="$DUR" repeatCount="indefinite" $decode/></rect></clipPath>
  <clipPath id="hexclip"><rect x="$($X0 - 10)" y="50" width="800" height="70"><animate attributeName="x" dur="$DUR" repeatCount="indefinite" values="$($X0 - 10);$($X0 - 10);$($X0 - 10 + $wipe);$($X0 - 10 + $wipe)" keyTimes="0;$(KT $d0);$(KT $d1);1"/></rect></clipPath>
$($script:defs)</defs>

<!-- window -->
<rect x="16" y="16" width="968" height="448" rx="14" fill="url(#bg)" stroke="#1a2f55" stroke-width="1.5"/>
<g clip-path="url(#win)">
  <rect x="16" y="16" width="968" height="38" fill="#0a1020"/>
  <line x1="16" y1="54" x2="984" y2="54" stroke="#1a2f55"/>
  <circle cx="44" cy="35" r="6.5" fill="#ff5f57"/><circle cx="66" cy="35" r="6.5" fill="#febc2e"/><circle cx="88" cy="35" r="6.5" fill="#3d8bff"/>
  <text x="500" y="40" text-anchor="middle" font-size="13" fill="#6f8fbf">ASGARD  -  SESSION A</text>
  <circle class="dot" cx="890" cy="35" r="4" fill="$BLU0" filter="url(#glow)"/>
  <text x="900" y="40" font-size="12" fill="$BLU0" letter-spacing="1">ONLINE</text>

  <!-- title: EBCDIC hex decodes into the name -->
  <g clip-path="url(#hexclip)"><text x="$X0" y="102" font-size="34" font-weight="700" fill="$DIM" letter-spacing="0" xml:space="preserve">$hex</text></g>
  <g clip-path="url(#titleclip)"><g class="flicker">
    <text class="ga" x="$X0" y="106" font-size="54" font-weight="800" fill="#ff2e63" letter-spacing="3">ALEX SCHNELL</text>
    <text class="gb" x="$X0" y="106" font-size="54" font-weight="800" fill="#00e5ff" letter-spacing="3">ALEX SCHNELL</text>
    <text x="$X0" y="106" font-size="54" font-weight="800" fill="$BLU0" letter-spacing="3" filter="url(#bigglow)">ALEX SCHNELL</text>
  </g></g>
  <rect x="0" y="56" width="3" height="60" fill="$CYN" filter="url(#glow)" opacity="0">
    <animate attributeName="x" dur="$DUR" repeatCount="indefinite" values="$($X0 - 10);$($X0 - 10);$($X0 - 10 + $wipe);$($X0 - 10 + $wipe)" keyTimes="0;$(KT $d0);$(KT $d1);1"/>
    <animate attributeName="opacity" dur="$DUR" repeatCount="indefinite" calcMode="discrete" values="0;1;0" keyTimes="0;$(KT $d0);$(KT $d1)"/>
  </rect>
  <text x="948" y="98" text-anchor="end" font-size="14" fill="$YEL" letter-spacing="1">&#127809; ONTARIO, CANADA</text>

  <!-- session -->
  <g fill="$WHT">
    <animate attributeName="opacity" dur="$DUR" repeatCount="indefinite" values="1;1;0;0" keyTimes="0;$(KT ($LOOP - 0.9));$(KT ($LOOP - 0.3));1"/>
$($script:body)    $cursorSvg
  </g>
  $flash

  <!-- status line -->
  <line x1="40" y1="432" x2="960" y2="432" stroke="#1a2f55"/>
  <rect x="$($X0 - 3)" y="440" width="60" height="16" fill="$LBL"/>
  <text x="$($X0 + 1)" y="452" font-size="13" font-weight="700" fill="#060a14">STATUS</text>
  $status
  $statusAb
  <text x="948" y="452" text-anchor="end" font-size="13" fill="$LBL" xml:space="preserve">&#127809;  DATE $julian</text>

  <!-- crt effects -->
  <rect x="16" y="16" width="968" height="448" fill="url(#scan)" pointer-events="none"/>
  <rect x="16" y="0" width="968" height="120" fill="url(#band)"><animate attributeName="y" from="-120" to="480" dur="5s" repeatCount="indefinite"/></rect>
  <rect x="16" y="16" width="968" height="448" fill="url(#vig)"/>
</g>
</svg>
"@

# ---------------- resolve timing tokens ----------------
foreach ($k in $script:sceneEnd.Keys) { $svg = $svg.Replace("{{$k}}", "{{T:$(F $script:sceneEnd[$k])}}") }
$svg = [regex]::Replace($svg, '\{\{T:([0-9.]+)\}\}', { param($m) F ([math]::Min([double]1.0, [math]::Max([double]0.0, [double]$m.Groups[1].Value / $LOOP))) })
$svg = $svg.Replace('{{DUR}}', "${LOOP}s")
if ($svg -match '\{\{') { throw 'unresolved timing token' }

# ---------------- write (content-hashed name: GitHub caches README images by URL) ----------------
$bytes = (New-Object Text.UTF8Encoding $false).GetBytes($svg)
$hash = -join ([Security.Cryptography.SHA256]::Create().ComputeHash($bytes)[0..3] | ForEach-Object { $_.ToString('x2') })
Get-ChildItem $PSScriptRoot -Filter '*header*.svg' | Remove-Item
$name = "header-$hash.svg"
$out = Join-Path $PSScriptRoot $name
[IO.File]::WriteAllBytes($out, $bytes)
$readme = Join-Path $PSScriptRoot 'README.md'
$md = [IO.File]::ReadAllText($readme) -replace 'src="\./[^"]*\.svg"', "src=`"./$name`""
[IO.File]::WriteAllText($readme, $md, (New-Object Text.UTF8Encoding $false))
"wrote $out  ($([math]::Round($bytes.Length / 1KB, 1)) KB, loop ${LOOP}s, job $jobNo, date $julian, contributions $contrib, uptime $uptime)"

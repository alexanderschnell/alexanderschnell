# Generates header.svg - an animated IBM 3270 / TSO mainframe-terminal GitHub profile header.
# Pure SVG + SMIL + CSS (no JS), so it animates inside GitHub READMEs.
# Run:  powershell -ExecutionPolicy Bypass -File build-header.ps1
# NOTE: PowerShell variable names are case-insensitive ($t == $T) - keep names distinct.

[System.Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
$ErrorActionPreference = 'Stop'

# ---------------- config ----------------
$LOOP     = 18.0      # full loop length (s)
$X0       = 52        # left text margin
$Y0       = 162       # first terminal line baseline
$LH       = 25        # line height
$FS       = 17        # terminal font size
$ADV      = 10.2      # monospace advance (0.6em) - every char is placed explicitly
$CMD_CPS  = 0.07      # seconds per typed char
$OUT_CPS  = 0.010     # seconds per system-output char
$FONT     = "'IBM Plex Mono','JetBrains Mono','Cascadia Code',Consolas,'Courier New',monospace"

# classic 3270 palette
$GRN = '#3d8bff'; $TRQ = '#5ad1ff'; $WHT = '#f2f2f2'; $YEL = '#fff35c'
$BLU = '#7aa2ff'; $PNK = '#ff79c6'; $RED = '#ff4b4b'; $DIM = '#2a4f8a'

# ---------------- helpers ----------------
function F($n) { '{0:0.####}' -f $n }
function KT($tm) { F ([math]::Min([double]1.0, [math]::Max([double]0.0, [double]$tm / $LOOP))) }
function Esc($s) { $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;') }

# Builds a <text> with explicit per-char x so layout is font-independent.
function Line-Text($segments, $ly) {
    $chars = 0; $spans = ''
    foreach ($s in $segments) { $spans += "<tspan fill=`"$($s[1])`">$(Esc $s[0])</tspan>"; $chars += $s[0].Length }
    $xs = (0..($chars - 1) | ForEach-Object { F ($X0 + $_ * $ADV) }) -join ' '
    "<text x=`"$xs`" y=`"$ly`" xml:space=`"preserve`">$spans</text>"
}

$script:cursor = New-Object System.Collections.ArrayList   # (time, x, y)
$script:defs = ''; $script:body = ''; $script:clipId = 0
function Cur($tm, $cxp, $cyp) { [void]$script:cursor.Add(@($tm, $cxp, $cyp)) }

# Discrete clip reveal: chars appear one by one starting at time t0. Returns end time.
function Reveal($segments, $ly, $t0, $cps, [switch]$NoCursor) {
    $total = ($segments | ForEach-Object { $_[0].Length } | Measure-Object -Sum).Sum
    $id = "c$($script:clipId)"; $script:clipId++
    $vals = @('0'); $kts = @('0'); $tm = $t0
    for ($n = 1; $n -le $total; $n++) {
        $vals += F ($n * $ADV + 2); $kts += KT $tm
        Cur $tm ($X0 + $n * $ADV) $ly
        if ($n -lt $total) { $tm += $cps }
    }
    $vals += '0'; $kts += KT ($LOOP - 0.05)
    $script:defs += "<clipPath id=`"$id`"><rect x=`"$($X0 - 2)`" y=`"$($ly - 20)`" width=`"0`" height=`"27`"><animate attributeName=`"width`" dur=`"${LOOP}s`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"$($vals -join ';')`" keyTimes=`"$($kts -join ';')`"/></rect></clipPath>`n"
    $script:body += "<g clip-path=`"url(#$id)`">$(Line-Text $segments $ly)</g>`n"
    return $tm
}
function Show-Window($ta, $tb = $LOOP - 0.05) {
    "<animate attributeName=`"opacity`" dur=`"${LOOP}s`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"0;1;0`" keyTimes=`"0;$(KT $ta);$(KT $tb)`"/>"
}

# ---------------- the TSO session ----------------
$tm = 0.6; $ly = $Y0

# READY, then the user types a SUBMIT for their JCL
$tm = Reveal @(,@('READY', $WHT)) $ly $tm 0.001 -NoCursor; $ly += $LH
Cur $tm $X0 $ly; $tm += 0.7
$tm = Reveal @(@('SUBMIT ', $GRN), @("'ALEX.JCL(PROFILE)'", $TRQ)) $ly $tm $CMD_CPS; $tm += 0.5; $ly += $LH
$tm = Reveal @(@('IKJ56250I ', $GRN), @('JOB ALEXPROF(JOB04521) SUBMITTED', $GRN)) $ly $tm $OUT_CPS -NoCursor; $tm += 0.4; $ly += $LH

# job running: step label + progress bar
$label = 'STEP01   EXEC PGM=PROFILE'
$tm = Reveal @(,@($label, $BLU)) $ly $tm $OUT_CPS -NoCursor; $tm += 0.15
$bx = $X0 + ($label.Length + 2) * $ADV; $bw = 300; $pt0 = $tm; $pdur = 1.9
$script:body += "<g opacity=`"0`">$(Show-Window $tm)" +
    "<rect x=`"$bx`" y=`"$($ly - 14)`" width=`"$bw`" height=`"17`" fill=`"none`" stroke=`"$DIM`" stroke-width=`"1.3`"/>" +
    "<rect x=`"$($bx + 3)`" y=`"$($ly - 11)`" width=`"0`" height=`"11`" fill=`"url(#bar)`" filter=`"url(#glow)`"><animate attributeName=`"width`" dur=`"${LOOP}s`" repeatCount=`"indefinite`" values=`"0;0;$($bw - 6);$($bw - 6);0`" keyTimes=`"0;$(KT $tm);$(KT ($tm + $pdur));$(KT ($LOOP - 0.05));1`" calcMode=`"spline`" keySplines=`"0 0 1 1;.4 0 .2 1;0 0 1 1;0 0 1 1`"/></rect></g>`n"
for ($p = 0; $p -le 10; $p++) {
    $ta = $pt0 + $pdur * $p / 10
    $tb = if ($p -lt 10) { $pt0 + $pdur * ($p + 1) / 10 } else { $LOOP - 0.05 }
    $script:body += "<text x=`"$($bx + $bw + 14)`" y=`"$ly`" fill=`"$GRN`" opacity=`"0`">$(Show-Window $ta $tb)$($p * 10)%</text>`n"
}
$tm += $pdur + 0.3; $ly += $LH

# JES: job ended, condition code 0
$tm = Reveal @(@('$HASP165 ALEXPROF ENDED AT N1  ', $GRN), @('MAXCC=0000', $YEL)) $ly $tm $OUT_CPS -NoCursor; $tm += 0.6; $ly += $LH

# SYSOUT from the COBOL program
$tm = Reveal @(@('NAME  ===> ', $TRQ), @('ALEX SCHNELL', $YEL)) $ly $tm 0.02 -NoCursor; $tm += 0.35; $ly += $LH
$tm = Reveal @(@('ROLE  ===> ', $TRQ), @('FSWEP MAINFRAME DEVELOPER', $WHT), @(' @ EMPLOYMENT AND SOCIAL DEVELOPMENT CANADA', $GRN)) $ly $tm $OUT_CPS -NoCursor; $tm += 0.35; $ly += $LH
$tm = Reveal @(@('STUDY ===> ', $TRQ), @('COMPUTER ENGINEERING TECHNOLOGY - COMPUTING SCIENCE', $WHT)) $ly $tm $OUT_CPS -NoCursor; $tm += 0.35; $ly += $LH
$tm = Reveal @(,@('STACK ===> ', $TRQ)) $ly $tm $OUT_CPS -NoCursor; $tm += 0.1

# language chips pop in one by one
$chips = @( @('COBOL','#ff79c6'), @('JCL','#5ad1ff'), @('JAVA','#f0a040'), @('C','#a8b9cc'), @('PHP','#8892f0'), @('JAVASCRIPT','#fff35c'), @('CSS','#b07cff') )
$cx = $X0 + 11 * $ADV
foreach ($c in $chips) {
    $cw = $c[0].Length * 8.6 + 30
    $script:body += "<g opacity=`"0`">$(Show-Window $tm)<animateTransform attributeName=`"transform`" type=`"translate`" dur=`"${LOOP}s`" repeatCount=`"indefinite`" values=`"0 8;0 8;0 0;0 0`" keyTimes=`"0;$(KT $tm);$(KT ($tm + 0.22));1`"/>" +
        "<rect x=`"$cx`" y=`"$($ly - 16)`" width=`"$cw`" height=`"21`" rx=`"3`" fill=`"$($c[1])`" fill-opacity=`"0.14`" stroke=`"$($c[1])`" stroke-width=`"1.3`"/>" +
        "<circle cx=`"$($cx + 11)`" cy=`"$($ly - 5.5)`" r=`"3.5`" fill=`"$($c[1])`"/>" +
        "<text x=`"$($cx + 20)`" y=`"$ly`" font-size=`"14`" font-weight=`"700`" fill=`"$($c[1])`">$($c[0])</text></g>`n"
    Cur $tm ($cx + $cw + 8) $ly
    $cx += $cw + 9; $tm += 0.17
}
$tm += 0.5; $ly += $LH

# back to READY, cursor waits on the next line
$tm = Reveal @(,@('READY', $WHT)) $ly $tm 0.001 -NoCursor; $ly += $LH
Cur $tm $X0 $ly
$tEnd = $tm
if ($tEnd -gt $LOOP - 1.5) { throw "Timeline ($tEnd s) exceeds loop length; raise `$LOOP." }

# ---------------- cursor ----------------
$cv = @(); $ck = @(); $cyv = @()
$first = $script:cursor[0]
$cv += F $first[1]; $cyv += F ($first[2] - 15); $ck += '0'
foreach ($c in $script:cursor) { $cv += F $c[1]; $cyv += F ($c[2] - 15); $ck += KT $c[0] }
$cursorSvg = "<g class=`"blink`" opacity=`"0`"><animate attributeName=`"opacity`" dur=`"${LOOP}s`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"0;1`" keyTimes=`"0;$(KT $first[0])`"/><rect width=`"10`" height=`"19`" fill=`"$GRN`" filter=`"url(#glow)`">" +
  "<animate attributeName=`"x`" dur=`"${LOOP}s`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"$($cv -join ';')`" keyTimes=`"$($ck -join ';')`"/>" +
  "<animate attributeName=`"y`" dur=`"${LOOP}s`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"$($cyv -join ';')`" keyTimes=`"$($ck -join ';')`"/></rect></g>"

# ---------------- assemble ----------------
$SW = 1000; $SH = 480
$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $SW $SH" width="$SW" height="$SH" font-family="$FONT" font-size="$FS" role="img" aria-label="Alex Schnell - FSWEP Mainframe Developer at Employment and Social Development Canada, writing COBOL and JCL on the mainframe through the Asgard terminal. Also Java, C, PHP, JavaScript, CSS.">
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
  <linearGradient id="band" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="$GRN" stop-opacity="0"/><stop offset=".5" stop-color="$GRN" stop-opacity=".07"/><stop offset="1" stop-color="$GRN" stop-opacity="0"/></linearGradient>
  <pattern id="scan" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="4" height="1.4" fill="#000" fill-opacity=".35"/></pattern>
  <clipPath id="win"><rect x="16" y="16" width="968" height="448" rx="14"/></clipPath>
$($script:defs)</defs>

<!-- window -->
<rect x="16" y="16" width="968" height="448" rx="14" fill="url(#bg)" stroke="#1a2f55" stroke-width="1.5"/>
<g clip-path="url(#win)">
  <rect x="16" y="16" width="968" height="38" fill="#0a1020"/>
  <line x1="16" y1="54" x2="984" y2="54" stroke="#1a2f55"/>
  <circle cx="44" cy="35" r="6.5" fill="#ff5f57"/><circle cx="66" cy="35" r="6.5" fill="#febc2e"/><circle cx="88" cy="35" r="6.5" fill="#3d8bff"/>
  <text x="500" y="40" text-anchor="middle" font-size="13" fill="#6f8fbf">ASGARD  -  SESSION A</text>
  <circle class="dot" cx="890" cy="35" r="4" fill="$GRN" filter="url(#glow)"/>
  <text x="900" y="40" font-size="12" fill="$GRN" letter-spacing="1">ONLINE</text>

  <!-- title -->
  <g class="flicker">
    <text class="ga" x="$X0" y="106" font-size="54" font-weight="800" fill="#ff2e63" letter-spacing="3">ALEX SCHNELL</text>
    <text class="gb" x="$X0" y="106" font-size="54" font-weight="800" fill="#00e5ff" letter-spacing="3">ALEX SCHNELL</text>
    <text x="$X0" y="106" font-size="54" font-weight="800" fill="$GRN" letter-spacing="3" filter="url(#bigglow)">ALEX SCHNELL</text>
  </g>
  <text x="$($X0 + 2)" y="131" font-size="14" fill="$DIM" letter-spacing="2.5">// COBOL  &#183;  JCL  &#183;  ASGARD TERMINAL  &#183;  JAVA  &#183;  C  &#183;  WEB</text>
  <text x="948" y="104" text-anchor="end" font-size="13" fill="$BLU">TSO / JES2</text>
  <text x="948" y="122" text-anchor="end" font-size="13" fill="$YEL">CANADA</text>

  <!-- session -->
  <g fill="$WHT">
    <animate attributeName="opacity" dur="${LOOP}s" repeatCount="indefinite" values="1;1;0;0" keyTimes="0;$(KT ($LOOP - 0.9));$(KT ($LOOP - 0.3));1"/>
$($script:body)    $cursorSvg
  </g>

  <!-- 3270 operator information area -->
  <line x1="40" y1="432" x2="960" y2="432" stroke="#1a2f55"/>
  <rect x="$($X0 - 3)" y="440" width="24" height="16" fill="$BLU"/>
  <text x="$($X0 + 1)" y="452" font-size="13" font-weight="700" fill="#060a14">4A</text>
  <text x="$($X0 + 34)" y="452" font-size="13" fill="$BLU" xml:space="preserve">|  CONNECTED  |  SYSTEM AVAILABLE</text>
  <text x="948" y="452" text-anchor="end" font-size="13" fill="$BLU">MAXCC=0000   024/001</text>

  <!-- crt effects -->
  <rect x="16" y="16" width="968" height="448" fill="url(#scan)" pointer-events="none"/>
  <rect x="16" y="0" width="968" height="120" fill="url(#band)"><animate attributeName="y" from="-120" to="480" dur="5s" repeatCount="indefinite"/></rect>
  <rect x="16" y="16" width="968" height="448" fill="url(#vig)"/>
</g>
</svg>
"@

$out = Join-Path $PSScriptRoot 'terminal-header.svg'
[IO.File]::WriteAllText($out, $svg, (New-Object Text.UTF8Encoding $false))
"wrote $out  ($([math]::Round((Get-Item $out).Length / 1KB, 1)) KB, timeline ends at $([math]::Round($tEnd,2))s of ${LOOP}s)"

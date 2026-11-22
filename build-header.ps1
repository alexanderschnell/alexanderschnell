# Generates header.svg - an animated mainframe-terminal GitHub profile header.
# Pure SVG + SMIL + CSS (no JS), so it animates inside GitHub READMEs.
# Run:  powershell -ExecutionPolicy Bypass -File build-header.ps1

[System.Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::InvariantCulture
$ErrorActionPreference = 'Stop'

# ---------------- config ----------------
$LOOP        = 17.0      # full loop length (s)
$X0       = 52        # left text margin
$Y0       = 172       # first terminal line baseline
$LH       = 29        # line height
$FS       = 17        # terminal font size
$ADV      = 10.2      # monospace advance (0.6em) - every char is placed explicitly
$CMD_CPS  = 0.072     # seconds per typed command char
$OUT_CPS  = 0.012     # seconds per output char
$FONT     = "'JetBrains Mono','Fira Code','Cascadia Code',Consolas,'Courier New',monospace"
$PROMPT   = @( @('alex@esdc','#4af626'), @(':','#9fb3a3'), @('~','#00e5ff'), @('$ ','#9fb3a3') )

$G   = '#4af626'; $DIM = '#2f8f3a'; $AMB = '#ffb000'; $TXT = '#c8f7c5'

# ---------------- helpers ----------------
function F($n) { '{0:0.####}' -f $n }
function KT($t) { F ([math]::Min([double]1.0, [math]::Max([double]0.0, [double]$t / $LOOP))) }
function Esc($s) { $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;') }

# Builds a <text> with explicit per-char x so layout is font-independent.
function Line-Text($segments, $y, $extra = '') {
    $chars = 0; $spans = ''
    foreach ($s in $segments) { $spans += "<tspan fill=`"$($s[1])`">$(Esc $s[0])</tspan>"; $chars += $s[0].Length }
    $xs = (0..($chars - 1) | ForEach-Object { F ($X0 + $_ * $ADV) }) -join ' '
    "<text x=`"$xs`" y=`"$y`" xml:space=`"preserve`" $extra>$spans</text>"
}

# Discrete clip reveal: chars appear one by one from startChars at time t0.
$script:cursor = New-Object System.Collections.ArrayList   # (time, x, y)
$script:defs = ''; $script:body = ''; $script:clipId = 0
function Reveal($segments, $y, $t0, $startChars, $cps) {
    $total = ($segments | ForEach-Object { $_[0].Length } | Measure-Object -Sum).Sum
    $id = "c$($script:clipId)"; $script:clipId++
    $vals = @('0'); $kts = @('0'); $t = $t0
    for ($n = $startChars; $n -le $total; $n++) {
        $vals += F ($n * $ADV + 2); $kts += KT $t
        [void]$script:cursor.Add(@($t, ($X0 + $n * $ADV), $y))
        if ($n -lt $total) { $t += $cps }
    }
    $vals += '0'; $kts += KT ($LOOP - 0.05)
    $script:defs += "<clipPath id=`"$id`"><rect x=`"$($X0 - 2)`" y=`"$($y - 20)`" width=`"0`" height=`"28`"><animate attributeName=`"width`" dur=`"${LOOP}s`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"$($vals -join ';')`" keyTimes=`"$($kts -join ';')`"/></rect></clipPath>`n"
    $script:body += "<g clip-path=`"url(#$id)`">$(Line-Text $segments $y)</g>`n"
    return $t
}
function Show-Window($t0, $t1 = $LOOP - 0.05) {   # discrete visibility window -> animate tag
    "<animate attributeName=`"opacity`" dur=`"${LOOP}s`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"0;1;0`" keyTimes=`"0;$(KT $t0);$(KT $t1)`"/>"
}

# ---------------- script of the terminal session ----------------
$t = 0.7; $y = $Y0; $pl = 13   # prompt length

$t = Reveal ($PROMPT + ,@('whoami', $TXT)) $y $t $pl $CMD_CPS;               $t += 0.35; $y += $LH
$t = Reveal @(@('Alex Schnell', $AMB), @('  //  Computer Engineering Technology - Computing Science', $TXT)) $y $t 0 $OUT_CPS; $t += 0.6; $y += $LH

$t = Reveal ($PROMPT + ,@('cat role.txt', $TXT)) $y $t $pl $CMD_CPS;         $t += 0.35; $y += $LH
$t = Reveal @(@('FSWEP Mainframe Developer', $G), @(' @ ', $DIM), @('Employment and Social Development Canada', $TXT)) $y $t 0 $OUT_CPS; $t += 0.6; $y += $LH

$t = Reveal ($PROMPT + ,@('ls ./stack', $TXT)) $y $t $pl $CMD_CPS;           $t += 0.3; $y += $LH
# language chips pop in one by one
$chips = @( @('mainframe','#0f62fe'), @('java','#b07219'), @('c','#7f8ea3'), @('php','#4F5D95'), @('javascript','#c9b400'), @('css','#663399') )
$cx = $X0
foreach ($c in $chips) {
    $w = $c[0].Length * 8.4 + 30
    $script:body += "<g opacity=`"0`">$(Show-Window $t)<animateTransform attributeName=`"transform`" type=`"translate`" dur=`"${LOOP}s`" repeatCount=`"indefinite`" values=`"0 8;0 8;0 0;0 0`" keyTimes=`"0;$(KT $t);$(KT ($t + 0.22));1`"/>" +
        "<rect x=`"$cx`" y=`"$($y - 17)`" width=`"$w`" height=`"23`" rx=`"5`" fill=`"$($c[1])`" fill-opacity=`"0.18`" stroke=`"$($c[1])`" stroke-width=`"1.3`"/>" +
        "<circle cx=`"$($cx + 11)`" cy=`"$($y - 5.5)`" r=`"3.5`" fill=`"$($c[1])`"/>" +
        "<text x=`"$($cx + 20)`" y=`"$y`" font-size=`"14`" fill=`"$TXT`">$($c[0])</text></g>`n"
    [void]$script:cursor.Add(@($t, ($cx + $w + 8), $y))
    $cx += $w + 10; $t += 0.18
}
$t += 0.5; $y += $LH

$t = Reveal ($PROMPT + ,@('./deploy --from=mainframe --to=web', $TXT)) $y $t $pl $CMD_CPS; $t += 0.35; $y += $LH
# progress bar
$bx = $X0; $bw = 360; $pt0 = $t; $pdur = 1.9
$script:body += "<g opacity=`"0`">$(Show-Window $t)" +
    "<rect x=`"$bx`" y=`"$($y - 15)`" width=`"$bw`" height=`"18`" rx=`"3`" fill=`"none`" stroke=`"$DIM`" stroke-width=`"1.3`"/>" +
    "<rect x=`"$($bx + 3)`" y=`"$($y - 12)`" width=`"0`" height=`"12`" rx=`"2`" fill=`"url(#bar)`" filter=`"url(#glow)`"><animate attributeName=`"width`" dur=`"${LOOP}s`" repeatCount=`"indefinite`" values=`"0;0;$($bw - 6);$($bw - 6);0`" keyTimes=`"0;$(KT $t);$(KT ($t + $pdur));$(KT ($LOOP - 0.05));1`" calcMode=`"spline`" keySplines=`"0 0 1 1;.4 0 .2 1;0 0 1 1;0 0 1 1`"/></rect></g>`n"
for ($p = 0; $p -le 10; $p++) {
    $ta = $pt0 + $pdur * $p / 10
    $tb = if ($p -lt 10) { $pt0 + $pdur * ($p + 1) / 10 } else { $LOOP - 0.05 }
    $script:body += "<text x=`"$($bx + $bw + 14)`" y=`"$y`" fill=`"$G`" opacity=`"0`">$(Show-Window $ta $tb)$($p * 10)%</text>`n"
}
[void]$script:cursor.Add(@($t, ($bx + $bw + 64), $y))
$t += $pdur + 0.15
$okX = $bx + $bw + 70
$script:body += "<text x=`"$okX`" y=`"$y`" opacity=`"0`">$(Show-Window $t)<tspan fill=`"$G`" font-weight=`"700`">[ OK ]</tspan><tspan fill=`"$TXT`"> shipped. ready for what's next.</tspan></text>`n"
[void]$script:cursor.Add(@($t, ($okX + 40 * $ADV - 10), $y))
$t += 0.5; $y += $LH

# final idle prompt
$t = Reveal $PROMPT $y $t $pl $CMD_CPS
$tEnd = $t
if ($tEnd -gt $LOOP - 1.5) { throw "Timeline ($tEnd s) exceeds loop length; raise `$LOOP." }

# ---------------- cursor ----------------
$cv = @(); $ck = @(); $cyv = @()
$first = $script:cursor[0]
$cv += F $first[1]; $cyv += F ($first[2] - 15); $ck += '0'
foreach ($c in $script:cursor) { $cv += F $c[1]; $cyv += F ($c[2] - 15); $ck += KT $c[0] }
# dedupe identical keyTimes (keep last)
$cur = "<g class=`"blink`"><rect width=`"10`" height=`"19`" fill=`"$G`" filter=`"url(#glow)`">" +
  "<animate attributeName=`"x`" dur=`"${LOOP}s`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"$($cv -join ';')`" keyTimes=`"$($ck -join ';')`"/>" +
  "<animate attributeName=`"y`" dur=`"${LOOP}s`" repeatCount=`"indefinite`" calcMode=`"discrete`" values=`"$($cyv -join ';')`" keyTimes=`"$($ck -join ';')`"/></rect></g>"

# ---------------- assemble ----------------
$W = 1000; $H = 470
$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $W $H" width="$W" height="$H" font-family="$FONT" font-size="$FS" role="img" aria-label="Alex Schnell - FSWEP Mainframe Developer at ESDC. Computer Engineering Technology student. Stack: mainframe, Java, C, PHP, JavaScript, CSS.">
<title>Alex Schnell - mainframe to web</title>
<style>
  .blink { animation: blink 1s steps(1) infinite; }
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
  <linearGradient id="bar" x1="0" x2="1"><stop offset="0" stop-color="#1fae2e"/><stop offset="1" stop-color="#7dff5a"/></linearGradient>
  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#07130b"/><stop offset="1" stop-color="#030805"/></linearGradient>
  <radialGradient id="vig" cx=".5" cy=".45" r=".75"><stop offset=".6" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".55"/></radialGradient>
  <linearGradient id="band" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="$G" stop-opacity="0"/><stop offset=".5" stop-color="$G" stop-opacity=".07"/><stop offset="1" stop-color="$G" stop-opacity="0"/></linearGradient>
  <pattern id="scan" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="4" height="1.4" fill="#000" fill-opacity=".35"/></pattern>
  <clipPath id="win"><rect x="16" y="16" width="968" height="438" rx="14"/></clipPath>
$($script:defs)</defs>

<!-- window -->
<rect x="16" y="16" width="968" height="438" rx="14" fill="url(#bg)" stroke="#1d4d26" stroke-width="1.5"/>
<g clip-path="url(#win)">
  <rect x="16" y="16" width="968" height="38" fill="#0c1f12"/>
  <line x1="16" y1="54" x2="984" y2="54" stroke="#1d4d26"/>
  <circle cx="44" cy="35" r="6.5" fill="#ff5f57"/><circle cx="66" cy="35" r="6.5" fill="#febc2e"/><circle cx="88" cy="35" r="6.5" fill="#28c840"/>
  <text x="500" y="40" text-anchor="middle" font-size="13" fill="#6fae78">alex@esdc: ~  -  tn3270  -  80x24</text>
  <circle class="dot" cx="902" cy="35" r="4" fill="$G" filter="url(#glow)"/>
  <text x="912" y="40" font-size="12" fill="$G" letter-spacing="1">ONLINE</text>

  <!-- title -->
  <g class="flicker">
    <text class="ga" x="$X0" y="114" font-size="54" font-weight="800" fill="#ff2e63" letter-spacing="3">ALEX SCHNELL</text>
    <text class="gb" x="$X0" y="114" font-size="54" font-weight="800" fill="#00e5ff" letter-spacing="3">ALEX SCHNELL</text>
    <text x="$X0" y="114" font-size="54" font-weight="800" fill="$G" letter-spacing="3" filter="url(#bigglow)">ALEX SCHNELL</text>
  </g>
  <text x="$($X0 + 2)" y="140" font-size="14" fill="$DIM" letter-spacing="2.5">// MAINFRAME  &#183;  JAVA  &#183;  C  &#183;  WEB  -  FROM BATCH JOBS TO BROWSERS</text>
  <text x="948" y="114" text-anchor="end" font-size="13" fill="$DIM" xml:space="preserve">SYS1  READY</text>
  <text x="948" y="132" text-anchor="end" font-size="13" fill="$AMB" xml:space="preserve">CANADA</text>

  <!-- session -->
  <g fill="$TXT">
    <animate attributeName="opacity" dur="${LOOP}s" repeatCount="indefinite" values="1;1;0;0" keyTimes="0;$(KT ($LOOP - 0.9));$(KT ($LOOP - 0.3));1"/>
$($script:body)    $cur
  </g>

  <!-- crt effects -->
  <rect x="16" y="16" width="968" height="438" fill="url(#scan)" pointer-events="none"/>
  <rect x="16" y="0" width="968" height="120" fill="url(#band)"><animate attributeName="y" from="-120" to="470" dur="5s" repeatCount="indefinite"/></rect>
  <rect x="16" y="16" width="968" height="438" fill="url(#vig)"/>
</g>
</svg>
"@

$out = Join-Path $PSScriptRoot 'header.svg'
[IO.File]::WriteAllText($out, $svg, (New-Object Text.UTF8Encoding $false))
"wrote $out  ($([math]::Round((Get-Item $out).Length / 1KB, 1)) KB, timeline ends at $([math]::Round($tEnd,2))s of ${LOOP}s)"

# =====================================================================
#   AKENETIC TERMINAL  -  terminal de comandos colorido para o pendrive
#   Abra pelo arquivo "ABRIR TERMINAL.bat" na raiz do pendrive.
# =====================================================================

try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
$Raw = $Host.UI.RawUI
$Raw.WindowTitle     = 'AKENETIC TERMINAL'
$Raw.BackgroundColor = 'Black'
$Raw.ForegroundColor = 'Gray'
try {
    if ([Console]::BufferWidth -lt 110) { [Console]::BufferWidth = 110 }
    [Console]::SetWindowSize(110, 35)
} catch {}

$Root       = $PSScriptRoot
$Drive      = Split-Path -Qualifier $Root
$NotesFile  = Join-Path $Root 'notas.txt'
$ConfigFile = Join-Path $Root 'config.txt'
# a edicao premium e liberada pelo arquivo premium.key, que o 'compartilhar' nunca copia
$IsPremium  = Test-Path -LiteralPath (Join-Path $Root 'premium.key')
$Version    = '1.5'
# de onde o comando 'atualizar' baixa a versao nova (publicada pelo 'site publicar' do premium)
$SiteBase   = 'https://akimisttemperor.github.io/akenetic/'
$UpdateBase = "$($SiteBase)pc/"
$Rnd        = New-Object Random
$script:SoundOn = $true
$script:History = New-Object System.Collections.Generic.List[string]

# ----------------------------------------------------------------- temas
$Themes = @{
    verde    = @{ P='Green';   S='DarkGreen';   A='Cyan';   T='Gray'; G=@('White','Green','Green','DarkGreen','DarkGreen','DarkGray') }
    azul     = @{ P='Cyan';    S='DarkCyan';    A='Yellow'; T='Gray'; G=@('White','Cyan','Cyan','DarkCyan','Blue','DarkBlue') }
    roxo     = @{ P='Magenta'; S='DarkMagenta'; A='Cyan';   T='Gray'; G=@('White','Magenta','Magenta','DarkMagenta','DarkMagenta','DarkBlue') }
    vermelho = @{ P='Red';     S='DarkRed';     A='Yellow'; T='Gray'; G=@('Yellow','Yellow','Red','Red','DarkRed','DarkRed') }
    arcoiris = @{ P='Yellow';  S='Magenta';     A='Cyan';   T='Gray'; G=@('Red','Yellow','Green','Cyan','Blue','Magenta') }
}
if ($IsPremium) {
    $Themes.ouro = @{ P='Yellow'; S='DarkYellow'; A='White'; T='Gray'; G=@('White','Yellow','Yellow','DarkYellow','DarkYellow','DarkRed') }
}
$script:ThemeName = 'verde'
$script:ChatName  = $env:USERNAME
$script:ChatRoom  = ''
$script:AvisoSeen = ''
if (Test-Path $ConfigFile) {
    foreach ($l in Get-Content $ConfigFile -Encoding UTF8) {
        if ($l -match '^tema=(\w+)$' -and $Themes.ContainsKey($Matches[1])) { $script:ThemeName = $Matches[1] }
        if ($l -eq 'som=off') { $script:SoundOn = $false }
        if ($l -match '^nome=(.+)$') { $script:ChatName = $Matches[1] }
        if ($l -match '^sala=(.+)$') { $script:ChatRoom = $Matches[1] }
        if ($l -match '^aviso=(.+)$') { $script:AvisoSeen = $Matches[1] }
    }
}
$script:T = $Themes[$script:ThemeName]

function Save-Config {
    @("tema=$script:ThemeName",
      "som=$(if ($script:SoundOn) {'on'} else {'off'})",
      "nome=$script:ChatName",
      "sala=$script:ChatRoom",
      "aviso=$script:AvisoSeen") | Set-Content $ConfigFile -Encoding UTF8
}

# ----------------------------------------------------------------- sons
function Play([int[]]$notes) {
    if (-not $script:SoundOn) { return }
    for ($i = 0; $i -lt $notes.Count; $i += 2) {
        if ($notes[$i] -eq 0) { Start-Sleep -Milliseconds $notes[$i + 1] }
        else { try { [Console]::Beep($notes[$i], $notes[$i + 1]) } catch {} }
    }
}

function Sfx([string]$name) {
    switch ($name) {
        'enter' { Play 1400,18 }
        'tick'  { Play 2200,10 }
        'ok'    { Play 880,50,1320,70 }
        'err'   { Play 330,110,220,200 }
        'boot'  { Play 523,90,659,90,784,90,1047,220 }
        'bye'   { Play 1047,90,784,90,659,90,523,260 }
        'alarm' { Play 1500,60,1000,60,1500,60,1000,60 }
    }
}

# ----------------------------------------------------------------- utilitarios visuais
function Cursor([bool]$visible) { try { [Console]::CursorVisible = $visible } catch {} }

function Center-Pad([int]$width) {
    try { [math]::Max(0, [int](([Console]::WindowWidth - $width) / 2)) } catch { 2 }
}

function Type-Center([string]$text, $color = $script:T.T, [int]$delay = 12) {
    Write-Host (' ' * (Center-Pad $text.Length)) -NoNewline
    Type-Out $text $color $delay
}

function Type-Out([string]$text, $color = $script:T.T, [int]$delay = 12) {
    foreach ($ch in $text.ToCharArray()) {
        Write-Host $ch -NoNewline -ForegroundColor $color
        if ($ch -ne ' ') { Start-Sleep -Milliseconds $delay }
    }
    Write-Host ''
}

function Bot([string]$msg) {
    Write-Host '  AKENETIC » ' -NoNewline -ForegroundColor $script:T.P
    Type-Out $msg $script:T.T 14
}

function Err([string]$msg) {
    Write-Host '  [!] ' -NoNewline -ForegroundColor Red
    Write-Host $msg -ForegroundColor DarkRed
    Sfx err
}

function Box([string[]]$lines, $color = $script:T.S, $textColor = $script:T.T) {
    $w = ($lines | Measure-Object -Property Length -Maximum).Maximum + 4
    $ind = ' ' * (Center-Pad ($w + 2))
    Write-Host ($ind + '╔' + ('═' * $w) + '╗') -ForegroundColor $color
    foreach ($l in $lines) {
        Write-Host ($ind + '║  ') -NoNewline -ForegroundColor $color
        Write-Host $l.PadRight($w - 2) -NoNewline -ForegroundColor $textColor
        Write-Host '║' -ForegroundColor $color
    }
    Write-Host ($ind + '╚' + ('═' * $w) + '╝') -ForegroundColor $color
}

function Show-Bar([string]$label, [int]$ms = 600, [int]$width = 30) {
    for ($i = 0; $i -le $width; $i++) {
        Write-Host "`r  $($label.PadRight(28))" -NoNewline -ForegroundColor $script:T.T
        Write-Host '[' -NoNewline -ForegroundColor $script:T.S
        Write-Host ('█' * $i) -NoNewline -ForegroundColor $script:T.P
        Write-Host ('░' * ($width - $i)) -NoNewline -ForegroundColor DarkGray
        Write-Host ']' -NoNewline -ForegroundColor $script:T.S
        Write-Host (' {0,3}%' -f [int]($i * 100 / $width)) -NoNewline -ForegroundColor $script:T.A
        Start-Sleep -Milliseconds ([int]($ms / $width))
    }
    Write-Host '  OK' -ForegroundColor Green
    Sfx tick
}

function Spin([string]$label, [int]$ms = 900) {
    $frames = '|', '/', '-', '\'
    $end = (Get-Date).AddMilliseconds($ms); $i = 0
    while ((Get-Date) -lt $end) {
        Write-Host "`r  $($frames[$i % 4]) $label" -NoNewline -ForegroundColor $script:T.A
        Start-Sleep -Milliseconds 80; $i++
    }
    Write-Host "`r  √ $label" -ForegroundColor Green
}

function Meter([string]$label, [double]$used, [double]$total, [string]$unit = 'GB') {
    $pct = 0; if ($total -gt 0) { $pct = $used / $total }
    $n = [int][math]::Round($pct * 30)
    $c = 'Green'; if ($pct -gt 0.85) { $c = 'Red' } elseif ($pct -gt 0.6) { $c = 'Yellow' }
    for ($k = 0; $k -le $n; $k++) {
        Write-Host ("`r  {0,-10}" -f $label) -NoNewline -ForegroundColor $script:T.A
        Write-Host ('█' * $k) -NoNewline -ForegroundColor $c
        Write-Host ('░' * (30 - $k)) -NoNewline -ForegroundColor DarkGray
        Start-Sleep -Milliseconds 12
    }
    Write-Host (' {0:N1}/{1:N1} {2} ({3:P0})' -f $used, $total, $unit, $pct) -ForegroundColor $script:T.T
}

# ----------------------------------------------------------------- banner
$Font = @{
    'A' = @(' █████╗ ', '██╔══██╗', '███████║', '██╔══██║', '██║  ██║', '╚═╝  ╚═╝')
    'K' = @('██╗  ██╗', '██║ ██╔╝', '█████╔╝ ', '██╔═██╗ ', '██║  ██╗', '╚═╝  ╚═╝')
    'E' = @('███████╗', '██╔════╝', '█████╗  ', '██╔══╝  ', '███████╗', '╚══════╝')
    'N' = @('███╗   ██╗', '████╗  ██║', '██╔██╗ ██║', '██║╚██╗██║', '██║ ╚████║', '╚═╝  ╚═══╝')
    'T' = @('████████╗', '╚══██╔══╝', '   ██║   ', '   ██║   ', '   ██║   ', '   ╚═╝   ')
    'I' = @('██╗', '██║', '██║', '██║', '██║', '╚═╝')
    'C' = @(' ██████╗', '██╔════╝', '██║     ', '██║     ', '╚██████╗', ' ╚═════╝')
}

$BannerLines = foreach ($r in 0..5) { ('AKENETIC'.ToCharArray() | ForEach-Object { $Font[[string]$_][$r] }) -join '' }
$BannerWidth = $BannerLines[0].Length

# Banner centralizado. Com -Animated as letras entram da esquerda ondulando,
# a onda vai acalmando ate o nome assentar e um brilho atravessa o texto.
function Show-Banner([switch]$Animated, $colors = $script:T.G) {
    $pad = Center-Pad $BannerWidth
    if (-not $Animated) {
        Write-Host ''
        for ($r = 0; $r -lt 6; $r++) { Write-Host ((' ' * $pad) + $BannerLines[$r]) -ForegroundColor $colors[$r] }
        Write-Host ''
        return
    }
    Cursor $false
    $amp = 2; $H = 6 + 2 * $amp; $frames = 40
    Write-Host ''
    for ($i = 0; $i -lt $H; $i++) { Write-Host '' }
    $top  = [Console]::CursorTop - $H
    $grid = New-Object 'char[][]' $H
    for ($f = 0; $f -le $frames; $f++) {
        $a      = $amp * (1 - $f / $frames)
        $reveal = [int][math]::Min($BannerWidth, $BannerWidth * $f / ($frames * 0.6))
        for ($i = 0; $i -lt $H; $i++) { $grid[$i] = (' ' * $BannerWidth).ToCharArray() }
        for ($x = 0; $x -lt $reveal; $x++) {
            $off = [int][math]::Round($a * [math]::Sin($x * 0.22 - $f * 0.5))
            for ($r = 0; $r -lt 6; $r++) { $grid[$r + $amp + $off][$x] = $BannerLines[$r][$x] }
        }
        for ($i = 0; $i -lt $H; $i++) {
            $ci = [math]::Min(5, [math]::Max(0, $i - $amp))
            [Console]::SetCursorPosition($pad, $top + $i)
            [Console]::ForegroundColor = $colors[$ci]
            [Console]::Write((-join $grid[$i]))
        }
        if ($f % 4 -eq 0) { Play (500 + $f * 25),12 } else { Start-Sleep -Milliseconds 22 }
    }
    for ($s = -6; $s -le $BannerWidth + 6; $s += 3) {
        for ($r = 0; $r -lt 6; $r++) {
            $ln = $BannerLines[$r]
            $a1 = [math]::Max(0, [math]::Min($BannerWidth, $s - 3 + $r))
            $a2 = [math]::Max(0, [math]::Min($BannerWidth, $s + 3 + $r))
            [Console]::SetCursorPosition($pad, $top + $amp + $r)
            [Console]::ForegroundColor = $colors[$r]; [Console]::Write($ln.Substring(0, $a1))
            [Console]::ForegroundColor = 'White';     [Console]::Write($ln.Substring($a1, $a2 - $a1))
            [Console]::ForegroundColor = $colors[$r]; [Console]::Write($ln.Substring($a2))
        }
        Start-Sleep -Milliseconds 15
    }
    Play 1047,40,1568,90
    [Console]::ForegroundColor = 'Gray'
    [Console]::SetCursorPosition(0, $top + $amp + 7)
    Cursor $true
}

function Show-Header([switch]$Animated) {
    Clear-Host
    Show-Banner -Animated:$Animated
    $edition = "v$Version"; if ($IsPremium) { $edition += ' PREMIUM' }
    Box @("AKENETIC TERMINAL $edition  ·  pendrive $Drive  ·  tema: $script:ThemeName",
          "Digite 'ajuda' para ver os comandos. Comandos do CMD tambem funcionam.")
}

# ----------------------------------------------------------------- comandos
$Commands = [ordered]@{
    'ajuda'            = 'mostra esta lista'
    'limpar'           = 'limpa a tela'
    'hora'             = 'data e hora atual'
    'sistema'          = 'informacoes do PC'
    'pendrive'         = 'espaco usado/livre no pendrive'
    'ls  /  cd <pasta>'= 'lista arquivos / muda de pasta'
    'vacina'           = 'protege o pendrive contra virus de atalho'
    'apps [num|nome]'  = 'abre programas portateis da pasta Apps'
    'backup <pasta>'   = 'copia uma pasta do PC pro pendrive'
    'ejetar'           = 'fecha o terminal e ejeta o pendrive'
    'chat'             = 'chat com amigos: arquivos e sala de RPG'
    'compartilhar <E:>'= 'copia o AKENETIC pro pendrive de um amigo'
    'nota <texto>'     = 'salva uma anotacao no pendrive'
    'notas'            = 'mostra suas anotacoes'
    'calc <conta>'     = 'calculadora  (ex: calc 2*(3+4))'
    'dado [lados]'     = 'rola um dado'
    'piada'            = 'conta uma piada'
    'matrix'           = 'chuva de codigo  (qualquer tecla para parar)'
    'hack'             = 'modo hacker de filme'
    'musica'           = 'toca uma musiquinha'
    'tema <nome>'      = 'verde | azul | roxo | vermelho | arcoiris'
    'som on|off'       = 'liga / desliga os sons'
    'historico'        = 'comandos que voce ja digitou'
    'atualizar'        = 'baixa a versao mais nova do AKENETIC'
    'restaurar [arq]'  = 'recupera um backup .aknbak neste pendrive'
    'sair'             = 'fecha o terminal'
}
if ($IsPremium) {
    $Commands.Insert($Commands.Count - 1, 'site', '[PREMIUM] situacao do site do celular')
    $Commands.Insert($Commands.Count - 1, 'site publicar [msg]', '[PREMIUM] envia D:\Celular\index.html pro GitHub')
    $Commands.Insert($Commands.Count - 1, 'site config', '[PREMIUM] configura o token do GitHub')
    $Commands.Insert($Commands.Count - 1, 'site abrir', '[PREMIUM] abre o site no navegador')
    $Commands.Insert($Commands.Count - 1, 'aviso <texto>', '[PREMIUM] aviso geral (aviso 2d texto = vale 2 dias)')
    $Commands.Insert($Commands.Count - 1, 'aviso apagar', '[PREMIUM] tira o aviso do ar')
    $Commands.Insert($Commands.Count - 1, 'backup-premium [pasta]', '[PREMIUM] backup criptografado de tudo')
    $Commands['tema <nome>'] = 'verde | azul | roxo | vermelho | arcoiris | ouro'
}

function Show-Help {
    Write-Host ''
    Write-Host '  ══ COMANDOS ═══════════════════════════════════════════════════' -ForegroundColor $script:T.S
    foreach ($k in $Commands.Keys) {
        Write-Host ('    ' + $k.PadRight(20)) -NoNewline -ForegroundColor $script:T.P
        Write-Host $Commands[$k] -ForegroundColor $script:T.T
        Start-Sleep -Milliseconds 18
    }
    Write-Host '  ═══════════════════════════════════════════════════════════════' -ForegroundColor $script:T.S
    Write-Host '    Qualquer outro comando roda no CMD de verdade (dir, ipconfig, ping...)' -ForegroundColor DarkGray
    Write-Host '    Voce tambem pode conversar: "oi", "tudo bem?", "quem e voce?"' -ForegroundColor DarkGray
}

function Show-System {
    Spin 'Lendo informacoes do sistema...' 700
    $os  = Get-CimInstance Win32_OperatingSystem
    $cpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()
    $up  = (Get-Date) - $os.LastBootUpTime
    $info = [ordered]@{
        'Computador' = $env:COMPUTERNAME
        'Usuario'    = $env:USERNAME
        'Sistema'    = $os.Caption
        'Processador'= $cpu
        'Ligado ha'  = '{0}d {1}h {2}min' -f $up.Days, $up.Hours, $up.Minutes
    }
    Write-Host ''
    foreach ($k in $info.Keys) {
        Write-Host ('  {0,-12}' -f $k) -NoNewline -ForegroundColor $script:T.A
        Write-Host $info[$k] -ForegroundColor $script:T.T
    }
    $total = $os.TotalVisibleMemorySize / 1MB
    Meter 'RAM' ($total - $os.FreePhysicalMemory / 1MB) $total
    Sfx ok
}

function Show-Pendrive {
    $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$Drive'"
    if (-not $d) { Err 'Nao consegui ler o pendrive.'; return }
    Write-Host ''
    Write-Host '  Nome      ' -NoNewline -ForegroundColor $script:T.A; Write-Host $d.VolumeName -ForegroundColor $script:T.T
    Write-Host '  Formato   ' -NoNewline -ForegroundColor $script:T.A; Write-Host $d.FileSystem -ForegroundColor $script:T.T
    Write-Host '  Livre     ' -NoNewline -ForegroundColor $script:T.A; Write-Host ('{0:N2} GB' -f ($d.FreeSpace / 1GB)) -ForegroundColor $script:T.T
    Meter 'Usado' (($d.Size - $d.FreeSpace) / 1GB) ($d.Size / 1GB)
    Sfx ok
}

function Show-Files {
    Write-Host ''
    $items = Get-ChildItem -Force -ErrorAction SilentlyContinue | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::System) }
    if (-not $items) { Write-Host '  (pasta vazia)' -ForegroundColor DarkGray; return }
    foreach ($i in $items) {
        if ($i.PSIsContainer) {
            Write-Host '  [PASTA]  ' -NoNewline -ForegroundColor $script:T.S
            Write-Host $i.Name -ForegroundColor $script:T.A
        } else {
            $size = '{0:N1} KB' -f ($i.Length / 1KB)
            if ($i.Length -ge 1MB) { $size = '{0:N1} MB' -f ($i.Length / 1MB) }
            Write-Host ('  {0,9}  ' -f $size) -NoNewline -ForegroundColor DarkGray
            Write-Host $i.Name -ForegroundColor $script:T.T
        }
        Start-Sleep -Milliseconds 10
    }
}

function Roll-Dice([string]$arg) {
    $sides = 6
    if ($arg -match '^\d+$' -and [int]$arg -ge 2) { $sides = [int]$arg }
    Cursor $false
    for ($i = 0; $i -lt 14; $i++) {
        Write-Host ("`r  Rolando d$sides...  [ {0,3} ]" -f $Rnd.Next(1, $sides + 1)) -NoNewline -ForegroundColor $script:T.S
        Sfx tick
        Start-Sleep -Milliseconds (30 + $i * 12)
    }
    $r = $Rnd.Next(1, $sides + 1)
    Write-Host ("`r  Resultado d${sides}:  [ {0,3} ]   " -f $r) -ForegroundColor $script:T.A
    Cursor $true
    Sfx ok
}

$Jokes = @(
    'Existem 10 tipos de pessoas: as que entendem binario e as que nao entendem.',
    'Qual e o cafe preferido do programador? Java.',
    'Por que o computador foi preso? Porque executou um comando ilegal.',
    'O que o pendrive disse pro PC? "Me tira daqui que eu to sem espaco!"',
    'Qual e a cobra favorita do programador? O Python.',
    'O Wi-Fi caiu. Tive que conversar com minha familia. Parecem pessoas legais.',
    'Meu codigo nao funciona e eu nao sei por que. Meu codigo funciona e eu tambem nao sei por que.',
    'Por que o programador usa oculos? Porque ele nao consegue C#.'
)

function Matrix {
    Clear-Host; Cursor $false
    $w = [Console]::WindowWidth - 1; $h = [Console]::WindowHeight - 1; $top = [Console]::WindowTop
    $glyphs = '0123456789ABCDEFXZ$#@%&*+=<>?:'.ToCharArray()
    $y = New-Object int[] $w; $len = New-Object int[] $w
    for ($x = 0; $x -lt $w; $x++) { $y[$x] = -$Rnd.Next(0, $h * 2); $len[$x] = $Rnd.Next(6, $h) }
    $end = (Get-Date).AddSeconds(30)
    while (-not [Console]::KeyAvailable -and (Get-Date) -lt $end) {
        for ($x = 0; $x -lt $w; $x += 2) {
            $cy = $y[$x]
            if ($cy -ge 0 -and $cy -lt $h) {
                [Console]::SetCursorPosition($x, $top + $cy); [Console]::ForegroundColor = 'White'
                [Console]::Write($glyphs[$Rnd.Next($glyphs.Length)])
            }
            if ($cy - 1 -ge 0 -and $cy - 1 -lt $h) {
                [Console]::SetCursorPosition($x, $top + $cy - 1); [Console]::ForegroundColor = 'Green'
                [Console]::Write($glyphs[$Rnd.Next($glyphs.Length)])
            }
            $my = $cy - [int]($len[$x] / 2)
            if ($my -ge 0 -and $my -lt $h) {
                [Console]::SetCursorPosition($x, $top + $my); [Console]::ForegroundColor = 'DarkGreen'
                [Console]::Write($glyphs[$Rnd.Next($glyphs.Length)])
            }
            $ty = $cy - $len[$x]
            if ($ty -ge 0 -and $ty -lt $h) { [Console]::SetCursorPosition($x, $top + $ty); [Console]::Write(' ') }
            $y[$x]++
            if ($ty -ge $h) { $y[$x] = -$Rnd.Next(0, $h); $len[$x] = $Rnd.Next(6, $h) }
        }
        if ($Rnd.Next(0, 5) -eq 0) { Play ($Rnd.Next(2500, 4000)),8 }
        Start-Sleep -Milliseconds 35
    }
    while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) }
    [Console]::ForegroundColor = 'Gray'
    Show-Header -Animated
}

function Hack {
    Write-Host ''
    Type-Out '  >> Iniciando protocolo de invasao...' 'Green' 18
    Show-Bar 'Quebrando firewall' 700
    Show-Bar 'Descriptografando senhas' 900
    Show-Bar 'Baixando arquivos secretos' 800
    for ($i = 0; $i -lt 28; $i++) {
        $bytes = (1..16 | ForEach-Object { '{0:X2}' -f $Rnd.Next(256) }) -join ' '
        $c = 'Green'; if ($i % 2) { $c = 'DarkGreen' }
        Write-Host ('  0x{0:X8}  {1}' -f $Rnd.Next(), $bytes) -ForegroundColor $c
        if ($i % 3 -eq 0) { Sfx tick }
        Start-Sleep -Milliseconds 25
    }
    Write-Host ''
    Box @('*** ACESSO CONCEDIDO ***') 'Green' 'Green'
    $pos = [Console]::CursorTop - 3
    for ($b = 0; $b -lt 6; $b++) {
        $c = 'Green'; if ($b % 2 -eq 0) { $c = 'DarkGreen' }
        [Console]::SetCursorPosition(0, $pos)
        Box @('*** ACESSO CONCEDIDO ***') $c $c
        Play 1047,70
        Start-Sleep -Milliseconds 90
    }
    Sfx alarm
    Write-Host '  (e brincadeira, nada foi invadido :) )' -ForegroundColor DarkGray
}

function Music {
    if (-not $script:SoundOn) { Err "Os sons estao desligados. Use 'som on'."; return }
    # Korobeiniki (cancao folclorica russa, dominio publico)
    $q = 320; $e = 160
    $song = @(659,$q, 494,$e, 523,$e, 587,$q, 523,$e, 494,$e, 440,$q, 440,$e, 523,$e, 659,$q, 587,$e, 523,$e,
              494,($q+$e), 523,$e, 587,$q, 659,$q, 523,$q, 440,$q, 440,$q)
    $colors = 'Red', 'Yellow', 'Green', 'Cyan', 'Blue', 'Magenta'
    Write-Host ''
    Cursor $false
    for ($i = 0; $i -lt $song.Count; $i += 2) {
        $n = [int](($song[$i] - 400) / 8)
        Write-Host ("`r  ♪ " + ('█' * $n).PadRight(40)) -NoNewline -ForegroundColor $colors[($i / 2) % 6]
        try { [Console]::Beep($song[$i], $song[$i + 1]) } catch {}
    }
    Write-Host ("`r  ♪ fim!".PadRight(46)) -ForegroundColor $script:T.A
    Cursor $true
}

function Set-Theme([string]$name) {
    $name = $name.ToLower() -replace '[ -]', ''
    if (-not $Themes.ContainsKey($name)) { Err "Tema desconhecido. Use: $($Themes.Keys -join ', ')"; return }
    $script:ThemeName = $name; $script:T = $Themes[$name]
    Save-Config
    Show-Header -Animated
}

function Run-Cmd([string]$line) {
    $psi = New-Object Diagnostics.ProcessStartInfo 'cmd.exe'
    $psi.Arguments        = '/d /s /c "' + $line + '"'
    $psi.UseShellExecute  = $false
    $psi.WorkingDirectory = (Get-Location).ProviderPath
    [Console]::ForegroundColor = $script:T.T
    $p = [Diagnostics.Process]::Start($psi)
    $p.WaitForExit()
    [Console]::ForegroundColor = 'Gray'
    if ($p.ExitCode -ne 0) { Sfx err }
}

function Chat([string]$line) {
    $l = $line.ToLower()
    if ($l -match '^(oi|ola|olá|eai|eae|salve|hey|hello|hi|bom dia|boa tarde|boa noite)\b') {
        Bot (@("Ola, $env:USERNAME! Pronto pra digitar uns comandos?", 'Salve! O que vamos fazer hoje?', 'E ai! Digite ajuda se precisar.') | Get-Random); return $true
    }
    if ($l -match 'tudo bem|como vai|como voce esta|como vc ta') { Bot 'Tudo otimo aqui dentro do pendrive! E com voce?'; return $true }
    if ($l -match 'quem (e|é) (voce|você|vc)|seu nome') { Bot 'Sou o AKENETIC, o terminal que mora no seu pendrive.'; return $true }
    if ($l -match 'obrigad|valeu|vlw') { Bot 'Por nada! Tamo junto.'; return $true }
    if ($l -match '^(tchau|flw|falou)') { Bot "Ate mais! Digite 'sair' pra fechar."; return $true }
    return $false
}

# ----------------------------------------------------------------- ferramentas do pendrive
$AppsDir    = "$Drive\Apps"
$BackupsDir = "$Drive\Backups"
$BadExt     = '.lnk', '.vbs', '.vbe', '.js', '.jse', '.wsf', '.wsh', '.scr', '.pif'

function Get-Suspects {
    @(Get-ChildItem -LiteralPath "$Drive\" -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $BadExt -contains $_.Extension.ToLower() -or $_.Name -ieq 'autorun.inf' })
}

# Nada e apagado: suspeitos vao para \Quarentena com a extensao .bloqueado
function Vaccine {
    Write-Host ''
    Spin 'Escaneando o pendrive...' 800
    $root = "$Drive\"; $quar = Join-Path $root 'Quarentena'
    $moved = 0; $shown = 0

    foreach ($f in Get-Suspects) {
        try {
            if (-not (Test-Path -LiteralPath $quar)) { New-Item -ItemType Directory $quar | Out-Null }
            $f.Attributes = 'Normal'
            $dest = Join-Path $quar ($f.Name + '.bloqueado'); $n = 1
            while (Test-Path -LiteralPath $dest) { $dest = Join-Path $quar ('{0}.{1}.bloqueado' -f $f.Name, $n); $n++ }
            Move-Item -LiteralPath $f.FullName $dest -Force -ErrorAction Stop
            Write-Host '  [QUARENTENA] ' -NoNewline -ForegroundColor Red
            Write-Host $f.Name -ForegroundColor Yellow
            $moved++
        } catch { Err "Nao consegui isolar $($f.Name)" }
    }

    $hideMask = [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::System
    Get-ChildItem -LiteralPath $root -Force -Recurse -ErrorAction SilentlyContinue |
        Where-Object { ($_.Attributes -band $hideMask) -and $_.FullName -notmatch '\\(System Volume Information|\$RECYCLE\.BIN|autorun\.inf)(\\|$)' } |
        ForEach-Object {
            try {
                $new = $_.Attributes -band -bnot $hideMask
                if ($new -eq 0) { $new = [IO.FileAttributes]::Normal }
                $_.Attributes = $new
                $shown++
                if ($shown -le 15) {
                    Write-Host '  [REEXIBIDO]  ' -NoNewline -ForegroundColor $script:T.A
                    Write-Host $_.FullName.Substring(3) -ForegroundColor $script:T.T
                }
            } catch {}
        }
    if ($shown -gt 15) { Write-Host "  ... e mais $($shown - 15) itens" -ForegroundColor DarkGray }

    # escudo: uma PASTA autorun.inf protegida impede virus de criar o arquivo
    $shield = Join-Path $root 'autorun.inf'
    if (-not (Test-Path -LiteralPath $shield)) {
        try {
            $d = New-Item -ItemType Directory $shield -ErrorAction Stop
            $d.Attributes = 'Directory, Hidden, System, ReadOnly'
            Write-Host '  [ESCUDO]     ' -NoNewline -ForegroundColor Green
            Write-Host 'protecao contra autorun ativada' -ForegroundColor $script:T.T
        } catch {}
    }

    Write-Host ''
    Box @("Suspeitos isolados : $moved",
          "Itens reexibidos   : $shown",
          'Nada foi apagado. Suspeitos ficam em \Quarentena',
          '(para recuperar um, tire o .bloqueado do nome)')
    if ($moved) { Sfx alarm } else { Bot 'Pendrive limpo!'; Sfx ok }
}

function Get-Apps {
    $skip  = 'unins|uninstall|update|setup|crash|helper|report'
    $files = @(Get-ChildItem -LiteralPath $AppsDir -File -ErrorAction SilentlyContinue)
    foreach ($d in Get-ChildItem -LiteralPath $AppsDir -Directory -ErrorAction SilentlyContinue) {
        $files += @(Get-ChildItem -LiteralPath $d.FullName -File -ErrorAction SilentlyContinue)
    }
    @($files | Where-Object { $_.Extension -match '^\.(exe|bat|cmd)$' -and $_.BaseName -notmatch $skip } | Sort-Object BaseName)
}

function Apps([string]$arg) {
    if (-not (Test-Path -LiteralPath $AppsDir)) { New-Item -ItemType Directory $AppsDir | Out-Null }
    $apps = Get-Apps
    if (-not $apps.Count) {
        Bot "Nenhum app ainda. Coloque programas portateis (.exe) em $AppsDir"
        Write-Host '  Dica: baixe versoes "Portable" (ex: portableapps.com), elas rodam sem instalar.' -ForegroundColor DarkGray
        return
    }
    $pick = 0
    if ($arg -match '^\d+$') { $pick = [int]$arg }
    elseif ($arg) {
        for ($i = 0; $i -lt $apps.Count; $i++) { if ($apps[$i].BaseName -like "*$arg*") { $pick = $i + 1; break } }
        if (-not $pick) { Err "App '$arg' nao encontrado."; return }
    } else {
        Write-Host ''
        for ($i = 0; $i -lt $apps.Count; $i++) {
            Write-Host ('  {0,3}  ' -f ($i + 1)) -NoNewline -ForegroundColor $script:T.A
            Write-Host $apps[$i].BaseName.PadRight(30) -NoNewline -ForegroundColor $script:T.P
            $folder = ''; if ($apps[$i].DirectoryName -ne $AppsDir) { $folder = $apps[$i].Directory.Name }
            Write-Host $folder -ForegroundColor DarkGray
            Start-Sleep -Milliseconds 15
        }
        Write-Host ''
        Write-Host '  Numero para abrir (Enter cancela): ' -NoNewline -ForegroundColor $script:T.S
        $in = [Console]::ReadLine()
        if ($in -notmatch '^\d+$') { return }
        $pick = [int]$in
    }
    if ($pick -lt 1 -or $pick -gt $apps.Count) { Err 'Numero invalido.'; return }
    $app = $apps[$pick - 1]
    Spin "Abrindo $($app.BaseName)..." 600
    try { Start-Process -FilePath $app.FullName -WorkingDirectory $app.DirectoryName -ErrorAction Stop; Sfx ok }
    catch { Err "Nao consegui abrir: $($_.Exception.Message)" }
}

function Backup([string]$arg) {
    if (-not $arg) {
        Bot 'Use: backup <pasta>   atalhos: desktop, documentos, downloads, imagens, musicas, videos'
        if (Test-Path -LiteralPath $BackupsDir) {
            Write-Host ''
            foreach ($pc in Get-ChildItem -LiteralPath $BackupsDir -Directory) {
                foreach ($b in Get-ChildItem -LiteralPath $pc.FullName -Directory) {
                    Write-Host ('  {0,-16}' -f $pc.Name) -NoNewline -ForegroundColor $script:T.A
                    Write-Host $b.Name.PadRight(24) -NoNewline -ForegroundColor $script:T.T
                    Write-Host $b.LastWriteTime.ToString('dd/MM/yyyy HH:mm') -ForegroundColor DarkGray
                }
            }
        }
        return
    }
    $known = @{
        'desktop'          = [Environment]::GetFolderPath('Desktop')
        'area de trabalho' = [Environment]::GetFolderPath('Desktop')
        'documentos'       = [Environment]::GetFolderPath('MyDocuments')
        'downloads'        = Join-Path $env:USERPROFILE 'Downloads'
        'imagens'          = [Environment]::GetFolderPath('MyPictures')
        'musicas'          = [Environment]::GetFolderPath('MyMusic')
        'videos'           = [Environment]::GetFolderPath('MyVideos')
    }
    $src = $arg.Trim('"')
    if ($known.ContainsKey($src)) { $src = $known[$src] }
    if (-not (Test-Path -LiteralPath $src -PathType Container)) { Err "Pasta nao encontrada: $src"; return }
    $src = (Resolve-Path -LiteralPath $src).ProviderPath.TrimEnd('\')
    $leaf = Split-Path $src -Leaf
    if (-not $leaf -or $src.Length -le 3) { Err 'Escolha uma pasta, nao um disco inteiro.'; return }
    if ($src.StartsWith($Drive, [StringComparison]::OrdinalIgnoreCase)) { Err 'Essa pasta ja esta no pendrive.'; return }
    $dest = Join-Path (Join-Path $BackupsDir $env:COMPUTERNAME) $leaf

    Spin 'Comparando arquivos...' 500
    $todo = @(foreach ($f in Get-ChildItem -LiteralPath $src -Recurse -File -Force -ErrorAction SilentlyContinue) {
        $t = Join-Path $dest $f.FullName.Substring($src.Length + 1)
        $e = Get-Item -LiteralPath $t -Force -ErrorAction SilentlyContinue
        # tolerancia de 2s: FAT32/exFAT guardam a hora com menos precisao
        if (-not $e -or $e.Length -ne $f.Length -or ($f.LastWriteTimeUtc - $e.LastWriteTimeUtc).TotalSeconds -gt 2) {
            [pscustomobject]@{ F = $f; T = $t }
        }
    })
    if (-not $todo.Count) { Bot "Tudo ja esta atualizado em $dest"; Sfx ok; return }

    $bytes = [long]($todo | ForEach-Object { $_.F.Length } | Measure-Object -Sum).Sum
    $free  = [long](Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$Drive'").FreeSpace
    if ($bytes -gt $free) { Err ('Falta espaco: precisa de {0:N2} GB, livre {1:N2} GB' -f ($bytes / 1GB), ($free / 1GB)); return }

    Write-Host ''
    Bot ('Copiando {0} arquivos ({1:N1} MB) para {2}' -f $todo.Count, ($bytes / 1MB), $dest)
    Cursor $false
    $done = 0; $fail = 0; [long]$copied = 0
    $step = [math]::Max(1, [int]($todo.Count / 200))
    foreach ($j in $todo) {
        try {
            $dir = Split-Path $j.T
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }
            Copy-Item -LiteralPath $j.F.FullName $j.T -Force -ErrorAction Stop
        } catch { $fail++ }
        $done++; $copied += $j.F.Length
        if ($done % $step -and $done -ne $todo.Count) { continue }
        $pct = 1; if ($bytes) { $pct = $copied / $bytes }
        $n = [int]($pct * 30)
        $name = $j.F.Name; if ($name.Length -gt 28) { $name = $name.Substring(0, 25) + '...' }
        Write-Host "`r  [" -NoNewline -ForegroundColor $script:T.S
        Write-Host ('█' * $n) -NoNewline -ForegroundColor $script:T.P
        Write-Host ('░' * (30 - $n)) -NoNewline -ForegroundColor DarkGray
        Write-Host '] ' -NoNewline -ForegroundColor $script:T.S
        Write-Host ('{0,4}  {1}/{2}  {3}' -f ('{0:P0}' -f $pct), $done, $todo.Count, $name.PadRight(28)) -NoNewline -ForegroundColor $script:T.T
    }
    Write-Host ''
    Cursor $true
    if ($fail) { Err "$fail arquivo(s) nao puderam ser copiados (em uso ou sem permissao)." } else { Sfx ok }
    Bot "Backup pronto em $dest"
}

# O terminal roda de dentro do pendrive, entao quem ejeta e um processo
# escondido que espera esta janela fechar e depois avisa se deu certo.
function Eject {
    Write-Host ''
    Show-Bar 'Fechando o terminal' 400
    $helper = @"
Start-Sleep -Seconds 2
try { (New-Object -ComObject Shell.Application).Namespace(17).ParseName('$Drive\').InvokeVerb('Eject') } catch {}
Start-Sleep -Seconds 3
if (Test-Path '$Drive\') { `$m = 'Nao consegui ejetar o pendrive. Feche programas e janelas abertas nele e tente de novo.'; `$i = 48 }
else { `$m = 'Pendrive ejetado! Pode remover com seguranca.'; `$i = 64 }
(New-Object -ComObject WScript.Shell).Popup(`$m, 8, 'AKENETIC', `$i) | Out-Null
"@
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($helper))
    Start-Process powershell.exe -ArgumentList "-NoProfile -WindowStyle Hidden -EncodedCommand $enc" -WorkingDirectory $env:TEMP -WindowStyle Hidden
    Set-Location $env:TEMP
    Sfx bye
    exit
}

# ----------------------------------------------------------------- chat entre AKENETICs
# As mensagens passam pelo ntfy.sh (gratuito, sem cadastro), mas saem daqui
# criptografadas (AES-256 + HMAC) com uma chave derivada da senha da sala.
# O servidor so ve texto embaralhado; o topico e um hash do codigo da sala.
# Arquivos vao como anexo do ntfy (ate ~15 MB, ficam ~3h), tambem criptografados.

$ChatPoller = {
    param($topic, $queue, $state)
    $since = '12h'; $first = $true
    while (-not $state.Stop) {
        try {
            if ($first) {
                $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                $wc = New-Object Net.WebClient; $wc.Encoding = [Text.Encoding]::UTF8
                $txt = $wc.DownloadString("https://ntfy.sh/$topic/json?poll=1&since=$since")
                foreach ($l in ($txt -split "`n")) {
                    if (-not $l.Trim()) { continue }
                    $queue.Enqueue($l)
                    try { $o = $l | ConvertFrom-Json; if ($o.id) { $since = $o.id } } catch {}
                }
                if ($since -eq '12h') { $since = "$now" }
                $queue.Enqueue('!LIVE'); $first = $false
            }
            $req = [Net.HttpWebRequest]::Create("https://ntfy.sh/$topic/json?since=$since")
            $req.Timeout = 15000; $req.ReadWriteTimeout = 120000
            $state.Req = $req
            $resp = $req.GetResponse()
            $rd = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
            if ($state.Err) { $state.Err = $false; $queue.Enqueue('!OK') }
            while (-not $state.Stop -and $null -ne ($l = $rd.ReadLine())) {
                if (-not $l.Trim()) { continue }
                try { $o = $l | ConvertFrom-Json } catch { continue }
                if ($o.event -eq 'message') { $since = $o.id; $queue.Enqueue($l) }
            }
            $resp.Close()
        } catch {
            if ($state.Stop) { break }
            if (-not $state.Err) { $state.Err = $true; $queue.Enqueue('!ERR') }
            Start-Sleep -Seconds 3
        }
    }
}

function New-ChatKeys([string]$room, [string]$pass) {
    $sha  = [Security.Cryptography.SHA256]::Create()
    $salt = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("akenetic-salt|$room"))
    $k    = [Security.Cryptography.Rfc2898DeriveBytes]::new($pass, $salt, 20000).GetBytes(64)
    $tid  = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes("akenetic-topic|$room"))
    @{
        Enc   = [byte[]]$k[0..31]
        Mac   = [byte[]]$k[32..63]
        Topic = 'akn-' + (($tid[0..11] | ForEach-Object { $_.ToString('x2') }) -join '')
    }
}

# formato: iv(16) | cifrado | hmac(32)  -- Array.Copy para aguentar arquivos grandes
function Protect-Bytes([byte[]]$plain, $keys = $script:ChatKeys) {
    $aes = [Security.Cryptography.Aes]::Create(); $aes.Key = $keys.Enc; $aes.GenerateIV()
    $ct   = $aes.CreateEncryptor().TransformFinalBlock($plain, 0, $plain.Length)
    $all  = New-Object byte[] (16 + $ct.Length + 32)
    [Array]::Copy($aes.IV, 0, $all, 0, 16)
    [Array]::Copy($ct, 0, $all, 16, $ct.Length)
    $mac  = [Security.Cryptography.HMACSHA256]::new($keys.Mac).ComputeHash($all, 0, 16 + $ct.Length)
    [Array]::Copy($mac, 0, $all, 16 + $ct.Length, 32)
    , $all
}

function Unprotect-Bytes([byte[]]$all, $keys = $script:ChatKeys) {
    try {
        if ($all.Length -lt 64) { return $null }
        $n    = $all.Length - 32
        $calc = [Security.Cryptography.HMACSHA256]::new($keys.Mac).ComputeHash($all, 0, $n)
        $diff = 0; for ($i = 0; $i -lt 32; $i++) { $diff = $diff -bor ($calc[$i] -bxor $all[$n + $i]) }
        if ($diff) { return $null }
        $aes = [Security.Cryptography.Aes]::Create(); $aes.Key = $keys.Enc
        $iv = New-Object byte[] 16; [Array]::Copy($all, $iv, 16); $aes.IV = $iv
        , $aes.CreateDecryptor().TransformFinalBlock($all, 16, $n - 16)
    } catch { $null }
}

function Protect-Msg([string]$text) { [Convert]::ToBase64String((Protect-Bytes ([Text.Encoding]::UTF8.GetBytes($text)))) }

function Unprotect-Msg([string]$b64) {
    try {
        $b = Unprotect-Bytes ([Convert]::FromBase64String($b64))
        if ($null -eq $b) { return $null }
        [Text.Encoding]::UTF8.GetString($b)
    } catch { $null }
}

function New-ChatPayload([string]$type, [string]$text = '', $extra = $null) {
    $id = [guid]::NewGuid().ToString('N').Substring(0, 12)
    [void]$script:ChatOwnIds.Add($id)
    $o = @{ i = $id; n = $script:ChatName; t = $type; m = $text }
    if ($null -ne $extra) { $o.x = $extra }
    Protect-Msg ($o | ConvertTo-Json -Compress -Depth 6)
}

function Send-Chat([string]$type, [string]$text = '', $extra = $null) {
    try {
        Invoke-RestMethod -Method Post -Uri "https://ntfy.sh/$($script:ChatKeys.Topic)" -Body (New-ChatPayload $type $text $extra) -ContentType 'text/plain' -TimeoutSec 10 | Out-Null
        $true
    } catch { $false }
}

function Format-Size([double]$b) {
    if ($b -ge 1MB) { '{0:N1} MB' -f ($b / 1MB) } else { '{0:N0} KB' -f [math]::Ceiling($b / 1KB) }
}

function Send-ChatFile([string]$path) {
    $path = $path.Trim().Trim('"')
    if (-not $path) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $dlg = New-Object Windows.Forms.OpenFileDialog
            $dlg.Title = 'AKENETIC - escolha o arquivo para enviar'
            $owner = New-Object Windows.Forms.Form -Property @{ TopMost = $true }
            $ok = $dlg.ShowDialog($owner); $owner.Dispose()
            if ($ok -ne 'OK') { return }
            $path = $dlg.FileName
        } catch { Write-ChatNotice 'use: /enviar C:\caminho\do\arquivo  (ou arraste o arquivo pra janela)' Yellow; return }
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Write-ChatNotice "arquivo nao encontrado: $path" Red; Sfx err; return }
    $fi = Get-Item -LiteralPath $path
    if ($fi.Length -gt 14MB) { Write-ChatNotice 'arquivo grande demais (maximo ~14 MB)' Red; Sfx err; return }
    Write-ChatNotice ('enviando {0} ({1})...' -f $fi.Name, (Format-Size $fi.Length)) $script:T.A
    try {
        $body = Protect-Bytes ([IO.File]::ReadAllBytes($fi.FullName))
        $msg  = New-ChatPayload 'file' $fi.Name @{ s = $fi.Length }
        Invoke-RestMethod -Method Put -Uri "https://ntfy.sh/$($script:ChatKeys.Topic)" -Body $body `
            -ContentType 'application/octet-stream' -Headers @{ Filename = 'akn.bin'; Message = $msg } -TimeoutSec 180 | Out-Null
        Write-ChatLine (Get-Date -Format 'HH:mm') $script:ChatName ('[ANEXO] {0} ({1})' -f $fi.Name, (Format-Size $fi.Length)) $script:T.P
        Sfx ok
    } catch { Write-ChatNotice "falha ao enviar: $($_.Exception.Message)" Red; Sfx err }
}

# baixa, decifra e salva em \Recebidos sem sobrescrever nada; devolve $null ou o erro
function Save-ChatFile([string]$url, [string]$name) {
    $dir = "$Drive\Recebidos"
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory $dir | Out-Null }
    $safe = ([IO.Path]::GetFileName($name)) -replace '[\\/:*?"<>|]', '_'
    if (-not $safe) { $safe = 'arquivo' }
    $base = [IO.Path]::GetFileNameWithoutExtension($safe); $ext = [IO.Path]::GetExtension($safe)
    $dest = Join-Path $dir $safe; $n = 1
    while (Test-Path -LiteralPath $dest) { $dest = Join-Path $dir ('{0} ({1}){2}' -f $base, $n, $ext); $n++ }
    try {
        $plain = Unprotect-Bytes ((New-Object Net.WebClient).DownloadData($url))
        if ($null -eq $plain) { return 'arquivo com outra senha ou corrompido' }
        [IO.File]::WriteAllBytes($dest, $plain)
        $script:ChatLastFile = $dest
        $null
    } catch { 'o arquivo expirou (ficam ~3h) ou nao pode ser baixado' }
}

function Clean([string]$s) { ($s -replace '[\x00-\x1F\x7F]', '').Trim() }

function Name-Color([string]$n) {
    $pal = 'Cyan', 'Yellow', 'Magenta', 'Green', 'Red', 'Blue', 'DarkYellow', 'DarkCyan'
    $s = 0; foreach ($c in $n.ToCharArray()) { $s += [int]$c }
    $pal[$s % $pal.Count]
}

function Read-Secret([string]$label) {
    Write-Host $label -NoNewline -ForegroundColor $script:T.A
    $s = ''
    while ($true) {
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq 'Enter') { Write-Host ''; return $s }
        if ($k.Key -eq 'Backspace') {
            if ($s.Length) { $s = $s.Substring(0, $s.Length - 1); Write-Host "`b `b" -NoNewline }
        } elseif (-not [char]::IsControl($k.KeyChar)) {
            $s += $k.KeyChar; Write-Host '*' -NoNewline -ForegroundColor $script:T.P
        }
    }
}

function Ask([string]$label, [string]$default = '') {
    $hint = ''; if ($default) { $hint = " [$default]" }
    Write-Host "  ${label}${hint}: " -NoNewline -ForegroundColor $script:T.A
    [Console]::ForegroundColor = 'White'
    $v = [Console]::ReadLine(); [Console]::ForegroundColor = 'Gray'
    if (-not $v) { $v = $default }
    Clean $v
}

function Chat-Header {
    Clear-Host
    Show-Banner
    Box @("SALA: $script:ChatRoom   ·   voce: $script:ChatName",
          '/ajuda  todos os comandos (chat, arquivos e RPG)',
          '/r 1d20  rola dado      /enviar  manda arquivo',
          '/ficha   cria ficha     /historico  conversas antigas',
          '/sair    volta pro terminal')
    Write-Host ''
}

function Clear-InputLine { Write-Host ("`r" + (' ' * ([Console]::WindowWidth - 1)) + "`r") -NoNewline }

function Draw-Input {
    Clear-InputLine
    $max = [Console]::WindowWidth - 8
    $shown = $script:ChatBuf
    if ($shown.Length -gt $max) { $shown = '...' + $shown.Substring($shown.Length - $max + 3) }
    Write-Host '  » ' -NoNewline -ForegroundColor $script:T.P
    Write-Host $shown -NoNewline -ForegroundColor White
}

function Write-ChatLine([string]$time, [string]$name, [string]$text, $nameColor) {
    Write-Host "  [$time] " -NoNewline -ForegroundColor DarkGray
    Write-Host $name -NoNewline -ForegroundColor $nameColor
    Write-Host ' » ' -NoNewline -ForegroundColor $script:T.S
    Write-Host $text -ForegroundColor White
}

function Write-ChatNotice([string]$text, $color = 'DarkGray') {
    Write-Host "          ** $text **" -ForegroundColor $color
}

# ----------------------------------------------------------------- RPG
$SheetFile = Join-Path $Root 'ficha.json'

function Cut([string]$s, [int]$n) { $s = Clean $s; if ($s.Length -gt $n) { $s.Substring(0, $n) } else { $s } }

function Normalize-Sheet($x) {
    if (-not $x) { return $null }
    try {
        $max = [math]::Max(1, [math]::Min(9999, [int]$x.max))
        @{ c = (Cut $x.c 24); k = (Cut $x.k 20); hp = [math]::Max(0, [math]::Min($max, [int]$x.hp)); max = $max; a = (Cut $x.a 60) }
    } catch { $null }
}

function Load-Sheet {
    if (-not (Test-Path -LiteralPath $SheetFile)) { return $null }
    try { Normalize-Sheet (Get-Content -LiteralPath $SheetFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { $null }
}

function Save-Sheet { $script:MySheet | ConvertTo-Json -Compress | Set-Content -LiteralPath $SheetFile -Encoding UTF8 }

function Roll-Expr([string]$expr) {
    $e = ($expr -replace '\s', '').ToLower()
    if (-not $e) { $e = '1d20' }
    if ($e -notmatch '^(\d{0,2})d(\d{1,3})([+-]\d{1,3})?$') { return $null }
    $cnt = 1; if ($Matches[1]) { $cnt = [int]$Matches[1] }
    $faces = [int]$Matches[2]; $bonus = 0; if ($Matches[3]) { $bonus = [int]$Matches[3] }
    if ($cnt -lt 1 -or $cnt -gt 20 -or $faces -lt 2) { return $null }
    $d = @(1..$cnt | ForEach-Object { $Rnd.Next(1, $faces + 1) })
    @{ e = $e; d = $d; b = $bonus; r = [int](($d | Measure-Object -Sum).Sum + $bonus); f = $faces }
}

# o total e recalculado aqui, entao o que aparece sempre bate com os dados
function Normalize-Roll($x) {
    if (-not $x) { return $null }
    try {
        $d = @(@($x.d) | Select-Object -First 20 | ForEach-Object { [int]$_ })
        $b = [int]$x.b
        @{ e = (Cut $x.e 16); d = $d; b = $b; r = [int](($d | Measure-Object -Sum).Sum + $b); f = [int]$x.f; c = (Cut $x.c 24) }
    } catch { $null }
}

function Write-Roll([string]$time, [string]$name, $x, $color, [bool]$animate, [string]$verb = 'rolou') {
    if (-not $x) { return }
    $dice = @($x.d); $faces = [int]$x.f
    if ($animate) {
        for ($k = 0; $k -lt 10; $k++) {
            Write-Host ("`r  [{0}] {1} {2} {3}: [{4}]   " -f $time, $name, $verb, $x.e, $Rnd.Next(1, [math]::Max(2, $faces) + 1)) -NoNewline -ForegroundColor DarkGray
            Play (1800 + $k * 60),8
            Start-Sleep -Milliseconds (25 + $k * 6)
        }
        Clear-InputLine
    }
    $bonus = ''; if ($x.b -gt 0) { $bonus = " +$($x.b)" } elseif ($x.b -lt 0) { $bonus = " $($x.b)" }
    Write-Host "  [$time] " -NoNewline -ForegroundColor DarkGray
    Write-Host $name -NoNewline -ForegroundColor $color
    Write-Host " $verb $($x.e): " -NoNewline -ForegroundColor $script:T.T
    Write-Host ('[' + ($dice -join '] [') + ']') -NoNewline -ForegroundColor White
    Write-Host "$bonus = " -NoNewline -ForegroundColor $script:T.T
    Write-Host $x.r -NoNewline -ForegroundColor $script:T.A
    $single20 = ($faces -eq 20 -and $dice.Count -eq 1)
    if ($single20 -and $dice[0] -eq 20) {
        Write-Host '   CRITICO!' -ForegroundColor Green
        if ($animate) { Play 784,80,1047,80,1568,220 }
    } elseif ($single20 -and $dice[0] -eq 1) {
        Write-Host '   FALHA CRITICA!' -ForegroundColor Red
        if ($animate) { Play 400,150,300,150,200,300 }
    } else {
        Write-Host ''
        if ($animate) { Sfx tick }
    }
}

function Write-Narration([string]$text, [bool]$animate) {
    Write-Host ''
    Write-Host '  ~~~~~~~~~~~~~~~~ NARRACAO DO MESTRE ~~~~~~~~~~~~~~~~' -ForegroundColor DarkYellow
    Write-Host '    ' -NoNewline
    if ($animate) { Play 523,120,659,120,784,200; Type-Out $text 'Yellow' 18 } else { Write-Host $text -ForegroundColor Yellow }
    Write-Host '  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~' -ForegroundColor DarkYellow
}

function Write-Sheet([string]$player, $s) {
    if (-not $s) { return }
    $max = [math]::Max(1, [int]$s.max); $hp = [int]$s.hp; $pct = $hp / $max
    $n = [int][math]::Round(10 * [math]::Max(0.0, [math]::Min(1.0, $pct)))
    $c = 'Green'; if ($pct -le 0.25) { $c = 'Red' } elseif ($pct -le 0.5) { $c = 'Yellow' }
    Write-Host ('  {0,-12} ' -f $player) -NoNewline -ForegroundColor (Name-Color $player)
    $title = $s.c; if ($s.k) { $title += " ($($s.k))" }
    Write-Host $title.PadRight(26) -NoNewline -ForegroundColor White
    Write-Host ('█' * $n) -NoNewline -ForegroundColor $c
    Write-Host ('░' * (10 - $n)) -NoNewline -ForegroundColor DarkGray
    Write-Host (' {0}/{1}' -f $hp, $max) -NoNewline -ForegroundColor $c
    if ($s.a) { Write-Host "  $($s.a)" -ForegroundColor DarkGray } else { Write-Host '' }
}

function Write-HpChange([string]$player, $s, [int]$delta, [bool]$sound) {
    if (-not $s) { return }
    $who = "$($s.c) ($player)"
    if ($delta -lt 0)     { $txt = "$who levou $(-$delta) de dano"; $c = 'Red';   if ($sound) { Play 300,80,200,120 } }
    elseif ($delta -gt 0) { $txt = "$who curou $delta";             $c = 'Green'; if ($sound) { Play 880,60,1175,90 } }
    else                  { $txt = "$who atualizou a vida";        $c = $script:T.A }
    Write-ChatNotice ("{0}  -  vida {1}/{2}" -f $txt, $s.hp, $s.max) $c
    if ([int]$s.hp -eq 0) { Write-ChatNotice "$($s.c) CAIU!" Red }
}

function Show-Sheets {
    Write-Host ''
    Write-Host '  ══ FICHAS ══════════════════════════════════════════' -ForegroundColor $script:T.S
    $any = $false
    if ($script:MySheet) { Write-Sheet $script:ChatName $script:MySheet; $any = $true }
    foreach ($p in ($script:Sheets.Keys | Sort-Object)) { if ($script:Sheets[$p]) { Write-Sheet $p $script:Sheets[$p]; $any = $true } }
    if (-not $any) { Write-Host '  ninguem criou ficha ainda. Use /ficha' -ForegroundColor DarkGray }
    if ($script:ChatMaster) { Write-Host "  Mestre: $script:ChatMaster" -ForegroundColor Yellow }
}

function Show-Inits {
    $list = @($script:Inits.GetEnumerator() | Sort-Object { [int]$_.Value.r } -Descending)
    if (-not $list.Count) { return }
    $parts = for ($i = 0; $i -lt $list.Count; $i++) { '{0}. {1} ({2})' -f ($i + 1), $list[$i].Value.c, $list[$i].Value.r }
    Write-Host '  ORDEM: ' -NoNewline -ForegroundColor $script:T.A
    Write-Host ($parts -join '  >  ') -ForegroundColor White
}

function New-Sheet {
    Write-ChatNotice 'criando sua ficha (Enter mantem o valor atual)' $script:T.A
    $old = $script:MySheet; if (-not $old) { $old = @{ c = ''; k = ''; hp = 10; max = 10; a = '' } }
    $c   = Ask 'Nome do personagem' $old.c
    $k   = Ask 'Classe' $old.k
    $max = Ask 'Vida maxima' ([string]$old.max)
    $a   = Ask 'Atributos (ex: FOR 16 DES 12 CON 14)' $old.a
    if (-not $c) { Write-ChatNotice 'ficha cancelada' Yellow; return }
    $m = 10; if ($max -match '^\d{1,4}$' -and [int]$max -gt 0) { $m = [int]$max }
    $script:MySheet = Normalize-Sheet @{ c = $c; k = $k; hp = $m; max = $m; a = $a }
    Save-Sheet
    Write-Sheet $script:ChatName $script:MySheet
    Sfx ok
    if (-not (Send-Chat 'sheet' '' $script:MySheet)) { Write-ChatNotice 'ficha salva, mas nao consegui enviar pra sala' Red }
}

function Here-Extra { @{ s = $script:MySheet; m = ($script:ChatMaster -eq $script:ChatName) } }

function Merge-Here([string]$name, $x) {
    if (-not $x) { return }
    if ($x.s) { $script:Sheets[$name] = Normalize-Sheet $x.s }
    if ($x.m -eq $true) { $script:ChatMaster = $name }
}

function Handle-ChatItem([string]$raw) {
    switch ($raw) {
        '!LIVE' {
            if ($script:ChatHadHistory) { Write-Host '  ──────────────── agora ────────────────' -ForegroundColor $script:T.S }
            $script:ChatLive = $true
            Write-ChatNotice 'conectado! as mensagens sao criptografadas' Green
            return
        }
        '!ERR' { Write-ChatNotice 'sem conexao com o servidor, tentando de novo...' Red; Sfx err; return }
        '!OK'  { Write-ChatNotice 'conexao de volta!' Green; return }
    }
    try { $o = $raw | ConvertFrom-Json } catch { return }
    if ($o.event -ne 'message' -or -not $script:ChatSeen.Add($o.id)) { return }
    $time = [DateTimeOffset]::FromUnixTimeSeconds([long]$o.time).LocalDateTime.ToString('HH:mm')

    $plain = Unprotect-Msg $o.message
    if (-not $plain) { Write-Host "  [$time] (mensagem com outra senha, ignorada)" -ForegroundColor DarkGray; return }
    try { $p = $plain | ConvertFrom-Json } catch { return }
    $name = Cut ([string]$p.n) 16; if (-not $name) { $name = '???' }
    # o historico grava tambem as nossas mensagens (quando o eco volta do servidor)
    $logText = switch ([string]$p.t) {
        'msg'   { "$name » $(Clean ([string]$p.m))" }
        'file'  { "$name » [ANEXO] $(Cut ([string]$p.m) 120)" }
        'roll'  { $x = Normalize-Roll $p.x; if ($x) { "$name rolou $($x.e): [$($x.d -join '] [')] = $($x.r)" } }
        'init'  { $x = Normalize-Roll $p.x; if ($x) { "$name rolou iniciativa: $($x.r)" } }
        'narr'  { "NARRACAO ($name): $(Clean ([string]$p.m))" }
        'hp'    { $s = Normalize-Sheet $p.x; if ($s) { "$($s.c) ($name) ficou com vida $($s.hp)/$($s.max)" } }
        'join'  { "** $name entrou **" }
        'leave' { "** $name saiu **" }
    }
    if ($logText) { Log-Chat $o.id ([DateTimeOffset]::FromUnixTimeSeconds([long]$o.time).LocalDateTime.ToString('dd/MM HH:mm')) $logText }
    if ($script:ChatOwnIds.Contains([string]$p.i)) { return }
    $live = $script:ChatLive

    if (-not $live -and -not $script:ChatHadHistory) {
        $script:ChatHadHistory = $true
        Write-Host '  ────────── mensagens anteriores ──────────' -ForegroundColor $script:T.S
    }
    $script:ChatPeople[$name] = $true
    switch ([string]$p.t) {
        'msg' {
            Write-ChatLine $time $name (Clean ([string]$p.m)) (Name-Color $name)
            if ($live) { Play 1319,45,1760,70 }
        }
        'file' {
            $fname = Cut ([string]$p.m) 120; $size = 0; if ($p.x) { $size = [long]$p.x.s }
            Write-ChatLine $time $name ('[ANEXO] {0} ({1})' -f $fname, (Format-Size $size)) (Name-Color $name)
            if (-not $o.attachment) { Write-ChatNotice 'anexo indisponivel'; break }
            if ($live) {
                $err = Save-ChatFile $o.attachment.url $fname
                if ($err) { Write-ChatNotice $err Red } else { Write-ChatNotice "salvo em $script:ChatLastFile   (/abrir abre a pasta)" Green; Play 1319,45,1760,70 }
            } else {
                $script:ChatPendingFiles.Add(@{ u = $o.attachment.url; n = $fname })
                Write-ChatNotice 'arquivo antigo: digite /baixar para salvar'
            }
        }
        'roll'   { Write-Roll $time $name (Normalize-Roll $p.x) (Name-Color $name) $live }
        'init'   {
            $x = Normalize-Roll $p.x
            if ($x) {
                $cn = $x.c; if (-not $cn) { $cn = $name }
                $script:Inits[$name] = @{ r = $x.r; c = $cn }
                Write-Roll $time $name $x (Name-Color $name) $live 'rolou iniciativa'
                Show-Inits
            }
        }
        'initreset' { $script:Inits = @{}; Write-ChatNotice "$name zerou a iniciativa" $script:T.A }
        'secret' { Write-ChatNotice "$name (mestre) rolou um dado em segredo..." DarkYellow; if ($live) { Play 220,200 } }
        'master' { $script:ChatMaster = $name; Write-ChatNotice "$name agora e o MESTRE da sala" Yellow; if ($live) { Play 523,90,784,160 } }
        'narr'   { Write-Narration (Clean ([string]$p.m)) $live }
        'sheet'  {
            $script:Sheets[$name] = Normalize-Sheet $p.x
            Write-ChatNotice "$name atualizou a ficha:" (Name-Color $name)
            Write-Sheet $name $script:Sheets[$name]
        }
        'hp' {
            $script:Sheets[$name] = Normalize-Sheet $p.x
            $delta = 0; [void][int]::TryParse([string]$p.m, [ref]$delta)
            Write-HpChange $name $script:Sheets[$name] $delta $live
        }
        'join' {
            Merge-Here $name $p.x
            Write-ChatNotice "$name entrou na sala" (Name-Color $name)
            # responde para quem chegou saber que estamos aqui (e receber nossa ficha)
            if ($live) { Play 784,60,1047,90; [void](Send-Chat 'here' '' (Here-Extra)) }
        }
        'here'  { Merge-Here $name $p.x }
        'leave' {
            $script:ChatPeople.Remove($name)
            Write-ChatNotice "$name saiu da sala" DarkGray
            if ($live) { Play 1047,60,784,90 }
        }
    }
}

# Historico em D:\Conversas\<topico>.log: uma linha por mensagem, "id<TAB>texto cifrado".
# Cifrado com a chave da sala, entao so quem sabe a senha consegue ler.
function Open-ChatLog {
    $dir = "$Drive\Conversas"
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory $dir | Out-Null }
    $script:ChatLogFile = Join-Path $dir "$($script:ChatKeys.Topic).log"
    $script:ChatLogIds  = New-Object 'System.Collections.Generic.HashSet[string]'
    if (Test-Path -LiteralPath $script:ChatLogFile) {
        foreach ($l in Get-Content -LiteralPath $script:ChatLogFile) { [void]$script:ChatLogIds.Add(($l -split "`t", 2)[0]) }
    }
}

function Log-Chat([string]$id, [string]$when, [string]$text) {
    if (-not $id -or -not $script:ChatLogIds.Add($id)) { return }
    try { Add-Content -LiteralPath $script:ChatLogFile -Value ("$id`t" + (Protect-Msg "[$when] $text")) -Encoding ASCII } catch {}
}

function Show-ChatHistory([string]$arg) {
    $n = 30; if ($arg -match '^\d{1,4}$') { $n = [int]$arg }
    if (-not (Test-Path -LiteralPath $script:ChatLogFile)) { Write-ChatNotice 'nenhuma conversa salva ainda nessa sala'; return }
    $lines = @(Get-Content -LiteralPath $script:ChatLogFile -Tail $n)
    Write-Host ''
    Write-Host "  ══ HISTORICO DA SALA (ultimas $($lines.Count)) ══════════════" -ForegroundColor $script:T.S
    foreach ($l in $lines) {
        $t = Unprotect-Msg (($l -split "`t", 2)[1])
        if ($t) { Write-Host "  $t" -ForegroundColor DarkGray }
    }
    Write-Host '  ═════════════════════════════════════════════' -ForegroundColor $script:T.S
}

function Chat-Help {
    $rows = @(
        @('CHAT', ''),
        @('/enviar [arquivo]', 'manda arquivo (sem nome abre a janela, ou arraste)'),
        @('/baixar', 'salva os arquivos antigos da sala'),
        @('/abrir', 'abre a pasta Recebidos'),
        @('/quem  /limpar  /som', 'pessoas na sala / limpa / sons'),
        @('/historico [n]', 'conversas antigas salvas no pendrive'),
        @('/sair', 'volta pro terminal'),
        @('RPG', ''),
        @('/rolar 1d20+3  (/r)', 'rola dados pra todos verem'),
        @('/ficha  /fichas', 'cria sua ficha / ve a de todos'),
        @('/vida -5  /vida +3', 'dano / cura'),
        @('/iniciativa [+2]', 'rola iniciativa e mostra a ordem'),
        @('/mestre', 'vira o mestre da sala'),
        @('/narrar <texto>', 'narracao em destaque (mestre)'),
        @('/secreto 1d20', 'rolagem escondida (mestre)'),
        @('/iniciativa limpar', 'zera a ordem de turnos')
    )
    Write-Host ''
    foreach ($r in $rows) {
        if (-not $r[1]) { Write-Host "  ══ $($r[0]) ══" -ForegroundColor $script:T.S; continue }
        Write-Host ('    ' + $r[0].PadRight(22)) -NoNewline -ForegroundColor $script:T.P
        Write-Host $r[1] -ForegroundColor $script:T.T
    }
}

function Chat-Command([string]$text) {
    $cmd, $rest = $text -split '\s+', 2
    $arg = ''; if ($rest) { $arg = $rest.Trim() }
    $me = $script:ChatName; $now = Get-Date -Format 'HH:mm'
    $isMaster = ($script:ChatMaster -eq $me)
    $usage = 'use: /rolar 1d20+3  (ate 20 dados: 2d6, 1d100, 4d6-1)'
    switch -Regex ($cmd.ToLower()) {
        '^/(sair|exit)$'      { $script:ChatExit = $true; break }
        '^/limpar$'           { Chat-Header; break }
        '^/(ajuda|help|\?)$'  { Chat-Help; break }
        '^/som$' {
            $script:SoundOn = -not $script:SoundOn; Save-Config
            Write-ChatNotice "som $(if ($script:SoundOn) {'ligado'} else {'desligado'})"; break
        }
        '^/quem$' {
            $others = @($script:ChatPeople.Keys | Sort-Object)
            if ($others.Count) { Write-ChatNotice ('na sala: voce, ' + ($others -join ', ')) $script:T.A }
            else { Write-ChatNotice 'por enquanto so voce esta aqui' }
            break
        }
        '^/enviar$' { Send-ChatFile $arg; break }
        '^/baixar$' {
            if (-not $script:ChatPendingFiles.Count) { Write-ChatNotice 'nenhum arquivo antigo pra baixar'; break }
            foreach ($f in @($script:ChatPendingFiles)) {
                $err = Save-ChatFile $f.u $f.n
                if ($err) { Write-ChatNotice "$($f.n): $err" Red } else { Write-ChatNotice "salvo: $script:ChatLastFile" Green }
            }
            $script:ChatPendingFiles.Clear(); break
        }
        '^/abrir$' {
            $dir = "$Drive\Recebidos"
            if (Test-Path -LiteralPath $dir) { Start-Process explorer.exe $dir } else { Write-ChatNotice 'voce ainda nao recebeu arquivos' }
            break
        }
        '^/(rolar|r)$' {
            $x = Roll-Expr $arg
            if (-not $x) { Write-ChatNotice $usage Yellow; break }
            Write-Roll $now $me $x $script:T.P $true
            if (-not (Send-Chat 'roll' '' $x)) { Write-ChatNotice 'rolagem NAO enviada (sem internet?)' Red }
            break
        }
        '^/secreto$' {
            if (-not $isMaster) { Write-ChatNotice 'so o mestre rola em segredo (use /mestre)' Yellow; break }
            $x = Roll-Expr $arg
            if (-not $x) { Write-ChatNotice $usage Yellow; break }
            Write-Roll $now $me $x 'DarkGray' $true 'rolou em SEGREDO'
            [void](Send-Chat 'secret'); break
        }
        '^/mestre$' {
            $script:ChatMaster = $me
            Write-ChatNotice 'voce agora e o MESTRE da sala' Yellow
            [void](Send-Chat 'master'); break
        }
        '^/narrar$' {
            if (-not $isMaster) { Write-ChatNotice 'so o mestre narra (use /mestre)' Yellow; break }
            if (-not $arg) { Write-ChatNotice 'use: /narrar A porta range e uma sombra aparece...' Yellow; break }
            Write-Narration $arg $false
            if (-not (Send-Chat 'narr' $arg)) { Write-ChatNotice 'narracao NAO enviada' Red }
            break
        }
        '^/ficha$'  { New-Sheet; break }
        '^/fichas$' { Show-Sheets; break }
        '^/(historico|history)$' { Show-ChatHistory $arg; break }
        '^/vida$' {
            if (-not $script:MySheet) { Write-ChatNotice 'crie sua ficha primeiro: /ficha' Yellow; break }
            if ($arg -notmatch '^([+-]?)(\d{1,4})$') { Write-ChatNotice 'use: /vida -5 (dano)   /vida +3 (cura)   /vida 10 (define)' Yellow; break }
            $old = [int]$script:MySheet.hp; $v = [int]$Matches[2]
            $new = $v; if ($Matches[1] -eq '-') { $new = $old - $v } elseif ($Matches[1] -eq '+') { $new = $old + $v }
            $script:MySheet.hp = [math]::Max(0, [math]::Min([int]$script:MySheet.max, $new))
            Save-Sheet
            $delta = [int]$script:MySheet.hp - $old
            Write-HpChange $me $script:MySheet $delta $true
            [void](Send-Chat 'hp' ([string]$delta) $script:MySheet); break
        }
        '^/iniciativa$' {
            if ($arg -eq 'limpar') { $script:Inits = @{}; Write-ChatNotice 'iniciativa zerada' $script:T.A; [void](Send-Chat 'initreset'); break }
            $b = 0; if ($arg -match '^[+-]?\d{1,2}$') { $b = [int]$arg }
            $x = Roll-Expr ('1d20' + $(if ($b -lt 0) { "$b" } else { "+$b" }))
            $cn = $me; if ($script:MySheet) { $cn = $script:MySheet.c }
            $x.c = $cn
            Write-Roll $now $me $x $script:T.P $true 'rolou iniciativa'
            $script:Inits[$me] = @{ r = $x.r; c = $cn }
            Show-Inits
            [void](Send-Chat 'init' '' $x); break
        }
        default {
            if ($text.StartsWith('/')) { Write-ChatNotice 'comando desconhecido. /ajuda mostra todos' Yellow; break }
            if ($text.Length -gt 1000) { $text = $text.Substring(0, 1000) }
            Write-ChatLine $now $me $text $script:T.P
            Sfx enter
            if (-not (Send-Chat 'msg' $text)) { Write-ChatNotice 'mensagem NAO enviada (sem internet ou limite do servidor)' Red; Sfx err }
        }
    }
}

function Open-ChatRoom {
    Write-Host ''
    Box @('CHAT AKENETIC  ·  chat, arquivos e RPG',
          'Combine com seu amigo o MESMO codigo de sala e a MESMA senha.',
          'Funciona junto com o AKENETIC do celular.')
    Write-Host ''
    $name = Ask 'Seu apelido' $script:ChatName
    if ($name.Length -gt 16) { $name = $name.Substring(0, 16) }
    $room = Ask 'Codigo da sala' $script:ChatRoom
    if ($name.Length -lt 2 -or $room.Length -lt 4) { Err 'Apelido precisa de 2+ letras e o codigo da sala de 4+.'; return }
    $pass = Read-Secret '  Senha da sala: '
    if ($pass.Length -lt 4) { Err 'A senha precisa de pelo menos 4 caracteres.'; return }

    $script:ChatName = $name; $script:ChatRoom = $room; Save-Config
    Spin 'Gerando chave secreta...' 400
    $script:ChatKeys         = New-ChatKeys $room.ToLower() $pass
    $script:ChatOwnIds       = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:ChatSeen         = New-Object 'System.Collections.Generic.HashSet[string]'
    $script:ChatPendingFiles = New-Object 'System.Collections.Generic.List[object]'
    $script:ChatPeople       = @{}
    $script:Sheets           = @{}
    $script:Inits            = @{}
    $script:MySheet          = Load-Sheet
    $script:ChatMaster       = ''
    $script:ChatLastFile     = ''
    $script:ChatLive         = $false
    $script:ChatHadHistory   = $false
    $script:ChatExit         = $false
    $script:ChatBuf          = ''
    Open-ChatLog

    $queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[string]'
    $state = [hashtable]::Synchronized(@{ Stop = $false; Err = $false; Req = $null })
    $ps = [powershell]::Create()
    [void]$ps.AddScript($ChatPoller).AddArgument($script:ChatKeys.Topic).AddArgument($queue).AddArgument($state)
    [void]$ps.BeginInvoke()

    Chat-Header
    Write-ChatNotice 'conectando...' $script:T.A
    if (-not (Send-Chat 'join' '' (Here-Extra))) { Write-ChatNotice 'nao consegui enviar. Tem internet?' Red; Sfx err }
    while ([Console]::KeyAvailable) { [void][Console]::ReadKey($true) }
    Draw-Input

    $item = $null
    while ($true) {
        if (-not $queue.IsEmpty) {
            Clear-InputLine
            while ($queue.TryDequeue([ref]$item)) { Handle-ChatItem $item }
            Draw-Input
        }
        if (-not [Console]::KeyAvailable) { Start-Sleep -Milliseconds 30; continue }

        $k = [Console]::ReadKey($true)
        if ($k.Key -eq 'Enter') {
            $text = Clean $script:ChatBuf
            $script:ChatBuf = ''
            Clear-InputLine
            if ($text) { Chat-Command $text | Out-Null }
            if ($script:ChatExit) { break }
            Draw-Input
        }
        elseif ($k.Key -eq 'Backspace') {
            if ($script:ChatBuf.Length) { $script:ChatBuf = $script:ChatBuf.Substring(0, $script:ChatBuf.Length - 1); Draw-Input }
        }
        elseif ($k.Key -eq 'Escape') { $script:ChatBuf = ''; Draw-Input }
        elseif (-not [char]::IsControl($k.KeyChar) -and $script:ChatBuf.Length -lt 1000) {
            $script:ChatBuf += $k.KeyChar
            if ($script:ChatBuf.Length -lt [Console]::WindowWidth - 8) { Write-Host $k.KeyChar -NoNewline -ForegroundColor White }
            else { Draw-Input }
        }
    }

    Clear-InputLine
    Write-ChatNotice 'saindo da sala...'
    [void](Send-Chat 'leave')
    $state.Stop = $true
    try { if ($state.Req) { $state.Req.Abort() } } catch {}
    [void]$ps.BeginStop($null, $null)
    Sfx bye
}

# Copia so o programa (sem notas, config, apps ou backups) para outro pendrive/pasta
function Share([string]$arg) {
    if (-not $arg) {
        Bot 'Use: compartilhar E:   (letra do pendrive do seu amigo, ou uma pasta)'
        $others = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=2' | Where-Object { $_.DeviceID -ne $Drive })
        if ($others.Count) {
            Write-Host ''
            foreach ($d in $others) {
                Write-Host ('  {0}  ' -f $d.DeviceID) -NoNewline -ForegroundColor $script:T.A
                Write-Host ('{0}  ({1:N1} GB livres)' -f $d.VolumeName, ($d.FreeSpace / 1GB)) -ForegroundColor $script:T.T
            }
        } else { Write-Host '  (nenhum outro pendrive conectado agora)' -ForegroundColor DarkGray }
        return
    }
    $target = $arg.Trim('"').TrimEnd('\')
    if ($target -match '^[a-zA-Z]:?$') { $target = $target.Substring(0, 1).ToUpper() + ':' }
    if (-not (Test-Path -LiteralPath "$target\")) { Err "Nao encontrei $target"; return }
    if ($target.StartsWith($Drive, [StringComparison]::OrdinalIgnoreCase)) { Err 'Esse e o seu proprio pendrive.'; return }
    $tdir = Join-Path "$target\" 'Terminal'
    if (Test-Path -LiteralPath (Join-Path $tdir 'terminal.ps1')) {
        Write-Host '  Ja existe um AKENETIC la. Atualizar? (s/n): ' -NoNewline -ForegroundColor Yellow
        if ([Console]::ReadLine() -notmatch '^s') { return }
    }
    try {
        New-Item -ItemType Directory $tdir -Force | Out-Null
        Show-Bar 'Copiando AKENETIC' 600
        Copy-Item -LiteralPath (Join-Path $Root 'terminal.ps1') $tdir -Force -ErrorAction Stop
        Copy-Item -LiteralPath "$Drive\ABRIR TERMINAL.bat" "$target\" -Force -ErrorAction Stop
        Bot "Pronto! Em $target e so abrir 'ABRIR TERMINAL.bat'. Suas notas e configs nao foram copiadas."
        Sfx ok
    } catch { Err "Nao consegui copiar: $($_.Exception.Message)" }
}

# ----------------------------------------------------------------- premium: publicar o site no GitHub
# Usa a API do GitHub com um token "fine-grained" que fica em github.dat
# criptografado com a senha mestra (PBKDF2 100k + AES + HMAC). O token
# decifrado fica so na memoria enquanto o terminal estiver aberto.
$GitHubFile = Join-Path $Root 'github.dat'
$SiteFile   = "$Drive\Celular\index.html"
$script:GhToken = $null
$script:GhRepo  = 'AkimistTemperor/akenetic'
if (Test-Path -LiteralPath $GitHubFile) {
    try { $script:GhRepo = (Get-Content -LiteralPath $GitHubFile -Raw -Encoding UTF8 | ConvertFrom-Json).repo } catch {}
}

function New-SecretKeys([string]$pass, [byte[]]$salt) {
    $k = [Security.Cryptography.Rfc2898DeriveBytes]::new($pass, $salt, 100000).GetBytes(64)
    @{ Enc = [byte[]]$k[0..31]; Mac = [byte[]]$k[32..63] }
}

function Site-Url {
    $owner, $name = $script:GhRepo -split '/', 2
    if ($name -ieq "$owner.github.io") { "https://$($owner.ToLower()).github.io/" } else { "https://$($owner.ToLower()).github.io/$name/" }
}

function Get-GitBlobSha([byte[]]$bytes) {
    $hdr = [Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)`0")
    $sha = [Security.Cryptography.SHA1]::Create()
    [void]$sha.TransformBlock($hdr, 0, $hdr.Length, $null, 0)
    [void]$sha.TransformFinalBlock($bytes, 0, $bytes.Length)
    ($sha.Hash | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Invoke-GitHub([string]$method, [string]$path, $body = $null, [switch]$Anonymous) {
    $h = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'AKENETIC-Terminal'; 'X-GitHub-Api-Version' = '2022-11-28' }
    if (-not $Anonymous) { $h.Authorization = "Bearer $script:GhToken" }
    $req = @{ Method = $method; Uri = "https://api.github.com$path"; Headers = $h; TimeoutSec = 60 }
    if ($null -ne $body) {
        $req.Body = [Text.Encoding]::UTF8.GetBytes(($body | ConvertTo-Json -Compress -Depth 10))
        $req.ContentType = 'application/json'
    }
    Invoke-RestMethod @req
}

function Get-GhStatus($e) { try { [int]$e.Exception.Response.StatusCode } catch { 0 } }

function Get-GhError($e) {
    switch (Get-GhStatus $e) {
        401     { 'Token invalido ou expirado. Crie outro e rode: site config' }
        403     { 'O token nao tem permissao. Ele precisa de "Contents: Read and write" nesse repositorio.' }
        404     { "Repositorio $script:GhRepo nao encontrado (ou o token nao tem acesso a ele)." }
        409     { 'O site mudou enquanto enviava. Tente de novo.' }
        422     { 'O GitHub recusou o arquivo (talvez grande demais).' }
        0       { 'Sem conexao com o GitHub. Tem internet?' }
        default { "Falha no GitHub: $($e.Exception.Message)" }
    }
}

function Unlock-GitHub {
    if ($script:GhToken) { return $true }
    if (-not (Test-Path -LiteralPath $GitHubFile)) { Err "Primeiro configure o token: site config"; return $false }
    try {
        $cfg  = Get-Content -LiteralPath $GitHubFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $pass = Read-Secret '  Senha mestra do GitHub: '
        $keys = New-SecretKeys $pass ([Convert]::FromBase64String($cfg.s))
        $tok  = Unprotect-Bytes ([Convert]::FromBase64String($cfg.d)) $keys
        if ($null -eq $tok) { Err 'Senha mestra errada.'; return $false }
        $script:GhToken = [Text.Encoding]::UTF8.GetString($tok)
        $script:GhRepo  = $cfg.repo
        $true
    } catch { Err 'O arquivo github.dat esta corrompido. Rode: site config'; $false }
}

function Site-Config {
    Write-Host ''
    Box @('CONFIGURAR PUBLICACAO NO GITHUB',
          'Voce precisa de um token "fine-grained" do GitHub com',
          'permissao "Contents: Read and write" no repositorio do site.',
          'Ele fica salvo CRIPTOGRAFADO no pendrive com uma senha sua.')
    Write-Host ''
    $repo = Ask 'Repositorio (usuario/nome)' $script:GhRepo
    if ($repo -notmatch '^[\w.-]+/[\w.-]+$') { Err 'Use o formato usuario/repositorio, ex: AkimistTemperor/akenetic'; return }
    $tok = (Read-Secret '  Cole o token (botao direito ou Ctrl+V): ').Trim()
    if ($tok.Length -lt 20) { Err 'Isso nao parece um token do GitHub.'; return }

    $script:GhToken = $tok; $script:GhRepo = $repo
    Spin 'Testando o token...' 300
    try { [void](Invoke-GitHub GET "/repos/$repo") }
    catch { Err (Get-GhError $_); $script:GhToken = $null; return }
    Write-Host '  √ token aceito pelo GitHub' -ForegroundColor Green

    $p1 = Read-Secret '  Crie uma senha mestra (6+ caracteres): '
    if ($p1.Length -lt 6) { Err 'Senha muito curta.'; $script:GhToken = $null; return }
    $p2 = Read-Secret '  Repita a senha mestra: '
    if ($p1 -cne $p2) { Err 'As senhas nao batem.'; $script:GhToken = $null; return }

    Spin 'Criptografando o token...' 300
    $salt = New-Object byte[] 16
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)
    $data = Protect-Bytes ([Text.Encoding]::UTF8.GetBytes($tok)) (New-SecretKeys $p1 $salt)
    @{ repo = $repo; s = [Convert]::ToBase64String($salt); d = [Convert]::ToBase64String($data) } |
        ConvertTo-Json | Set-Content -LiteralPath $GitHubFile -Encoding UTF8
    Bot "Configurado! Agora e so usar 'site publicar'."
    Sfx ok
}

# tudo que vai pro site: os arquivos de D:\Celular (app do celular) e, em pc/,
# o terminal que os amigos baixam com 'atualizar'
function Get-SiteFiles {
    $list = @()
    foreach ($f in Get-ChildItem -LiteralPath "$Drive\Celular" -File -ErrorAction SilentlyContinue) {
        if ($f.Name -ieq 'akenetic.html') { continue }
        $list += @{ Path = $f.Name; File = $f.FullName }
    }
    $list += @{ Path = 'pc/terminal.ps1'; File = Join-Path $Root 'terminal.ps1' }
    $list += @{ Path = 'pc/ABRIR TERMINAL.bat'; File = "$Drive\ABRIR TERMINAL.bat" }
    $list
}

function Get-RemoteTree([switch]$Anonymous) {
    $repo   = Invoke-GitHub GET "/repos/$script:GhRepo" -Anonymous:$Anonymous
    $ref    = Invoke-GitHub GET "/repos/$script:GhRepo/git/ref/heads/$($repo.default_branch)" -Anonymous:$Anonymous
    $commit = Invoke-GitHub GET "/repos/$script:GhRepo/git/commits/$($ref.object.sha)" -Anonymous:$Anonymous
    $tree   = Invoke-GitHub GET "/repos/$script:GhRepo/git/trees/$($commit.tree.sha)?recursive=1" -Anonymous:$Anonymous
    $files  = New-Object Collections.Hashtable ([StringComparer]::Ordinal)
    foreach ($t in $tree.tree) { if ($t.type -eq 'blob') { $files[$t.path] = $t.sha } }
    @{ Branch = $repo.default_branch; Commit = $ref.object.sha; Tree = $commit.tree.sha; Files = $files }
}

function Site-Status {
    Write-Host ''
    Write-Host '  Site         ' -NoNewline -ForegroundColor $script:T.A; Write-Host (Site-Url) -ForegroundColor White
    Write-Host '  Repositorio  ' -NoNewline -ForegroundColor $script:T.A; Write-Host $script:GhRepo -ForegroundColor $script:T.T
    $cfg = 'nao configurado (use: site config)'; if (Test-Path -LiteralPath $GitHubFile) { $cfg = 'configurado e criptografado' }
    Write-Host '  Token        ' -NoNewline -ForegroundColor $script:T.A; Write-Host $cfg -ForegroundColor $script:T.T
    Write-Host '  Terminal     ' -NoNewline -ForegroundColor $script:T.A; Write-Host "v$Version" -ForegroundColor $script:T.T
    Spin 'Comparando com o site publicado...' 400
    try { $remote = Get-RemoteTree -Anonymous } catch { Err (Get-GhError $_); return }
    $pending = 0
    Write-Host ''
    foreach ($f in Get-SiteFiles) {
        if (-not (Test-Path -LiteralPath $f.File)) { continue }
        $sha = Get-GitBlobSha ([IO.File]::ReadAllBytes($f.File))
        if (-not $remote.Files.ContainsKey($f.Path)) { $tag = '  + novo     '; $c = 'Yellow'; $pending++ }
        elseif ($remote.Files[$f.Path] -ne $sha)   { $tag = '  ~ mudou    '; $c = 'Yellow'; $pending++ }
        else                                       { $tag = '  √ igual    '; $c = 'Green' }
        Write-Host $tag -NoNewline -ForegroundColor $c
        Write-Host $f.Path -ForegroundColor $script:T.T
    }
    Write-Host ''
    if ($pending) { Write-Host "  ! $pending arquivo(s) para enviar. Use 'site publicar'" -ForegroundColor Yellow }
    else { Write-Host '  √ o site esta igual ao pendrive' -ForegroundColor Green }
}

function Site-Publish([string]$msg) {
    $sent = Publish-Files (Get-SiteFiles) $msg
    if ($sent | Where-Object { $_.Path -eq 'pc/terminal.ps1' }) {
        Bot "Seus amigos ja podem digitar 'atualizar' para receber a v$Version."
    }
}

# envia so o que mudou, tudo num commit (API Git Data: blobs -> tree -> commit -> ref);
# devolve os arquivos enviados (vazio se nada mudou ou se deu erro)
function Publish-Files($files, [string]$msg) {
    if (-not (Unlock-GitHub)) { return }
    Write-Host ''
    Spin 'Conectando ao GitHub...' 400
    try { $remote = Get-RemoteTree } catch { Err (Get-GhError $_); return }
    $changed = @(foreach ($f in $files) {
        if (-not (Test-Path -LiteralPath $f.File)) { continue }
        $bytes = [IO.File]::ReadAllBytes($f.File)
        if ($remote.Files[$f.Path] -ne (Get-GitBlobSha $bytes)) { $f.Bytes = $bytes; $f }
    })
    if (-not $changed.Count) { Bot 'Tudo ja esta publicado. Nada para enviar.'; Sfx ok; return }
    foreach ($f in $changed) {
        Write-Host '  + ' -NoNewline -ForegroundColor $script:T.P
        Write-Host ('{0}  ({1})' -f $f.Path, (Format-Size $f.Bytes.Length)) -ForegroundColor $script:T.T
    }
    if (-not $msg) { $msg = "AKENETIC v$Version - $(Get-Date -Format 'dd/MM/yyyy HH:mm')" }
    try {
        $entries = @(); $i = 0
        foreach ($f in $changed) {
            $i++
            Write-Host ("`r  Enviando {0}/{1}: {2}" -f $i, $changed.Count, $f.Path).PadRight(60) -NoNewline -ForegroundColor $script:T.A
            $blob = Invoke-GitHub POST "/repos/$script:GhRepo/git/blobs" @{ content = [Convert]::ToBase64String($f.Bytes); encoding = 'base64' }
            $entries += @{ path = $f.Path; mode = '100644'; type = 'blob'; sha = $blob.sha }
            Sfx tick
        }
        Write-Host ''
        $tree   = Invoke-GitHub POST "/repos/$script:GhRepo/git/trees" @{ base_tree = $remote.Tree; tree = $entries }
        $commit = Invoke-GitHub POST "/repos/$script:GhRepo/git/commits" @{ message = $msg; tree = $tree.sha; parents = @($remote.Commit) }
        [void](Invoke-GitHub PATCH "/repos/$script:GhRepo/git/refs/heads/$($remote.Branch)" @{ sha = $commit.sha })
    } catch { Write-Host ''; Err (Get-GhError $_); return }
    Write-Host '  √ enviado! commit ' -NoNewline -ForegroundColor Green
    Write-Host $commit.sha.Substring(0, 7) -ForegroundColor White
    Sfx ok
    $check = $changed | Where-Object { $_.Path -eq 'index.html' } | Select-Object -First 1
    if (-not $check) { $check = $changed[0] }
    Wait-Site $check.Path $check.Bytes
    $changed
}

# ----------------------------------------------------------------- avisos gerais
# O premium publica aviso.json no site; celulares e pendrives conferem ao abrir
# e a cada 3 minutos. So quem tem o token consegue publicar, entao nao da pra falsificar.
$AvisoFile = "$Drive\Celular\aviso.json"
$script:AvisoChecked = [DateTime]::MinValue

function Wrap-Text([string]$text, [int]$width) {
    $lines = @(); $cur = ''
    foreach ($w in ($text -split '\s+')) {
        if ($cur -and ($cur.Length + 1 + $w.Length) -gt $width) { $lines += $cur; $cur = $w }
        elseif ($cur) { $cur += " $w" } else { $cur = $w }
    }
    if ($cur) { $lines += $cur }
    $lines
}

function Get-Aviso([int]$timeout = 4000) {
    try {
        $req = [Net.HttpWebRequest]::Create("$($SiteBase)aviso.json?akn=$([DateTime]::UtcNow.Ticks)")
        $req.Timeout = $timeout; $req.ReadWriteTimeout = $timeout; $req.UserAgent = 'AKENETIC'
        $resp = $req.GetResponse()
        $rd = New-Object IO.StreamReader($resp.GetResponseStream(), [Text.Encoding]::UTF8)
        $a = $rd.ReadToEnd().TrimStart([char]0xFEFF) | ConvertFrom-Json; $resp.Close()
        if (-not $a.texto -or -not $a.id) { return $null }
        if ($a.ate -and [long]$a.ate -lt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) { return $null }
        $a
    } catch { $null }
}

function Show-Aviso($a, [switch]$Quiet) {
    $when = ''
    try { $when = [DateTimeOffset]::FromUnixTimeSeconds([long]$a.data).LocalDateTime.ToString('dd/MM/yyyy HH:mm') } catch {}
    $lines = @('>>> AVISO DO CRIADOR DO AKENETIC <<<', '') + @(Wrap-Text (Clean ([string]$a.texto)) 56) + @('', $when)
    Write-Host ''
    Box $lines 'Yellow' 'White'
    if ($Quiet) { return }
    $pos = [Console]::CursorTop - ($lines.Count + 2)
    for ($b = 0; $b -lt 6; $b++) {
        $c = 'Yellow'; if ($b % 2 -eq 0) { $c = 'DarkYellow' }
        try { [Console]::SetCursorPosition(0, $pos); Box $lines $c 'White' } catch {}
        Play 880,60
        Start-Sleep -Milliseconds 110
    }
    Play 523,100,659,100,784,100,1047,300
}

# chamado ao abrir e antes de cada comando; so vai na internet a cada 3 minutos
function Check-Aviso {
    if (((Get-Date) - $script:AvisoChecked).TotalSeconds -lt 180) { return }
    $script:AvisoChecked = Get-Date
    $a = Get-Aviso 2500
    if ($a -and [string]$a.id -ne $script:AvisoSeen) {
        Show-Aviso $a
        $script:AvisoSeen = [string]$a.id; Save-Config
    }
}

function Aviso([string]$arg) {
    if (-not $arg) {
        Spin 'Buscando o aviso atual...' 400
        $a = Get-Aviso
        if ($a) { Show-Aviso $a -Quiet; Write-Host '  (para tirar do ar: aviso apagar)' -ForegroundColor DarkGray }
        else { Bot 'Nenhum aviso no ar agora.' }
        Write-Host '  Use: aviso <texto>   |   aviso 3d <texto> (vale 3 dias, padrao 7)   |   aviso apagar' -ForegroundColor DarkGray
        return
    }
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($arg -match '^(apagar|remover|limpar)$') {
        $obj = [ordered]@{ id = "$now"; texto = ''; data = $now; ate = 0 }
        $what = 'Aviso removido'
    } else {
        $dias = 7
        if ($arg -match '^\[?(\d{1,2})d\]?(\s+(.*))?$') { $dias = [math]::Max(1, [int]$Matches[1]); $arg = $Matches[3] }
        $texto = Cut $arg 500
        if ($texto.Length -lt 3 -or $texto -match '^<?texto>?$') {
            Err 'Escreva o aviso depois do comando. Ex: aviso Sessao de RPG hoje as 20h!   ou   aviso 2d Manutencao amanha'
            return
        }
        $obj = [ordered]@{ id = "$now"; texto = $texto; data = $now; ate = $now + $dias * 86400 }
        Show-Aviso $obj -Quiet
        Write-Host "  Vale por $dias dia(s). Enviar para TODOS os celulares e pendrives? (s/n): " -NoNewline -ForegroundColor Yellow
        if ([Console]::ReadLine() -notmatch '^s') { Bot 'Cancelado.'; return }
        $what = 'Aviso enviado'
    }
    [IO.File]::WriteAllText($AvisoFile, ($obj | ConvertTo-Json -Compress), (New-Object Text.UTF8Encoding $false))
    $sent = Publish-Files @(@{ Path = 'aviso.json'; File = $AvisoFile }) "AKENETIC: $($what.ToLower())"
    if ($sent) {
        $script:AvisoSeen = $obj.id; Save-Config
        Bot "$what! Os celulares e pendrives veem ao abrir ou em ate 3 minutos."
    }
}

# o GitHub Pages leva ~1 min pra publicar; confere o site de verdade ate ele bater com o arquivo
function Wait-Site([string]$path, [byte[]]$bytes) {
    $url = Site-Url
    $fileUrl = $url + (($path -split '/' | ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/')
    $want = [Convert]::ToBase64String([Security.Cryptography.SHA256]::Create().ComputeHash($bytes))
    $frames = '|', '/', '-', '\'; $i = 0; $ok = $false
    $start = Get-Date; $next = $start
    Cursor $false
    while (((Get-Date) - $start).TotalSeconds -lt 180) {
        if ((Get-Date) -ge $next) {
            $next = (Get-Date).AddSeconds(6)
            try {
                $live = (New-Object Net.WebClient).DownloadData("$($fileUrl)?akn=$([DateTime]::UtcNow.Ticks)")
                if ([Convert]::ToBase64String([Security.Cryptography.SHA256]::Create().ComputeHash($live)) -eq $want) { $ok = $true; break }
            } catch {}
        }
        $secs = [int]((Get-Date) - $start).TotalSeconds
        Write-Host ("`r  {0} GitHub Pages publicando... {1}s   " -f $frames[$i % 4], $secs) -NoNewline -ForegroundColor $script:T.A
        Start-Sleep -Milliseconds 120; $i++
    }
    Cursor $true
    if ($ok) {
        Write-Host ("`r  √ SITE NO AR com a versao nova!".PadRight(46)) -ForegroundColor Green
        Write-Host "    $url" -ForegroundColor White
        Write-Host '    (no celular, feche e abra o app para pegar a versao nova)' -ForegroundColor DarkGray
        Play 784,90,988,90,1175,90,1568,260
    } else {
        Write-Host ("`r  ! o GitHub ainda esta publicando. Em alguns minutos estara no ar.".PadRight(70)) -ForegroundColor Yellow
        Write-Host "    $url" -ForegroundColor White
    }
}

function Site([string]$arg) {
    $sub, $rest = $arg -split '\s+', 2
    switch -Regex ($sub.ToLower()) {
        '^$'                  { Site-Status; break }
        '^(publicar|enviar)$' { Site-Publish $rest; break }
        '^config$'            { Site-Config; break }
        '^abrir$'             { Start-Process (Site-Url); Bot 'Abrindo o site no navegador...'; break }
        '^(sair|trancar)$'    { $script:GhToken = $null; Bot 'Token apagado da memoria. Vai pedir a senha mestra de novo.'; break }
        default               { Err 'Use: site | site publicar [mensagem] | site config | site abrir | site trancar' }
    }
}

# ----------------------------------------------------------------- backup do premium
# Um arquivo .aknbak com tudo que so existe no pendrive (chave premium, token,
# notas, ficha, historico, config) + o proprio terminal e o app do celular.
# Formato: "AKNBKP1" | salt(16) | zip cifrado (PBKDF2 100k + AES-256 + HMAC).
$BackupMagic = 'AKNBKP1'

function Get-PremiumFiles {
    $list = @()
    foreach ($n in 'terminal.ps1', 'premium.key', 'github.dat', 'config.txt', 'notas.txt', 'ficha.json') {
        $f = Join-Path $Root $n
        if (Test-Path -LiteralPath $f) { $list += @{ Rel = "Terminal/$n"; File = $f } }
    }
    $bat = "$Drive\ABRIR TERMINAL.bat"
    if (Test-Path -LiteralPath $bat) { $list += @{ Rel = 'ABRIR TERMINAL.bat'; File = $bat } }
    foreach ($dir in 'Celular', 'Conversas') {
        foreach ($f in Get-ChildItem -LiteralPath "$Drive\$dir" -File -ErrorAction SilentlyContinue) {
            $list += @{ Rel = "$dir/$($f.Name)"; File = $f.FullName }
        }
    }
    $list
}

function Confirm-Yes([string]$question) {
    Write-Host "  $question (s/n): " -NoNewline -ForegroundColor Yellow
    [Console]::ReadLine() -match '^s'
}

function Backup-Premium([string]$dest) {
    $files = @(Get-PremiumFiles)
    Write-Host ''
    Box @('BACKUP DO PREMIUM',
          'Gera UM arquivo criptografado com tudo que so existe neste',
          'pendrive. Guarde no PC, no Google Drive ou no seu e-mail.')
    Write-Host ''
    foreach ($f in $files) {
        Write-Host '  + ' -NoNewline -ForegroundColor $script:T.P
        Write-Host $f.Rel -ForegroundColor $script:T.T
    }
    Write-Host ''
    if (-not $dest) { $dest = [Environment]::GetFolderPath('Desktop') }
    $dest = $dest.Trim('"')
    if (-not (Test-Path -LiteralPath $dest -PathType Container)) { Err "Pasta nao encontrada: $dest"; return }
    $dest = (Resolve-Path -LiteralPath $dest).ProviderPath
    if ($dest.StartsWith($Drive, [StringComparison]::OrdinalIgnoreCase)) { Err 'Salve o backup FORA do pendrive, senao ele some junto. Ex: backup-premium C:\Users\voce\Documents'; return }

    Write-Host '  Crie uma senha SO para este backup. Sem ela nao da para restaurar!' -ForegroundColor Yellow
    $p1 = Read-Secret '  Senha do backup (8+ caracteres): '
    if ($p1.Length -lt 8) { Err 'Senha muito curta (minimo 8).'; return }
    $p2 = Read-Secret '  Repita a senha: '
    if ($p1 -cne $p2) { Err 'As senhas nao batem.'; return }

    try {
        Show-Bar 'Compactando arquivos' 500
        Add-Type -AssemblyName System.IO.Compression
        $ms  = New-Object IO.MemoryStream
        $zip = [IO.Compression.ZipArchive]::new($ms, [IO.Compression.ZipArchiveMode]::Create, $true)
        foreach ($f in $files) {
            $s = $zip.CreateEntry($f.Rel, [IO.Compression.CompressionLevel]::Optimal).Open()
            $b = [IO.File]::ReadAllBytes($f.File); $s.Write($b, 0, $b.Length); $s.Close()
        }
        $zip.Dispose()
        Show-Bar 'Criptografando' 500
        $salt = New-Object byte[] 16
        [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)
        $enc  = Protect-Bytes $ms.ToArray() (New-SecretKeys $p1 $salt)
        $out  = Join-Path $dest ('AKENETIC-premium-{0}.aknbak' -f (Get-Date -Format 'yyyy-MM-dd_HHmm'))
        $magic = [Text.Encoding]::ASCII.GetBytes($BackupMagic)
        $fs = [IO.File]::Create($out)
        $fs.Write($magic, 0, $magic.Length); $fs.Write($salt, 0, 16); $fs.Write($enc, 0, $enc.Length); $fs.Close()
    } catch { Err "Nao consegui criar o backup: $($_.Exception.Message)"; return }

    Write-Host ''
    Box @('BACKUP CRIADO!', $out, ('{0} arquivos  ·  {1}' -f $files.Count, (Format-Size (Get-Item -LiteralPath $out).Length))) 'Green' 'White'
    Bot 'Mande esse arquivo pro seu Google Drive ou e-mail. Num pendrive novo: restaurar <arquivo>'
    Play 784,90,988,90,1175,90,1568,260
}

# funciona em qualquer edicao: num pendrive novo voce ainda nao tem o premium
function Restore-Premium([string]$path) {
    $path = $path.Trim().Trim('"')
    if (-not $path) {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $dlg = New-Object Windows.Forms.OpenFileDialog
            $dlg.Title = 'AKENETIC - escolha o backup (.aknbak)'; $dlg.Filter = 'Backup AKENETIC (*.aknbak)|*.aknbak|Todos (*.*)|*.*'
            $owner = New-Object Windows.Forms.Form -Property @{ TopMost = $true }
            $ok = $dlg.ShowDialog($owner); $owner.Dispose()
            if ($ok -ne 'OK') { return }
            $path = $dlg.FileName
        } catch { Err 'Use: restaurar C:\caminho\AKENETIC-premium-....aknbak'; return }
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Err "Arquivo nao encontrado: $path"; return }
    $all = [IO.File]::ReadAllBytes($path)
    if ($all.Length -lt 100 -or [Text.Encoding]::ASCII.GetString($all, 0, 7) -ne $BackupMagic) { Err 'Esse arquivo nao e um backup do AKENETIC.'; return }
    $salt = New-Object byte[] 16; [Array]::Copy($all, 7, $salt, 0, 16)
    $data = New-Object byte[] ($all.Length - 23); [Array]::Copy($all, 23, $data, 0, $data.Length)

    Write-Host ''
    $pass = Read-Secret '  Senha do backup: '
    Spin 'Abrindo o backup...' 400
    $zipBytes = Unprotect-Bytes $data (New-SecretKeys $pass $salt)
    if ($null -eq $zipBytes) { Err 'Senha errada (ou arquivo corrompido).'; return }

    Add-Type -AssemblyName System.IO.Compression
    $zip = [IO.Compression.ZipArchive]::new([IO.MemoryStream]::new($zipBytes), [IO.Compression.ZipArchiveMode]::Read)
    # so aceita caminhos relativos e sem '..', para nada sair do pendrive
    $entries = @($zip.Entries | Where-Object { $_.Name -and $_.FullName -notmatch '(^|[\\/])\.\.([\\/]|$)' -and $_.FullName -notmatch '^[\\/]|:' })
    Write-Host ''
    foreach ($e in $entries) {
        Write-Host '  > ' -NoNewline -ForegroundColor $script:T.P
        Write-Host $e.FullName -ForegroundColor $script:T.T
    }
    Write-Host ''
    if (-not (Confirm-Yes "Gravar esses $($entries.Count) arquivos em ${Drive}? (os atuais viram .antes)")) { $zip.Dispose(); Bot 'Cancelado.'; return }
    try {
        foreach ($e in $entries) {
            $target = Join-Path "$Drive\" ($e.FullName -replace '/', '\')
            $dir = Split-Path $target
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory $dir -Force | Out-Null }
            if (Test-Path -LiteralPath $target) { Copy-Item -LiteralPath $target "$target.antes" -Force }
            $s = $e.Open(); $fs = [IO.File]::Create($target); $s.CopyTo($fs); $fs.Close(); $s.Close()
        }
    } catch { $zip.Dispose(); Err "Falha ao restaurar: $($_.Exception.Message)"; return }
    $zip.Dispose()
    Show-Bar 'Restaurando' 500
    Bot 'Restauracao concluida! Reiniciando o AKENETIC...'
    Play 523,90,659,90,784,90,1047,220
    Start-Sleep -Milliseconds 600
    Start-Process -FilePath "$Drive\ABRIR TERMINAL.bat" -WorkingDirectory "$Drive\"
    Set-Location $env:TEMP
    exit
}

# ----------------------------------------------------------------- atualizacao automatica
# Baixa pc/terminal.ps1 do site; so instala se o arquivo for um AKENETIC valido
# (sem erro de sintaxe) e guarda o anterior em terminal.ps1.bak.
function Get-RemoteTerminal([int]$timeout = 8000) {
    try {
        $req = [Net.HttpWebRequest]::Create("$($UpdateBase)terminal.ps1?akn=$([DateTime]::UtcNow.Ticks)")
        $req.Timeout = $timeout; $req.ReadWriteTimeout = $timeout; $req.UserAgent = 'AKENETIC'
        $resp = $req.GetResponse(); $ms = New-Object IO.MemoryStream
        $resp.GetResponseStream().CopyTo($ms); $resp.Close()
        $bytes = $ms.ToArray()
        $text  = [Text.Encoding]::UTF8.GetString($bytes)
        $ver = '?'; if ($text -match "(?m)^\`$Version\s*=\s*'([^']+)'") { $ver = $Matches[1] }
        @{ Bytes = $bytes; Text = $text; Version = $ver }
    } catch { $null }
}

function Same-Bytes([byte[]]$a, [byte[]]$b) {
    $h = [Security.Cryptography.SHA256]::Create()
    [Convert]::ToBase64String($h.ComputeHash($a)) -eq [Convert]::ToBase64String($h.ComputeHash($b))
}

function Update-Terminal {
    if ($IsPremium) {
        Bot "Voce e o dono do AKENETIC: sua versao e a original (v$Version)."
        Write-Host "  Para mandar ela pros amigos use: site publicar" -ForegroundColor DarkGray
        return
    }
    Write-Host ''
    Spin 'Procurando versao nova...' 500
    $remote = Get-RemoteTerminal
    if (-not $remote) { Err 'Nao consegui acessar o servidor de atualizacao. Tem internet?'; return }
    $mine = Join-Path $Root 'terminal.ps1'
    if (Same-Bytes $remote.Bytes ([IO.File]::ReadAllBytes($mine))) { Bot "Voce ja tem a versao mais nova (v$Version)."; Sfx ok; return }

    $errs = $null
    [void][Management.Automation.Language.Parser]::ParseInput($remote.Text, [ref]$null, [ref]$errs)
    if ($errs -or $remote.Text -notmatch 'AKENETIC TERMINAL') { Err 'O arquivo baixado veio com defeito. Nada foi alterado.'; return }

    Box @("Nova versao disponivel: v$($remote.Version)", "Voce tem: v$Version")
    Write-Host '  Instalar agora? (s/n): ' -NoNewline -ForegroundColor Yellow
    if ([Console]::ReadLine() -notmatch '^s') { return }
    try {
        Copy-Item -LiteralPath $mine "$mine.bak" -Force
        [IO.File]::WriteAllBytes($mine, $remote.Bytes)
    } catch { Err "Nao consegui instalar: $($_.Exception.Message)"; return }
    Show-Bar 'Instalando atualizacao' 600
    Bot 'Atualizado! Reiniciando o AKENETIC...'
    Play 523,90,659,90,784,90,1047,220
    Start-Sleep -Milliseconds 600
    Start-Process -FilePath "$Drive\ABRIR TERMINAL.bat" -WorkingDirectory "$Drive\"
    Set-Location $env:TEMP
    exit
}

function Write-Prompt {
    Write-Host ''
    Write-Host '  ┌─[' -NoNewline -ForegroundColor $script:T.S
    Write-Host 'AKENETIC' -NoNewline -ForegroundColor $script:T.P
    Write-Host ']─[' -NoNewline -ForegroundColor $script:T.S
    Write-Host (Get-Location).ProviderPath -NoNewline -ForegroundColor $script:T.A
    Write-Host ']─[' -NoNewline -ForegroundColor $script:T.S
    Write-Host (Get-Date -Format 'HH:mm') -NoNewline -ForegroundColor DarkGray
    Write-Host ']' -ForegroundColor $script:T.S
    Write-Host '  └─» ' -NoNewline -ForegroundColor $script:T.S
    [Console]::ForegroundColor = 'White'
}

# ----------------------------------------------------------------- inicializacao
Set-Location "$Drive\"
Clear-Host
Cursor $false
Write-Host ''
Type-Out '  Inicializando AKENETIC OS...' $script:T.P 22
Write-Host ''
Show-Bar 'Carregando kernel' 500
Show-Bar 'Montando pendrive' 400
Show-Bar 'Calibrando cores' 400
Show-Bar 'Afinando alto-falante' 300
Sfx boot

# abertura: nome ondulando no centro da tela
Clear-Host
for ($i = 0; $i -lt [math]::Max(0, [int](([Console]::WindowHeight - 14) / 2)); $i++) { Write-Host '' }
Show-Banner -Animated
if ($IsPremium) { Type-Center '*  EDICAO PREMIUM  *' 'Yellow' 30 }
Type-Center 'terminal portatil  ·  leve para qualquer PC' $script:T.A 18
Start-Sleep -Milliseconds 900

Show-Header
Write-Host ''
Bot "Ola, $env:USERNAME! Bem-vindo ao seu terminal."
if ((Get-Suspects).Count) { Err "Achei arquivos suspeitos na raiz do pendrive. Digite 'vacina'." }
if (-not $IsPremium) {
    $upd = Get-RemoteTerminal 2500
    if ($upd -and -not (Same-Bytes $upd.Bytes ([IO.File]::ReadAllBytes((Join-Path $Root 'terminal.ps1'))))) {
        Write-Host "  [*] Versao nova do AKENETIC disponivel (v$($upd.Version)). Digite 'atualizar'." -ForegroundColor Yellow
        Play 1047,60,1319,90
    }
}
Check-Aviso
Cursor $true

# ----------------------------------------------------------------- loop principal
while ($true) {
    Check-Aviso
    Write-Prompt
    $line = [Console]::ReadLine()
    [Console]::ForegroundColor = 'Gray'
    if ($null -eq $line) { break }
    $line = $line.Trim()
    if (-not $line) { continue }
    $script:History.Add($line)
    Sfx enter

    $cmd, $rest = $line -split '\s+', 2
    $arg = ''; if ($rest) { $arg = $rest.Trim() }

    switch -Regex ($cmd.ToLower()) {
        '^(ajuda|help|\?)$'     { Show-Help; break }
        '^(limpar|cls|clear)$'  { Show-Header; break }
        '^(hora|data)$'         { Write-Host ''; Type-Out ('  ' + (Get-Date -Format "dddd, dd 'de' MMMM 'de' yyyy  -  HH:mm:ss")) $script:T.A 10; break }
        '^sistema$'             { Show-System; break }
        '^vacina$'              { Vaccine; break }
        '^apps?$'               { Apps $arg; break }
        '^backup$'              { Backup $arg; break }
        '^(ejetar|eject)$'      { Eject; break }
        '^(chat|sala)$'         { Open-ChatRoom; Show-Header; break }
        '^compartilhar$'        { Share $arg; break }
        '^site$'                { if ($IsPremium) { Site $arg } else { Err 'Comando exclusivo da edicao premium.' }; break }
        '^atualizar$'           { Update-Terminal; break }
        '^aviso$'               { if ($IsPremium) { Aviso $arg } else { Err 'Comando exclusivo da edicao premium.' }; break }
        '^backup-premium$'      { if ($IsPremium) { Backup-Premium $arg } else { Err 'Comando exclusivo da edicao premium.' }; break }
        '^restaurar$'           { Restore-Premium $arg; break }
        '^pendrive$'            { Show-Pendrive; break }
        '^(ls|dir)$'            { if ($arg) { Run-Cmd $line } else { Show-Files }; break }
        '^cd$' {
            if (-not $arg) { Write-Host "  $((Get-Location).ProviderPath)" -ForegroundColor $script:T.A }
            else { try { Set-Location -LiteralPath $arg -ErrorAction Stop; Sfx tick } catch { Err "Pasta nao encontrada: $arg" } }
            break
        }
        '^cd\.\.$'              { Set-Location ..; Sfx tick; break }
        '^[a-z]:$'              { try { Set-Location "$cmd\" -ErrorAction Stop; Sfx tick } catch { Err "Unidade $cmd nao existe." }; break }
        '^nota$' {
            if (-not $arg) { Err 'Escreva algo: nota comprar pao'; break }
            Add-Content $NotesFile ("[{0}] {1}" -f (Get-Date -Format 'dd/MM/yyyy HH:mm'), $arg) -Encoding UTF8
            Bot 'Anotado e salvo no pendrive!'; Sfx ok; break
        }
        '^notas$' {
            if (-not (Test-Path $NotesFile)) { Bot "Nenhuma nota ainda. Use: nota <texto>"; break }
            Write-Host ''
            foreach ($n in Get-Content $NotesFile -Encoding UTF8) { Type-Out "  $n" $script:T.T 4 }
            break
        }
        '^calc$' {
            if ($arg -notmatch '^[\d\s\.,\+\-\*/\(\)%]+$') { Err 'Use so numeros e + - * / ( ) %   ex: calc 10*(2+3)'; break }
            try {
                $r = (New-Object System.Data.DataTable).Compute(($arg -replace ',', '.'), $null)
                Write-Host '  = ' -NoNewline -ForegroundColor $script:T.S
                Type-Out "$r" $script:T.A 20; Sfx ok
            } catch { Err 'Conta invalida.' }
            break
        }
        '^dado$'                { Roll-Dice $arg; break }
        '^piada$'               { Write-Host ''; Bot ($Jokes | Get-Random); Play 523,80,659,80,784,120; break }
        '^matrix$'              { Matrix; break }
        '^hack$'                { Hack; break }
        '^(musica|música)$'     { Music; break }
        '^tema$'                { if ($arg) { Set-Theme $arg } else { Bot "Temas: $($Themes.Keys -join ', ')  (atual: $script:ThemeName)" }; break }
        '^som$' {
            if ($arg -eq 'off') { $script:SoundOn = $false; Bot 'Sons desligados.' }
            elseif ($arg -eq 'on') { $script:SoundOn = $true; Bot 'Sons ligados!'; Sfx ok }
            else { Bot "Som esta $(if ($script:SoundOn) {'ligado'} else {'desligado'}). Use: som on | som off" }
            Save-Config; break
        }
        '^(historico|history)$' {
            Write-Host ''
            for ($i = 0; $i -lt $script:History.Count; $i++) {
                Write-Host ('  {0,3}  ' -f ($i + 1)) -NoNewline -ForegroundColor DarkGray
                Write-Host $script:History[$i] -ForegroundColor $script:T.T
            }
            break
        }
        '^(sair|exit|quit)$' {
            Cursor $false
            Write-Host ''
            Show-Bar 'Desligando AKENETIC' 500
            Sfx bye
            Clear-Host
            Show-Banner -colors @('DarkGray', 'DarkGray', 'DarkGray', 'DarkGray', 'DarkGray', 'DarkGray')
            Type-Center 'Ate a proxima!' $script:T.P 30
            Start-Sleep -Milliseconds 600
            Cursor $true
            exit
        }
        default {
            if (-not (Chat $line)) { Run-Cmd $line }
        }
    }
}

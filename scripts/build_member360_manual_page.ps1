$ErrorActionPreference = 'Stop'
$root = 'c:\Users\milvus-0\Goldendew'
$outPath = Join-Path $root 'goldendew_member360_list_manual_page_20260331.pptx'

function AddText($slide, $x, $y, $w, $h, $text, $size = 14, $bold = $false, $color = 0x323232) {
    $tb = $slide.Shapes.AddTextbox(1, $x, $y, $w, $h)
    $tb.TextFrame.TextRange.Text = $text
    $tb.TextFrame.TextRange.Font.NameFarEast = '맑은 고딕'
    $tb.TextFrame.TextRange.Font.Name = 'Malgun Gothic'
    $tb.TextFrame.TextRange.Font.Size = $size
    $tb.TextFrame.TextRange.Font.Bold = $(if($bold){-1}else{0})
    $tb.TextFrame.TextRange.Font.Color.RGB = $color
    return $tb
}

function AddNum($slide, $num, $x, $y) {
    $c = $slide.Shapes.AddShape(9, $x, $y, 24, 24)
    $c.Fill.ForeColor.RGB = 255
    $c.Line.ForeColor.RGB = 255
    $c.TextFrame.TextRange.Text = [string]$num
    $c.TextFrame.TextRange.Font.NameFarEast = '맑은 고딕'
    $c.TextFrame.TextRange.Font.Name = 'Malgun Gothic'
    $c.TextFrame.TextRange.Font.Size = 13
    $c.TextFrame.TextRange.Font.Bold = -1
    $c.TextFrame.TextRange.Font.Color.RGB = 16777215
    $c.TextFrame.HorizontalAnchor = 2
    $c.TextFrame.VerticalAnchor = 3
    return $c
}

function AddRedBox($slide, $x, $y, $w, $h) {
    $r = $slide.Shapes.AddShape(1, $x, $y, $w, $h)
    $r.Fill.Transparency = 1
    $r.Line.ForeColor.RGB = 255
    $r.Line.Weight = 2.25
    return $r
}

$ppt = New-Object -ComObject PowerPoint.Application
$ppt.Visible = -1
$pres = $ppt.Presentations.Add()
$pres.PageSetup.SlideSize = 16
$slide = $pres.Slides.Add(1, 12)

$bg = $slide.Shapes.AddShape(1, 0, 0, 960, 540)
$bg.Fill.ForeColor.RGB = 16777215
$bg.Line.Visible = 0

$header = $slide.Shapes.AddShape(1, 0, 0, 960, 50)
$header.Fill.ForeColor.RGB = 12612263
$header.Line.Visible = 0
AddText $slide 24 10 720 24 '회원 360 목록 화면 안내' 24 $true 16777215 | Out-Null

# mock screen
$screen = $slide.Shapes.AddShape(1, 25, 70, 615, 420)
$screen.Fill.ForeColor.RGB = 16777215
$screen.Line.ForeColor.RGB = 13882323
$screen.Line.Weight = 1

AddText $slide 45 83 150 26 'GOLDEN DEW' 20 $true 6579300 | Out-Null
AddText $slide 42 116 70 22 '통합뷰' 12 $true 3289650 | Out-Null
AddText $slide 132 116 65 22 '회원 360' 12 $false 6579300 | Out-Null
AddText $slide 210 116 70 22 '주문/판매' 12 $false 3289650 | Out-Null

$searchTop = $slide.Shapes.AddShape(1, 320, 82, 160, 18)
$searchTop.Fill.ForeColor.RGB = 16777215
$searchTop.Line.ForeColor.RGB = 12632256
AddText $slide 330 83 120 14 '검색...' 10 $false 8421504 | Out-Null

AddText $slide 42 145 110 18 '회원 360' 24 $true 3289650 | Out-Null
AddText $slide 42 181 240 16 '항목 157개 · 정렬 기준: 회원 번호 · 필터 기준: 회원 번호' 10 $false 8421504 | Out-Null

# list view filter/search toolbar
$toolbar = $slide.Shapes.AddShape(1, 430, 170, 170, 28)
$toolbar.Fill.ForeColor.RGB = 16777215
$toolbar.Line.ForeColor.RGB = 10197915
AddText $slide 440 175 120 16 '이 목록 검색...' 11 $false 8421504 | Out-Null

for ($i=0; $i -lt 6; $i++) {
  $icon = $slide.Shapes.AddShape(9, 604 + ($i*24), 171, 18, 18)
  $icon.Fill.ForeColor.RGB = 16777215
  $icon.Line.ForeColor.RGB = 8421504
}

# table
$tableTop = 205
$colXs = @(35, 90, 230, 290, 350, 500, 560)
$colWs = @(55, 140, 60, 60, 150, 60, 70)
$headers = @('번호','회원 번호','이름','회원 등급','이메일','생년월일','성별')
for ($i=0; $i -lt $headers.Count; $i++) {
  $cell = $slide.Shapes.AddShape(1, $colXs[$i], $tableTop, $colWs[$i], 24)
  $cell.Fill.ForeColor.RGB = 16119285
  $cell.Line.ForeColor.RGB = 13882323
  AddText $slide ($colXs[$i] + 4) ($tableTop + 4) ($colWs[$i]-8) 14 $headers[$i] 10 $true 3289650 | Out-Null
}
$rows = @(
  @('1','carson0330001','김창환','GIP','carson0330001@milvus.co.kr','7/31/1997','여'),
  @('2','carson0319002','김창환','GIP','carson031901@milvus.co.kr','7/31/1997','여'),
  @('3','269999800015','김창환','GIP','-','4/26/1998','남'),
  @('4','262001100027','조서현','SVIP','della@milvus.co.kr','10/2/1996','여'),
  @('5','262001100026','박예진','GIP','-','7/23/1996','여')
)
for ($r=0; $r -lt $rows.Count; $r++) {
  $y = $tableTop + 24 + ($r*36)
  for ($i=0; $i -lt $headers.Count; $i++) {
    $cell = $slide.Shapes.AddShape(1, $colXs[$i], $y, $colWs[$i], 36)
    $cell.Fill.ForeColor.RGB = 16777215
    $cell.Line.ForeColor.RGB = 14737632
    AddText $slide ($colXs[$i] + 4) ($y + 10) ($colWs[$i]-8) 16 $rows[$r][$i] 10 $false 5263440 | Out-Null
  }
}

# red annotation boxes
AddRedBox $slide 30 138 120 34 | Out-Null
AddNum $slide 1 18 132 | Out-Null
AddRedBox $slide 34 174 315 18 | Out-Null
AddRedBox $slide 430 170 170 28 | Out-Null
AddNum $slide 2 610 165 | Out-Null
AddRedBox $slide 35 205 595 205 | Out-Null
AddNum $slide 3 18 214 | Out-Null
AddNum $slide 4 18 420 | Out-Null

# explanation panel
$panel = $slide.Shapes.AddShape(1, 660, 70, 275, 420)
$panel.Fill.ForeColor.RGB = 16579581
$panel.Line.ForeColor.RGB = 255
$panel.Line.Weight = 1.5
AddText $slide 676 88 240 24 '화면 설명' 20 $true 255 | Out-Null

$items = @(
  '1. 회원 멤버십 목록을 볼 수 있습니다.',
  '2. 회원 360 리스트 뷰에서만 필터 조건을 걸 수 있습니다. 빨간색으로 표시한 필터 영역에서 원하는 데이터를 필터링합니다.',
  '3. 목록 검색은 회원 번호로 가능합니다.',
  '4. 회원 목록은 한 번에 최대 2,000개까지만 표시되는 점을 함께 안내합니다.'
)
$y = 126
foreach ($item in $items) {
  $box = $slide.Shapes.AddShape(1, 675, $y, 245, 72)
  $box.Fill.ForeColor.RGB = 16777215
  $box.Line.ForeColor.RGB = 14737632
  $box.TextFrame.TextRange.Text = $item
  $box.TextFrame.TextRange.Font.NameFarEast = '맑은 고딕'
  $box.TextFrame.TextRange.Font.Name = 'Malgun Gothic'
  $box.TextFrame.TextRange.Font.Size = 12
  $box.TextFrame.TextRange.Font.Color.RGB = 3289650
  $box.TextFrame.MarginLeft = 8
  $box.TextFrame.MarginRight = 8
  $box.TextFrame.MarginTop = 6
  $box.TextFrame.MarginBottom = 6
  $y += 82
}

$note = $slide.Shapes.AddShape(1, 675, 456, 245, 24)
$note.Fill.ForeColor.RGB = 16777215
$note.Line.ForeColor.RGB = 255
$note.TextFrame.TextRange.Text = '샘플 1페이지 버전 / 추후 실제 화면 캡처로 교체 가능'
$note.TextFrame.TextRange.Font.NameFarEast = '맑은 고딕'
$note.TextFrame.TextRange.Font.Name = 'Malgun Gothic'
$note.TextFrame.TextRange.Font.Size = 10
$note.TextFrame.TextRange.Font.Color.RGB = 8421504

$pres.SaveAs($outPath)
$pres.Close()
$ppt.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($pres) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($ppt) | Out-Null
Write-Output $outPath

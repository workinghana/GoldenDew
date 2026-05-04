$ErrorActionPreference = 'Stop'

$root = 'c:\Users\milvus-0\Goldendew'
$outPath = Join-Path $root 'goldendew_loyalty_operator_manual_lwc_draft_20260331_v2.pptx'

$ppt = New-Object -ComObject PowerPoint.Application
$ppt.Visible = -1
$presentation = $ppt.Presentations.Add()
$presentation.PageSetup.SlideSize = 16

function Add-TitleSlide($title, $subtitle) {
    $slide = $presentation.Slides.Add($presentation.Slides.Count + 1, 12)
    $bg = $slide.Shapes.AddShape(1, 0, 0, 960, 540)
    $bg.Fill.ForeColor.RGB = 16777215
    $bg.Line.Visible = 0

    $band = $slide.Shapes.AddShape(1, 0, 0, 960, 140)
    $band.Fill.ForeColor.RGB = 12612263
    $band.Line.Visible = 0

    $accent = $slide.Shapes.AddShape(1, 0, 140, 960, 10)
    $accent.Fill.ForeColor.RGB = 13850955
    $accent.Line.Visible = 0

    $tb = $slide.Shapes.AddTextbox(1, 70, 180, 820, 90)
    $tb.TextFrame.TextRange.Text = $title
    $tb.TextFrame.TextRange.Font.NameFarEast = '맑은 고딕'
    $tb.TextFrame.TextRange.Font.Name = 'Malgun Gothic'
    $tb.TextFrame.TextRange.Font.Size = 28
    $tb.TextFrame.TextRange.Font.Bold = -1
    $tb.TextFrame.TextRange.Font.Color.RGB = 3289650

    $sb = $slide.Shapes.AddTextbox(1, 72, 280, 760, 120)
    $sb.TextFrame.TextRange.Text = $subtitle
    $sb.TextFrame.TextRange.Font.NameFarEast = '맑은 고딕'
    $sb.TextFrame.TextRange.Font.Name = 'Malgun Gothic'
    $sb.TextFrame.TextRange.Font.Size = 16
    $sb.TextFrame.TextRange.Font.Color.RGB = 5263440
}

function Add-ContentSlide($title, $bullets, $footer) {
    $slide = $presentation.Slides.Add($presentation.Slides.Count + 1, 12)
    $bg = $slide.Shapes.AddShape(1, 0, 0, 960, 540)
    $bg.Fill.ForeColor.RGB = 16777215
    $bg.Line.Visible = 0

    $header = $slide.Shapes.AddShape(1, 0, 0, 960, 70)
    $header.Fill.ForeColor.RGB = 12612263
    $header.Line.Visible = 0

    $tb = $slide.Shapes.AddTextbox(1, 36, 16, 860, 40)
    $tb.TextFrame.TextRange.Text = $title
    $tb.TextFrame.TextRange.Font.NameFarEast = '맑은 고딕'
    $tb.TextFrame.TextRange.Font.Name = 'Malgun Gothic'
    $tb.TextFrame.TextRange.Font.Size = 24
    $tb.TextFrame.TextRange.Font.Bold = -1
    $tb.TextFrame.TextRange.Font.Color.RGB = 16777215

    $panel = $slide.Shapes.AddShape(1, 36, 95, 888, 380)
    $panel.Fill.ForeColor.RGB = 16448250
    $panel.Line.ForeColor.RGB = 14737632

    $content = $slide.Shapes.AddTextbox(1, 62, 120, 835, 330)
    $content.TextFrame.WordWrap = -1
    $content.TextFrame.AutoSize = 0
    $content.TextFrame.TextRange.Text = ($bullets -join "`r")
    $content.TextFrame.TextRange.Font.NameFarEast = '맑은 고딕'
    $content.TextFrame.TextRange.Font.Name = 'Malgun Gothic'
    $content.TextFrame.TextRange.Font.Size = 20
    $content.TextFrame.TextRange.ParagraphFormat.Bullet.Visible = -1
    $content.TextFrame.TextRange.ParagraphFormat.SpaceAfter = 8
    $content.TextFrame.TextRange.Font.Color.RGB = 3289650

    $foot = $slide.Shapes.AddTextbox(1, 40, 492, 880, 24)
    $foot.TextFrame.TextRange.Text = $footer
    $foot.TextFrame.TextRange.Font.NameFarEast = '맑은 고딕'
    $foot.TextFrame.TextRange.Font.Name = 'Malgun Gothic'
    $foot.TextFrame.TextRange.Font.Size = 10
    $foot.TextFrame.TextRange.Font.Color.RGB = 8421504
}

Add-TitleSlide '골든듀 로열티 운영자 메뉴얼' "LWC 화면 기준 초안`r운영자가 자주 사용하는 주요 화면과 작업 흐름을 중심으로 정리한 버전입니다."

Add-ContentSlide '1. 메뉴 구성' @(
    '프로모션 관리: promotionview'
    '쿠폰 관리: couponview'
    '포인트 하위 유형 관리: pointsubtypeview'
    '쿠폰/포인트 지급 대상 업로드: couponview, pointsubtypeview, couponsubtypeview'
    '회원 이력 및 운영 확인: memberHistory, logview, errorlogview'
    '이 문서는 화면 구조와 운영 포인트를 빠르게 파악하는 데 초점을 둡니다.'
) '기준 컴포넌트: promotionview / couponview / pointsubtypeview / couponsubtypeview / memberHistory / logview / errorlogview'

Add-ContentSlide '2. 프로모션 상세 화면' @(
    '상단 요약 카드에서 프로모션 코드, 명칭, 상태를 확인합니다.'
    '프로모션 정보 카드에서 운영 기간, 게시 기간, 매장 범위를 확인합니다.'
    '포인트/쿠폰 정보 카드에서 포인트 적립 가능 여부, 포인트 사용 여부, 쿠폰 사용 여부를 확인합니다.'
    '실무 체크 포인트: 프로모션 번호, 상태, 쿠폰 허용 플래그, 매장 적용 범위를 먼저 확인합니다.'
    '관련 쿠폰이나 상품이 예상과 다르면 관련 목록 데이터와 활성 여부를 함께 점검합니다.'
) '컴포넌트: force-app/main/default/lwc/promotionview'

Add-ContentSlide '3. 쿠폰 상세 화면' @(
    '쿠폰 정보 카드에서 쿠폰명, 관리코드, 사용 기간, 유형, 혜택 값, 상태를 확인합니다.'
    '우측 상단의 지급 대상 업로드 버튼으로 지급 대상 CSV 업로드 모달을 엽니다.'
    '쿠폰 사용 정책 설정 버튼으로 매장, 회원, 상품, 카테고리 등 제한 조건을 조회하고 저장합니다.'
    '정책 저장 전에는 선택된 대상이 맞는지 반드시 검토합니다.'
    '운영 시 자주 보는 값: 쿠폰 상태, 만료일, 제한 조건, 업로드 결과 건수.'
) '컴포넌트: force-app/main/default/lwc/couponview'

Add-ContentSlide '4. 포인트 하위 유형 화면' @(
    '포인트 정보 카드에서 포인트명, 우선순위, 비용을 확인합니다.'
    '보상 정보 카드에서 연결된 혜택 목록과 활성 상태를 확인합니다.'
    '지급 대상 업로드 버튼을 누르면 CSV 드래그 앤 드롭 모달이 먼저 열립니다.'
    '검증 중에는 업로드 진행 안내 문구가 노출되며, 완료 전까지 새 파일 업로드가 제한됩니다.'
    '검증 완료 후 성공/실패 건수를 보고 지급 포인트와 만료일을 설정한 뒤 지급합니다.'
) '컴포넌트: force-app/main/default/lwc/pointsubtypeview'

Add-ContentSlide '5. 지급 대상 업로드 공통 흐름' @(
    '업로드 버튼 클릭'
    '드래그 앤 드롭 또는 파일 선택으로 CSV 등록'
    '회원번호 기준 유효성 검증 진행'
    '성공/실패 건수 및 오류 사유 확인'
    '지급 값 입력 후 최종 실행'
    '권장 운영 방식: 대량 업로드 전 샘플 파일로 먼저 검증하고, 오류 회원은 재업로드 전 원인을 정리합니다.'
) '적용 화면: couponview / pointsubtypeview / couponsubtypeview'

Add-ContentSlide '6. 이력 및 로그 확인' @(
    '회원 이력 화면에서는 회원 기준 적립, 사용, 쿠폰, 주문 이력을 교차 확인합니다.'
    '운영 이상 징후가 있으면 logview 와 errorlogview 에서 에러 메시지와 처리 이력을 우선 확인합니다.'
    '배치 또는 ERP 연동 이슈는 실행 시간, 대상 번호, 오류 문구를 같이 기록해 두면 원인 파악이 빨라집니다.'
    '운영 문의 대응 시 회원번호, 주문번호, 프로모션번호, 쿠폰 관리번호를 함께 확보하는 것이 좋습니다.'
) '컴포넌트: memberHistory / logview / errorlogview'

Add-ContentSlide '7. 운영 체크리스트' @(
    '변경 전: 대상 프로모션/쿠폰/포인트의 활성 상태와 기간을 확인합니다.'
    '업로드 전: CSV 헤더와 회원번호 형식을 확인합니다.'
    '업로드 후: 성공/실패 건수와 오류 사유를 검토합니다.'
    'ERP 연동 이슈 발생 시: 실행 시각, 사용자, 로그 ID, 관련 프로모션번호 또는 쿠폰번호를 남깁니다.'
    '설정 불일치가 의심되면 플래그 값과 실제 관련 목록 데이터가 모두 맞는지 함께 확인합니다.'
) '운영자 공통 점검 포인트'

Add-ContentSlide '8. 문서 메모' @(
    '현재 버전은 LWC 코드 기준으로 정리한 운영자 메뉴얼 초안입니다.'
    '실제 교육용 배포본으로 사용하려면 운영 화면 캡처를 각 슬라이드에 추가하면 가장 좋습니다.'
    '필요 시 다음 차수에서 프로모션, 쿠폰, 포인트 화면별 상세 절차를 더 세분화할 수 있습니다.'
) '작성 기준일: 2026-03-31'

$presentation.SaveAs($outPath)
$presentation.Close()
$ppt.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($presentation) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($ppt) | Out-Null
Write-Output $outPath

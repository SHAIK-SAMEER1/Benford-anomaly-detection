$docxPath = (Resolve-Path "Final_Report.docx").Path
$pdfPath = [System.IO.Path]::ChangeExtension($docxPath, ".pdf")

Write-Output "Converting $docxPath to $pdfPath using Microsoft Word..."

$word = New-Object -ComObject Word.Application
$word.Visible = $false
try {
    $doc = $word.Documents.Open($docxPath)
    # 17 = wdFormatPDF
    $doc.SaveAs([ref]$pdfPath, [ref]17)
    $pageCount = $doc.ComputeStatistics([Microsoft.Office.Interop.Word.WdStatistic]::wdStatisticPages)
    $doc.Close([ref]$false)
    Write-Output "SUCCESS: Converted to PDF! Total Word Pages: $pageCount"
} catch {
    Write-Output "ERROR: $_"
} finally {
    $word.Quit()
}

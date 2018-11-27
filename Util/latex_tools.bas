Attribute VB_Name = "latex_tools"
Option Explicit


Sub word_to_latex()

Dim i As Integer, j As Integer, k As Integer
Dim ranActRange As Range
Dim txt As String, path As String, para As String, file As String, file_txt As String
Dim begin As Date

begin = Now
path = "C:\Users\marti\OneDrive\Documents\OLAT\Master\4. Semester\Masterarbeit\LaTeX\input\"
k = 0
file_txt = ""

For i = 1 To ActiveDocument.Paragraphs.Count

    Set ranActRange = ActiveDocument.Paragraphs(i).Range
    para = text_format(ranActRange.text)
    txt = ""
    
    Select Case ActiveDocument.Paragraphs(i).Style
    
        Case "Überschrift 1"
        
            If file_txt <> "" Then
            
                ' Save the previous file_txt if it's not empty
                Call save_file(file, file_txt)
                ' Clean the file_text variable for the next section
                file_txt = ""
                k = k + 1
                
            End If
            
            If k = 0 Then
            
                ' Exception for first file (abstract)
                file = path & "abstract.tex"
                txt = "\section*{\centering{" & para & "}}"
                
            Else:
            
                ' All other files will be saved with its section number
                file = path & "sec" & CStr(k) & ".tex"
                txt = "\section{" & para & "} \label{" & label_format(para) & "}"
                
            End If
            
        Case "Überschrift 2"
        
            txt = "\subsection{" & para & "} \label{" & label_format(para) & "}"
            
        Case "Überschrift 3"
        
            txt = "\subsubsection{" & para & "} \label{" & label_format(para) & "}"
            
        Case "Standard"
        
            txt = para
            
            ' Check if carriage return characters after the paragraph are required
            If i < ActiveDocument.Paragraphs.Count Then
            
                If ActiveDocument.Paragraphs(i + 1).Style = "Standard" _
                And no_equation(i) _
                And Left(ActiveDocument.Paragraphs(i + 1).Range.text, 7) <> "\input{" _
                And Left(ActiveDocument.Paragraphs(i + 1).Range.text, 7) <> "\begin{" Then
                
                    txt = txt & "\\"
                    
                End If
                
            End If
            
        Case "Titel":
        
            ' Ignore all passages formatted as a title
            
        Case "Listenabsatz":
        
            If ActiveDocument.Paragraphs(i - 1).Style <> "Listenabsatz" Then
                
                ' If it's the first item in itemize, first add an opening bracket
                txt = "\begin{itemize}" & Chr(13)
                
            End If
            
            ' Add the item
            txt = txt & "\item " & text_format(ranActRange.ListParagraphs(1).Range.text)
            
            If ActiveDocument.Paragraphs(i - 1).Style = "Listenabsatz" _
            And ActiveDocument.Paragraphs(i + 1).Style <> "Listenabsatz" Then
            
                ' If it's the last item in itemize, finally close the bracket
                txt = txt & "\end{itemize}"
                
            End If
            
        Case Else
        
            ' If there is another paragraph with unknown format, return an error and exit
            MsgBox ("Fehler: Nicht erkanntes Format eines Absatzes (" & ActiveDocument.Paragraphs(i).Style & ")")
            Exit Sub
            
    End Select
    
    If txt <> "" Then
    
        If file_txt <> "" Then
        
            ' If file_txt is not empty anymore, append the paragraph separated by a carriage return
            file_txt = file_txt & Chr(13) & txt
            
        Else:
        
            ' Else it's the first line in the file and no carriage return is required
            file_txt = txt
            
        End If
        
    End If
    
Next

' Save the last file_txt if the parsing of the word is finished
Call save_file(file, file_txt)

MsgBox ("Das Dokument wurde ohne Fehler übersetzt (Laufzeit: " & CStr(DateDiff("s", begin, Now)) & " Sekunden).")

End Sub


Private Function no_equation(i As Integer) As Boolean

Dim j As Integer
no_equation = True

For j = i To i - 3 Step -1

    If j = 0 Then Exit For
    If Left(ActiveDocument.Paragraphs(j).Range.text, 16) = "\begin{equation}" Then no_equation = False
    
Next

End Function


Private Function text_format(text As String) As String

text_format = Trim(text)
text_format = Replace(text_format, Chr(13), "")
text_format = Replace(text_format, "„", """`")
text_format = Replace(text_format, "“", """'")

End Function


Private Function label_format(label As String) As String

label_format = Trim(label)
label_format = LCase(label_format)
label_format = Replace(label_format, " ", "-")
label_format = Replace(label_format, """`", "")
label_format = Replace(label_format, """'", "")

End Function


Private Sub save_file(file As String, file_txt As String)

Dim stream As ADODB.stream
Set stream = New ADODB.stream

With stream
    .Open
    .Type = adTypeText
    .Charset = "iso-8859-1"
    .LineSeparator = adLF
    .WriteText file_txt, adWriteLine
    .SaveToFile file, adSaveCreateOverWrite
    .Close
End With

Set stream = Nothing

End Sub

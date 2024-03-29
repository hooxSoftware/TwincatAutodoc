﻿
cls

$strProject = 'C:\Temp\src' # change this lines for your Project
$strExport  = 'C:\Temp\doc' # add folder for the md-files
 
$RegExBegin = '<(Method|Action|Property|Get|Set) Name="'
$RegexName  = '(?s).(.*?)'
$RegexEnd   = '" Id='
$Regex      = "(?s)(?=($RegExBegin))($RegExName)(?=($RegExEnd))"
 
$RegexReturn     = '(?<Method>%Name) *: *(?<Return>\S*)'
$RegexVariable   = '(?<Variable>\S*)\s*: *(?<Type>\S*)'
$RegexComment    = '(?<Start>\(\*\* *)(?<Value>.*?)(?<End>\*\*\))'
$RegexComment    = '(?<Start>\/\/ *)(?<Value>.*)'
$RegexCommentBegin    = '(?<Start>\(\*\* +)(?<Line>.*)'
$RegexCommentEnd      = '(?<Line>.*?)(?<End> *\*\*\))'
 
function New-Documentation
{
    param(
        [string] $Path,
        [string] $Filter,
        [string] $Destination,
        [switch] $Structured
    )
 
    $index = 0
 
    Get-ChildItem -Path $Path -Recurse -Filter "*.tcPou" | % {
 
      $index++
      $strPath = Split-Path -Parent $_.fullname
      $strFile = Split-Path -Leaf $_.fullname
 
      $Content = Read-SourceFile -Path $strPath -File $strFile
    
      if ($index -lt 10)
      {
        $FileNew = "0" + $index.ToString() + "_" + $strFile.Replace("TcPOU", "md")
      }
      else
      {
        $FileNew = $index.ToString() + "_" + $strFile.Replace("TcPOU", "md")
      }
    
 
      $FolderNew = $Destination;
 
      if ($Structured -eq $true)
      {
          $FolderNew += $strPath.Replace($Path,"")
      }
 
      New-Item -Path $FolderNew -Name $FileNew -Force
    
      Set-Content -Path "$FolderNew\$FileNew" -Value $Content -Encoding UTF8   
 
    }
}
 
function Read-SourceFile
{
    param(
        [string] $Path,
        [string] $File      
    )
 
    Write-Host "Create $FileNew"
 
    $strContent = "[[_TOC_]]`n`n"
    $strContent += "## " + $File.Replace(".TcPOU", "") + "`n`n"
 
    $strSource = Get-Content -Path "$Path\$File"
 
    $strMethodType   = ""
    $strMethodName   = $File.Replace(".TcPOU", "")
    $strDescription  = $null
    $strReturnValue  = "- "
    $strInput        = $null
    $strOutput       = $null
    $strVarInput     = $null
    $DeclarationPart = $false
    $VarLocal        = $false
    $VarInput        = $false
    $VarOutput       = $false
    $strDescription  = '- '
    $Description     = $false
 
    foreach($strLine in $strSource)
    {
 
        if ($DeclarationPart -eq $false)
        {
 
            $strLine |
            Select-String $Regex -AllMatches |
            % { $_.Matches } |
            % {
                $strMethodType = "Method"
 
                if ($_.Value.Contains("Action") -eq $true)
                {
                    $strMethodType = "Action"
                }
 
                $strMethodName = $_.Value.Replace("<Method Name=`"","")
                $strMethodName = $strMethodName.Replace("<Action Name=`"","")
                $strMethodName = $strMethodName.Replace("<Property Name=`"","")
                $strMethodName = $strMethodName.Replace("<Get Name=`"","")
                $strMethodName = $strMethodName.Replace("<Set Name=`"","")
                $strContent += "### " + $strMethodType + " " + $strMethodName + "  `n"
              }
 
            if ($strLine.Contains('Declaration><![CDATA[') -eq $true)
            {
                $DeclarationPart = $true
                $strVarInput     = ''
                $strVarOutput    = ''
                $strDescription  = ''
            }
        }
        if ($DeclarationPart -eq $true)
        {
          
            if ($strLine.Contains(']]></Declaration>') -eq $true)
            {
                $DeclarationPart = $false
 
                $strContent += "returns : $strReturnValue  `n"
                $strContent += "#### Description  `n"
                $strContent += "$strDescription `n"          
                $strContent += "#### Input  `n"
                if ($strVarInput.Length -gt 2)
                {
                    $strContent += "|Name |Type |Comment| `n"
                    $strContent += "|---- |---- |----   | `n"
                }
                else
                {
                    $strVarInput = '- '
                }
 
                $strContent += $strVarInput + "`n"
                $strContent += "#### Output  `n"
                if ($strVarOutput.Length -gt 2)
                {
                    $strContent += "|Name |Type |Comment| `n"
                    $strContent += "|---- |---- |----   | `n"
                }
                else
                {
                    $strVarOutput = '- '
                }
 
                $strContent += $strVarOutput + "`n"
            }
 
            if ($VarInput -eq $false -and $VarOutput -eq $false -and $VarLocal -eq $false)
            {
                if ($Description -eq $false)
                {
                    if ($strLine -match $RegexComment)
                    {                  
                        $strDescription += $Matches["value"] +"  `n"                  
                    }
                    else
                    {
                        if ($strLine -match $RegexCommentBegin)
                        { 
                            $strDescription = ''          
                            $Description = $true                
                        }
                    }
                }
                else
                {
                    if ($strLine -match $RegexCommentEnd)
                    {                
                        $Description = $false                                      
                    }
                    else
                    {
                        $strDescription += $strLine + "  `n"
                    }                  
                }
 
                if ($strLine.Contains($strMethodName) -eq $true)
                {
                    if ($strLine -match $RegexReturn.Replace('%Name', $strMethodName))
                    {
                        $strReturnValue = $Matches["Return"] +"  `n"
                    }
                }
 
                if ($strLine.Contains("VAR") -eq $true)
                {
                    $VarLocal = $true;
                }
                if ($strLine.Contains("VAR_INPUT") -eq $true)
                {
                    $VarInput = $true;
                }
                if ($strLine.Contains("VAR_OUTPUT") -eq $true)
                {
                    $VarOutput = $true;
                }
 
            }
            else
            {
                if ($strLine.Contains("END_VAR") -eq $true)
                {
                    $VarInput  = $false;
                    $VarOutput = $false;
                    $VarLocal  = $false;
                }
 
                if ($VarInput -eq $true)
                {
                    $strVarInput += Read-Variables($strLine)
                }
 
                if ($VarOutput -eq $true)
                {
                    $strVarOutput += Read-Variables($strLine)
                }
            }
 
 
        }
    }
 
    $strContent 
}
 
function Read-Variables()
{
    param(
        [string] $strLine
    )
 
    $strComment = ''
    $strData = ""
 
    if ($strLine -match $RegexComment)
    {                  
        $strComment += $Matches["value"]                  
    }
    if ($strLine -match $RegexVariable)
    {                  
        $strData += "|"+ $Matches["Variable"] + " |" + $Matches["Type"] + " |"+ $strComment + "| `n"
        $strData = $strData.Replace(';', '')
    }
 
    $strData
}
 
New-Documentation -Path $strProject -Filter "*.tcPOU" -Destination $strExport #-Structured
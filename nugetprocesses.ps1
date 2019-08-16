$SourceURL = ""
$APIKey = ""


#remap nuget
write-host "... remapping nuget commands" 
$sourceNugetExe = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$targetNugetExe = "$rootPath\nuget.exe"
Invoke-WebRequest $sourceNugetExe -OutFile $targetNugetExe
Set-Alias nuget $targetNugetExe -Scope Global -Verbose

#getfiles
write-host "...gathering PSD1 files" 
$psds = get-childitem *.psd1 -recurse
foreach ($psd in $psds){
  # build .nuspecs for each psd1
    write-host "...building .Nuspec for $psd" 
    nuget spec $psd

    #split out the package name from path for naming XML ID
    write-host "... updating XML Description"  
    $id = split-path $psd -leaf -resolve 
    write-host $id
    $realid = $id.split(".")[0]
    write-host $realid 
  
    #test split out description and add to XML Description
    $xml = [xml](Get-Content "$psd.nuspec")
    
    write-host "$psd" 
    $descr = Get-Content $psd | Select-String 'description = '
    $des = $descr.tostring().split("=")[-1]

    $description = $xml.SelectSingleNode("//description")
    $description.InnerText = "$des"
    $xml.Save("$psd.nuspec")

    #Update name ID in XML on the Nuspec
    write-host ".. updating XML ID" 
    $element =  $xml.SelectSingleNode("//id")
    $element.InnerText = "$realid"
    $xml.Save("$psd.nuspec")

    #Update Version in XML on the Nuspec
    write-host ".. updating XML Version" 
    $version = Get-Content $psd | Select-String 'ModuleVersion'
    $vrsn = $version.tostring().split("'")[-2]
    $xml.package.metadata.version = "$vrsn"
    $xml.Save("$psd.nuspec")
}

#add source
write-host "... adding Artifact Feed to NuGet sources" 
nuget sources Add -Name "PS_repo_test" -Source "$SourceURL"

#pack up nuspec files
write-host "... gathering Nuspec files" 
$specs = get-childitem *.nuspec -recurse
foreach($spec in $specs){
    write-host "... Packaging $spec"  
    nuget pack $spec
}

#find all packages and push via Nuget to the source
write-host "... Gathering Packages" 
$pkgs = get-childitem *.nupkg -recurse
foreach($pkg in $pkgs){
    write-host "... Pushing $pkg to NuGet Source"  
    nuget push $pkg -source 'PS_repo_test' -apikey $APIKey -skipduplicate

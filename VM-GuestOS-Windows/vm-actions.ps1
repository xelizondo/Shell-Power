$Title = "Action on VM?"
$Prompt = "Enter your choice"
$Choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&Quit", "&Start", "&Stop")
$Default = 1
 
# Prompt for the choice
$Choice = $host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)
 
# Action based on the choice
switch($Choice)
{
    0 { exit }
    1 { Start-AzVM -ResourceGroupName "RG-AVD-POOL-1-COMPUTE" -Name "vd-pd-0" }
    2 { Stop-AzVM -ResourceGroupName "RG-AVD-POOL-1-COMPUTE" -Name "vd-pd-0" }
}
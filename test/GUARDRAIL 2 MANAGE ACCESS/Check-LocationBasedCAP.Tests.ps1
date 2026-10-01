BeforeAll {
    . "$PSScriptRoot\..\..\src\Common\Get-allowedLocationCAPCompliance.ps1"
    Import-Module ".\src\GUARDRAIL 2 MANAGE ACCESS\Audit\Check-LocationBasedCAP.psm1"
    # Import-Module $ModulePath -Force
}

Describe "Get-LocationBasedCAP" {

    BeforeEach {

        $msgTable = @{
            isCompliant    = "Compliant"
            compliantC2    = "Allowed location CAP configured."
            isNotCompliant = "Non-Compliant"
            nonCompliantC2 = "Allowed location CAP not configured."
        }

        $BaseParams = @{
            ControlName        = "GR2"
            ItemName           = "Location Based CAP"
            itsgcode           = "AC-01"
            msgTable           = $msgTable
            ReportTime         = (Get-Date).ToString()
            StorageAccountName = "teststorage"
            ContainerName      = "reports"
            ResourceGroupName  = "rg-test"
            SubscriptionID     = "12345"
            DocumentName       = @("testdoc")
        }
    }

    Context "When Conditional Access Policy is compliant" {

        BeforeEach {

            Mock Get-allowedLocationCAPCompliance {
                [PSCustomObject]@{
                    ComplianceStatus = $true
                    Comments         = "Named locations configured"
                    Errors           = @()
                }
            }
        }

        It "Returns ComplianceStatus as true" {

            $result = Get-LocationBasedCAP @BaseParams

            $result.ComplianceResults.ComplianceStatus | Should -BeTrue
        }

        It "Returns compliant comments" {

            $result = Get-LocationBasedCAP @BaseParams

            $result.ComplianceResults.Comments | Should -Match "Compliant"
        }

        It "Returns no errors" {

            $result = Get-LocationBasedCAP @BaseParams

            $result.Errors.Count | Should -Be 0
        }
    }

    Context "When Conditional Access Policy is non-compliant" {

        BeforeEach {

            Mock Get-allowedLocationCAPCompliance {
                [PSCustomObject]@{
                    ComplianceStatus = $false
                    Comments         = "No named location policy"
                    Errors           = @()
                }
            }
        }

        It "Returns ComplianceStatus as false" {

            $result = Get-LocationBasedCAP @BaseParams

            $result.ComplianceResults.ComplianceStatus | Should -BeFalse
        }

        It "Returns non-compliant comments" {

            $result = Get-LocationBasedCAP @BaseParams

            $result.ComplianceResults.Comments | Should -Match "Non-Compliant"
        }
    }

    Context "When errors are returned from compliance check" {

        BeforeEach {

            Mock Get-allowedLocationCAPCompliance {
                [PSCustomObject]@{
                    ComplianceStatus = $false
                    Comments         = "Error occurred"
                    Errors           = @("Graph API Error")
                }
            }
        }

        It "Returns errors in output" {

            $result = Get-LocationBasedCAP @BaseParams

            $result.Errors.Count | Should -Be 1
            $result.Errors[0] | Should -Be "Graph API Error"
        }
    }

    Context "When Multi Cloud Usage Profiles feature is enabled" {

        BeforeEach {

            Mock Get-allowedLocationCAPCompliance {
                [PSCustomObject]@{
                    ComplianceStatus = $true
                    Comments         = "Named locations configured"
                    Errors           = @()
                }
            }

            Mock Add-ProfileInformation {
                param(
                    $Result,
                    $CloudUsageProfiles,
                    $ModuleProfiles,
                    $SubscriptionId,
                    $ErrorList
                )

                return $Result
            }
        }

        It "Calls Add-ProfileInformation" {

            $params = $BaseParams.Clone()
            $params.EnableMultiCloudProfiles = $true
            $params.CloudUsageProfiles = "3"
            $params.ModuleProfiles = "Test"

            $null = Get-LocationBasedCAP @params

            Should -Invoke Add-ProfileInformation -Times 1 -Exactly
        }
    }

    Context "Output structure validation" {

        BeforeEach {

            Mock Get-allowedLocationCAPCompliance {
                [PSCustomObject]@{
                    ComplianceStatus = $true
                    Comments         = "Configured"
                    Errors           = @()
                }
            }
        }

        It "Returns expected ComplianceResults properties" {

            $result = Get-LocationBasedCAP @BaseParams

            $result.ComplianceResults.ControlName | Should -Be "GR2"
            $result.ComplianceResults.ItemName | Should -Be "Location Based CAP"
            $result.ComplianceResults.itsgcode | Should -Be "AC-01"
            $result.ComplianceResults.ReportTime | Should -Not -BeNullOrEmpty
        }
    }
}
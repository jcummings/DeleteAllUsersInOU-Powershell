<# Duo_org.ps1 #>
# define the default Duo Org/Instance you want to use, useful if you have more than one.
[string]$DuoDefaultOrg = "prod"

[Hashtable]$DuoOrgs = @{
                        prod = [Hashtable]@{
                                iKey  = [string]"DIN73Q13I1E2Z5CJ7NUU"
                                sKey = [string]"3oILJHZJDSGRPy5vMmctMzpSv2oyPnIFPKyNObTz"
                                apiHost = [string]"api-c9cc3e0e.duosecurity.com"
                               }
                        etst = [Hashtable]@{
                                iKey  = [string]"DIxxxxxxxxxxxxxxxxxx"
                                sKeyEnc = [string]"Big Long protected string on 1 line here"
                                apiHost = [string]"api-nnnnnxnx.duosecurity.com"
							   }
                       }
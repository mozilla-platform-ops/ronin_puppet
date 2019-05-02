$tooltool_cer = "$env:SYSTEMROOT\temp\tooltool.cer"
$webRequest = [Net.WebRequest]::Create("https://tooltool.mozilla-releng.net")
try { $webRequest.GetResponse() } catch {}
$cert = $webRequest.ServicePoint.Certificate
$bytes = $cert.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert)
certutil -addstore root $tooltool_cer

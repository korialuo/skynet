local skynet = require "skynet"
local crypt = require "skynet.crypt"


local src = "hello world !"

local privpem_pkcs8 = [[-----BEGIN PRIVATE KEY-----
MIICeAIBADANBgkqhkiG9w0BAQEFAASCAmIwggJeAgEAAoGBANMfFz1aPEuvl/AN
0lVNXoMGoRrUPfmHtKtUfpaM7vxPXtYzHsBzu6KLOBDeOjXO9YD43vLIRpZwO0r4
kWLMYGSZMxSQba7itQ5H6kDc2dm7UQqsJ34wupejGADd2iEOBappvXH7LEaGhjvs
W1ZOZi1r5or0HXqRNkWIGvU8YYWpAgMBAAECgYA+wMcPnXq+pHrtB661XEHzgEzy
xJOHUCcLphnadhmzNYRi9t71JXFoZylLGkMDK3kd1NuwHoecv89gAXJ1g3pC4mW+
D9xZluFre2qlYs+nn0nE1cNJ+ogqkjQ76XuV/9IuZSSPCxRJ6W4EaR3rQi/ORK/o
KOKucP4kFTJTMQrwYQJBAO6xYGrfiRSQkQKj0dR2at29t5gRJ5FU6XzVsy1WAN3G
goSqOVBYCAL2IF8jHbt5dvX1QKzAKX44vBSmCs6/B5sCQQDibe68z4WKFOYGbg75
ZKmmJuCzDCTRaZu4ThpqFVJlwdw1JeFOX3r+4qpwfNDOSOinzL7BmO+sHBBmBUJG
jLYLAkEA7ZFFcZmCiiFI8uOx2FD0FDbbIFMSmqd0rHbVmu3aduE4zmnOGZVEhA4M
MiR1Vz6RlEPBVy77HVHCgJqybwvauQJBAJQ9WKFwU4MVL4tiHpeUGaVXqqBOAQTA
2VwOdiihkPJhuuNoy1reE84vY1qFvMZw4TCKURC6KZ9KOEoygzNhCAUCQQDsOp9u
EL2lf9pph/xpdMlIk4s1f6cJ19YTOq/F9Bdk6Ilok23yuuynDnV31LLG1wEscn/n
jyiiuJjC1pbr+LLV
-----END PRIVATE KEY-----]]

local pubpem_pkcs8 = [[-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDTHxc9WjxLr5fwDdJVTV6DBqEa
1D35h7SrVH6WjO78T17WMx7Ac7uiizgQ3jo1zvWA+N7yyEaWcDtK+JFizGBkmTMU
kG2u4rUOR+pA3NnZu1EKrCd+MLqXoxgA3dohDgWqab1x+yxGhoY77FtWTmYta+aK
9B16kTZFiBr1PGGFqQIDAQAB
-----END PUBLIC KEY-----]]

local privpem_pkcs1 = [[-----BEGIN RSA PRIVATE KEY-----
MIICWwIBAAKBgQCqCeoCQ2Hgv/WVO2V4aAD8l9O5DWOVJXChgSpXWNMTqGU/vr1b
JHFeIZgsvuRDpGKRoOzkA7tc7MueVETMdIAVdTI8kFS/QneDr3F56j61zv3tpQtU
0NRqcQTxXir8Nc7cEyZQuvzpFSowXqfk92819oskJKo4m+59vCge7r7JfwIDAQAB
AoGAEHezVRLHiOeuVgyRkC6qYcwmchaM3WXp2YpT2m+8yXuWiqzjU89ct1wTi8nU
+4QRE799EbwWyjIYqjXJD+/8c28BXnLJhxils7qNJtEeE/cJ6qim+VmsLx4xTGEu
jxe+fVfqS4dLbChZbo8ijBdhF7UQPAeqS4tMm7ZRmawzXSkCQQDiVpRLkL8/dVh0
Dd1DONBCHvnyg4VbqU661LxhqYpWKSgy7SAxi2+GgQb/ZFfHI4BNyq1RHt7rqZYw
6xjgDo2tAkEAwFKLLnY9opP2D8ClzCJzKIZPWolXzQjfhKQvPVMrriJKd32UBGIh
MdQUqGzs0tWbrYN5sbDkky6jvtAfRi/BWwJAU7VNlzzrXl7Z3eIayPfEHhAyxLxb
n/DYC0UOftgjL4Z9NYh5dZlqH8asfdvwktfQZfTlcLEIJQRNZb4tLwBy6QJAakTy
HUE+u3gQrhGgS5T5lvnoHTno5yWxBIUIiVVMvJK8HRypzmY+u17Z71sI3VMlC5Kr
itEY7G8IEebEcS7wIwJAZlK4D+K1wxSOeUvEnEGGt62oPVr/27CBwA9ePON48Rpx
90lSNcIaEUDTYnNZuz+NTN6ptCJruMkjiW0G30NAWQ==
-----END RSA PRIVATE KEY-----
]]

local pubpem_pkcs1 = [[-----BEGIN RSA PUBLIC KEY-----
MIGJAoGBAKoJ6gJDYeC/9ZU7ZXhoAPyX07kNY5UlcKGBKldY0xOoZT++vVskcV4h
mCy+5EOkYpGg7OQDu1zsy55URMx0gBV1MjyQVL9Cd4OvcXnqPrXO/e2lC1TQ1Gpx
BPFeKvw1ztwTJlC6/OkVKjBep+T3bzX2iyQkqjib7n28KB7uvsl/AgMBAAE=
-----END RSA PUBLIC KEY-----]]


skynet.start(function()
    local bs = crypt.rsaprisign(src, privpem_pkcs8)
    local sign = crypt.base64encode(bs)
    print("----- RSA SIGN TEST -----")
    print(sign)
    local dbs = crypt.base64decode(sign)
    assert(crypt.rsapubverify(src, dbs, pubpem_pkcs8))
    print("----- RSA SIGN TEST OK -----\n")

    print("----- RSA CRYPT TEST -----")
    bs = crypt.rsapubenc(src, pubpem_pkcs1)
    local dst = crypt.base64encode(bs)
    print(dst)
    dbs = crypt.base64decode(dst)
    local dsrc = crypt.rsapridec(dbs, privpem_pkcs1)
    print(dsrc)
    assert(dsrc == src)

    print("----- RSA CRYPT TEST OK -----\n")
    skynet.exit()
end)